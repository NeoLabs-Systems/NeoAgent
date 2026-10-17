// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppL10nNl extends AppL10n {
  AppL10nNl([String locale = 'nl']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Welkom';

  @override
  String get onboardingEyebrowCommunication => 'Communicatie';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligentie';

  @override
  String get onboardingEyebrowComputer => 'Computer';

  @override
  String get onboardingEyebrowAutomation => 'Automatisering';

  @override
  String get onboardingNext => 'Volgende';

  @override
  String get onboardingIntroCouldNotLoad =>
      'De introductie kon niet worden geladen.';

  @override
  String get onboardingModelDescription =>
      'Kies het model dat NeoAgent standaard moet gebruiken, of laat het automatisch kiezen.';

  @override
  String get onboardingLoadingModels => 'Modellen laden…';

  @override
  String get noAiModelTitle => 'Er is nog geen AI-model ingesteld';

  @override
  String get noAiModelBody =>
      'Voeg een API-sleutel toe van een aanbieder zoals OpenAI, Anthropic of Google. NeoAgent toont vervolgens de modellen die je kunt gebruiken.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent heeft een AI-model nodig om te kunnen antwoorden. Voeg een API-sleutel toe van een provider zoals OpenAI, Anthropic of Google.';

  @override
  String get noAiModelAdminHint =>
      'Als beheerder kun je ook voor iedereen providers instellen onder Beheer → Providers.';

  @override
  String get addApiKey => 'API-sleutel toevoegen';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform is verbonden.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Wachten tot $platform verbinding maakt...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'De instellingen konden niet worden opgeslagen: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Klaar';

  @override
  String get onboardingStepRequired => 'Vereist';

  @override
  String get onboardingStepOptional => 'Optioneel';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud of lokaal';

  @override
  String get onboardingStepComputer => 'Computer';

  @override
  String get onboardingStepRoutines => 'Routines';

  @override
  String get onboardingComputerChoiceTitle => 'Waar moet het\nwerken?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Je kunt per sessie wisselen.';

  @override
  String get onboardingCloudComputerSubtitle => 'Privé-sandbox · altijd aan';

  @override
  String get onboardingThisComputer => 'Deze computer';

  @override
  String get onboardingThisComputerSubtitle => 'Je bestanden, apps en browser';

  @override
  String get onboardingSearchApps => 'Apps zoeken…';

  @override
  String get onboardingRoutinesDescription =>
      'Resultaten verschijnen in je chats.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Resultaten komen binnen als meldingen.';

  @override
  String get onboardingNotifications => 'Meldingen';

  @override
  String get onboardingReadyTitle => 'Je bent\ner klaar voor.';

  @override
  String get onboardingReadyDescription => 'Stuur je eerste bericht.';

  @override
  String get onboardingMessageNeoagent => 'Stuur een bericht naar NeoAgent';

  @override
  String get onboardingAskAnything => 'Stel een vraag…';

  @override
  String get onboardingOpenNeoagent => 'Open NeoAgent';

  @override
  String get onboardingStarterTrip => 'Plan een weekendje weg';

  @override
  String get onboardingStarterLanding => 'Bouw een landingspagina';

  @override
  String onboardingQuickSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count snelle stappen',
      one: '$count snelle stap',
    );
    return '$_temp0';
  }

  @override
  String get taskNeedsEmail => 'Verbind eerst e-mail';

  @override
  String get taskNeedsCalendar => 'Sluit eerst een kalender aan';

  @override
  String get taskNeedsModel => 'Zet eerst een AI-model op';

  @override
  String get taskPromptDailyRecap =>
      'Samenvatting van mijn dag: vat de gesprekken, het voltooide werk en de beslissingen van vandaag samen en maak een lijst van alles wat ik morgen moet opvolgen. Houd het kort en stuur het naar mij.';

  @override
  String get taskPromptInboxCheck =>
      'Controleer mijn e-mailinbox op berichten die sinds de laatste controle zijn binnengekomen. Stuur mij alleen berichten over e-mails die dringend zijn of een antwoord nodig hebben, met elk een samenvatting van één regel. Als niets mijn aandacht nodig heeft, stuur dan niets.';

  @override
  String get taskPromptMorningBriefing =>
      'Bereid mijn ochtendbriefing voor: het weer van vandaag waar ik ben, de gebeurtenissen in mijn agenda en de belangrijkste openstaande posten die ik ken. Verstuur het als een kort, scanbaar bericht.';

  @override
  String get taskPromptTomorrowPrep =>
      'Kijk in mijn agenda voor morgen. Vertel mij per bijeenkomst waar het over gaat, wie er bij betrokken zijn en wat ik allemaal moet voorbereiden. Als morgen leeg is, stuur dan niets.';

  @override
  String get taskPromptNewsDigest =>
      'Zoek op internet naar het belangrijkste nieuws van vandaag over de onderwerpen die mij interesseren (gebruik wat u zich herinnert over mijn interesses). Stuur mij een samenvatting van maximaal vijf items met elk één zin en een link.';

  @override
  String get taskPromptWeeklyReview =>
      'Kijk eens naar mijn week: wat is er gedaan, wat is er misgegaan en wat staat er nog open. Stel de drie belangrijkste dingen voor waarop u zich volgende week kunt concentreren.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Koppel een telefoonnummer dat bij de agent hoort. Iedereen die u toestemming geeft, kan ermee chatten, in directe chats en groepen.';

  @override
  String get whatsappSelfChatDescription =>
      'Koppel uw eigen nummer en praat met de agent in uw “Stuur uzelf een bericht”-chat. Elke andere chat en groep op dit account wordt genegeerd.';

  @override
  String get chatSendHintMac => '⌘↵ om te verzenden';

  @override
  String get chatSendHintOther => 'Ctrl+Enter om te verzenden';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Voor dit eindpunt is een basis-URL vereist.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Een gewijzigd e-mailadres wordt bevestigd voordat het wordt gebruikt.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Een beslissing hogerop in de keten wint.';

  @override
  String get aDeletedAccount => 'een verwijderd account';

  @override
  String get aFridayLookBackAtThe =>
      'Een vrijdag terugblik op de week en een plan voor de volgende.';

  @override
  String get aKeyThatAsksForA =>
      'Een sleutel die om een ​​pincode of vingerafdruk vraagt, vervangt bovendien uw tweefactorcode.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Een taalmodel heeft dit bericht beoordeeld omdat SystemOne is uitgeschakeld.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Een metagegevensbestand voor de installatie van NeoAgent overschreed de veilige groottelimiet.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Er is een nieuwere webbuild beschikbaar op de server. Herlaad om de nieuwste bundel op te halen.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Een privédesktop met Chromium, bestanden, een teksteditor, terminal en Python. Uw werk blijft tussen sessies opgeslagen.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Een privé Linux-computer of een Android-apparaat.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Een vereist NeoAgent-installatiebestand kon niet worden gedownload.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Een teamgenoot stuurt je een uitnodigingslink. Zodra je het accepteert, zij ';

  @override
  String get aTeammateSentYouAnInvite =>
      'een teamgenoot heeft je een uitnodigingslink gestuurd. Voer deze hier in om lid te worden van hun team.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Een tijdelijke download wordt later opgeschoond.';

  @override
  String get aValueIsStored => 'Er wordt een waarde opgeslagen.';

  @override
  String get access => 'Toegang';

  @override
  String get accessActivity => 'Toegang tot activiteit';

  @override
  String accessArg1(Object? arg1) {
    return 'Toegang: $arg1';
  }

  @override
  String get accessMode => 'Toegangsmodus';

  @override
  String get accessPermissions => 'Toegangsrechten';

  @override
  String get accessToken => 'toegangstoken';

  @override
  String get accessToken2 => 'Toegangstoken';

  @override
  String get account => 'Account';

  @override
  String accountArg1(Object? arg1) {
    return 'Rekening #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Waarschuwingen voor accountwijzigingen';

  @override
  String get accountEmail => 'Account-e-mailadres';

  @override
  String get accountEmailIsOffUntilThese =>
      'Account-e-mail is uitgeschakeld totdat deze zijn ingesteld: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent gebruikt deze taal in de hele app. Bij je eerste aanmelding wordt de taal van dit apparaat gebruikt. Daarna wordt je keuze opgeslagen in je account en op al je apparaten gebruikt.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Kan de taal niet wijzigen: $error';
  }

  @override
  String get accountLanguageTitle => 'Taal';

  @override
  String get accountNumber => 'Rekeningnummer';

  @override
  String get accountSettings => 'Accountinstellingen';

  @override
  String get accounts => 'Accounts';

  @override
  String get accountsByTokensUsedAllTime =>
      'Accounts op basis van gebruikte tokens, altijd.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'de cloudcomputers van accounts. Wijzigingen zijn van toepassing na een server ';

  @override
  String get accountsOnThisServer => 'Accounts op deze server';

  @override
  String get active => 'Actief';

  @override
  String get activeSessions => 'Actieve sessies';

  @override
  String get activeToday => 'Actief vandaag';

  @override
  String get add => 'Toevoegen';

  @override
  String get addAProviderCredentialFirstIts =>
      'Voeg eerst een providerreferentie toe. De modellen verschijnen hier één keer ';

  @override
  String get addAgent => 'Agent toevoegen';

  @override
  String get addAnotherSignInMethodBefore =>
      'Voeg nog een aanmeldingsmethode toe voordat u deze verwijdert.';

  @override
  String get addBinding => 'Voeg binding toe';

  @override
  String get addByNameOrId => 'Voeg toe op naam of ID';

  @override
  String get addByNameOrIdInstead => 'Voeg in plaats daarvan op naam of ID toe';

  @override
  String get addCredentialBinding => 'Voeg referentiebinding toe';

  @override
  String get addEntry => 'Invoer toevoegen';

  @override
  String get addKey => 'Sleutel toevoegen';

  @override
  String get addMcpServer => 'MCP-server toevoegen';

  @override
  String get addMemory => 'Geheugen toevoegen';

  @override
  String get memoryReview => 'Beoordelen';

  @override
  String get memoryReviewPrompt =>
      'Loop al mijn herinneringen door en ruim ze op: archiveer duplicaten, verouderde feiten en alles zonder blijvende waarde. Vertel me daarna kort wat je hebt veranderd.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Voeg meer lengte of een ander tekentype toe.';

  @override
  String get addPeopleOrGroups => 'Voeg mensen of groepen toe';

  @override
  String get addSecurityKey => 'Beveiligingssleutel toevoegen';

  @override
  String get addSomeoneOrAGroup => 'Voeg iemand of een groep toe';

  @override
  String get addTask => 'Taak toevoegen';

  @override
  String get addTests => 'Voeg tests toe';

  @override
  String get addTestsForThePartsOf =>
      'Voeg tests toe voor de delen van dit project die de minste dekking hebben en voer deze vervolgens uit.';

  @override
  String get addTheirOwnKeysInSettings =>
      'hun eigen sleutels toevoegen in Instellingen.';

  @override
  String get addToPrompt => 'Toevoegen aan prompt';

  @override
  String get added => 'Toegevoegd';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1 toegevoegd · Laatst gebruikte $arg2';
  }

  @override
  String get addressWithTheProvider => 'adres bij de aanbieder.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Pas het luidsprekervolume aan, bekijk de standaardinstellingen van de hardwareknoppen en beheer deze opstartsessie.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Pas het zoek- of statusfilter aan om meer berichtenkanalen te zien.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Pas hier het luidsprekervolume aan.';

  @override
  String get admin => 'Beheerder';

  @override
  String adminArg1(Object? arg1) {
    return 'Beheerder › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Beheerderstoekenningen, uitnodigingslinks en beheerwijzigingen worden hier weergegeven.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Geavanceerd handmatig schema voor speciale gevallen.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Gevorderd: minuut uur dag maand weekdag.';

  @override
  String get againRightAway => 'meteen weer.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Agentoproepen';

  @override
  String get agentCommunication => 'Communicatie tussen agenten';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agentcommunicatie: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agentmodus bewerkt de werkruimte · ⌘↵ verzenden · ⌘N nieuwe sessie';

  @override
  String get agentPausesAndAsksYouBefore =>
      'De agent pauzeert en vraagt je toestemming voordat hij iets uitvoert.';

  @override
  String get agentProfile => 'Agentprofiel';

  @override
  String get agentVisibleName => 'Voor agent zichtbare naam';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent wil $arg1 gebruiken. Tik om te beslissen.';
  }

  @override
  String get agents => 'Agenten';

  @override
  String get aiAnswerUnreadable => 'AI-antwoord onleesbaar';

  @override
  String get aiProviderKeys => 'AI-providersleutels';

  @override
  String get aiUnavailable => 'AI niet beschikbaar';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'waarschuwingen en andere account-e-mail van.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Waarschuwt wanneer een berichtenverbinding aandacht van de gebruiker vereist';

  @override
  String get all => 'Allemaal';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Alle agenten ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Alle $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Alle slots voor cloudcomputers zijn momenteel in gebruik. Probeer het zo nog eens.';

  @override
  String get allComputerSlotsAreBusy => 'Alle computerslots zijn bezet';

  @override
  String get allTables => 'Alle tafels';

  @override
  String get allTime => 'Altijd';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Alle tools zijn toegestaan; de agent kan elke mogelijkheid gebruiken zonder te vragen. ';

  @override
  String get allow => 'Toestaan';

  @override
  String get allowedRunsWithoutAsking => 'Toegestaan. Loopt zonder te vragen.';

  @override
  String get allowAll => 'Alles toestaan';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Sta \'Installeer onbekende apps\' toe voor NeoAgent en probeer de update opnieuw.';

  @override
  String get allowOnce => 'Eén keer toestaan';

  @override
  String get allowSender => 'Afzender toestaan';

  @override
  String get allowSession => 'Sessie toestaan';

  @override
  String get allowTheAgentToStartAn =>
      'Laat de agent een in-app-spraakgesprek met u starten.';

  @override
  String get allowedOrigins => 'Toegestane oorsprong';

  @override
  String get allowedPathPrefix => 'Toegestaan padvoorvoegsel';

  @override
  String get allowsYouCanChangeThatPer =>
      'staat toe. Dat kun je later per persoon wijzigen. Links worden nooit verleend ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'behoort al tot een bestaand account';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'al gekoppeld aan een ander account';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'al gekoppeld aan een ander neoagent-account';

  @override
  String get alreadyUsed => 'al gebruikt';

  @override
  String get always => 'Altijd';

  @override
  String get alwaysAllow => 'Altijd toestaan';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Met \'Altijd toestaan\' wordt het beleid permanent opgeslagen. Je kunt dit wijzigen in Instellingen.';

  @override
  String get alwaysAsk => 'Vraag het altijd';

  @override
  String get alwaysEngage => 'Altijd betrokken';

  @override
  String get alwaysJoins => 'Doet altijd mee';

  @override
  String get anApiKeyIsRequired => 'Er is een API-sleutel vereist.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Een avondoverzicht van wat er is gebeurd en wat er moet worden opgevolgd.';

  @override
  String get anHttpOrHttpsUrlIs => 'Een http- of https-URL is vereist.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'en analyses. Teamlinks live op de Teampagina.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Android APK-installatie is niet beschikbaar op dit platform.';

  @override
  String get androidApp => 'Android-app';

  @override
  String get androidControl => 'Android-besturing';

  @override
  String get androidCouldNotStart => 'Android kon niet starten';

  @override
  String get androidNotificationReceived => 'Android-melding ontvangen';

  @override
  String get androidOnly => 'Alleen Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Het Android-pakketinstallatieprogramma kan niet worden geopend.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android-scherm: tik om aan te raken, sleep om te vegen';

  @override
  String get androidSdk => 'Android SDK';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Beantwoordt @vermeldingen over problemen en pull-aanvragen';

  @override
  String get anyone => 'Iedereen';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Iedereen op dit platform kan een bericht sturen naar $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Iedereen op dit platform kan een bericht sturen naar $arg1 in $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Iedereen die dit account kan bereiken, kan met $arg1 praten.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Iedereen met de link kan lid worden totdat deze verloopt of totdat u deze intrekt.';

  @override
  String get apiHttpsOrigin => 'API HTTPS-oorsprong';

  @override
  String get apiKey => 'API-sleutel';

  @override
  String get apiKey2 => 'API-sleutel';

  @override
  String get apiKey3 => 'API-sleutel';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api sleutel antropische claude openai gpt xai grok google gemini minimax nvidia nim openrouter inloggegevens';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API-sleutels en eindpunten voor AI-, zoek- en spraakproviders. Zij ';

  @override
  String get apiRequest => 'API-verzoek';

  @override
  String get apiYourOwnServerASelf =>
      'API - uw eigen server, een door uzelf gehost model of een ander model ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK-download mislukt met HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'App-naam is vereist.';

  @override
  String get appUpdates => 'App-updates';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'App-updates zijn niet geconfigureerd voor deze build.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return '$arg1 heeft stuurupdates in de wachtrij geplaatst voor de huidige run.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return '$arg1 stuurupdate(s) toegepast.';
  }

  @override
  String get apply => 'Toepassen';

  @override
  String get applyBehaviorNotes => 'Gedragsnotities toepassen';

  @override
  String get applyCoreMemory => 'Kerngeheugen toepassen';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Goedkeuringsverzoeken voor gevoelige agenttools';

  @override
  String get approvalRequired => 'Goedkeuring vereist';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Goedkeuring blijft binnen uw geverifieerde mobiele sessie en elke code vervalt automatisch na een korte periode.';

  @override
  String get approveLogin => 'Inloggen goedkeuren';

  @override
  String get approveQrLogin => 'QR-login goedkeuren';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Keur dit alleen goed als u zojuist op dat apparaat bent ingelogd.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Goedgekeurde login voor $arg1.';
  }

  @override
  String get approvedOnly => 'Alleen goedgekeurd';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Goedgekeurde koppeling voor $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Goedgekeurde mensen en groepen';

  @override
  String get approvedPeopleOnly => 'Alleen goedgekeurde mensen';

  @override
  String get archive => 'Archief';

  @override
  String get archiveAgent => 'Archiefagent?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archief ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archief $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories =>
      'Geselecteerde herinneringen archiveren?';

  @override
  String get areSharedByEveryAccountOn =>
      'worden gedeeld door elk account op deze server; rekeningen kunnen nog steeds ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M-ingang';
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
    return '$arg1-toegang vereist';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1-rekeningen';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 actief';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 toegevoegd. Bewerk het op elk gewenst moment om de ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '“$arg1” en zijn rungeschiedenis worden permanent verwijderd. Elke actieve run wordt gestopt. Bestanden in de werkruimte worden niet aangeraakt.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return '$arg1-goedkeuring vereist';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1-apps actief';
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
    return '$arg1 ($arg2 actieve gereedschappen)';
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
    return '$arg1 $arg2 en $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 gewijzigd';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2-tekens';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · $arg3 gemaakt';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [lokale uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 passend bij “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent-werkruimte';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 nieuwe accounts';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 loopt · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2\'s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2-voorbeelden';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2-besturing in de wachtrij';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2-tokens';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2-tokens';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 en $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 is een beheerder geworden ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1-bytes';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1-kanaal';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1-tekens';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 gewist.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 geconfigureerd';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 aangesloten. Kies opslagplaatsen en mensen onder Wie kan berichten sturen.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 kernvermeldingen.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 heeft een uitnodigingslink gemaakt';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1-bureaublad';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1-evenementen';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 is mislukt';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 is mislukt';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 mislukt';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 voor $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1-groepen zijn alleen getagd';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h geleden';
  }

  @override
  String arg1HArg2M(Object? arg1, Object? arg2) {
    return '${arg1}h ${arg2}m';
  }

  @override
  String arg1HArg2Min(Object? arg1, Object? arg2) {
    return '$arg1 u $arg2 min';
  }

  @override
  String arg1Helpers(Object? arg1) {
    return '$arg1-helpers';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1-hitratio)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 is een beheerder, dus het account kan niet worden verwijderd ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 is geblokkeerd op $arg2. Werk de toegangslijst bij om antwoorden toe te staan.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 is verbonden en reageert.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 is niet langer een beheerder ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 is niet beschikbaar op $arg2 (ontbrekende runtime-toestemming of afhankelijkheid).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 is samengevoegd onder $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 gekeurd door LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1-sleutel$arg2 geconfigureerd';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1-sleutel verwijderd.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 links';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 links $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 gekoppeld';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m geleden';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m $arg2\'s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Zorg ervoor dat deze actief is en probeer het opnieuw.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 beheert dit account';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '${arg1}MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 min';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 min. $arg2 sec';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return '$arg1-modellen klaar';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 meer';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 meer stappen in de loopgeschiedenis';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 verplaatst van $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 moet een eindig getal zijn.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 moet een http://- of https://-adres zijn.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 heeft aandacht nodig';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent-werkruimte';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nieuwe accounts in de laatste $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nieuwe berichten sturen deze run';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nieuwe runs';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 beheert nu dit account.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 van 4 machtigingen toegestaan. Bestanden zijn beperkt tot uw NeoAgent Workspace-map.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 of $arg2 ingeschakeld';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 van de $arg2-groepen nemen deel aan de gewone chat';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1- of $arg2-modellen';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1- of $arg2-modellen gereed';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 of $arg2-set';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1- of $arg2-gereedschappen toegestaan';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Oké';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 op dag $arg2 bij $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 reageert alleen op de mensen die je hieronder toevoegt.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 antwoordt alleen als hij getagd wordt';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 praat alleen met mensen en groepen die u goedkeurt';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 mensen of groepen toegevoegd';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1-planning';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1-aanbieders';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 klaar';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1-records';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1-omleidings-URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 geregistreerd';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 heeft geantwoord';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 heeft een uitnodigingslink ingetrokken';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 wordt uitgevoerd';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 draait · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 draait in de laatste $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 opgeslagen.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sec';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 geselecteerd';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 afgebeeld';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 bleef stil';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 stuur $arg2 in de wachtrij';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 stap$arg2 · tik op een knooppunt om te inspecteren';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1-stappen';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 is gestopt met het beheer van $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1-tokens';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1-tokens in de laatste $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1-gereedschappen';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (niet beschikbaar opgeslagen overschrijving)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% gebruikt · $arg2 resterend';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 wil met je praten.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1-web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" wordt permanent verwijderd.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 beheert dit account';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 reageert niet op dit platform';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 antwoordt niet op $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Artefactopslag door gebruiker';

  @override
  String get askAQuestionOrStartA => 'Stel een vraag of start een taak...';

  @override
  String get askBeforeClosingToBackground =>
      'Vraag voordat u sluit naar de achtergrond';

  @override
  String get askMe => 'Vraag het mij';

  @override
  String get assignedAgent => 'Toegewezen agent';

  @override
  String get assignedAgent2 => 'Toegewezen agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Toegewezen agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Ontvanger (optioneel)';

  @override
  String get assistant => 'Assistent';

  @override
  String get assistantKey131 => 'Assistent-toets 131';

  @override
  String get atLeast1 => 'Minstens 1.';

  @override
  String get attachFiles => 'Bestanden bijvoegen';

  @override
  String attentionArg1(Object? arg1) {
    return 'Let op $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'auditlogboek beheerder subsidie intrekken uitnodiging teamgeschiedenis';

  @override
  String get authMethod => 'Authenticatiemethode';

  @override
  String get authServerUrl => 'URL van de authenticatieserver';

  @override
  String get authentication => 'Authenticatie';

  @override
  String get authenticationFailed => 'Authenticatie mislukt.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'De authenticatie is nog niet afgerond. Voltooi de stappen in de browser en probeer het opnieuw.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'De authenticatie is nog niet afgerond. Voltooi de stappen in de browser en vernieuw.';

  @override
  String get authenticationTimedOut =>
      'Er is een time-out opgetreden bij de authenticatie.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'De authenticatie is geannuleerd voordat deze was voltooid.';

  @override
  String get authenticatorApp => 'Authenticator-app';

  @override
  String get authenticatorCode => 'Authenticatiecode';

  @override
  String get authorOptional => 'Auteur (optioneel)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (eerste provider met een API-sleutel)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatische routes naar het best beschikbare model';

  @override
  String get automaticFast => 'Automatisch (snel)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatisch leest de kamer en houdt normaal gesproken tegen. Mention-only neemt geen besluit tot er direct wordt geadresseerd.';

  @override
  String get automaticReserved => 'Automatisch, gereserveerd';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatisch terugdraaien vereist een nieuwe poging vanaf het installatiescherm.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatisch selecteert een snel model via de normale modellencatalogus.';

  @override
  String get automation => 'Automatisering';

  @override
  String get available => 'Beschikbaar';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Opnieuw verkrijgbaar in $arg1';
  }

  @override
  String get availableAgainShortly => 'Binnenkort weer beschikbaar';

  @override
  String get availableInTheDesktopAppFor =>
      'Beschikbaar in de desktop-app voor macOS, Windows en Linux';

  @override
  String get availableToTheAgent => 'Beschikbaar voor de makelaar';

  @override
  String get averageAllTime => 'Gemiddeld, altijd';

  @override
  String get avgImp => 'Gem. imp.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Gem/run: $arg1-tokens';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Vermijd herhaalde karakters en voor de hand liggende reeksen.';

  @override
  String get awaitingScan => 'Wachten op scannen';

  @override
  String get back => 'Terug';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count op de achtergrond';
  }

  @override
  String get backgroundTasks => 'Achtergrondtaken';

  @override
  String get backOn => 'terug aan.';

  @override
  String get backToChat => 'Terug naar chatten';

  @override
  String get backToFolder => 'Terug naar map';

  @override
  String get backToSignIn => 'Terug naar inloggen';

  @override
  String get backendChannel => 'Backend-kanaal';

  @override
  String get backendOnThisComputer => 'Backend op deze computer';

  @override
  String get backendSync => 'Backend-synchronisatie';

  @override
  String get backgroundLocationNeeded => 'Achtergrondlocatie vereist';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Achtergrondsynchronisatie blijft gepland op Android';

  @override
  String get badState => 'Slechte staat: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Basisimage en grootte van de virtuele QEMU-machines die worden uitgevoerd ';

  @override
  String get baseUrlOptional => 'Basis-URL (optioneel)';

  @override
  String get baseUrlTokenLocal => 'basis-URL-token lokaal';

  @override
  String get basicAuthentication => 'Basisauthenticatie';

  @override
  String get behaviorModules => 'Gedragsmodules';

  @override
  String get behaviorNotes => 'gedragsnotities';

  @override
  String get beta => 'Bèta';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden-referentiemakelaar';

  @override
  String get bitwardenItem => 'Bitwarden-artikel';

  @override
  String get bitwardenServer => 'Bitwarden-server';

  @override
  String get blankUsesCommon => 'Blank gebruikt \"algemeen\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank gebruikt de standaard callback';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Bij lege waarden worden de standaardinstellingen van de provider gebruikt.';

  @override
  String get block => 'Blok';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Binnenkomend bericht van $arg1 geblokkeerd.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubbles-compatibele brug';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles-server-URL';

  @override
  String get botToken => 'Bot-token';

  @override
  String get botTokenAndApprovedChats => 'Bot-token en goedgekeurde chats';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bot-token en server-/kanaaltoegang';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot-token, evenementen-API en kanaaltoegang';

  @override
  String get botUserId => 'Bot-gebruikers-ID';

  @override
  String get botUsername => 'Bot-gebruikersnaam';

  @override
  String get brandName => 'Merknaam';

  @override
  String get braveSearch => 'Moedig zoeken';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Overbrug elke provider die webhook-payloads kan posten en ontvangen.';

  @override
  String get bringYourOwnKey => 'neem je eigen sleutel mee';

  @override
  String get bringYourOwnKey2 => 'Neem uw eigen sleutel mee';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Browser, Linux-desktop, bestanden, terminal en Python delen één persistente cloudcomputer.';

  @override
  String get browserLogin => 'Browser-aanmelding';

  @override
  String get browserScripting => 'Browserscripting';

  @override
  String get call => 'Bel';

  @override
  String get callAgent => 'Bel agent';

  @override
  String get callUser => 'Gebruiker bellen';

  @override
  String get calledByName => 'Bij naam genoemd';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Kan taken delegeren aan andere agenten';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Kan delegeren aan $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Kan gedelegeerde taken ontvangen';

  @override
  String get cancel => 'Annuleren';

  @override
  String get cancelTask => 'Taak annuleren';

  @override
  String get cannotPreview => 'Kan geen voorbeeld bekijken';

  @override
  String get cannotReceiveDelegatedTasks =>
      'kan geen gedelegeerde taken ontvangen';

  @override
  String get cannotRunYet => 'kan nog niet draaien.';

  @override
  String get capturedThePage => 'De pagina vastgelegd';

  @override
  String get category => 'Categorie';

  @override
  String chainArg1(Object? arg1) {
    return 'Ketting: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Wijzig de instelmodus';

  @override
  String get channel => 'Kanaal';

  @override
  String get channelAccessToken => 'Kanaaltoegangstoken';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanaal: $arg1$arg2 | Updateversie: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Kanaalgericht sociaal geheugen';

  @override
  String get channels => 'Kanalen';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'Chat-ID';

  @override
  String get chatMode => 'Chatmodus';

  @override
  String get chatModel => 'Chatmodel';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Controleer automatisch bij het opstarten';

  @override
  String get checkForMessagesEveryMs => 'Controleer elke (ms) op berichten';

  @override
  String get checkForNewMessagesAutomatically =>
      'Controleer automatisch op nieuwe berichten';

  @override
  String get checkNow => 'Controleer nu';

  @override
  String get checkYourEmailToConfirmYour =>
      'Controleer uw e-mail om uw NeoAgent-account te bevestigen voordat u zich aanmeldt.';

  @override
  String checkedArg1(Object? arg1) {
    return '$arg1 gecontroleerd';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Kies een categorie of zoek in alle instellingen.';

  @override
  String get chooseAPerson => 'Kies een persoon';

  @override
  String get chooseAProjectFolder => 'Kies een projectmap';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Kies standaardinstellingen voor chat, agenten, terugvalgedrag en slimme routering.';

  @override
  String get chooseGroups => 'Kies groepen';

  @override
  String get chooseHowMuchYouWantTo =>
      'Kies nu hoeveel u wilt configureren. Beide opties kunnen later worden gewijzigd.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Kies hoe deze taak moet starten. Handmatig werkt alleen op Nu uitvoeren. Het schema is op tijd gebaseerd. Integratie activeert vuur vanuit verbonden officiële apps.';

  @override
  String get chooseOneToGetStartedNow =>
      'Kies er één om nu aan de slag te gaan. Je kunt er later meer toevoegen.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Kies het live-model en de stem in Instellingen.';

  @override
  String get chooseTheirGroup => 'Kies hun groep';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Kies waar deze persoon met $arg1 mag praten. Je kunt dit later wijzigen onder Wie kan berichten sturen.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Kies van welke groepen $arg1 lid moet worden, zelfs als niemand hem tagt. Dit platform kan tags niet onderscheiden van reguliere berichten.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Kies welke modellen elk account op deze server kan kiezen en ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Kies met wie $arg1 praat en wanneer hij deelneemt aan groepschats.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Kies wie $arg1 kan bereiken en sla vervolgens uw wijzigingen op.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Kies wie de agent een bericht mag sturen met \"Wie kan een bericht sturen\" op de WhatsApp-kaart.';

  @override
  String get chooseYourDefaultModel => 'Kies uw\nstandaardmodel.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, bestanden, de teksteditor en terminal zijn allemaal beschikbaar vanaf de Linux-desktop.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Wissen';

  @override
  String get clearAll => 'Alles wissen';

  @override
  String clearArg1(Object? arg1) {
    return '$arg1 wissen?';
  }

  @override
  String get clearFilter => 'Wis filter';

  @override
  String get clearFilters => 'Filters wissen';

  @override
  String get clearSearch => 'Duidelijke zoekopdracht';

  @override
  String get clearView => 'Duidelijk zicht';

  @override
  String get cliSession => 'CLI-sessie';

  @override
  String get clickIsNotSupportedOnThis =>
      'klik wordt niet ondersteund op dit platform.';

  @override
  String get clickOnceToBeginCapturing =>
      'Klik één keer om te beginnen met vastleggen';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klik, typ en communiceer met desktop-apps.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Geklikt op ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'In de browser geklikt';

  @override
  String get clientId => 'Klant-ID';

  @override
  String get clientSecret => 'Klantgeheim';

  @override
  String get close => 'Sluiten';

  @override
  String get closeJ => 'Sluiten (⌘J)';

  @override
  String get closeTeachMode => 'Sluit de leermodus';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Door het venster te sluiten kan NeoAgent op de achtergrond blijven draaien met toegang tot de lade, of kan de desktopruntime volledig worden afgesloten.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Cloud- en zelf-gehoste instanties worden ondersteund. Lokale en particuliere netwerk-URL\'s werken wanneer NeoAgent deze kan bereiken.';

  @override
  String get cloudComputer => 'Computer in de cloud';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloudcomputer · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Cloudcomputerinstellingen opgeslagen. Start de server opnieuw op om ze toe te passen.';

  @override
  String get cloudComputerVm => 'Cloudcomputer (VM)';

  @override
  String get cloudComputers => 'Cloudcomputers';

  @override
  String get codeHosting => 'Code-hosting';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Door komma\'s gescheiden kanaalnamen, zonder #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Door komma\'s gescheiden, bijvoorbeeld #algemeen, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Komma gescheiden. De kwestie moet ze allemaal hebben.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Opdracht mislukt ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Commando is vereist.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Commando-uitvoeraccumulator is niet actief.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Uploaden van opdrachtuitvoer mislukt ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Bij het uploaden van opdrachtuitvoer zijn artefactmetagegevens weggelaten.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'De opdrachtuitvoer was al voltooid.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Commando\'s en apps';

  @override
  String get commandsRunInTheSamePersistent =>
      'Commando\'s worden uitgevoerd op dezelfde persistente computer die wordt gebruikt door het zichtbare bureaublad.';

  @override
  String get communityChatops => 'Gemeenschap en ChatOps';

  @override
  String get completeSetup => 'Volledige installatie';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Voltooi de workflow op het bureaublad.';

  @override
  String get completed => 'Voltooid';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Volledig geblokkeerd: de agent kan deze categorie niet gebruiken.';

  @override
  String get computerShell => 'Computeromhulsel';

  @override
  String get computerUsedByThisSession => 'Computer gebruikt door deze sessie';

  @override
  String get computerWorkspace => 'Computerwerkruimte';

  @override
  String get configurablePersonalWebhookBridge =>
      'Configureerbare persoonlijke webhookbridge';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Configureerbare relais- of webhookbridge';

  @override
  String get configurableTalkWebhookBridge =>
      'Configureerbare Talk-webhookbridge';

  @override
  String get configurableWebInboxBridge => 'Configureerbare web-inbox-bridge';

  @override
  String get configurableWebhookBridge => 'Configureerbare webhookbridge';

  @override
  String get configurableWebhooks => 'Configureerbare webhooks';

  @override
  String get configurationOrInTheEnvFile =>
      'Configuratie of in het .env-bestand.';

  @override
  String get configure => 'Configureer';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configureer werkruimtegedrag en modelstandaarden.';

  @override
  String configuredArg1(Object? arg1) {
    return '$arg1 geconfigureerd';
  }

  @override
  String get confirmEmailChanges => 'Bevestig e-mailwijzigingen';

  @override
  String get confirmNewSignUps => 'Bevestig nieuwe aanmeldingen';

  @override
  String get confirmPassword => 'Bevestig wachtwoord';

  @override
  String get confirmPassword2 => 'Bevestig wachtwoord';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Bevestig uw e-mailadres voordat u zich aanmeldt. Controleer het service-e-mailbericht van NeoAgent.';

  @override
  String get connect => 'Verbinden';

  @override
  String get connectAMessagingPlatform => 'Verbind een\nberichtenplatform.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Verbind een openbaar HTTPS Home Assistant-eindpunt met een langlevend toegangstoken. Lokale, loopback- en particuliere netwerkadressen worden door de server geblokkeerd.';

  @override
  String get connectAccount => 'Account verbinden';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Verbind app-accounts afzonderlijk, zodat de AI voor elke officiële integratie het juiste account kan gebruiken.';

  @override
  String connectArg1(Object? arg1) {
    return 'Sluit $arg1 aan';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Verbind zoveel accounts als je wilt. Elke app kan een ander account gebruiken.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Verbind kanalen, kies met wie $arg1 praat en bekijk recente activiteiten.';
  }

  @override
  String get connectInstance => 'Connect-instantie';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Sluit eerst deze integratie aan om een account te kiezen.';

  @override
  String get connectToThisServer => 'Maak verbinding met deze server';

  @override
  String get connectWhatsapp => 'Verbind WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Verbind uw Nextcloud-instantie, inclusief zelf-gehoste servers. NeoAgent opent de eigen inlogpagina van Nextcloud, zodat u kunt inloggen met wachtwoord, SSO of 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Verbind uw zelf-gehoste NeoRecall-server. NeoAgent krijgt alleen-lezen toegang tot lokale zoekopdrachten, herinneringen en transcriptiebewijs nadat u het OAuth-scherm heeft goedgekeurd.';

  @override
  String get connected => 'Verbonden';

  @override
  String get connectedAccount => 'Verbonden account';

  @override
  String connectedArg1(Object? arg1) {
    return 'Verbonden $arg1';
  }

  @override
  String get connectedInstance => 'Verbonden exemplaar';

  @override
  String get connectedNeorecallUser => 'Verbonden NeoRecall-gebruiker';

  @override
  String get connectedNextcloudUser => 'Verbonden Nextcloud-gebruiker';

  @override
  String get connectedServer => 'Verbonden server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Verbinding maken met het live stemmodel...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Verbinding #$arg1';
  }

  @override
  String get connectionId => 'Verbindings-ID';

  @override
  String get connectionLooksGood => 'Verbinding ziet er goed uit.';

  @override
  String get connectionMethod => 'Verbindingsmethode';

  @override
  String get containsTextOptional => 'Bevat tekst (optioneel)';

  @override
  String get content => 'Inhoud';

  @override
  String get contentSecurityPolicy => 'inhoud beveiligingsbeleid';

  @override
  String get continue2 => 'Ga door';

  @override
  String get continueFullSetup => 'Ga door met de volledige installatie';

  @override
  String get continueRun => 'Ga door met rennen';

  @override
  String get continueToSetup => 'Ga door met instellen';

  @override
  String get controlSurface => 'CONTROLE-OPPERVLAK';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Beheert de toegang tot $arg1-tools.';
  }

  @override
  String get conversation => 'Gesprek';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Gespreks-ID die wordt gebruikt wanneer deze agent een chat start.';

  @override
  String get cookieSetup => 'Cookie-instelling';

  @override
  String get cookiesNotConfigured => 'Cookies niet geconfigureerd';

  @override
  String get copiedAsCsv => 'Gekopieerd als CSV';

  @override
  String get copiedDebugInfo => 'Foutopsporingsinformatie gekopieerd';

  @override
  String get copiedExportForTheLast5 =>
      'Gekopieerde export voor de laatste 5 berichten';

  @override
  String get copiedFullPrompt => 'Volledige prompt gekopieerd';

  @override
  String get copiedLogs => 'Gekopieerde logboeken';

  @override
  String get copiedRunId => 'Gekopieerde run-ID';

  @override
  String get copy => 'Kopieer';

  @override
  String get copyAll => 'Kopieer alles';

  @override
  String get copyCodes => 'Codes kopiëren';

  @override
  String get copyCsv => 'Kopieer CSV';

  @override
  String get copyDebugInfo => 'Kopieer debug-informatie';

  @override
  String get copyLink => 'Kopieer link';

  @override
  String get copyLogs => 'Kopieer logboeken';

  @override
  String get copyPrompt => 'Kopieerprompt';

  @override
  String get copyResponse => 'Kopieer het antwoord';

  @override
  String get copyRunId => 'Kopieer run-ID';

  @override
  String get copyWebhookUrl => 'Kopieer de webhook-URL';

  @override
  String get core => 'Kern';

  @override
  String get coreMemory => 'kern geheugen';

  @override
  String get coreServicesThisServerDependsOn =>
      'Kernservices waarvan deze server afhankelijk is.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors-domein https openbare URL-oorsprong';

  @override
  String get couldHelp => 'Zou kunnen helpen';

  @override
  String get couldNotApproveQrLogin => 'Kan QR-login niet goedkeuren.';

  @override
  String get couldNotApproveQrPairing => 'Kan QR-koppeling niet goedkeuren.';

  @override
  String get couldNotConnect => 'Kan geen verbinding maken.';

  @override
  String get couldNotCreateBinding => 'Kan geen binding creëren.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Kan uw account niet verwijderen: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Kan Bitwarden niet ontkoppelen.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Kan Home Assistant niet loskoppelen.';

  @override
  String get couldNotDisconnectNeorecall => 'Kan NeoRecall niet loskoppelen.';

  @override
  String get couldNotDisconnectNextcloud => 'Kan Nextcloud niet ontkoppelen.';

  @override
  String get couldNotDisconnectTrello => 'Kon Trello niet ontkoppelen.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Kan uw gegevens niet exporteren: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Kan beslissingen niet laden';

  @override
  String get couldNotLoadUsageData => 'Kan gebruiksgegevens niet laden.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Kan Linux-instellingen niet automatisch openen.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Kan de linkpagina van de provider niet openen.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Kan de aanmeldingspagina van de provider niet openen.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Kan het release-item niet openen.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Kan Trello niet openen in je browser.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Kan het downloaden van het werkruimtebestand niet openen.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Kon het Android-apppakket niet lezen.';

  @override
  String get couldNotReadTheApk => 'Kon de APK niet lezen.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Kan sleutel niet verwijderen: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Kan agent niet opslaan.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Kan de Bitwarden-installatie niet opslaan.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Kan de Home Assistant-configuratie niet opslaan.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Kan de NeoRecall-installatie niet opslaan.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Kan de Nextcloud-installatie niet opslaan.';

  @override
  String get couldNotSaveTrelloSetup => 'Kan Trello-installatie niet opslaan.';

  @override
  String get couldNotSendConfirmationEmail =>
      'kon geen bevestigingsmail verzenden';

  @override
  String get couldNotStart => 'Kon niet starten';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Creëer';

  @override
  String get createAPasswordFirstToChange =>
      'Maak eerst een wachtwoord aan om het e-mailadres van uw account te wijzigen.';

  @override
  String get createAPasswordOrLinkAnother =>
      'maak een wachtwoord aan of koppel een andere provider voordat u deze inlogmethode verwijdert';

  @override
  String get createATaskWhileThisAgent =>
      'Maak een taak terwijl deze agent is geselecteerd.';

  @override
  String get createLink => 'Maak een koppeling';

  @override
  String get createOrModifyFilesInYour =>
      'Maak of wijzig bestanden in uw werkruimte.';

  @override
  String get createPassword => 'Wachtwoord aanmaken';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Creëer gespecialiseerde bots met afzonderlijk geheugen, instellingen, tools en accounttoewijzingen.';

  @override
  String get createTheFirstAccount => 'Maak het eerste account aan';

  @override
  String get createUpdateOrDeleteSkills =>
      'Vaardigheden maken, bijwerken of verwijderen.';

  @override
  String get creatingYourSkill => 'Je vaardigheden creëren...';

  @override
  String get credentialBindings => 'Referentiebindingen';

  @override
  String get credentialUse => 'Referentiegebruik';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron-gebaseerde terugkerende runs en eenmalige getimede uitvoering.';

  @override
  String get cronExpression => 'Cron-expressie';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter voert de query uit.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Spatie';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Huidig e-mailadres: $arg1';
  }

  @override
  String get currentPassword => 'Huidig wachtwoord';

  @override
  String get currentPasswordIsIncorrect => 'huidige wachtwoord is onjuist';

  @override
  String get currentTwoStepLoginCode => 'Huidige tweestaps-inlogcode';

  @override
  String get customAccess => 'Aangepaste toegang';

  @override
  String get customCron => 'Aangepaste cron';

  @override
  String get customCronMustHave5Fields =>
      'Aangepaste Cron moet 5 velden bevatten.';

  @override
  String get customEndpoint => 'aangepast eindpunt';

  @override
  String get customField => 'Aangepast veld';

  @override
  String get customHeader => 'Aangepaste koptekst';

  @override
  String get customHeadersJson => 'Aangepaste headers (JSON)';

  @override
  String get customOpenaiCompatible => 'Aangepaste OpenAI-compatibel';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Aangepast OpenAI-compatibel eindpunt';

  @override
  String get customOutgoingUrl => 'Aangepaste uitgaande URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Dagelijks';

  @override
  String get dailyRecap => 'Dagelijkse samenvatting';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'databasequery selecteer csv-sjablonen';

  @override
  String dayArg1(Object? arg1) {
    return 'Dag $arg1';
  }

  @override
  String get dayOfMonth => 'Dag van de maand';

  @override
  String get decideWhichToolsYourAgentMay =>
      'bepaal welke hulpmiddelen uw agent mag gebruiken. Ze zien je naam en ';

  @override
  String get decisionHigherUpTheChainWins =>
      'beslissing hogerop in de keten wint en toont een slot met de ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Beslissingen worden hier weergegeven terwijl $arg1 goedgekeurde $arg2-groepen leest. Alleen de laatste 30 worden bewaard en worden gereset wanneer de server opnieuw opstart.';
  }

  @override
  String get decline => 'Weigeren';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'diepe run · stap $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram-sleutel';

  @override
  String get default2 => 'Standaard';

  @override
  String get default3 => 'STANDAARD';

  @override
  String defaultArg1(Object? arg1) {
    return 'Standaard ($arg1)';
  }

  @override
  String get defaultConversation => 'Standaardgesprek';

  @override
  String get defaultForNewGroups => 'Standaard voor nieuwe groepen';

  @override
  String get defaultGroupParticipation => 'Standaard groepsdeelname';

  @override
  String get defaultNeoagentWorkspace => 'Standaard NeoAgent-werkruimte';

  @override
  String get defaultOpenai => 'Standaard (OpenAI)';

  @override
  String get defaultRateLimits => 'Standaard tarieflimieten';

  @override
  String get defaultRateLimitsSaved => 'Standaard tarieflimieten opgeslagen.';

  @override
  String get defaultRecommended => 'Standaard (aanbevolen)';

  @override
  String get defaultRouting => 'Standaardroutering';

  @override
  String get defaultSpace => 'Standaardruimte';

  @override
  String get delete => 'Verwijderen';

  @override
  String get deleteAccount => 'Account verwijderen';

  @override
  String get deleteAccountPermanently => 'Account definitief verwijderen?';

  @override
  String get deleteAnAccount => 'Verwijder een account';

  @override
  String deleteArg1(Object? arg1) {
    return '@$arg1 verwijderen?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Verwijderen ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 definitief verwijderen?';
  }

  @override
  String get deleteBinding => 'Binding verwijderen';

  @override
  String get deleteCoreMemoryEntry => 'Kerngeheugeninvoer verwijderen?';

  @override
  String get deleteForever => 'Voor altijd verwijderen';

  @override
  String get deleteMcpServer => 'MCP-server verwijderen?';

  @override
  String get deleteMemory => 'Geheugen verwijderen?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Verwijderen wist permanent een account en alle bijbehorende gegevens ';

  @override
  String get deleteRun => 'Uitvoering verwijderen?';

  @override
  String get deleteRun2 => 'Uitvoering verwijderen';

  @override
  String get deleteSelectedMemories =>
      'Geselecteerde herinneringen verwijderen?';

  @override
  String get deleteSession => 'Sessie verwijderen?';

  @override
  String get deleteSkill => 'Vaardigheid verwijderen?';

  @override
  String get deleteTask => 'Taak verwijderen?';

  @override
  String deletedArg1(Object? arg1) {
    return '\"$arg1\" verwijderd.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return '@$arg1 en al hun gegevens verwijderd.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Door te verwijderen worden al uw gesprekken, herinneringen, bestanden, taken en andere bestanden verwijderd ';

  @override
  String get deliverableArtifactProduced => 'Leverbaar artefact geproduceerd';

  @override
  String get deliverableCompleted => 'Leverbaar voltooid';

  @override
  String get deliverableExecutionStarted => 'Leveringsuitvoering gestart';

  @override
  String get deliverableSelected => 'Leverbaar geselecteerd';

  @override
  String get deliverableValidationFailed =>
      'Validatie van het leverbare product is mislukt';

  @override
  String get deliverableValidationStarted =>
      'Validatie van leverbare producten is gestart';

  @override
  String get deny => 'Weigeren';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Beschrijf het resultaat en demonstreer het vervolgens op het bureaublad';

  @override
  String get describeWhatToBuildOrChange =>
      'Beschrijf wat u wilt bouwen of veranderen...';

  @override
  String get description => 'Beschrijving';

  @override
  String get desktopApp => 'Desktop-app';

  @override
  String get desktopAppControlsAvailable =>
      'Bedieningselementen voor desktop-apps beschikbaar';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Bureaubladopname is niet beschikbaar op dit platform.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Uploaden van bureaubladopdrachtuitvoer geannuleerd.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'De opdracht Desktop Companion is geannuleerd.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Er is een time-out opgetreden bij de verbinding met de desktopcompagnon.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Er is een time-out opgetreden voor de handshake van de desktopbegeleider.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Desktop Companion is hier niet beschikbaar.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Bureaubladbegeleider wordt lokaal gepauzeerd.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Verwerking van begeleidende berichten op het bureaublad is mislukt: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Instellingen voor machtigingen voor bureaubladbegeleiders zijn niet beschikbaar op internet.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Toestemmingsinstellingen voor desktopbegeleiders zijn niet beschikbaar op dit platform.';

  @override
  String get desktopCompanionRejected => 'Desktopgenoot afgewezen.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Reactie van desktopcompagnon mislukt: $arg1';
  }

  @override
  String get desktopControl => 'Bureaubladbediening';

  @override
  String get desktopFailedToStart => 'Het bureaublad kan niet worden gestart';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Vastleggen van desktopstream mislukt: $arg1';
  }

  @override
  String get destinationId => 'Bestemmings-ID';

  @override
  String get deviceAccess => 'Toegang tot apparaat';

  @override
  String get deviceSettings => 'Apparaatinstellingen';

  @override
  String get devices => 'Apparaten';

  @override
  String get diagnosticsSaved => 'Diagnostiek opgeslagen.';

  @override
  String get directBluebubblesImessageBridge =>
      'Directe BlueBubbles iMessage-bridge';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Directe berichten blijven responsief. Groepen die op de toelatingslijst staan, gebruiken de onderstaande deelnamemodus.';

  @override
  String get directoryDoesNotExist => 'Directory bestaat niet.';

  @override
  String get disable2fa => 'Schakel 2FA uit';

  @override
  String get disableAll => 'Schakel alles uit';

  @override
  String get discard => 'Gooi weg';

  @override
  String get disconnect => 'Verbreek de verbinding';

  @override
  String get disconnectHomeAssistant => 'Home Assistant loskoppelen?';

  @override
  String get disconnectNeorecall => 'NeoRecall ontkoppelen?';

  @override
  String get disconnectNextcloud => 'Nextcloud ontkoppelen?';

  @override
  String get disconnectPlatform => 'Platform loskoppelen';

  @override
  String get disconnectTrello => 'Trello loskoppelen?';

  @override
  String get discoveryFailed => 'Ontdekking mislukt';

  @override
  String get dismiss => 'Negeren';

  @override
  String get displayIdIsRequired => 'Weergave-ID is vereist.';

  @override
  String get displayName => 'Weergavenaam';

  @override
  String get displayNameMustBe64Characters =>
      'De weergavenaam moet 64 tekens of minder bevatten.';

  @override
  String get displayNameSaved => 'Weergavenaam opgeslagen.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Vermeld niet uw gebruikersnaam of e-mailadres.';

  @override
  String get done => 'Klaar';

  @override
  String get downloadACopyOfYourData =>
      'Download een kopie van uw gegevens. Beheerdersaccounts kunnen niet worden verwijderd ';

  @override
  String get downloadACopyOfYourData2 =>
      'Download een kopie van uw gegevens of verwijder uw account definitief. ';

  @override
  String downloadArg1(Object? arg1) {
    return '$arg1 downloaden';
  }

  @override
  String get downloadUpdate => 'Update downloaden';

  @override
  String get downloadingTheNeoagentBackend => 'De NeoAgent-backend downloaden';

  @override
  String get draft => 'Diepgang';

  @override
  String get dragIsNotSupportedOnThis =>
      'slepen wordt niet ondersteund op dit platform.';

  @override
  String get draggedOnTheScreen => 'Op het scherm gesleept';

  @override
  String get dropAnApkOrApkBundle =>
      'Zet hier een APK of APK-bundel neer om deze te installeren';

  @override
  String get dropApkOrApksHere => 'Zet hier APK of .apks neer';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Duurzame instructies voor stem- en interactiestijl. Veiligheids- en uitvoeringsregels hebben nog steeds prioriteit.';

  @override
  String get eGAlexSLaptop => 'bijv. De laptop van Alex';

  @override
  String get eGMyLocalServer => 'bijv. Mijn lokale server';

  @override
  String get edit => 'Bewerken';

  @override
  String get editAgent => 'Agent bewerken';

  @override
  String get editCoreMemoryEntry => 'Bewerk het kerngeheugenitem';

  @override
  String get editInstructions => 'Instructies bewerken';

  @override
  String get editMcpServer => 'MCP-server bewerken';

  @override
  String get editTask => 'Taak bewerken';

  @override
  String editedArg1(Object? arg1) {
    return '$arg1 bewerkt';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-mail accounteigenaren over aanmeldingen die er ongebruikelijk uitzien.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'E-mail accounteigenaren wanneer hun accountgegevens veranderen.';

  @override
  String get emailCode => 'E-mailcode';

  @override
  String get emailConfirmationRequired => 'e-mailbevestiging vereist';

  @override
  String get emailIsAlreadyInUse => 'e-mail is al in gebruik';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail opgeslagen. Als bevestiging vereist is, controleer dan het nieuwe adres op een NeoAgent-bevestigingslink.';

  @override
  String get emailSettingsSaved => 'E-mailinstellingen opgeslagen.';

  @override
  String get emailUnverified => 'E-mail niet geverifieerd';

  @override
  String get empty => 'Leeg';

  @override
  String get emptyFile => 'Leeg bestand';

  @override
  String get emptyFolder => 'Lege map';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Leeg gebruikt de serverstandaard ($arg1).';
  }

  @override
  String get enable2fa => 'Schakel 2FA in';

  @override
  String get enableAll => 'Schakel alles in';

  @override
  String get enableBehaviorModules => 'Gedragsmodules inschakelen';

  @override
  String get enableOrDisableModels => 'Modellen in- of uitschakelen';

  @override
  String get enabled => 'Ingeschakeld';

  @override
  String get encryptedPrivateToYourAccount =>
      'Gecodeerd, privé voor uw account';

  @override
  String get end => 'Einde';

  @override
  String get endCall => 'Beëindig gesprek';

  @override
  String get endVoiceCall => 'Spraakoproep beëindigen?';

  @override
  String get endpoint => 'Eindpunt';

  @override
  String get enterAPassword => 'Voer een wachtwoord in.';

  @override
  String get enterAUsername => 'Voer een gebruikersnaam in.';

  @override
  String get enterAValidEmailAddress => 'Voer een geldig e-mailadres in.';

  @override
  String get enterAnAddressManually => 'Voer handmatig een adres in';

  @override
  String get enterAnApiKeyFirst => 'Voer eerst een API-sleutel in.';

  @override
  String get enterInviteLink => 'Voer de uitnodigingslink in';

  @override
  String get enterTheAddressOfANeoagent =>
      'Voer het adres van een NeoAgent-server in.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Voer de gegevens in die $arg1 u heeft gegeven, zodat $arg2 berichten kan verzenden en ontvangen.';
  }

  @override
  String get enterYour2faOrRecoveryCode => 'Voer uw 2FA- of herstelcode in.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Voer uw huidige wachtwoord in om het te wijzigen.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Voer uw huidige wachtwoord in om e-mailwijzigingen op te slaan.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Voer uw NeoAgent-accountgegevens in.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Voer uw gebruikersnaam of account-e-mailadres in. NeoAgent zal een resetlink sturen als deze overeenkomt met het account.';

  @override
  String get enterYourUsernameOrEmail =>
      'Voer uw gebruikersnaam of e-mailadres in.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entiteit: $arg1';
  }

  @override
  String get environment => 'Milieu';

  @override
  String get error => 'Fout';

  @override
  String errorArg1(Object? arg1) {
    return '\nfout: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Fouten uit het recente logboek, gegroepeerd op bericht.';

  @override
  String get errorsProblemsFailures => 'fouten problemen mislukkingen';

  @override
  String get eventTypesCommaSeparated =>
      'Gebeurtenistypen (door komma\'s gescheiden)';

  @override
  String get every15Minutes => 'Elke 15 minuten';

  @override
  String get every30Minutes => 'Elke 30 minuten';

  @override
  String get everyAccountOnThisServerLoses =>
      'Elk account op deze server verliest deze gedeelde sleutel. Rekeningen ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'elk account op deze server. Geheimen kunnen alleen worden geschreven: vertrek ';

  @override
  String get everyAccountOnThisServerUses =>
      'Elk account op deze server gebruikt dit adres voor ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Elke actieve sessie voor dit account eindigt. Zij kunnen inloggen ';

  @override
  String get everyDay0800 => 'Elke dag · 08:00 uur';

  @override
  String get everyDay2000 => 'Elke dag · 20:00 uur';

  @override
  String get everyHour => 'Elk uur';

  @override
  String get everyRunOnThisServerAll => 'Elke run op deze server, altijd.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Elk gevoelig gereedschap vereist elke keer goedkeuring.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Elke tool werkt zonder te vragen, behalve degene die de persoon is ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Iedereen in deze groepen, kanalen of kamers kan met $arg1 praten.';
  }

  @override
  String get everyoneInThisGroup => 'Iedereen in deze groep';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Alles wat $arg1 voor uw agent heeft uitgeschakeld, komt ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Al het andere is uitgeschakeld.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Alles is beschikbaar vanaf de desktop.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Alles wat de agent kan gebruiken: officiële integraties, MCP-servers en vaardigheden.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Alles wat u voor $arg1 hebt uitgeschakeld, komt terug ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Exacte weboorsprong toegestaan om cross-origineverzoeken te doen, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Voer JavaScript uit in uw browsersessie.';

  @override
  String get execution => 'Uitvoering';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Uitvoeringsdetails zijn niet beschikbaar voor deze run.';

  @override
  String get executionPlanCreated => 'Uitvoeringsplan gemaakt.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Oefen $arg1-sessies';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[afsluiten $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Verloopt op $arg1';
  }

  @override
  String get explainThisProject => 'Leg dit project uit';

  @override
  String exploredArg1(Object? arg1) {
    return '$arg1 onderzocht';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1$arg2 onderzocht';
  }

  @override
  String get exploredTheWorkspace => 'De werkruimte verkend';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Exporteren mislukt: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exporteer de laatste 5 berichten';

  @override
  String get exportMyData => 'Exporteer mijn gegevens';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Externe browserstart mislukt met afsluitcode $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Het extern starten van een browser wordt niet ondersteund op dit platform.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Er is een time-out opgetreden bij het starten van de externe browser.';

  @override
  String get externalMcpTools => 'Externe en MCP-tools';

  @override
  String get extraButtons => 'Extra knoppen';

  @override
  String get extractingTheNeoagentRuntime => 'De NeoAgent-runtime extraheren';

  @override
  String get failed => 'Mislukt';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Kan geen verbinding maken: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kan geen verbinding maken met $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kan \"$arg1\" niet verwijderen: $arg2';
  }

  @override
  String get failedToFetch => 'kon niet worden opgehaald';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Kan prompt niet genereren: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Kan externe browser niet starten via url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Kan de OAuth-stroom niet starten.';

  @override
  String get failedToLoadPolicies => 'Kan beleid niet laden';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Opslaan mislukt: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Kan de MCP-server niet opslaan.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Kan selectie niet opslaan: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Kan melding niet naar backend sturen: $arg1';
  }

  @override
  String get fair => 'Eerlijk';

  @override
  String get fasterReplies => 'Snellere antwoorden';

  @override
  String get fewerModelCalls => 'Minder modeloproepen';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'veld leeg om de ingebouwde standaard te herstellen.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Bestand overschrijdt de editorlimiet van 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Bestand overschrijdt de ondersteunde groottelimiet.';

  @override
  String get fileWrites => 'Bestand schrijft';

  @override
  String get filename => 'Bestandsnaam';

  @override
  String get files => 'Bestanden';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Bestanden die NeoAgent in deze sessie schrijft of bewerkt, worden hier weergegeven.';

  @override
  String get filesSavedByAllUsers =>
      'Bestanden opgeslagen door alle gebruikers';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Vul goedgekeurde logins in of authenticeer verzoeken zonder geheimen aan de AI te tonen.';

  @override
  String get finalResponse => 'Laatste reactie';

  @override
  String get findAPlatform => 'Zoek een platform';

  @override
  String get findAndFixABug => 'Zoek en repareer een bug';

  @override
  String get findRecentChats => 'Vind recente chats';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Het vinden van de juiste NeoAgent-runtime';

  @override
  String get finish => 'Afwerking';

  @override
  String get finishAtTheScheduledTime => 'Eindig op de geplande tijd';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Voltooi het aanmelden bij $arg1 in uw browser en maak vervolgens opnieuw verbinding.';
  }

  @override
  String get flowGraph => 'Stroomgrafiek';

  @override
  String get flutterApp => 'Flutter-app';

  @override
  String get focusedExecutionProfile => 'Gericht uitvoeringsprofiel';

  @override
  String get folderIdOptional => 'Map-ID (optioneel)';

  @override
  String get folderUnavailable => 'Map niet beschikbaar';

  @override
  String get forExampleHttpsMatrixOrg => 'Bijvoorbeeld https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Voor gehoste of geavanceerde netwerkinstellingen';

  @override
  String get forLinksInEmailsBlankUses =>
      'Voor links in e-mails. Blank gebruikt de openbare URL van de server.';

  @override
  String get forgotPassword => 'Wachtwoord vergeten?';

  @override
  String get frameUnavailable => 'Kader niet beschikbaar';

  @override
  String freshnessArg1(Object? arg1) {
    return 'versheid: $arg1';
  }

  @override
  String get fridays1700 => 'Vrijdag · 17:00 uur';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Van BotFather nadat je de bot hebt gemaakt.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return '$arg1 bepaalt voortaan zelf welke tools jouw agent mag gebruiken. Zij ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Vanuit de Discord Developer Portal, onder uw bot.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Vanuit de LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Vanuit het Matrix-client- of botaccount.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Van twitchapps.com/tmi of je Twitch-ontwikkelaarsapp.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Volledige prompt';

  @override
  String get fullSetup => 'Volledige installatie';

  @override
  String get general => 'Algemeen';

  @override
  String get generalSettings => 'Algemene instellingen';

  @override
  String get generalSettingsSaved => 'Algemene instellingen opgeslagen.';

  @override
  String get generateAPromptForAnotherAi =>
      'Genereer een prompt voor een andere AI, plak het antwoord hier om herinneringen te importeren.';

  @override
  String get generatePrompt => 'Vraag genereren';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geofence-trackingfout: $arg1';
  }

  @override
  String get getInspired => 'Laat je inspireren';

  @override
  String get githubCopilot => 'GitHub-copiloot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot en OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHub-probleem geopend';

  @override
  String get neorecallMemoryCreated => 'NeoRecall-geheugen gemaakt';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'GitHub-releasecontrole mislukt met HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'De releasepayload van GitHub was geen releaselijst.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub-gebruikersnaam waarmee het probleem is geopend';

  @override
  String get globalSecurityMode => 'Globale beveiligingsmodus';

  @override
  String get gmailMessageReceived => 'Gmail-bericht ontvangen';

  @override
  String get good => 'Goed';

  @override
  String get goodAfternoon => 'Goedemiddag';

  @override
  String get goodEvening => 'Goedenavond';

  @override
  String get goodMorning => 'Goedemorgen';

  @override
  String get goodPasswordALittleMoreLength =>
      'Goed wachtwoord. Iets meer lengte maakt het sterker.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Werkruimte';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live gebruikt uw OpenAI API-sleutel, Gemini Live uw Google AI-sleutel. Wijzigingen gelden voor het volgende gesprek.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Verleen Health Connect-machtigingen voordat u gaat synchroniseren.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Groep, kanaal of kamer';

  @override
  String get groupType => 'Groepstype';

  @override
  String get groupsAndChannels => 'Groepen en kanalen';

  @override
  String groupsArg1(Object? arg1) {
    return 'Groepen: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Groepen die $arg1 nog niet gezien heeft, volgen dit.';
  }

  @override
  String get handlesDirectTasksItself => 'Voert directe taken zelf uit';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Handsfree (vrijuit praten, op elk moment onderbreken)';

  @override
  String get headerName => 'Kopnaam';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Koppen over de onderwerpen die u interesseren, gefilterd op signaal.';

  @override
  String get health => 'Gezondheid';

  @override
  String get healthChecks => 'Gezondheidscontroles';

  @override
  String get healthConnect => 'gezondheid verbinden';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect is niet beschikbaar op dit apparaat.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health Connect-synchronisatiestatus en opgeslagen backend-statistieken.';

  @override
  String get healthStatusIsUnavailable =>
      'Gezondheidsstatus is niet beschikbaar.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Gezondheidssynchronisatie is alleen beschikbaar op Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Hart $arg1-records';
  }

  @override
  String get heldBack => 'Teruggehouden';

  @override
  String get helper => 'Helper';

  @override
  String helperArg1(Object? arg1) {
    return 'Helper: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'hier. Trek de beheerder in met eerst \'neoagent admin revoke $arg1\'.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Hogere waarden maken NeoAgent selectiever in groepen.';

  @override
  String get highlyRecommended => 'Sterk aanbevolen';

  @override
  String get holdButton131ForTheAssistant =>
      'Houd knop 131 voor de assistent ingedrukt.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Houd Ctrl+Shift+Spatie ingedrukt om te praten';

  @override
  String get holdToTalk => 'Houd ingedrukt om te praten.';

  @override
  String get holdToTalk2 => 'Houd ingedrukt om te praten';

  @override
  String get home => 'Thuis';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Home Assistant langlevende toegangstoken is vereist.';

  @override
  String get homeAssistantSetup => 'Thuisassistent instellen';

  @override
  String get homeAssistantUrl => 'Home Assistant-URL';

  @override
  String get homeAssistantUrlIsRequired => 'Home Assistant-URL is vereist.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Homeserver-token met kamerpeiling';

  @override
  String get homeserverUrl => 'Homeserver-URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'gehoste dienst). Uw sleutels zijn gecodeerd en kunnen alleen worden gebruikt door ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Hostnaam van het IRC-netwerk, bijvoorbeeld irc.libera.chat';

  @override
  String get hourly => 'Per uur';

  @override
  String get hourlyInboxCheck => 'Uurlijkse inboxcontrole';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Hoe lang bevestigingslinks geldig blijven.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Hoe vaak deze agent naar nieuwe chatberichten zoekt.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Hoe vaak deze agent zoekt naar nieuwe Signal-berichten.';

  @override
  String get howTeamsWork => 'Hoe teams werken';

  @override
  String get howThisServerIsReachedPlus =>
      'Hoe deze server wordt bereikt, plus serverbrede switches.';

  @override
  String get httpsSessionCookie => 'https-sessiecookie';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Ik kan dat verzoek nu niet voltooien. Probeer het over enkele ogenblikken opnieuw.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inactief';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Als $arg1 om een webhook-URL vraagt, plak deze dan zodat berichten $arg2 kunnen bereiken.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Als dat account een bevestigd e-mailadres heeft, zal NeoAgent een link voor het opnieuw instellen van het wachtwoord sturen.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Als de service een token vereist voor uitgaande verzoeken.';

  @override
  String get ignoreGroups => 'Negeer groepen';

  @override
  String get ignoreThisChat => 'Negeer deze chat';

  @override
  String get ignoredChannels => 'Genegeerde kanalen';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Misvormd begeleidend bericht op het bureaublad genegeerd: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Voer het bovenstaande plan uit.';

  @override
  String get implementThisPlan => 'Voer dit plan uit';

  @override
  String get implicitTls => 'Impliciete TLS';

  @override
  String get import => 'Importeren';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Importeren mislukt: $arg1';
  }

  @override
  String get importFromComputer => 'Importeren vanaf computer';

  @override
  String get importMemoryTransfer => 'Geheugenoverdracht importeren?';

  @override
  String get importance => 'Belang';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Geïmporteerde $arg1-herinneringen, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'In het team van @$arg1';
  }

  @override
  String get inBackground => 'achtergrond';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Hier verschijnen inkomende en uitgaande kanaalberichten.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Inkomende in-app spraakoproepen van NeoAgent';

  @override
  String get incomingMessages => 'Inkomende berichten';

  @override
  String get incomingNeoagentCall => 'Inkomende NeoAgent-oproep';

  @override
  String get incomingNeoagentCall2 => 'INKOMEND NEOAGENT-OPROEP';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Ondersteuning voor inkomende webhook en uitgaande terugbelondersteuning';

  @override
  String get incorporatingSteering => 'Inclusief besturing';

  @override
  String get input => 'Invoer';

  @override
  String get inputMode => 'Invoermodus';

  @override
  String get insertATemplate => 'Voeg een sjabloon in';

  @override
  String get install => 'Installeren';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installeer een ondertekende, op zichzelf staande runtime. Node.js-, npm-, Git- en terminalopdrachten zijn niet vereist.';

  @override
  String get installApk => 'Installeer APK';

  @override
  String get installApkBundle => 'Installeer APK / Bundel';

  @override
  String get installApkClickOrDropA =>
      'Installeer APK: klik of zet een .apk-bestand neer';

  @override
  String get installNeoagent => 'Installeer NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installeer NeoAgent op deze computer zonder terminal, of maak verbinding met een terminal die al actief is.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installeer nieuwe releases en kies welk kanaal deze server volgt.';

  @override
  String get installTheBackend => 'Installeer de backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installeer de kern met extra optionele instellingen. AI-providersleutels worden achteraf toegevoegd, hetzelfde als Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installeer de beveiligde kern en maak vervolgens uw account aan. Voeg achteraf AI-providersleutels toe.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Geïnstalleerd: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Geïnstalleerd: $arg1 • Laatst gecontroleerd: $arg2';
  }

  @override
  String get instructions => 'Instructies';

  @override
  String get integration => 'Integratie';

  @override
  String get integrationApps => 'Integratie-apps';

  @override
  String get integrationConnections => 'Integratie verbindingen';

  @override
  String get integrationSettingsSaved => 'Integratie-instellingen opgeslagen.';

  @override
  String get integrations => 'Integraties';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integraties/oauth/callback, en registreer hetzelfde ';

  @override
  String get interruptAi => 'Onderbreek AI';

  @override
  String get invalid2fa => 'ongeldig 2fa';

  @override
  String get invalidArgumentS => 'Ongeldige argument(en): ';

  @override
  String get invalidCredentials => 'ongeldige inloggegevens';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Ongeldig NeoAgent-runtimemanifest.';

  @override
  String get inviteLink => 'Uitnodigingslink';

  @override
  String get inviteLinkReady => 'Uitnodigingslink klaar';

  @override
  String get inviteLinks => 'Links uitnodigen';

  @override
  String get iphoneApp => 'iPhone-app';

  @override
  String get issues => 'Problemen';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Er verschijnen problemen zodra het logboek is geladen.';

  @override
  String get itCanTBeUndone => 'Het kan niet ongedaan worden gemaakt.';

  @override
  String get itMayHaveBeenDeleted => 'Mogelijk is deze verwijderd.';

  @override
  String get javaRuntime => 'Java-runtime';

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
    return 'Aangesloten bij $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'De afgelopen 7 dagen lid geworden';

  @override
  String get joiningATeam => 'Deelnemen aan een team';

  @override
  String get joiningIsOffHere => 'Deelnemen is hier uitgeschakeld';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON-veld dat de berichttekst bevat. Meestal tekst.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON-veld dat aangeeft voor wie het bericht bedoeld is.';

  @override
  String get jumpToLatest => 'Ga naar de laatste';

  @override
  String get justNow => 'zojuist';

  @override
  String get keepNeoagentRunning => 'NeoAgent draaiende houden?';

  @override
  String get keepRunning => 'Blijf rennen';

  @override
  String get keepTaskRunning => 'Houd de taak actief';

  @override
  String get keepTheVaultAvailable => 'Houd de kluis beschikbaar';

  @override
  String get keepThisLauncherUpToDate =>
      'Houd dit opstartprogramma up-to-date.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Houd dit paneel open totdat het platform de verbinding bevestigt.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Houd de computer van deze sessie zichtbaar';

  @override
  String get keepTrackOfYourAiUsage =>
      'Houd uw AI-gebruik bij. Er worden limieten opgelegd om eerlijk gebruik op het hele platform te garanderen.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Blijf uw apps normaal gebruiken. NeoAgent werkt op hetzelfde scherm en vraagt ​​wanneer er nieuwe toegang nodig is.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Dit apparaat verbonden houden';

  @override
  String get key => 'Sleutel';

  @override
  String get keyIsRequired => 'Sleutel is vereist.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Sleutel-waardeparen die in gesprekken blijven bestaan.';

  @override
  String get knowledgeGraph => 'Kennisgrafiek';

  @override
  String get knowledgeView => 'Kennisweergave';

  @override
  String get labelOnlyYouSeeIt => 'Label (alleen jij ziet het)';

  @override
  String get labelsOptional => 'Etiketten (optioneel)';

  @override
  String get last24Hours => 'Afgelopen 24 uur';

  @override
  String get last7Days => 'Laatste 7 dagen';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Afgelopen 7 dagen: $arg1-tokens in $arg2-runs';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Laatste $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Laatste: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Laatste niet-lege synchronisatie · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Laatste run: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Laatst gezien $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Laatste aanmelding $arg1';
  }

  @override
  String get lastSyncSummary => 'Samenvatting laatste synchronisatie';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Laatst gebruikt: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Het laatste venster eindigde op $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'later start ook uitgeschakeld.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Laatste run · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Het starten van desktop-apps wordt niet ondersteund op dit platform.';

  @override
  String get learnRoomNorms => 'Leer kamernormen';

  @override
  String get leave => 'Vertrekken';

  @override
  String get leaveARedirectUriBlankTo =>
      'Laat een omleidings-URI leeg om <openbare URL>/api/ te gebruiken';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Het team van $arg1 verlaten?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Laat dit de standaardwaarde tenzij u BlueBubbles hebt aangepast.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Laat het token leeg om het momenteel opgeslagen token te behouden.';

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
    return 'Laat $arg1 mij beheren';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Laat iedereen in deze groep met $arg1 praten.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Laat het werken terwijl\nje dat niet doet.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Laat NeoAgent klikken, typen en door uw apps bladeren.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Laat NeoAgent begrijpen wat er op uw scherm zichtbaar is.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Laat iemand met wie u samenwerkt beslissen welke hulpmiddelen uw agent mag gebruiken ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Laat deze persoon $arg1 een één-op-één bericht sturen.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Laat deze persoon hier met $arg1 praten, maar niet in privéchats of andere groepen.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Laat deze persoon met $arg1 praten in privéchats en in elke groep die ze delen.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Niveau $arg1/$arg2$arg3';
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
  String get linkCopied => 'Link gekopieerd';

  @override
  String get linkExpiresAfter => 'Link verloopt daarna';

  @override
  String get linkLifetimeHours => 'Levensduur van link (uren)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'De levensduur van de link moet tussen 1 en 8760 uur liggen.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link geldig tot $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Gekoppelde aanmeldingsproviders';

  @override
  String get linuxApp => 'Linux-app';

  @override
  String listedArg1(Object? arg1) {
    return 'Vermeld $arg1/';
  }

  @override
  String get listening => 'Luisteren';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Live uitvoeringsgeschiedenis, toolstappen en reacties.';

  @override
  String get liveModel => 'Levend model';

  @override
  String get liveModelProvider => 'Aanbieder van live modellen';

  @override
  String get liveRun => 'Live rennen';

  @override
  String get liveVoice => 'Live-stem';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Live spraakverbinding is niet beschikbaar.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'De live spraakverbinding is gesloten.';

  @override
  String get liveVoiceDefaults => 'Standaardinstellingen voor live stem';

  @override
  String get liveVoiceFailed => 'Live stem mislukt.';

  @override
  String get llmMemoryExportResponse => 'LLM-geheugenexportreactie';

  @override
  String get loadFailed => 'laden mislukt';

  @override
  String get loadingExecutionDetails => 'Uitvoeringsdetails laden...';

  @override
  String get loadingNeoagent => 'NeoAgent laden';

  @override
  String get loadingRunFlow => 'Runstroom laden…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokale en particuliere netwerk-URL\'s worden ondersteund wanneer de NeoAgent-server deze kan bereiken. Audio wordt nooit blootgesteld aan NeoAgent.';

  @override
  String get localApp => 'lokale app';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokale backend-installatie is niet beschikbaar op dit platform.';

  @override
  String get localBaseImagePath => 'Lokaal basisimagepad';

  @override
  String get localComputerControlIsAvailableIn =>
      'Lokale computerbesturing is beschikbaar in de NeoAgent desktop-app op macOS, Windows en Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokale computerbesturing is hier niet beschikbaar.';

  @override
  String get localModelsUrl => 'lokale modellen-URL';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokale NeoAgent-detectie is tijdelijk niet beschikbaar.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokale voorkeuren voor de NeoAgent-applicatie. Computerbesturing loopt altijd via de uniforme cloudcomputer.';

  @override
  String get localSetup => 'LOKALE INSTELLING';

  @override
  String get locationCityOrPlace => 'Locatie (stad of plaats)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Locatie is vereist voor triggers van weergebeurtenissen';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Initialisatie van LocationService mislukt: $arg1';
  }

  @override
  String get logCopied => 'Logboek gekopieerd';

  @override
  String get loginPassword => 'Wachtwoord voor inloggen';

  @override
  String get logout => 'Uitloggen';

  @override
  String get logs => 'Logboeken';

  @override
  String get logsCopied => 'Logboeken gekopieerd.';

  @override
  String get logsOnThisComputer => 'Logt in op deze computer';

  @override
  String get longLivedAccessToken => 'Toegangstoken met lange levensduur';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Langetermijnherinnering, gestructureerde feiten en kennisgrafiek.';

  @override
  String get lookedAtTheScreen => 'Keek naar het scherm';

  @override
  String get lookingOnThisComputerAndYour =>
      'Kijkend op deze computer en uw lokale netwerk...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Kijkt vooruit naar de vergaderingen van morgen, zodat niets je verrast.';

  @override
  String get loopExecution => 'Uitvoering van lus';

  @override
  String get loopPaused => 'Lus onderbroken';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS Toegankelijkheid wordt niet verleend aan NeoAgent. Sta dit toe in Systeeminstellingen > Privacy en beveiliging > Toegankelijkheid.';

  @override
  String get macosApp => 'macOS-app';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'macOS-schermopname wordt niet verleend aan NeoAgent. Sta dit toe in Systeeminstellingen › Privacy en beveiliging › Schermopname en open NeoAgent vervolgens opnieuw.';

  @override
  String get mailServersThatNeedAPassword =>
      'Mailservers die een wachtwoord nodig hebben, zullen weigeren te verzenden totdat er een nieuw wachtwoord is ';

  @override
  String get main => 'Belangrijkste';

  @override
  String get makeDefault => 'Maak standaard';

  @override
  String get manage => 'Beheer';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Beheer het e-mailadres van uw account, tweefactorauthenticatie en actieve sessies.';

  @override
  String get managedBy => 'Beheerd door';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Managers kunnen hun eigen managers hebben (maximaal vier niveaus). EEN ';

  @override
  String get managing => 'Beheer';

  @override
  String get manualDestination => 'Handmatige bestemming';

  @override
  String get manualTrigger => 'Handmatige trigger';

  @override
  String get masterPassword => 'Hoofdwachtwoord';

  @override
  String get matchThisDevice => 'Match dit apparaat';

  @override
  String get matchedAgainstTitleAndBody => 'Afgestemd op titel en lichaam';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Komt overeen met de oude NeoAgent MCP-stroom: URL plus auth-methode.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP-server';

  @override
  String get mcpServer2 => 'MCP-server';

  @override
  String get mcpServerUrl => 'MCP-server-URL';

  @override
  String get mcpServers => 'MCP-servers';

  @override
  String get meantForSomeoneElse => 'Bedoeld voor iemand anders';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Gemeten modelkosten: $arg1';
  }

  @override
  String get memories => 'Herinneringen';

  @override
  String get memory => 'Geheugen';

  @override
  String memoryArg1(Object? arg1) {
    return 'Geheugen: $arg1';
  }

  @override
  String get memoryInjected => 'Geheugen geïnjecteerd';

  @override
  String get mentionOrReplyOnly => 'Alleen vermelden of reageren';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Samengevoegde server- en Flutter-runtimelogboeken voor deze app-sessie.';

  @override
  String get messageBodyTemplateJson => 'Berichttekstsjabloon (JSON)';

  @override
  String get messageNeedsAccess => 'Bericht heeft toegang nodig';

  @override
  String get messageTextField => 'Tekstveld voor bericht';

  @override
  String get messaging => 'Berichten';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Berichten-API-push- en webhook-gebeurtenissen';

  @override
  String get messagingConnectionNeedsAttention =>
      'Berichtenverbinding heeft aandacht nodig';

  @override
  String get messagingConnections => 'Berichtenverbindingen';

  @override
  String get messagingDelivery => 'Bezorging van berichten';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Berichtfout. Probeer het opnieuw.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Microfoonopname is onverwacht gestopt. Probeer het opnieuw.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Microfoonfout: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Microfoon gedempt. Tik om het dempen op te heffen.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Voor live stem is toestemming voor de microfoon vereist.';

  @override
  String get microsoft365 => 'Microsoft365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack en de andere integraties. Ze zijn van toepassing op ';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimale bijdragewaarde: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobiele installatie mislukt.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobiele installatie is mislukt omdat Java niet beschikbaar is op de machine waarop NeoAgent draait.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobiele installatie is mislukt omdat Java niet beschikbaar is op de machine waarop NeoAgent draait. Installeer een JDK en probeer het opnieuw.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobiele installatie mislukt. Controleer of de Android-tools correct zijn geïnstalleerd en probeer het opnieuw.';

  @override
  String modeArg1(Object? arg1) {
    return 'modus: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'De modus wordt vergrendeld terwijl er een run actief is.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Beschikbaarheid van modellen';

  @override
  String get modelAvailabilitySaved =>
      'Beschikbaarheid van modellen opgeslagen.';

  @override
  String get modelForThisSession => 'Model voor deze sessie';

  @override
  String get modelOverride => 'Modeloverschrijving';

  @override
  String get modelPending => 'Model in behandeling';

  @override
  String get modelTurn => 'Model beurt';

  @override
  String get modelTurnCompleted => 'Modelbeurt voltooid';

  @override
  String get modelTurnStarted => 'Modelbeurt begonnen';

  @override
  String get modelVisibilityHideShowList =>
      'zichtbaarheid van model verberg toon lijst';

  @override
  String get models => 'Modellen';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modellen, gedrag, stem en werkruimte';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modellen, browser, stem, diagnostiek...';

  @override
  String get modelsRouting => 'Modellen & routering';

  @override
  String get monthly => 'Maandelijks';

  @override
  String get moreActions => 'Meer acties';

  @override
  String get morningBriefing => 'Ochtend briefing';

  @override
  String get mostUsedAgents => 'Meest gebruikte middelen';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Meest gebruikte modellen in de laatste $arg1.';
  }

  @override
  String get mouseKeyboard => 'Muis & toetsenbord';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove wordt niet ondersteund op dit platform.';

  @override
  String get mustBeReachableOnThePublic =>
      'Moet bereikbaar zijn op het openbare internet - lokaal en ';

  @override
  String get n24Hours => '24 uur';

  @override
  String get n2faOrRecoveryCode => '2FA of herstelcode';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA vereist dat SESSION_SECRET wordt geconfigureerd op deze NeoAgent-implementatie.';

  @override
  String get n30Days => '30 dagen';

  @override
  String get n365Days => '365 dagen';

  @override
  String get n4HourLimitTokens => 'Limiet van 4 uur (tokens)';

  @override
  String get n4HourUsage => '4 uur gebruik';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4u-limiet $arg1';
  }

  @override
  String get n7DayUsage => '7 dagen gebruik';

  @override
  String get n7Days => '7 dagen';

  @override
  String get n90Days => '90 dagen';

  @override
  String get name => 'Naam';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnaam: Nieuwe vaardigheid\nbeschrijving: Beschrijf wat deze vaardigheid doet\n---\nSchrijf hier de instructies voor deze vaardigheid.\n';

  @override
  String get nameOfWhoeverMadeIt => 'naam van degene die het gemaakt heeft.';

  @override
  String get nameOptional => 'Naam (optioneel)';

  @override
  String get nativeAndWebhookChannels => 'Native en webhookkanalen';

  @override
  String get naturalBubbles => 'Natuurlijke bubbels';

  @override
  String get nearbyNeoagentServers => 'NeoAgent-servers in de buurt';

  @override
  String get needANewAccountRegister => 'Een nieuw account nodig? Registreren';

  @override
  String get needAnIdea => 'Een idee nodig?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Moet antwoorden · $arg1% om te spreken';
  }

  @override
  String get needsAttention => 'Heeft aandacht nodig';

  @override
  String get needsInput => 'Heeft input nodig';

  @override
  String get neoagentApp => 'NeoAgent-app';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent-assistent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent kon de beschikbare backend-runtime niet controleren.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent kon de lokale installatie niet voltooien.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent kon de lokale installatie niet voltooien. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent-foutopsporingsinformatie';

  @override
  String get neoagentDesktopInstaller =>
      'NeoAgent Desktop-installatieprogramma';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter-updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installeert de nieuwste $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent is geïnstalleerd en actief.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent is niet op deze computer geïnstalleerd.';

  @override
  String get neoagentIsReady => 'NeoAgent is klaar';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent werkt nog aan een taak. Beëindig het gesprek en ontvang het resultaat in de chat, of annuleer de taak ook.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent verandert uw demonstratie in een aanpasbare workflow.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent wacht terwijl u het bureaublad gebruikt.';

  @override
  String get neoagentIsWorking => 'NeoAgent werkt';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux-computer';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT HEEFT EEN BESLUIT NODIG';

  @override
  String get neoagentNoReplyExampleCom =>
      'NeoAgent <geen antwoord@voorbeeld.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Voor NeoAgent runtime-downloads is een veilig adres vereist.';

  @override
  String get neoagentServerAddress => 'NeoAgent-serveradres';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgent-service-e-mail is niet gereed. Vraag de serveroperator om de instellingen van de e-mailomgeving te controleren.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'De installatie van NeoAgent kon niet worden voltooid.';

  @override
  String get neoagentUser => 'NeoAgent-gebruiker';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent gebruikt deze computer automatisch en vraagt voordat deze uw scherm, muis, toetsenbord, bestanden of opdrachtregel gebruikt.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent gebruikt uw geschatte achtergrondlocatie om geofence-herinneringen te activeren (bijvoorbeeld \"Herinner mij eraan melk te kopen als ik langs de supermarkt loop\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent-werkruimte';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stapel] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall-backend-URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'NeoRecall-backend-URL is vereist.';

  @override
  String get neorecallSetup => 'NeoRecall-installatie';

  @override
  String get networkRequestFailed => 'netwerkverzoek mislukt';

  @override
  String get networkWriteRequests => 'Netwerkschrijfverzoeken';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'telt nooit mee voor de gedeelde gebruikslimieten.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Nieuwe accounts bevestigen hun e-mailadres voordat ze inloggen.';

  @override
  String get newAccountsPerDay => 'Nieuwe accounts per dag';

  @override
  String get newChat => 'Nieuwe chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nieuwe groepen blijven stil tenzij iemand $arg1 tagt, totdat u ze inschakelt.';
  }

  @override
  String get newLink => 'Nieuwe koppeling';

  @override
  String get newPasswordsDoNotMatch =>
      'Nieuwe wachtwoorden komen niet overeen.';

  @override
  String get newRecoveryCodes => 'Nieuwe herstelcodes';

  @override
  String get newSession => 'Nieuwe sessie';

  @override
  String get newSessionN => 'Nieuwe sessie (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nieuwe sessie met dezelfde setup';

  @override
  String get newSkill => 'Nieuwe vaardigheid';

  @override
  String get newSkill2 => 'Nieuwe vaardigheid';

  @override
  String get newThisWeek => 'Nieuw deze week';

  @override
  String get newsDigest => 'Nieuwsoverzicht';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Volgende nieuwe poging: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud-inlogstroom';

  @override
  String get nextcloudSetup => 'Volgendecloud-installatie';

  @override
  String get nextcloudTalk => 'Volgendecloud Talk';

  @override
  String get nextcloudUrl => 'Volgendecloud-URL';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloud-URL is vereist.';

  @override
  String get nickname => 'Bijnaam';

  @override
  String get noAccountsConnectedYet => 'Nog geen accounts gekoppeld.';

  @override
  String get noAccountsFound => 'Geen accounts gevonden.';

  @override
  String get noActiveSessionsFound => 'Geen actieve sessies gevonden.';

  @override
  String get noAgentsYet => 'Nog geen agenten';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Er is geen AI-provider geconfigureerd, dus chat en berichtenuitwisseling ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Geen goedkeuringsprompts: de agent werkt zonder onderbrekingen.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Geen enkel $arg1-release-item kwam overeen met dit platform.';
  }

  @override
  String get noArguments => '(geen argumenten)';

  @override
  String get noAuth => 'Geen autorisatie';

  @override
  String get noBindingsYet => 'Nog geen bindingen.';

  @override
  String get noChangesYet => 'Nog geen wijzigingen';

  @override
  String get noChannelsFound => 'Geen kanalen gevonden';

  @override
  String get noCloudComputerSlotIsFree =>
      'Er is momenteel geen slot voor een cloudcomputer gratis. Probeer het zo nog eens.';

  @override
  String get noCoreMemoryEntriesYet => 'Nog geen kerngeheugenvermeldingen.';

  @override
  String get noDescription => 'Geen beschrijving';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Er zijn momenteel geen desktopschermen beschikbaar.';

  @override
  String get noDetailAvailable => 'Geen details beschikbaar';

  @override
  String get noDetailedSyncSummaryYet =>
      'Nog geen gedetailleerd synchronisatieoverzicht.';

  @override
  String get noDetailsCaptured => 'Geen details vastgelegd.';

  @override
  String get noEmailLinked => 'Geen e-mail gekoppeld';

  @override
  String get noExternalSignInProvidersLinked =>
      'Er zijn geen externe aanmeldingsproviders gekoppeld.';

  @override
  String get noGroupMessagesYet => 'Nog geen groepsberichten';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Er zijn nog geen groepsspecifieke mensen toegevoegd.';

  @override
  String get noGroupsAddedYet => 'Nog geen groepen toegevoegd.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Nog geen groepen gevonden. Nadat $arg1 een groepsbericht heeft gezien, gebruikt u Recente chats zoeken en deze worden hier weergegeven.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Nog geen groepen gevonden. Nadat $arg1 een groepsbericht heeft gezien, gebruikt u Recente chats zoeken.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Er is geen payload voor gezondheidsgegevens geretourneerd.';

  @override
  String get noHealthSamplesStoredYet =>
      'Er zijn nog geen gezondheidsmonsters opgeslagen.';

  @override
  String get noHttpClientImplementationForThis =>
      'Geen HTTP-clientimplementatie voor dit platform.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Voor deze stap is geen invoer of uitvoer geregistreerd.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Er zijn geen integraties die overeenkomen met deze zoekopdracht.';

  @override
  String get noLimit => 'Geen limiet';

  @override
  String get noLocalPasswordIsSetYet =>
      'Er is nog geen lokaal wachtwoord ingesteld. Maak er een om inloggen met gebruikersnaam en wachtwoord mogelijk te maken.';

  @override
  String get noLogEntries => 'Geen logvermeldingen.';

  @override
  String get noMatchingSettings => 'Geen overeenkomende instellingen';

  @override
  String get noMcpServersMatchThisSearch =>
      'Er komen geen MCP-servers overeen met deze zoekopdracht.';

  @override
  String get noMemoryEntriesFound => 'Geen geheugenvermeldingen gevonden.';

  @override
  String get noMemorySync => 'Geen geheugensynchronisatie';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Leest eenmalig de belangrijke en verzonden mail van de afgelopen 12 maanden, zodat de agent je contacten en projecten kent.';

  @override
  String get emailMemory => 'E-mailgeheugen';

  @override
  String get importNow => 'Nu importeren';

  @override
  String get importOnConnect =>
      'Eerdere mail importeren bij het koppelen van een account';

  @override
  String get sweepStarting => 'Voorbereiden…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'E-mails lezen · $done van $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'E-mails lezen · $count gevonden';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Leren van e-mails · $done van $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Laatste import: $emails e-mails · $memories nieuwe herinneringen';
  }

  @override
  String get sweepNothingNew => 'Geen nieuwe e-mails om te importeren';

  @override
  String sweepFailed(String error) {
    return 'Importeren mislukt: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Geen enkel model komt overeen met \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Voor deze run is geen modelverzoek geregistreerd.';

  @override
  String get noModelsDiscoveredYet => 'Nog geen modellen ontdekt';

  @override
  String get noModelsSelected => 'Geen modellen geselecteerd';

  @override
  String get noModelsYet => 'Nog geen modellen';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'aan deze aanbieder is geen neoagent-account gekoppeld';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Er is geen NeoAgent backend-runtime beschikbaar voor deze computer.';

  @override
  String get noNetworkConnection => 'Geen netwerkverbinding';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Geen netwerkverbinding. Maak verbinding om NeoAgent te blijven gebruiken.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Geen netwerkverbinding. Maak opnieuw verbinding om te controleren op updates.';

  @override
  String get noOne => 'Niemand';

  @override
  String get noOneAddedYet => 'Nog niemand toegevoegd.';

  @override
  String get noOneCanMessage => 'Niemand kan een bericht sturen';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Er is geen andere NeoAgent-server gevonden. U kunt opnieuw zoeken of handmatig een adres invoeren.';

  @override
  String get noPeopleAddedYet => 'Er zijn nog geen mensen toegevoegd.';

  @override
  String get noPlatformsMatch => 'Er komen geen platforms overeen';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Er zijn nog geen providers beschikbaar om te configureren.';

  @override
  String get noRecentChannelActivity => 'Geen recente kanaalactiviteit';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Geen resultaat voor \'$arg1\'';
  }

  @override
  String get noRunsInThisRange => 'Geen runs in dit bereik.';

  @override
  String get noRunsMatchTheseFilters =>
      'Er zijn geen runs die overeenkomen met deze filters';

  @override
  String get noRunsYet => 'Nog geen runs';

  @override
  String get noRunsYet2 => 'Nog geen runs.';

  @override
  String get noSecurityKeyWasProvided =>
      'Er werd geen beveiligingssleutel verstrekt.';

  @override
  String get noServerUrlSet => 'Er is geen server-URL ingesteld';

  @override
  String get noSessionMatchesThatSearch =>
      'Er is geen sessie die overeenkomt met die zoekopdracht.';

  @override
  String get noSessionsYet => 'Nog geen sessies';

  @override
  String get noSkillsMatchTheseFilters =>
      'Er zijn geen vaardigheden die overeenkomen met deze filters.';

  @override
  String get noStepsWereRecordedForThis =>
      'Voor deze run zijn geen stappen geregistreerd.';

  @override
  String get noSummaryAvailable => 'Geen samenvatting beschikbaar.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Geen taken voor $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Geen enkel gereedschap komt overeen met \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Er wordt geen update uitgevoerd';

  @override
  String get noUsageYet => 'Nog geen gebruik.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Er is nog geen geverifieerde NeoAgent backend-runtime beschikbaar.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Niemand kan het meer gebruiken. Mensen die al lid zijn ';

  @override
  String get none => 'Geen';

  @override
  String get notApprovedYet => 'nog niet goedgekeurd';

  @override
  String get notAuthenticated => 'niet geauthenticeerd';

  @override
  String get notCheckedYet => 'Nog niet gecontroleerd';

  @override
  String get notConfigured => 'Niet geconfigureerd';

  @override
  String get notConnected => 'Niet verbonden';

  @override
  String get notConnected2 => 'Niet verbonden';

  @override
  String get notInstalled => 'Niet geïnstalleerd';

  @override
  String get notNeeded => 'Niet nodig';

  @override
  String get notNeededEnough => 'Niet genoeg nodig';

  @override
  String get notNow => 'Niet nu';

  @override
  String get notNow2 => 'Niet nu';

  @override
  String get notSet => 'Niet ingesteld';

  @override
  String get notSetUp => 'Niet ingesteld';

  @override
  String get notTheSameAsAdmin => 'Niet hetzelfde als beheerder';

  @override
  String get nothingFound => 'Niets gevonden';

  @override
  String get nothingHereYet => 'Hier nog niets.';

  @override
  String get nothingHereYet2 => 'Hier nog niets';

  @override
  String get nothingMatches => 'Niets komt overeen';

  @override
  String get nothingStoredYet => 'Nog niets opgeslagen.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'OAuth-app-inloggegevens waarmee accounts verbinding kunnen maken met Google, ';

  @override
  String get oauthClientId => 'OAuth-client-ID';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth client-id geheime omleiding API-sleutel';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth client-id geheime omleiding gmail-agendastation';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth-lancering wordt niet ondersteund op dit platform.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'OAuth Outlook Tenant-client-ID geheim';

  @override
  String get oauthToken => 'OAuth-token';

  @override
  String get oauthWithPkce => 'OAuth met PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'van $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'van zichzelf. Na het opslaan wordt deze nooit meer weergegeven.';

  @override
  String get off => 'Uit';

  @override
  String get officialIntegration => 'Officiële integratie';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Officiële integratie heeft geen verbindings-URL geretourneerd.';

  @override
  String get on => 'Aan';

  @override
  String get onASignedInAndroidDevice =>
      'Open op een ingelogd Android-apparaat Instellingen › Aanmelden en beveiliging, scan deze code en keur de aanmelding goed.';

  @override
  String get onByDefaultForNewGroups =>
      'Standaard ingeschakeld voor nieuwe groepen';

  @override
  String get onDemand => 'Op aanvraag';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Aan voor $arg1- of $arg2-groepen';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'op. Ze kunnen alleen opnieuw deelnemen met een nieuwe uitnodigingslink.';

  @override
  String get onYourOwnTheDefault => 'Zelf (de standaard)';

  @override
  String get once => 'Een keer';

  @override
  String get oneBlankToKeepWhatIs =>
      'één blanco om te bewaren wat is opgeslagen.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'één wordt gered. Andere wijzigingen in dit formulier worden ook opgeslagen.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Een of meer accounts zijn verlopen. Maak opnieuw verbinding met het getroffen account om de toegang tot het hulpprogramma te herstellen.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Eén runtime regelt persona, groepsbeurten, ruimtegeheugen, normen, Theory of Mind en levering.';

  @override
  String get oneTimeRun => 'Eenmalige run';

  @override
  String get onlyApkOrApksFilesCan =>
      'Alleen .apk- of .apks-bestanden kunnen worden geïnstalleerd.';

  @override
  String get onlyInThisGroup => 'Alleen in deze groep';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Alleen nodig als de service om extra HTTP-headers vraagt.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Alleen nodig als u de uitgaande lading opnieuw wilt vormgeven.';

  @override
  String get onlyTheyCanChangeIt => 'Alleen zij kunnen het veranderen.';

  @override
  String get open => 'Openen';

  @override
  String get openAccountSettingsOnASigned =>
      'Open Instellingen › Aanmelden en beveiliging op een ingelogd Android-apparaat, scan deze code en keur de aanmelding goed.';

  @override
  String get openComputer => 'Computer openen';

  @override
  String get openDashboard => 'Dashboard openen';

  @override
  String get openFolder => 'Map openen…';

  @override
  String get openInWorkbench => 'Open in werkbank';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Open NeoAgent en maak opnieuw verbinding met $arg1 om de berichtenuitwisseling te herstellen.';
  }

  @override
  String get openTimeSettings => 'Instellingen voor open tijd';

  @override
  String get openToAnyone => 'Open voor iedereen';

  @override
  String get openTrello => 'Trello openen';

  @override
  String get openVoiceAssistant => 'Open stemassistent';

  @override
  String get openWiFiSettings => 'Open Wi-Fi-instellingen';

  @override
  String get openWithTheDefaultApp => 'Open met de standaardapp';

  @override
  String get openaiCodex => 'OpenAI-codex';

  @override
  String get openaiCompatible => 'openai-compatibel';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-compatibel eindpunt (uw eigen server of een andere ';

  @override
  String openedArg1(Object? arg1) {
    return '$arg1 geopend';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Het openen van desktop-URL\'s wordt niet ondersteund op dit platform.';

  @override
  String get openingYourSavedDesktop => 'Uw opgeslagen bureaublad openen.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Uw opgeslagen bureaublad openen. Normaal starten duurt minder dan 10 seconden.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Optioneel extra geheim als u de inkomende webhook beveiligt.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Optioneel overschrijven als de webhook-URL niet voldoende is.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Optioneel geheim om binnenkomende chatgebeurtenissen te verifiëren.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Optioneel geheim om binnenkomende gebeurtenissen te verifiëren.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Optioneel geheim om binnenkomende iMessage-gebeurtenissen te verifiëren.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Optioneel geheim om binnenkomende LINE-gebeurtenissen te verifiëren.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Optioneel geheim om binnenkomende Mattermost-gebeurtenissen te verifiëren.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Optioneel geheim om binnenkomende Teams-gebeurtenissen te verifiëren.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Optioneel. De agent heeft al een eigen persoonlijkheid. Alles wat u aan de toon toevoegt, wordt er bovenop gelegd, zodat u er nooit een hoeft te definiëren.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Optioneel. Indien ingesteld, wordt deze gebruikt in plaats van de URL.';

  @override
  String get orAnswerInYourOwnWords => 'Of antwoord in je eigen woorden';

  @override
  String get orBuildYourOwnTask => 'Of bouw uw eigen taak';

  @override
  String get orContinueWith => 'of doorgaan met';

  @override
  String get orFiles => 'of bestanden.';

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
  String get originNotAllowed => 'herkomst niet toegestaan';

  @override
  String get outgoingMessage => 'Uitgaand bericht';

  @override
  String get outgoingWebhookUrl => 'Uitgaande webhook-URL';

  @override
  String get outlookEmailReceived => 'Outlook-e-mail ontvangen';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Gedragsnotities van de import overschrijven.';

  @override
  String get ownModel => 'eigen model';

  @override
  String get packageName => 'Pakketnaam';

  @override
  String get pairWithQrCode => 'Koppel met QR-code';

  @override
  String get password => 'Wachtwoord';

  @override
  String get password2faAndActiveSessions =>
      'Wachtwoord, 2FA en actieve sessies';

  @override
  String get passwordCreated => 'Wachtwoord aangemaakt.';

  @override
  String get passwordIsTooWeak => 'wachtwoord is te zwak';

  @override
  String get passwordMin8 => 'wachtwoord minimaal 8';

  @override
  String get passwordOrApiKey => 'Wachtwoord of API-sleutel';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Wachtwoordsterkte: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Wachtwoorden komen niet overeen.';

  @override
  String get pasteAKey => 'Plak een sleutel.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Plak een nieuwe sleutel om $arg1 te vervangen';
  }

  @override
  String get pasteTheKey => 'Plak de sleutel';

  @override
  String get pasteYourAccountToken => 'Plak uw accounttoken';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Plak hieronder uw $arg1 API-sleutel. Het is ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Het pad moet binnen de NeoAgent-werkruimte blijven.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Het pad moet binnen de werkruimtemap blijven.';

  @override
  String get pauseLiveUpdates => 'Pauzeer live-updates';

  @override
  String get pauseTaskLoop => 'Pauzeer de taaklus';

  @override
  String get paused => 'Gepauzeerd';

  @override
  String peakArg1(Object? arg1) {
    return 'piek $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Mensen in privéchats';

  @override
  String get perAccountRateLimits => 'Tarieflimieten per account';

  @override
  String get perCategoryPermissions => 'Machtigingen per categorie';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Toestemmingsbeleid per tool, goedkeuringspoorten en procesisolatie voor shell-uitvoering.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Toestemming vereist: $arg1';
  }

  @override
  String get permissionsNeeded => 'Machtigingen nodig';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Machtigingen. Niemand anders kan dat veranderen.';

  @override
  String get personOrChat => 'Persoon of chat';

  @override
  String get personaBehaviorNotes => 'Persona-gedragsnotities';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Persoonlijk toegangstoken voor de Mattermost-bot.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Persoonlijke kanalen en directe steunvlakken.';

  @override
  String get personalSelfChat => 'Persoonlijke zelfschat';

  @override
  String get phoneNumber => 'Telefoonnummer';

  @override
  String get pickARunFromTheList =>
      'Kies een run uit de lijst om de stappen ervan te zien.';

  @override
  String get pickARunFromTheList2 =>
      'Kies een run uit de lijst aan de linkerkant om het verloop ervan te verkennen.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Kies uit recente $arg1-chats of voeg zelf een persoon of groep toe.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Kies hoe $arg1 dit account gebruikt.';
  }

  @override
  String get pickOneToFillInThe =>
      'Kies er één om de taak in te vullen. Je kunt achteraf alles aanpassen.';

  @override
  String get picksUpWhereYouLeftOff => 'Ga verder waar je was gebleven';

  @override
  String get plan => 'Plannen';

  @override
  String get planning => 'Plannen';

  @override
  String get platform => 'Platform';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platform $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Kies een schema.';

  @override
  String get pleaseEnterAFilename => 'Voer een bestandsnaam in.';

  @override
  String get pleaseEnterAKey => 'Voer een sleutel in.';

  @override
  String get pleaseEnterAPrompt => 'Voer een prompt in.';

  @override
  String get pleaseEnterATaskName => 'Voer een taaknaam in.';

  @override
  String get pleaseEnterTheMemoryContent => 'Voer de geheugeninhoud in.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Voer in wanneer de taak moet worden uitgevoerd.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Selecteer een account of voer een geldige verbindings-ID in.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Wijs NeoAgent op elke OpenAI-compatibele chatvoltooiing ';

  @override
  String get pointTheCameraAtTheCode =>
      'Richt de camera op de code die wordt weergegeven op het uitgelogde apparaat. Goedkeuring blijft op deze telefoon staan.';

  @override
  String get port => 'Haven';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env openbare URL trust proxy veilige cookies-implementatie';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Premium automatisering met plannings- en integratietriggers.';

  @override
  String get prepareQrCode => 'Bereid QR-code voor';

  @override
  String get preparingNeoagent => 'NeoAgent voorbereiden…';

  @override
  String get preparingNeoagent2 => 'NeoAgent voorbereiden';

  @override
  String get pressAndHoldForQuickCapture => 'Houd ingedrukt voor snelle opname';

  @override
  String get pressKeysIsNotSupportedOn =>
      'druktoetsen worden niet ondersteund op dit platform.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Druk op $arg1';
  }

  @override
  String get priceUnknown => 'Prijs onbekend';

  @override
  String get primaryDisplay => 'Primaire weergave';

  @override
  String get privateChat => 'Privéchat';

  @override
  String get privateChats => 'Privéchats';

  @override
  String get privateChats2 => 'privéchats';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privéchats: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privéchats $arg1 · groepen $arg2';
  }

  @override
  String get privateChatsOnly => 'Alleen privéchats';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privénetwerkadressen zijn niet toegestaan.';

  @override
  String get profileEmailAndPersonalData =>
      'Profiel-, e-mail- en persoonlijke gegevens';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Prompt voordat NeoAgent in het systeemvak blijft staan.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Prompt cache: $arg1 tokens in de cache ';
  }

  @override
  String get promptCopied => 'Prompt gekopieerd.';

  @override
  String get promptOrSchedule => 'prompt of schema.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Vraag om in een andere AI te plakken';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Het koppelen van providers kan niet worden gestart.';

  @override
  String get providerSignInCouldNotBe =>
      'Het aanmelden bij de provider kan niet worden gestart.';

  @override
  String get providers => 'Aanbieders';

  @override
  String get providersEachAccountCanStillPick =>
      'Aanbieders; elk account kan nog steeds zijn eigen model kiezen in Instellingen. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Providers, integraties, spraak en optionele mogelijkheden kunnen op elk moment via Instellingen worden voltooid.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Openbare kwestie- en pull-verzoekthreads, alleen beantwoord voor goedgekeurde mensen.';

  @override
  String get publicUrl => 'Openbare URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Openbare URL en toegestane oorsprong';

  @override
  String get publicUrlOverride => 'Openbare URL overschrijven';

  @override
  String get pullsTogetherTheDayAhead => 'Trekt samen de komende dag';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'QR-gebaseerde telefoonkoppeling';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR-login voltooid, maar NeoAgent kon de sessie niet behouden. Probeer het opnieuw.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR-login kon niet worden gestart.';

  @override
  String get qrLoginRequestHasExpired => 'qr-inlogverzoek is verlopen';

  @override
  String get qrLoginRequestWasNotFound => 'qr-inlogverzoek is niet gevonden';

  @override
  String get qrPairing => 'QR-koppeling';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'zoekopdrachten worden uitgevoerd; alles wat schrijft wordt afgewezen.';

  @override
  String get queryFilter => 'Opvragen/filteren';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'In de wachtrij als besturing voor de huidige run: $arg1';
  }

  @override
  String get quickstart => 'Snelstart';

  @override
  String get quit => 'Stoppen';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'regen_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Voerde een script uit op de pagina';

  @override
  String ranArg1(Object? arg1) {
    return 'Voerde $arg1 uit';
  }

  @override
  String get rateLimits => 'Tarieflimieten';

  @override
  String get readAnArtifact => 'Lees een artefact';

  @override
  String get readAndEditFilesInsideYour =>
      'Lees en bewerk bestanden in uw NeoAgent Workspace-map.';

  @override
  String readArg1(Object? arg1) {
    return 'Lees $arg1';
  }

  @override
  String get readError => 'Leesfout';

  @override
  String get readFiles => 'Bestanden lezen';

  @override
  String get readOnly => 'Alleen lezen';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Lees de map en vat de stapel samen, de toegangspunten en hoe u deze moet uitvoeren.';

  @override
  String get readThePage => 'Lees de pagina';

  @override
  String get readTheUiTree => 'Lees de UI-structuur';

  @override
  String get readWrite => 'Lezen / schrijven';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Leest stappen, hartslag, slaap, lichaamsbeweging en gewicht.';

  @override
  String get ready => 'Klaar';

  @override
  String get readyForFirstTimeSetup => 'Klaar voor de eerste installatie';

  @override
  String get readyToConnect => 'Klaar om verbinding te maken';

  @override
  String get recentChannelActivity => 'Recente kanaalactiviteit';

  @override
  String get recentChats => 'Recente chats';

  @override
  String get recentDecisions => 'Recente beslissingen';

  @override
  String get recentFailedRuns => 'Recente mislukte runs';

  @override
  String get recentGroupDecisions => 'Recente groepsbeslissingen';

  @override
  String get recentRuns => 'Recente runs';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Recente runs duren ongeveer $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Recente serveruitvoer, nieuwste eerst.';

  @override
  String get recentUsage4Hours => 'Recent gebruik (4 uur)';

  @override
  String get recents => 'Recent';

  @override
  String get recipientField => 'Ontvangerveld';

  @override
  String get reconnectOrFinishSetup =>
      'Maak opnieuw verbinding of voltooi de installatie';

  @override
  String get reconnectingThisDevice => 'Dit apparaat opnieuw verbinden…';

  @override
  String get recurring => 'Terugkerend';

  @override
  String get redirectUri => 'Omleidings-URI';

  @override
  String get redoOnboarding => 'Onboarding opnieuw uitvoeren';

  @override
  String get refresh => 'Vernieuwen';

  @override
  String get refreshCode => 'Vernieuwingscode';

  @override
  String get refreshNow => 'Vernieuw nu';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Vernieuw het Android-scherm om het opnieuw te proberen.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Weigeren om te verzenden, tenzij de verbinding wordt geüpgraded naar TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'ongeacht de onderstaande instellingen per categorie.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registreer $arg1 voor de assistent-oproepstroom.';
  }

  @override
  String get registrationIsClosed => 'inschrijving is gesloten';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registratie registreer nieuwe accounts sta aanmelding toe';

  @override
  String get rejectInvalidTlsCertificates =>
      'Weiger ongeldige TLS-certificaten';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'loslaten en opnieuw opstarten. Verbonden apps maken opnieuw verbinding zodra deze terug is.';

  @override
  String get releaseChannel => 'Kanaal vrijgeven';

  @override
  String get releaseCommitBranchNode => 'geef het commit-takknooppunt vrij';

  @override
  String get releaseWhenYouAreDone => 'Laat los als je klaar bent.';

  @override
  String get reloadNow => 'Herlaad nu';

  @override
  String get rememberThisChoice => 'Onthoud deze keuze';

  @override
  String get remove => 'Verwijderen';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return '\"$arg1\" en de geregistreerde stappen uit de rungeschiedenis verwijderen?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Verwijder \"$arg1\" uit het kerngeheugen.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return '$arg1-sleutel verwijderen?';
  }

  @override
  String get removeEraseGdprUser => 'verwijder gdpr-gebruiker verwijderen';

  @override
  String get removeSmtpPassword => 'SMTP-wachtwoord verwijderen';

  @override
  String get removeTheSmtpPassword => 'Het SMTP-wachtwoord verwijderen?';

  @override
  String get rename => 'Hernoemen';

  @override
  String get renameSecurityKey => 'Hernoem de beveiligingssleutel';

  @override
  String get renameSession => 'Sessie hernoemen';

  @override
  String get repairAndRetry => 'Repareer en probeer het opnieuw';

  @override
  String get repairDesktop => 'Bureaublad repareren';

  @override
  String get repeat => 'Herhaal';

  @override
  String get repliesWhenTagged => 'Reageert wanneer getagd';

  @override
  String get replyToAddress => 'Antwoordadres';

  @override
  String replyToArg1(Object? arg1) {
    return 'Reageer op $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'De repository moet de indeling eigenaar/repository hebben.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproduceer de bug die ik beschrijf, zoek de oorzaak en repareer deze met een regressietest.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'verzoek mislukt met http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Verzoek mislukt met HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Vraag machtigingen aan';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Verzoek aan $arg1 mislukte voordat de backend reageerde.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return '$arg1 aangevraagd';
  }

  @override
  String get requireStarttls => 'STARTTLS vereisen';

  @override
  String get requiredBehindHttpsOrATls =>
      'Vereist achter HTTPS of een TLS-proxy. Geldt na een server ';

  @override
  String get requiredExampleBerlinDe => 'Vereist. Voorbeeld: Berlijn, DE';

  @override
  String get requiredFormatOwnerRepo => 'Vereist. Formaat: eigenaar/repository';

  @override
  String get reserveAssistantHotkey => 'Reserve-assistent sneltoets';

  @override
  String get reset => 'Opnieuw instellen';

  @override
  String get resetPassword => 'Wachtwoord opnieuw instellen';

  @override
  String get resetView => 'Weergave opnieuw instellen';

  @override
  String get responsibilities => 'Verantwoordelijkheden';

  @override
  String get restart => 'Opnieuw opstarten';

  @override
  String get restartToFinishTheUpdate =>
      ' Start opnieuw op om de update te voltooien.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'De vorige NeoAgent-runtime herstellen';

  @override
  String get restrictDelegationTargets => 'Beperk delegatiedoelen';

  @override
  String get result => 'Resultaat';

  @override
  String get resultDelivery => 'Resultaat levering';

  @override
  String get resultOneClickAddsOneYou =>
      'resultaat. Met één klik wordt er één toegevoegd; je kunt het later bewerken.';

  @override
  String get results => 'Resultaten';

  @override
  String get retry => 'Opnieuw proberen';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Herbruikbaar · gebruikte $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Bekijk niet-vastgelegde wijzigingen';

  @override
  String get revoke => 'Intrekken';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Trek de beheerder in met eerst \'neoagent admin revoke $arg1\'';
  }

  @override
  String get revokeThisLink => 'Deze link intrekken?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Kamerbatchvenster: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Draai om door te gaan';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rijen. Voeg een LIMIT of een smallere WHERE-clausule toe om te zien ';

  @override
  String get rule => 'Regel';

  @override
  String get run => 'Uitvoering';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Voer willekeurige opdrachten uit op uw machine of VM.';

  @override
  String get runAt => 'Ren bij';

  @override
  String get runCompleted => 'Uitvoering voltooid';

  @override
  String get runFailed => 'Uitvoering mislukt';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Voer git diff uit, bekijk de niet-vastgelegde wijzigingen op bugs en stijlproblemen, en vat samen wat je vindt.';

  @override
  String get runNotFound => 'Uitvoering niet gevonden';

  @override
  String get runNow => 'Nu uitvoeren';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Run op inkomende persoonlijke WhatsApp-berichten.';

  @override
  String get runQuery => 'Query uitvoeren';

  @override
  String get runShellCommandsOrInstallApps =>
      'Voer shell-opdrachten uit of installeer apps op uw Android-apparaat.';

  @override
  String get runStarted => 'Het rennen is begonnen';

  @override
  String get runStatus => 'Uitvoerstatus';

  @override
  String get runStopped => 'Lopen gestopt';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Voer terminalopdrachten uit en open apps of webpagina\'s.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Voer deze server uit: accounts, updates, providers, configuratie ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Uitvoeren wanneer een bijbehorend Gmail-bericht binnenkomt.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Uitvoeren wanneer een overeenkomende Outlook-e-mail binnenkomt.';

  @override
  String get runWhenANewIssueMatching =>
      'Uitvoeren wanneer een nieuw probleem dat overeenkomt met uw filters wordt geopend in een repository.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Wordt uitgevoerd wanneer er een nieuw NeoRecall-geheugen is aangemaakt dat overeenkomt met uw filters.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Uitvoeren wanneer er een melding op uw apparaat binnenkomt.';

  @override
  String get runWhenASlackMessageMatches =>
      'Wordt uitgevoerd wanneer een Slack-bericht overeenkomt met het geselecteerde bereik.';

  @override
  String get runWhenATeamsChatMessage =>
      'Uitvoeren wanneer een Teams-chatbericht overeenkomt met het geselecteerde bereik.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Wordt uitgevoerd wanneer geconfigureerde weersomstandigheden worden voorspeld voor een locatie.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'loop. Terwijl elk model is uitgeschakeld, worden modellen die providers toevoegen ';

  @override
  String get running => 'Bezig';

  @override
  String runningArg1(Object? arg1) {
    return '$arg1 wordt uitgevoerd';
  }

  @override
  String get runningTask => 'Lopende taak';

  @override
  String get runningTool => 'Lopend hulpmiddel';

  @override
  String get runs => 'Uitvoeringen';

  @override
  String get runsEveryDayAtTheSelected =>
      'Wordt elke dag op het geselecteerde tijdstip uitgevoerd.';

  @override
  String get runsFourTimesPerHour => 'Rijdt vier keer per uur.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— runs, berichten, herinneringen, integraties, bestanden en ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'runs, berichten, herinneringen, integraties, bestanden en sessies. ';

  @override
  String get runsMondayThroughFriday => 'Loopt van maandag tot en met vrijdag.';

  @override
  String get runsOnSelectedWeekdays => 'Werkt op geselecteerde weekdagen.';

  @override
  String get runsOncePerHour => 'Draait één keer per uur.';

  @override
  String get runsOncePerMonthOnThe =>
      'Wordt één keer per maand uitgevoerd op de geselecteerde dag.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Wordt alleen uitgevoerd als u op Nu uitvoeren drukt.';

  @override
  String get runsPerDay => 'Draait per dag';

  @override
  String get runsPerDay30Days => 'Ritten per dag (30 dagen)';

  @override
  String get runsThatCompleted => 'Uitvoeringen die zijn voltooid';

  @override
  String get runsThisWeek => 'Wordt deze week uitgevoerd';

  @override
  String get runsToday => 'Wordt vandaag uitgevoerd';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Uitvoeringen, tools, geheugen, planning, vaardigheden en MCP zijn hier allemaal beschikbaar.';

  @override
  String get runsTwicePerHour => 'Rijdt tweemaal per uur.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Uitvoeringen vallen terug op de gedeelde serversleutel voor $arg1, als deze is geconfigureerd. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Runtime $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Looptijd: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Runtime-instellingen waarmee deze server is gestart. Bewerk ze onder ';

  @override
  String get runtimeSetupRequired => 'Runtime-installatie vereist';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'De openbare sleutel voor runtime-ondertekening moet 32 bytes groot zijn.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Opslaan';

  @override
  String get saveATrelloApiKeyFor =>
      'Bewaar een Trello API-sleutel voor deze agent en koppel vervolgens veilig één Trello-account. Het accounttoken wordt op de server opgeslagen en alleen voor deze agent gebruikt.';

  @override
  String get saveAccount => 'Account opslaan';

  @override
  String get saveChanges => 'Wijzigingen opslaan';

  @override
  String get saveCloudComputerSettings => 'Bewaar cloudcomputerinstellingen';

  @override
  String get saveConnect => 'Opslaan en verbinden';

  @override
  String get saveDefaults => 'Bewaar standaardinstellingen';

  @override
  String get saveDiagnosticReport => 'Diagnostisch rapport opslaan';

  @override
  String get saveEmail => 'E-mail opslaan';

  @override
  String get saveEmailSettings => 'Bewaar e-mailinstellingen';

  @override
  String get saveGeneralSettings => 'Sla algemene instellingen op';

  @override
  String get saveName => 'Naam opslaan';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Sla de diagnose van de NeoAgent-installatie op';

  @override
  String get saveOnly => 'Alleen opslaan';

  @override
  String get saveSetup => 'Instellingen opslaan';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Bewaar deze herstelcodes nu. Ze zullen niet meer getoond worden.';

  @override
  String get savedDeliveryDestination => 'Bezorgbestemming opgeslagen';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Opgeslagen tarieflimieten voor @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Scan een NeoAgent login-QR';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scan een NeoAgent-koppelings-QR vanaf een ander apparaat en keur deze goed vanuit deze opstartsessie.';

  @override
  String get scanLoginQr => 'QR-aanmelding scannen';

  @override
  String get scanPairingQr => 'QR-koppeling scannen';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scan QR-inlogverzoeken van afgemelde apparaten en keur ze goed via deze geverifieerde mobiele sessie.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scannen om $arg1 te voltooien';
  }

  @override
  String get scanWithNeoagentOnYourPhone => 'Scan met NeoAgent op uw telefoon';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Scant nieuwe e-mail en pingt u alleen als er iets belangrijks is.';

  @override
  String get schedule => 'Schema';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'geplande tijd. Zodra de runs zijn gemeten, begint deze eerder.';

  @override
  String get screen => 'Scherm';

  @override
  String get screenAction => 'scherm actie';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scrollen wordt niet ondersteund op dit platform.';

  @override
  String get scrollToBottom => 'Scroll naar beneden';

  @override
  String get search => 'Zoeken';

  @override
  String get search2 => 'Zoek…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Zoek beheerdersinstellingen (bijv. SMTP, Ollama, logs)';

  @override
  String get searchAgain => 'Zoek opnieuw';

  @override
  String get searchByUsernameOrEmail => 'Zoek op gebruikersnaam of e-mailadres';

  @override
  String get searchChannels => 'Zoek kanalen';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Zoek in ontdekte berichtenkanalen, contacten, groepen en recente gesprekken.';

  @override
  String get searchGroups => 'Zoek groepen';

  @override
  String get searchMemory => 'Zoek geheugen';

  @override
  String get searchModelsOrProviders => 'Zoek modellen of aanbieders';

  @override
  String get searchModelsOrProviders2 => 'Zoek modellen of aanbieders…';

  @override
  String get searchRecentPeopleAndGroups => 'Zoek recente mensen en groepen';

  @override
  String get searchSessions => 'Zoek sessies';

  @override
  String get searchSettings => 'Zoekinstellingen';

  @override
  String get searchTitleModelTriggerRunId =>
      'Zoektitel, model, trigger, run-ID';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Zoektools, integraties en vaardigheden';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Gezochte code voor \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Gezochte bestanden voor \"$arg1\"';
  }

  @override
  String get secretField => 'Geheim veld';

  @override
  String get secureCookies => 'Veilige cookies';

  @override
  String get security => 'Beveiliging';

  @override
  String get securityKey => 'Beveiligingssleutel';

  @override
  String get securityKeyPromptWasDismissed =>
      'De vraag om de beveiligingssleutel is afgewezen.';

  @override
  String get securityKeySignInCompletedBut =>
      'Inloggen met beveiligingssleutel voltooid, maar NeoAgent kon de browsersessie niet behouden. Meld u opnieuw aan.';

  @override
  String get securityKeySignInCouldNot =>
      'Het inloggen met de beveiligingssleutel kan niet worden gestart.';

  @override
  String get securityKeys => 'Beveiligingssleutels';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Beveiligingssleutels zijn alleen beschikbaar in de NeoAgent-webapp.';

  @override
  String get seeAll => 'Bekijk alles';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Kijk welke NeoAgent-server dit venster gebruikt en voer de backend op deze computer uit.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'zie uw gebruikersnaam en deze instellingen, nooit uw chats, herinneringen ';

  @override
  String get selectARun => 'Selecteer een run';

  @override
  String get selectASessionToSeeIts =>
      'Selecteer een sessie om de computer, bestanden en wijzigingen ervan te bekijken.';

  @override
  String get selectAll => 'Selecteer alles';

  @override
  String get selectAll2 => 'Selecteer Alles';

  @override
  String selectArg1(Object? arg1) {
    return 'Selecteer $arg1';
  }

  @override
  String get selectTrigger => 'Selecteer Trigger';

  @override
  String get send => 'Verzenden (⌘↵)';

  @override
  String get send2 => 'Verzenden';

  @override
  String get sendATaskFromChatAnd =>
      'Verzend een taak vanuit de chat en de uitvoeringsgeschiedenis ervan wordt hier weergegeven.';

  @override
  String get sendItToATeammateWith =>
      'stuur het naar een teamgenoot met een account op deze server.';

  @override
  String get sendLink => 'Stuur link';

  @override
  String get sendPath => 'Pad verzenden';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Verzend POST/PUT/DELETE-verzoeken naar externe API\'s.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Stuur deze link alleen naar de persoon waarvoor deze bedoeld is. Het wordt één keer getoond; ';

  @override
  String get senderAddress => 'Afzender adres';

  @override
  String get senderFilterOptional => 'Afzenderfilter (optioneel)';

  @override
  String get sentSharedAttachments => 'Gedeelde bijlagen verzonden.';

  @override
  String get separateAccount => 'Aparte rekening';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Serverstandaard ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Serverstandaarden voor in-app-spraakoproepen. Oproepen worden live uitgevoerd ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'server zelf: accounts, providers en configuratie.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, bijnaam, kanaal en optionele TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'serveruitvoer console waarschuwingen fouten kopiëren';

  @override
  String get serverProviderCredentials => 'Referenties van de serverprovider';

  @override
  String get serverUrl => 'Server-URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Servergebruikslimieten zijn niet van toepassing op modellen die op uw eigen sleutel draaien.';

  @override
  String get serviceEmail => 'Service-e-mail';

  @override
  String get serviceEmailIsNotConfigured =>
      'service-e-mail is niet geconfigureerd';

  @override
  String get serviceEmailSmtp => 'Service-e-mail (SMTP)';

  @override
  String get sessionActions => 'Sessieacties';

  @override
  String get sessions => 'Sessies';

  @override
  String get sessions2 => 'SESSIES';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sessies worden vastgemaakt aan een map en een computer. Begin er een om vanaf hier te plannen, bouwen, testen en verzenden.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sessies (AVG art. 17). Beheerdersaccounts kunnen niet worden verwijderd ';

  @override
  String get sessionsLogoutRevokeForce => 'sessies afmelden kracht intrekken';

  @override
  String get setBlockAskAllowPerTool =>
      'Stel blokkeren/vragen/toestaan in per gereedschapscategorie, of kies een globale modus.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Installeer NeoAgent op deze computer';

  @override
  String get setUpOrConnectNeoagent => 'NeoAgent instellen of verbinden';

  @override
  String get setUrl => 'URL instellen';

  @override
  String get settings => 'Instellingen';

  @override
  String get settingsAndCannotBeUndone =>
      'instellingen en kan niet ongedaan worden gemaakt.';

  @override
  String get settingsArea => 'Gebied Instellingen';

  @override
  String get settingsAreas => 'Instellingengebieden';

  @override
  String get setup => 'Installatie';

  @override
  String get setupDetails => 'Instellingsdetails';

  @override
  String get setupRequired => 'Installatie vereist';

  @override
  String get setupWasCancelled => 'Het instellen is geannuleerd.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Gedeelde bijlagen van de NeoAgent-client:';

  @override
  String get sharedFromAnotherApp => 'Gedeeld vanuit een andere app';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Gedeelde providersleutels worden op de server geconfigureerd. Als u in plaats daarvan uw eigen API-sleutel of een aangepast eindpunt wilt gebruiken, gaat u naar Geavanceerd → Breng uw eigen sleutel mee.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Gedeeld met de NeoAgent-chat en het geheugen ervan.';

  @override
  String get shellCommands => 'Shell-opdrachten';

  @override
  String showAllArg1(Object? arg1) {
    return 'Toon alle $arg1';
  }

  @override
  String get showEarlier => 'Eerder tonen';

  @override
  String get showEveryStep => 'Laat elke stap zien';

  @override
  String get showTools => 'Gereedschap tonen';

  @override
  String get showWorkbenchJ => 'Werkbank tonen (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Hierbij de eerste $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Getoond in de zijbalk. Laat dit leeg om uw gebruikersnaam te gebruiken.';

  @override
  String get signIn => 'Aanmelden';

  @override
  String get signInCompletedButNeoagentCould =>
      'Het aanmelden is voltooid, maar NeoAgent kon de browsersessie niet behouden. Meld u opnieuw aan. Als dit blijft gebeuren, controleer dan de cookie-instellingen voor de backend-sessie.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Het aanmelden is voltooid, maar NeoAgent kon de browsersessie niet behouden. Meld u opnieuw aan. Als dit blijft gebeuren, wordt de backend-sessiecookie waarschijnlijk niet bewaard.';

  @override
  String get signInToThisNeoagentServer =>
      'Meld u aan bij deze NeoAgent-server voordat u een koppelings-QR-code scant.';

  @override
  String get signInWithAHardwareKey =>
      'Meld u aan met een hardwaresleutel of wachtwoord in plaats van uw wachtwoord. ';

  @override
  String get signInWithASecurityKey => 'Meld u aan met een beveiligingssleutel';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Meld u aan met $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Keur NeoAgent goed in uw $arg1-account. Geen sleutel om te kopiëren.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Wachten op $arg1. Voltooi in uw browser.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Plak de $arg1-code';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Nadat u NeoAgent had goedgekeurd, toonde $arg1 een eenmalige code. Plak het hier.';
  }

  @override
  String get signInCode => 'Inlogcode';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Aangemeld met $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Aanmelden mislukt: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Meld u aan met hetzelfde e-mailadres en hoofdwachtwoord dat u in Bitwarden gebruikt. Het hoofdwachtwoord en de tweestapscode worden alleen gebruikt om in te loggen en worden nooit opgeslagen of naar de AI verzonden.';

  @override
  String get signOut => 'Afmelden';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return '@$arg1 overal uitloggen?';
  }

  @override
  String get signOutEverywhere => 'Meld u overal af';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API-brug';

  @override
  String get signalCliServerUrl => 'signaal-cli server-URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Ondertekend @$arg1 bij elke sessie.';
  }

  @override
  String get signedInDevices => 'Ingelogde apparaten';

  @override
  String get signedInWithin24Hours => 'Binnen 24 uur aangemeld';

  @override
  String get signingSecret => 'Ondertekening geheim';

  @override
  String sinceArg1(Object? arg1) {
    return 'Sinds $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'sinds $arg1';
  }

  @override
  String get singleMessage => 'Enkel bericht';

  @override
  String get singleUse => 'Eenmalig gebruik';

  @override
  String get skill => 'Vaardigheid';

  @override
  String get skillChanges => 'Veranderingen in vaardigheden';

  @override
  String get skillContent => 'Vaardigheidsinhoud';

  @override
  String get skills => 'Vaardigheden';

  @override
  String get skip => 'Overslaan';

  @override
  String get skipForNow => 'Overslaan voor nu';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Sla deze taak over voordat het model wordt aangeroepen.';

  @override
  String get slackMessageReceived => 'Slack-bericht ontvangen';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Slaap $arg1-sessies';
  }

  @override
  String get smartSelector => 'slimme keuzeschakelaar';

  @override
  String get smartSelector2 => 'Slimme selectie';

  @override
  String get smartSelectorPool => 'Slimme selectiepool';

  @override
  String get smtpHost => 'SMTP-host';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp e-mail afzender wachtwoord tls bevestigingsmeldingen opnieuw instellen';

  @override
  String get smtpPassword => 'SMTP-wachtwoord';

  @override
  String get smtpPort => 'SMTP-poort';

  @override
  String get smtpPortMustBeAWhole =>
      'De SMTP-poort moet een geheel getal zijn tussen 1 en 65535.';

  @override
  String get smtpUsername => 'SMTP-gebruikersnaam';

  @override
  String get soTheRunStartsThatMuch => 'dus de run begint zoveel eerder.';

  @override
  String get socialBehaviorOff => 'Sociaal gedrag uit';

  @override
  String get socialIntelligence => 'sociale intelligentie';

  @override
  String get socialIntelligence2 => 'Sociale intelligentie';

  @override
  String get socialObservability => 'Sociale waarneembaarheid';

  @override
  String get socialReach => 'sociaal bereik';

  @override
  String get socialReach2 => 'Sociaal bereik';

  @override
  String get socialReach3 => 'Sociaal bereik';

  @override
  String get socialReachUpdated => 'Sociaal bereik bijgewerkt.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenten voor sociale bronnen kunnen direct lezen, inclusief feeds, repositories, Reddit, X, video\'s en door cookies ondersteunde marktgegevens.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Er is iets misgegaan. Probeer het opnieuw.';

  @override
  String get source => 'Bron';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Spatie of chat-ID die wordt gebruikt wanneer deze agent een gesprek begint.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Ondersteuning voor Space-webhook en app-callback';

  @override
  String get speaking => 'Spreken';

  @override
  String get speechToSpeechModelUsingThe =>
      'spraak-naar-spraak-model met behulp van de OpenAI- of Google-sleutel onder ';

  @override
  String get speechToText => 'Spraak-naar-tekst';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Spraak-naar-tekst transcribeert spraaknotities en dictaat. Auto gebruikt OpenAI, Gemini of Deepgram, afhankelijk van welke een API-sleutel heeft. Het Voice Reply-model is het chatmodel dat gesproken notities beantwoordt.';

  @override
  String get sqlConsole => 'SQL-console';

  @override
  String get stable => 'Stabiel';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stabiel installeert de laatst gepubliceerde backend-release.';

  @override
  String get stackTrace => 'stapeltracering';

  @override
  String get standard => 'Standaard';

  @override
  String get standardView => 'Standaard weergave';

  @override
  String get start => 'Begin';

  @override
  String get startASessionToPlanOr =>
      'Start een sessie om te plannen of te bouwen met NeoAgent.';

  @override
  String get startAndroid => 'Start Android';

  @override
  String get startComputer => 'Computer starten';

  @override
  String get startFullSetup => 'Start de volledige installatie';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Begin met instellen';

  @override
  String get startTalking => 'Begin te praten';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Start eerst de Android-telefoon en zet hier vervolgens een .apk- of .apks-bestand neer.';

  @override
  String get startTheServerLaterFromThe =>
      'Start de server later vanuit de lijst zodra de configuratie is opgeslagen.';

  @override
  String get startWithARecommendedTask => 'Begin met een aanbevolen taak';

  @override
  String get startingAndroid => 'Android starten';

  @override
  String get startingYourComputer => 'Uw computer opstarten';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Begint met xoxb-. Vanuit uw Slack-app-inloggegevens.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting-fout: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistieken runs tokens gebruikers grafieken succespercentage';

  @override
  String get status => 'Status';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'status database runtime VM-providers';

  @override
  String get statusIsNotLoadedYet => 'Status is nog niet geladen.';

  @override
  String get stayManagedByYou => 'blijf door jou beheerd.';

  @override
  String get stayOnTheCall => 'Blijf aan de lijn';

  @override
  String get stayedQuiet => 'Bleef stil';

  @override
  String get steering => 'STUUR';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'STAP $arg1 VAN $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Stappen $arg1';
  }

  @override
  String get stop => 'Stoppen';

  @override
  String get stop2 => 'Stoppen (⌘.)';

  @override
  String get stopManaging => 'Houd op met beheren';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Het beheer van $arg1 stoppen?';
  }

  @override
  String get stopRun => 'Stop met rennen';

  @override
  String get stopSpeaking => 'Houd op met praten';

  @override
  String get stoppedBeforeCompletion => 'Gestopt vóór voltooiing';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting-fout: $arg1';
  }

  @override
  String get storage => 'Opslag';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'gecodeerd opgeslagen en alleen gebruikt voor uw eigen runs.';

  @override
  String get storedMetrics => 'Opgeslagen statistieken';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Slaat alleen de Bitwarden-sessiesleutel gecodeerd op deze server op, zodat verbindingen het opnieuw opstarten overleven. Je kunt het op elk moment vergrendelen.';

  @override
  String get strong => 'Sterk';

  @override
  String get strongPassword => 'Sterk wachtwoord.';

  @override
  String get subAgent => 'Onderagent';

  @override
  String get subagentUpdate => 'Subagent-update';

  @override
  String get subagentUpdate2 => 'Subagent-update.';

  @override
  String get successRate => 'Succespercentage';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Suggesties: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Samenvatting van mijn laatste run';

  @override
  String get supportUrl => 'Ondersteunings-URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Ondersteund: rain_start, snow_start, wind_alert, temperatuur_boven, temperatuur_onder';

  @override
  String get switchAgent => 'Schakel tussen agent';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Symbolische koppelingen zijn niet toegestaan in paden in de NeoAgent-werkruimte.';

  @override
  String get syncNow => 'Synchroniseer nu';

  @override
  String get synologyChat => 'Synology-chat';

  @override
  String get systemPrivacySettings => 'Systeemprivacy-instellingen';

  @override
  String get tableInfoUsers => 'Tabelinfo (gebruikers)';

  @override
  String get tagsOnly => 'Alleen tags';

  @override
  String get tasks => 'Taken';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Taken worden zelfstandig uitgevoerd en sturen u een bericht met de ';

  @override
  String get teach => 'Leer';

  @override
  String get teachingInProgress => 'Onderwijs in uitvoering';

  @override
  String get team => 'Team';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Teamkoppelingen maken van niemand een serverbeheerder. Beheerders voeren de ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Teamruimtes, kamers, kanalen en live communities.';

  @override
  String get teamsMessageReceived => 'Teamsbericht ontvangen';

  @override
  String get templates => 'Sjablonen';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Tijdelijke installatiebestanden worden later opgeschoond.';

  @override
  String get tenantId => 'Huurder-ID';

  @override
  String get testConnection => 'Verbinding testen';

  @override
  String get testConnection2 => 'Verbinding testen';

  @override
  String get textChat => 'Tekst en chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'die hun eigen sleutel hebben toegevoegd, blijf deze gebruiken.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Dat e-mailadres hoort al bij een bestaand account. Meld u eerst aan en koppel vervolgens Google vanuit de accountinstellingen.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Dat e-mailadres is al aan een ander account gekoppeld.';

  @override
  String get thatQrCodeIsNotA => 'Die QR-code is geen NeoAgent-inlogverzoek.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Die QR-code is geen NeoAgent-koppelingsverzoek.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Die beveiligingssleutel is al geregistreerd op dit account.';

  @override
  String get theAddress => 'Het adres';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Het adres van uw BlueBubbles-server.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Het adres dat mensen en OAuth-providers gebruiken om te bereiken ';

  @override
  String get theAgentReadsTimesYouMention =>
      'De agent leest de door u genoemde tijden en voert geplande taken uit in deze tijdzone.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'De agent zal vóór elk gevoelig hulpmiddel vragen: ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'De agent zal deze vaardigheid negeren.';

  @override
  String get theAppCouldNotReachThis =>
      'De app kon deze NeoAgent-implementatie niet bereiken. Controleer uw netwerkverbinding of controleer of de service-URL correct is.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'De browser heeft een verzoek aan $arg1 geblokkeerd vanwege het inhoudsbeveiligingsbeleid.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'De browser heeft een vereist verzoek geblokkeerd vanwege het inhoudsbeveiligingsbeleid.';

  @override
  String get theCloudWorkspace => 'de cloudwerkruimte';

  @override
  String get theComputerCouldNotStart => 'De computer kon niet opstarten';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'De computer heeft meer vrije schijfruimte nodig op de NeoAgent-host. Maak wat ruimte vrij en probeer het opnieuw.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'De runtime van de computer moet worden gerepareerd. Voer NeoAgent Doctor uit en probeer het opnieuw.';

  @override
  String get theConnectionTestFailed => 'De verbindingstest is mislukt.';

  @override
  String get theDesktopDidNotStart => 'Het bureaublad is niet gestart';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'De ontdekte NeoAgent retourneerde onvolledige identiteitsgegevens.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'De ontdekte NeoAgent gebruikt een niet-ondersteund installatieprotocol.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'De ontdekte service is niet NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'De gedownloade NeoAgent-runtime heeft de verificatie niet doorstaan.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'De webhook van de Google Chat-ruimte waarop deze agent berichten moet plaatsen.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Het installatieprogramma is niet langer beschikbaar.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'De interactieve Linux-desktop is beschikbaar in de NeoAgent-webapp.';

  @override
  String get theIntroIsNotAvailableOn =>
      'De intro is niet beschikbaar op dit apparaat.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Het nieuwste wordt op elk account weergegeven.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Het laatste synchronisatievenster eindigde met $arg1 en er zijn geen nieuwe Health Connect-records gevonden. De hieronder opgeslagen statistieken zijn afkomstig van eerdere synchronisaties.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'De grafische Linux-sessie is niet actief.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Het live stemmodel antwoordde niet. Probeer het opnieuw.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'De lokale NeoAgent-opdracht werd afgesloten met code $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Er is een time-out opgetreden bij de lokale NeoAgent-opdracht.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'De lokale NeoAgent-runtime moet worden gerepareerd.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'De lokale runtime moet worden gerepareerd ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'De lokale gebruikersmap is niet beschikbaar.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Het e-mailaccount NeoAgent verzendt aanmeldingsbevestigingen, aanmelding ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'De hoofdagent wordt automatisch aangemaakt wanneer dat nodig is.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'De overeenkomende NeoAgent-runtime ontbreekt in deze release.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'De Mattermost inkomende webhook waarop deze agent moet posten.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'De modellen waartussen de Smart Selector automatisch routeert.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'De NeoAgent-backenddownload kwam niet overeen met het manifest.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'De download van de NeoAgent-backend was onvolledig.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'De NeoAgent-backend op deze computer antwoordt niet op poort ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'De NeoAgent backend-runtime kon niet worden gedownload.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Het duurde te lang voordat de NeoAgent-backend reageerde op $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'De NeoAgent-implementatie reageerde met HTTP 402 in plaats van de normale 401 voor ongeldige inloggegevens. Controleer reverse-proxy, auth-gateway of betalingsgerelateerde regels op die server.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'De NeoAgent-implementatie reageerde met HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'De NeoAgent-implementatie reageerde met HTTP 402. Controleer reverse-proxy, auth-gateway of betalingsgerelateerde regels op die server.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'De NeoAgent-instantie waarmee deze app is verbonden.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'De NeoAgent-releaseservice heeft ongeldige gegevens geretourneerd.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'De metagegevens van het NeoAgent-runtime-artefact zijn ongeldig.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Het NeoAgent runtime manifest heeft de handtekeningverificatie niet doorstaan.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Het NeoAgent-runtimemanifest bevat geen artefacten.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'De handtekening van het NeoAgent-runtimemanifest is ongeldig.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Het wachtwoord dat u in BlueBubbles heeft ingesteld.';

  @override
  String get thePeopleYouManageStayWith =>
      'De mensen aan wie u leiding geeft, blijven bij u.';

  @override
  String get theProviderAnswers => 'antwoordt de aanbieder.';

  @override
  String get theQueryReturnedNoRows =>
      'De query heeft geen rijen geretourneerd.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'De gevraagde desktopweergave is niet beschikbaar.';

  @override
  String get theRest => 'de rest.';

  @override
  String get theRestEndpointForYourSignal =>
      'Het REST-eindpunt voor uw signal-cli-instantie.';

  @override
  String get theRunIsPausedUntilYou =>
      'De run wordt gepauzeerd totdat u antwoordt.';

  @override
  String get theRunStartsAtTheScheduled => 'De run begint op de geplande tijd.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'De runtime is een lichtgewicht Debian Linux-desktop met Chromium, PCManFM, Muismat, LXTerminal, Python, Git en standaard opdrachtregelprogramma\'s. De capaciteit wordt beheerd door de NeoAgent-host.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'De registratie van de beveiligingssleutel kon niet worden gestart.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'de server bewaart er alleen een vingerafdruk van.';

  @override
  String get theServerOnThisComputerIs =>
      'De server op deze computer is niet actief';

  @override
  String get theServerReportedNoHealthChecks =>
      'De server heeft geen statuscontroles gerapporteerd.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Het signaaltelefoonnummer dat deze bot gebruikt.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'De inkomende webhook van Teams waarop deze agent moet posten.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'De uitdaging met twee factoren is verlopen. Meld u opnieuw aan.';

  @override
  String get theTwoFactorCodeIsNot => 'De tweefactorcode is niet geldig.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Het geverifieerde runtimepakket kon niet als uitvoerbaar worden gemarkeerd.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Er ontbreken vereiste bestanden in het geverifieerde runtimepakket.';

  @override
  String get theWebAppCouldNotReach =>
      'De webapp kan de NeoAgent-backend niet bereiken.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'De webapp kan de NeoAgent-backend op $arg1 niet bereiken. Controleer de browserconsole en de reverse-proxy/netwerkconfiguratie.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'zich; de serveroperator verwijdert eerst de beheerder met ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Deze kanalen blijven stil. Als u opnieuw van hen wilt horen, voegt u ze toe onder Wie kan berichten sturen voor dat platform.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Deze lijsten zijn optioneel, tenzij een sectie hierboven is ingesteld op Alleen goedgekeurd.';

  @override
  String get thesePeopleAnywhere => 'Deze mensen, waar dan ook';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Deze mensen kunnen $arg1 een bericht sturen in privéchats en in elke groep die ze delen.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Deze mensen kunnen $arg1 één-op-één berichten sturen. Hierdoor kunnen ze niet in groepen spreken.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Deze mensen kunnen alleen berichten sturen naar $arg1 in de groep die je hebt gekozen.';
  }

  @override
  String get thesePeopleInOneGroup => 'Deze mensen, in één groep';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'deze schakelaars, nooit uw chats, herinneringen of bestanden.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Dit account ontgrendelt NeoAgent op deze machine.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Deze agent kan delegeren aan elke in aanmerking komende ontvangende agent.';

  @override
  String get thisAgentIsUsingAServer =>
      'Deze agent gebruikt een door de server beheerde Trello API-sleutel. U hoeft hieronder alleen een accounttoken te autoriseren.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Deze build mag niet praten met deze NeoAgent-implementatie.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Deze code hoort bij een andere NeoAgent-server: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Dit bureaublad is verbonden';

  @override
  String get thisDevice => 'Dit apparaat';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Dit apparaat: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Dit apparaat kan geen beveiligingssleutels registreren. Open NeoAgent in een browser via HTTPS om er een toe te voegen.';

  @override
  String get thisDeviceUnavailable => 'Dit apparaat is niet beschikbaar';

  @override
  String get thisFileHasNoContent => 'Dit bestand heeft geen inhoud.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Hierdoor wordt \"$arg1\" verborgen voor routering en selectie.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Deze integratie ondersteunt momenteel één verbonden account per agent. Open de installatie opnieuw om deze te vervangen.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Deze integratie is niet langer beschikbaar.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Deze intro is ontworpen voor landschapsweergave op volledig scherm.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Dit is een beheerde implementatie. De operator rolt uit ';

  @override
  String get thisMayTakeAMoment => 'Dit kan even duren.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Deze MCP-server is niet langer geconfigureerd.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Dit geheugen wordt definitief verwijderd.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Deze NeoAgent-build is niet geconfigureerd om backend-runtimes te verifiëren.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Hierdoor worden al uw gegevens permanent gewist en dat kan niet ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Hiermee wordt het account en alles wat het bezit permanent gewist: ';

  @override
  String get thisPersonAnywhere => 'Deze persoon, waar dan ook';

  @override
  String get thisPersonInOneGroup => 'Deze persoon, in één groep';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Dit QR-inlogverzoek is verlopen. Genereer een nieuwe code en probeer het opnieuw.';

  @override
  String get thisQrLoginRequestHasExpired => 'dit qr-inlogverzoek is verlopen';

  @override
  String get thisQrLoginRequestIsStill =>
      'Dit QR-inlogverzoek wacht nog op goedkeuring.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Dit QR-inlogverzoek is al gebruikt.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Hiermee worden de Home Assistant-installatie en de verbonden instantie voor deze agent verwijderd.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Hiermee worden de NeoRecall-backend-URL en alle verbonden NeoRecall-accounts voor deze agent verwijderd.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Hiermee worden de Nextcloud-URL en alle verbonden Nextcloud-accounts voor deze agent verwijderd.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Hiermee worden de Trello-installatie en verbonden accounts voor deze agent verwijderd.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Hiervoor is een geverifieerde sessie op dezelfde NeoAgent-server vereist.';

  @override
  String get thisRunDidNotProduceA =>
      'Deze run leverde geen gebruikersgericht antwoord op.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Deze run heeft geen geregistreerde stapgegevens.';

  @override
  String get thisServer => 'deze server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Deze server rapporteert geen providerinstellingen.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Deze vaardigheid is niet meer geïnstalleerd.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Deze taak is nog niet voltooid en begint dus nog steeds op het ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Deze taak wordt alleen uitgevoerd als u op Nu uitvoeren drukt.';

  @override
  String get thisWeek => 'Deze week';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Hierdoor wordt het antwoord geïmporteerd in $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Hierdoor wordt \"$arg1\" verwijderd.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Hierdoor wordt \"$arg1\" uit de serverlijst verwijderd.';
  }

  @override
  String get time => 'Tijd';

  @override
  String get timeZone => 'tijdzone';

  @override
  String get timeZone2 => 'Tijdzone';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Time-out$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Kan tijdzones niet weergeven: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Kan de tijdzone van het apparaat niet lezen: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Kan de tijdzone van het apparaat niet opslaan: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'naar $arg1';
  }

  @override
  String get toUseTheServerDefault => 'om de serverstandaard te gebruiken.';

  @override
  String get today => 'Vandaag';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Tokenbudget voor @$arg1. Laat een veld leeg ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Tokenbudget voor elk account zonder eigen overschrijving. Laat een ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'tokenbudgetlimiet Wekelijkse quotumgebruiker van 4 uur';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token budgetlimiet 4 uur per week quotum wereldwijd';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Tokengebruik is niet beschikbaar op deze serverversie.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokens die elk account binnen 4 uur kan gebruiken.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens die elk account binnen 7 dagen kan gebruiken.';

  @override
  String get tokensPerDay => 'Tokens per dag';

  @override
  String get tokensPerRun => 'Tokens per run';

  @override
  String get tokensToday => 'Tokens vandaag';

  @override
  String get tokensUsed => ' tokens gebruikt';

  @override
  String get tomorrowPrep => 'Morgen voorbereiding';

  @override
  String get tooManyAttempts => 'te veel pogingen';

  @override
  String get tooManySignInAttemptsPlease =>
      'Te veel inlogpogingen. Wacht even en probeer het opnieuw.';

  @override
  String get tool => 'Gereedschap';

  @override
  String get toolApproval => 'Goedkeuring van gereedschap';

  @override
  String get toolApprovalRequired => 'Gereedschapsgoedkeuring vereist';

  @override
  String get toolCompleted => 'Gereedschap voltooid';

  @override
  String get toolFailed => 'Gereedschap mislukt';

  @override
  String get toolPermissions => 'Gereedschapsrechten';

  @override
  String get toolStarted => 'Gereedschap gestart';

  @override
  String get tools => 'Gereedschap';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Tools die niet in NeoAgent zijn ingebouwd, inclusief aangesloten MCP-servers en aangepaste toolproviders.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Aangeboden gereedschappen ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Tools die het beheerde account kan gebruiken';

  @override
  String get topUsers => 'Topgebruikers';

  @override
  String get topUsersAndRecentRuns => 'Topgebruikers en recente runs';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Totaal: $arg1-tokens over $arg2-runs';
  }

  @override
  String get totalRuns => 'Totaal aantal runs';

  @override
  String get totalTokens => 'Totaal tokens';

  @override
  String get totalUsers => 'Totaal aantal gebruikers';

  @override
  String get transcript => 'Afschrift';

  @override
  String get transcript2 => 'TRANSCRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transcriptie mislukt: $arg1';
  }

  @override
  String get transfer => 'Overdracht';

  @override
  String get trelloApiKey => 'Trello API-sleutel';

  @override
  String get trelloApiKeyIsRequired => 'Trello API-sleutel is vereist.';

  @override
  String get trelloSetup => 'Trello-installatie';

  @override
  String get triggerType => 'Triggertype';

  @override
  String get tryABroaderSearchLikeModels =>
      'Probeer een bredere zoekopdracht, zoals modellen, browser of stem.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Probeer een providernaam, “e-mail”, “limieten”, “update” of “logboeken”.';

  @override
  String get tryAgain => 'Probeer het opnieuw';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Probeer het opnieuw. Als dit blijft gebeuren, voer dan NeoAgent Doctor uit om de runtime van de computer te controleren.';

  @override
  String get tryAgainInAMoment => 'Probeer het zo nog eens.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Probeer het opnieuw of voer NeoAgent Doctor uit.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Probeer een andere zoekopdracht, sluit een berichtenplatform aan of voer handmatig een bestemmings-ID in.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Schakel een groep in als $arg1 ook berichten moet lezen die deze niet taggen.';
  }

  @override
  String get turnOffComputer => 'Schakel de computer uit';

  @override
  String get turnOffOnlyForAMail =>
      'Schakel dit alleen uit voor een mailserver met een zelfondertekend certificaat.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Schakel dit in als Signal moet blijven zoeken naar inkomende chats.';

  @override
  String get turnTaking => 'beurt nemen';

  @override
  String get turnTakingModel => 'Beurtnemend model';

  @override
  String get turnTakingOff => 'Schakel uit';

  @override
  String get turnThisOffToKeepThis =>
      'Schakel dit uit om deze agent volledig gescheiden te houden van andere agenten.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Uitgeschakeld door $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Uitgeschakeld door $arg1, die dit account beheert. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Voor u uitgeschakeld door $arg1; alleen zij kunnen dit wijzigen';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Voor jou uitgeschakeld, dus je kunt het niet uitdelen';

  @override
  String get twitchChatOverIrc => 'Twitch-chat via IRC';

  @override
  String get twoFactorAuthentication => 'Tweefactorauthenticatie';

  @override
  String get twoFactorChallengeExpired => 'tweefactoruitdaging is verlopen';

  @override
  String get twoFactorCode => 'tweefactorcode';

  @override
  String get twoFactorSignInCompletedBut =>
      'Twee-factor-aanmelding voltooid, maar NeoAgent kon de browsersessie niet behouden. Meld u opnieuw aan.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Inloggen in twee stappen (alleen indien ingeschakeld)';

  @override
  String get type => 'Typ';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Typ $arg1 om te bevestigen';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'teksttype wordt niet ondersteund op dit platform.';

  @override
  String get typedInTheBrowser => 'In de browser getypt';

  @override
  String get typedText => 'Getypte tekst';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'kan geen Java-runtime vinden';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Kan de tijdinstellingen voor deze build niet openen.';

  @override
  String get unableToOpenWiFiSettings =>
      'Kan de wifi-instellingen voor deze build niet openen.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Kan de geselecteerde bureaubladweergave niet behouden.';

  @override
  String get unclearWhoItWasFor => 'Onduidelijk voor wie het was';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'ongedaan gemaakt. Typ uw gebruikersnaam om te bevestigen.';

  @override
  String get unknownAccount => 'Onbekende rekening';

  @override
  String get unknownAgent => 'Onbekende agent';

  @override
  String get unknownBrowser => 'Onbekende browser';

  @override
  String get unknownDevice => 'Onbekend apparaat';

  @override
  String get unknownError => 'onbekende fout';

  @override
  String get unknownLocalComputerPermission =>
      'Onbekende lokale computertoestemming.';

  @override
  String get unknownLocation => 'Onbekende locatie';

  @override
  String get unknownPublishTime => 'Onbekende publicatietijd';

  @override
  String get unknownSize => 'Onbekende maat';

  @override
  String get unlink => 'Ontkoppelen';

  @override
  String get unreadOnly => 'Alleen ongelezen';

  @override
  String get unsavedChanges => 'Niet-opgeslagen wijzigingen';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Niet-ondersteunde desktopcompanion-opdracht: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Niet-ondersteunde methode: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Ongebruikelijke aanmeldingswaarschuwingen';

  @override
  String updateArg1(Object? arg1) {
    return '$arg1 bijwerken';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Werk de kerngeheugenvermeldingen van de import bij.';

  @override
  String get updateNow => 'Nu bijwerken';

  @override
  String get updateReady => 'Update gereed';

  @override
  String get updateSetup => 'Installatie bijwerken';

  @override
  String get updateTheAccessListToAllow =>
      'Werk de toegangslijst bij om antwoorden toe te staan.';

  @override
  String get updateTheServer => 'De server updaten?';

  @override
  String get updateTheServer2 => 'Update de server';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Update de tijdzone automatisch vanaf het apparaat dat u gebruikt.';

  @override
  String updatedArg1(Object? arg1) {
    return 'bijgewerkte $arg1';
  }

  @override
  String get updates => 'Updates';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Updates zijn niet geconfigureerd voor deze build.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'updates, dus zelfupdates en kanaalwijzigingen zijn hier uitgeschakeld.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'upgrade-update geeft nu kanaalstabiele bèta vrij';

  @override
  String get usageAnalytics => 'Gebruiksanalyse';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Gebruiks- en statussignalen die het huidige runtime-gedrag helpen verklaren zonder eerst de logboeken te doorzoeken.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Gebruik wordt volledig gereset in $arg1';
  }

  @override
  String get usageLeaderboard => 'scorebord voor gebruik';

  @override
  String get usageLimits => 'Gebruik en limieten';

  @override
  String get usageLimits2 => 'Gebruik en limieten';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Gebruik meer dan 8 tekens. Langere wachtwoordzinnen werken goed.';

  @override
  String get useADateAndTimeFor =>
      'Gebruik een datum en tijd, bijvoorbeeld 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Gebruik een naam, telefoonnummer of chat-ID.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Gebruik een NeoRecall-URL die de NeoAgent-server kan bereiken. De PUBLIC_URL van NeoAgent moet ook bereikbaar zijn vanuit deze browser voor de OAuth-callback.';

  @override
  String get useANewPasswordWithAt =>
      'Gebruik een nieuw wachtwoord van minimaal 8 tekens.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Gebruik een Nextcloud-URL die de NeoAgent-server kan bereiken, bijvoorbeeld https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Gebruik een wachtwoord van minimaal 8 tekens.';

  @override
  String get useASecureConnectionTls =>
      'Gebruik een beveiligde verbinding (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Gebruik een authenticator-app zoals Authy, 1Password of Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Gebruik minimaal 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Maximaal geheugen per computer (MB)';

  @override
  String get maxVcpusPerComputer => 'Max. vCPU\'s per computer';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Minimaal $arg1. Computers krijgen minder als de host bezet is.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Het maximale geheugen moet minimaal $arg1 MB zijn.';
  }

  @override
  String get useAtLeast8Characters => 'Gebruik minimaal 8 tekens.';

  @override
  String get useDefault => 'Gebruik standaard';

  @override
  String get useDefaultChannel => 'Gebruik standaardkanaal';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Standaard gebruiken (NeoAgent-werkruimte)';

  @override
  String get useFor => 'Gebruik voor';

  @override
  String get useManualDestination => 'Gebruik handmatige bestemming';

  @override
  String get useOrDoTheSameFor =>
      'gebruiken, of doe hetzelfde voor je teamgenoten.';

  @override
  String get usePerCategorySettingsBelow =>
      'Gebruik onderstaande instellingen per categorie.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Standaardinstellingen gebruiken ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Gebruik de server op deze computer';

  @override
  String get useTheseForContextIfA =>
      'Gebruik deze voor context. Als een lokale URI niet rechtstreeks toegankelijk is vanaf de server, vraag mij dan om het bestand aan te leveren via een toegankelijke werkruimte.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Gebruik dit voor Orchestrator-agents. Laat het los voor geïsoleerde werkbots die directe berichten zelf moeten afhandelen.';

  @override
  String get useTlsFromTheStartOf =>
      'Gebruik TLS vanaf het begin van de verbinding, meestal op poort 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Gebruik uw eigen API-sleutel voor een provider, of koppel een aangepaste ';

  @override
  String get usedByEveryAccountOnThis =>
      'Wordt gebruikt door elk account op deze server dat geen sleutel heeft ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Wordt gebruikt om te verifiëren dat binnenkomende Slack-gebeurtenissen echt zijn.';

  @override
  String get userSummary => 'Gebruikersoverzicht';

  @override
  String get username => 'Gebruikersnaam';

  @override
  String get usernameOrEmail => 'Gebruikersnaam of e-mailadres';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'gebruikers mensen zoeken e-mail gebruikersnaam beheerdersbadge beheerd team';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Gebruikt het chatmodel dat is geconfigureerd in Instellingen';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Met behulp van de geïnstalleerde NeoAgent-runtime';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Ziet er meestal uit als @bot:matrix.org';

  @override
  String get validEmail => 'geldige e-mail';

  @override
  String get value => 'Waarde';

  @override
  String get vaultLocked => 'Kluis vergrendeld';

  @override
  String get vaultOperationFailed => 'Kluisbewerking mislukt.';

  @override
  String get verification => 'Verificatie';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verificatie: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verificatie: $arg1';
  }

  @override
  String get verificationCompleted => 'Verificatie voltooid.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Verificatiestatus: $arg1';
  }

  @override
  String get verifiedTheResult => 'Het resultaat geverifieerd';

  @override
  String get verifyingTheDownloadedRuntime =>
      'De gedownloade runtime verifiëren';

  @override
  String get versionAndUptime => 'Versie en uptime';

  @override
  String versionArg1(Object? arg1) {
    return 'Versie $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Versie $arg1 is geïnstalleerd, maar $arg2 draait nog steeds.';
  }

  @override
  String get videoLinks => 'Videolinks';

  @override
  String get viewDesktop => 'Bureaublad bekijken';

  @override
  String get viewLastRun => 'Bekijk de laatste run';

  @override
  String get viewLogs => 'Bekijk logboeken';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'vm beeldgeheugen cpu qemu runtime';

  @override
  String get voice => 'Stem';

  @override
  String get voiceAssistant => 'Stemassistent';

  @override
  String get voiceCall => 'SPRAAKOPROEP';

  @override
  String get voiceCall2 => 'Spraakoproep';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'spraakoproep gpt-live Gemini live model spraak realtime';

  @override
  String get voiceCallsRunOnALive =>
      'Spraakoproepen worden uitgevoerd op basis van een live spraak-naar-spraak-model met dezelfde persona, geheugen en chatgeschiedenis als NeoAgent. Het antwoordt meteen en geeft het echte werk over aan de normale agent, die op de achtergrond blijft draaien.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'spraaknotitie spraaktranscriptie API-sleutel';

  @override
  String get voiceNotesAndDictation => 'Spraaknotities en dictaat';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Spraakweergave is niet beschikbaar op dit apparaat.';

  @override
  String get voiceReplyModel => 'Voice-reply-model';

  @override
  String get waitingForApproval => 'Wachten op goedkeuring: ';

  @override
  String get waitingForCode => 'Wachten op code';

  @override
  String get waitingForInput => 'Wachten op invoer';

  @override
  String get waitingForServerOrFlutterLog =>
      'Wachten op server- of Flutter-logboekuitvoer...';

  @override
  String get waitingForTaskEvents => 'Wachten op taakgebeurtenissen...';

  @override
  String get waitingForYou => 'op je wachten';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Ik wilde een antwoord van $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Wil met je praten · ${arg1}s';
  }

  @override
  String get weak => 'Zwak';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Weer, kalender en prioriteiten voordat uw dag begint.';

  @override
  String get weatherEvent => 'Weer evenement';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Webbrowser';

  @override
  String get webSearchApiKey => 'API-sleutel voor zoeken op internet';

  @override
  String get webhookOrRestChannelPosting => 'Webhook- of REST-kanaalposting';

  @override
  String get webhookSecret => 'Webhook-geheim';

  @override
  String get webhookUrlCopied => 'Webhook-URL gekopieerd';

  @override
  String get weekdays => 'Weekdagen';

  @override
  String get weekdays0730 => 'Weekdagen · 07:30 uur';

  @override
  String get weekdays1800 => 'Weekdagen · 18:00 uur';

  @override
  String get weekly => 'Wekelijks';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Wekelijkse limiet $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Wekelijkse limiet (tokens)';

  @override
  String get weeklyReview => 'Wekelijkse beoordeling';

  @override
  String get weeklyUsage => 'Wekelijks gebruik';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Gewicht $arg1-records';
  }

  @override
  String get welcomeToNeoagent => 'WELKOM BIJ NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Welkom bij\nNeoAgent';

  @override
  String get whatAreYouAdding => 'Wat voeg je toe?';

  @override
  String get whatIsOnTomorrow => 'Wat staat er morgen op het programma?';

  @override
  String get whatShouldNeoagentLearn => 'Wat moet NeoAgent leren?';

  @override
  String get whatShouldWeBuild => 'Wat moeten we bouwen?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Wat jij en NeoAgent zeggen, verschijnt hier en in de chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'WhatsApp persoonlijk bericht ontvangen';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Als u kiest voor Alleen goedgekeurd, voegt u hieronder mensen of groepen toe.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Waar deze agent antwoorden moet sturen.';

  @override
  String get whoCanMessage => 'Wie kan een bericht sturen';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Wie kan een bericht sturen op $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Wie kan $arg1 een één-op-één bericht sturen.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Wie kan met $arg1 praten in een groep, kanaal of kamer.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'wie dit account beheert, staat uitgeschakeld: ';

  @override
  String get whoManagesWhom => 'Wie beheert wie';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Degene die een link accepteert, wordt lid van uw team met alleen de tools die daarvoor nodig zijn ';

  @override
  String get wholeGroup => 'Hele groep';

  @override
  String get wholeGroups => 'Hele groepen';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Waarom $arg1 reageerde of stil bleef in $arg2-groepen.';
  }

  @override
  String get windowsApp => 'Windows-app';

  @override
  String get windowsNt => 'Windows NT';

  @override
  String get workAccount => 'Werkaccount';

  @override
  String get workOnAProjectWithNeoagent => 'Werk aan een project met NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Werkstroom: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Werken in $arg1 op de cloudcomputer. NeoAgent leest en bewerkt daar bestanden en kan opdrachten en een browser uitvoeren.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Op de achtergrond werken: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Werkruimteconfiguratie en accountbeveiliging op één plek.';

  @override
  String get workspaceFiles => 'Werkruimtebestanden';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Werkruimte, modellen en diagnostische besturingselementen.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Het overschrijven van de werkruimte moet een absoluut pad zijn.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Schreef $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest-fout';

  @override
  String get yesterday => 'Gisteren';

  @override
  String get youAreInControl => 'Jij hebt de controle';

  @override
  String get youCanFollowAlongOnThe => 'Je kunt het volgen op het bureaublad.';

  @override
  String get youCanLeaveATeamAt =>
      'Je kunt op elk moment een team verlaten; uw eigen instellingen zijn weer van toepassing.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Je kunt op elk moment vertrekken vanaf de teampagina.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'U bepaalt zelf welke tools uw agent mag gebruiken, onder Instellingen › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Je beheert nog niemand. Maak hieronder een uitnodigingslink en ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'U heeft niet-opgeslagen instellingen. Wat zou je graag willen doen?';

  @override
  String get youReOnYourOwnYou =>
      'U staat er alleen voor: u bepaalt welke tools uw agent mag gebruiken. Als ';

  @override
  String get yourAccountAndUsageOnA =>
      'uw account - en gebruik op een model dat wordt ondersteund door uw eigen sleutel ';

  @override
  String get yourAccountHasBeenDeleted => 'Uw account is verwijderd.';

  @override
  String get yourAgentWillBeAllowed => 'Uw agent mag:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Uw apps en bestanden worden opgeslagen.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Je apps en bestanden blijven opgeslagen.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Uw $arg1-sleutel';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Uw assistentlaag voor vastleggen, context en actie.';

  @override
  String get yourComputerIsAsleep => 'Uw computer slaapt';

  @override
  String get yourComputerIsOff => 'Uw computer staat uit';

  @override
  String get yourComputerIsReady => 'Uw computer is klaar';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Uw huidige wachtwoord is onjuist.';

  @override
  String get yourData => 'Jouw gegevens';

  @override
  String get yourDataExportWasCopiedTo =>
      'Uw gegevensexport is naar het klembord gekopieerd.';

  @override
  String get yourDesktopIsReady => 'Je bureaublad is klaar';

  @override
  String get yourLinuxComputer => 'Je Linux-computer';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Uw locatie wordt nooit continu gevolgd of opgeslagen op onze servers. We gebruiken het alleen lokaal om uw actieve taken te vergelijken.';

  @override
  String get yourManager => 'uw leidinggevende';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Uw Mattermost-site-URL, als u de REST API gebruikt.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Uw sessie is verlopen of is niet bewaard door de browser. Meld u opnieuw aan.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Uw sessie is verlopen. Meld u opnieuw aan.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Uw gebruikersnaam of wachtwoord is onjuist.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Persoonlijk';

  @override
  String get sectionOverview => 'Overzicht';

  @override
  String get sectionDiagnostics => 'Diagnostiek';

  @override
  String get sectionVolume => 'Volume';

  @override
  String get sectionSession => 'Sessie';

  @override
  String get sectionDeliverable => 'Leverbaar';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'De lokale runtime heeft nog geen logbestand geschreven.';

  @override
  String get thisComputer => 'Deze computer';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta installeert de nieuwste prerelease-backend. Verwacht ruwe randen.';

  @override
  String get copiedFinalResponse => 'Eindreactie gekopieerd';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Het definitieve antwoord verschijnt hier wanneer de run is voltooid.';

  @override
  String get waitingForTheFirstStep => 'Wachten op de eerste stap...';

  @override
  String get loadingPrompt => 'Prompt laden...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Er is voor deze run geen definitief antwoord vastgelegd.';

  @override
  String get readyToSignIn => 'Klaar om in te loggen';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Schakel over naar \'Standaard\' of \'Altijd vragen\' om goedkeuringscontroles opnieuw in te schakelen.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Stuur een stuurupdate of volgende opmerking voor de huidige run...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Geen netwerkverbinding. NeoAgent zal opnieuw verbinding maken wanneer het apparaat weer online is.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'De laatste stuurupdate toegepast op de huidige run.';

  @override
  String get preparingThePrivateVoiceSession =>
      'De privéstemsessie voorbereiden…';

  @override
  String get preparingYourComputer => 'Uw computer voorbereiden';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent is bezig met het downloaden en voorbereiden van het beveiligde Linux-systeem. Dit gebeurt alleen de eerste keer.';

  @override
  String get moreFreeSpaceIsNeeded => 'Er is meer vrije ruimte nodig';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Maak wat schijfruimte vrij op de NeoAgent-host en probeer het opnieuw. Uw bestaande computergegevens zijn veilig.';

  @override
  String get androidReady => 'Android klaar';

  @override
  String get startingAndroid2 => 'Android starten…';

  @override
  String get androidStopped => 'Android gestopt';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Bij de eerste start worden de Android SDK en de systeemimage gedownload, wat enkele minuten kan duren.';

  @override
  String get androidIsStopped => 'Android is gestopt';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Start de beheerde Android-omgeving wanneer u deze nodig heeft.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Laat NeoAgent op deze computer werken';

  @override
  String get firstTimeSetupIsInProgress =>
      'De eerste installatie wordt uitgevoerd.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent kan de toegang gebruiken die u toestaat.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Maak wat hostopslag vrij en probeer het opnieuw.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Begin hier wanneer u wilt dat NeoAgent helpt.';

  @override
  String get systemPermissionMissing => 'Systeemmachtiging ontbreekt';

  @override
  String get connectingThisDevice => 'Dit apparaat aansluiten';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'De beveiligde lokale verbinding wordt tot stand gebracht.';

  @override
  String get recordingYourDemonstration => 'Uw demonstratie opnemen';

  @override
  String get noErrorsInTheRecentLog => 'Geen fouten in het recente logboek.';

  @override
  String get loadingAccounts => 'Accounts laden…';

  @override
  String get neverSignedIn => 'Nooit aangemeld';

  @override
  String get emptyUsesTheServerDefault => 'Leeg gebruikt de serverstandaard.';

  @override
  String get followTheSelectedSession => 'Volg de geselecteerde sessie';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Alleen de planmodus inspecteert. Schakel over naar de Agent-modus om NeoAgent bestanden te laten bewerken.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Vereist om uw account-e-mailadres toe te voegen of te wijzigen.';

  @override
  String get confirmNewPassword => 'Bevestig nieuw wachtwoord';

  @override
  String get passwordChanged => 'Wachtwoord gewijzigd.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Dit verzoek is al gebruikt.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Dit verzoek is verlopen. Vraag het andere apparaat om een ​​nieuwe code te genereren.';

  @override
  String get startQuickstart => 'Snelstart starten';

  @override
  String get createYourAccount => 'Maak uw account aan';

  @override
  String get showWorkAsSummaries => 'Toon werk als samenvattingen';

  @override
  String get tokensUsedByTheLatestRun => 'Tokens gebruikt door de laatste run';

  @override
  String get listedTheWorkspaceRoot => 'Vermeld de hoofdmap van de werkruimte';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Er zijn nog geen officiële integraties beschikbaar.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Er zijn nog geen MCP-servers geconfigureerd. Voeg er een toe om de tools ervan zichtbaar te maken.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Voeg een MCP-server toe of installeer een vaardigheid om aan de slag te gaan.';

  @override
  String get setUp => 'Instellen';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Laat dit leeg om de opgeslagen waarde te behouden';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Hierdoor wordt het adres van elk account op deze server verwijderd.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Gewoon praten. U kunt op elk moment onderbreken. Tik om te dempen.';

  @override
  String get tapAgainWhenYouAreDone => 'Tik nogmaals als u klaar bent.';

  @override
  String get workingOnATaskInTheBackground =>
      'Op de achtergrond bezig met een taak.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Spraak-naar-spraak met hetzelfde geheugen, dezelfde tools en chatgeschiedenis als NeoAgent.';

  @override
  String get checkLink => 'Controleer de link';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Uw agent mag geen van de gecontroleerde hulpmiddelen gebruiken.';

  @override
  String get notYoursToChange => 'Het is niet aan jou om te veranderen';

  @override
  String get setByYou => 'Door jou ingesteld';

  @override
  String get noTools => 'Geen gereedschap';

  @override
  String get untitledLink => 'Naamloze link';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Stopt met werken nadat één persoon het heeft ingewisseld.';

  @override
  String get theOperator => 'De exploitant';

  @override
  String get smartSelectorOn => 'Slimme selector aan';

  @override
  String get startASessionToBegin => 'Start een sessie om te beginnen';

  @override
  String get steerTheActiveRun => 'Stuur de actieve run…';

  @override
  String get describeWhatToPlan => 'Beschrijf wat u wilt plannen...';

  @override
  String get stopDictation => 'Stop met dicteren';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Berichten sturen de huidige run · ⌘↵ verzenden · ⌘. stop';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Alleen inspecteert de planmodus; er verandert niets totdat u · ⌘↵ verzenden implementeert';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent bewerkt de werkruimte. Plan alleen inspecties.';

  @override
  String get defaultModel => 'Standaardmodel';

  @override
  String get openingScanner => 'Scanner openen...';

  @override
  String get theAgentCanUseThisSkill =>
      'De agent kan deze vaardigheid gebruiken.';

  @override
  String get allSelected => 'Allemaal geselecteerd';

  @override
  String get addCoreMemoryEntry => 'Kerngeheugeninvoer toevoegen';

  @override
  String get channelId => 'Kanaal-ID';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Door AI gemaakte en niet-gespecificeerde taken gebruiken de huidige standaard.';

  @override
  String get waitingForRunEvents => 'Wachten op run-evenementen...';

  @override
  String get hideSteps => 'Stappen verbergen';

  @override
  String get commitTheActiveLiveCapture => 'Voer de actieve live-opname uit';

  @override
  String get stopCaptureAndSubmit => 'Stop met vastleggen en verzend';

  @override
  String get clickTheMicToStartSpeaking =>
      'Klik op de microfoon om te beginnen met spreken';

  @override
  String get connectACustomEndpoint => 'Verbind een aangepast eindpunt';

  @override
  String get hostedProvider => 'gehoste aanbieder.';

  @override
  String get muted => ' • gedempt';

  @override
  String get addWhoCanMessage => 'Voeg toe wie berichten kan sturen';

  @override
  String get joinsGroupConversations => 'Neemt deel aan groepsgesprekken';

  @override
  String get label1PersonOrGroupAdded => '1 persoon of groep toegevoegd';

  @override
  String get inProgress => 'In uitvoering';

  @override
  String get waitingForUpdateJobOutput => 'Wachten op updatetaakuitvoer...';

  @override
  String get taskTrigger => 'Taaktrigger';

  @override
  String get bearerToken => 'Token aan toonder';

  @override
  String get bearerToken2 => 'Token aan toonder';

  @override
  String get notRecorded => 'Niet opgenomen';

  @override
  String get sessionCookie => 'Sessiecookie';

  @override
  String get neverUsed => 'Nooit gebruikt';

  @override
  String get linkedRecently => 'Onlangs gekoppeld';

  @override
  String get notUsedYet => 'Nog niet gebruikt';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Een of meer accounts zijn verlopen. Maak opnieuw verbinding om de toegang te herstellen. Als dit blijft gebeuren, bevindt uw Google Cloud OAuth-app zich mogelijk in de testmodus. Publiceer deze naar Productie in de Google Cloud Console om tokens met een lange levensduur te krijgen.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault verbonden en beschikbaar na herstart';

  @override
  String get vaultConnectedForThisSession => 'Vault verbonden voor deze sessie';

  @override
  String get connectAnotherAccount => 'Koppel een ander account';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Plak het vervangende langlevende toegangstoken';

  @override
  String get updateInstance => 'Instantie bijwerken';

  @override
  String get pasteAReplacementToken => 'Plak een vervangend token';

  @override
  String get replaceAccount => 'Vervang account';

  @override
  String get addAccount => 'Account toevoegen';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Kan delegeren aan elke ontvangende agent';

  @override
  String get canReceiveDelegatedTasks2 => 'gedelegeerde taken kunnen ontvangen';

  @override
  String get noSyncYet => 'Nog geen synchronisatie';

  @override
  String get noNewData => 'Geen nieuwe gegevens';

  @override
  String get syncOnceToSeedYourBackend =>
      'Synchroniseer één keer om uw backend te seeden.';

  @override
  String get lastWindowEndIsUnknown => 'Laatste venstereinde is onbekend.';

  @override
  String get lastNonEmptySync => 'Laatste niet-lege synchronisatie';

  @override
  String get stopTranscribe => 'Stoppen en transcriberen';

  @override
  String get steeringMode => 'Stuurmodus';

  @override
  String get noMessageText => 'Geen berichttekst';

  @override
  String get reconnectingToServer => 'Opnieuw verbinding maken met de server…';

  @override
  String get signingIn => 'Aanmelden...';

  @override
  String get noGroupsFoundYet => 'Nog geen groepen gevonden';

  @override
  String get onForNewGroupsOnly => 'Alleen ingeschakeld voor nieuwe groepen';

  @override
  String get noGroupsInThisCategory => 'Geen groepen in deze categorie';

  @override
  String get groupOrChannel => 'Groep of kanaal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Notities die u aan uzelf schrijft, beginnen een run en antwoorden komen in dezelfde chat terecht. De toelatingslijst is hier niet van toepassing.';

  @override
  String get needToReply => 'Moet antwoorden';

  @override
  String get enter2faCode => 'Voer de 2FA-code in';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Open uw authenticator-app en voer de huidige NeoAgent-code in.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Heeft u al een account? Log in';

  @override
  String get serverOnThisComputer => 'Server op deze computer';

  @override
  String get showQrCode => 'Laat QR-code zien';

  @override
  String get createAnotherNeoagentAccount =>
      'Maak nog een NeoAgent-account aan.';

  @override
  String get canCoordinateDelegatedWork => 'Kan gedelegeerd werk coördineren';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Het NeoAgent runtime-archief kon niet worden uitgepakt.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Het NeoAgent runtime-archief kon niet worden gelezen.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Het NeoAgent runtime-archief bevat een onveilig pad.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Het NeoAgent runtime-archief bevat een onveilige link.';

  @override
  String get installingAppPackageOnThePhone =>
      'App-pakket op de telefoon installeren...';

  @override
  String get dragAndDropAApkOrApks =>
      'Sleep hier een .apk- of .apks-bestand, of klik om te bladeren.';

  @override
  String get releaseToInstallThisPackage =>
      'Geef vrij om dit pakket te installeren';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'De beveiligingssleutel kan niet worden gebruikt.';

  @override
  String get connecting => 'Verbinden…';

  @override
  String get changes => 'Veranderingen';

  @override
  String get runtimeReady => 'Runtime klaar';

  @override
  String get saving => 'Opslaan...';

  @override
  String get earlier => 'Eerder';

  @override
  String get monthJan => 'jan';

  @override
  String get monthFeb => 'februari';

  @override
  String get monthMar => 'Maart';

  @override
  String get monthApr => 'april';

  @override
  String get monthMay => 'Mei';

  @override
  String get monthJun => 'jun';

  @override
  String get monthJul => 'juli';

  @override
  String get monthAug => 'augustus';

  @override
  String get monthSep => 'september';

  @override
  String get monthOct => 'okt';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'dec';

  @override
  String get steeringWord => 'Sturen';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Hiermee schakelt u de backend van het $arg1-kanaal naar het $arg2-kanaal.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1-cookies geïmporteerd';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '$arg1\'s geleden';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Wachtrijbesturing: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'De webapp kan de NeoAgent-backend niet bereiken.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'De browser heeft een vereist verzoek geblokkeerd vanwege het inhoudsbeveiligingsbeleid.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 van 4 toegestaan';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Werk de taak uit zoals u dat normaal zou doen.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Wijzigingen · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Dit apparaat · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limiet bereikt$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1-herstelcodes zijn nog steeds beschikbaar.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Beveiligingssleutel $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Huidige sessie';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nLaatst gebruikt: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Werken in $arg1 op dit apparaat. NeoAgent leest en bewerkt de map direct en kan opdrachten uitvoeren, apps openen en het scherm gebruiken.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Heeft gewerkt voor $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Toegestaan door $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1-uitnodigingslinks van $arg2 zijn ingetrokken';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Voeg de mensen en groepen toe waarmee $arg1 moet praten';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Voeg de mensen en groepen toe waarmee $arg1 mag praten.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Waar $arg1 luistert';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 houdt deze plaatsen in de gaten voor vermeldingen. Iedereen kan hier berichten plaatsen, dus mensen hebben hieronder nog steeds hun eigen goedkeuring nodig.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Deze mensen kunnen $arg1 vragen, waar ze het ook taggen. Rollen tellen alleen op de hierboven genoemde plaatsen.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Alleen als $arg1 is getagd';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Aan voor alle $arg1-groepen';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 hoort nog steeds alleen mensen en groepen die u al heeft goedgekeurd. Hierdoor kan $arg1 daar gewoon deelnemen aan de gewone chat, niet alleen aan tags en antwoorden.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 hoort nog steeds alleen mensen en groepen die u al heeft goedgekeurd. Dit kiest gewoon bij welke van die groepen het zich moet aansluiten.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Als iemand $arg1 tagt of antwoordt, antwoordt $arg1 altijd. Schakel dit in als $arg1 ook moet meedoen aan de gewone groepschat.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Met nieuwe groepen kan $arg1 deelnemen aan de gewone chat met goedgekeurde mensen, totdat je ze uitschakelt.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Met nieuwe groepen kan $arg1 deelnemen aan de gewone chat totdat je ze uitschakelt.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nieuwe groepen blijven stil tenzij een goedgekeurde persoon $arg1 tagt, totdat u ze inschakelt.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Alleen als een goedgekeurde persoon $arg1 tagt, tenzij je een groep aanzet';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Alleen als $arg1 is getagd, tenzij je een groep inschakelt';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 van de $arg2-groepen nemen deel aan de gewone chat met goedgekeurde mensen';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Dit keurt nieuwe mensen niet goed. Tags en antwoorden van goedgekeurde mensen krijgen altijd een reactie. Schakel een groep in als $arg1 daar ook aan de gewone chat moet deelnemen.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Dit keurt nieuwe mensen niet goed. Schakel een groep in als $arg1 moet deelnemen aan de gewone chat met mensen die u al heeft goedgekeurd.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Tags en antwoorden krijgen altijd een reactie. Schakel een groep in als $arg1 daar ook aan de gewone chat moet deelnemen.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 neemt deel aan de gewone chat met goedgekeurde mensen';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 kan deelnemen aan de gewone chat';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 antwoordt alleen als een goedgekeurde persoon hem tagt';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Er is niets extra\'s nodig. Maak verbinding om $arg1 te gaan gebruiken.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Vernieuwt in ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registreer u bij $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Geen herinneringen gekoppeld aan \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (standaard)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filiaal: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 wordt alleen lid van de groepen en kanalen die je hieronder toevoegt.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 is vereist om NeoAgent-runtimegegevens te lokaliseren.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[afgeknot voorbeeld, $arg1 bytes totaal]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefact begrensd, $arg1 bytes totaal]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' in $arg1';
  }

  @override
  String get worldNews => 'Wereldnieuws';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Ren wanneer nieuwe wereldnieuws verschijnen. Uw prompt bepaalt of u op de hoogte wordt gesteld.';

  @override
  String get newsKeywordsOptional => 'Trefwoorden (optioneel)';

  @override
  String get worldNewsSetup => 'Wereldnieuws instellen';

  @override
  String get connectWorldNewsWithGnews =>
      'Voeg een GNews API-sleutel toe (gratis abonnement beschikbaar op gnews.io). Het wordt gecodeerd opgeslagen en gebruikt om de belangrijkste krantenkoppen te peilen naar triggers van Wereldnieuws.';

  @override
  String get gnewsApiKey => 'GNews API-sleutel';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Plak de vervangende GNews API-sleutel';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Laat de sleutel leeg om de momenteel opgeslagen sleutel te behouden.';

  @override
  String get gnewsApiKeyIsRequired => 'Een GNews API-sleutel is vereist.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Kan de World News-configuratie niet opslaan.';

  @override
  String get disconnectWorldNews => 'Ontkoppel Wereldnieuws';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Hiermee wordt de opgeslagen GNews API-sleutel verwijderd. World News-triggers stoppen met vuren totdat u opnieuw een sleutel toevoegt.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Kon de verbinding met World News niet verbreken.';

  @override
  String get systemOneModels => 'SystemOne-modellen';

  @override
  String get systemOneAuto => 'Automatisch';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Kiest het best beschikbare SystemOne-model';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Het chatmodel neemt deze beslissingen';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Beslissingsmodellen die in een fractie van een seconde de achter-de-schermen-gesprekken voeren: groepschats om beurten en browserstappen. Uw chatmodel schrijft nog steeds elk antwoord.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Het SystemOne-model beslist wanneer er moet worden gesproken terwijl het is ingeschakeld; dit model is de fallback.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 gescoord door SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne scoorde dit bericht direct. Er is geen taalmodel uitgevoerd.';

  @override
  String get systemOneUnavailable => 'SystemOne is niet beschikbaar';

  @override
  String get systemOneAdminAvailability =>
      'Beslissingsmodellen die agenten kunnen kiezen onder Instellingen › Modellen. Een model dat hier is uitgeschakeld, verlaat die kiezer en agenten die ervoor hebben gekozen, vallen terug op Auto. Terwijl elk model is uitgeschakeld, worden SystemOne-modellen die providers later toevoegen, ook uitgeschakeld.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Nog geen SystemOne-modellen. Voeg een TypeSafe- of OpenRouter-sleutel toe onder Providers, of gebruik een beslissingsmodel zoals nimble in Ollama 0.35 of hoger.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Er is nog geen SystemOne-model beschikbaar. Voeg een TypeSafe- of OpenRouter-sleutel toe onder Instellingen › Modellen › Breng uw eigen sleutel mee, of gebruik een beslismodel zoals nimble in Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one beslissingsmodellen jev typesafe openrouter ollama beschikbaarheid inschakelen uitschakelen';

  @override
  String get chatModels => 'Chat-modellen';

  @override
  String get disabled => 'Uitgeschakeld';

  @override
  String get enableShown => 'Inschakelen getoond';

  @override
  String get disableShown => 'Uitschakelen weergegeven';

  @override
  String get expandAll => 'Alles uitvouwen';

  @override
  String get collapseAll => 'Alles samenvouwen';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 niet-opgeslagen wijzigingen';
  }

  @override
  String get settingsScopeAllAgents => 'Alle agenten';

  @override
  String get settingsScopeAgent => 'Deze agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint =>
      'Hetzelfde overal waar u zich aanmeldt';

  @override
  String get settingsScopeAllAgentsHint => 'Gedeeld door al uw agenten';

  @override
  String get settingsAppliesTo => 'Geldt voor';

  @override
  String get settingsSaving => 'Opslaan…';

  @override
  String get settingsSavedAutomatically =>
      'Wijzigingen worden automatisch opgeslagen';

  @override
  String get settingsSearchHint => 'Zoek alle instellingen';

  @override
  String get settingsPageProfile => 'Profiel';

  @override
  String get settingsPageSecurity => 'Inloggen en beveiliging';

  @override
  String get settingsPageUsage => 'Gebruik';

  @override
  String get settingsPagePermissions => 'Machtigingen';

  @override
  String get settingsPageComputer => 'Computer en internet';

  @override
  String get settingsPageBehavior => 'Gedrag';

  @override
  String get settingsPageSystem => 'Systeem';

  @override
  String get settingsPagePlatforms => 'Platforms';

  @override
  String get settingsPageProfileDescription =>
      'Uw naam en e-mailadres, een kopie van uw gegevens en uitloggen.';

  @override
  String get settingsPageSecurityDescription =>
      'Wachtwoord, tweefactorauthenticatie, beveiligingssleutels en waar u bent aangemeld.';

  @override
  String get settingsPageUsageDescription =>
      'Uw limieten en tokenuitgaven, allemaal op één plek.';

  @override
  String get settingsPageAgentsDescription =>
      'Maak agenten aan en kies welke standaard antwoordt.';

  @override
  String get settingsPagePermissionsDescription =>
      'Wat uw agenten kunnen doen zonder u eerst te vragen.';

  @override
  String get settingsPageComputerDescription =>
      'De computer waarop uw agenten werken en de sites die zij net als u kunnen lezen.';

  @override
  String get settingsPageModelsDescription =>
      'Welke modellen deze agent gebruikt en de API-sleutels die ervoor betalen.';

  @override
  String get settingsPageBehaviorDescription =>
      'Hoe deze agent praat en hoe hij een groepschat leest.';

  @override
  String get settingsPageVoiceDescription =>
      'Live oproepen, dicteren en gesproken antwoorden voor deze agent.';

  @override
  String get settingsPageMessagingDescription =>
      'Waar mensen deze agent kunnen bereiken en hoe deze zich gedraagt ​​in chats.';

  @override
  String get settingsPageGeneralDescription =>
      'Uiterlijk, taal, tijdzone en wat deze app op de achtergrond doet.';

  @override
  String get settingsPageSystemDescription =>
      'De server die dit venster gebruikt, die op deze computer, en app-updates.';

  @override
  String get settingsYourAgents => 'Jouw agenten';

  @override
  String get settingsChatModel => 'Chatmodel';

  @override
  String get settingsChatModelDescription => 'Beantwoordt uw berichten.';

  @override
  String get settingsSubAgentModel => 'Subagentmodel';

  @override
  String get settingsSubAgentModelDescription =>
      'Voert werk uit dat tijdens een taak wordt overgedragen.';

  @override
  String get settingsDefaultModels => 'Standaardmodellen';

  @override
  String get settingsDefaultModelsDescription =>
      'Wordt gebruikt wanneer een chat of taak niet zijn eigen model kiest.';

  @override
  String get settingsModelPool => 'Modelzwembad';

  @override
  String get settingsApiKeysDescription =>
      'Gebruik uw eigen sleutels of eindpunt voor deze agent. Sleutels worden gecodeerd en nooit meer getoond.';

  @override
  String get settingsPersona => 'Persoon';

  @override
  String get settingsFineTuning => 'Fijnafstemming';

  @override
  String get settingsFineTuningDescription =>
      'Zelden nodig. De standaardinstellingen zijn geschikt voor de meeste chats.';

  @override
  String get settingsShow => 'Toon';

  @override
  String get settingsHide => 'Verbergen';

  @override
  String get settingsMinimumContribution => 'Minimale contributiewaarde';

  @override
  String get settingsBatchWindow => 'Kamerbatchvenster';

  @override
  String get settingsBatchWindowDescription =>
      'Wacht zo lang voordat snelle berichten als één beurt worden behandeld.';

  @override
  String get settingsHandsFree => 'Handsfree';

  @override
  String get settingsHandsFreeDescription =>
      'Praat vrijuit en onderbreek op elk moment.';

  @override
  String get settingsPushToTalkDescription =>
      'Houd ingedrukt om te praten, laat los om te verzenden.';

  @override
  String get settingsLiveVoice => 'Live-stem';

  @override
  String get settingsChannels => 'Kanalen';

  @override
  String get settingsGroupChats => 'In groepschats';

  @override
  String get settingsGroupChatsDescription =>
      'Hoe deze agent zich in groepen op elk kanaal gedraagt.';

  @override
  String get settingsGroupChatsDisabled =>
      'Schakel gedragsmodules in Gedrag in om deze te wijzigen.';

  @override
  String get settingsParticipationAutomatic => 'Automatisch';

  @override
  String get settingsParticipationMentionOnly => 'Alleen vermelden';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Leest de kamer en doet mee als hij iets nuttigs toe te voegen heeft.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Reageert alleen wanneer vermeld of beantwoord.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Antwoorden op elk bericht.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Splitst langere antwoorden op in korte berichten, zoals iemand dat zou doen.';

  @override
  String get settingsDeliverySingleDescription =>
      'Verzendt elk antwoord als één bericht.';

  @override
  String get settingsComputerStatus => 'Status';

  @override
  String get settingsTest => 'Testen';

  @override
  String get settingsAppearance => 'Uiterlijk';

  @override
  String get settingsTheme => 'Thema';

  @override
  String get settingsThemeSystem => 'Systeem';

  @override
  String get settingsThemeLight => 'Licht';

  @override
  String get settingsThemeDark => 'Donker';

  @override
  String get settingsCloseWindow => 'Wanneer u het venster sluit';

  @override
  String get settingsCloseAsk => 'Vraag';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent blijft op de achtergrond draaien en blijft bereikbaar.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent stopt volledig.';

  @override
  String get settingsPhoneTriggers => 'Telefoontriggers';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signalen die deze telefoon naar uw agenten stuurt, zodat taken erop kunnen reageren.';

  @override
  String get settingsLocationTriggers => 'Locatietriggers';

  @override
  String get settingsLocationTriggersDescription =>
      'Controleert elke paar minuten uw geschatte locatie ten opzichte van de plaatsen waar uw taken naar kijken.';

  @override
  String get settingsNotificationTriggers => 'Meldingstriggers';

  @override
  String get settingsNotificationTriggersDescription =>
      'Stuur meldingen van andere apps op deze telefoon door naar uw agenten.';

  @override
  String get settingsSetup => 'Installatie';

  @override
  String get settingsOnboarding => 'Aan boord';

  @override
  String get settingsOnboardingDescription =>
      'Loop opnieuw door de eerste run-installatie. Niets dat u hebt ingesteld, gaat verloren.';

  @override
  String get settingsUsernameDescription =>
      'Wordt gebruikt om in te loggen. Dit kan niet worden gewijzigd.';

  @override
  String get settingsExport => 'Exporteren';

  @override
  String get settingsLeave => 'Uitloggen en verwijderen';

  @override
  String get settingsSignOutDescription =>
      'Hiermee wordt u alleen op dit apparaat uitgelogd.';

  @override
  String get settingsDeleteAccountDescription =>
      'Wist uw account, agenten, geheugen en instellingen. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get settingsTokenUsage => 'Tokengebruik';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Geen enkele instelling komt overeen met “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultaten',
      one: '$count resultaat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Geavanceerde modelinstellingen';

  @override
  String get settingsAdvancedModelsDescription =>
      'Optioneel. Een model vastpinnen op één soort werk; het neemt het over wanneer de agent deze tools gebruikt. Alles wat standaard blijft staan, volgt het chatmodel.';

  @override
  String get settingsTaskModelDefault => 'Standaard';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Volgt het chatmodel';

  @override
  String get settingsTaskModelCoding => 'Codering';

  @override
  String get settingsTaskModelCodingDescription =>
      'Code schrijven, bewerken en debuggen.';

  @override
  String get settingsTaskModelComputerUse => 'Computergebruik';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Het besturen van de browser en desktop.';

  @override
  String get settingsTaskModelAndroidUse => 'Android-gebruik';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Apps bedienen op een Android-apparaat of emulator.';

  @override
  String get settingsTaskModelResearch => 'Onderzoek';

  @override
  String get settingsTaskModelResearchDescription =>
      'Bronnen zoeken, lezen en samenvatten.';

  @override
  String get knowledgeGraphHint =>
      'Uw meest genoemde entiteiten, gekleurd per cluster. Lijnen verbinden entiteiten die in dezelfde herinneringen voorkomen. Tik op één om de links en herinneringen te bekijken; sleep om te pannen, knijp of Ctrl/⌘-scroll om te zoomen.';

  @override
  String get linkedEntities => 'Gekoppelde entiteiten';

  @override
  String get noLinkedEntities => 'Nog niet gekoppeld aan andere entiteiten.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 vermeldt';
  }

  @override
  String get entityKindConcept => 'Begrip';

  @override
  String get entityKindDomain => 'Domein';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Koppeling';

  @override
  String get entityKindFile => 'Bestand';

  @override
  String get entityKindAcronym => 'Acroniem';

  @override
  String get entityKindIdentifier => 'Identificatie';

  @override
  String get entityKindVersion => 'Versie';

  @override
  String get openFullscreen => 'Volledig scherm openen';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Uitzoomen';

  @override
  String get searchEntities => 'Zoek een entiteit';

  @override
  String get incomingCall => 'Inkomend gesprek';

  @override
  String get answerCall => 'Antwoord';

  @override
  String get callMeLater => 'Bel mij later';

  @override
  String get callingEllipsis => 'Bellen…';

  @override
  String get reconnectingCall => 'Opnieuw verbinding maken';

  @override
  String get agentWorking => 'Werken';

  @override
  String get micMuted => 'Gedempt';

  @override
  String get speakerphone => 'Spreker';

  @override
  String get muteMic => 'Dempen';

  @override
  String get unmuteMic => 'Dempen opheffen';

  @override
  String get releaseToSend => 'Laat los om te verzenden';

  @override
  String get callEnded => 'Gesprek beëindigd';

  @override
  String get openConversation => 'Open gesprek';

  @override
  String get callBack => 'Bel terug';

  @override
  String get letCallsReachYou => 'Laat oproepen u bereiken';

  @override
  String get callPermissionsIntro =>
      'Uw agenten kunnen u bellen. Om te kunnen overgaan als een telefoongesprek terwijl NeoAgent op de achtergrond staat of uw telefoon is vergrendeld, heeft hij deze nodig.';

  @override
  String get showOverOtherApps => 'Toon boven andere apps';

  @override
  String get showOverOtherAppsDetail =>
      'Brengt het oproepscherm naar voren, waar u ook bent.';

  @override
  String get fullScreenCalls => 'Gesprekken op volledig scherm';

  @override
  String get fullScreenCallsDetail => 'Beltonen over het vergrendelscherm.';

  @override
  String get unrestrictedBattery => 'Onbeperkte batterij';

  @override
  String get unrestrictedBatteryDetail =>
      'Houdt NeoAgent verbonden zodat oproepen binnenkomen.';

  @override
  String get permissionAllowed => 'Toegestaan';

  @override
  String get triggerSectionCalendar => 'Kalender';

  @override
  String get triggerSectionFiles => 'Bestanden en documenten';

  @override
  String get triggerSectionHome => 'Thuis en media';

  @override
  String get triggerSectionDevices => 'Apparaten en plaatsen';

  @override
  String get triggerSectionTasks => 'Taken';

  @override
  String get messagingMemberJoined => 'Lid is toegetreden';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Wordt uitgevoerd wanneer iemand lid wordt van een Discord-server, Telegram- of WhatsApp-groep, Slack-kanaal of Matrix-ruimte.';

  @override
  String get messagingMemberLeft => 'Lid is vertrokken';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Wordt uitgevoerd wanneer iemand een Discord-server, Telegram- of WhatsApp-groep, Slack-kanaal of Matrix-kamer verlaat.';

  @override
  String get messagingReactionAdded => 'Reactie toegevoegd';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Wordt uitgevoerd wanneer een toegestane persoon reageert op een bericht in een privéchat.';

  @override
  String get messagingPlatformDisconnected => 'Berichten verbroken';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Uitvoeren wanneer een berichtenverbinding stopt en u nodig heeft, bijvoorbeeld na het afmelden.';

  @override
  String get googleCalendarEventStarting => 'Google Agenda-evenement begint';

  @override
  String get googleCalendarEventCreated => 'Google Agenda-afspraak gemaakt';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Wordt uitgevoerd wanneer er een nieuwe gebeurtenis of uitnodiging verschijnt.';

  @override
  String get outlookCalendarEventStarting => 'Outlook Agenda-evenement begint';

  @override
  String get nextcloudCalendarEventStarting =>
      'Volgendecloud Agenda-evenement begint';

  @override
  String get runMinutesBeforeEachEvent =>
      'Voer een vast aantal minuten uit vóór elke gebeurtenis.';

  @override
  String get googleDriveFileAdded => 'Google Drive-bestand toegevoegd';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Wordt uitgevoerd wanneer een bestand wordt toegevoegd aan Drive of een map daarin.';

  @override
  String get googleSheetsRowAdded => 'Google Spreadsheets-rij toegevoegd';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Uitvoeren wanneer er nieuwe rijen in een blad verschijnen.';

  @override
  String get onedriveFileAdded => 'OneDrive-bestand toegevoegd';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Uitvoeren wanneer een bestand wordt toegevoegd aan een OneDrive-map.';

  @override
  String get nextcloudFileAdded => 'Nextcloud-bestand toegevoegd';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Uitvoeren wanneer een bestand wordt toegevoegd aan een Nextcloud-map.';

  @override
  String get nextcloudShareReceived => 'Nextcloud-bestand met u gedeeld';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Uitvoeren wanneer iemand een bestand of map met u deelt.';

  @override
  String get notionItemAdded => 'Begrip database-item toegevoegd';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Wordt uitgevoerd wanneer een item wordt toegevoegd aan een Notion-database.';

  @override
  String get notionItemUpdated => 'Begrip database-item bijgewerkt';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Uitvoeren wanneer een item in een Notion-database verandert.';

  @override
  String get trelloCardEnteredList => 'Trello-kaart toegevoegd aan de lijst';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Uitvoeren wanneer een kaart wordt aangemaakt in of verplaatst naar een lijst.';

  @override
  String get figmaCommentAdded => 'Figma-opmerking toegevoegd';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Wordt uitgevoerd wanneer iemand commentaar geeft op een Figma-bestand.';

  @override
  String get githubPrOpened => 'GitHub-pullverzoek geopend';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Wordt uitgevoerd wanneer een nieuw pull-verzoek wordt geopend in een repository.';

  @override
  String get githubWorkflowRunFailed =>
      'GitHub-werkstroomuitvoering is mislukt';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Uitvoeren wanneer een uitvoering van GitHub Actions mislukt.';

  @override
  String get githubCommitPushed => 'GitHub-commit gepusht';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Wordt uitgevoerd wanneer nieuwe commits een branch bereiken.';

  @override
  String get mcpServerFailed => 'MCP-server is mislukt';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Uitvoeren wanneer een werkende MCP-server faalt of moet worden aangemeld.';

  @override
  String get homeAssistantStateChanged =>
      'De status van de Home Assistant is gewijzigd';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Wordt uitgevoerd wanneer een entiteit verandert, een status bereikt of een waarde overschrijdt.';

  @override
  String get spotifyTrackChanged => 'Spotify-track gewijzigd';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Wordt uitgevoerd wanneer een ander nummer begint te spelen.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecall dagelijkse samenvatting klaar';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Wordt uitgevoerd wanneer de samenvatting van een dag definitief is.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall-gesprek opgenomen';

  @override
  String get runWhenARecordedConversationEnds =>
      'Wordt uitgevoerd wanneer een opgenomen gesprek eindigt.';

  @override
  String get geofenceTrigger => 'Locatie geofence';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Ren wanneer uw telefoon een plaats arriveert of verlaat. Locatietracking op de telefoon vereist.';

  @override
  String get healthMetricRecorded => 'Gezondheidsstatistiek geregistreerd';

  @override
  String get runWhenAHealthReadingArrives =>
      'Uitvoeren wanneer een gesynchroniseerde statusmeting binnenkomt, optioneel boven of onder een waarde.';

  @override
  String get wearableConnectionChanged => 'Draagbaar verbonden of losgekoppeld';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Ren wanneer uw wearable verbinding maakt of de verbinding verbreekt.';

  @override
  String get taskRunFinished => 'Weer een taak afgerond';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Uitvoeren nadat een andere taak is voltooid, geslaagd of mislukt.';

  @override
  String get appPackageOptional => 'App-pakket (optioneel)';

  @override
  String get appPackageHelper => 'Bijvoorbeeld com.whatsapp';

  @override
  String get anyPlatform => 'Elk platform';

  @override
  String get spaceIdOptional =>
      'Server-, groeps-, kanaal- of kamer-ID (optioneel)';

  @override
  String get spaceIdHelper => 'Empty kijkt naar iedereen waar de bot in zit.';

  @override
  String get emojiOptional => 'Emoji (optioneel)';

  @override
  String get chatIdOptional => 'Chat-ID (optioneel)';

  @override
  String get platformOptional => 'Platform (optioneel)';

  @override
  String get platformOptionalHelper =>
      'Bijvoorbeeld whatsappen. Lege horloges allemaal.';

  @override
  String get minutesBefore => 'Minuten eerder';

  @override
  String get calendarIdOptional => 'Agenda-ID (optioneel)';

  @override
  String get calendarIdHelper => 'Leeg gebruikt uw primaire agenda.';

  @override
  String get invitesOnly => 'Alleen uitnodigingen van anderen';

  @override
  String get nextcloudCalendarPath => 'Kalender';

  @override
  String get nextcloudCalendarPathHelper =>
      'De naam ervan in de Nextcloud-agendalijst, bijvoorbeeld persoonlijk';

  @override
  String get folderIdOptionalHelperDrive =>
      'Empty houdt heel Drive in de gaten.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty bewaakt de hoofdmap.';

  @override
  String get driveFolderIdOptional => 'Map-ID (optioneel)';

  @override
  String get spreadsheetId => 'Spreadsheet-ID';

  @override
  String get sheetRange => 'Bereik';

  @override
  String get sheetRangeHelper =>
      'De kolommen van de tabel, bijvoorbeeld Blad1!A:E';

  @override
  String get folderPathOptional => 'Mappad (optioneel)';

  @override
  String get folderPathHelper => 'Bijvoorbeeld Documenten';

  @override
  String get notionDatabaseId => 'Database-ID';

  @override
  String get trelloListId => 'Lijst-ID';

  @override
  String get figmaFileKey => 'Bestandssleutel';

  @override
  String get figmaFileKeyHelper =>
      'Via de bestandslink: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Bewaarplaats';

  @override
  String get workflowOptional => 'Werkstroom (optioneel)';

  @override
  String get workflowHelper => 'Bestandsnaam zoals ci.yml';

  @override
  String get branchOptional => 'Filiaal (optioneel)';

  @override
  String get branchHelper => 'Leeg gebruikt de standaardvertakking.';

  @override
  String get mcpServerIdOptional => 'MCP-server-ID (optioneel)';

  @override
  String get entityId => 'Entiteits-ID';

  @override
  String get entityIdHelper => 'Bijvoorbeeld binaire_sensor.front_door';

  @override
  String get targetStateOptional => 'Doelstatus (optioneel)';

  @override
  String get targetStateHelper => 'Bijvoorbeeld op';

  @override
  String get aboveOptional => 'Boven (optioneel)';

  @override
  String get belowOptional => 'Hieronder (optioneel)';

  @override
  String get placeName => 'Plaatsnaam';

  @override
  String get latitude => 'Breedtegraad';

  @override
  String get longitude => 'Lengtegraad';

  @override
  String get radiusMeters => 'Straal in meters';

  @override
  String get geofenceTransition => 'Wanneer';

  @override
  String get arriving => 'Aankomst';

  @override
  String get leaving => 'Vertrekkend';

  @override
  String get healthMetric => 'Gezondheidsstatistiek';

  @override
  String get healthMetricHelper => 'Bijvoorbeeld hartslag, stappen, gewicht';

  @override
  String get wearableTransition => 'Wanneer het draagbare';

  @override
  String get wearableConnects => 'Verbindt';

  @override
  String get wearableDisconnects => 'Verbreekt de verbinding';

  @override
  String get sourceTask => 'Na taak';

  @override
  String get taskOutcome => 'Resultaat';

  @override
  String get anyOutcome => 'Enige uitkomst';

  @override
  String get succeeded => 'Geslaagd';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 ontbreekt of is niet geldig.';
  }

  @override
  String get triggerSectionMessaging => 'Berichten';

  @override
  String get triggerSectionDeveloper => 'Ontwikkelaar';

  @override
  String get triggerSectionMemory => 'Geheugen';

  @override
  String get triggerSectionNews => 'Nieuws';

  @override
  String get triggerSectionSystem => 'Systeem';

  @override
  String get searchTriggersHint => 'Zoektriggers, apps of gebeurtenissen';

  @override
  String get noTriggersMatch =>
      'Geen enkele trigger komt overeen met uw zoekopdracht.';

  @override
  String get triggerAccountMissing => 'Nog geen account';

  @override
  String get pickTriggerKeyboardHint => 'Enter kiest het eerste resultaat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1-triggers';
  }

  @override
  String get addFromSkillsSh => 'Toevoegen vanuit skills.sh';

  @override
  String get skillsShHint =>
      'Zoek hierboven om vaardigheden te vinden op skills.sh, of plak een skills.sh-link of een `npx skills add`-commando.';

  @override
  String get noSkillsShMatches =>
      'Er zijn geen skills.sh-vaardigheden die overeenkomen met deze zoekopdracht.';

  @override
  String get installingSkill => 'Installeren…';

  @override
  String installedSkillArg1(Object? arg1) {
    return '$arg1 geïnstalleerd';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1-installaties';
  }

  @override
  String get authVerify => 'Verifiëren';

  @override
  String get authCreateAccount => 'Account aanmaken';

  @override
  String get authNewInviteLink => 'Nieuwe uitnodigingslink';

  @override
  String get authShowPassword => 'Wachtwoord tonen';

  @override
  String get authHidePassword => 'Wachtwoord verbergen';

  @override
  String get authPasswordWillBeRejected => 'te zwak, zal worden afgewezen';

  @override
  String get authUsernameTooShort =>
      'Gebruikersnamen hebben minimaal 3 tekens nodig.';

  @override
  String get authUsernameTaken => 'Die gebruikersnaam is al in gebruik.';

  @override
  String get authSignupsClosed =>
      'Registratie is gesloten op deze server. Vraag de beheerder om een account.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Deze server accepteert alleen aanmeldingen via HTTPS. Open in plaats daarvan $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Deze server accepteert alleen aanmeldingen via HTTPS. Maak er verbinding mee met een https://-adres.';

  @override
  String get authAccountNotFound => 'Dat account bestaat niet meer.';

  @override
  String get authQrRateLimited =>
      'Te veel QR-inlogverzoeken. Wacht even en vernieuw vervolgens de code.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Wachtwoord vergeten? Vraag je serverbeheerder om het opnieuw in te stellen via Beheerder → Gebruikers.';

  @override
  String get authChangeServer => 'Server wijzigen';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Aanmelden bij $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Dit adres antwoordt niet zoals een NeoAgent-server. Controleer de URL en probeer het opnieuw.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Kan geen beveiligde verbinding (HTTPS) met $arg1 openen.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Kon $arg1 niet bereiken via HTTPS, en gewone HTTP antwoordde ook niet. Controleer het adres en de poort.';
  }

  @override
  String get adminResetPassword => 'Wachtwoord opnieuw instellen';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Wachtwoord opnieuw instellen voor $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Kies een nieuw wachtwoord voor $arg1. Ze worden op elk apparaat uitgelogd en loggen opnieuw in met dit wachtwoord.';
  }

  @override
  String get adminNewPassword => 'Nieuw wachtwoord';

  @override
  String get adminSetPassword => 'Wachtwoord instellen';

  @override
  String get authMissingFields => 'Vul elk verplicht veld in.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 reset het wachtwoord van $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Wachtwoord bijgewerkt; de gebruiker is overal afgemeld.';

  @override
  String get authSignInTitle => 'Aanmelden bij NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Scan met je telefoon of gebruik je wachtwoord.';

  @override
  String get authOrUsePassword => 'of gebruik je wachtwoord';

  @override
  String get qrLoginWaitingTitle => 'Goedkeuren op uw telefoon';

  @override
  String get qrLoginWaitingBody =>
      'Je telefoon heeft de code gescand. Bevestig daar de login om het inloggen te voltooien.';

  @override
  String get qrLoginSigningInOn => 'Inloggen op';

  @override
  String get qrLoginLocation => 'Locatie';

  @override
  String get qrLoginWaitingForApproval => 'Wachten op goedkeuring';

  @override
  String get qrLoginCancelAndUsePassword =>
      'Annuleer en gebruik een wachtwoord';

  @override
  String get qrLoginDeclinedOnPhone =>
      'De login is geweigerd op uw telefoon. Scan de nieuwe code om het opnieuw te proberen.';

  @override
  String get signupKey => 'Registratiesleutel';

  @override
  String get signupKeyStepSubtitle =>
      'Nieuwe accounts op deze server hebben een registratiesleutel nodig. Voer de sleutel in die u van een beheerder hebt gekregen.';

  @override
  String get signupKeyChange => 'Wijzigen';

  @override
  String get signupKeyRequiredError => 'Voer uw registratiesleutel in.';

  @override
  String get signupKeyInvalidError =>
      'Deze registratiesleutel is ongeldig. Controleer hem en probeer het opnieuw.';

  @override
  String get signupKeyUsedError =>
      'Deze registratiesleutel is al gebruikt. Vraag een beheerder om een nieuwe.';

  @override
  String get adminRequireSignupKey => 'Registratiesleutel vereisen';

  @override
  String get adminRequireSignupKeyHint =>
      'Nieuwe accounts hebben een eenmalige sleutel van een beheerder nodig. Als dit uit staat, kan iedereen die deze server kan bereiken zich registreren. Het eerste account heeft nooit een sleutel nodig.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Nieuwe accounts hebben nu een registratiesleutel nodig.';

  @override
  String get adminSignupOpenNotice => 'Iedereen kan zich nu registreren.';

  @override
  String get signupKeys => 'Registratiesleutels';

  @override
  String get signupKeysDescription =>
      'Eenmalige sleutels om te registreren zolang een sleutel vereist is. Elke sleutel maakt precies één account aan.';

  @override
  String get signupKeysNew => 'Nieuwe sleutels';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Ongebruikt · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Gebruikt · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Ingetrokken · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Alle · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Ongebruikt';

  @override
  String get signupKeyStatusUsed => 'Gebruikt';

  @override
  String get signupKeyStatusRevoked => 'Ingetrokken';

  @override
  String get signupKeysExport => 'Exporteren als .txt';

  @override
  String get signupKeysCopied => 'Sleutels gekopieerd';

  @override
  String get signupKeyCopied => 'Sleutel gekopieerd';

  @override
  String get signupKeysEmpty => 'Geen sleutels in deze lijst.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Aangemaakt op $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Gebruikt door $arg1 op $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Gebruikt op $arg1 door een inmiddels verwijderd account';
  }

  @override
  String get signupKeyRevokeTitle => 'Deze sleutel intrekken?';

  @override
  String get signupKeyRevokeMessage =>
      'Niemand kan zich er nog mee registreren. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get signupKeyRevoked => 'Sleutel ingetrokken.';

  @override
  String signupKeysShowMore(int count) {
    return 'Nog $count tonen';
  }

  @override
  String get signupKeysCreateTitle => 'Registratiesleutels aanmaken';

  @override
  String get signupKeysCount => 'Aantal sleutels';

  @override
  String get signupKeysCountHelper => '1 tot 500';

  @override
  String get signupKeysCountInvalid => 'Voer een getal van 1 tot 500 in.';

  @override
  String get signupKeysLabel => 'Label (optioneel)';

  @override
  String get signupKeysLabelHint => 'bijv. Bètatesters voorjaar';

  @override
  String signupKeysCreateAction(int count) {
    return 'Aanmaken ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Sleutels klaar: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Geef elke sleutel aan één persoon. Ongebruikte sleutels blijven in de lijst staan, zodat u ze later opnieuw kunt kopiëren of exporteren.';

  @override
  String get signupKeysSaveDialogTitle => 'Registratiesleutels opslaan';

  @override
  String get signupKeysExported => 'Sleutels geëxporteerd.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor heeft registratiesleutels aangemaakt ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor heeft een registratiesleutel ingetrokken';
  }

  @override
  String get providerChooseUsername => 'Kies je gebruikersnaam';

  @override
  String get providerChooseUsernameBody =>
      'Kies een beschikbare gebruikersnaam om je account af te ronden.';

  @override
  String get dataSharingTitle => 'Gebruiksgegevens delen';

  @override
  String get dataSharingDescription =>
      'Help de beheerders van deze server hem te verbeteren. Deelt hoe je NeoAgent gebruikt, nooit wat je schrijft of opslaat.';

  @override
  String dataSharingSince(String date) {
    return 'Gedeeld sinds $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Wat er gedeeld wordt';

  @override
  String get dataSharingIncluded => 'Gedeeld';

  @override
  String get dataSharingExcluded => 'Nooit gedeeld';

  @override
  String get dataSharingIncludedDevice => 'Apparaattype en app-versie';

  @override
  String get dataSharingIncludedLocale =>
      'App-taal en tijdzoneregio, zoals Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Welke functies je hebt ingesteld, zoals taken, skills en integraties';

  @override
  String get dataSharingIncludedRuns =>
      'Welke tools en modellen je runs gebruiken, met duur en aantal tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Wanneer je NeoAgent gebruikt, per weekdag en uur';

  @override
  String get dataSharingExcludedContent => 'Berichten, prompts en antwoorden';

  @override
  String get dataSharingExcludedRuns =>
      'Run-titels, tool-invoer en -resultaten';

  @override
  String get dataSharingExcludedFiles =>
      'Bestanden, herinneringen en alles wat je verder opslaat';

  @override
  String get dataSharingExcludedIdentity =>
      'Je naam, e-mail, IP-adres en locatie';

  @override
  String get dataSharingExcludedAccounts =>
      'De accounts waarmee je integraties koppelt';

  @override
  String get dataSharingPooledNote =>
      'Beheerders zien alleen totalen over iedereen die deelt, nooit jou afzonderlijk. Zet het op elk moment uit en je valt direct uit de totalen.';

  @override
  String get dataSharingConfirmTitle => 'Gebruiksgegevens delen?';

  @override
  String get dataSharingConfirmAction => 'Delen';

  @override
  String get sharedUsageTitle => 'Gedeeld gebruik';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Accounts die gebruiksgegevens delen: $sharing van $total. Alleen totalen, geen inhoud.';
  }

  @override
  String get sharedUsageEmpty =>
      'Nog niemand deelt gebruiksgegevens. Het staat aan te zetten onder Instellingen, Profiel, Jouw gegevens.';

  @override
  String get sharedUsageRuns => 'Gedeelde runs';

  @override
  String get sharedUsageAvgDuration => 'Gem. duur';

  @override
  String get sharedUsageCompletedRuns => 'Voltooide runs';

  @override
  String get sharedUsageStepsPerRun => 'Stappen per run';

  @override
  String get sharedUsageDevices => 'Apparaten';

  @override
  String get sharedUsageAppVersions => 'App-versies';

  @override
  String get sharedUsageLanguages => 'Talen';

  @override
  String get sharedUsageRegions => 'Regio\'s';

  @override
  String get sharedUsageFeatures => 'Gebruik van functies';

  @override
  String get sharedUsageFeaturesDescription =>
      'Aandeel van de delende accounts dat het heeft ingesteld.';

  @override
  String get sharedUsageTools => 'Tools';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Meest aangeroepen tools ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Aanroepen: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Mislukt: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integraties';

  @override
  String get sharedUsageMessaging => 'Berichtenkanalen';

  @override
  String get sharedUsageTriggers => 'Hoe runs starten';

  @override
  String get sharedUsageActivity => 'Wanneer het gebruikt wordt';

  @override
  String get sharedUsageActivityDescription => 'Runs per weekdag en uur, UTC.';

  @override
  String get sharedUsageModels => 'Modelprestaties';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'gem. $latency · $cached% gecachet · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Accounts: $count';
  }

  @override
  String get sharedUsageNoData => 'Niets in deze periode.';

  @override
  String get sharedUsageNotReported => 'Nog niet gemeld';

  @override
  String get sharedUsageFeatureAgents => 'Meer dan één agent';

  @override
  String get sharedUsageFeatureTasks => 'Geplande taken';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'MCP-servers';

  @override
  String get sharedUsageFeatureIntegrations => 'Integraties';

  @override
  String get sharedUsageFeatureMessaging => 'Berichtenkanalen';

  @override
  String get sharedUsageFeatureMemory => 'Geheugen';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in gegevens delen telemetrie apparaten functies tools modellen activiteit';
}
