// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Estonian (`et`).
class AppL10nEt extends AppL10n {
  AppL10nEt([String locale = 'et']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Tere tulemast';

  @override
  String get onboardingEyebrowCommunication => 'Suhtlemine';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligentsus';

  @override
  String get onboardingEyebrowComputer => 'Arvuti';

  @override
  String get onboardingEyebrowAutomation => 'Automatiseerimine';

  @override
  String get onboardingNext => 'Edasi';

  @override
  String get onboardingIntroCouldNotLoad => 'Sissejuhatust ei saanud laadida.';

  @override
  String get onboardingModelDescription =>
      'Valige mudel, mida NeoAgent vaikimisi kasutab, või laske sellel automaatselt valida.';

  @override
  String get onboardingLoadingModels => 'Mudelite laadimine…';

  @override
  String get noAiModelTitle => 'AI mudelit pole veel seadistatud';

  @override
  String get noAiModelBody =>
      'Lisage API-võti teenusepakkujalt (nt OpenAI, Anthropic või Google). Seejärel näitab NeoAgent mudeleid, mida saate kasutada.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent vajab vastamiseks tehisintellekti mudelit. Lisage API-võti teenusepakkujalt (nt OpenAI, Anthropic või Google).';

  @override
  String get noAiModelAdminHint =>
      'Administraatorina saate ka kõigi jaoks teenusepakkujaid seadistada jaotises Administraator → Pakkujad.';

  @override
  String get addApiKey => 'Lisage API võti';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform on ühendatud.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return '$platform ühendamise ootamine…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Seadistust ei saanud salvestada: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Valmis';

  @override
  String get onboardingStepRequired => 'Nõutav';

  @override
  String get onboardingStepOptional => 'Valikuline';

  @override
  String get onboardingStepCloudOrLocal => 'Pilv või kohalik';

  @override
  String get onboardingStepComputer => 'Arvuti';

  @override
  String get onboardingStepRoutines => 'Rutiinid';

  @override
  String get onboardingComputerChoiceTitle => 'Kus see peaks\ntöötama?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Saate seansi kaupa vahetada.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Privaatne liivakast · alati sees';

  @override
  String get onboardingThisComputer => 'See arvuti';

  @override
  String get onboardingThisComputerSubtitle =>
      'Teie failid, rakendused ja brauser';

  @override
  String get onboardingSearchApps => 'Otsi rakendusi…';

  @override
  String get onboardingRoutinesDescription =>
      'Tulemused jõuavad teie vestlustesse.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Tulemused saabuvad märguannetena.';

  @override
  String get onboardingNotifications => 'Märguanded';

  @override
  String get onboardingReadyTitle => 'Kõik on\nvalmis.';

  @override
  String get onboardingReadyDescription => 'Saatke oma esimene sõnum.';

  @override
  String get onboardingMessageNeoagent => 'Sõnum NeoAgent';

  @override
  String get onboardingAskAnything => 'Küsi midagi…';

  @override
  String get onboardingOpenNeoagent => 'Avage NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planeerige nädalavahetuse reis';

  @override
  String get onboardingStarterLanding => 'Looge sihtleht';

  @override
  String onboardingQuickSteps(int count) {
    return '$count kiired sammud';
  }

  @override
  String get taskNeedsEmail => 'Ühendage esmalt e-post';

  @override
  String get taskNeedsCalendar => 'Ühendage esmalt kalender';

  @override
  String get taskNeedsModel => 'Esmalt seadistage AI-mudel';

  @override
  String get taskPromptDailyRecap =>
      'Kokkuvõte minu päevast: tehke kokkuvõte tänasest vestlusest, lõpetatud töödest ja otsustest ning seejärel loetlege kõik, mida peaksin homme järgima. Hoidke see lühike ja saatke see mulle.';

  @override
  String get taskPromptInboxCheck =>
      'Kontrollige minu e-posti postkasti sõnumeid, mis on saabunud pärast viimast kontrolli. Saatke mulle sõnumeid ainult kiireloomuliste või vastust vajavate e-kirjade kohta koos üherealise kokkuvõttega. Kui miski ei vaja minu tähelepanu, ärge saatke midagi.';

  @override
  String get taskPromptMorningBriefing =>
      'Valmistage ette minu hommikune infotund: tänane ilm, kus ma olen, sündmused minu kalendris ja kõige olulisemad avatud asjad, millest tean. Saatke see lühikese skannitava sõnumina.';

  @override
  String get taskPromptTomorrowPrep =>
      'Vaata mu homset kalendrit. Rääkige mulle iga kohtumise kohta, millega see on seotud, kes on sellega seotud ja mida peaksin ette valmistama. Kui homme on tühi, ärge saatke midagi.';

  @override
  String get taskPromptNewsDigest =>
      'Otsige veebist tänaste kõige olulisemate uudiste kohta mulle olulistel teemadel (kasutage seda, mida minu huvide kohta mäletate). Saatke mulle kokkuvõte kuni viiest üksusest koos ühe lause ja lingiga.';

  @override
  String get taskPromptWeeklyReview =>
      'Vaata üle minu nädal: mis sai tehtud, mis libises ja mis on veel lahtine. Paku välja kolm kõige olulisemat asja, millele järgmisel nädalal keskenduda.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Linkige agendile kuuluv telefoninumber. Kõik, kelle lubate, saavad sellega otsevestlustes ja rühmades vestelda.';

  @override
  String get whatsappSelfChatDescription =>
      'Linkige oma number ja rääkige agendiga vestluses „Sõnum ise”. Kõiki teisi selle konto vestlusi ja gruppe eiratakse.';

  @override
  String get chatSendHintMac => '⌘↵ saatmiseks';

  @override
  String get chatSendHintOther => 'Saatmiseks Ctrl+Enter';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Selle lõpp-punkti jaoks on vaja baas-URL-i.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Muudetud e-posti aadress kinnitatakse enne selle kasutamist.';

  @override
  String get aDecisionHigherUpTheChain => 'Ahelas kõrgemal asuv otsus võidab.';

  @override
  String get aDeletedAccount => 'kustutatud konto';

  @override
  String get aFridayLookBackAtThe =>
      'Reedene tagasivaade nädalale ja plaan järgmiseks.';

  @override
  String get aKeyThatAsksForA =>
      'Võti, mis küsib PIN-koodi või sõrmejälge, asendab ka teie kahefaktorilise koodi.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Keelemudel hindas seda sõnumit, kuna SystemOne on välja lülitatud.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'NeoAgenti häälestuse metaandmete fail ületas oma ohutu suuruse piiri.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Serveris on saadaval uuem veebiversioon. Laadige uuesti, et tuua uusim kogum.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Privaatne töölaud Chromiumi, failide, tekstiredaktori, terminali ja Pythoniga. Teie töö jääb seansside vahel salvestatuks.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Privaatne Linuxi arvuti või Android-seade.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Nõutavat NeoAgenti seadistusfaili ei saanud alla laadida.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Meeskonnakaaslane saadab teile kutselingi. Kui te sellega nõustute, siis nemad ';

  @override
  String get aTeammateSentYouAnInvite =>
      'meeskonnakaaslane saatis teile kutselingi, sisestage see siia, et nende meeskonnaga liituda.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Ajutine allalaadimine puhastatakse hiljem.';

  @override
  String get aValueIsStored => 'Väärtus salvestatakse.';

  @override
  String get access => 'Juurdepääs';

  @override
  String get accessActivity => 'Juurdepääsutegevus';

  @override
  String accessArg1(Object? arg1) {
    return 'Juurdepääs: $arg1';
  }

  @override
  String get accessMode => 'Juurdepääsurežiim';

  @override
  String get accessPermissions => 'Juurdepääsuload';

  @override
  String get accessToken => 'juurdepääsuluba';

  @override
  String get accessToken2 => 'Juurdepääsuluba';

  @override
  String get account => 'Konto';

  @override
  String accountArg1(Object? arg1) {
    return 'Konto #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Konto muutmise märguanded';

  @override
  String get accountEmail => 'Konto meiliaadress';

  @override
  String get accountEmailIsOffUntilThese =>
      'Konto e-posti aadress on välja lülitatud, kuni need on määratud: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent kasutab seda keelt kõikjal rakenduses. Esmakordsel sisselogimisel järgitakse seda seadet. Pärast seda salvestatakse valik teie kontole ja seda kasutatakse igas seadmes.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Keelt ei saanud muuta: $error';
  }

  @override
  String get accountLanguageTitle => 'Keel';

  @override
  String get accountNumber => 'Konto number';

  @override
  String get accountSettings => 'Konto seaded';

  @override
  String get accounts => 'Kontod';

  @override
  String get accountsByTokensUsedAllTime =>
      'Kontod kasutatud žetoonide järgi, kogu aeg.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'kontode pilvarvutid. Muudatused rakenduvad pärast serverit ';

  @override
  String get accountsOnThisServer => 'Kontod selles serveris';

  @override
  String get active => 'Aktiivne';

  @override
  String get activeSessions => 'Aktiivsed seansid';

  @override
  String get activeToday => 'Täna aktiivne';

  @override
  String get add => 'Lisa';

  @override
  String get addAProviderCredentialFirstIts =>
      'Esmalt lisage teenusepakkuja mandaat. Selle mudelid kuvatakse siin korra ';

  @override
  String get addAgent => 'Lisa agent';

  @override
  String get addAnotherSignInMethodBefore =>
      'Enne selle eemaldamist lisage teine sisselogimisviis.';

  @override
  String get addBinding => 'Lisa sidumine';

  @override
  String get addByNameOrId => 'Lisage nime või ID järgi';

  @override
  String get addByNameOrIdInstead => 'Lisage selle asemel nime või ID järgi';

  @override
  String get addCredentialBinding => 'Lisage mandaadi sidumine';

  @override
  String get addEntry => 'Lisa kirje';

  @override
  String get addKey => 'Lisa võti';

  @override
  String get addMcpServer => 'Lisage MCP-server';

  @override
  String get addMemory => 'Lisa mälu';

  @override
  String get memoryReview => 'Vaata üle';

  @override
  String get memoryReviewPrompt =>
      'Vaata kõik mu mälestused üle ja korrasta need: arhiveeri duplikaadid, aegunud faktid ja kõik, millel pole püsivat väärtust. Seejärel ütle mulle lühidalt, mida muutsid.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Lisage rohkem pikkust või muud märgitüüpi.';

  @override
  String get addPeopleOrGroups => 'Lisage inimesi või gruppe';

  @override
  String get addSecurityKey => 'Lisa turvavõti';

  @override
  String get addSomeoneOrAGroup => 'Lisage keegi või grupp';

  @override
  String get addTask => 'Lisa ülesanne';

  @override
  String get addTests => 'Lisa testid';

  @override
  String get addTestsForThePartsOf =>
      'Lisage testid selle projekti kõige väiksema levialaga osade jaoks ja seejärel käivitage need.';

  @override
  String get addTheirOwnKeysInSettings => 'lisage seadetes oma võtmed.';

  @override
  String get addToPrompt => 'Lisa viipale';

  @override
  String get added => 'Lisatud';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Lisatud $arg1 · Viimati kasutatud $arg2';
  }

  @override
  String get addressWithTheProvider => 'aadress teenusepakkujaga.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Reguleerige kõlarite helitugevust, vaadake üle riistvaranuppude vaikeseaded ja hallake seda käivitusseanssi.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Rohkemate sõnumikanalite nägemiseks kohandage otsingu- või olekufiltrit.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Siin saate reguleerida kõlarite helitugevust.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Administraator › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Siin kuvatakse administraatoritoetused, kutselingid ja haldusmuudatused.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Täiustatud käsitsi ajakava erijuhtudeks.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Täiustatud: minut tund päev kuu nädalapäev.';

  @override
  String get againRightAway => 'kohe uuesti.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Agent kutsub';

  @override
  String get agentCommunication => 'Agendi suhtlus';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agendi suhtlus: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agendirežiim muudab tööruumi · ⌘↵ saada · ⌘N uut seanssi';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agent peatub ja küsib enne käivitamist sinu luba.';

  @override
  String get agentProfile => 'Agendi profiil';

  @override
  String get agentVisibleName => 'Agendile nähtav nimi';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent soovib kasutada $arg1. Puudutage otsustamiseks.';
  }

  @override
  String get agents => 'Agendid';

  @override
  String get aiAnswerUnreadable => 'AI vastus on loetamatu';

  @override
  String get aiProviderKeys => 'AI pakkuja võtmed';

  @override
  String get aiUnavailable => 'AI pole saadaval';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'märguanded ja muud konto meilid.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Annab märku, kui sõnumsideühendus vajab kasutaja tähelepanu';

  @override
  String get all => 'Kõik';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Kõik agendid ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Kõik $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Kõik pilvearvuti pesad on praegu kasutusel. Proovige hetke pärast uuesti.';

  @override
  String get allComputerSlotsAreBusy => 'Kõik arvutipesad on hõivatud';

  @override
  String get allTables => 'Kõik lauad';

  @override
  String get allTime => 'Kogu aeg';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Kõik tööriistad on lubatud — agent võib ilma küsimata kasutada mis tahes võimalusi. ';

  @override
  String get allow => 'Luba';

  @override
  String get allowedRunsWithoutAsking => 'Lubatud. Jookseb küsimata.';

  @override
  String get allowAll => 'Luba kõik';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Lubage NeoAgenti jaoks \"Installi tundmatud rakendused\" ja proovige seejärel värskendada.';

  @override
  String get allowOnce => 'Luba üks kord';

  @override
  String get allowSender => 'Luba saatja';

  @override
  String get allowSession => 'Luba seanss';

  @override
  String get allowTheAgentToStartAn =>
      'Lubage agendil alustada teiega rakendusesisest häälkõnet.';

  @override
  String get allowedOrigins => 'Lubatud päritolu';

  @override
  String get allowedPathPrefix => 'Lubatud tee eesliide';

  @override
  String get allowsYouCanChangeThatPer =>
      'lubab. Saate seda hiljem inimese kohta muuta. Lingid ei anna kunagi ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'kuulub juba olemasolevale kontole';

  @override
  String get alreadyLinkedToAnotherAccount => 'on juba lingitud teise kontoga';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'juba lingitud teise neoagendi kontoga';

  @override
  String get alreadyUsed => 'juba kasutatud';

  @override
  String get always => 'Alati';

  @override
  String get alwaysAllow => 'Lubage alati';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '„Alati luba” salvestab reegli jäädavalt – saate seda seadetes muuta.';

  @override
  String get alwaysAsk => 'Küsi alati';

  @override
  String get alwaysEngage => 'Alati kaasata';

  @override
  String get alwaysJoins => 'Alati liitub';

  @override
  String get anApiKeyIsRequired => 'Vaja on API-võtit.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Õhtune kokkuvõte sellest, mis juhtus ja mida edasi teha.';

  @override
  String get anHttpOrHttpsUrlIs => 'Nõutav on http või https URL.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'ja analüütika. Meeskonna lingid elavad meeskonna lehel.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Androidi APK installimine pole sellel platvormil saadaval.';

  @override
  String get androidApp => 'Androidi rakendus';

  @override
  String get androidControl => 'Androidi juhtimine';

  @override
  String get androidCouldNotStart => 'Android ei saanud käivituda';

  @override
  String get androidNotificationReceived => 'Androidi teatis vastu võetud';

  @override
  String get androidOnly => 'Ainult Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Androidi paketi installerit ei saanud avada.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Androidi ekraan – puudutamiseks puudutage, lohistamiseks pühkige';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Vastused @mainimised probleemidele ja tõmbetaotlustele';

  @override
  String get anyone => 'Igaüks';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Igaüks sellel platvormil saab sõnumit $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Kõik sellel platvormil olevad inimesed saavad $arg1-le $arg2-s sõnumit saata.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Kõik, kes saavad selle kontoga ühendust võtta, saavad $arg1-ga rääkida.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Igaüks, kellel on link, saab liituda, kuni see aegub või kui te selle tühistate.';

  @override
  String get apiHttpsOrigin => 'API HTTPS-i päritolu';

  @override
  String get apiKey => 'API võti';

  @override
  String get apiKey2 => 'api võti';

  @override
  String get apiKey3 => 'API võti';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api võti anthropic claude openai gpt xai grok google gemini minimax nvidia nim openruuteri mandaadid';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API-võtmed ja lõpp-punktid AI-, otsingu- ja häälteenuse pakkujatele. Nad ';

  @override
  String get apiRequest => 'API taotlus';

  @override
  String get apiYourOwnServerASelf =>
      'API – teie enda server, isehostitav mudel või mõni muu ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK allalaadimine ebaõnnestus HTTP $arg1-ga.';
  }

  @override
  String get appNameIsRequired => 'Rakenduse nimi on kohustuslik.';

  @override
  String get appUpdates => 'Rakenduste värskendused';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Rakenduse värskendused pole selle järgu jaoks konfigureeritud.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Praegusele jooksule rakendati $arg1 järjekorda seatud roolimise värskendused.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Rakendatud on $arg1 roolisüsteemi uuendus(ed).';
  }

  @override
  String get apply => 'Rakenda';

  @override
  String get applyBehaviorNotes => 'Rakenda käitumismärkusi';

  @override
  String get applyCoreMemory => 'Rakendage põhimälu';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Tundlike agentide tööriistade kinnitustaotlused';

  @override
  String get approvalRequired => 'Nõutav heakskiit';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Heakskiit jääb teie autentitud mobiiliseansse ja iga kood aegub pärast lühikest aega automaatselt.';

  @override
  String get approveLogin => 'Kinnitage sisselogimine';

  @override
  String get approveQrLogin => 'Kinnitage QR-sisselogimine';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Kinnitage see ainult siis, kui alustasite just praegu selles seadmes sisselogimist.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Kinnitatud sisselogimine $arg1 jaoks.';
  }

  @override
  String get approvedOnly => 'Ainult heaks kiidetud';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Heakskiidetud sidumine $arg1 jaoks.';
  }

  @override
  String get approvedPeopleAndGroups => 'Heakskiidetud inimesed ja rühmad';

  @override
  String get approvedPeopleOnly => 'Ainult heakskiidetud inimesed';

  @override
  String get archive => 'Arhiiv';

  @override
  String get archiveAgent => 'Arhiivi agent?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arhiiv ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arhiiv $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arhiveerida valitud mälestused?';

  @override
  String get areSharedByEveryAccountOn =>
      'jagavad kõik selle serveri kontod; kontod saavad ikka ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M sisend';
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
    return 'Vajalik on juurdepääs $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 kontod';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktiivne';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Lisatud on $arg1. Muutke seda igal ajal, et muuta ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '\"$arg1\" ja selle käitamisajalugu kustutatakse jäädavalt. Iga aktiivne jooks peatatakse. Tööalal olevaid faile ei puudutata.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Vajalik on $arg1 kinnitus';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 rakendused on aktiivsed';
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
    return '$arg1 (aktiivsed tööriistad $arg2)';
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
    return '$arg1 $arg2 ja $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 muudetud';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 tähemärgid';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Loodud $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [kohalik uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2, mis vastab \"$arg3\"';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent tööruum';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 uued kontod';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 jookseb · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 näidised';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 roolimine on järjekorras';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 märgid';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 märgid';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 ja $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 sai administraatoriks ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 baiti';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanal';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 märgid';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 tühjendatud.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 on konfigureeritud';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 ühendatud. Valige hoidlad ja inimesed jaotises Kes saavad sõnumeid saata.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 põhikirjed.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 lõi kutselingi';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 töölaud';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 sündmused';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 ebaõnnestus';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 ebaõnnestus';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 ebaõnnestub';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 jaoks';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Ainult märgistatud rühmad $arg1';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h tagasi';
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
    return '$arg1 abilised';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 tabamussuhe)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 on administraator, seega ei saa kontot kustutada ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 on seadmel $arg2 blokeeritud. Vastuste lubamiseks värskendage juurdepääsuloendit.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 on ühendatud ja reageerib.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 ei ole enam administraator ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 pole mudelil $arg2 saadaval (puudub käitusaja luba või sõltuvus).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 liideti $arg2 alla';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 hindas LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 võti$arg2 on konfigureeritud';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1 võti eemaldatud.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 jäänud';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 vasak $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 on lingitud';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m tagasi';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Veenduge, et see töötab, seejärel proovige uuesti.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 haldab seda kontot';
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
    return '$arg1 mudelid valmis';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 rohkem';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 rohkem samme jooksuajaloos';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 on $arg2-st teisaldatud ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 peab olema lõplik arv.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 peab olema http:// või https:// aadress.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 vajab tähelepanu';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgenti tööruum';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 uued kontod viimases $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · seda jooksu juhivad uued sõnumid';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 uued jooksud';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 haldab nüüd seda kontot.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return 'Lubatud on 4 luba $arg1. Failid on piiratud teie NeoAgent Workspace\'i kaustaga.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 või $arg2 on lubatud';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 rühmadest liitub tavalise vestlusega';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 mudelitest';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 mudelitest on valmis';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 komplektist';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 ja $arg2 tööriistad on lubatud';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 päeval $arg2 kell $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 vastab ainult neile inimestele, kelle allpool lisate.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 vastab ainult märgistamise korral';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 räägib ainult teie poolt heaks kiidetud inimeste ja rühmadega';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Lisatud on $arg1 inimesed või rühmad';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 planeerimine';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 pakkujad';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 valmis';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 rekordid';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 ümbersuunamise URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registreeritud';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 vastas';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 tühistas kutselingi';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 jookseb';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 töötab · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 töötab viimases $arg2-s.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 salvestatud.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Valitud on $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 näidatud';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 jäi vaikseks';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 rool $arg2 on järjekorras';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 samm$arg2 · puudutage kontrollimiseks sõlme';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 sammud';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 lõpetas $arg2 haldamise';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 märgid';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 märgid viimases $arg2-s.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 tööriistad';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (salvestatud alistamine pole saadaval)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% kasutatud · $arg2 alles';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 soovib teiega rääkida.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 veeb';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" eemaldatakse jäädavalt.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return 'Seda kontot haldab $arg1';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 ei vasta sellel platvormil';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 ei vasta küsimusele $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Artefaktide salvestamine kasutaja poolt';

  @override
  String get askAQuestionOrStartA =>
      'Esitage küsimus või alustage ülesannet...';

  @override
  String get askBeforeClosingToBackground => 'Küsi enne tausta sulgemist';

  @override
  String get askMe => 'Küsi minult';

  @override
  String get assignedAgent => 'Määratud agent';

  @override
  String get assignedAgent2 => 'Määratud agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Määratud agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Määratud saaja (valikuline)';

  @override
  String get assistant => 'Assistent';

  @override
  String get assistantKey131 => 'Assistendi võti 131';

  @override
  String get atLeast1 => 'Vähemalt 1.';

  @override
  String get attachFiles => 'Manustage failid';

  @override
  String attentionArg1(Object? arg1) {
    return 'Tähelepanu $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'auditi logi administraator luba tühistada kutse meeskonna ajalugu';

  @override
  String get authMethod => 'Auth meetod';

  @override
  String get authServerUrl => 'Auth serveri URL';

  @override
  String get authentication => 'Autentimine';

  @override
  String get authenticationFailed => 'Autentimine ebaõnnestus.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Autentimine on veel pooleli. Lõpetage brauseri voog ja proovige uuesti.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Autentimine on veel pooleli. Lõpetage brauseri voog ja värskendage.';

  @override
  String get authenticationTimedOut => 'Autentimine aegus.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentimine tühistati enne lõpetamist.';

  @override
  String get authenticatorApp => 'Autentija rakendus';

  @override
  String get authenticatorCode => 'Autentija kood';

  @override
  String get authorOptional => 'Autor (valikuline)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automaatne (esimene API-võtmega pakkuja)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automaatne marsruut parimale saadaolevale mudelile';

  @override
  String get automaticFast => 'Automaatne (kiire)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automaatne loeb ruumi ja hoiab tavaliselt tagasi. Ainult mainimine ei tee otsustuskõnet enne, kui seda otseselt käsitletakse.';

  @override
  String get automaticReserved => 'Automaatne, reserveeritud';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automaatne tagasipööramine nõuab seadistusekraanilt uuesti proovimist.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automaatne valib tavalise mudelikataloogi kaudu kiire mudeli.';

  @override
  String get automation => 'Automatiseerimine';

  @override
  String get available => 'Saadaval';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Taas saadaval mudelina $arg1';
  }

  @override
  String get availableAgainShortly => 'Varsti taas saadaval';

  @override
  String get availableInTheDesktopAppFor =>
      'Saadaval macOS-i, Windowsi ja Linuxi töölauarakenduses';

  @override
  String get availableToTheAgent => 'Saadaval agendile';

  @override
  String get averageAllTime => 'Keskmine, kogu aeg';

  @override
  String get avgImp => 'Keskm. näit.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Keskmine/jooks: $arg1 märgid';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Vältige korduvaid märke ja ilmseid jadasid.';

  @override
  String get awaitingScan => 'Ootab skannimist';

  @override
  String get back => 'Tagasi';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count taustal';
  }

  @override
  String get backgroundTasks => 'Taustaülesanded';

  @override
  String get backOn => 'tagasi.';

  @override
  String get backToChat => 'Tagasi vestlusesse';

  @override
  String get backToFolder => 'Tagasi kausta';

  @override
  String get backToSignIn => 'Tagasi sisselogimiseks';

  @override
  String get backendChannel => 'Taustakanal';

  @override
  String get backendOnThisComputer => 'Selle arvuti taustaprogramm';

  @override
  String get backendSync => 'Taustaprogrammi sünkroonimine';

  @override
  String get backgroundLocationNeeded => 'Vajalik asukoht taustal';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Taustal sünkroonimine jääb Androidis ajakavasse';

  @override
  String get badState => 'Halb olek: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Töötavate QEMU virtuaalmasinate põhipilt ja suurus ';

  @override
  String get baseUrlOptional => 'Baas-URL (valikuline)';

  @override
  String get baseUrlTokenLocal => 'baasi URL-i luba kohalik';

  @override
  String get basicAuthentication => 'Põhiline autentimine';

  @override
  String get behaviorModules => 'Käitumise moodulid';

  @override
  String get behaviorNotes => 'käitumismärkmed';

  @override
  String get beta => 'Beeta';

  @override
  String get bitwardenCredentialBroker => 'Bitwardeni mandaadi vahendaja';

  @override
  String get bitwardenItem => 'Bitwardeni üksus';

  @override
  String get bitwardenServer => 'Bitwardeni server';

  @override
  String get blankUsesCommon => 'Tühi kasutab sõna \"tavaline\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Tühi kasutab vaikimisi tagasihelistamist';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Tühjad väärtused kasutavad pakkuja vaikeväärtusi.';

  @override
  String get block => 'Blokeeri';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Blokeeritud sissetulev sõnum $arg1-lt.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubblesiga ühilduv sild';

  @override
  String get bluebubblesServerUrl => 'BlueBubblesi serveri URL';

  @override
  String get botToken => 'Boti märk';

  @override
  String get botTokenAndApprovedChats =>
      'Boti tunnus ja heakskiidetud vestlused';

  @override
  String get botTokenAndServerChannelAccess =>
      'Boti tunnus ja juurdepääs serverile/kanalile';

  @override
  String get botTokenEventsApiAndChannel =>
      'Boti tunnus, sündmuste API ja juurdepääs kanalile';

  @override
  String get botUserId => 'Boti kasutaja ID';

  @override
  String get botUsername => 'Boti kasutajanimi';

  @override
  String get brandName => 'Kaubamärgi nimi';

  @override
  String get braveSearch => 'Julge otsing';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Ühendage kõik pakkujad, kes saavad veebihaagi kasulikke koormusi postitada ja vastu võtta.';

  @override
  String get bringYourOwnKey => 'kaasa oma võti';

  @override
  String get bringYourOwnKey2 => 'Kaasa oma võti';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Brauser, Linuxi töölaud, failid, terminal ja Python jagavad ühte püsivat pilvearvutit.';

  @override
  String get browserLogin => 'Brauseri sisselogimine';

  @override
  String get browserScripting => 'Brauseri skriptimine';

  @override
  String get call => 'Helista';

  @override
  String get callAgent => 'Helista agentuurile';

  @override
  String get callUser => 'Helista kasutajale';

  @override
  String get calledByName => 'Nimepidi kutsutud';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Saab delegeerida ülesandeid teistele agentidele';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Saab delegeerida $arg1-le';
  }

  @override
  String get canReceiveDelegatedTasks =>
      'Saab vastu võtta delegeeritud ülesandeid';

  @override
  String get cancel => 'Tühista';

  @override
  String get cancelTask => 'Tühista ülesanne';

  @override
  String get cannotPreview => 'Eelvaadet ei saa vaadata';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ei saa delegeeritud ülesandeid vastu võtta';

  @override
  String get cannotRunYet => 'ei saa veel joosta.';

  @override
  String get capturedThePage => 'Jäädvustas lehe';

  @override
  String get category => 'Kategooria';

  @override
  String chainArg1(Object? arg1) {
    return 'Kett: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Muutke seadistusrežiimi';

  @override
  String get channel => 'Kanal';

  @override
  String get channelAccessToken => 'Kanali juurdepääsuluba';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Värskendatud versioon: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Kanali ulatusega sotsiaalne mälu';

  @override
  String get channels => 'Kanalid';

  @override
  String get chat => 'Vestlus';

  @override
  String get chatId => 'Vestluse ID';

  @override
  String get chatMode => 'Vestlusrežiim';

  @override
  String get chatModel => 'Vestlusmudel';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Kontrollige käivitamisel automaatselt';

  @override
  String get checkForMessagesEveryMs => 'Kontrollige sõnumeid iga (ms) järel';

  @override
  String get checkForNewMessagesAutomatically =>
      'Otsige automaatselt uusi sõnumeid';

  @override
  String get checkNow => 'Kontrollige kohe';

  @override
  String get checkYourEmailToConfirmYour =>
      'Enne sisselogimist kontrollige oma e-posti, et kinnitada oma NeoAgenti konto.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Kontrollitud $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Valige kategooria või otsige kõigist seadetest.';

  @override
  String get chooseAPerson => 'Valige inimene';

  @override
  String get chooseAProjectFolder => 'Valige projekti kaust';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Valige vestluse, agentide, varukäitumise ja nutika marsruutimise vaikeseaded.';

  @override
  String get chooseGroups => 'Valige rühmad';

  @override
  String get chooseHowMuchYouWantTo =>
      'Valige, kui palju soovite praegu konfigureerida. Mõlemat valikut saab hiljem muuta.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Valige, kuidas see ülesanne peaks algama. Käsitsi töötab ainult Run Now. Ajakava on ajapõhine. Integreerimine käivitab ühendatud ametlikest rakendustest tulekahju.';

  @override
  String get chooseOneToGetStartedNow =>
      'Kohe alustamiseks valige üks. Saate hiljem lisada.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Valige seadetes reaalajas mudel ja hääl.';

  @override
  String get chooseTheirGroup => 'Valige nende rühm';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Valige, kus sellel inimesel peaks olema lubatud $arg1-ga rääkida. Saate seda hiljem muuta jaotises Kes saavad sõnumeid saata.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Valige, milliste rühmadega $arg1 peaks liituma isegi siis, kui keegi seda ei märgi. See platvorm ei pruugi silte tavalistest sõnumitest eristada.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Valige, milliseid mudeleid iga selle serveri konto saab valida ja ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Valige, kellega $arg1 räägib ja millal see grupivestlustega liitub.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Valige, kes saavad ühendust võtta $arg1-ga, ja seejärel salvestage muudatused.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Valige, kes võib agendile WhatsAppi kaardil sõnumit saata: \"Kes saab sõnumit saata\".';

  @override
  String get chooseYourDefaultModel => 'Valige\nvaikemudel.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, failid, tekstiredaktor ja terminal on kõik saadaval Linuxi töölaualt.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Tühjenda';

  @override
  String get clearAll => 'Tühjenda kõik';

  @override
  String clearArg1(Object? arg1) {
    return 'Selge $arg1?';
  }

  @override
  String get clearFilter => 'Selge filter';

  @override
  String get clearFilters => 'Selge filtrid';

  @override
  String get clearSearch => 'Tühjenda otsing';

  @override
  String get clearView => 'Selge vaade';

  @override
  String get cliSession => 'CLI seanss';

  @override
  String get clickIsNotSupportedOnThis =>
      'sellel platvormil klikki ei toetata.';

  @override
  String get clickOnceToBeginCapturing =>
      'Jäädvustamise alustamiseks klõpsake üks kord';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klõpsake, tippige ja kasutage töölauarakendusi.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Klõpsatud ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Klõpsatud brauseris';

  @override
  String get clientId => 'Kliendi ID';

  @override
  String get clientSecret => 'Kliendi saladus';

  @override
  String get close => 'Sule';

  @override
  String get closeJ => 'Sule (⌘J)';

  @override
  String get closeTeachMode => 'Sulgege õpetamisrežiim';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Akna sulgemine võib hoida NeoAgenti taustal töötamas koos salve juurdepääsuga või sulgeda täielikult töölaua käitusaja.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Toetatakse pilve- ja isehostitud eksemplare. Kohaliku ja privaatvõrgu URL-id töötavad siis, kui NeoAgent saab nendega ühendust võtta.';

  @override
  String get cloudComputer => 'Pilvearvuti';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Pilvearvuti · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Pilvearvuti seaded on salvestatud. Nende rakendamiseks taaskäivitage server.';

  @override
  String get cloudComputerVm => 'Pilvearvuti (VM)';

  @override
  String get cloudComputers => 'Pilvearvutid';

  @override
  String get codeHosting => 'Koodi hostimine';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Komaga eraldatud kanalite nimed ilma #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Komaga eraldatud, näiteks #üldine, #abi';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Komaga eraldatud. Probleem peab hõlmama neid kõiki.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Käsk nurjus ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Käsk on vajalik.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Käsuväljundi akumulaator ei ole aktiivne.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Käsu väljundi üleslaadimine ebaõnnestus ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Käsu väljundi üleslaadimise artefakti metaandmed on välja jäetud.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Käsu väljund oli juba lõpetatud.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Käsud ja rakendused';

  @override
  String get commandsRunInTheSamePersistent =>
      'Käsud töötavad samas püsivas arvutis, mida kasutab nähtav töölaud.';

  @override
  String get communityChatops => 'Kogukond ja ChatOps';

  @override
  String get completeSetup => 'Täielik seadistamine';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Viige töövoog töölaual lõpule.';

  @override
  String get completed => 'Lõpetatud';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Täielikult blokeeritud – agent ei saa seda kategooriat kasutada.';

  @override
  String get computerShell => 'Arvuti kest';

  @override
  String get computerUsedByThisSession => 'Sellel seansil kasutatav arvuti';

  @override
  String get computerWorkspace => 'Arvuti tööruum';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigureeritav isiklik veebihaagi sild';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigureeritav relee või veebihaagi sild';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigureeritav Talk veebihaagi sild';

  @override
  String get configurableWebInboxBridge =>
      'Konfigureeritav veebipostkasti sild';

  @override
  String get configurableWebhookBridge => 'Konfigureeritav veebihaagi sild';

  @override
  String get configurableWebhooks => 'Konfigureeritavad veebihaagid';

  @override
  String get configurationOrInTheEnvFile =>
      'konfiguratsioonis või .env-failis.';

  @override
  String get configure => 'Seadistage';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigureerige tööruumi käitumist ja mudeli vaikeseadeid.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigureeritud $arg1';
  }

  @override
  String get confirmEmailChanges => 'Kinnitage e-posti muudatused';

  @override
  String get confirmNewSignUps => 'Kinnitage uued registreerumised';

  @override
  String get confirmPassword => 'Kinnitage parool';

  @override
  String get confirmPassword2 => 'Kinnitage parool';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Enne sisselogimist kinnitage oma e-post. Kontrollige NeoAgenti teenuse meilisõnumit.';

  @override
  String get connect => 'Ühendage';

  @override
  String get connectAMessagingPlatform => 'Ühendage\nsõnumsideplatvorm.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Ühendage avalik HTTPS-i koduabilise lõpp-punkt pikaajalise juurdepääsumärgiga. Server blokeerib kohaliku võrgu, tagasisilmuse ja privaatvõrgu aadressid.';

  @override
  String get connectAccount => 'Ühendage konto';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Ühendage rakenduste kontod eraldi, et tehisintellekt saaks kasutada iga ametliku integratsiooni jaoks õiget kontot.';

  @override
  String connectArg1(Object? arg1) {
    return 'Ühendage $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Ühendage nii palju kontosid, kui soovite. Iga rakendus saab kasutada erinevat kontot.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Ühendage kanalid, valige, kellega $arg1 räägib, ja vaadake hiljutist tegevust.';
  }

  @override
  String get connectInstance => 'Ühenda eksemplar';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Konto valimiseks ühendage esmalt see integratsioon.';

  @override
  String get connectToThisServer => 'Ühendage selle serveriga';

  @override
  String get connectWhatsapp => 'Ühendage WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Ühendage oma Nextcloudi eksemplar, sealhulgas isehostitavad serverid. NeoAgent avab Nextcloudi enda sisselogimislehe, et saaksite sisse logida parooli, SSO või 2FA-ga.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Ühendage oma hostitud NeoRecalli server. NeoAgent saab pärast OAuthi ekraani kinnitamist kirjutuskaitstud juurdepääsu kohalikule otsingule, mälestustele ja ärakirja tõenditele.';

  @override
  String get connected => 'Ühendatud';

  @override
  String get connectedAccount => 'Ühendatud konto';

  @override
  String connectedArg1(Object? arg1) {
    return 'Ühendatud $arg1';
  }

  @override
  String get connectedInstance => 'Ühendatud eksemplar';

  @override
  String get connectedNeorecallUser => 'Ühendatud NeoRecalli kasutaja';

  @override
  String get connectedNextcloudUser => 'Ühendatud Nextcloudi kasutaja';

  @override
  String get connectedServer => 'Ühendatud server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Ühenduse loomine reaalajas häälemudeliga...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Ühendus #$arg1';
  }

  @override
  String get connectionId => 'Ühenduse ID';

  @override
  String get connectionLooksGood => 'Ühendus näeb hea välja.';

  @override
  String get connectionMethod => 'Ühendusmeetod';

  @override
  String get containsTextOptional => 'Sisaldab teksti (valikuline)';

  @override
  String get content => 'Sisu';

  @override
  String get contentSecurityPolicy => 'sisu turvapoliitika';

  @override
  String get continue2 => 'Jätka';

  @override
  String get continueFullSetup => 'Jätkake täielikku seadistamist';

  @override
  String get continueRun => 'Jätka jooksmist';

  @override
  String get continueToSetup => 'Jätkake seadistamisega';

  @override
  String get controlSurface => 'JUHTpind';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Juhib juurdepääsu $arg1 tööriistadele.';
  }

  @override
  String get conversation => 'Vestlus';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Vestluse ID, mida kasutatakse, kui see agent vestlust alustab.';

  @override
  String get cookieSetup => 'Küpsiste seadistamine';

  @override
  String get cookiesNotConfigured => 'Küpsiseid pole konfigureeritud';

  @override
  String get copiedAsCsv => 'Kopeeritud CSV-vormingus';

  @override
  String get copiedDebugInfo => 'Silumisinfo kopeeritud';

  @override
  String get copiedExportForTheLast5 =>
      'Viimase 5 sõnumi eksportimine on kopeeritud';

  @override
  String get copiedFullPrompt => 'Täielik viip kopeeritud';

  @override
  String get copiedLogs => 'Kopeeritud logid';

  @override
  String get copiedRunId => 'Kopeeritud käitamise ID';

  @override
  String get copy => 'Kopeeri';

  @override
  String get copyAll => 'Kopeeri kõik';

  @override
  String get copyCodes => 'Kopeeri koodid';

  @override
  String get copyCsv => 'Kopeerige CSV';

  @override
  String get copyDebugInfo => 'Kopeeri silumisinfo';

  @override
  String get copyLink => 'Kopeeri link';

  @override
  String get copyLogs => 'Kopeeri logid';

  @override
  String get copyPrompt => 'Kopeeri viip';

  @override
  String get copyResponse => 'Kopeeri vastus';

  @override
  String get copyRunId => 'Kopeeri käitamise ID';

  @override
  String get copyWebhookUrl => 'Kopeeri veebihaagi URL';

  @override
  String get core => 'Tuum';

  @override
  String get coreMemory => 'põhimälu';

  @override
  String get coreServicesThisServerDependsOn =>
      'Põhiteenused, millest see server sõltub.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domeeni https avaliku URL-i päritolu';

  @override
  String get couldHelp => 'Võiks aidata';

  @override
  String get couldNotApproveQrLogin =>
      'QR-sisselogimist ei saanud heaks kiita.';

  @override
  String get couldNotApproveQrPairing =>
      'QR-koodi sidumist ei saanud heaks kiita.';

  @override
  String get couldNotConnect => 'Ühendust ei õnnestunud luua.';

  @override
  String get couldNotCreateBinding => 'Köitmist ei saanud luua.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Teie kontot ei saanud kustutada: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Bitwardeni ühendust ei saanud lahti ühendada.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Koduabilist ei saanud lahti ühendada.';

  @override
  String get couldNotDisconnectNeorecall =>
      'NeoRecalli ühendust ei saanud lahti ühendada.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Nextcloudiga ei saanud ühendust katkestada.';

  @override
  String get couldNotDisconnectTrello => 'Trellot ei saanud lahti ühendada.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Teie andmeid ei saanud eksportida: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Otsuseid ei saanud laadida';

  @override
  String get couldNotLoadUsageData => 'Kasutusandmeid ei saanud laadida.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Linuxi seadeid ei saanud automaatselt avada.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Pakkuja linkimislehte ei saanud avada.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Teenusepakkuja sisselogimislehte ei saanud avada.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Väljalaskevara ei saanud avada.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Trellot ei saanud teie brauseris avada.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Tööruumi faili allalaadimist ei saanud avada.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Androidi rakenduse paketti ei õnnestunud lugeda.';

  @override
  String get couldNotReadTheApk => 'APK-d ei õnnestunud lugeda.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Võtit ei saanud eemaldada: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agenti ei õnnestunud salvestada.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Bitwardeni seadistust ei saanud salvestada.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Koduabilise seadistust ei saanud salvestada.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'NeoRecalli seadistust ei saanud salvestada.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nextcloudi seadistust ei saanud salvestada.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Trello seadistust ei saanud salvestada.';

  @override
  String get couldNotSendConfirmationEmail => 'ei saanud kinnitusmeili saata';

  @override
  String get couldNotStart => 'Ei saanud käivitada';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Loo';

  @override
  String get createAPasswordFirstToChange =>
      'Konto e-posti aadressi muutmiseks looge esmalt parool.';

  @override
  String get createAPasswordOrLinkAnother =>
      'enne selle sisselogimismeetodi eemaldamist looge parool või linkige teine pakkuja';

  @override
  String get createATaskWhileThisAgent =>
      'Looge ülesanne, kuni see agent on valitud.';

  @override
  String get createLink => 'Loo link';

  @override
  String get createOrModifyFilesInYour =>
      'Looge või muutke oma tööruumis faile.';

  @override
  String get createPassword => 'Loo parool';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Looge spetsiaalseid roboteid eraldi mälu, seadete, tööriistade ja kontoülesannetega.';

  @override
  String get createTheFirstAccount => 'Looge esimene konto';

  @override
  String get createUpdateOrDeleteSkills =>
      'Oskuste loomine, värskendamine või kustutamine.';

  @override
  String get creatingYourSkill => 'Oma oskuste loomine…';

  @override
  String get credentialBindings => 'Volikirjade sidumine';

  @override
  String get credentialUse => 'Mandaadi kasutamine';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron-põhised korduvad käitused ja ühekordne ajastatud täitmine.';

  @override
  String get cronExpression => 'Croni väljend';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter käivitab päringu.';

  @override
  String get ctrlShiftSpace => 'Ctrl + tõstuklahv + tühik';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Praegune e-post: $arg1';
  }

  @override
  String get currentPassword => 'Praegune parool';

  @override
  String get currentPasswordIsIncorrect => 'praegune parool on vale';

  @override
  String get currentTwoStepLoginCode =>
      'Praegune kaheastmeline sisselogimiskood';

  @override
  String get customAccess => 'Kohandatud juurdepääs';

  @override
  String get customCron => 'Kohandatud Cron';

  @override
  String get customCronMustHave5Fields =>
      'Kohandatud Cronil peab olema 5 välja.';

  @override
  String get customEndpoint => 'kohandatud lõpp-punkt';

  @override
  String get customField => 'Kohandatud väli';

  @override
  String get customHeader => 'Kohandatud päis';

  @override
  String get customHeadersJson => 'Kohandatud päised (JSON)';

  @override
  String get customOpenaiCompatible => 'Kohandatud OpenAI-ga ühilduv';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Kohandatud OpenAI-ga ühilduv lõpp-punkt';

  @override
  String get customOutgoingUrl => 'Kohandatud väljaminev URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Igapäevane';

  @override
  String get dailyRecap => 'Igapäevane kokkuvõte';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'andmebaasi päring vali csv-mallid';

  @override
  String dayArg1(Object? arg1) {
    return 'Päev $arg1';
  }

  @override
  String get dayOfMonth => 'Kuu päev';

  @override
  String get decideWhichToolsYourAgentMay =>
      'otsustada, milliseid tööriistu teie agent kasutada võib. Nad näevad teie nime ja ';

  @override
  String get decisionHigherUpTheChainWins =>
      'otsus kõrgemal võidab kett ja näitab lukku ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Otsused kuvatakse siin, kuna $arg1 loeb heakskiidetud $arg2 rühmi. Säilitatakse ainult 30 viimast ja need lähtestatakse serveri taaskäivitamisel.';
  }

  @override
  String get decline => 'Keeldumine';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'sügavjooks · samm $arg1';
  }

  @override
  String get deepgramKey => 'Deepgrami võti';

  @override
  String get default2 => 'Vaikimisi';

  @override
  String get default3 => 'VAIKESÄTE';

  @override
  String defaultArg1(Object? arg1) {
    return 'Vaikimisi ($arg1)';
  }

  @override
  String get defaultConversation => 'Vaikevestlus';

  @override
  String get defaultForNewGroups => 'Uute rühmade jaoks vaikimisi';

  @override
  String get defaultGroupParticipation => 'Vaikimisi grupis osalemine';

  @override
  String get defaultNeoagentWorkspace => 'NeoAgenti vaiketööruum';

  @override
  String get defaultOpenai => 'Vaikimisi (OpenAI)';

  @override
  String get defaultRateLimits => 'Vaikimisi intressipiirangud';

  @override
  String get defaultRateLimitsSaved =>
      'Vaikimisi kiiruspiirangud on salvestatud.';

  @override
  String get defaultRecommended => 'Vaikimisi (soovitatav)';

  @override
  String get defaultRouting => 'Vaikemarsruutimine';

  @override
  String get defaultSpace => 'Vaikeruum';

  @override
  String get delete => 'Kustuta';

  @override
  String get deleteAccount => 'Kustuta konto';

  @override
  String get deleteAccountPermanently => 'Kas kustutada konto jäädavalt?';

  @override
  String get deleteAnAccount => 'Kustuta konto';

  @override
  String deleteArg1(Object? arg1) {
    return 'Kas kustutada @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Kustuta ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Kas kustutada $arg1 $arg2 jäädavalt?';
  }

  @override
  String get deleteBinding => 'Kustuta sidumine';

  @override
  String get deleteCoreMemoryEntry => 'Kas kustutada põhimälu kirje?';

  @override
  String get deleteForever => 'Kustuta igaveseks';

  @override
  String get deleteMcpServer => 'Kas kustutada MCP-server?';

  @override
  String get deleteMemory => 'Kas kustutada mälu?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Kustuta kustutab jäädavalt konto ja kõik selle andmed ';

  @override
  String get deleteRun => 'Kas kustutada jooks?';

  @override
  String get deleteRun2 => 'Kustuta jooks';

  @override
  String get deleteSelectedMemories => 'Kas kustutada valitud mälestused?';

  @override
  String get deleteSession => 'Kas kustutada seanss?';

  @override
  String get deleteSkill => 'Kas kustutada oskus?';

  @override
  String get deleteTask => 'Kas kustutada ülesanne?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Kustutatud \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Kustutatud @$arg1 ja kõik nende andmed.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Kustutamine eemaldab kõik teie vestlused, mälestused, failid, ülesanded ja ';

  @override
  String get deliverableArtifactProduced => 'Toodetud tarnitav artefakt';

  @override
  String get deliverableCompleted => 'Tarnitav lõpetatud';

  @override
  String get deliverableExecutionStarted => 'Algas tarnitav täitmine';

  @override
  String get deliverableSelected => 'Tarnitav valitud';

  @override
  String get deliverableValidationFailed =>
      'Tarnitav valideerimine ebaõnnestus';

  @override
  String get deliverableValidationStarted => 'Tarnitava valideerimine algas';

  @override
  String get deny => 'Keela';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Kirjeldage tulemust ja seejärel näidake seda töölaual';

  @override
  String get describeWhatToBuildOrChange =>
      'Kirjeldage, mida ehitada või muuta…';

  @override
  String get description => 'Kirjeldus';

  @override
  String get desktopApp => 'Töölauarakendus';

  @override
  String get desktopAppControlsAvailable =>
      'Saadaval on töölauarakenduse juhtnupud';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Töölaua jäädvustamine pole sellel platvormil saadaval.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Töölauakäsu väljundi üleslaadimine tühistati.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Töölaua kaaslase käsk tühistati.';

  @override
  String get desktopCompanionConnectionTimedOut => 'Töölaua kaasühendus aegus.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Töölaua kaaslase käepigistus aegus.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Töölauakaaslane pole siin saadaval.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Töölauakaaslane on kohalikult peatatud.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Töölaua kaassõnumite käsitlemine ebaõnnestus: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Töölaua kaaslase lubade seaded pole veebis saadaval.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Töölaua kaaslase lubade seaded pole sellel platvormil saadaval.';

  @override
  String get desktopCompanionRejected => 'Töölauakaaslane lükati tagasi.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Töölaua kaaslase vastus nurjus: $arg1';
  }

  @override
  String get desktopControl => 'Töölaua juhtimine';

  @override
  String get desktopFailedToStart => 'Töölaua käivitamine ebaõnnestus';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Töölaua voo hõivamine ebaõnnestus: $arg1';
  }

  @override
  String get destinationId => 'Sihtkoha ID';

  @override
  String get deviceAccess => 'Seadme juurdepääs';

  @override
  String get deviceSettings => 'Seadme sätted';

  @override
  String get devices => 'Seadmed';

  @override
  String get diagnosticsSaved => 'Diagnostika salvestatud.';

  @override
  String get directBluebubblesImessageBridge =>
      'Otsene BlueBubbles iMessage\'i sild';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Otsesõnumid jäävad reageerivaks. Lubatud rühmad kasutavad allolevat osalemisrežiimi.';

  @override
  String get directoryDoesNotExist => 'Kataloogi pole olemas.';

  @override
  String get disable2fa => 'Keela 2FA';

  @override
  String get disableAll => 'Keela kõik';

  @override
  String get discard => 'Visake ära';

  @override
  String get disconnect => 'Katkesta ühendus';

  @override
  String get disconnectHomeAssistant => 'Kas katkestada koduabilise ühendus?';

  @override
  String get disconnectNeorecall => 'Kas katkestada NeoRecalli ühendus?';

  @override
  String get disconnectNextcloud => 'Kas katkestada Nextcloudi ühendus?';

  @override
  String get disconnectPlatform => 'Ühendage platvorm lahti';

  @override
  String get disconnectTrello => 'Kas katkestada Trello ühendus?';

  @override
  String get discoveryFailed => 'Avastamine ebaõnnestus';

  @override
  String get dismiss => 'Loobu';

  @override
  String get displayIdIsRequired => 'Kuva ID on nõutav.';

  @override
  String get displayName => 'Kuvatav nimi';

  @override
  String get displayNameMustBe64Characters =>
      'Kuvatav nimi peab olema 64 tähemärki või vähem.';

  @override
  String get displayNameSaved => 'Kuvanimi salvestatud.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Ärge lisage oma kasutajanime ega e-posti aadressi.';

  @override
  String get done => 'Valmis';

  @override
  String get downloadACopyOfYourData =>
      'Laadige alla oma andmete koopia. Administraatorikontosid ei saa kustutada ';

  @override
  String get downloadACopyOfYourData2 =>
      'Laadige alla oma andmete koopia või kustutage oma konto jäädavalt. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Laadige alla $arg1';
  }

  @override
  String get downloadUpdate => 'Laadige värskendus alla';

  @override
  String get downloadingTheNeoagentBackend =>
      'NeoAgenti taustaprogrammi allalaadimine';

  @override
  String get draft => 'Mustand';

  @override
  String get dragIsNotSupportedOnThis =>
      'lohistamist sellel platvormil ei toetata.';

  @override
  String get draggedOnTheScreen => 'Lohistatakse ekraanil';

  @override
  String get dropAnApkOrApkBundle =>
      'Pukseerige APK või APK pakett selle installimiseks siia';

  @override
  String get dropApkOrApksHere => 'Pukseerige APK või .apks siia';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Vastupidavad juhised hääle ja suhtlusstiili jaoks. Ohutus- ja teostusreeglid on endiselt prioriteetsed.';

  @override
  String get eGAlexSLaptop => 'nt. Alexi sülearvuti';

  @override
  String get eGMyLocalServer => 'nt. Minu kohalik server';

  @override
  String get edit => 'Muuda';

  @override
  String get editAgent => 'Redigeeri agenti';

  @override
  String get editCoreMemoryEntry => 'Redigeeri põhimälu kirjet';

  @override
  String get editInstructions => 'Muutke juhiseid';

  @override
  String get editMcpServer => 'Redigeeri MCP-serverit';

  @override
  String get editTask => 'Redigeeri ülesannet';

  @override
  String editedArg1(Object? arg1) {
    return 'Redigeeritud $arg1';
  }

  @override
  String get email => 'Meil';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Saatke kontoomanikele meilisõnum sisselogimistest, mis näivad ebatavalised.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Saatke konto omanikele meilisõnum, kui nende konto üksikasjad muutuvad.';

  @override
  String get emailCode => 'E-posti kood';

  @override
  String get emailConfirmationRequired => 'vaja meili kinnitust';

  @override
  String get emailIsAlreadyInUse => 'email on juba kasutusel';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Meil on salvestatud. Kui kinnitus on vajalik, kontrollige uut aadressi NeoAgenti kinnituslingi jaoks.';

  @override
  String get emailSettingsSaved => 'Meiliseaded on salvestatud.';

  @override
  String get emailUnverified => 'E-post on kinnitamata';

  @override
  String get empty => 'Tühi';

  @override
  String get emptyFile => 'Tühi fail';

  @override
  String get emptyFolder => 'Tühi kaust';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Tühi kasutab serveri vaikeseadet ($arg1).';
  }

  @override
  String get enable2fa => 'Luba 2FA';

  @override
  String get enableAll => 'Luba kõik';

  @override
  String get enableBehaviorModules => 'Luba käitumismoodulid';

  @override
  String get enableOrDisableModels => 'Mudelite lubamine või keelamine';

  @override
  String get enabled => 'Lubatud';

  @override
  String get encryptedPrivateToYourAccount =>
      'Krüpteeritud, teie kontole privaatne';

  @override
  String get end => 'Lõpp';

  @override
  String get endCall => 'Lõpeta kõne';

  @override
  String get endVoiceCall => 'Kas lõpetada häälkõne?';

  @override
  String get endpoint => 'Lõpp-punkt';

  @override
  String get enterAPassword => 'Sisestage parool.';

  @override
  String get enterAUsername => 'Sisestage kasutajanimi.';

  @override
  String get enterAValidEmailAddress => 'Sisestage kehtiv e-posti aadress.';

  @override
  String get enterAnAddressManually => 'Sisestage aadress käsitsi';

  @override
  String get enterAnApiKeyFirst => 'Esmalt sisestage API võti.';

  @override
  String get enterInviteLink => 'Sisestage kutse link';

  @override
  String get enterTheAddressOfANeoagent =>
      'Sisestage NeoAgenti serveri aadress.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Sisestage andmed, mille $arg1 teile andis, et $arg2 saaks sõnumeid saata ja vastu võtta.';
  }

  @override
  String get enterYour2faOrRecoveryCode => 'Sisestage oma 2FA või taastekood.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Sisestage oma praegune parool selle muutmiseks.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'E-posti muudatuste salvestamiseks sisestage oma praegune parool.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Sisestage oma NeoAgenti konto andmed.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Sisestage oma kasutajanimi või konto meiliaadress. NeoAgent saadab lähtestamislingi, kui see vastab kontole.';

  @override
  String get enterYourUsernameOrEmail =>
      'Sisestage oma kasutajanimi või e-posti aadress.';

  @override
  String entityArg1(Object? arg1) {
    return 'Üksus: $arg1';
  }

  @override
  String get environment => 'Keskkond';

  @override
  String get error => 'Viga';

  @override
  String errorArg1(Object? arg1) {
    return '\nviga: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Vead hiljutisest logist, rühmitatud sõnumite järgi.';

  @override
  String get errorsProblemsFailures => 'vead probleemid tõrked';

  @override
  String get eventTypesCommaSeparated =>
      'Sündmuste tüübid (komadega eraldatud)';

  @override
  String get every15Minutes => 'Iga 15 minuti järel';

  @override
  String get every30Minutes => 'Iga 30 minuti järel';

  @override
  String get everyAccountOnThisServerLoses =>
      'Kõik selle serveri kontod kaotavad selle jagatud võtme. Kontod ';

  @override
  String get everyAccountOnThisServerUses =>
      'Iga selle serveri konto kasutab seda aadressi ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Iga selle konto aktiivne seanss lõpeb. Nad saavad sisse logida ';

  @override
  String get everyDay0800 => 'Iga päev · 08:00';

  @override
  String get everyDay2000 => 'Iga päev · 20:00';

  @override
  String get everyHour => 'Iga tund';

  @override
  String get everyRunOnThisServerAll => 'Iga kord selles serveris, kogu aeg.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Iga tundlik tööriist nõuab iga kord heakskiitu.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Iga tööriist töötab ilma küsimata, välja arvatud need, mida inimene ise kasutab ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Kõik nendes rühmades, kanalites või ruumides saavad $arg1-ga rääkida.';
  }

  @override
  String get everyoneInThisGroup => 'Kõik selles grupis';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Kõik, mis $arg1 on teie agendi jaoks välja lülitatud, tuleb ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Kõik muu on välja lülitatud.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Kõik on saadaval töölaualt.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Kõik, mida agent saab kasutada: ametlikud integratsioonid, MCP-serverid ja oskused.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Kõik, mille $arg1 jaoks välja lülitasite, tuleb tagasi ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Täpne veebi päritolu lubab teha ristpäritolu taotlusi, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Käivitage JavaScript oma brauseri seansi sees.';

  @override
  String get execution => 'Täitmine';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Täitmise üksikasjad pole selle jooksu jaoks saadaval.';

  @override
  String get executionPlanCreated => 'Teostusplaan loodud.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Harjutuse $arg1 seansid';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[välju $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Aegub $arg1';
  }

  @override
  String get explainThisProject => 'Selgitage seda projekti';

  @override
  String exploredArg1(Object? arg1) {
    return 'Uuritud $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Uuritud $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Uuris tööruumi';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Eksport ebaõnnestus: $arg1';
  }

  @override
  String get exportLast5Messages => 'Ekspordi viimased 5 sõnumit';

  @override
  String get exportMyData => 'Ekspordi minu andmed';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Välise brauseri käivitamine ebaõnnestus väljumiskoodiga $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Sellel platvormil ei toetata välise brauseri käivitamist.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Välise brauseri käivitamine aegus.';

  @override
  String get externalMcpTools => 'Välised ja MCP-tööriistad';

  @override
  String get extraButtons => 'Lisanupud';

  @override
  String get extractingTheNeoagentRuntime =>
      'NeoAgenti käitusaja ekstraktimine';

  @override
  String get failed => 'Ebaõnnestunud';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Ühendamine ebaõnnestus: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 ühendamine nurjus: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return '\"$arg1\" kustutamine ebaõnnestus: $arg2';
  }

  @override
  String get failedToFetch => 'toomine ebaõnnestus';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Viipa genereerimine nurjus: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Välise brauseri käivitamine url_launcheri kaudu ebaõnnestus.';

  @override
  String get failedToLaunchOauthFlow => 'OAuthi voo käivitamine ebaõnnestus.';

  @override
  String get failedToLoadPolicies => 'Eeskirjade laadimine ebaõnnestus';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Salvestamine ebaõnnestus: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'MCP-serveri salvestamine ebaõnnestus.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Valiku salvestamine ebaõnnestus: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Teatise saatmine taustaprogrammi nurjus: $arg1';
  }

  @override
  String get fair => 'Õiglane';

  @override
  String get fasterReplies => 'Kiiremad vastused';

  @override
  String get fewerModelCalls => 'Vähem modellikõnesid';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'sisseehitatud vaikeväärtuse taastamiseks väli tühi.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Fail ületab redaktori piirangu 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Fail ületab toetatud suuruse piirangu.';

  @override
  String get fileWrites => 'Fail kirjutab';

  @override
  String get filename => 'Failinimi';

  @override
  String get files => 'Failid';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Siin kuvatakse failid, mille NeoAgent sellel seansil kirjutab või muudab.';

  @override
  String get filesSavedByAllUsers => 'Kõigi kasutajate salvestatud failid';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Täitke heakskiidetud sisselogimisi või autentige taotlusi ilma tehisintellektile saladusi näitamata.';

  @override
  String get finalResponse => 'Lõplik vastus';

  @override
  String get findAPlatform => 'Leidke platvorm';

  @override
  String get findAndFixABug => 'Leidke ja parandage viga';

  @override
  String get findRecentChats => 'Otsige üles hiljutised vestlused';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Õige NeoAgenti käitusaja leidmine';

  @override
  String get finish => 'Lõpeta';

  @override
  String get finishAtTheScheduledTime => 'Lõpeta ettenähtud ajal';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Lõpetage oma brauseris $arg1-sse sisselogimine ja seejärel ühendage uuesti.';
  }

  @override
  String get flowGraph => 'Voolugraafik';

  @override
  String get flutterApp => 'Flutter rakendus';

  @override
  String get focusedExecutionProfile => 'Fokuseeritud täitmise profiil';

  @override
  String get folderIdOptional => 'Kausta ID (valikuline)';

  @override
  String get folderUnavailable => 'Kaust pole saadaval';

  @override
  String get forExampleHttpsMatrixOrg => 'Näiteks https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Hostitud või täiustatud võrgu seadistuste jaoks';

  @override
  String get forLinksInEmailsBlankUses =>
      'Meilides olevate linkide jaoks. Tühi kasutab serveri avalikku URL-i.';

  @override
  String get forgotPassword => 'Unustasid parooli?';

  @override
  String get frameUnavailable => 'Raam pole saadaval';

  @override
  String freshnessArg1(Object? arg1) {
    return 'värskus: $arg1';
  }

  @override
  String get fridays1700 => 'Reedeti · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'BotFatherilt pärast roboti loomist.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Nüüdsest otsustab $arg1, milliseid tööriistu teie agent kasutada võib. Nad ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Discordi arendajaportaalist teie roboti alt.';

  @override
  String get fromTheLineDevelopersConsole => 'LINE Developers Console\'ist.';

  @override
  String get fromTheMatrixClientOrBot => 'Matrixi kliendi või roboti kontolt.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Saidilt twitchapps.com/tmi või teie Twitchi arendajarakendusest.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Täielik viip';

  @override
  String get fullSetup => 'Täielik seadistamine';

  @override
  String get general => 'Kindral';

  @override
  String get generalSettings => 'Üldseaded';

  @override
  String get generalSettingsSaved => 'Üldseaded salvestatud.';

  @override
  String get generateAPromptForAnotherAi =>
      'Looge teise AI jaoks viip, kleepige vastus mälestuste importimiseks siia.';

  @override
  String get generatePrompt => 'Loo viip';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geofence tracking error: $arg1';
  }

  @override
  String get getInspired => 'Saa inspiratsiooni';

  @override
  String get githubCopilot => 'GitHubi kopiloot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot ja OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHubi probleem on avatud';

  @override
  String get neorecallMemoryCreated => 'NeoRecalli mälu loodud';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'GitHubi väljalaskekontroll ebaõnnestus HTTP $arg1-ga.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'GitHubi väljalaskekoormus ei olnud väljalaskeloend.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHubi kasutajanimi, mis probleemi avas';

  @override
  String get globalSecurityMode => 'Globaalne turvarežiim';

  @override
  String get gmailMessageReceived => 'Gmaili sõnum vastu võetud';

  @override
  String get good => 'Hea';

  @override
  String get goodAfternoon => 'Tere pärastlõunast';

  @override
  String get goodEvening => 'Tere õhtust';

  @override
  String get goodMorning => 'Tere hommikust';

  @override
  String get goodPasswordALittleMoreLength =>
      'Hea parool. Veidi pikem pikkus muudab selle tugevamaks.';

  @override
  String get googleChat => 'Google\'i vestlus';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live kasutab teie OpenAI API võtit ja Gemini Live teie Google AI võtit. Muudatused rakenduvad järgmisele kõnele.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Andke enne sünkroonimist Health Connecti load.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupp, kanal või ruum';

  @override
  String get groupType => 'Grupi tüüp';

  @override
  String get groupsAndChannels => 'Grupid ja kanalid';

  @override
  String groupsArg1(Object? arg1) {
    return 'Rühmad: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupid $arg1, mida pole veel näinud, järgivad seda.';
  }

  @override
  String get handlesDirectTasksItself =>
      'Otseste ülesannetega saab ise hakkama';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Käed-vabad (rääkige vabalt, katkestage igal ajal)';

  @override
  String get headerName => 'Päise nimi';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Pealkirjad teile olulistel teemadel, filtreeritud signaali saamiseks.';

  @override
  String get health => 'Tervis';

  @override
  String get healthChecks => 'Tervisekontrollid';

  @override
  String get healthConnect => 'tervis ühendada';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect pole selles seadmes saadaval.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health Connecti sünkroonimise olek ja salvestatud taustamõõdikud.';

  @override
  String get healthStatusIsUnavailable => 'Tervislik seisund pole saadaval.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Tervise sünkroonimine on saadaval ainult Androidis.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Südame $arg1 rekordid';
  }

  @override
  String get heldBack => 'Hoidis tagasi';

  @override
  String get helper => 'Abimees';

  @override
  String helperArg1(Object? arg1) {
    return 'Abimees: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'siin. Tühista administraator esmalt käsuga „neoagendi admin tühista $arg1”.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Kõrgemad väärtused muudavad NeoAgent rühmades selektiivsemaks.';

  @override
  String get highlyRecommended => 'Väga soovitatav';

  @override
  String get holdButton131ForTheAssistant =>
      'Hoidke abilise jaoks all nuppu 131.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Rääkimiseks hoidke all klahvikombinatsiooni Ctrl+Shift+Tühik';

  @override
  String get holdToTalk => 'Hoidke, et rääkida.';

  @override
  String get holdToTalk2 => 'Hoidke, et rääkida';

  @override
  String get home => 'Kodu';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Vaja on koduabilise pikaealist juurdepääsuluba.';

  @override
  String get homeAssistantSetup => 'Koduabilise seadistamine';

  @override
  String get homeAssistantUrl => 'Koduabilise URL';

  @override
  String get homeAssistantUrlIsRequired => 'Koduabilise URL on nõutav.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Koduserveri luba ruumi küsitlusega';

  @override
  String get homeserverUrl => 'Koduserveri URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'hostitud teenus). Teie võtmed on krüpteeritud ja neid saavad kasutada ainult ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'IRC-võrgu hostinimi, näiteks irc.libera.chat';

  @override
  String get hourly => 'Tunni kaupa';

  @override
  String get hourlyInboxCheck => 'Tunnipõhine postkasti kontroll';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Kui kaua kinnituslingid kehtivad.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Kui sageli see agent uusi ruumiteateid otsib.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Kui sageli see agent uusi signaalisõnumeid otsib.';

  @override
  String get howTeamsWork => 'Kuidas meeskonnad töötavad';

  @override
  String get howThisServerIsReachedPlus =>
      'Kuidas selle serverini jõutakse, pluss kogu serveri lülitid.';

  @override
  String get httpsSessionCookie => 'https seansi küpsis';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Ma ei saanud seda taotlust praegu täita. Proovige mõne aja pärast uuesti.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Tühikäik';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Kui $arg1 küsib veebihaagi URL-i, kleepige see, et sõnumid jõuaksid $arg2-i.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Kui sellel kontol on kinnitatud e-kiri, saadab NeoAgent parooli lähtestamise lingi.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Kui teenus nõuab väljaminevate päringute puhul luba.';

  @override
  String get ignoreGroups => 'Ignoreeri rühmi';

  @override
  String get ignoreThisChat => 'Ignoreeri seda vestlust';

  @override
  String get ignoredChannels => 'Ignoreeritud kanalid';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ignoreeriti valesti vormindatud töölaua kaassõnumit: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Rakendage ülaltoodud plaan.';

  @override
  String get implementThisPlan => 'Rakenda see plaan';

  @override
  String get implicitTls => 'Kaudne TLS';

  @override
  String get import => 'Import';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import ebaõnnestus: $arg1';
  }

  @override
  String get importFromComputer => 'Import arvutist';

  @override
  String get importMemoryTransfer => 'Kas importida mäluedastus?';

  @override
  String get importance => 'Tähtsus';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Imporditud $arg1 mälud, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return '@$arg1 meeskonnas';
  }

  @override
  String get inBackground => 'taustal';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Siia kuvatakse sissetulevate ja väljaminevate kanalite teated.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Sissetulevad rakendusesisesed häälkõned NeoAgentilt';

  @override
  String get incomingMessages => 'Sissetulevad sõnumid';

  @override
  String get incomingNeoagentCall => 'Sissetulev NeoAgenti kõne';

  @override
  String get incomingNeoagentCall2 => 'SISSEV NEOAGENTI KÕNE';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Sissetuleva veebihaagi ja väljamineva tagasihelistamise tugi';

  @override
  String get incorporatingSteering => 'Sisaldab roolimist';

  @override
  String get input => 'Sisend';

  @override
  String get inputMode => 'Sisestusrežiim';

  @override
  String get insertATemplate => 'Sisestage mall';

  @override
  String get install => 'Installige';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installige allkirjastatud iseseisev käituskeskkond. Node.js, npm, Git ja terminali käsud pole vajalikud.';

  @override
  String get installApk => 'Installige APK';

  @override
  String get installApkBundle => 'Installige APK / komplekt';

  @override
  String get installApkClickOrDropA =>
      'Installige APK – klõpsake või pukseerige apk-fail';

  @override
  String get installNeoagent => 'Installige NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installige NeoAgent sellesse arvutisse ilma terminalita või ühendage juba töötava terminaliga.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installige uued versioonid ja valige, millist kanalit see server järgib.';

  @override
  String get installTheBackend => 'Installige taustaprogramm';

  @override
  String get installTheCoreWithExtraOptional =>
      'Paigaldage tuum täiendava valikulise seadistusega. AI pakkuja võtmed lisatakse hiljem samamoodi nagu Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installige turvatuum ja looge seejärel oma konto. Seejärel lisage tehisintellekti pakkuja võtmed.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Paigaldatud: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Paigaldatud: $arg1 • Viimati kontrollitud: $arg2';
  }

  @override
  String get instructions => 'Juhised';

  @override
  String get integration => 'Integratsioon';

  @override
  String get integrationConnections => 'Integratsiooniühendused';

  @override
  String get integrationSettingsSaved => 'Integratsiooniseaded on salvestatud.';

  @override
  String get integrations => 'Integratsioonid';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback ja registreerige see sama ';

  @override
  String get interruptAi => 'Katkestage AI';

  @override
  String get invalid2fa => 'kehtetu 2fa';

  @override
  String get invalidArgumentS => 'Vale argument(id): ';

  @override
  String get invalidCredentials => 'kehtetud volikirjad';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Kehtetu NeoAgenti käitusaegne manifest.';

  @override
  String get inviteLink => 'Kutse link';

  @override
  String get inviteLinkReady => 'Kutselink on valmis';

  @override
  String get inviteLinks => 'Kutsuge linke';

  @override
  String get iphoneApp => 'iPhone\'i rakendus';

  @override
  String get issues => 'Probleemid';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Probleemid ilmnevad pärast logi laadimist.';

  @override
  String get itCanTBeUndone => 'Seda ei saa tagasi võtta.';

  @override
  String get itMayHaveBeenDeleted => 'See võib olla kustutatud.';

  @override
  String get javaRuntime => 'java käitusaeg';

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
    return 'Liitus $arg1-ga';
  }

  @override
  String get joinedInTheLast7Days => 'Liitunud viimase 7 päeva jooksul';

  @override
  String get joiningATeam => 'Meeskonnaga liitumine';

  @override
  String get joiningIsOffHere => 'Liitumine on siin välja lülitatud';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON-väli, mis sisaldab sõnumi teksti. Tavaliselt tekst.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON-väli, mis tuvastab, kellele sõnum on mõeldud.';

  @override
  String get jumpToLatest => 'Hüppa uusimale';

  @override
  String get justNow => 'just praegu';

  @override
  String get keepNeoagentRunning => 'Kas hoida NeoAgenti töös?';

  @override
  String get keepRunning => 'Jätka jooksmist';

  @override
  String get keepTaskRunning => 'Jätkake ülesannete täitmist';

  @override
  String get keepTheVaultAvailable => 'Hoidke varahoidla saadaval';

  @override
  String get keepThisLauncherUpToDate =>
      'Hoidke seda käivitusprogrammi ajakohasena.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Hoidke seda paneeli avatuna, kuni platvorm ühenduse kinnitab.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Hoidke selle seansi arvuti nähtavana';

  @override
  String get keepTrackOfYourAiUsage =>
      'Jälgige oma AI kasutamist. Piirangud on kehtestatud, et tagada õiglane kasutamine kogu platvormil.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Jätkake oma rakenduste kasutamist tavapäraselt. NeoAgent töötab samal ekraanil ja küsib alati, kui vajab uut juurdepääsu.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Selle seadme ühendamine';

  @override
  String get key => 'Võti';

  @override
  String get keyIsRequired => 'Võti on nõutav.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Vestlustes püsivad võtme-väärtuste paarid.';

  @override
  String get knowledgeGraph => 'Teadmiste graafik';

  @override
  String get knowledgeView => 'Teadmiste vaade';

  @override
  String get labelOnlyYouSeeIt => 'Silt (seda näete ainult teie)';

  @override
  String get labelsOptional => 'Sildid (valikuline)';

  @override
  String get last24Hours => 'Viimased 24 tundi';

  @override
  String get last7Days => 'Viimased 7 päeva';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Viimased 7 päeva: $arg1 märgid rakenduses $arg2 käivituvad';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Viimane $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Viimane: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Viimane mittetühi sünkroonimine · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Viimane käik: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Viimati nähtud $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Viimane sisselogimine $arg1';
  }

  @override
  String get lastSyncSummary => 'Viimase sünkroonimise kokkuvõte';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Viimati kasutatud: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Viimane aken lõppes $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'hilisem start ka välja lülitatud.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Viimane jooks · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Sellel platvormil ei toetata töölauarakenduste käivitamist.';

  @override
  String get learnRoomNorms => 'Õppige ruuminorme';

  @override
  String get leave => 'Lahku';

  @override
  String get leaveARedirectUriBlankTo =>
      'Kui soovite kasutada <avalikku URL-i>/api/, jätke ümbersuunamise URI tühjaks';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Kas lahkuda $arg1 meeskonnast?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Jätke vaikeseadeks, välja arvatud juhul, kui olete BlueBubblesi kohandanud.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Praegu salvestatud märgi säilitamiseks jätke märk tühjaks.';

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
    return 'Las $arg1 haldab mind';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Laske kõigil selles rühmas $arg1-ga rääkida.';
  }

  @override
  String get letItWorkWhileYouDon => 'Laske sel töötada,\nkuni te seda ei tee.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Laske NeoAgentil klõpsata, tippida ja rakendustes liikuda.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Laske NeoAgentil mõista, mis teie ekraanil on näha.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Laske kellelgi, kellega koos töötate, otsustada, milliseid tööriistu teie agent võib kasutada ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Las see inimene saadab $arg1-le üks-ühele sõnum.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Lubage sellel inimesel siin $arg1-ga rääkida, kuid mitte privaatvestlustes või muudes gruppides.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Lubage sellel inimesel rääkida $arg1-ga privaatvestlustes ja mis tahes grupis, mida ta jagab.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Tase $arg1/$arg2$arg3';
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
  String get linkCopied => 'Link on kopeeritud';

  @override
  String get linkExpiresAfter => 'Link aegub pärast seda';

  @override
  String get linkLifetimeHours => 'Lingi eluiga (tundides)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Lingi eluiga peab olema 1 kuni 8760 tundi.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link kehtib kuni $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Lingitud sisselogimisteenuse pakkujad';

  @override
  String get linuxApp => 'Linuxi rakendus';

  @override
  String listedArg1(Object? arg1) {
    return 'Loendis $arg1/';
  }

  @override
  String get listening => 'Kuulamine';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Reaalajas täitmisajalugu, tööriista sammud ja vastused.';

  @override
  String get liveModel => 'Elav mudel';

  @override
  String get liveModelProvider => 'Reaalajas mudeli pakkuja';

  @override
  String get liveRun => 'Live jooks';

  @override
  String get liveVoice => 'Elav hääl';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Reaalajas häälühendus pole saadaval.';

  @override
  String get liveVoiceConnectionWasClosed => 'Reaalajas kõneühendus suleti.';

  @override
  String get liveVoiceDefaults => 'Reaalajas hääle vaikeseaded';

  @override
  String get liveVoiceFailed => 'Reaalajas hääl ebaõnnestus.';

  @override
  String get llmMemoryExportResponse => 'LLM-mälu ekspordi vastus';

  @override
  String get loadFailed => 'laadimine ebaõnnestus';

  @override
  String get loadingExecutionDetails => 'Täitmise üksikasjade laadimine...';

  @override
  String get loadingNeoagent => 'NeoAgenti laadimine';

  @override
  String get loadingRunFlow => 'Käitusvoo laadimine…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Kohaliku ja privaatvõrgu URL-e toetatakse, kui NeoAgenti server suudab nendega ühendust võtta. Heli ei puutu kunagi NeoAgentiga kokku.';

  @override
  String get localApp => 'kohalik rakendus';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Kohalik taustaprogrammi installimine pole sellel platvormil saadaval.';

  @override
  String get localBaseImagePath => 'Kohaliku baaspildi tee';

  @override
  String get localComputerControlIsAvailableIn =>
      'Kohalik arvutijuhtimine on saadaval MacOS-i, Windowsi ja Linuxi töölauarakenduses NeoAgent.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Kohalik arvutijuhtimine pole siin saadaval.';

  @override
  String get localModelsUrl => 'kohalike mudelite url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Kohalik NeoAgenti avastus pole ajutiselt saadaval.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'NeoAgenti rakenduse kohalikud eelistused. Arvuti juhtimine jookseb alati läbi ühtse pilvarvuti.';

  @override
  String get localSetup => 'KOHALIK SEADISTUS';

  @override
  String get locationCityOrPlace => 'Asukoht (linn või koht)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Ilmasündmuste käivitamiseks on vajalik asukoht';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'LocationService\'i lähtestamine nurjus: $arg1';
  }

  @override
  String get logCopied => 'Logi kopeeritud';

  @override
  String get loginPassword => 'Sisselogimisparool';

  @override
  String get logout => 'Väljalogimine';

  @override
  String get logs => 'Palgid';

  @override
  String get logsCopied => 'Logid kopeeritud.';

  @override
  String get logsOnThisComputer => 'Logib sellesse arvutisse';

  @override
  String get longLivedAccessToken => 'Pikaealine juurdepääsuluba';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Pikaajaline meeldetuletus, struktureeritud faktid ja teadmiste graafik.';

  @override
  String get lookedAtTheScreen => 'Vaatas ekraani';

  @override
  String get lookingOnThisComputerAndYour =>
      'Selle arvuti ja kohaliku võrgu vaatamine…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Vaatab homsetele koosolekutele ette, nii et miski ei üllata teid.';

  @override
  String get loopExecution => 'Loop täitmine';

  @override
  String get loopPaused => 'Silmus peatatud';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS-i juurdepääsetavust NeoAgentile ei võimaldata. Lubage see jaotises Süsteemi seaded › Privaatsus ja turvalisus › Juurdepääsetavus.';

  @override
  String get macosApp => 'macOS-i rakendus';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'MacOS-i ekraanisalvestust ei anta NeoAgentile. Lubage see jaotises Süsteemi seaded › Privaatsus ja turvalisus › Ekraani salvestamine, seejärel avage uuesti NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Parooli vajavad meiliserverid keelduvad saatmast enne uut ';

  @override
  String get main => 'Peamine';

  @override
  String get makeDefault => 'Määra vaikeseadeks';

  @override
  String get manage => 'Halda';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Hallake oma konto meili, kahefaktorilist autentimist ja aktiivseid seansse.';

  @override
  String get managedBy => 'Haldaja';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Juhtidel võivad olla oma juhid (kuni neli taset). A ';

  @override
  String get managing => 'Haldamine';

  @override
  String get manualDestination => 'Käsitsi sihtkoht';

  @override
  String get manualTrigger => 'Käsitsi päästik';

  @override
  String get masterPassword => 'Peaparool';

  @override
  String get matchThisDevice => 'Sobitage see seade';

  @override
  String get matchedAgainstTitleAndBody => 'Ühildub pealkirja ja kehaga';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Ühildub vana NeoAgent MCP vooga: URL pluss autentimismeetod.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP server';

  @override
  String get mcpServer2 => 'MCP server';

  @override
  String get mcpServerUrl => 'MCP serveri URL';

  @override
  String get mcpServers => 'MCP-serverid';

  @override
  String get meantForSomeoneElse => 'Mõeldud kellelegi teisele';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Mõõdetud mudeli maksumus: $arg1';
  }

  @override
  String get memories => 'Mälestused';

  @override
  String get memory => 'Mälu';

  @override
  String memoryArg1(Object? arg1) {
    return 'Mälu: $arg1';
  }

  @override
  String get memoryInjected => 'Mälu süstitud';

  @override
  String get mentionOrReplyOnly => 'Mainige või vastake ainult';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Selle rakenduse seansi jaoks on ühendatud serveri ja Flutteri käitusaja logid.';

  @override
  String get messageBodyTemplateJson => 'Sõnumi kehamall (JSON)';

  @override
  String get messageNeedsAccess => 'Sõnum vajab juurdepääsu';

  @override
  String get messageTextField => 'Sõnumi tekstiväli';

  @override
  String get messaging => 'Sõnumid';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Sõnumside API tõuke- ja veebihaagi sündmused';

  @override
  String get messagingConnectionNeedsAttention =>
      'Sõnumiühendus vajab tähelepanu';

  @override
  String get messagingConnections => 'Sõnumside ühendused';

  @override
  String get messagingDelivery => 'Sõnumite edastamine';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Sõnumside viga. Palun proovi uuesti.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Mikrofoni jäädvustamine katkes ootamatult. Proovi uuesti.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofoni viga: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon vaigistatud. Vaigistuse tühistamiseks puudutage.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Reaalajas hääle jaoks on vaja mikrofoni luba.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimaalne sissemakse väärtus: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobiili seadistamine ebaõnnestus.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobiili seadistamine nurjus, kuna Java pole NeoAgenti kasutavas masinas saadaval.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobiili seadistamine nurjus, kuna Java pole NeoAgenti kasutavas masinas saadaval. Installige JDK ja proovige uuesti.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobiili seadistamine ebaõnnestus. Kontrollige, kas Androidi tööriistad on õigesti installitud, ja proovige uuesti.';

  @override
  String modeArg1(Object? arg1) {
    return 'režiim: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Režiim lukustub, kui jooks on aktiivne.';

  @override
  String get model => 'Mudel';

  @override
  String modelArg1(Object? arg1) {
    return 'Mudel: $arg1';
  }

  @override
  String get modelAvailability => 'Mudeli saadavus';

  @override
  String get modelAvailabilitySaved => 'Mudeli saadavus on salvestatud.';

  @override
  String get modelForThisSession => 'Selle seansi mudel';

  @override
  String get modelOverride => 'Mudeli alistamine';

  @override
  String get modelPending => 'Mudel ootel';

  @override
  String get modelTurn => 'Mudel pööre';

  @override
  String get modelTurnCompleted => 'Mudelpööre lõpetatud';

  @override
  String get modelTurnStarted => 'Mudelpööre algas';

  @override
  String get modelVisibilityHideShowList => 'mudeli nähtavus peida kuvaloend';

  @override
  String get models => 'Mudelid';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Mudelid, käitumine, hääl ja tööruum';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Mudelid, brauser, hääl, diagnostika...';

  @override
  String get modelsRouting => 'Mudelid ja marsruutimine';

  @override
  String get monthly => 'Igakuine';

  @override
  String get moreActions => 'Rohkem toiminguid';

  @override
  String get morningBriefing => 'Hommikune infotund';

  @override
  String get mostUsedAgents => 'Enim kasutatud ained';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Viimases $arg1 enim kasutatud mudelid.';
  }

  @override
  String get mouseKeyboard => 'Hiir ja klaviatuur';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'MouseMove\'i sellel platvormil ei toetata.';

  @override
  String get mustBeReachableOnThePublic =>
      'Peab olema kättesaadav avalikus Internetis -- kohalikus ja ';

  @override
  String get n24Hours => '24 tundi';

  @override
  String get n2faOrRecoveryCode => '2FA või taastekood';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA nõuab, et sellel NeoAgenti juurutamisel oleks konfigureeritud SESSION_SECRET.';

  @override
  String get n30Days => '30 päeva';

  @override
  String get n365Days => '365 päeva';

  @override
  String get n4HourLimitTokens => '4-tunnine limiit (märgid)';

  @override
  String get n4HourUsage => '4-tunnine kasutus';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h piirang $arg1';
  }

  @override
  String get n7DayUsage => '7-päevane kasutus';

  @override
  String get n7Days => '7 päeva';

  @override
  String get n90Days => '90 päeva';

  @override
  String get name => 'Nimi';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnimi: Uus oskus\nkirjeldus: Kirjeldage, mida see oskus teeb\n---\nKirjutage selle oskuse juhised siia.\n';

  @override
  String get nameOfWhoeverMadeIt => 'selle tegija nimi.';

  @override
  String get nameOptional => 'Nimi (valikuline)';

  @override
  String get nativeAndWebhookChannels => 'Omakanalid ja veebihaagi kanalid';

  @override
  String get naturalBubbles => 'Looduslikud mullid';

  @override
  String get nearbyNeoagentServers => 'Lähedal asuvad NeoAgenti serverid';

  @override
  String get needANewAccountRegister => 'Kas vajate uut kontot? Registreeru';

  @override
  String get needAnIdea => 'Vajad ideed?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Vaja vastata · Rääkimiseks $arg1%.';
  }

  @override
  String get needsAttention => 'Vajab tähelepanu';

  @override
  String get needsInput => 'Vajab sisendit';

  @override
  String get neoagentApp => 'Rakendus NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgenti assistent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent ei saanud saadaolevat taustaprogrammi käitusaega kontrollida.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent ei saanud kohalikku seadistamist lõpule viia.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent ei saanud kohalikku seadistamist lõpule viia. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgenti silumise teave';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installib uusima $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent on installitud ja töötab.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent pole sellesse arvutisse installitud.';

  @override
  String get neoagentIsReady => 'NeoAgent on valmis';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent töötab endiselt ülesande kallal. Lõpetage kõne ja saate tulemuse vestluses või tühistage ka ülesanne.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent muudab teie demonstratsiooni kohandatavaks töövooks.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent ootab, kuni te töölauda kasutate.';

  @override
  String get neoagentIsWorking => 'NeoAgent töötab';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linuxi arvuti';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT VAJAB OTSUST';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'NeoAgenti käitusaegseks allalaadimiseks on vaja turvalist aadressi.';

  @override
  String get neoagentServerAddress => 'NeoAgent serveri aadress';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgenti teenusemeil pole valmis. Paluge serveri operaatoril kontrollida meilikeskkonna sätteid.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'NeoAgenti seadistamist ei saanud lõpule viia.';

  @override
  String get neoagentUser => 'NeoAgenti kasutaja';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent kasutab seda arvutit automaatselt ja küsib enne teie ekraani, hiire, klaviatuuri, failide või käsurea kasutamist.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent kasutab geotara meeldetuletuste käivitamiseks teie ligikaudset tausta asukohta (nt \"Tuleta mulle meelde piima ostmist, kui lähen supermarketist mööda\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgenti tööruum';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stack] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecalli taustaprogrammi URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'NeoRecalli taustaprogrammi URL on nõutav.';

  @override
  String get neorecallSetup => 'NeoRecalli häälestus';

  @override
  String get networkRequestFailed => 'võrgutaotlus ebaõnnestus';

  @override
  String get networkWriteRequests => 'Võrgu kirjutamise taotlused';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'ei lähe kunagi jagatud kasutuspiirangute hulka.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Uued kontod kinnitavad enne sisselogimist oma e-posti aadressi.';

  @override
  String get newAccountsPerDay => 'Uusi kontosid päevas';

  @override
  String get newChat => 'Uus vestlus';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Uued rühmad jäävad vaikseks, kui keegi ei märgi $arg1, kuni te need sisse lülitate.';
  }

  @override
  String get newLink => 'Uus link';

  @override
  String get newPasswordsDoNotMatch => 'Uued paroolid ei ühti.';

  @override
  String get newRecoveryCodes => 'Uued taastekoodid';

  @override
  String get newSession => 'Uus seanss';

  @override
  String get newSessionN => 'Uus seanss (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Uus seanss sama seadistusega';

  @override
  String get newSkill => 'Uus oskus';

  @override
  String get newSkill2 => 'Uus oskus';

  @override
  String get newThisWeek => 'Uus sel nädalal';

  @override
  String get newsDigest => 'Uudiste kokkuvõte';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Järgmine korduskatse: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloudi sisselogimisvoog';

  @override
  String get nextcloudSetup => 'Nextcloudi seadistamine';

  @override
  String get nextcloudTalk => 'Nextcloudi kõne';

  @override
  String get nextcloudUrl => 'Nextcloudi URL';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloudi URL on nõutav.';

  @override
  String get nickname => 'Hüüdnimi';

  @override
  String get noAccountsConnectedYet => 'Ühtegi kontot pole veel ühendatud.';

  @override
  String get noAccountsFound => 'Ühtegi kontot ei leitud.';

  @override
  String get noActiveSessionsFound => 'Aktiivseid seansse ei leitud.';

  @override
  String get noAgentsYet => 'Agente veel pole';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Ükski AI pakkuja pole konfigureeritud, seega vestelge ja sõnumside ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Kinnitusviipasid pole – agent töötab katkestusteta.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Sellele platvormile ei vastanud ükski $arg1 väljalaskevara.';
  }

  @override
  String get noArguments => '(argumente pole)';

  @override
  String get noAuth => 'Autentimist pole';

  @override
  String get noBindingsYet => 'Sidumisi veel pole.';

  @override
  String get noChangesYet => 'Muudatusi veel pole';

  @override
  String get noChannelsFound => 'Ühtegi kanalit ei leitud';

  @override
  String get noCloudComputerSlotIsFree =>
      'Ükski pilvearvuti pesa pole praegu tasuta. Proovige hetke pärast uuesti.';

  @override
  String get noCoreMemoryEntriesYet => 'Põhimälu kirjeid pole veel.';

  @override
  String get noDescription => 'Kirjeldust pole';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Töölauakuvareid pole praegu saadaval.';

  @override
  String get noDetailAvailable => 'Üksikasjad puuduvad';

  @override
  String get noDetailedSyncSummaryYet =>
      'Üksikasjalikku sünkroonimise kokkuvõtet pole veel.';

  @override
  String get noDetailsCaptured => 'Üksikasju ei jäädvustatud.';

  @override
  String get noEmailLinked => 'Meil ei ole lingitud';

  @override
  String get noExternalSignInProvidersLinked =>
      'Väliseid sisselogimisteenuse pakkujaid pole lingitud.';

  @override
  String get noGroupMessagesYet => 'Grupisõnumeid pole veel';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Grupispetsiifilisi inimesi pole veel lisatud.';

  @override
  String get noGroupsAddedYet => 'Gruppe pole veel lisatud.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Ühtegi gruppi pole veel leitud. Kui $arg1 näeb grupisõnumit, kasutage valikut Otsi hiljutised vestlused ja need kuvatakse siin.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Ühtegi gruppi pole veel leitud. Kui $arg1 näeb grupisõnumit, kasutage valikut Otsi hiljutised vestlused.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Terviseandmete kasulikku koormust ei tagastatud.';

  @override
  String get noHealthSamplesStoredYet => 'Terviseproove pole veel salvestatud.';

  @override
  String get noHttpClientImplementationForThis =>
      'Sellel platvormil pole HTTP-kliendi juurutamist.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Selle sammu jaoks ei salvestatud sisendit ega väljundit.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Sellele otsingule ei vasta ükski integratsioon.';

  @override
  String get noLimit => 'Piiramata';

  @override
  String get noLocalPasswordIsSetYet =>
      'Kohalikku parooli pole veel määratud. Looge see kasutajanime/parooliga sisselogimise lubamiseks.';

  @override
  String get noLogEntries => 'Logi sissekanded puuduvad.';

  @override
  String get noMatchingSettings => 'Ühtegi sobivat seadet pole';

  @override
  String get noMcpServersMatchThisSearch =>
      'Sellele otsingule ei vasta ükski MCP-server.';

  @override
  String get noMemoryEntriesFound => 'Mälukirjeid ei leitud.';

  @override
  String get noMemorySync => 'Mälu sünkroonimine puudub';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Loeb ühekordselt viimase 12 kuu olulised ja saadetud kirjad, et agent tunneks su kontakte ja projekte.';

  @override
  String get emailMemory => 'E-posti mälu';

  @override
  String get importNow => 'Impordi kohe';

  @override
  String get importOnConnect => 'Impordi konto ühendamisel varasemad kirjad';

  @override
  String get sweepStarting => 'Valmistumine…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'E-kirjade lugemine · $done/$total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'E-kirjade lugemine · leitud $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'E-kirjadest õppimine · $done/$total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Viimane import: $emails e-kirja · $memories uut mälestust';
  }

  @override
  String get sweepNothingNew => 'Uusi e-kirju importimiseks pole';

  @override
  String sweepFailed(String error) {
    return 'Import ebaõnnestus: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Ükski mudel ei vasta \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Selle jooksu jaoks ei registreeritud ühtegi mudelitaotlust.';

  @override
  String get noModelsDiscoveredYet => 'Ühtegi mudelit pole veel avastatud';

  @override
  String get noModelsSelected => 'Ühtegi mudelit pole valitud';

  @override
  String get noModelsYet => 'Mudeleid veel pole';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'selle pakkujaga pole lingitud ühtegi neoagendi kontot';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Selle arvuti jaoks pole NeoAgenti taustaprogrammi käituskeskkond saadaval.';

  @override
  String get noNetworkConnection => 'Võrguühendus puudub';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Võrguühendus puudub. NeoAgenti kasutamise jätkamiseks looge ühendus.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Võrguühendus puudub. Värskenduste kontrollimiseks ühendage uuesti.';

  @override
  String get noOne => 'Mitte keegi';

  @override
  String get noOneAddedYet => 'Keegi pole veel lisanud.';

  @override
  String get noOneCanMessage => 'Keegi ei saa sõnumit saata';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Teist NeoAgenti serverit ei leitud. Saate uuesti otsida või aadressi käsitsi sisestada.';

  @override
  String get noPeopleAddedYet => 'Inimesi pole veel lisatud.';

  @override
  String get noPlatformsMatch => 'Ükski platvorm ei sobi';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Ühtegi pakkujat pole veel seadistamiseks saadaval.';

  @override
  String get noRecentChannelActivity => 'Hiljutine kanalitegevus puudub';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Päringule \"$arg1\" ei leitud tulemusi';
  }

  @override
  String get noRunsInThisRange => 'Selles vahemikus ei jookse.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nendele filtritele ei vasta ükski käitamine';

  @override
  String get noRunsYet => 'Pole veel jookse';

  @override
  String get noRunsYet2 => 'Pole veel jookse.';

  @override
  String get noSecurityKeyWasProvided => 'Turvavõtit ei antud.';

  @override
  String get noServerUrlSet => 'Serveri URL-i pole määratud';

  @override
  String get noSessionMatchesThatSearch => 'Otsingule ei vasta ükski seanss.';

  @override
  String get noSessionsYet => 'Seansse veel pole';

  @override
  String get noSkillsMatchTheseFilters =>
      'Nendele filtritele ei vasta ükski oskus.';

  @override
  String get noStepsWereRecordedForThis =>
      'Selle jooksu jaoks ei salvestatud ühtegi sammu.';

  @override
  String get noSummaryAvailable => 'Kokkuvõte pole saadaval.';

  @override
  String noTasksForArg1(Object? arg1) {
    return '$arg1 jaoks pole ülesandeid';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Ükski tööriist ei vasta \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Värskendus ei tööta';

  @override
  String get noUsageYet => 'Pole veel kasutust.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Kontrollitud NeoAgenti taustaprogrammi käitusaeg pole veel saadaval.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Keegi ei saa seda enam kasutada. Inimesed, kes on juba liitunud ';

  @override
  String get none => 'Mitte ühtegi';

  @override
  String get notApprovedYet => 'pole veel heaks kiidetud';

  @override
  String get notAuthenticated => 'pole autentitud';

  @override
  String get notCheckedYet => 'Pole veel kontrollitud';

  @override
  String get notConfigured => 'Pole konfigureeritud';

  @override
  String get notConnected => 'Pole ühendatud';

  @override
  String get notConnected2 => 'Pole ühendatud';

  @override
  String get notInstalled => 'Pole installitud';

  @override
  String get notNeeded => 'Pole vaja';

  @override
  String get notNeededEnough => 'Pole piisavalt vaja';

  @override
  String get notNow => 'Mitte praegu';

  @override
  String get notNow2 => 'Mitte praegu';

  @override
  String get notSet => 'Pole määratud';

  @override
  String get notSetUp => 'Pole seadistatud';

  @override
  String get notTheSameAsAdmin => 'Pole sama mis admin';

  @override
  String get nothingFound => 'Midagi ei leitud';

  @override
  String get nothingHereYet => 'Siin pole veel midagi.';

  @override
  String get nothingHereYet2 => 'Siin pole veel midagi';

  @override
  String get nothingMatches => 'Mitte miski ei ühti';

  @override
  String get nothingStoredYet => 'Midagi pole veel salvestatud.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'OAuthi kliendi ID';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth kliendi ID salajane ümbersuunamise api võti';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth kliendi ID salajane ümbersuunamine Gmaili kalendri draiv';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Sellel platvormil ei toetata OAuthi käivitamist.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook rentniku kliendi ID saladus';

  @override
  String get oauthToken => 'OAuthi luba';

  @override
  String get oauthWithPkce => 'OAuth PKCE-ga';

  @override
  String ofArg1(Object? arg1) {
    return '$arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'omast. Pärast salvestamist ei kuvata seda enam kunagi.';

  @override
  String get off => 'Väljas';

  @override
  String get officialIntegration => 'Ametlik integratsioon';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Ametlik integratsioon ei tagastanud ühenduse URL-i.';

  @override
  String get on => 'Sees';

  @override
  String get onASignedInAndroidDevice =>
      'Avage sisselogitud Android-seadmes Seaded › Sisselogimine ja turvalisus, skannige see kood ja kinnitage sisselogimine.';

  @override
  String get onByDefaultForNewGroups =>
      'Uute rühmade jaoks vaikimisi sisse lülitatud';

  @override
  String get onDemand => 'Nõudmisel';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Sees $arg2 rühmade $arg1 jaoks';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'sisse. Nad saavad uuesti liituda ainult uue kutselingiga.';

  @override
  String get onYourOwnTheDefault => 'Üksinda (vaikimisi)';

  @override
  String get once => 'Üks kord';

  @override
  String get oneIsSavedOtherChangesIn =>
      'üks on päästetud. Ka muud selle vormi muudatused salvestatakse.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Üks või mitu kontot on aegunud. Tööriistale juurdepääsu taastamiseks ühendage mõjutatud konto uuesti.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Üks käitusaeg kontrollib isikut, grupi kordamist, ruumi mälu, norme, mõistuse teooriat ja kohaletoimetamist.';

  @override
  String get oneTimeRun => 'Ühekordne jooks';

  @override
  String get onlyApkOrApksFilesCan =>
      'Installida saab ainult .apk- või .apks-faile.';

  @override
  String get onlyInThisGroup => 'Ainult selles grupis';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Vajalik ainult siis, kui teenus nõuab täiendavaid HTTP-päiseid.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Vajalik ainult siis, kui soovite väljaminevat kasulikku koormust ümber kujundada.';

  @override
  String get onlyTheyCanChangeIt => 'Ainult nemad saavad seda muuta.';

  @override
  String get open => 'Avatud';

  @override
  String get openAccountSettingsOnASigned =>
      'Avage sisselogitud Android-seadmes Seaded › Sisselogimine ja turvalisus, skannige see kood ja kinnitage sisselogimine.';

  @override
  String get openComputer => 'Ava arvuti';

  @override
  String get openDashboard => 'Ava armatuurlaud';

  @override
  String get openFolder => 'Ava kaust…';

  @override
  String get openInWorkbench => 'Avatud töölaual';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Sõnumside taastamiseks avage NeoAgent ja ühendage $arg1 uuesti.';
  }

  @override
  String get openTimeSettings => 'Ava aja seaded';

  @override
  String get openToAnyone => 'Avatud kõigile';

  @override
  String get openTrello => 'Avage Trello';

  @override
  String get openVoiceAssistant => 'Ava hääleassistent';

  @override
  String get openWiFiSettings => 'Avage Wi-Fi seaded';

  @override
  String get openWithTheDefaultApp => 'Avage vaikerakendusega';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai ühilduv';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-ga ühilduv lõpp-punkt (teie enda server või mõni muu ';

  @override
  String openedArg1(Object? arg1) {
    return 'Avatud $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Sellel platvormil ei toetata töölaua URL-ide avamist.';

  @override
  String get openingYourSavedDesktop => 'Salvestatud töölaua avamine.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Salvestatud töölaua avamine. Tavaline käivitamine võtab vähem kui 10 sekundit.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Valikuline lisasaladus, kui kaitsete sissetulevat veebihaaki.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Valikuline alistamine, kui veebihaagi URL-ist ei piisa.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Valikuline saladus sissetulevate vestlussündmuste kinnitamiseks.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Valikuline saladus sissetulevate sündmuste kontrollimiseks.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Valikuline saladus sissetulevate iMessage\'i sündmuste kontrollimiseks.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Valikuline saladus LINE sissetulevate sündmuste kontrollimiseks.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Valikuline saladus sissetulevate Mattermosti sündmuste kontrollimiseks.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Valikuline saladus sissetulevate Teamsi sündmuste kontrollimiseks.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Valikuline. Agendil on juba oma isiksus. Kõik, mida lisate tooni kohta, on selle peale kihiline, nii et te ei pea seda kunagi määratlema.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Valikuline. Kui see on määratud, kasutatakse seda URL-i asemel.';

  @override
  String get orAnswerInYourOwnWords => 'Või vastake oma sõnadega';

  @override
  String get orBuildYourOwnTask => 'Või koostage oma ülesanne';

  @override
  String get orContinueWith => 'või jätkata';

  @override
  String get orFiles => 'või failid.';

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
  String get originNotAllowed => 'päritolu pole lubatud';

  @override
  String get outgoingMessage => 'Väljuv sõnum';

  @override
  String get outgoingWebhookUrl => 'Väljuva veebihaagi URL';

  @override
  String get outlookEmailReceived => 'Outlooki meilisõnum vastu võetud';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Kirjutage impordi käitumismärkused üle.';

  @override
  String get ownModel => 'enda mudel';

  @override
  String get packageName => 'Paketi nimi';

  @override
  String get pairWithQrCode => 'Siduge QR-koodiga';

  @override
  String get password => 'Parool';

  @override
  String get password2faAndActiveSessions => 'Parool, 2FA ja aktiivsed seansid';

  @override
  String get passwordCreated => 'Parool loodud.';

  @override
  String get passwordIsTooWeak => 'parool on liiga nõrk';

  @override
  String get passwordMin8 => 'parool min 8';

  @override
  String get passwordOrApiKey => 'Parool või API võti';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Parooli tugevus: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Paroolid ei ühti.';

  @override
  String get pasteAKey => 'Kleepige võti.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Kleepige $arg1 asendamiseks uus võti';
  }

  @override
  String get pasteTheKey => 'Kleepige võti';

  @override
  String get pasteYourAccountToken => 'Kleepige oma konto tunnus';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Kleepige alla oma $arg1 API võti. See on ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Tee peab jääma NeoAgenti tööruumi.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Tee peab jääma tööruumi kausta.';

  @override
  String get pauseLiveUpdates => 'Peatage reaalajas värskendused';

  @override
  String get pauseTaskLoop => 'Peatage ülesande tsükkel';

  @override
  String get paused => 'Peatatud';

  @override
  String peakArg1(Object? arg1) {
    return 'tipp $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Inimesed privaatvestlustes';

  @override
  String get perAccountRateLimits => 'Kontopõhise intressimäära limiidid';

  @override
  String get perCategoryPermissions => 'Kategooriapõhised load';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Tööriistapõhised loapoliitikad, kinnitusväravad ja protsesside isoleerimine kesta täitmiseks.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Nõutav luba: $arg1';
  }

  @override
  String get permissionsNeeded => 'Vajalikud load';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'load. Keegi teine ​​ei saa seda muuta.';

  @override
  String get personOrChat => 'Isik või vestlus';

  @override
  String get personaBehaviorNotes => 'Isiku käitumise märkmed';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Mattermosti roboti isiklik juurdepääsuluba.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Isiklikud kanalid ja otsesed tugipinnad.';

  @override
  String get personalSelfChat => 'Isiklik enesevestlus';

  @override
  String get phoneNumber => 'Telefoninumber';

  @override
  String get pickARunFromTheList =>
      'Valige loendist jooks, et näha selle samme.';

  @override
  String get pickARunFromTheList2 =>
      'Valige vasakpoolsest loendist jooks, et selle kulgu uurida.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Valige hiljutiste $arg1 vestluste hulgast või lisage ise inimene või rühm.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Valige, kuidas $arg1 seda kontot kasutab.';
  }

  @override
  String get pickOneToFillInThe =>
      'Valige üks ülesande täitmiseks. Pärast saate kõike muuta.';

  @override
  String get picksUpWhereYouLeftOff => 'Jätkab sealt, kus pooleli jäite';

  @override
  String get plan => 'Plaan';

  @override
  String get planning => 'Planeerimine';

  @override
  String get platform => 'Platvorm';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platvorm $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Valige ajakava.';

  @override
  String get pleaseEnterAFilename => 'Palun sisesta failinimi.';

  @override
  String get pleaseEnterAKey => 'Sisestage võti.';

  @override
  String get pleaseEnterAPrompt => 'Sisestage viip.';

  @override
  String get pleaseEnterATaskName => 'Sisestage ülesande nimi.';

  @override
  String get pleaseEnterTheMemoryContent => 'Sisestage mälu sisu.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Sisestage, millal ülesanne peaks käima.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Valige konto või sisestage kehtiv ühenduse ID.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Osutage NeoAgentile mis tahes OpenAI-ga ühilduva vestluse lõpetamise kohta ';

  @override
  String get pointTheCameraAtTheCode =>
      'Suunake kaamera väljalogitud seadmel kuvatavale koodile. Heakskiit jääb sellele telefonile.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env avaliku URL-i usalduspuhverserveri turvaliste küpsiste juurutamine';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Esmaklassiline automatiseerimine ajakava ja integratsioonipäästikutega.';

  @override
  String get prepareQrCode => 'Valmistage QR-kood';

  @override
  String get preparingNeoagent => 'NeoAgenti ettevalmistamine…';

  @override
  String get preparingNeoagent2 => 'NeoAgenti ettevalmistamine';

  @override
  String get pressAndHoldForQuickCapture =>
      'Kiireks jäädvustamiseks vajutage ja hoidke all';

  @override
  String get pressKeysIsNotSupportedOn =>
      'klahve ei toetata sellel platvormil.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Pressitud $arg1';
  }

  @override
  String get priceUnknown => 'Hind teadmata';

  @override
  String get primaryDisplay => 'Esmane ekraan';

  @override
  String get privateChat => 'Privaatne vestlus';

  @override
  String get privateChats => 'Privaatsed vestlused';

  @override
  String get privateChats2 => 'privaatsed vestlused';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privaatvestlused: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privaatvestlused $arg1 · grupid $arg2';
  }

  @override
  String get privateChatsOnly => 'Ainult privaatsed vestlused';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privaatvõrgu aadressid pole lubatud.';

  @override
  String get profileEmailAndPersonalData => 'Profiil, e-post ja isikuandmed';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Küsib, enne kui NeoAgent jääb süsteemses salves residentseks.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Viip vahemälu: $arg1 vahemällu salvestatud märgid ';
  }

  @override
  String get promptCopied => 'Viip on kopeeritud.';

  @override
  String get promptOrSchedule => 'viipe või ajakava.';

  @override
  String get promptToPasteIntoAnotherAi => 'Viip teise AI-sse kleepimiseks';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Pakkuja linkimist ei saanud alustada.';

  @override
  String get providerSignInCouldNotBe =>
      'Pakkuja sisselogimist ei saanud alustada.';

  @override
  String get providers => 'Pakkujad';

  @override
  String get providersEachAccountCanStillPick =>
      'Pakkujad; iga konto saab seadetes siiski valida oma mudeli. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Pakkujaid, integratsioone, häält ja valikulisi võimalusi saab seadetes igal ajal täiendada.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Avalikud väljaandmis- ja tõmbamistaotluste lõimed, millele vastatakse ainult heakskiidetud inimestele.';

  @override
  String get publicUrl => 'Avalik URL';

  @override
  String get publicUrlAndAllowedOrigins => 'Avalik URL ja lubatud päritolu';

  @override
  String get publicUrlOverride => 'Avaliku URL-i alistamine';

  @override
  String get pullsTogetherTheDayAhead => 'Võtab eelseisva päeva kokku';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'QR-põhine telefoni linkimine';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR-sisselogimine lõpetati, kuid NeoAgent ei saanud seanssi jätkata. Palun proovi uuesti.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'QR-sisselogimist ei saanud käivitada.';

  @override
  String get qrLoginRequestHasExpired => 'qr sisselogimistaotlus on aegunud';

  @override
  String get qrLoginRequestWasNotFound => 'qr sisselogimistaotlust ei leitud';

  @override
  String get qrPairing => 'QR-sidustamine';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'päringud käivitatakse; kõik, mis kirjutab, lükatakse tagasi.';

  @override
  String get queryFilter => 'Päring / Filter';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Jooksvas jooksus juhina: $arg1';
  }

  @override
  String get quickstart => 'Kiirstart';

  @override
  String get quit => 'Lõpeta';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'vihma_start, tuulehoiatus';

  @override
  String get ranAScriptInThePage => 'Käivitas lehel skripti';

  @override
  String ranArg1(Object? arg1) {
    return 'Jooks $arg1';
  }

  @override
  String get rateLimits => 'Hindade piirangud';

  @override
  String get readAnArtifact => 'Lugege artefakti';

  @override
  String get readAndEditFilesInsideYour =>
      'Lugege ja redigeerige oma NeoAgent Workspace\'i kaustas olevaid faile.';

  @override
  String readArg1(Object? arg1) {
    return 'Lugege $arg1';
  }

  @override
  String get readError => 'Lugemisviga';

  @override
  String get readFiles => 'Lugege faile';

  @override
  String get readOnly => 'Ainult lugemiseks';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Lugege kausta ja tehke kokkuvõte pinust, sisestuspunktidest ja selle käivitamisest.';

  @override
  String get readThePage => 'Lugege lehte';

  @override
  String get readTheUiTree => 'Lugege kasutajaliidese puud';

  @override
  String get readWrite => 'Loe / Kirjuta';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Loeb samme, pulssi, und, treeningut ja kaalu.';

  @override
  String get ready => 'Valmis';

  @override
  String get readyForFirstTimeSetup => 'Esmakordseks seadistamiseks valmis';

  @override
  String get readyToConnect => 'Ühenduse loomiseks valmis';

  @override
  String get recentChannelActivity => 'Hiljutine kanali tegevus';

  @override
  String get recentChats => 'Viimased vestlused';

  @override
  String get recentDecisions => 'Viimased otsused';

  @override
  String get recentFailedRuns => 'Viimased ebaõnnestunud jooksud';

  @override
  String get recentGroupDecisions => 'Hiljutised grupiotsused';

  @override
  String get recentRuns => 'Viimased jooksud';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Hiljutised jooksud kestavad umbes $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Värske serveriväljund, uusim enne.';

  @override
  String get recentUsage4Hours => 'Hiljutine kasutus (4 tundi)';

  @override
  String get recents => 'Viimased';

  @override
  String get recipientField => 'Saaja väli';

  @override
  String get reconnectOrFinishSetup =>
      'Ühendage uuesti või lõpetage seadistamine';

  @override
  String get reconnectingThisDevice => 'Selle seadme uuesti ühendamine…';

  @override
  String get recurring => 'Korduv';

  @override
  String get redirectUri => 'Ümbersuunamise URI';

  @override
  String get redoOnboarding => 'Uuesti liitumine';

  @override
  String get refresh => 'Värskenda';

  @override
  String get refreshCode => 'Värskenda koodi';

  @override
  String get refreshNow => 'Värskenda kohe';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Uuesti proovimiseks värskendage Androidi ekraani.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Keelduge saatmisest, välja arvatud juhul, kui ühendus läheb üle TLS-ile.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'sõltumata allolevatest kategooriate sätetest.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registreerige $arg1 assistendi kutsevoo jaoks.';
  }

  @override
  String get registrationIsClosed => 'registreerimine on suletud';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registreerimine registreerige uued kontod võimaldavad registreeruda';

  @override
  String get rejectInvalidTlsCertificates =>
      'Keeldu kehtetutest TLS-sertifikaatidest';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'vabastada ja taaskäivitada. Ühendatud rakendused ühendavad uuesti, kui see on tagasi.';

  @override
  String get releaseChannel => 'Vabasta kanal';

  @override
  String get releaseCommitBranchNode => 'vabasta commit harusõlme';

  @override
  String get releaseWhenYouAreDone => 'Vabastage, kui olete lõpetanud.';

  @override
  String get reloadNow => 'Laadige kohe uuesti';

  @override
  String get rememberThisChoice => 'Pidage meeles seda valikut';

  @override
  String get remove => 'Eemalda';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Kas eemaldada \"$arg1\" ja selle salvestatud sammud jooksuajaloost?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Eemaldage põhimälust \"$arg1\".';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Kas eemaldada võti $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'eemaldage kustutage gdpr-i kasutaja';

  @override
  String get removeSmtpPassword => 'Eemaldage SMTP parool';

  @override
  String get removeTheSmtpPassword => 'Kas eemaldada SMTP parool?';

  @override
  String get rename => 'Nimeta ümber';

  @override
  String get renameSecurityKey => 'Nimeta turvavõti ümber';

  @override
  String get renameSession => 'Nimeta seanss ümber';

  @override
  String get repairAndRetry => 'Parandage ja proovige uuesti';

  @override
  String get repairDesktop => 'Parandage töölaud';

  @override
  String get repeat => 'Korda';

  @override
  String get repliesWhenTagged => 'Vastab märgistamise korral';

  @override
  String get replyToAddress => 'Vastus-aadressile';

  @override
  String replyToArg1(Object? arg1) {
    return 'Vastus küsimusele $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Hoidla peab olema vormingus omanik/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reprodutseerige minu kirjeldatud viga, leidke algpõhjus ja parandage see regressioonitestiga.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'taotlus nurjus http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'HTTP $arg1 taotlus nurjus';
  }

  @override
  String get requestPermissions => 'Lubade taotlemine';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Taotlus aadressile $arg1 nurjus enne, kui taustaprogramm vastas.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Soovitud $arg1';
  }

  @override
  String get requireStarttls => 'Nõua STARTTLS-i';

  @override
  String get requiredBehindHttpsOrATls =>
      'Nõutav HTTPS-i või TLS-puhverserveri taga. Kehtib pärast serverit ';

  @override
  String get requiredExampleBerlinDe => 'Nõutav. Näide: Berliin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Nõutav. Formaat: omanik/repo';

  @override
  String get reserveAssistantHotkey => 'Reservassistendi kiirklahv';

  @override
  String get reset => 'Lähtesta';

  @override
  String get resetPassword => 'Lähtestage parool';

  @override
  String get resetView => 'Lähtesta vaade';

  @override
  String get responsibilities => 'Kohustused';

  @override
  String get restart => 'Taaskäivitage';

  @override
  String get restartToFinishTheUpdate =>
      ' Värskenduse lõpetamiseks taaskäivitage.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Eelmise NeoAgenti käitusaja taastamine';

  @override
  String get restrictDelegationTargets => 'Piirake delegeerimise eesmärke';

  @override
  String get result => 'Tulemus';

  @override
  String get resultDelivery => 'Tulemuse kohaletoimetamine';

  @override
  String get resultOneClickAddsOneYou =>
      'tulemus. Üks klõps lisab ühe; saate seda hiljem redigeerida.';

  @override
  String get results => 'Tulemused';

  @override
  String get retry => 'Proovi uuesti';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Korduvkasutatav · kasutatud $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Vaadake läbi tegemata muudatused';

  @override
  String get revoke => 'Tühista';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Tühista administraator esmalt käsuga `neoagendi admin tühista $arg1';
  }

  @override
  String get revokeThisLink => 'Kas tühistada see link?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Ruumi partii aken: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Jätkamiseks pöörake';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'read. Lisage vaatamiseks LIMIT või kitsam WHERE-klausel ';

  @override
  String get rule => 'Reegel';

  @override
  String get run => 'Käivitus';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Käivitage oma masinas või virtuaalses masinas suvalisi käske.';

  @override
  String get runAt => 'Jookse kell';

  @override
  String get runCompleted => 'Jooks lõpetatud';

  @override
  String get runFailed => 'Jooks ebaõnnestus';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Käivitage git diff, vaadake läbi tegemata jäänud muudatused vigade ja stiiliprobleemide osas ning tehke leitu kokkuvõte.';

  @override
  String get runNotFound => 'Käivitamist ei leitud';

  @override
  String get runNow => 'Käivita kohe';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Töötage sissetulevate isiklike WhatsAppi sõnumitega.';

  @override
  String get runQuery => 'Käivita päring';

  @override
  String get runShellCommandsOrInstallApps =>
      'Käivitage oma Android-seadmesse kestakäske või installige rakendusi.';

  @override
  String get runStarted => 'Jooks algas';

  @override
  String get runStatus => 'Käivita olek';

  @override
  String get runStopped => 'Jooks jäi seisma';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Käivitage terminalikäsud ja avage rakendused või veebilehed.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Käivitage see server: kontod, värskendused, pakkujad, konfiguratsioon ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Käivitage, kui saabub sobiv Gmaili sõnum.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Käivitage, kui saabub sobiv Outlooki meil.';

  @override
  String get runWhenANewIssueMatching =>
      'Käivitage, kui hoidlas avatakse teie filtritele vastav uus probleem.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Käivitage, kui luuakse teie filtritele vastav uus NeoRecalli mälu.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Käivitage, kui teie seadmesse saabub teatis.';

  @override
  String get runWhenASlackMessageMatches =>
      'Käivitage, kui Slacki sõnum vastab valitud ulatusele.';

  @override
  String get runWhenATeamsChatMessage =>
      'Käivitage, kui Teamsi vestlussõnum vastab valitud ulatusele.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Käivitage, kui asukoha jaoks on prognoositud konfigureeritud ilmastikunähtused.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'jooksma. Kui mis tahes mudel on välja lülitatud, lisavad pakkujad mudelid ';

  @override
  String get running => 'Töötab';

  @override
  String runningArg1(Object? arg1) {
    return 'Töötab $arg1';
  }

  @override
  String get runningTask => 'Jooksuülesanne';

  @override
  String get runningTool => 'Jooksutööriist';

  @override
  String get runs => 'Käivitused';

  @override
  String get runsEveryDayAtTheSelected => 'Töötab iga päev valitud ajal.';

  @override
  String get runsFourTimesPerHour => 'Jookseb neli korda tunnis.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— jooksud, sõnumid, mälud, integratsioonid, failid ja ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'jooksud, sõnumid, mälud, integratsioonid, failid ja seansid. ';

  @override
  String get runsMondayThroughFriday => 'Töötab esmaspäevast reedeni.';

  @override
  String get runsOnSelectedWeekdays => 'Töötab valitud tööpäevadel.';

  @override
  String get runsOncePerHour => 'Jookse korra tunnis.';

  @override
  String get runsOncePerMonthOnThe => 'Töötab kord kuus valitud päeval.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Töötab ainult siis, kui vajutate Käivita kohe.';

  @override
  String get runsPerDay => 'Jookseb päevas';

  @override
  String get runsPerDay30Days => 'Töötab päevas (30 päeva)';

  @override
  String get runsThatCompleted => 'Käitab, mis on lõpetatud';

  @override
  String get runsThisWeek => 'Jookse sel nädalal';

  @override
  String get runsToday => 'Jookseb täna';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Käitamised, tööriistad, mälu, ajakava, oskused ja MCP on kõik saadaval siin.';

  @override
  String get runsTwicePerHour => 'Jookse kaks korda tunnis.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Käitamised langevad tagasi $arg1 jagatud serveri võtmele, kui see on konfigureeritud. Seda ei saa tagasi võtta.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Tööaeg $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Kestus: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Käitusaja seaded, millega see server algas. Redigeerige neid all ';

  @override
  String get runtimeSetupRequired => 'Nõutav käitusaja seadistus';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Käitusaja allkirjastamise avalik võti peab olema 32 baiti.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Salvesta';

  @override
  String get saveATrelloApiKeyFor =>
      'Salvestage selle agendi jaoks Trello API võti ja seejärel ühendage üks Trello konto turvaliselt. Konto tunnus salvestatakse serverisse ja seda kasutatakse ainult selle agendi jaoks.';

  @override
  String get saveAccount => 'Salvesta konto';

  @override
  String get saveChanges => 'Salvestage muudatused';

  @override
  String get saveCloudComputerSettings => 'Salvestage pilvearvuti seaded';

  @override
  String get saveConnect => 'Salvesta ja ühenda';

  @override
  String get saveDefaults => 'Salvesta vaikeseaded';

  @override
  String get saveDiagnosticReport => 'Salvestage diagnostikaaruanne';

  @override
  String get saveEmail => 'Salvesta meil';

  @override
  String get saveEmailSettings => 'Salvestage meiliseaded';

  @override
  String get saveGeneralSettings => 'Salvestage üldised seaded';

  @override
  String get saveName => 'Salvesta nimi';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Salvestage NeoAgenti seadistusdiagnostika';

  @override
  String get saveOnly => 'Ainult salvesta';

  @override
  String get saveSetup => 'Salvesta seadistus';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Salvestage need taastekoodid kohe. Neid enam ei näidata.';

  @override
  String get savedDeliveryDestination =>
      'Salvestatud kohaletoimetamise sihtkoht';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Salvestatud piirangud @$arg1 jaoks.';
  }

  @override
  String get scanANeoagentLoginQr =>
      'Skannige NeoAgenti sisselogimise QR-koodi';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skannige NeoAgenti siduv QR teisest seadmest ja kinnitage see sellel käivitusseansil.';

  @override
  String get scanLoginQr => 'Skanni sisselogimise QR';

  @override
  String get scanPairingQr => 'Skanni sidumise QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skannige väljalogitud seadmete QR-sisselogimistaotlusi ja kinnitage need sellel autentitud mobiiliseansil.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skanni, et lõpetada $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skannige oma telefonis NeoAgentiga';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skannib uusi e-kirju ja pingib teid ainult siis, kui miski on oluline.';

  @override
  String get schedule => 'Ajakava';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'planeeritud aeg. Kui jooksud on mõõdetud, algab see varem.';

  @override
  String get screen => 'Ekraan';

  @override
  String get screenAction => 'ekraani tegevus';

  @override
  String get scrollIsNotSupportedOnThis =>
      'kerimist sellel platvormil ei toetata.';

  @override
  String get scrollToBottom => 'Kerige alla';

  @override
  String get search => 'Otsi';

  @override
  String get search2 => 'Otsi…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Otsi administraatori seadeid (nt SMTP, Ollama, logid)';

  @override
  String get searchAgain => 'Otsige uuesti';

  @override
  String get searchByUsernameOrEmail => 'Otsige kasutajanime või e-posti teel';

  @override
  String get searchChannels => 'Otsige kanaleid';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Otsige leitud sõnumikanaleid, kontakte, gruppe ja hiljutisi vestlusi.';

  @override
  String get searchGroups => 'Otsi gruppe';

  @override
  String get searchMemory => 'Otsi mälust';

  @override
  String get searchModelsOrProviders => 'Otsige mudeleid või pakkujaid';

  @override
  String get searchModelsOrProviders2 => 'Otsige mudeleid või pakkujaid…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Otsige hiljutisi inimesi ja gruppe';

  @override
  String get searchSessions => 'Otsi seansse';

  @override
  String get searchSettings => 'Otsinguseaded';

  @override
  String get searchTitleModelTriggerRunId =>
      'Otsige pealkirja, mudelit, päästikut, käitamise ID-d';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Otsingutööriistad, integratsioonid ja oskused';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Otsisin koodi \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Otsisid failid \"$arg1\"';
  }

  @override
  String get secretField => 'Salaväli';

  @override
  String get secureCookies => 'Turvalised küpsised';

  @override
  String get security => 'Turvalisus';

  @override
  String get securityKey => 'Turvavõti';

  @override
  String get securityKeyPromptWasDismissed => 'Turvavõtme viip lükati tagasi.';

  @override
  String get securityKeySignInCompletedBut =>
      'Turvavõtmega sisselogimine lõpetati, kuid NeoAgent ei saanud brauseri seanssi jätkata. Palun logige uuesti sisse.';

  @override
  String get securityKeySignInCouldNot =>
      'Turvavõtmega sisselogimist ei saanud alustada.';

  @override
  String get securityKeys => 'Turvavõtmed';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Turvavõtmed on saadaval ainult veebirakenduses NeoAgent.';

  @override
  String get seeAll => 'Vaata kõiki';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Vaadake, millist NeoAgenti serverit see aken kasutab, ja käivitage selles arvutis taustaprogramm.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'näha oma kasutajanime ja neid seadeid, mitte kunagi oma vestlusi, mälestusi ';

  @override
  String get selectARun => 'Valige jooks';

  @override
  String get selectASessionToSeeIts =>
      'Valige seanss, et näha selle arvutit, faile ja muudatusi.';

  @override
  String get selectAll => 'Valige kõik';

  @override
  String get selectAll2 => 'Valige Kõik';

  @override
  String selectArg1(Object? arg1) {
    return 'Valige $arg1';
  }

  @override
  String get selectTrigger => 'Valige Trigger';

  @override
  String get send => 'Saada (⌘↵)';

  @override
  String get send2 => 'Saada';

  @override
  String get sendATaskFromChatAnd =>
      'Saatke vestlusest ülesanne ja selle täitmise ajalugu kuvatakse siin.';

  @override
  String get sendItToATeammateWith =>
      'saata see meeskonnakaaslasele, kellel on konto selles serveris.';

  @override
  String get sendLink => 'Saada link';

  @override
  String get sendPath => 'Saada tee';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Saatke POST / PUT / DELETE taotlused välistele API-dele.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Saatke see link ainult sellele inimesele, kellele see on mõeldud. Seda näidatakse üks kord; ';

  @override
  String get senderAddress => 'Saatja aadress';

  @override
  String get senderFilterOptional => 'Saatja filter (valikuline)';

  @override
  String get sentSharedAttachments => 'Saadetud jagatud manused.';

  @override
  String get separateAccount => 'Eraldi konto';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Serveri vaikeseade ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Server on rakendusesiseste häälkõnede jaoks vaikeseade. Kõned toimuvad otseülekandes ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'server ise: kontod, pakkujad ja konfiguratsioon.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, hüüdnimi, kanal ja valikuline TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'serveri väljundkonsooli hoiatused vead kopeeri';

  @override
  String get serverProviderCredentials => 'Serveri pakkuja mandaadid';

  @override
  String get serverUrl => 'Serveri URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Serveri kasutuspiirangud ei kehti mudelitele, mis töötavad teie enda võtmega.';

  @override
  String get serviceEmail => 'Teenindusmeil';

  @override
  String get serviceEmailIsNotConfigured =>
      'teeninduse e-posti aadress pole konfigureeritud';

  @override
  String get serviceEmailSmtp => 'Teenuspostitus (SMTP)';

  @override
  String get sessionActions => 'Seansi toimingud';

  @override
  String get sessions => 'Seansid';

  @override
  String get sessions2 => 'SESSIOONID';

  @override
  String get sessionsArePinnedToAFolder =>
      'Seansid kinnitatakse kausta ja arvutisse. Alustage siit, et planeerida, ehitada, testida ja tarnida.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'istungid (GDPR art. 17). Administraatorikontosid ei saa kustutada ';

  @override
  String get sessionsLogoutRevokeForce => 'seansside väljalogimine tühista jõu';

  @override
  String get setBlockAskAllowPerTool =>
      'Määrake iga tööriistakategooria jaoks plokk / küsi / luba või valige globaalne režiim.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Seadistage selles arvutis NeoAgent';

  @override
  String get setUpOrConnectNeoagent => 'Seadistage või ühendage NeoAgent';

  @override
  String get setUrl => 'Määra URL';

  @override
  String get settings => 'Seaded';

  @override
  String get settingsAndCannotBeUndone =>
      'seadeid ja seda ei saa tagasi võtta.';

  @override
  String get settingsArea => 'Seadete ala';

  @override
  String get settingsAreas => 'Seadete alad';

  @override
  String get setup => 'Seadistamine';

  @override
  String get setupDetails => 'Seadistuse üksikasjad';

  @override
  String get setupRequired => 'Seadistamine on vajalik';

  @override
  String get setupWasCancelled => 'Seadistamine tühistati.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Jagatud manused NeoAgenti kliendilt:';

  @override
  String get sharedFromAnotherApp => 'Jagatud teisest rakendusest';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Jagatud pakkuja võtmed on serveris konfigureeritud. Selle asemel oma API-võtme või kohandatud lõpp-punkti kasutamiseks avage Täpsem → Tooge oma võti.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Jagatud NeoAgenti vestluse ja selle mäluga.';

  @override
  String get shellCommands => 'Shelli käsud';

  @override
  String showAllArg1(Object? arg1) {
    return 'Kuva kõik $arg1';
  }

  @override
  String get showEarlier => 'Näita varem';

  @override
  String get showEveryStep => 'Näita iga sammu';

  @override
  String get showTools => 'Näita tööriistu';

  @override
  String get showWorkbenchJ => 'Kuva töölaud (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Kuvatakse esimene $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Kuvatakse külgribal. Kasutajanime kasutamiseks jätke tühjaks.';

  @override
  String get signIn => 'Logi sisse';

  @override
  String get signInCompletedButNeoagentCould =>
      'Sisselogimine lõpetati, kuid NeoAgent ei suutnud brauseri seanssi jätkata. Palun logige uuesti sisse. Kui see jätkub, kontrollige taustaseansi küpsiseseadeid.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Sisselogimine lõpetati, kuid NeoAgent ei suutnud brauseri seanssi jätkata. Palun logige uuesti sisse. Kui see jätkub, siis tõenäoliselt taustaseansi küpsist ei säilitata.';

  @override
  String get signInToThisNeoagentServer =>
      'Enne sidumis-QR-koodi skannimist logige sellesse NeoAgenti serverisse sisse.';

  @override
  String get signInWithAHardwareKey =>
      'Logige sisse oma parooli asemel riistvaravõtme või pääsukoodiga. ';

  @override
  String get signInWithASecurityKey => 'Logige sisse turvavõtmega';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Logige sisse $arg1-ga';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Kinnitage NeoAgent oma $arg1 kontol. Kopeerimiseks pole võtit.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Ootan $arg1-i. Lõpetage oma brauseris.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Kleepige kood $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Pärast NeoAgenti kinnitamist näitas $arg1 ühekordset koodi. Kleepige see siia.';
  }

  @override
  String get signInCode => 'Sisselogimiskood';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Sisse logitud $arg1-ga.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Sisselogimine ebaõnnestus: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Logige sisse sama e-posti aadressi ja peaparooliga, mida kasutate Bitwardenis. Peaparooli ja kaheastmelist koodi kasutatakse ainult sisselogimiseks ning neid ei salvestata ega saadeta kunagi tehisintellektile.';

  @override
  String get signOut => 'Logi välja';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Logige kõikjal @$arg1 välja?';
  }

  @override
  String get signOutEverywhere => 'Kõikjal logige välja';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API sild';

  @override
  String get signalCliServerUrl => 'signal-cli serveri URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Signeeritud @$arg1 iga seansi ajal.';
  }

  @override
  String get signedInDevices => 'Sisselogitud seadmed';

  @override
  String get signedInWithin24Hours => 'Sisse logitud 24 tunni jooksul';

  @override
  String get signingSecret => 'Allkirjastamise saladus';

  @override
  String sinceArg1(Object? arg1) {
    return 'Alates $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'alates $arg1';
  }

  @override
  String get singleMessage => 'Üksik sõnum';

  @override
  String get singleUse => 'Ühekordseks kasutamiseks';

  @override
  String get skill => 'Oskus';

  @override
  String get skillChanges => 'Oskuste muudatused';

  @override
  String get skillContent => 'Oskuste sisu';

  @override
  String get skills => 'Oskused';

  @override
  String get skip => 'Jäta vahele';

  @override
  String get skipForNow => 'Jäta praegu vahele';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Enne mudeli kutsumist jätke see ülesanne vahele.';

  @override
  String get slackMessageReceived => 'Sõnum vastu võetud';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Magage $arg1 seansse';
  }

  @override
  String get smartSelector => 'nutikas valija';

  @override
  String get smartSelector2 => 'Nutikas valija';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP host';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp-posti saatja parool tls-i kinnitusteatised lähtestatakse';

  @override
  String get smtpPassword => 'SMTP parool';

  @override
  String get smtpPort => 'SMTP port';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP-port peab olema täisarv vahemikus 1 kuni 65535.';

  @override
  String get smtpUsername => 'SMTP kasutajanimi';

  @override
  String get soTheRunStartsThatMuch => 'nii et jooks algab palju varem.';

  @override
  String get socialBehaviorOff => 'Sotsiaalne käitumine maha';

  @override
  String get socialIntelligence => 'sotsiaalne intelligentsus';

  @override
  String get socialIntelligence2 => 'Sotsiaalne intelligentsus';

  @override
  String get socialObservability => 'Sotsiaalne jälgitavus';

  @override
  String get socialReach => 'sotsiaalne haare';

  @override
  String get socialReach2 => 'Sotsiaalne haare';

  @override
  String get socialReach3 => 'Sotsiaalne haare';

  @override
  String get socialReachUpdated => 'Sotsiaalset katvust värskendati.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Suhtlusallikate agendid saavad otse lugeda, sealhulgas vooge, hoidlaid, Redditi, X-i, videoid ja küpsistega tagatud turuandmeid.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Midagi läks valesti. Palun proovi uuesti.';

  @override
  String get source => 'Allikas';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Kui see agent vestlust alustab, kasutatakse ruumi või vestluse ID-d.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space\'i veebihaagi ja rakenduse tagasihelistamise tugi';

  @override
  String get speaking => 'Rääkimine';

  @override
  String get speechToSpeechModelUsingThe =>
      'kõne-kõneks mudel, kasutades OpenAI või Google\'i klahvi all ';

  @override
  String get speechToText => 'Kõne tekstiks';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Kõne tekstiks transkribeerib häälmärkmeid ja dikteerimist. Automaatne kasutab OpenAI-d, Geminit või Deepgrami, olenevalt sellest, kummal on API-võti. Häälvastuse mudel on vestlusmudel, mis vastab häälmärkmetele.';

  @override
  String get sqlConsole => 'SQL-konsool';

  @override
  String get stable => 'Stabiilne';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable installib uusima avaldatud taustaprogrammi versiooni.';

  @override
  String get stackTrace => 'virna jälg';

  @override
  String get standard => 'Standardne';

  @override
  String get standardView => 'Standardvaade';

  @override
  String get start => 'Alusta';

  @override
  String get startASessionToPlanOr =>
      'Alustage seanssi, et NeoAgentiga planeerida või ehitada.';

  @override
  String get startAndroid => 'Käivitage Android';

  @override
  String get startComputer => 'Käivitage arvuti';

  @override
  String get startFullSetup => 'Alustage täielikku seadistamist';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Alusta seadistamist';

  @override
  String get startTalking => 'Hakka rääkima';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Käivitage esmalt Android-telefon ja seejärel pukseerige siia apk- või apks-fail.';

  @override
  String get startTheServerLaterFromThe =>
      'Pärast konfiguratsiooni salvestamist käivitage server hiljem loendist.';

  @override
  String get startWithARecommendedTask => 'Alustage soovitatud ülesandega';

  @override
  String get startingAndroid => 'Androidi käivitamine';

  @override
  String get startingYourComputer => 'Arvuti käivitamine';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Algab xoxb-. Teie Slacki rakenduse mandaatidest.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Error: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistika jookseb märgid kasutajate diagrammid edukuse määra';

  @override
  String get status => 'Olek';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'olekuandmebaasi käitusaja VM pakkujad';

  @override
  String get statusIsNotLoadedYet => 'Olek pole veel laaditud.';

  @override
  String get stayManagedByYou => 'jääge teie juhiks.';

  @override
  String get stayOnTheCall => 'Jätkake kõnet';

  @override
  String get stayedQuiet => 'Jäi vaikseks';

  @override
  String get steering => 'ROOL';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'SAMM $arg1 OF $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Sammud $arg1';
  }

  @override
  String get stop => 'Peata';

  @override
  String get stop2 => 'Peata (⌘.)';

  @override
  String get stopManaging => 'Lõpetage haldamine';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Kas lõpetada $arg1 haldamine?';
  }

  @override
  String get stopRun => 'Lõpeta jooksmine';

  @override
  String get stopSpeaking => 'Lõpeta rääkimine';

  @override
  String get stoppedBeforeCompletion => 'Peatatud enne lõpetamist';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Error: $arg1';
  }

  @override
  String get storage => 'Säilitamine';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'salvestatakse krüpteeritult ja kasutatakse ainult teie enda jooksude jaoks.';

  @override
  String get storedMetrics => 'Salvestatud mõõdikud';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Salvestab ainult sellesse serverisse krüptitud Bitwardeni seansivõtme, nii et ühendused jäävad taaskäivitamise ellu. Saate selle igal ajal lukustada.';

  @override
  String get strong => 'Tugev';

  @override
  String get strongPassword => 'Tugev parool.';

  @override
  String get subAgent => 'Alamagent';

  @override
  String get subagentUpdate => 'Alamagendi värskendus';

  @override
  String get subagentUpdate2 => 'Alamagendi värskendus.';

  @override
  String get successRate => 'Edukuse määr';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Soovitused: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Võta kokku minu viimane jooks';

  @override
  String get supportUrl => 'Toe URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Toetatud: rain_start, snow_start, wind_alert, temperatuur_üle, temperatuur_alla';

  @override
  String get switchAgent => 'Vahetage agenti';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Sümboolsed lingid ei ole NeoAgent Workspace\'i teedel lubatud.';

  @override
  String get syncNow => 'Sünkrooni kohe';

  @override
  String get synologyChat => 'Synology vestlus';

  @override
  String get systemPrivacySettings => 'Süsteemi privaatsusseaded';

  @override
  String get tableInfoUsers => 'Tabeliteave (kasutajad)';

  @override
  String get tagsOnly => 'Ainult sildid';

  @override
  String get tasks => 'Ülesanded';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Ülesanded töötavad iseseisvalt ja saadavad teile sõnumi ';

  @override
  String get teach => 'Õpetada';

  @override
  String get teachingInProgress => 'Õppetöö pooleli';

  @override
  String get team => 'Meeskond';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Meeskonnalingid ei tee kellestki kunagi serveri administraatorit. Administraatorid juhivad ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Meeskonnaruumid, ruumid, kanalid ja reaalajas kogukonnad.';

  @override
  String get teamsMessageReceived => 'Meeskondade sõnum vastu võetud';

  @override
  String get templates => 'Mallid';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Ajutised seadistusfailid puhastatakse hiljem.';

  @override
  String get tenantId => 'Üürniku ID';

  @override
  String get testConnection => 'Katsetage ühendust';

  @override
  String get testConnection2 => 'Testi ühendus';

  @override
  String get textChat => 'Tekst ja vestlus';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'mis lisasid oma võtme, jätkavad selle kasutamist.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'See e-kiri kuulub juba olemasolevale kontole. Logige esmalt sisse ja seejärel linkige konto seadetes Google.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'See meil on juba lingitud teise kontoga.';

  @override
  String get thatQrCodeIsNotA =>
      'See QR-kood ei ole NeoAgenti sisselogimistaotlus.';

  @override
  String get thatQrCodeIsNotA2 =>
      'See QR-kood ei ole NeoAgenti sidumistaotlus.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'See turvavõti on sellel kontol juba registreeritud.';

  @override
  String get theAddress => 'Aadress';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Teie BlueBubblesi serveri aadress.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Aadress, mida inimesed ja OAuthi pakkujad kasutavad ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agent loeb teie mainitud aegu ja käivitab selles ajavööndis ajastatud ülesandeid.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agent küsib enne iga tundlikku tööriista, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Agent ignoreerib seda oskust.';

  @override
  String get theAppCouldNotReachThis =>
      'Rakendus ei saanud selle NeoAgenti juurutusega ühendust. Kontrollige oma võrguühendust või veenduge, et teenuse URL on õige.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Brauser blokeeris päringu aadressile $arg1 sisu turbepoliitika tõttu.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Brauser blokeeris nõutud taotluse sisu turbepoliitika tõttu.';

  @override
  String get theCloudWorkspace => 'pilve tööruum';

  @override
  String get theComputerCouldNotStart => 'Arvuti ei saanud käivituda';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Arvuti vajab NeoAgenti hostis rohkem vaba kettaruumi. Vabastage ruumi ja proovige uuesti.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Arvuti käitusaeg vajab remonti. Käivitage NeoAgent Doctor ja proovige uuesti.';

  @override
  String get theConnectionTestFailed => 'Ühenduse test ebaõnnestus.';

  @override
  String get theDesktopDidNotStart => 'Töölaud ei käivitunud';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Avastatud NeoAgent tagastas mittetäielikud isikuandmed.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Avastatud NeoAgent kasutab toetamata häälestusprotokolli.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Avastatud teenus ei ole NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Allalaaditud NeoAgenti käituskeskkond ei läbinud kinnitust.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Google\'i vestlusruumi veebihaak, kuhu see agent peaks postitama.';

  @override
  String get theInstallerIsNoLongerAvailable => 'Installer pole enam saadaval.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktiivne Linuxi töölaud on saadaval veebirakenduses NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Sissejuhatus pole selles seadmes saadaval.';

  @override
  String get theLatestRunsAcrossEveryAccount => 'Uusim jookseb igal kontol.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Viimane sünkroonimisaken lõppes $arg1 ja ei leidnud ühtegi uut Health Connecti kirjet. Allpool olevad salvestatud mõõdikud pärinevad varasematest sünkroonimistest.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Linuxi graafiline seanss ei tööta.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Otsehääle mudel ei vastanud. Proovi uuesti.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Kohalik NeoAgenti käsk väljus koodiga $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Kohaliku NeoAgenti käsk aegus.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Kohalik NeoAgenti käituskeskkond vajab parandamist.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Kohalik käitusaeg vajab remonti ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Kohaliku kasutaja kodukataloog pole saadaval.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Meilikonto NeoAgent saadab registreerumise kinnitused, sisselogimine ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Peaagent luuakse vajadusel automaatselt.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Sellest versioonist puudub sobiv NeoAgenti käitusaeg.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Kõige olulisem sissetulev veebihaak, kuhu see agent peaks postitama.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Mudelid, mille vahel Smart Selector suunab automaatselt.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'NeoAgenti taustaprogrammi allalaadimine ei vastanud selle manifestile.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'NeoAgenti taustaprogrammi allalaadimine oli poolik.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Selle arvuti NeoAgenti taustaprogramm ei vasta pordi kaudu ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'NeoAgenti taustaprogrammi käituskeskkonda ei saanud alla laadida.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'NeoAgenti taustaprogrammil kulus $arg1 jaoks vastamine liiga kaua.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'NeoAgenti juurutus vastas kehtetute mandaatide korral tavapärase 401 asemel HTTP 402-ga. Kontrollige selle serveri pöördpuhverserverit, autentimislüüsi või maksetega seotud reegleid.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'NeoAgenti juurutus vastas HTTP 402-ga.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'NeoAgenti juurutus vastas HTTP 402-ga. Kontrollige selle serveri pöördpuhverserveri, autentimislüüsi või maksetega seotud reegleid.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'NeoAgenti eksemplar, millega see rakendus on ühendatud.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'NeoAgenti väljalasketeenus tagastas kehtetud andmed.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'NeoAgenti käitusaja artefakti metaandmed on kehtetud.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'NeoAgenti käitusaegne manifest ei läbinud allkirja kontrollimist.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'NeoAgenti käitusaegsel manifestil pole artefakte.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'NeoAgenti käitusaegse manifesti allkiri on kehtetu.';

  @override
  String get thePasswordYouSetInBluebubbles => 'BlueBubblesis määratud parool.';

  @override
  String get thePeopleYouManageStayWith =>
      'Inimesed, keda juhite, jäävad teie juurde.';

  @override
  String get theProviderAnswers => 'teenusepakkuja vastab.';

  @override
  String get theQueryReturnedNoRows => 'Päring ei andnud ühtegi rida.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Taotletud töölauakuva pole saadaval.';

  @override
  String get theRest => 'ülejäänud.';

  @override
  String get theRestEndpointForYourSignal =>
      'Signaalikliendi eksemplari REST lõpp-punkt.';

  @override
  String get theRunIsPausedUntilYou => 'Jooks peatatakse, kuni vastate.';

  @override
  String get theRunStartsAtTheScheduled => 'Jooks algab ettenähtud ajal.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Käitusaeg on kerge Debian Linuxi töölaud, millel on Chromium, PCManFM, Mousepad, LXTerminal, Python, Git ja standardsed käsurea tööriistad. Selle võimsust haldab NeoAgenti host.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Turvavõtme registreerimist ei saanud alustada.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'server jätab sellest ainult sõrmejälje.';

  @override
  String get theServerOnThisComputerIs => 'Selle arvuti server ei tööta';

  @override
  String get theServerReportedNoHealthChecks =>
      'Server ei teatanud tervisekontrollist.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Signaali telefoninumber, mida see robot kasutab.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Teamsi sissetulevate sõnumite veebihaak, kuhu see agent peaks postitama.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Kahefaktoriline väljakutse aegus. Logige uuesti sisse.';

  @override
  String get theTwoFactorCodeIsNot => 'Kahefaktoriline kood ei kehti.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Kontrollitud käitusaja paketti ei saanud käivitatavaks märkida.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Kinnitatud käitusaja paketis puuduvad nõutavad failid.';

  @override
  String get theWebAppCouldNotReach =>
      'Veebirakendus ei saanud ühendust NeoAgenti taustaprogrammiga.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Veebirakendus ei pääsenud NeoAgenti taustaprogrammi aadressil $arg1. Kontrollige brauseri konsooli ja pöördpuhverserveri/võrgu konfiguratsiooni.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'ise; serveri operaator eemaldab kõigepealt administraatori ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Need kanalid vaikivad. Nendest uuesti kuulmiseks lisage nad jaotisesse Kes saavad selle platvormi jaoks sõnumeid saata.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Need loendid on valikulised, välja arvatud juhul, kui ülaltoodud jaotis on määratud ainult heakskiidetuks.';

  @override
  String get thesePeopleAnywhere => 'Need inimesed kõikjal';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Need inimesed saavad $arg1-le sõnumeid privaatvestlustes ja mis tahes jagatud grupis.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Need inimesed saavad $arg1-le üks-ühele sõnumeid saata. See ei lase neil rühmades rääkida.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Need inimesed saavad $arg1-le sõnumeid saata ainult teie valitud grupis.';
  }

  @override
  String get thesePeopleInOneGroup => 'Need inimesed ühes grupis';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'need lülitid, mitte kunagi teie vestlused, mälestused ega failid.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'See konto avab NeoAgenti selles masinas.';

  @override
  String get thisAgentCanDelegateToAny =>
      'See agent saab delegeerida mis tahes sobivale vastuvõtvale agendile.';

  @override
  String get thisAgentIsUsingAServer =>
      'See agent kasutab serveri hallatavat Trello API võtit. Teil on vaja ainult allolevat kontoluba autoriseerida.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Sellel järgul ei ole lubatud selle NeoAgenti juurutusega suhelda.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'See kood kuulub teisele NeoAgenti serverile: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'See töölaud on ühendatud';

  @override
  String get thisDevice => 'See seade';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'See seade: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'See seade ei saa turvavõtmeid registreerida. Selle lisamiseks avage HTTPS-i kaudu brauseris NeoAgent.';

  @override
  String get thisDeviceUnavailable => 'See seade – pole saadaval';

  @override
  String get thisFileHasNoContent => 'Sellel failil pole sisu.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'See peidab \"$arg1\" marsruudi ja valiku eest.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'See integratsioon toetab praegu ühte ühendatud kontot agendi kohta. Selle asendamiseks avage seadistus uuesti.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'See integratsioon pole enam saadaval.';

  @override
  String get thisIntroIsDesignedForFull =>
      'See sissejuhatus on mõeldud täisekraanil maastiku taasesitamiseks.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'See on hallatud juurutus. Selle operaator veereb välja ';

  @override
  String get thisMayTakeAMoment => 'See võib võtta hetke.';

  @override
  String get thisMcpServerIsNoLonger =>
      'See MCP-server pole enam konfigureeritud.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'See mälu eemaldatakse jäädavalt.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'See NeoAgenti järg ei ole konfigureeritud taustaprogrammi käitusaegade kontrollimiseks.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'See kustutab jäädavalt kõik teie andmed ja seda ei saa teha ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'See kustutab jäädavalt konto ja kõik sellele kuuluva: ';

  @override
  String get thisPersonAnywhere => 'See inimene, ükskõik kus';

  @override
  String get thisPersonInOneGroup => 'See inimene ühes grupis';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'See QR-i sisselogimistaotlus aegus. Looge uus kood ja proovige uuesti.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'see qr-i sisselogimistaotlus on aegunud';

  @override
  String get thisQrLoginRequestIsStill =>
      'See QR-sisselogimistaotlus ootab endiselt kinnitamist.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Seda QR-sisselogimistaotlust kasutati juba.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'See eemaldab selle agendi koduabilise seadistuse ja ühendatud eksemplari.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'See eemaldab selle agendi NeoRecalli taustaprogrammi URL-i ja kõik ühendatud NeoRecalli kontod.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'See eemaldab selle agendi Nextcloudi URL-i ja kõik ühendatud Nextcloudi kontod.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'See eemaldab selle agendi Trello seadistuse ja ühendatud kontod.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Selleks on vaja autentitud seanssi samas NeoAgenti serveris.';

  @override
  String get thisRunDidNotProduceA =>
      'See käitamine ei andnud kasutajale suunatud vastust.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Sellel jooksul pole salvestatud sammuandmeid.';

  @override
  String get thisServer => 'see server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'See server ei teata pakkuja seadetest.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Seda oskust pole enam installitud.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Seda ülesannet pole veel lõpule viidud, seega algab see ikka kell ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Seda ülesannet käivitatakse ainult siis, kui vajutate Käivita kohe.';

  @override
  String get thisWeek => 'Sel nädalal';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'See impordib vastuse $arg1-sse.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'See eemaldab \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'See eemaldab \"$arg1\" serverite loendist.';
  }

  @override
  String get time => 'Aeg';

  @override
  String get timeZone => 'ajavöönd';

  @override
  String get timeZone2 => 'Ajavöönd';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Aeg läbi $arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Ajavööndeid ei saanud loetleda: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Seadme ajavööndit ei õnnestunud lugeda: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Seadme ajavööndit ei saanud salvestada: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'kuni $arg1';
  }

  @override
  String get toUseTheServerDefault => 'serveri vaikeväärtuse kasutamiseks.';

  @override
  String get today => 'Täna';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return '@$arg1 märgieelarve. Jätke väli tühjaks ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Token-eelarve iga konto jaoks ilma oma alistamiseta. Jäta a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'märgi eelarvelimiit 4 tundi nädalase kvoodi kasutaja';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'märgieelarve limiit 4-tunnine nädalakvoot ülemaailmne';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Märgi kasutamine pole selles serveri versioonis saadaval.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Märgid, mida iga konto saab kasutada 4 tunni jooksul.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Märgid, mida iga konto võib kasutada 7 päeva jooksul.';

  @override
  String get tokensPerDay => 'Tokenid päevas';

  @override
  String get tokensPerRun => 'Tokenid jooksu kohta';

  @override
  String get tokensToday => 'Tokenid täna';

  @override
  String get tokensUsed => ' kasutatud märgid';

  @override
  String get tomorrowPrep => 'Homme ettevalmistus';

  @override
  String get tooManyAttempts => 'liiga palju katseid';

  @override
  String get tooManySignInAttemptsPlease =>
      'Liiga palju sisselogimiskatseid. Palun oodake ja proovige uuesti.';

  @override
  String get tool => 'Tööriist';

  @override
  String get toolApproval => 'Tööriista heakskiit';

  @override
  String get toolApprovalRequired => 'Nõutav tööriista kinnitus';

  @override
  String get toolCompleted => 'Tööriist valmis';

  @override
  String get toolFailed => 'Tööriist ebaõnnestus';

  @override
  String get toolPermissions => 'Tööriista load';

  @override
  String get toolStarted => 'Tööriist käivitatud';

  @override
  String get tools => 'Tööriistad';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Tööriistad, mis pole NeoAgenti sisse ehitatud, sealhulgas ühendatud MCP-serverid ja kohandatud tööriistade pakkujad.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Pakutavad tööriistad ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Tööriistad, mida hallatav konto võib kasutada';

  @override
  String get topUsers => 'Tippkasutajad';

  @override
  String get topUsersAndRecentRuns => 'Tippkasutajad ja hiljutised jooksud';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Kokku: $arg1 märgid $arg2 käitamise ajal';
  }

  @override
  String get totalRuns => 'Jooksud kokku';

  @override
  String get totalTokens => 'Märke kokku';

  @override
  String get totalUsers => 'Kasutajaid kokku';

  @override
  String get transcript => 'Ärakiri';

  @override
  String get transcript2 => 'TRAKTIERIMINE';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkriptsioon ebaõnnestus: $arg1';
  }

  @override
  String get transfer => 'Ülekanne';

  @override
  String get trelloApiKey => 'Trello API võti';

  @override
  String get trelloApiKeyIsRequired => 'Trello API võti on nõutav.';

  @override
  String get trelloSetup => 'Trello seadistamine';

  @override
  String get triggerType => 'Päästiku tüüp';

  @override
  String get tryABroaderSearchLikeModels =>
      'Proovige laiemat otsingut, nagu mudelid, brauser või hääl.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Proovige teenusepakkuja nime, \"e-post\", \"limiidid\", \"värskendus\" või \"logid\".';

  @override
  String get tryAgain => 'Proovi uuesti';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Proovi uuesti. Kui see kordub, käivitage arvuti käitusaja kontrollimiseks NeoAgent Doctor.';

  @override
  String get tryAgainInAMoment => 'Proovige hetke pärast uuesti.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Proovige uuesti või käivitage NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Proovige teist otsingut, ühendage sõnumsideplatvorm või sisestage sihtkoha ID käsitsi.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Lülitage rühm sisse, kui $arg1 peaks lugema ka sõnumeid, mis seda ei märgista.';
  }

  @override
  String get turnOffComputer => 'Lülitage arvuti välja';

  @override
  String get turnOffOnlyForAMail =>
      'Lülitage välja ainult iseallkirjastatud sertifikaadiga meiliserveri puhul.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Lülitage sisse, kui signaal peaks jätkuvalt sissetulevaid vestlusi otsima.';

  @override
  String get turnTaking => 'pöörde võtmine';

  @override
  String get turnTakingModel => 'Pööratud mudel';

  @override
  String get turnTakingOff => 'Väljalülitamine';

  @override
  String get turnThisOffToKeepThis =>
      'Lülitage see välja, et hoida seda agenti teistest agentidest täielikult lahus.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Lülitas välja $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Selle konto haldaja $arg1 lülitas selle välja. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return '$arg1 lülitas selle teie jaoks välja – ainult nemad saavad seda muuta';
  }

  @override
  String get turnedOffForYouSoYou =>
      'See on teie jaoks välja lülitatud, nii et te ei saa seda välja anda';

  @override
  String get twitchChatOverIrc => 'Twitch vestlus IRC kaudu';

  @override
  String get twoFactorAuthentication => 'Kahefaktoriline autentimine';

  @override
  String get twoFactorChallengeExpired => 'kahefaktoriline väljakutse aegus';

  @override
  String get twoFactorCode => 'kahefaktoriline kood';

  @override
  String get twoFactorSignInCompletedBut =>
      'Kahefaktoriline sisselogimine lõpetati, kuid NeoAgent ei suutnud brauseri seanssi jätkata. Palun logige uuesti sisse.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Kaheastmeline sisselogimine (ainult siis, kui see on lubatud)';

  @override
  String get type => 'Tüüp';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Kinnitamiseks tippige $arg1';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'tüüpi teksti sellel platvormil ei toetata.';

  @override
  String get typedInTheBrowser => 'Sisestati brauserisse';

  @override
  String get typedText => 'Trükitud tekst';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'ei suuda leida java käitusaega';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Selle järgu ajaseadeid ei saa avada.';

  @override
  String get unableToOpenWiFiSettings =>
      'Selle järgu WiFi-seadeid ei saa avada.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Valitud töölauakuva ei saa säilitada.';

  @override
  String get unclearWhoItWasFor => 'Pole selge, kellele see mõeldud oli';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'tagasi võetud. Sisestage kinnitamiseks oma kasutajanimi.';

  @override
  String get unknownAccount => 'Tundmatu konto';

  @override
  String get unknownAgent => 'Tundmatu agent';

  @override
  String get unknownBrowser => 'Tundmatu brauser';

  @override
  String get unknownDevice => 'Tundmatu seade';

  @override
  String get unknownError => 'tundmatu viga';

  @override
  String get unknownLocalComputerPermission => 'Tundmatu kohaliku arvuti luba.';

  @override
  String get unknownLocation => 'Tundmatu asukoht';

  @override
  String get unknownPublishTime => 'Avaldamise aeg teadmata';

  @override
  String get unknownSize => 'Tundmatu suurus';

  @override
  String get unlink => 'Tühista linkimine';

  @override
  String get unreadOnly => 'Ainult lugemata';

  @override
  String get unsavedChanges => 'Salvestamata muudatused';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Toetamata töölaua kaaskäsk: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Toetamata meetod: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Ebatavalised sisselogimishoiatused';

  @override
  String updateArg1(Object? arg1) {
    return 'Värskendage $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Värskendage põhimälu kirjeid impordist.';

  @override
  String get updateNow => 'Värskendage kohe';

  @override
  String get updateReady => 'Värskendus valmis';

  @override
  String get updateSetup => 'Värskenda seadistust';

  @override
  String get updateTheAccessListToAllow =>
      'Vastuste lubamiseks värskendage juurdepääsuloendit.';

  @override
  String get updateTheServer => 'Kas värskendada serverit?';

  @override
  String get updateTheServer2 => 'Värskendage serverit';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Värskendage kasutatavas seadmes ajavööndit automaatselt.';

  @override
  String updatedArg1(Object? arg1) {
    return 'värskendatud $arg1';
  }

  @override
  String get updates => 'Värskendused';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Selle järgu jaoks pole värskendusi konfigureeritud.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'värskendused, seega on enesevärskendused ja kanalimuudatused siin välja lülitatud.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'uuenda värskendus nüüd vabasta kanali stabiilne beetaversioon';

  @override
  String get usageAnalytics => 'Kasutusanalüütika';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Kasutus- ja tervisesignaalid, mis aitavad selgitada praegust käitusaja käitumist ilma logisid esmalt uurimata.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return '$arg1-i kasutus lähtestab täielikult';
  }

  @override
  String get usageLeaderboard => 'kasutamise edetabel';

  @override
  String get usageLimits => 'Kasutus ja piirangud';

  @override
  String get usageLimits2 => 'Kasutus ja piirangud';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Kasutage 8+ tähemärki. Pikemad paroolid töötavad hästi.';

  @override
  String get useADateAndTimeFor =>
      'Kasutage kuupäeva ja kellaaega, näiteks 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Kasutage nime, telefoninumbrit või vestluse ID-d.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Kasutage NeoRecalli URL-i, millele NeoAgent server pääseb. Sellest brauserist peab OAuthi tagasihelistamiseks olema juurdepääsetav ka NeoAgenti PUBLIC_URL.';

  @override
  String get useANewPasswordWithAt =>
      'Kasutage uut vähemalt 8 tähemärgist koosnevat parooli.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Kasutage Nextcloudi URL-i, kuhu NeoAgenti server jõuda, näiteks https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Kasutage vähemalt 8 tähemärgist koosnevat parooli.';

  @override
  String get useASecureConnectionTls => 'Kasutage turvalist ühendust (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Kasutage autentimisrakendust, nagu Authy, 1Password või Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Kasutage vähemalt 1 vCPU-d.';

  @override
  String get maxMemoryPerComputerMb => 'Maksimaalne mälu arvuti kohta (MB)';

  @override
  String get maxVcpusPerComputer => 'Maksimaalne vCPU-d arvuti kohta';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Vähemalt $arg1. Arvutid saavad vähem, kui host on hõivatud.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maksimaalne mälumaht peab olema vähemalt $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Kasutage vähemalt 8 tähemärki.';

  @override
  String get useDefault => 'Kasuta vaikeseadet';

  @override
  String get useDefaultChannel => 'Kasuta vaikekanalit';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Kasuta vaikeseadet (NeoAgent Workspace)';

  @override
  String get useFor => 'Kasutage selleks';

  @override
  String get useManualDestination => 'Kasutage käsitsi sihtkohta';

  @override
  String get useOrDoTheSameFor =>
      'kasutada või teha sama oma meeskonnakaaslaste jaoks.';

  @override
  String get usePerCategorySettingsBelow =>
      'Kasutage allolevaid kategooriapõhiseid seadeid.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Kasuta vaikeseadeid ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Kasutage selles arvutis serverit';

  @override
  String get useTheseForContextIfA =>
      'Kasutage neid konteksti jaoks. Kui kohalikule URI-le pole serverist otse juurdepääs, paluge mul esitada fail juurdepääsetava tööruumi kaudu.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Kasutage seda orkestrantide jaoks. Jätke välja isoleeritud töörobotite jaoks, mis peaksid otsesõnumid ise lõpetama.';

  @override
  String get useTlsFromTheStartOf =>
      'Kasutage TLS-i ühenduse algusest peale, tavaliselt pordis 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Kasutage teenusepakkuja jaoks oma API-võtit või ühendage kohandatud võti ';

  @override
  String get usedByEveryAccountOnThis =>
      'Seda kasutavad kõik selle serveri kontod, millel pole võtit ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Kasutatakse selleks, et kontrollida, kas sissetulevad Slacki sündmused on ehtsad.';

  @override
  String get userSummary => 'Kasutaja kokkuvõte';

  @override
  String get username => 'Kasutajanimi';

  @override
  String get usernameOrEmail => 'Kasutajanimi või email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'kasutajad inimesed otsivad meili kasutajanimi administraatori märk hallatud meeskond';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Kasutab seadetes konfigureeritud vestlusmudelit';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Installitud NeoAgenti käitusaja kasutamine';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Tavaliselt näeb see välja nagu @bot:matrix.org';

  @override
  String get validEmail => 'kehtiv email';

  @override
  String get value => 'Väärtus';

  @override
  String get vaultLocked => 'Võlv lukus';

  @override
  String get vaultOperationFailed => 'Varahoidla toiming ebaõnnestus.';

  @override
  String get verification => 'Kontrollimine';

  @override
  String verificationArg1(Object? arg1) {
    return 'Kinnitus: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'kinnitus: $arg1';
  }

  @override
  String get verificationCompleted => 'Kinnitamine lõpetatud.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Kontrolli olek: $arg1';
  }

  @override
  String get verifiedTheResult => 'Kontrollis tulemust';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Allalaaditud käitusaja kontrollimine';

  @override
  String get versionAndUptime => 'Versioon ja tööaeg';

  @override
  String versionArg1(Object? arg1) {
    return 'Versioon $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Versioon $arg1 on installitud, kuid $arg2 töötab endiselt.';
  }

  @override
  String get videoLinks => 'Video lingid';

  @override
  String get viewDesktop => 'Kuva töölaud';

  @override
  String get viewLastRun => 'Vaata viimast jooksu';

  @override
  String get viewLogs => 'Vaata logisid';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'vm-pildimälu cpu qemu käitusaeg';

  @override
  String get voice => 'Hääl';

  @override
  String get voiceAssistant => 'Hääleabiline';

  @override
  String get voiceCall => 'HÄÄLKÕNE';

  @override
  String get voiceCall2 => 'Häälkõne';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'häälkõne gpt-live gemini live-mudeli kõne reaalajas';

  @override
  String get voiceCallsRunOnALive =>
      'Häälkõned toimuvad reaalajas kõne-kõneks mudelil, millel on sama isik, mälu ja vestluste ajalugu nagu NeoAgent. See vastab kohe ja annab tegeliku töö tavalisele agendile, mis töötab taustal.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'häälmärkus kõne transkriptsiooni API-võti';

  @override
  String get voiceNotesAndDictation => 'Häälnoodid ja dikteerimine';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Hääle taasesitus pole selles seadmes saadaval.';

  @override
  String get voiceReplyModel => 'Häälvastuse mudel';

  @override
  String get waitingForApproval => 'Heakskiidu ootel: ';

  @override
  String get waitingForCode => 'Ootan koodi';

  @override
  String get waitingForInput => 'Ootan sisendit';

  @override
  String get waitingForServerOrFlutterLog =>
      'Serveri või Flutteri logi väljundi ootamine…';

  @override
  String get waitingForTaskEvents => 'Ülesande sündmuste ootamine...';

  @override
  String get waitingForYou => 'ootab sind';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Soovisin vastust kasutajalt $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Tahab teiega rääkida · ${arg1}s';
  }

  @override
  String get weak => 'Nõrk';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Ilm, kalender ja prioriteedid enne teie päeva algust.';

  @override
  String get weatherEvent => 'Ilmasündmus';

  @override
  String get web => 'Veeb';

  @override
  String get webBrowser => 'Veebibrauser';

  @override
  String get webSearchApiKey => 'veebiotsingu API võti';

  @override
  String get webhookOrRestChannelPosting =>
      'Veebihaagi või REST kanali postitamine';

  @override
  String get webhookSecret => 'Veebihaagi saladus';

  @override
  String get webhookUrlCopied => 'Veebihaagi URL on kopeeritud';

  @override
  String get weekdays => 'Argipäevad';

  @override
  String get weekdays0730 => 'Argipäeviti · 07:30';

  @override
  String get weekdays1800 => 'Tööpäeviti · 18:00';

  @override
  String get weekly => 'Iganädalane';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Nädalalimiit $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Nädalalimiit (märgid)';

  @override
  String get weeklyReview => 'Nädala ülevaade';

  @override
  String get weeklyUsage => 'Iganädalane kasutamine';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Kaal $arg1 rekordid';
  }

  @override
  String get welcomeToNeoagent => 'TERE TULEMAST NEOAGENTISSE';

  @override
  String get welcomeToNeoagent2 => 'Tere tulemast\nNeoAgenti';

  @override
  String get whatAreYouAdding => 'Mida sa lisad?';

  @override
  String get whatIsOnTomorrow => 'Mis homme toimub?';

  @override
  String get whatShouldNeoagentLearn => 'Mida peaks NeoAgent õppima?';

  @override
  String get whatShouldWeBuild => 'Mida peaksime ehitama?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'See, mida teie ja NeoAgent ütlete, kuvatakse siin ja vestluses.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Saabus WhatsAppi isiklik sõnum';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Kui valite Ainult heaks kiidetud, lisage allpool inimesi või gruppe.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Kuhu see agent vastused saatma peaks.';

  @override
  String get whoCanMessage => 'Kes saab sõnumit saata';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kes saavad $arg1 kaudu sõnumeid saata';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kes saab $arg1-le üks-ühele sõnumi saata.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kes saab $arg1-ga grupis, kanalis või ruumis rääkida.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kes seda kontot haldab, on välja lülitatud: ';

  @override
  String get whoManagesWhom => 'Kes keda juhib';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Kes lingi vastu võtab, liitub teie meeskonnaga ainult selle tööriistade abil ';

  @override
  String get wholeGroup => 'Terve grupp';

  @override
  String get wholeGroups => 'Terved rühmad';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Miks $arg1 vastas või vaikis $arg2 rühmades?';
  }

  @override
  String get windowsApp => 'Windowsi rakendus';

  @override
  String get windowsNt => 'aknad nt';

  @override
  String get workAccount => 'Töökonto';

  @override
  String get workOnAProjectWithNeoagent =>
      'Töötage NeoAgentiga projekti kallal';

  @override
  String workflowArg1(Object? arg1) {
    return 'Töövoog: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Pilvearvutis $arg1-ga töötamine. NeoAgent loeb ja redigeerib seal faile ning saab käivitada käske ja brauserit.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Töötab taustal: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Tööruumi konfigureerimine ja konto turvalisus ühes kohas.';

  @override
  String get workspaceFiles => 'Tööruumi failid';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Tööruum, mudelid ja diagnostika juhtelemendid.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Tööruumi alistamine peab olema absoluutne tee.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Kirjutas $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttppäringu viga';

  @override
  String get yesterday => 'eile';

  @override
  String get youAreInControl => 'Teie käes on kontroll';

  @override
  String get youCanFollowAlongOnThe => 'Saate seda jälgida töölaual.';

  @override
  String get youCanLeaveATeamAt =>
      'Võite igal ajal meeskonnast lahkuda; teie enda seaded rakenduvad uuesti.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Võite igal ajal lahkuda meeskonna lehelt.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Saate otsustada, milliseid tööriistu teie agent kasutada võib, jaotises Seaded › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Te ei halda veel kedagi. Looge allpool kutselink ja ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Teil on salvestamata seadeid. Mida sa teha tahaksid?';

  @override
  String get youReOnYourOwnYou =>
      'Olete üksi: otsustate, milliseid tööriistu teie agent kasutada võib. Kui ';

  @override
  String get yourAccountAndUsageOnA =>
      'teie konto ja kasutamine teie enda võtmega toetatud mudelil ';

  @override
  String get yourAccountHasBeenDeleted => 'Teie konto on kustutatud.';

  @override
  String get yourAgentWillBeAllowed => 'Teie agendil on lubatud:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Teie rakendused ja failid salvestatakse.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Teie rakendused ja failid jäävad salvestatuks.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Teie $arg1 võti';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Teie abiline jäädvustamise, konteksti ja tegevuse jaoks.';

  @override
  String get yourComputerIsAsleep => 'Teie arvuti magab';

  @override
  String get yourComputerIsOff => 'Teie arvuti on välja lülitatud';

  @override
  String get yourComputerIsReady => 'Teie arvuti on valmis';

  @override
  String get yourCurrentPasswordIsIncorrect => 'Teie praegune parool on vale.';

  @override
  String get yourData => 'Teie andmed';

  @override
  String get yourDataExportWasCopiedTo =>
      'Teie andmete eksport kopeeriti lõikelauale.';

  @override
  String get yourDesktopIsReady => 'Teie töölaud on valmis';

  @override
  String get yourLinuxComputer => 'Teie Linuxi arvuti';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Teie asukohta ei jälgita kunagi pidevalt ega salvestata meie serveritesse. Kasutame seda ainult kohapeal teie aktiivsete ülesannete kontrollimiseks.';

  @override
  String get yourManager => 'teie juht';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Teie Mattermosti saidi URL, kui kasutate REST API-t.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Teie seanss aegus või brauser ei säilitanud seda. Palun logige uuesti sisse.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Teie seanss aegus. Palun logige uuesti sisse.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Teie kasutajanimi või parool on vale.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Ülevaade';

  @override
  String get sectionDiagnostics => 'Diagnostika';

  @override
  String get sectionVolume => 'Helitugevus';

  @override
  String get sectionSession => 'Seanss';

  @override
  String get sectionDeliverable => 'Tarnitav';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Kohalik käituskeskkond pole veel logifaili kirjutanud.';

  @override
  String get thisComputer => 'See arvuti';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beeta installib uusima väljalaskeeelse taustaprogrammi. Oodata karedaid servi.';

  @override
  String get copiedFinalResponse => 'Lõplik vastus on kopeeritud';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Lõplik vastus kuvatakse siin, kui käitamine on lõppenud.';

  @override
  String get waitingForTheFirstStep => 'Oodates esimest sammu…';

  @override
  String get loadingPrompt => 'Viipa laadimine…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Selle jooksu jaoks lõplikku vastust ei saadud.';

  @override
  String get readyToSignIn => 'Sisselogimiseks valmis';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Kinnituskontrolli uuesti lubamiseks lülitage valikule „Vaikimisi” või „Küsi alati”.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Saatke praeguse jooksmise kohta juhtimisvärskendus või järgmine märge...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Võrguühendus puudub. NeoAgent loob ühenduse uuesti, kui seade on taas võrgus.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Praegusele sõidule rakendati uusim roolisüsteemi värskendus.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Privaatse hääleseansi ettevalmistamine…';

  @override
  String get preparingYourComputer => 'Arvuti ettevalmistamine';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent laadib alla ja valmistab ette turvalist Linuxi süsteemi. See juhtub ainult esimest korda.';

  @override
  String get moreFreeSpaceIsNeeded => 'Vaja on rohkem vaba ruumi';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Vabastage NeoAgenti hostis kettaruumi ja proovige uuesti. Teie olemasolevad arvutiandmed on turvalised.';

  @override
  String get androidReady => 'Android valmis';

  @override
  String get startingAndroid2 => 'Androidi käivitamine…';

  @override
  String get androidStopped => 'Android peatus';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Esimesel käivitamisel laaditakse alla Android SDK ja süsteemipilt, mis võib võtta mitu minutit.';

  @override
  String get androidIsStopped => 'Android on peatatud';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Käivitage hallatav Androidi keskkond, kui seda vajate.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Laske NeoAgentil selles arvutis töötada';

  @override
  String get firstTimeSetupIsInProgress =>
      'Esmakordne seadistamine on pooleli.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent saab kasutada teie lubatud juurdepääsu.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Vabastage hosti salvestusruumi ja proovige uuesti.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Alustage siis, kui soovite, et NeoAgent siin aitaks.';

  @override
  String get systemPermissionMissing => 'Süsteemi luba puudub';

  @override
  String get connectingThisDevice => 'Selle seadme ühendamine';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Turvalist kohalikku ühendust luuakse.';

  @override
  String get recordingYourDemonstration => 'Teie demonstratsiooni salvestamine';

  @override
  String get noErrorsInTheRecentLog => 'Hiljutises logis pole vigu.';

  @override
  String get loadingAccounts => 'Kontode laadimine…';

  @override
  String get neverSignedIn => 'Pole kunagi sisse loginud';

  @override
  String get emptyUsesTheServerDefault => 'Tühi kasutab serveri vaikeseadet.';

  @override
  String get followTheSelectedSession => 'Jälgige valitud seanssi';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Planeerimisrežiim kontrollib ainult. Lülituge agendirežiimile, et lubada NeoAgentil faile redigeerida.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Nõutav teie konto e-posti aadressi lisamiseks või muutmiseks.';

  @override
  String get confirmNewPassword => 'Kinnitage uus parool';

  @override
  String get passwordChanged => 'Parool muudetud.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Seda taotlust on juba kasutatud.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'See taotlus on aegunud. Paluge teisel seadmel luua uus kood.';

  @override
  String get startQuickstart => 'Käivitage kiirkäivitus';

  @override
  String get createYourAccount => 'Looge oma konto';

  @override
  String get showWorkAsSummaries => 'Näita tööd kokkuvõtetena';

  @override
  String get tokensUsedByTheLatestRun => 'Viimases käitamises kasutatud märgid';

  @override
  String get listedTheWorkspaceRoot => 'Loetletud tööruumi juur';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Ametlikke integratsioone pole veel saadaval.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'MCP-servereid pole veel konfigureeritud. Lisage üks, et paljastada selle tööriistad.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Alustamiseks lisage MCP-server või installige oskus.';

  @override
  String get setUp => 'Seadistage';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Salvestatud väärtuse säilitamiseks jätke tühjaks';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'See eemaldab selle serveri iga konto aadressi.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Lihtsalt räägi. Saate igal ajal katkestada. Puudutage vaigistamiseks.';

  @override
  String get tapAgainWhenYouAreDone => 'Kui olete lõpetanud, puudutage uuesti.';

  @override
  String get workingOnATaskInTheBackground =>
      'Taustal ülesande kallal töötamine.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Kõnest kõneks sama mälu, tööriistade ja vestluste ajalooga nagu NeoAgent.';

  @override
  String get checkLink => 'Kontrolli linki';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Teie agendile ei lubata ühtegi kontrollitud tööriista.';

  @override
  String get notYoursToChange => 'Pole sinu muuta';

  @override
  String get setByYou => 'Teie poolt määratud';

  @override
  String get noTools => 'Tööriistad puuduvad';

  @override
  String get untitledLink => 'Pealkirjata link';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Lõpetab töötamise pärast seda, kui üks inimene selle lunastab.';

  @override
  String get theOperator => 'Operaator';

  @override
  String get smartSelectorOn => 'Nutikas valija sees';

  @override
  String get startASessionToBegin => 'Alustamiseks alustage seanssi';

  @override
  String get steerTheActiveRun => 'Juhtige aktiivset jooksu…';

  @override
  String get describeWhatToPlan => 'Kirjeldage, mida plaanite…';

  @override
  String get stopDictation => 'Lõpetage dikteerimine';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Sõnumid juhivad jooksvat käitamist · ⌘↵ saada · ⌘. peatus';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Planeerimisrežiim kontrollib ainult; midagi ei muudeta enne, kui rakendate funktsiooni · ⌘↵ saada';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent redigeerib tööruumi. Plaan ainult kontrollib.';

  @override
  String get defaultModel => 'Vaikimisi mudel';

  @override
  String get openingScanner => 'Skänneri avamine...';

  @override
  String get theAgentCanUseThisSkill => 'Agent saab seda oskust kasutada.';

  @override
  String get allSelected => 'Kõik valitud';

  @override
  String get addCoreMemoryEntry => 'Lisage põhimälu sisestus';

  @override
  String get channelId => 'Kanali ID';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'AI-loodud ja täpsustamata ülesanded kasutavad praegust vaikeseadet.';

  @override
  String get waitingForRunEvents => 'Jooksuürituste ootel...';

  @override
  String get hideSteps => 'Peida sammud';

  @override
  String get commitTheActiveLiveCapture =>
      'Tehke aktiivne reaalajas jäädvustamine';

  @override
  String get stopCaptureAndSubmit => 'Lõpetage püüdmine ja esitage';

  @override
  String get clickTheMicToStartSpeaking =>
      'Rääkimise alustamiseks klõpsake mikrofonil';

  @override
  String get connectACustomEndpoint => 'Ühendage kohandatud lõpp-punkt';

  @override
  String get hostedProvider => 'hostitud pakkuja.';

  @override
  String get muted => ' • vaigistatud';

  @override
  String get addWhoCanMessage => 'Lisage, kes saavad sõnumit saata';

  @override
  String get joinsGroupConversations => 'Liitub grupivestlustega';

  @override
  String get label1PersonOrGroupAdded => 'Lisatud on 1 inimene või grupp';

  @override
  String get inProgress => 'Pooleli';

  @override
  String get waitingForUpdateJobOutput => 'Värskendustöö väljundi ootamine…';

  @override
  String get taskTrigger => 'Ülesande käivitaja';

  @override
  String get bearerToken => 'Kandja märk';

  @override
  String get bearerToken2 => 'Kandja märk';

  @override
  String get notRecorded => 'Ei salvestatud';

  @override
  String get sessionCookie => 'Seansi küpsis';

  @override
  String get neverUsed => 'Pole kordagi kasutatud';

  @override
  String get linkedRecently => 'Lingitud hiljuti';

  @override
  String get notUsedYet => 'Pole veel kasutatud';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Üks või mitu kontot on aegunud. Juurdepääsu taastamiseks ühendage uuesti. Kui see kordub, võib teie Google Cloud OAuthi rakendus olla testimisrežiimis – avaldage see Google Cloud Console\'i ​​tootmisüksuses, et saada pikaealised žetoonid.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault on ühendatud ja saadaval pärast taaskäivitamist';

  @override
  String get vaultConnectedForThisSession =>
      'Selle seansi jaoks on võlv ühendatud';

  @override
  String get connectAnotherAccount => 'Ühendage teine konto';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Kleepige asendus pikaealine juurdepääsuluba';

  @override
  String get updateInstance => 'Värskenda eksemplari';

  @override
  String get pasteAReplacementToken => 'Kleepige asendusmärk';

  @override
  String get replaceAccount => 'Asenda konto';

  @override
  String get addAccount => 'Lisa konto';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Saab delegeerida mis tahes vastuvõtvale agendile';

  @override
  String get canReceiveDelegatedTasks2 =>
      'saab vastu võtta delegeeritud ülesandeid';

  @override
  String get noSyncYet => 'Sünkroonimist veel pole';

  @override
  String get noNewData => 'Uusi andmeid pole';

  @override
  String get syncOnceToSeedYourBackend =>
      'Taustaprogrammi külvamiseks sünkroonige üks kord.';

  @override
  String get lastWindowEndIsUnknown => 'Viimane akna ots on teadmata.';

  @override
  String get lastNonEmptySync => 'Viimane mittetühi sünkroonimine';

  @override
  String get stopTranscribe => 'Peata ja transkribeeri';

  @override
  String get steeringMode => 'Juhtimisrežiim';

  @override
  String get noMessageText => 'Sõnumi teksti pole';

  @override
  String get reconnectingToServer => 'Serveriga taasühendamine…';

  @override
  String get signingIn => 'Sisselogimine...';

  @override
  String get noGroupsFoundYet => 'Ühtegi gruppi pole veel leitud';

  @override
  String get onForNewGroupsOnly => 'Sees ainult uutele gruppidele';

  @override
  String get noGroupsInThisCategory => 'Selles kategoorias pole gruppe';

  @override
  String get groupOrChannel => 'Grupp või kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Endale kirjutatud märkmed alustavad jooksu ja vastused jõuavad samasse vestlusesse. Lubatud nimekiri siin ei kehti.';

  @override
  String get needToReply => 'Vaja vastata';

  @override
  String get enter2faCode => 'Sisestage 2FA kood';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Avage autentimisrakendus ja sisestage praegune NeoAgenti kood.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Kas teil on juba konto? Logi sisse';

  @override
  String get serverOnThisComputer => 'Server selles arvutis';

  @override
  String get showQrCode => 'Kuva QR-kood';

  @override
  String get createAnotherNeoagentAccount => 'Looge teine NeoAgenti konto.';

  @override
  String get canCoordinateDelegatedWork =>
      'Oskab koordineerida delegeeritud tööd';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'NeoAgenti käitusaegset arhiivi ei saanud ekstraktida.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'NeoAgenti käitusaegset arhiivi ei saanud lugeda.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'NeoAgenti käitusaegne arhiiv sisaldab ebaturvalist teed.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'NeoAgenti käitusaegne arhiiv sisaldab ebaturvalist linki.';

  @override
  String get installingAppPackageOnThePhone =>
      'Rakendusepaketi installimine telefoni...';

  @override
  String get dragAndDropAApkOrApks =>
      'Lohistage apk- või apks-fail siia või klõpsake sirvimiseks.';

  @override
  String get releaseToInstallThisPackage =>
      'Selle paketi installimiseks vabastage';

  @override
  String get theSecurityKeyCouldNotBeUsed => 'Turvavõtit ei saanud kasutada.';

  @override
  String get connecting => 'Ühendamine…';

  @override
  String get changes => 'Muudatused';

  @override
  String get runtimeReady => 'Tööaeg valmis';

  @override
  String get saving => 'Salvestamine...';

  @override
  String get earlier => 'Varem';

  @override
  String get monthJan => 'jaan';

  @override
  String get monthFeb => 'veebr';

  @override
  String get monthMar => 'märts';

  @override
  String get monthApr => 'apr';

  @override
  String get monthMay => 'mai';

  @override
  String get monthJun => 'juuni';

  @override
  String get monthJul => 'juuli';

  @override
  String get monthAug => 'augustil';

  @override
  String get monthSep => 'sept';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'dets';

  @override
  String get steeringWord => 'Juhtimine';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'See lülitab taustaprogrammi $arg1 kanalilt $arg2 kanalile.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Imporditud $arg1 küpsised';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s tagasi';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Järjekorras rool: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Veebirakendus ei saanud ühendust NeoAgenti taustaprogrammiga.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Brauser blokeeris nõutud taotluse sisu turbepoliitika tõttu.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 4-st lubatud';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Töötage ülesandega nagu tavaliselt.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Muudatused · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'See seade · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limiit on saavutatud$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 taastekoodid on endiselt saadaval.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Turvavõti $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Praegune seanss';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nViimati kasutatud: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Töötab selles seadmes $arg1-s. NeoAgent loeb ja redigeerib kausta otse ning saab käivitada käske, avada rakendusi ja kasutada ekraani.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Töötas $arg1 jaoks';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Lubatud: $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 kutselingid saidilt $arg2 tühistati';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Lisage inimesed ja rühmad, kellega $arg1 peaks rääkima';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Lisage inimesed ja rühmad, kellega $arg1-l on lubatud rääkida.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Kus $arg1 kuulab';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 jälgib neid kohti mainimiseks. Siia saab postitada igaüks, seega vajavad inimesed allpool siiski oma nõusolekut.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Need inimesed saavad $arg1-lt küsida kõikjal, kus nad selle märgistavad. Rollid loevad ainult ülaltoodud kohtades.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Ainult siis, kui $arg1 on märgistatud';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Sees kõigi $arg1 rühmade jaoks';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 kuuleb endiselt ainult inimesi ja gruppe, mille olete juba heaks kiitnud. See võimaldab $arg1-l lihtsalt liituda tavalise vestlusega, mitte ainult siltide ja vastustega.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 kuuleb endiselt ainult inimesi ja gruppe, mille olete juba heaks kiitnud. See lihtsalt valib, millise rühmaga ta peaks liituma.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Kui keegi märgib $arg1 või vastab, vastab $arg1 alati. Lülitage see sisse, kui $arg1 peaks helistama ka tavalises grupivestluses.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Uued grupid lubavad $arg1-l liituda tavalise vestlusega heakskiidetud inimestega, kuni need välja lülitate.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Uued grupid lubavad $arg1-l tavavestlusega liituda, kuni need välja lülitate.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Uued grupid jäävad vaikseks, välja arvatud juhul, kui heakskiidetud isik märgista $arg1, kuni need sisse lülitate.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Ainult siis, kui heakskiidetud isik märgib $arg1, välja arvatud juhul, kui lülitate rühma sisse';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Ainult siis, kui $arg1 on märgistatud, välja arvatud juhul, kui lülitate rühma sisse';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 rühmast $arg2 liitub tavalise vestlusega heakskiidetud inimestega';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'See ei kiida uusi inimesi heaks. Heakskiidetud inimeste sildid ja vastused saavad alati vastuse. Lülitage grupp sisse, kui $arg1 peaks seal ka tavalise vestlusega liituma.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'See ei kiida uusi inimesi heaks. Lülitage grupp sisse, kui $arg1 peaks liituma tavalise vestlusega inimestega, kelle olete juba heaks kiitnud.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Sildid ja vastused saavad alati vastuse. Lülitage grupp sisse, kui $arg1 peaks seal ka tavalise vestlusega liituma.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 liitub tavalise vestlusega heakskiidetud inimestega';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 saab liituda tavalise vestlusega';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 vastab ainult siis, kui heakskiidetud isik märgib selle';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Midagi lisa pole vaja. Ühendage $arg1 kasutamise alustamiseks.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Värskendab ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registreeruge $arg1-ga';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return '\"$arg1\"-ga pole seotud ühtegi mälestust.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (vaikeseade)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filiaal: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 liitub ainult nende rühmade ja kanalitega, mille allpool lisate.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 on vajalik NeoAgenti käitusaja andmete leidmiseks.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[kärbitud eelvaade, $arg1 baiti kokku]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakt piiratud, $arg1 baiti kokku]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' in $arg1';
  }

  @override
  String get worldNews => 'Maailmauudised';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Käivitage, kui ilmuvad uued maailmapealkirjad. Teie viip otsustab, kas teid teavitada.';

  @override
  String get newsKeywordsOptional => 'Märksõnad (valikuline)';

  @override
  String get worldNewsSetup => 'Maailmauudiste seadistus';

  @override
  String get connectWorldNewsWithGnews =>
      'Lisage GNewsi API võti (tasuta plaan on saadaval aadressil gnews.io). See salvestatakse krüpteeritult ja seda kasutatakse World Newsi käivitajate peamiste pealkirjade küsitlemiseks.';

  @override
  String get gnewsApiKey => 'GNewsi API võti';

  @override
  String get pasteReplacementGnewsApiKey => 'Kleepige GNewsi API asendusvõti';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Hetkel salvestatud võtme säilitamiseks jätke võti tühjaks.';

  @override
  String get gnewsApiKeyIsRequired => 'Vaja on GNewsi API võtit.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'World Newsi seadistust ei saanud salvestada.';

  @override
  String get disconnectWorldNews => 'Katkesta maailmauudiste ühendus';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'See eemaldab salvestatud GNewsi API-võtme. World Newsi päästikud lõpetavad käivitumise, kuni lisate uuesti võtme.';

  @override
  String get couldNotDisconnectWorldNews =>
      'World Newsi ühendust ei saanud katkestada.';

  @override
  String get systemOneModels => 'SystemOne mudelid';

  @override
  String get systemOneAuto => 'Automaatne';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Valib parima saadaoleva SystemOne\'i mudeli';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Vestlusmudel teeb need otsused';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Otsustusmudelid, mis teevad telgitagused kõned sekundi murdosaga: grupivestluse käiguvahetus ja brauseri sammud. Teie vestlusmudel kirjutab endiselt iga vastuse.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'SystemOne\'i mudel otsustab, millal rääkida, kui see on sisse lülitatud; see mudel on varu.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 skoori SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne hindas selle sõnumi otse. Ükski keelemudel ei jooksnud.';

  @override
  String get systemOneUnavailable => 'SystemOne pole saadaval';

  @override
  String get systemOneAdminAvailability =>
      'Otsustusmudelite agendid saavad valida jaotises Seaded › Mudelid. Siin välja lülitatud mudel jätab valija ja selle valinud agendid naasevad automaatsele. Kui kõik mudelid on välja lülitatud, lülitatakse välja ka SystemOne\'i mudelid, mille pakkujad hiljem lisavad.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'SystemOne\'i mudeleid veel pole. Lisage teenusepakkujate alla TypeSafe\'i või OpenRouteri võti või tõmmake Ollama 0.35 või uuema versiooniga otsustusmudel, näiteks nimble.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Ükski SystemOne\'i mudel pole veel saadaval. Lisage TypeSafe\'i või OpenRouteri võti jaotises Seaded › Mudelid › Tooge oma võti või tõmmake otsustusmudel, nt Ollamas.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone süsteem üks otsustusmudelid jev typesafe openrouter ollama kättesaadavus lubama keelata';

  @override
  String get chatModels => 'Vestlusmudelid';

  @override
  String get disabled => 'Välja lülitatud';

  @override
  String get enableShown => 'Luba kuvatud';

  @override
  String get disableShown => 'Kuvatakse keelamine';

  @override
  String get expandAll => 'Laienda kõik';

  @override
  String get collapseAll => 'Ahenda kõik';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 salvestamata muudatused';
  }

  @override
  String get settingsScopeAllAgents => 'Kõik agendid';

  @override
  String get settingsScopeAgent => 'See agent';

  @override
  String get settingsScopeApp => 'Rakendus';

  @override
  String get settingsScopeAccountHint => 'Sama kõikjal, kuhu sisse logite';

  @override
  String get settingsScopeAllAgentsHint => 'Jagavad kõik teie agendid';

  @override
  String get settingsAppliesTo => 'Kehtib';

  @override
  String get settingsSaving => 'Salvestamine…';

  @override
  String get settingsSavedAutomatically =>
      'Muudatused salvestatakse automaatselt';

  @override
  String get settingsSearchHint => 'Otsige kõiki seadeid';

  @override
  String get settingsPageProfile => 'Profiil';

  @override
  String get settingsPageSecurity => 'Sisselogimine ja turvalisus';

  @override
  String get settingsPageUsage => 'Kasutamine';

  @override
  String get settingsPagePermissions => 'load';

  @override
  String get settingsPageComputer => 'Arvuti ja veeb';

  @override
  String get settingsPageBehavior => 'Käitumine';

  @override
  String get settingsPageSystem => 'Süsteem';

  @override
  String get settingsPagePlatforms => 'Platvormid';

  @override
  String get settingsPageProfileDescription =>
      'Teie nimi ja e-posti aadress, teie andmete koopia ja väljalogimine.';

  @override
  String get settingsPageSecurityDescription =>
      'Parool, kahefaktoriline autentimine, turvavõtmed ja koht, kus olete sisse logitud.';

  @override
  String get settingsPageUsageDescription =>
      'Teie limiidid ja märgikulu – kõik ühes kohas.';

  @override
  String get settingsPageAgentsDescription =>
      'Looge agendid ja valige, milline neist vaikimisi vastab.';

  @override
  String get settingsPagePermissionsDescription =>
      'Mida teie agendid võivad teilt küsimata teha.';

  @override
  String get settingsPageComputerDescription =>
      'Arvuti, milles teie agendid töötavad, ja saidid, mida nad saavad lugeda teiena.';

  @override
  String get settingsPageModelsDescription =>
      'Milliseid mudeleid see agent kasutab, ja API-võtmed, mis nende eest maksavad.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kuidas see agent räägib ja grupivestlust loeb.';

  @override
  String get settingsPageVoiceDescription =>
      'Selle agendi reaalajas kõned, dikteerimine ja suulised vastused.';

  @override
  String get settingsPageMessagingDescription =>
      'Kust inimesed selle agendiga ühendust saavad ja kuidas see vestlustes käitub.';

  @override
  String get settingsPageGeneralDescription =>
      'Välimus, keel, ajavöönd ja see, mida see rakendus taustal teeb.';

  @override
  String get settingsPageSystemDescription =>
      'Server, mida see aken kasutab, selles arvutis olev server ja rakenduse värskendused.';

  @override
  String get settingsYourAgents => 'Teie agendid';

  @override
  String get settingsChatModel => 'Vestlusmudel';

  @override
  String get settingsChatModelDescription => 'Vastab teie sõnumitele.';

  @override
  String get settingsSubAgentModel => 'Alamagendi mudel';

  @override
  String get settingsSubAgentModelDescription =>
      'Käitab ülesande ajal üle antud tööd.';

  @override
  String get settingsDefaultModels => 'Vaikimisi mudelid';

  @override
  String get settingsDefaultModelsDescription =>
      'Kasutatakse alati, kui vestlus või ülesanne ei vali oma mudelit.';

  @override
  String get settingsModelPool => 'Mudelbassein';

  @override
  String get settingsApiKeysDescription =>
      'Kasutage selle agendi jaoks oma võtmeid või lõpp-punkti. Võtmed on krüptitud ja neid ei kuvata enam kunagi.';

  @override
  String get settingsPersona => 'Isik';

  @override
  String get settingsFineTuning => 'Peenhäälestus';

  @override
  String get settingsFineTuningDescription =>
      'Harva vaja. Vaikeseaded sobivad enamiku vestluste jaoks.';

  @override
  String get settingsShow => 'Näita';

  @override
  String get settingsHide => 'Peida';

  @override
  String get settingsMinimumContribution => 'Minimaalne sissemakse väärtus';

  @override
  String get settingsBatchWindow => 'Ruumi partii aken';

  @override
  String get settingsBatchWindowDescription =>
      'Ootab nii kaua, et käsitleda kiirsõnumeid ühe käiguna.';

  @override
  String get settingsHandsFree => 'Käed-vabad';

  @override
  String get settingsHandsFreeDescription =>
      'Rääkige vabalt ja katkestage igal ajal.';

  @override
  String get settingsPushToTalkDescription =>
      'Rääkimiseks hoidke, saatmiseks vabastage.';

  @override
  String get settingsLiveVoice => 'Elav hääl';

  @override
  String get settingsChannels => 'Kanalid';

  @override
  String get settingsGroupChats => 'Grupivestlustes';

  @override
  String get settingsGroupChatsDescription =>
      'Kuidas see agent igal kanalil rühmades käitub.';

  @override
  String get settingsGroupChatsDisabled =>
      'Nende muutmiseks lülitage käitumismoodulid sisse käitumismoodulid.';

  @override
  String get settingsParticipationAutomatic => 'Automaatne';

  @override
  String get settingsParticipationMentionOnly => 'Mainige ainult';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Loeb ruumi ja liitub, kui sellel on midagi kasulikku lisada.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Vastab ainult siis, kui mainitakse või vastatakse.';

  @override
  String get settingsParticipationAlwaysDescription => 'Vastab igale sõnumile.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Jaotab pikemad vastused lühisõnumiteks, nagu inimene seda teeks.';

  @override
  String get settingsDeliverySingleDescription =>
      'Saadab iga vastuse ühe sõnumina.';

  @override
  String get settingsComputerStatus => 'Olek';

  @override
  String get settingsTest => 'Test';

  @override
  String get settingsAppearance => 'Välimus';

  @override
  String get settingsTheme => 'Teema';

  @override
  String get settingsThemeSystem => 'Süsteem';

  @override
  String get settingsThemeLight => 'Hele';

  @override
  String get settingsThemeDark => 'Tume';

  @override
  String get settingsCloseWindow => 'Kui sulgete akna';

  @override
  String get settingsCloseAsk => 'Küsi';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent töötab taustal ja jääb kättesaadavaks.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent väljub täielikult.';

  @override
  String get settingsPhoneTriggers => 'Telefoni käivitajad';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signaalid, mille see telefon saadab teie agentidele, et ülesanded saaksid neile reageerida.';

  @override
  String get settingsLocationTriggers => 'Asukoha käivitajad';

  @override
  String get settingsLocationTriggersDescription =>
      'Kontrollib teie ligikaudset asukohta iga paari minuti järel võrreldes kohtadega, mida teie ülesanded vaatavad.';

  @override
  String get settingsNotificationTriggers => 'Teavituste käivitajad';

  @override
  String get settingsNotificationTriggersDescription =>
      'Edastab selle telefoni teiste rakenduste märguanded teie agentidele.';

  @override
  String get settingsSetup => 'Seadistamine';

  @override
  String get settingsOnboarding => 'Sisseastumine';

  @override
  String get settingsOnboardingDescription =>
      'Käige uuesti läbi esmakordse seadistuse. Midagi, mille olete seadistanud, ei lähe kaotsi.';

  @override
  String get settingsUsernameDescription =>
      'Kasutati sisselogimiseks. Seda ei saa muuta.';

  @override
  String get settingsExport => 'Ekspordi';

  @override
  String get settingsLeave => 'Logi välja ja kustuta';

  @override
  String get settingsSignOutDescription =>
      'Logib teid välja ainult sellest seadmest.';

  @override
  String get settingsDeleteAccountDescription =>
      'Kustutab teie konto, agendid, mälu ja seaded. Seda ei saa tagasi võtta.';

  @override
  String get settingsTokenUsage => 'Märgi kasutamine';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Ükski seade ei vasta “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vastet',
      one: '$count vaste',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Mudeli täpsemad sätted';

  @override
  String get settingsAdvancedModelsDescription =>
      'Valikuline. Kinnitage mudel ühte tüüpi tööle; see võtab üle alati, kui agent neid tööriistu kasutab. Kõik, mis on vaikimisi jäetud, järgib vestlusmudelit.';

  @override
  String get settingsTaskModelDefault => 'Vaikimisi';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Järgib vestlusmudelit';

  @override
  String get settingsTaskModelCoding => 'Kodeerimine';

  @override
  String get settingsTaskModelCodingDescription =>
      'Koodi kirjutamine, redigeerimine ja silumine.';

  @override
  String get settingsTaskModelComputerUse => 'Arvuti kasutamine';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Brauseri ja töölaua juhtimine.';

  @override
  String get settingsTaskModelAndroidUse => 'Androidi kasutamine';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Rakenduste kasutamine Android-seadmes või emulaatoris.';

  @override
  String get settingsTaskModelResearch => 'Uurimine';

  @override
  String get settingsTaskModelResearchDescription =>
      'Allikate otsimine, lugemine ja kokkuvõtete tegemine.';

  @override
  String get knowledgeGraphHint =>
      'Teie enimmainitud olemid, mis on värvitud klastri järgi. Jooned ühendavad üksusi, mis ilmuvad samades mälestustes. Puudutage ühte, et näha selle linke ja mälestusi; lohistage panoraamimiseks, pigistage kokku või Ctrl/⌘-kerige suumimiseks.';

  @override
  String get linkedEntities => 'Lingitud olemid';

  @override
  String get noLinkedEntities => 'Pole veel teiste üksustega lingitud.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 mainib';
  }

  @override
  String get entityKindConcept => 'Kontseptsioon';

  @override
  String get entityKindDomain => 'Domeen';

  @override
  String get entityKindEmail => 'Meil';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'Fail';

  @override
  String get entityKindAcronym => 'Akronüüm';

  @override
  String get entityKindIdentifier => 'Identifikaator';

  @override
  String get entityKindVersion => 'Versioon';

  @override
  String get openFullscreen => 'Ava täisekraan';

  @override
  String get zoomIn => 'Suumi sisse';

  @override
  String get zoomOut => 'Suumi välja';

  @override
  String get searchEntities => 'Leidke üksus';

  @override
  String get incomingCall => 'Sissetulev kõne';

  @override
  String get answerCall => 'Vastus';

  @override
  String get callMeLater => 'Helista mulle hiljem';

  @override
  String get callingEllipsis => 'Helistamine…';

  @override
  String get reconnectingCall => 'Ühenduse taastamine';

  @override
  String get agentWorking => 'Töötab';

  @override
  String get micMuted => 'Vaigistatud';

  @override
  String get speakerphone => 'Kõlar';

  @override
  String get muteMic => 'Vaigista';

  @override
  String get unmuteMic => 'Tühista vaigistus';

  @override
  String get releaseToSend => 'Saatmiseks vabastage';

  @override
  String get callEnded => 'Kõne lõppes';

  @override
  String get openConversation => 'Ava vestlus';

  @override
  String get callBack => 'Helista tagasi';

  @override
  String get letCallsReachYou => 'Laske kõnedel teieni jõuda';

  @override
  String get callPermissionsIntro =>
      'Teie agendid võivad teile helistada. Telefonikõnena helistamiseks, kui NeoAgent on taustal või telefon on lukus, vajab see neid.';

  @override
  String get showOverOtherApps => 'Kuva teiste rakenduste kohal';

  @override
  String get showOverOtherAppsDetail => 'Toob kõneekraani kõikjal üles.';

  @override
  String get fullScreenCalls => 'Täisekraanil kõned';

  @override
  String get fullScreenCallsDetail => 'Heliseb üle lukustuskuva.';

  @override
  String get unrestrictedBattery => 'Piiranguteta aku';

  @override
  String get unrestrictedBatteryDetail =>
      'Hoiab NeoAgenti ühenduses, nii et kõned saabuvad.';

  @override
  String get permissionAllowed => 'Lubatud';

  @override
  String get triggerSectionCalendar => 'Kalender';

  @override
  String get triggerSectionFiles => 'Failid ja dokumendid';

  @override
  String get triggerSectionHome => 'Kodu ja meedia';

  @override
  String get triggerSectionDevices => 'Seadmed ja kohad';

  @override
  String get triggerSectionTasks => 'Ülesanded';

  @override
  String get messagingMemberJoined => 'Liige liitus';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Käivitage, kui keegi liitub Discordi serveri, Telegrami või WhatsAppi grupiga, Slacki kanali või Matrixi ruumiga.';

  @override
  String get messagingMemberLeft => 'Liige lahkus';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Käivitage, kui keegi lahkub Discordi serverist, Telegrami või WhatsAppi grupist, Slacki kanalist või Matrixi ruumist.';

  @override
  String get messagingReactionAdded => 'Reaktsioon lisatud';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Käivitage, kui lubatud isik reageerib privaatvestluses sõnumile.';

  @override
  String get messagingPlatformDisconnected => 'Sõnumside ühendus katkestati';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Käivitage, kui sõnumsideühendus peatub ja teid vajab, näiteks pärast väljalogimist.';

  @override
  String get googleCalendarEventStarting => 'Google\'i kalendri sündmus algab';

  @override
  String get googleCalendarEventCreated => 'Google\'i kalendri sündmus loodud';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Käivitage, kui ilmub uus sündmus või kutse.';

  @override
  String get outlookCalendarEventStarting => 'Outlooki kalendrisündmus algab';

  @override
  String get nextcloudCalendarEventStarting =>
      'Nextcloudi kalendri sündmus algab';

  @override
  String get runMinutesBeforeEachEvent =>
      'Jookse enne iga sündmust teatud arv minuteid.';

  @override
  String get googleDriveFileAdded => 'Google Drive\'i fail on lisatud';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Käivitage, kui fail lisatakse Drive\'i või selles kausta.';

  @override
  String get googleSheetsRowAdded =>
      'Google\'i arvutustabelite rida on lisatud';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Käivitage, kui lehel ilmuvad uued read.';

  @override
  String get onedriveFileAdded => 'OneDrive\'i fail on lisatud';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Käivitage, kui fail lisatakse OneDrive\'i kausta.';

  @override
  String get nextcloudFileAdded => 'Nextcloudi fail on lisatud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Käivitage, kui fail lisatakse Nextcloudi kausta.';

  @override
  String get nextcloudShareReceived => 'Teiega jagatud Nextcloudi fail';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Käivitage, kui keegi jagab teiega faili või kausta.';

  @override
  String get notionItemAdded => 'Mõistete andmebaasi üksus lisatud';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Käivitage, kui üksus lisatakse Notioni andmebaasi.';

  @override
  String get notionItemUpdated => 'Mõistete andmebaasi üksust värskendati';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Käivitage, kui üksus Notioni andmebaasis muutub.';

  @override
  String get trelloCardEnteredList => 'Trello kaart lisati loendisse';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Käivitage, kui kaart luuakse loendisse või teisaldatakse loendisse.';

  @override
  String get figmaCommentAdded => 'Figma kommentaar lisatud';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Käivitage, kui keegi kommenteerib Figma faili.';

  @override
  String get githubPrOpened => 'GitHubi tõmbamistaotlus on avatud';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Käivitage, kui hoidlas avatakse uus tõmbamistaotlus.';

  @override
  String get githubWorkflowRunFailed => 'GitHubi töövoo käitamine ebaõnnestus';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Käivitage, kui GitHubi toimingute käitamine ebaõnnestub.';

  @override
  String get githubCommitPushed => 'GitHubi kohustus lükati';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Käivitage, kui haruni jõuavad uued kohustused.';

  @override
  String get mcpServerFailed => 'MCP-server ebaõnnestus';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Käivitage, kui töötav MCP-server ebaõnnestub või vajab sisselogimist.';

  @override
  String get homeAssistantStateChanged => 'Koduabilise olek muudetud';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Käivitage, kui olem muutub, jõuab olekusse või ületab väärtuse.';

  @override
  String get spotifyTrackChanged => 'Spotify rada muudetud';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Käivitage, kui mängima hakkab mõni muu lugu.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecalli igapäevane kokkuvõte on valmis';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Jookse, kui päeva kokkuvõte on lõplik.';

  @override
  String get neorecallConversationRecorded => 'NeoRecalli vestlus salvestati';

  @override
  String get runWhenARecordedConversationEnds =>
      'Käivitage, kui salvestatud vestlus lõpeb.';

  @override
  String get geofenceTrigger => 'Asukoht geotara';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Jookse, kui telefon kohale jõuab või sealt lahkub. Vajab asukoha jälgimist telefonis.';

  @override
  String get healthMetricRecorded => 'Salvestatud tervisemõõdik';

  @override
  String get runWhenAHealthReadingArrives =>
      'Käivitage, kui saabub sünkroonitud tervisenäit, valikuliselt väärtusest kõrgemal või madalamal.';

  @override
  String get wearableConnectionChanged =>
      'Kantav ühendatud või lahti ühendatud';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Käivitage, kui teie kantav ühendub või katkeb.';

  @override
  String get taskRunFinished => 'Järjekordne ülesanne on lõpetatud';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Jookse pärast teise ülesande lõppemist, õnnestumist või ebaõnnestumist.';

  @override
  String get appPackageOptional => 'Rakenduse pakett (valikuline)';

  @override
  String get appPackageHelper => 'Näiteks com.whatsapp';

  @override
  String get anyPlatform => 'Mis tahes platvorm';

  @override
  String get spaceIdOptional =>
      'Serveri, rühma, kanali või ruumi ID (valikuline)';

  @override
  String get spaceIdHelper => 'Tühjad kellad, milles bot on.';

  @override
  String get emojiOptional => 'Emotikonid (valikuline)';

  @override
  String get chatIdOptional => 'Vestluse ID (valikuline)';

  @override
  String get platformOptional => 'Platvorm (valikuline)';

  @override
  String get platformOptionalHelper => 'Näiteks whatsapp. Tühjad kellad kõik.';

  @override
  String get minutesBefore => 'Minutid enne';

  @override
  String get calendarIdOptional => 'Kalendri ID (valikuline)';

  @override
  String get calendarIdHelper => 'Tühi kasutab teie peamist kalendrit.';

  @override
  String get invitesOnly => 'Ainult kutsed teistelt';

  @override
  String get nextcloudCalendarPath => 'Kalender';

  @override
  String get nextcloudCalendarPathHelper =>
      'Selle nimi Nextcloudi kalendriloendis, näiteks isiklik';

  @override
  String get folderIdOptionalHelperDrive => 'Tühjad kellad kogu Drive\'is.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty jälgib juurkausta.';

  @override
  String get driveFolderIdOptional => 'Kausta ID (valikuline)';

  @override
  String get spreadsheetId => 'Arvutustabeli ID';

  @override
  String get sheetRange => 'Vahemik';

  @override
  String get sheetRangeHelper => 'Tabeli veerud, näiteks Sheet1!A:E';

  @override
  String get folderPathOptional => 'Kausta tee (valikuline)';

  @override
  String get folderPathHelper => 'Näiteks Dokumendid';

  @override
  String get notionDatabaseId => 'Andmebaasi ID';

  @override
  String get trelloListId => 'Loendi ID';

  @override
  String get figmaFileKey => 'Faili võti';

  @override
  String get figmaFileKeyHelper => 'Faili lingilt: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Hoidla';

  @override
  String get workflowOptional => 'Töövoog (valikuline)';

  @override
  String get workflowHelper => 'Failinimi, näiteks ci.yml';

  @override
  String get branchOptional => 'Filiaal (valikuline)';

  @override
  String get branchHelper => 'Tühi kasutab vaikeharu.';

  @override
  String get mcpServerIdOptional => 'MCP-serveri ID (valikuline)';

  @override
  String get entityId => 'Üksuse ID';

  @override
  String get entityIdHelper => 'Näiteks binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Sihtolek (valikuline)';

  @override
  String get targetStateHelper => 'Näiteks peal';

  @override
  String get aboveOptional => 'Üleval (valikuline)';

  @override
  String get belowOptional => 'All (valikuline)';

  @override
  String get placeName => 'Kohanimi';

  @override
  String get latitude => 'Laiuskraad';

  @override
  String get longitude => 'Pikkuskraad';

  @override
  String get radiusMeters => 'Raadius meetrites';

  @override
  String get geofenceTransition => 'Millal';

  @override
  String get arriving => 'Saabuvad';

  @override
  String get leaving => 'Lahkumine';

  @override
  String get healthMetric => 'Tervise mõõdik';

  @override
  String get healthMetricHelper => 'Näiteks pulss, sammud, kaal';

  @override
  String get wearableTransition => 'Kui kantav';

  @override
  String get wearableConnects => 'Ühendab';

  @override
  String get wearableDisconnects => 'Katkestab ühendust';

  @override
  String get sourceTask => 'Pärast ülesannet';

  @override
  String get taskOutcome => 'Tulemus';

  @override
  String get anyOutcome => 'Mis tahes tulemus';

  @override
  String get succeeded => 'Õnnestus';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 puudub või ei kehti.';
  }

  @override
  String get triggerSectionMessaging => 'Sõnumid';

  @override
  String get triggerSectionDeveloper => 'Arendaja';

  @override
  String get triggerSectionMemory => 'Mälu';

  @override
  String get triggerSectionNews => 'Uudised';

  @override
  String get triggerSectionSystem => 'Süsteem';

  @override
  String get searchTriggersHint => 'Otsige päästikuid, rakendusi või sündmusi';

  @override
  String get noTriggersMatch => 'Ükski päästik ei vasta teie otsingule.';

  @override
  String get triggerAccountMissing => 'Kontot pole veel';

  @override
  String get pickTriggerKeyboardHint => 'Enter valib esimese tulemuse';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 päästikud';
  }

  @override
  String get addFromSkillsSh => 'Lisage saidilt skill.sh';

  @override
  String get skillsShHint =>
      'Otsige ülalt, et leida oskusi saidilt skill.sh või kleepige link skill.sh või käsk „npx skills add”.';

  @override
  String get noSkillsShMatches =>
      'Sellele otsingule ei vasta ükski skill.sh oskus.';

  @override
  String get installingSkill => 'Installimine…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Paigaldatud $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 installib';
  }

  @override
  String get authVerify => 'Kinnitage';

  @override
  String get authCreateAccount => 'Loo konto';

  @override
  String get authNewInviteLink => 'Uus kutse link';

  @override
  String get authShowPassword => 'Näita parooli';

  @override
  String get authHidePassword => 'Peida parool';

  @override
  String get authPasswordWillBeRejected => 'liiga nõrk, lükatakse tagasi';

  @override
  String get authUsernameTooShort =>
      'Kasutajanimed peavad sisaldama vähemalt 3 tähemärki.';

  @override
  String get authUsernameTaken => 'See kasutajanimi on juba hõivatud.';

  @override
  String get authSignupsClosed =>
      'Registreerumine on selles serveris suletud. Küsige administraatorilt kontot.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'See server aktsepteerib ainult HTTPS-i kaudu sisselogimisi. Avage selle asemel $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'See server aktsepteerib ainult HTTPS-i kaudu sisselogimisi. Ühendage sellega https:// aadressiga.';

  @override
  String get authAccountNotFound => 'Seda kontot pole enam olemas.';

  @override
  String get authQrRateLimited =>
      'Liiga palju QR-sisselogimistaotlusi. Oodake hetk, seejärel värskendage koodi.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Unustasite parooli? Paluge oma serveri administraatoril see lähtestada menüüs Administraator → Kasutajad.';

  @override
  String get authChangeServer => 'Muuda serverit';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Sisselogimine $arg1-sse';
  }

  @override
  String get authNotANeoagentServer =>
      'See aadress ei vasta nagu NeoAgenti server. Kontrollige URL-i ja proovige uuesti.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Turvalist (HTTPS) ühendust ühendusega $arg1 ei saanud avada.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return '$arg1 ei saanud HTTPS-i kaudu ühendust ja ka tavaline HTTP ei vastanud. Kontrollige aadressi ja porti.';
  }

  @override
  String get adminResetPassword => 'Lähtestage parool';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Lähtestage $arg1 parool';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Valige $arg1 jaoks uus parool. Nad logitakse igast seadmest välja ja selle parooliga uuesti sisse.';
  }

  @override
  String get adminNewPassword => 'Uus parool';

  @override
  String get adminSetPassword => 'Määra parool';

  @override
  String get authMissingFields => 'Täitke kõik vajalikud väljad.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 lähtestab $arg2 parooli';
  }

  @override
  String get adminPasswordUpdated =>
      'Parool uuendatud; kasutaja oli kõikjal välja logitud.';

  @override
  String get authSignInTitle => 'Logige NeoAgenti sisse';

  @override
  String get authSignInSubtitle =>
      'Skannige oma telefoniga või kasutage oma parooli.';

  @override
  String get authOrUsePassword => 'või kasutage oma parooli';

  @override
  String get qrLoginWaitingTitle => 'Kinnitage oma telefonis';

  @override
  String get qrLoginWaitingBody =>
      'Teie telefon skaneeris koodi. Sisselogimise lõpetamiseks kinnitage seal sisselogimine.';

  @override
  String get qrLoginSigningInOn => 'Sisselogimine';

  @override
  String get qrLoginLocation => 'Asukoht';

  @override
  String get qrLoginWaitingForApproval => 'Ootab heakskiitu';

  @override
  String get qrLoginCancelAndUsePassword => 'Tühistage ja kasutage parooli';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Teie telefoni sisselogimine lükati tagasi. Uuesti proovimiseks skannige uus kood.';

  @override
  String get signupKey => 'Registreerimisvõti';

  @override
  String get signupKeyStepSubtitle =>
      'Selle serveri uued kontod vajavad registreerimisvõtit. Sisestage administraatorilt saadud võti.';

  @override
  String get signupKeyChange => 'Muuda';

  @override
  String get signupKeyRequiredError => 'Sisestage oma registreerimisvõti.';

  @override
  String get signupKeyInvalidError =>
      'See registreerimisvõti ei kehti. Kontrollige seda ja proovige uuesti.';

  @override
  String get signupKeyUsedError =>
      'Seda registreerimisvõtit on juba kasutatud. Küsige administraatorilt uus.';

  @override
  String get adminRequireSignupKey => 'Nõua registreerimisvõtit';

  @override
  String get adminRequireSignupKeyHint =>
      'Uued kontod vajavad administraatorilt ühekordset võtit. Kui see on välja lülitatud, saab registreeruda igaüks, kes serverini jõuab. Esimene konto ei vaja kunagi võtit.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Uued kontod vajavad nüüd registreerimisvõtit.';

  @override
  String get adminSignupOpenNotice => 'Nüüd saab registreeruda igaüks.';

  @override
  String get signupKeys => 'Registreerimisvõtmed';

  @override
  String get signupKeysDescription =>
      'Ühekordsed võtmed registreerimiseks ajal, mil võti on nõutud. Iga võti loob täpselt ühe konto.';

  @override
  String get signupKeysNew => 'Uued võtmed';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Kasutamata · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Kasutatud · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Tühistatud · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Kõik · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Kasutamata';

  @override
  String get signupKeyStatusUsed => 'Kasutatud';

  @override
  String get signupKeyStatusRevoked => 'Tühistatud';

  @override
  String get signupKeysExport => 'Ekspordi .txt';

  @override
  String get signupKeysCopied => 'Võtmed kopeeritud';

  @override
  String get signupKeyCopied => 'Võti kopeeritud';

  @override
  String get signupKeysEmpty => 'Selles loendis pole võtmeid.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Loodud $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Kasutas $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Kasutatud $arg1 kontoga, mis on vahepeal kustutatud';
  }

  @override
  String get signupKeyRevokeTitle => 'Kas tühistada see võti?';

  @override
  String get signupKeyRevokeMessage =>
      'Sellega ei saa enam keegi registreeruda. Seda ei saa tagasi võtta.';

  @override
  String get signupKeyRevoked => 'Võti tühistatud.';

  @override
  String signupKeysShowMore(int count) {
    return 'Näita veel $count';
  }

  @override
  String get signupKeysCreateTitle => 'Loo registreerimisvõtmed';

  @override
  String get signupKeysCount => 'Võtmete arv';

  @override
  String get signupKeysCountHelper => '1 kuni 500';

  @override
  String get signupKeysCountInvalid => 'Sisestage arv vahemikus 1 kuni 500.';

  @override
  String get signupKeysLabel => 'Silt (valikuline)';

  @override
  String get signupKeysLabelHint => 'nt kevadised beetatestijad';

  @override
  String signupKeysCreateAction(int count) {
    return 'Loo ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Võtmed valmis: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Andke iga võti ainult ühele inimesele. Kasutamata võtmed jäävad loendisse, nii et saate need hiljem uuesti kopeerida või eksportida.';

  @override
  String get signupKeysSaveDialogTitle => 'Salvesta registreerimisvõtmed';

  @override
  String get signupKeysExported => 'Võtmed eksporditud.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor lõi registreerimisvõtmeid ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor tühistas registreerimisvõtme';
  }

  @override
  String get providerChooseUsername => 'Vali kasutajanimi';

  @override
  String get providerChooseUsernameBody =>
      'Konto loomise lõpetamiseks vali vaba kasutajanimi.';

  @override
  String get dataSharingTitle => 'Jaga kasutusandmeid';

  @override
  String get dataSharingDescription =>
      'Aita selle serveri haldajatel seda paremaks teha. Jagab seda, kuidas sa NeoAgenti kasutad, mitte kunagi seda, mida kirjutad või salvestad.';

  @override
  String dataSharingSince(String date) {
    return 'Jagatud alates $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Mida jagatakse';

  @override
  String get dataSharingIncluded => 'Jagatakse';

  @override
  String get dataSharingExcluded => 'Ei jagata kunagi';

  @override
  String get dataSharingIncludedDevice => 'Seadme tüüp ja rakenduse versioon';

  @override
  String get dataSharingIncludedLocale =>
      'Rakenduse keel ja ajavööndi piirkond, näiteks Euroopa';

  @override
  String get dataSharingIncludedFeatures =>
      'Milliseid funktsioone oled seadistanud, nagu ülesanded, oskused ja integratsioonid';

  @override
  String get dataSharingIncludedRuns =>
      'Milliseid tööriistu ja mudeleid sinu käivitused kasutavad, koos kestuste ja tokenite arvuga';

  @override
  String get dataSharingIncludedActivity =>
      'Millal sa NeoAgenti kasutad, nädalapäeva ja tunni kaupa';

  @override
  String get dataSharingExcludedContent => 'Sõnumid, viibad ja vastused';

  @override
  String get dataSharingExcludedRuns =>
      'Käivituste pealkirjad, tööriistade sisendid ja tulemused';

  @override
  String get dataSharingExcludedFiles =>
      'Failid, mälestused ja kõik muu, mida salvestad';

  @override
  String get dataSharingExcludedIdentity =>
      'Sinu nimi, e-post, IP-aadress ja asukoht';

  @override
  String get dataSharingExcludedAccounts =>
      'Kontod, millega integratsioone ühendad';

  @override
  String get dataSharingPooledNote =>
      'Administraatorid näevad ainult kõigi jagajate kogusummasid, mitte kunagi sind eraldi. Lülita see igal ajal välja ja sa kaod kohe summadest.';

  @override
  String get dataSharingConfirmTitle => 'Kas jagada kasutusandmeid?';

  @override
  String get dataSharingConfirmAction => 'Jaga';

  @override
  String get sharedUsageTitle => 'Jagatud kasutus';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Kasutusandmeid jagavad kontod: $sharing/$total. Ainult summad, mitte sisu.';
  }

  @override
  String get sharedUsageEmpty =>
      'Keegi ei jaga veel kasutusandmeid. Selle saab sisse lülitada: Seaded, Profiil, Teie andmed.';

  @override
  String get sharedUsageRuns => 'Jagatud käivitused';

  @override
  String get sharedUsageAvgDuration => 'Keskm. kestus';

  @override
  String get sharedUsageCompletedRuns => 'Lõpetatud käivitused';

  @override
  String get sharedUsageStepsPerRun => 'Samme käivituse kohta';

  @override
  String get sharedUsageDevices => 'Seadmed';

  @override
  String get sharedUsageAppVersions => 'Rakenduse versioonid';

  @override
  String get sharedUsageLanguages => 'Keeled';

  @override
  String get sharedUsageRegions => 'Piirkonnad';

  @override
  String get sharedUsageFeatures => 'Funktsioonide kasutuselevõtt';

  @override
  String get sharedUsageFeaturesDescription =>
      'Osakaal jagavatest kontodest, kes on selle seadistanud.';

  @override
  String get sharedUsageTools => 'Tööriistad';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Enim kutsutud tööriistad ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Kutseid: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Ebaõnnestus: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integratsioonid';

  @override
  String get sharedUsageMessaging => 'Sõnumikanalid';

  @override
  String get sharedUsageTriggers => 'Kuidas käivitused algavad';

  @override
  String get sharedUsageActivity => 'Millal seda kasutatakse';

  @override
  String get sharedUsageActivityDescription =>
      'Käivitused nädalapäeva ja tunni kaupa, UTC.';

  @override
  String get sharedUsageModels => 'Mudelite jõudlus';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'keskm. $latency · $cached% vahemälust · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Kontosid: $count';
  }

  @override
  String get sharedUsageNoData => 'Selles vahemikus pole midagi.';

  @override
  String get sharedUsageNotReported => 'Pole veel teatatud';

  @override
  String get sharedUsageFeatureAgents => 'Rohkem kui üks agent';

  @override
  String get sharedUsageFeatureTasks => 'Ajastatud ülesanded';

  @override
  String get sharedUsageFeatureSkills => 'Oskused';

  @override
  String get sharedUsageFeatureMcp => 'MCP-serverid';

  @override
  String get sharedUsageFeatureIntegrations => 'Integratsioonid';

  @override
  String get sharedUsageFeatureMessaging => 'Sõnumikanalid';

  @override
  String get sharedUsageFeatureMemory => 'Mälu';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in andmete jagamine telemeetria seadmed funktsioonid tööriistad mudelid aktiivsus';

  @override
  String get yourOAuthApp => 'Sinu OAuth-rakendus';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Sinu $provider OAuth-rakendus';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Sellel serveril pole globaalset $provider-rakendust, seega ühendad end ise registreeritud OAuth-rakendusega. Kliendi saladus salvestatakse krüpteeritult ja seda ei näidata enam kunagi.';
  }

  @override
  String get oauthAppStepCreate => '1. Loo rakendus';

  @override
  String get openDeveloperConsole => 'Ava arendajakonsool';

  @override
  String get oauthAppStepCallback => '2. Registreeri see tagasikutse URL';

  @override
  String get callbackUrlCopied => 'Tagasikutse URL kopeeritud';

  @override
  String get oauthAppScopes => 'Lubatavad ulatused';

  @override
  String get scopesCopied => 'Ulatused kopeeritud';

  @override
  String get oauthAppStepCredentials => '3. Kleebi rakenduse mandaadid';

  @override
  String get couldNotSaveOAuthApp =>
      'OAuth-rakendust ei õnnestunud salvestada.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Kas eemaldada sinu $provider-rakendus?';
  }

  @override
  String get removeOAuthAppBody =>
      'Ühendatud kontod jäävad loendisse, kuid lakkavad töötamast, kuni lisad uuesti rakenduse.';

  @override
  String get globalIntegrationConfiguration =>
      'Integratsioonide globaalne seadistus';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Valikulised kogu serverit hõlmavad OAuth-rakendused. Kui integratsioonil see on, kasutab seda iga konto ega saa oma lisada. Jäta integratsioon seadistamata ja iga kasutaja seadistab oma rakenduse. Saladused on ainult kirjutatavad: jäta tühjaks, et salvestatud väärtus alles jääks.';

  @override
  String get globalStatus => 'Globaalne';

  @override
  String get perUserStatus => 'Kasutajapõhine';

  @override
  String get phoneSyncGuidance =>
      'Jaga selle telefoni kalendreid ja kontakte oma agendiga. Töötab kõigi telefonis juba olevate kontodega.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Ava telefonis NeoAgent ja lülita seal jagamine sisse. Agent näeb siis kõigi selle telefoni kontode kalendreid ja kontakte.';

  @override
  String get manageOnThisPhone => 'Halda selles telefonis';

  @override
  String get setUpOnThisPhone => 'Seadista selles telefonis';

  @override
  String get setUpOnPhone => 'Seadista oma telefonis';

  @override
  String emailConnectedArg1(String email) {
    return '$email ühendatud';
  }

  @override
  String get couldNotConnectEmail => 'Kontot ei õnnestunud ühendada.';

  @override
  String get emailSetupTitle => 'Ühenda e-post ja kalender';

  @override
  String get emailChecking => 'Postkasti kontrollimine…';

  @override
  String get emailSetupIntro =>
      'Kasuta e-posti teenusepakkuja rakenduse parooli. Arendajakonsooli pole vaja, valmis mõne minutiga.';

  @override
  String emailOpenArg1(String provider) {
    return 'Ava $provider';
  }

  @override
  String get emailStepServers => '1. Sisesta serverid';

  @override
  String get emailStepPassword => '1. Loo rakenduse parool';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Ava $provider rakenduse paroolid';
  }

  @override
  String get emailStepSignIn => '2. Logi sisse';

  @override
  String get appPassword => 'Rakenduse parool';

  @override
  String get appPasswordHelper =>
      'Tühikud ei loe. NeoAgent salvestab selle krüpteerituna.';

  @override
  String get emailUsernameOptional =>
      'Kasutajanimi, kui see pole sinu e-posti aadress';

  @override
  String get emailIncludeCalendar => 'Kaasa kalender';

  @override
  String get emailIncludeContacts => 'Kaasa kontaktid';

  @override
  String get imapServer => 'IMAP-server';

  @override
  String get smtpServer => 'SMTP-server';

  @override
  String get caldavUrlOptional => 'CalDAV URL (valikuline)';

  @override
  String get carddavUrlOptional => 'CardDAV URL (valikuline)';

  @override
  String get alternativeEmail =>
      'Ühenda postkast rakenduse parooliga või kalender selle iCal-lingiga. Valmis mõne minutiga.';

  @override
  String get alternativePhone =>
      'Jaga telefonis juba olevat kalendrit ja kontakte NeoAgenti rakenduse kaudu.';

  @override
  String get alternativePhoneElsewhere =>
      'Jaga telefonis juba olevat kalendrit ja kontakte. Seadista see telefoni NeoAgenti rakenduses.';

  @override
  String get skipTheDeveloperConsole => 'Ilma arendajakonsoolita';

  @override
  String get phoneSyncPromptTitle => 'Kas agent võib su kalendrit näha?';

  @override
  String get phoneSyncPromptBody =>
      'Jaga selle telefoni kalendreid ja kontakte, et agent saaks su päeva järgi planeerida. Saad seda igal ajal muuta jaotises Tööriistad › Integratsioonid.';

  @override
  String get phoneSyncTitle => 'Jaga telefoni kalendrit ja kontakte';

  @override
  String get phoneSyncIntro =>
      'Agent näeb kõigi selle telefoni kontode kalendreid ja kontakte. Arendajakonsooli ega lisasisselogimist pole vaja.';

  @override
  String get phoneSyncPointAccounts =>
      'Töötab selle telefoni Google\'i, Outlooki, iCloudi ja Exchange\'i kontodega.';

  @override
  String get phoneSyncPointPrivate =>
      'Jagatakse ainult sinu NeoAgenti serveriga, mis salvestab need krüpteerituna.';

  @override
  String get phoneSyncPointWrites =>
      'Agendi lisatud sündmused loob see telefon ja need sünkroonitakse tavapäraselt.';

  @override
  String get phoneSyncCalendarHint =>
      'Sündmused 30 päeva tagant kuni 90 päeva ette';

  @override
  String get phoneSyncContacts => 'Kontaktid';

  @override
  String get phoneSyncContactsHint =>
      'Nimed, e-posti aadressid ja telefoninumbrid';

  @override
  String get phoneSyncOtherAgent =>
      'See telefon jagab teise agendiga. Siin jagamine viib selle sellele agendile.';

  @override
  String get phoneSyncDenied =>
      'NeoAgentil pole veel ligipääsu. Luba see seadetes ja tule tagasi.';

  @override
  String get openPhoneSettings => 'Ava seaded';

  @override
  String get phoneSyncShare => 'Jaga NeoAgentiga';

  @override
  String get phoneSyncStop => 'Lõpeta jagamine';

  @override
  String get phoneSyncWaiting => 'Ootan esimest sünkroonimist…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Viimati sünkroonitud $time';
  }

  @override
  String get calendarLink => 'Kalendri link';

  @override
  String get calendarLinkHelper =>
      'Kalendri iCal-aadress. Igaüks, kellel see on, saab kalendrit lugeda, seega hoia see privaatsena.';

  @override
  String get calendarLinkName => 'Nimi (valikuline)';

  @override
  String get calendarLinkAdded => 'Kalender lisatud';

  @override
  String get toolsApps => 'Rakendused';

  @override
  String get reconnect => 'Ühenda uuesti';

  @override
  String get reconnectNeeded => 'Vaja uuesti ühendada';

  @override
  String get mixedAccess => 'Segajuurdepääs';

  @override
  String disconnectAccountTitle(String account) {
    return 'Kas katkestada $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agent kaotab selle konto kaudu juurdepääsu teenustele $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Ühenda oma NeoRouter üks kord ja iga konto siin kasutab seda allpool sisse lülitatud töödeks.';

  @override
  String get neoRouterUserDescription =>
      'Kasuta allpool sisse lülitatud töödeks oma NeoRouteri kontot selle serveri teenusepakkujate asemel.';

  @override
  String get neoRouterAddress => 'NeoRouteri aadress';

  @override
  String get neoRouterConnect => 'Ühenda NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Kinnita NeoAgent NeoRouteris. Seal on kood $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Ava uuesti';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Ühendatud: $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter pole praegu kättesaadav.';

  @override
  String get neoRouterDisconnect => 'Katkesta ühendus';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent lõpetab selle NeoRouteri kasutamise. Võta ka võti tagasi NeoRouteri API-võtmete all.';

  @override
  String get neoRouterServerInUse =>
      'See server kasutab juba kõigi jaoks NeoRouterit. Ühenda oma NeoRouteri konto, et saada oma mudelid ja eelarve.';

  @override
  String get neoRouterConnected => 'NeoRouter on ühendatud.';

  @override
  String get neoRouterRoleChat => 'Vestlus ja pildituvastus';

  @override
  String get neoRouterRoleSystemOne => 'System One otsused';

  @override
  String get neoRouterRoleTranscription => 'Kõne tekstiks';

  @override
  String get neoRouterRoleLive => 'Otsehääl';

  @override
  String get neoRouterRoleEmbeddings => 'Mälust otsimine';

  @override
  String get neoRouterRoleImages => 'Piltide loomine';

  @override
  String get neoRouterRoleSearch => 'Veebiotsing';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Sinu NeoRouteris saadaval: $arg1';
  }

  @override
  String get neoRouterNoModels => 'Sinu NeoRouteris pole veel midagi.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter valib iga päringu jaoks mudeli, nii et seda valikut ei kasutata.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return 'Sinu NeoRouteris: $arg1, kuid NeoAgenti võti ei tohi neid veel kasutada (nt tasulisi). Luba need NeoAgentile NeoRouteri API-võtmete all.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Vajab otsustusmudeleid, nagu Jev. Turvaklassifikaatorid ei vasta neile küsimustele.';

  @override
  String get voiceLiveNoProvider =>
      'Ühtegi otsehääle pakkujat pole seadistatud. Lisa OpenAI või Google AI võti või ühenda NeoRouter jaotises Mudelid → Kaasa oma võti.';

  @override
  String get voiceSttAutoNeoRouter => 'Automaatne (mudeli valib NeoRouter)';

  @override
  String get voiceNotOffered => 'Pole enam saadaval, vali muu';
}
