// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppL10nSv extends AppL10n {
  AppL10nSv([String locale = 'sv']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Välkommen';

  @override
  String get onboardingEyebrowCommunication => 'Kommunikation';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligens';

  @override
  String get onboardingEyebrowComputer => 'Dator';

  @override
  String get onboardingEyebrowAutomation => 'Automation';

  @override
  String get onboardingNext => 'Nästa';

  @override
  String get onboardingIntroCouldNotLoad => 'Det gick inte att ladda introt.';

  @override
  String get onboardingModelDescription =>
      'Välj den modell NeoAgent ska använda som standard, eller låt den välja automatiskt.';

  @override
  String get onboardingLoadingModels => 'Laddar modeller...';

  @override
  String get noAiModelTitle => 'Ingen AI-modell har konfigurerats ännu';

  @override
  String get noAiModelBody =>
      'Lägg till en API-nyckel från en leverantör som OpenAI, Anthropic eller Google. NeoAgent visar sedan vilka modeller du kan använda.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent behöver en AI-modell för att svara. Lägg till en API-nyckel från en leverantör som OpenAI, Anthropic eller Google.';

  @override
  String get noAiModelAdminHint =>
      'Som admin kan du även ställa in leverantörer för alla under Admin → Leverantörer.';

  @override
  String get addApiKey => 'Lägg till API-nyckel';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform är ansluten.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Väntar på att $platform ska ansluta...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Installationen kunde inte sparas: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Klar';

  @override
  String get onboardingStepRequired => 'Krävs';

  @override
  String get onboardingStepOptional => 'Valfritt';

  @override
  String get onboardingStepCloudOrLocal => 'Moln eller lokalt';

  @override
  String get onboardingStepComputer => 'Dator';

  @override
  String get onboardingStepRoutines => 'Rutiner';

  @override
  String get onboardingComputerChoiceTitle => 'Var ska det\nfungera?';

  @override
  String get onboardingComputerChoiceDescription => 'Du kan byta per session.';

  @override
  String get onboardingCloudComputerSubtitle => 'Privat sandlåda · alltid på';

  @override
  String get onboardingThisComputer => 'Den här datorn';

  @override
  String get onboardingThisComputerSubtitle =>
      'Dina filer, appar och webbläsare';

  @override
  String get onboardingSearchApps => 'Sök appar...';

  @override
  String get onboardingRoutinesDescription =>
      'Resultaten kommer i dina chattar.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Resultaten kommer som aviseringar.';

  @override
  String get onboardingNotifications => 'Aviseringar';

  @override
  String get onboardingReadyTitle => 'Allt är\nklart.';

  @override
  String get onboardingReadyDescription => 'Skicka ditt första meddelande.';

  @override
  String get onboardingMessageNeoagent => 'Meddelande NeoAgent';

  @override
  String get onboardingAskAnything => 'Fråga vad som helst...';

  @override
  String get onboardingOpenNeoagent => 'Öppna NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planera en weekendresa';

  @override
  String get onboardingStarterLanding => 'Bygg en målsida';

  @override
  String onboardingQuickSteps(int count) {
    return '$count snabba steg';
  }

  @override
  String get taskNeedsEmail => 'Anslut e-post först';

  @override
  String get taskNeedsCalendar => 'Anslut en kalender först';

  @override
  String get taskNeedsModel => 'Konfigurera en AI-modell först';

  @override
  String get taskPromptDailyRecap =>
      'Sammanfatta min dag: sammanfatta samtalen, det färdiga arbetet och besluten från idag, lista sedan allt jag borde följa upp imorgon. Håll det kort och skicka det till mig.';

  @override
  String get taskPromptInboxCheck =>
      'Kolla min e-postkorg efter meddelanden som kommit in sedan den senaste kontrollen. Skicka bara ett meddelande till mig om e-postmeddelanden som är brådskande eller behöver ett svar, med en sammanfattning på en rad vardera. Om inget behöver min uppmärksamhet, skicka inget.';

  @override
  String get taskPromptMorningBriefing =>
      'Förbered min morgonbriefing: dagens väder där jag är, händelserna i min kalender och de viktigaste öppna föremålen jag känner till. Skicka det som ett kort, skanningsbart meddelande.';

  @override
  String get taskPromptTomorrowPrep =>
      'Titta i min kalender för imorgon. För varje möte, berätta för mig vad det handlar om, vem som är inblandad och allt jag borde förbereda. Om morgondagen är tom, skicka inget.';

  @override
  String get taskPromptNewsDigest =>
      'Sök på webben efter dagens viktigaste nyheter om de ämnen jag bryr mig om (använd det du kommer ihåg om mina intressen). Skicka mig ett sammandrag av upp till fem objekt med en mening var och en länk.';

  @override
  String get taskPromptWeeklyReview =>
      'Se över min vecka: vad som blev gjort, vad som halkade och vad som fortfarande är öppet. Föreslå de tre viktigaste sakerna att fokusera på nästa vecka.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Länka ett telefonnummer som tillhör agenten. Alla du tillåter kan chatta med den, i direkta chattar och grupper.';

  @override
  String get whatsappSelfChatDescription =>
      'Länka ditt eget nummer och prata med agenten i chatten \"Meddela dig själv\". Alla andra chattar och grupper på detta konto ignoreras.';

  @override
  String get chatSendHintMac => '⌘↵ för att skicka';

  @override
  String get chatSendHintOther => 'Ctrl+Enter för att skicka';

  @override
  String get aBaseUrlIsRequiredFor => 'En bas-URL krävs för denna slutpunkt.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'En ändrad e-postadress bekräftas innan den används.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Ett beslut högre upp i kedjan vinner.';

  @override
  String get aDeletedAccount => 'ett raderat konto';

  @override
  String get aFridayLookBackAtThe =>
      'En fredagsblick tillbaka på veckan och en plan för nästa.';

  @override
  String get aKeyThatAsksForA =>
      'En nyckel som ber om en PIN-kod eller fingeravtryck ersätter också din tvåfaktorskod.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'En språkmodell bedömde detta meddelande eftersom SystemOne är avstängt.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'En NeoAgent-installationsmetadatafil överskred sin säkra storleksgräns.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'En nyare webbbyggnad finns tillgänglig på servern. Ladda om för att hämta det senaste paketet.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Ett privat skrivbord med Chromium, filer, en textredigerare, terminal och Python. Ditt arbete förblir sparat mellan sessionerna.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'En privat Linux-dator eller en Android-enhet.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'En nödvändig NeoAgent-installationsfil kunde inte laddas ned.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'En lagkamrat skickar en inbjudningslänk till dig. När du accepterar det, de ';

  @override
  String get aTeammateSentYouAnInvite =>
      'en lagkamrat skickade en inbjudningslänk till dig, skriv in den här för att gå med i deras team.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'En tillfällig nedladdning kommer att rensas upp senare.';

  @override
  String get aValueIsStored => 'Ett värde lagras.';

  @override
  String get access => 'Tillgång';

  @override
  String get accessActivity => 'Åtkomstaktivitet';

  @override
  String accessArg1(Object? arg1) {
    return 'Tillträde: $arg1';
  }

  @override
  String get accessMode => 'Åtkomstläge';

  @override
  String get accessPermissions => 'Åtkomstbehörigheter';

  @override
  String get accessToken => 'åtkomsttoken';

  @override
  String get accessToken2 => 'Tillgångstoken';

  @override
  String get account => 'Konto';

  @override
  String accountArg1(Object? arg1) {
    return 'Konto #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Aviseringar om kontoändringar';

  @override
  String get accountEmail => 'Kontots e-postadress';

  @override
  String get accountEmailIsOffUntilThese =>
      'Kontots e-postadress är avstängd tills dessa är inställda: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent använder detta språk överallt i appen. Första gången du loggar in följer den den här enheten. Därefter sparas valet på ditt konto och används på alla enheter.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Kunde inte ändra språket: $error';
  }

  @override
  String get accountLanguageTitle => 'Språk';

  @override
  String get accountNumber => 'Kontonummer';

  @override
  String get accountSettings => 'Kontoinställningar';

  @override
  String get accounts => 'Konton';

  @override
  String get accountsByTokensUsedAllTime =>
      'Konton med tokens som används, hela tiden.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'kontons molndatorer. Ändringar gäller efter en server ';

  @override
  String get accountsOnThisServer => 'Konton på denna server';

  @override
  String get active => 'Aktiv';

  @override
  String get activeSessions => 'Aktiva sessioner';

  @override
  String get activeToday => 'Aktiv idag';

  @override
  String get add => 'Lägg till';

  @override
  String get addAProviderCredentialFirstIts =>
      'Lägg till en leverantörsuppgifter först. Dess modeller dyker upp här en gång ';

  @override
  String get addAgent => 'Lägg till agent';

  @override
  String get addAnotherSignInMethodBefore =>
      'Lägg till en annan inloggningsmetod innan du tar bort den här.';

  @override
  String get addBinding => 'Lägg till bindning';

  @override
  String get addByNameOrId => 'Lägg till med namn eller ID';

  @override
  String get addByNameOrIdInstead => 'Lägg till med namn eller ID istället';

  @override
  String get addCredentialBinding => 'Lägg till autentiseringsbindning';

  @override
  String get addEntry => 'Lägg till post';

  @override
  String get addKey => 'Lägg till nyckel';

  @override
  String get addMcpServer => 'Lägg till MCP-server';

  @override
  String get addMemory => 'Lägg till minne';

  @override
  String get memoryReview => 'Granska';

  @override
  String get memoryReviewPrompt =>
      'Gå igenom alla mina minnen och städa upp: arkivera dubbletter, inaktuella fakta och allt utan bestående värde. Berätta sedan kort vad du ändrade.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Lägg till mer längd eller annan teckentyp.';

  @override
  String get addPeopleOrGroups => 'Lägg till personer eller grupper';

  @override
  String get addSecurityKey => 'Lägg till säkerhetsnyckel';

  @override
  String get addSomeoneOrAGroup => 'Lägg till någon eller en grupp';

  @override
  String get addTask => 'Lägg till uppgift';

  @override
  String get addTests => 'Lägg till tester';

  @override
  String get addTestsForThePartsOf =>
      'Lägg till tester för de delar av det här projektet som har minst täckning och kör dem sedan.';

  @override
  String get addTheirOwnKeysInSettings =>
      'lägga till sina egna nycklar i Inställningar.';

  @override
  String get addToPrompt => 'Lägg till i prompten';

  @override
  String get added => 'Tillagd';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Lade till $arg1 · Senast använda $arg2';
  }

  @override
  String get addressWithTheProvider => 'adress hos leverantören.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Justera högtalarvolymen, granska standardinställningarna för hårdvaruknappar och hantera den här startsessionen.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Justera sök- eller statusfiltret för att se fler meddelandekanaler.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Justera högtalarvolymen här.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Admin › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Administratörsbidrag, inbjudningslänkar och hanteringsändringar visas här.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Avancerat manuellt schema för specialfall.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avancerat: minut timme dag månad veckodag.';

  @override
  String get againRightAway => 'igen direkt.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Agenten ringer';

  @override
  String get agentCommunication => 'Agentkommunikation';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agentkommunikation: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agentläge redigerar arbetsytan · ⌘↵ skicka · ⌘N ny session';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agenten pausar och ber om ditt tillstånd innan den kör uppgiften.';

  @override
  String get agentProfile => 'Agent profil';

  @override
  String get agentVisibleName => 'Agent-synligt namn';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent vill använda $arg1. Tryck för att bestämma.';
  }

  @override
  String get agents => 'Agenter';

  @override
  String get aiAnswerUnreadable => 'AI-svar oläsligt';

  @override
  String get aiProviderKeys => 'AI-leverantörsnycklar';

  @override
  String get aiUnavailable => 'AI inte tillgänglig';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'varningar och annan konto-e-post från.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Varningar när en meddelandeanslutning behöver användarens uppmärksamhet';

  @override
  String get all => 'Alla';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Alla agenter ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Alla $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Alla molndatorplatser används för närvarande. Försök igen om ett ögonblick.';

  @override
  String get allComputerSlotsAreBusy => 'Alla datorplatser är upptagna';

  @override
  String get allTables => 'Alla bord';

  @override
  String get allTime => 'Hela tiden';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Alla verktyg är tillåtna - agenten kan använda vilken kapacitet som helst utan att fråga. ';

  @override
  String get allow => 'Tillåt';

  @override
  String get allowedRunsWithoutAsking => 'Tillåtet. Springer utan att fråga.';

  @override
  String get allowAll => 'Tillåt alla';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Tillåt \"Installera okända appar\" för NeoAgent och försök sedan att uppdatera igen.';

  @override
  String get allowOnce => 'Tillåt en gång';

  @override
  String get allowSender => 'Tillåt avsändare';

  @override
  String get allowSession => 'Tillåt session';

  @override
  String get allowTheAgentToStartAn =>
      'Tillåt agenten att starta ett röstsamtal i appen med dig.';

  @override
  String get allowedOrigins => 'Tillåtet ursprung';

  @override
  String get allowedPathPrefix => 'Tillåtet sökvägsprefix';

  @override
  String get allowsYouCanChangeThatPer =>
      'tillåter. Du kan ändra det per person senare. Länkar ger aldrig ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'tillhör redan ett befintligt konto';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'redan länkad till ett annat konto';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'redan länkad till ett annat neoagent-konto';

  @override
  String get alreadyUsed => 'redan använt';

  @override
  String get always => 'Alltid';

  @override
  String get alwaysAllow => 'Tillåt alltid';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Tillåt alltid\" sparar policyn permanent – du kan ändra den i Inställningar.';

  @override
  String get alwaysAsk => 'Fråga alltid';

  @override
  String get alwaysEngage => 'Engagera dig alltid';

  @override
  String get alwaysJoins => 'Går alltid med';

  @override
  String get anApiKeyIsRequired => 'En API-nyckel krävs.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'En kvällssammanfattning av vad som hände och vad man ska följa upp.';

  @override
  String get anHttpOrHttpsUrlIs => 'En http eller https URL krävs.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'och analyser. Laglänkar live på Team-sidan.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Android APK-installation är inte tillgänglig på den här plattformen.';

  @override
  String get androidApp => 'Android app';

  @override
  String get androidControl => 'Android kontroll';

  @override
  String get androidCouldNotStart => 'Android kunde inte starta';

  @override
  String get androidNotificationReceived => 'Android-avisering mottagen';

  @override
  String get androidOnly => 'Endast Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Installationsprogrammet för Android-paketet kunde inte öppnas.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android-skärm – tryck för att peka, dra för att svepa';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Svarar på @omnämnanden om problem och pull-förfrågningar';

  @override
  String get anyone => 'Vem som helst';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Vem som helst på den här plattformen kan skicka meddelanden till $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Vem som helst på den här plattformen kan skicka meddelanden till $arg1 i $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Alla som kan nå detta konto kan prata med $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Vem som helst med länken kan gå med tills den går ut eller du återkallar den.';

  @override
  String get apiHttpsOrigin => 'API HTTPS ursprung';

  @override
  String get apiKey => 'API-nyckel';

  @override
  String get apiKey2 => 'api-nyckel';

  @override
  String get apiKey3 => 'API-nyckel';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api nyckel antropisk claude openai gpt xai grok google gemini minimax nvidia nim openrouter referenser';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API-nycklar och slutpunkter för AI-, sök- och röstleverantörer. De ';

  @override
  String get apiRequest => 'API-begäran';

  @override
  String get apiYourOwnServerASelf =>
      'API -- din egen server, en självvärd modell eller någon annan ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK-nedladdning misslyckades med HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Appens namn krävs.';

  @override
  String get appUpdates => 'Appuppdateringar';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Appuppdateringar är inte konfigurerade för denna version.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Tillämpade $arg1 köade styruppdateringar för den aktuella körningen.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Tillämpade $arg1 styruppdatering(ar).';
  }

  @override
  String get apply => 'Ansök';

  @override
  String get applyBehaviorNotes => 'Applicera beteendeanteckningar';

  @override
  String get applyCoreMemory => 'Applicera kärnminne';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Godkännandeförfrågningar för känsliga agentverktyg';

  @override
  String get approvalRequired => 'Godkännande krävs';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Godkännandet förblir i din autentiserade mobilsession och varje kod upphör automatiskt efter ett kort fönster.';

  @override
  String get approveLogin => 'Godkänn inloggning';

  @override
  String get approveQrLogin => 'Godkänn QR-inloggning';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Godkänn detta endast om du startade inloggningen på den enheten nyss.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Godkänd inloggning för $arg1.';
  }

  @override
  String get approvedOnly => 'Endast godkänd';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Godkänd parning för $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Godkända personer och grupper';

  @override
  String get approvedPeopleOnly => 'Endast godkända personer';

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
  String get archiveSelectedMemories => 'Arkivera valda minnen?';

  @override
  String get areSharedByEveryAccountOn =>
      'delas av alla konton på denna server; konton kan fortfarande ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M ingång';
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
    return '$arg1-åtkomst behövs';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 konton';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktiv';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 har lagts till. Redigera den när som helst för att ändra ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '\"$arg1\" och dess körhistorik kommer att raderas permanent. Alla aktiva körningar stoppas. Filer i arbetsytan berörs inte.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return '$arg1 godkännande krävs';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 appar aktiva';
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
    return '$arg1 ($arg2 aktiva verktyg)';
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
    return '$arg1 $arg2 vid $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 har ändrats';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 tecken';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Skapad $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [lokal uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 matchar \"$arg3\"';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent arbetsyta';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 nya konton';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 körs · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 prover';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 styrning i kö';
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
    return '$arg1 blev administratör ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 byte';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanal';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 tecken';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 raderades.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfigurerad';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 ansluten. Välj arkiv och personer under Vem kan skicka meddelanden.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 kärnposter.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 skapade en inbjudningslänk';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 skrivbord';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 händelser';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 misslyckades';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 misslyckades';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 misslyckas';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 för $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 grupper endast taggade';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h sedan';
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
    return '$arg1 hjälpare';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 träffförhållande)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 är en administratör, så kontot kan inte raderas ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 är blockerad på $arg2. Uppdatera åtkomstlistan för att tillåta svar.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 är ansluten och svarar.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 är inte längre en administratör ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 är inte tillgängligt på $arg2 (saknar körtidsbehörighet eller beroende).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 gick med under $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 bedömd av LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1-nyckel$arg2 konfigurerad';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1-nyckeln har tagits bort.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 kvar';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 vänster $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 länkad';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m sedan';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Se till att den körs och försök sedan igen.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 hanterar detta konto';
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
    return '$arg1-modeller redo';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 mer';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 fler steg i körhistorik';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 flyttade från $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 måste vara ett ändligt tal.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 måste vara en http://- eller https://-adress.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 behöver uppmärksamhet';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent arbetsyta';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nya konton i den senaste $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nya meddelanden styr denna körning';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nya körningar';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 hanterar nu detta konto.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 av 4 behörigheter tillåtna. Filer är begränsade till din NeoAgent Workspace-mapp.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2 aktiverad';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2-grupper går med i vanlig chatt';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2-modeller';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2-modeller redo';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2 set';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2-verktyg tillåtna';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 på dagen $arg2 på $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 svarar endast de personer du lägger till nedan.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 svarar bara när taggad';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 pratar bara med personer och grupper som du godkänner';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 personer eller grupper har lagts till';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 planering';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1-leverantörer';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 redo';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 rekord';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 omdirigerings-URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registrerad';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 svarade';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 återkallade en inbjudningslänk';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 körs';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 körs · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 körs i den senaste $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 sparad.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 valt';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 visas';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 förblev tyst';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 styrning $arg2 i kö';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · tryck på en nod för att inspektera';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 steg';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 slutade hantera $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 tokens';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1-tokens i den senaste $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 verktyg';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (inte tillgänglig sparad åsidosättning)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1 % använd · $arg2 återstår';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 vill prata med dig.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 webb';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" kommer att tas bort permanent.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 kommer att hantera detta konto';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 kommer inte att svara på den här plattformen';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 kommer inte att svara på $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Artefaktlagring av användare';

  @override
  String get askAQuestionOrStartA =>
      'Ställ en fråga eller påbörja en uppgift...';

  @override
  String get askBeforeClosingToBackground =>
      'Fråga innan du stänger till bakgrunden';

  @override
  String get askMe => 'Fråga mig';

  @override
  String get assignedAgent => 'Tilldelad agent';

  @override
  String get assignedAgent2 => 'Tilldelad agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Tilldelad agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Tilldelad (valfritt)';

  @override
  String get assistant => 'Assistent';

  @override
  String get assistantKey131 => 'Assistentnyckel 131';

  @override
  String get atLeast1 => 'Minst 1.';

  @override
  String get attachFiles => 'Bifoga filer';

  @override
  String attentionArg1(Object? arg1) {
    return 'Observera $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'granskningslogg admin bevilja återkalla inbjudningsteamhistorik';

  @override
  String get authMethod => 'Auth-metod';

  @override
  String get authServerUrl => 'Auth Server URL';

  @override
  String get authentication => 'Autentisering';

  @override
  String get authenticationFailed => 'Autentiseringen misslyckades.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Autentisering väntar fortfarande. Avsluta webbläsarflödet och försök igen.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Autentisering väntar fortfarande. Avsluta webbläsarflödet och uppdatera.';

  @override
  String get authenticationTimedOut => 'Autentiseringen tog slut.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentiseringen avbröts innan den slutfördes.';

  @override
  String get authenticatorApp => 'Autentiseringsapp';

  @override
  String get authenticatorCode => 'Autentiseringskod';

  @override
  String get authorOptional => 'Författare (valfritt)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (första leverantören med en API-nyckel)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Auto-rutter till den bästa tillgängliga modellen';

  @override
  String get automaticFast => 'Automatisk (snabb)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatisk läser av rummet och håller normalt igen. Mention-only gör inget beslutssamtal förrän det är direkt adresserat.';

  @override
  String get automaticReserved => 'Automatisk, reserverad';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatisk återställning kräver ett nytt försök från inställningsskärmen.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatic väljer en snabb modell genom den normala modellkatalogen.';

  @override
  String get automation => 'Automation';

  @override
  String get available => 'Tillgänglig';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Återigen tillgänglig i $arg1';
  }

  @override
  String get availableAgainShortly => 'Tillgänglig snart igen';

  @override
  String get availableInTheDesktopAppFor =>
      'Tillgänglig i skrivbordsappen för macOS, Windows och Linux';

  @override
  String get availableToTheAgent => 'Tillgänglig för agenten';

  @override
  String get averageAllTime => 'Genomsnittligt, hela tiden';

  @override
  String get avgImp => 'Genomsnittlig visn.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Genomsnittlig/körd: $arg1 tokens';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Undvik upprepade tecken och uppenbara sekvenser.';

  @override
  String get awaitingScan => 'Väntar på skanning';

  @override
  String get back => 'Tillbaka';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count i bakgrunden';
  }

  @override
  String get backgroundTasks => 'Bakgrundsuppgifter';

  @override
  String get backOn => 'tillbaka på.';

  @override
  String get backToChat => 'Tillbaka till chatten';

  @override
  String get backToFolder => 'Tillbaka till mappen';

  @override
  String get backToSignIn => 'Tillbaka för att logga in';

  @override
  String get backendChannel => 'Backend-kanal';

  @override
  String get backendOnThisComputer => 'Backend på den här datorn';

  @override
  String get backendSync => 'Backend-synkronisering';

  @override
  String get backgroundLocationNeeded => 'Bakgrundsplats behövs';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Bakgrundssynkronisering förblir schemalagd på Android';

  @override
  String get badState => 'Dåligt tillstånd: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Basbild och storlek på de virtuella QEMU-maskinerna som körs ';

  @override
  String get baseUrlOptional => 'Bas-URL (valfritt)';

  @override
  String get baseUrlTokenLocal => 'bas-url-token lokal';

  @override
  String get basicAuthentication => 'Grundläggande autentisering';

  @override
  String get behaviorModules => 'Beteendemoduler';

  @override
  String get behaviorNotes => 'beteendeanteckningar';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden legitimationsmäklare';

  @override
  String get bitwardenItem => 'Bitwarden objekt';

  @override
  String get bitwardenServer => 'Bitwarden-server';

  @override
  String get blankUsesCommon => 'Blank använder \"vanligt\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank använder standardåteruppringning';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Tomma värden använder leverantörens standardvärden.';

  @override
  String get block => 'Block';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Blockerat inkommande meddelande från $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubbles-kompatibel bro';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles server URL';

  @override
  String get botToken => 'Bot-token';

  @override
  String get botTokenAndApprovedChats => 'Bot-token och godkända chattar';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bottoken och server/kanalåtkomst';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bottoken, Events API och kanalåtkomst';

  @override
  String get botUserId => 'Bot användar-ID';

  @override
  String get botUsername => 'Bot användarnamn';

  @override
  String get brandName => 'Varumärke';

  @override
  String get braveSearch => 'Modig sökning';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Överbrygga alla leverantörer som kan lägga upp och ta emot webhook-nyttolaster.';

  @override
  String get bringYourOwnKey => 'ta med egen nyckel';

  @override
  String get bringYourOwnKey2 => 'Ta med egen nyckel';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Webbläsare, Linux-skrivbord, filer, terminal och Python delar en ihållande molndator.';

  @override
  String get browserLogin => 'Webbläsarinloggning';

  @override
  String get browserScripting => 'Webbläsarskript';

  @override
  String get call => 'Ring';

  @override
  String get callAgent => 'Ring agenten';

  @override
  String get callUser => 'Ring användare';

  @override
  String get calledByName => 'Kallas vid namn';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Kan delegera uppgifter till andra agenter';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Kan delegera till $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Kan ta emot delegerade uppgifter';

  @override
  String get cancel => 'Avbryt';

  @override
  String get cancelTask => 'Avbryt uppgift';

  @override
  String get cannotPreview => 'Kan inte förhandsgranska';

  @override
  String get cannotReceiveDelegatedTasks =>
      'kan inte ta emot delegerade uppgifter';

  @override
  String get cannotRunYet => 'kan inte köra ännu.';

  @override
  String get capturedThePage => 'Fångade sidan';

  @override
  String get category => 'Kategori';

  @override
  String chainArg1(Object? arg1) {
    return 'Kedja: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Ändra inställningsläge';

  @override
  String get channel => 'Kanal';

  @override
  String get channelAccessToken => 'Kanalåtkomsttoken';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Uppdateringsversion: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Socialt minne med kanalomfattning';

  @override
  String get channels => 'Kanaler';

  @override
  String get chat => 'Chatta';

  @override
  String get chatId => 'Chatt-ID';

  @override
  String get chatMode => 'Chattläge';

  @override
  String get chatModel => 'Chattmodell';

  @override
  String get checkAutomaticallyOnLaunch => 'Kontrollera automatiskt vid start';

  @override
  String get checkForMessagesEveryMs => 'Sök efter meddelanden varje (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Sök efter nya meddelanden automatiskt';

  @override
  String get checkNow => 'Kolla nu';

  @override
  String get checkYourEmailToConfirmYour =>
      'Kontrollera din e-post för att bekräfta ditt NeoAgent-konto innan du loggar in.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Kollade $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Välj en kategori eller sök i alla inställningar.';

  @override
  String get chooseAPerson => 'Välj en person';

  @override
  String get chooseAProjectFolder => 'Välj en projektmapp';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Välj standardinställningar för chatt, agenter, reservbeteende och smart routing.';

  @override
  String get chooseGroups => 'Välj grupper';

  @override
  String get chooseHowMuchYouWantTo =>
      'Välj hur mycket du vill konfigurera nu. Båda alternativen kan ändras senare.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Välj hur denna uppgift ska starta. Manuell körs endast på Kör nu. Schema är tidsbaserat. Integration utlöser brand från anslutna officiella appar.';

  @override
  String get chooseOneToGetStartedNow =>
      'Välj en för att komma igång nu. Du kan lägga till mer senare.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Välj livemodell och röst i Inställningar.';

  @override
  String get chooseTheirGroup => 'Välj deras grupp';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Välj var den här personen ska få prata med $arg1. Du kan ändra detta senare under Vem kan meddelande.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Välj vilka grupper $arg1 ska gå med även när ingen taggar den. Denna plattform kanske inte skiljer taggar från vanliga meddelanden.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Välj vilka modeller varje konto på denna server kan välja och ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Välj vem $arg1 pratar med och när den går med i gruppchattar.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Välj vem som kan nå $arg1 och spara sedan dina ändringar.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Välj vem som får skicka meddelanden till agenten med \"Vem kan skicka meddelanden\" på WhatsApp-kortet.';

  @override
  String get chooseYourDefaultModel => 'Välj din\nstandardmodell.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, filer, textredigeraren och terminalen är alla tillgängliga från Linux-skrivbordet.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Rensa';

  @override
  String get clearAll => 'Rensa alla';

  @override
  String clearArg1(Object? arg1) {
    return 'Rensa $arg1?';
  }

  @override
  String get clearFilter => 'Rensa filter';

  @override
  String get clearFilters => 'Rensa filter';

  @override
  String get clearSearch => 'Rensa sökning';

  @override
  String get clearView => 'Fri sikt';

  @override
  String get cliSession => 'CLI session';

  @override
  String get clickIsNotSupportedOnThis =>
      'click stöds inte på den här plattformen.';

  @override
  String get clickOnceToBeginCapturing => 'Klicka en gång för att börja fånga';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klicka, skriv och interagera med skrivbordsappar.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Klickade på ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Klickade i webbläsaren';

  @override
  String get clientId => 'Klient-ID';

  @override
  String get clientSecret => 'Klienthemlighet';

  @override
  String get close => 'Stäng';

  @override
  String get closeJ => 'Stäng (⌘J)';

  @override
  String get closeTeachMode => 'Stäng Teach Mode';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Om du stänger fönstret kan du antingen hålla NeoAgent igång i bakgrunden med åtkomst till fack, eller helt avsluta skrivbordskörningen.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Moln och självvärdade instanser stöds. Lokala och privata nätverksadresser fungerar när NeoAgent kan nå dem.';

  @override
  String get cloudComputer => 'Moln dator';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Molndator · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Molndatorinställningarna sparade. Starta om servern för att tillämpa dem.';

  @override
  String get cloudComputerVm => 'Molndator (VM)';

  @override
  String get cloudComputers => 'Molndatorer';

  @override
  String get codeHosting => 'Kodvärd';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Kommaseparerade kanalnamn, utan #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Kommaseparerade, till exempel #allmänt, #hjälp';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Komma separerad. Frågan måste ha dem alla.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kommandot misslyckades ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Kommando krävs.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Kommandoutgångsackumulatorn är inte aktiv.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Uppladdning av kommandoutgång misslyckades ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Kommandoutgångsuppladdning utelämnad artefaktmetadata.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Kommandoutmatningen var redan klar.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Kommandon och appar';

  @override
  String get commandsRunInTheSamePersistent =>
      'Kommandon körs i samma beständiga dator som används av det synliga skrivbordet.';

  @override
  String get communityChatops => 'Community & ChatOps';

  @override
  String get completeSetup => 'Slutför installationen';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Slutför arbetsflödet på skrivbordet.';

  @override
  String get completed => 'Avslutad';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Helt blockerad — agenten kan inte använda denna kategori.';

  @override
  String get computerShell => 'Datorskal';

  @override
  String get computerUsedByThisSession => 'Dator som används av denna session';

  @override
  String get computerWorkspace => 'Dator arbetsyta';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurerbar personlig webhook-brygga';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurerbar relä eller webhook bridge';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigurerbar Talk webhook bridge';

  @override
  String get configurableWebInboxBridge => 'Konfigurerbar webbinkorgsbrygga';

  @override
  String get configurableWebhookBridge => 'Konfigurerbar webhook bridge';

  @override
  String get configurableWebhooks => 'Konfigurerbara Webhooks';

  @override
  String get configurationOrInTheEnvFile => 'Konfiguration eller i .env-filen.';

  @override
  String get configure => 'Konfigurera';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigurera arbetsytans beteende och modellstandarder.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfigurerad $arg1';
  }

  @override
  String get confirmEmailChanges => 'Bekräfta e-poständringar';

  @override
  String get confirmNewSignUps => 'Bekräfta nya registreringar';

  @override
  String get confirmPassword => 'Bekräfta lösenord';

  @override
  String get confirmPassword2 => 'Bekräfta lösenord';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Bekräfta din e-post innan du loggar in. Kontrollera tjänstens e-postmeddelande från NeoAgent.';

  @override
  String get connect => 'Anslut';

  @override
  String get connectAMessagingPlatform => 'Anslut en\nmeddelandeplattform.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Anslut en offentlig HTTPS Home Assistant-slutpunkt med en Long-Lived Access Token. Lokala, loopback- och privata nätverksadresser blockeras av servern.';

  @override
  String get connectAccount => 'Anslut konto';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Anslut appkonton individuellt så att AI kan använda rätt konto för varje officiell integration.';

  @override
  String connectArg1(Object? arg1) {
    return 'Anslut $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Anslut så många konton du vill. Varje app kan använda ett annat konto.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Anslut kanaler, välj vem $arg1 pratar med och titta på senaste aktivitet.';
  }

  @override
  String get connectInstance => 'Anslut instans';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Anslut denna integration först för att välja ett konto.';

  @override
  String get connectToThisServer => 'Anslut till denna server';

  @override
  String get connectWhatsapp => 'Anslut WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Anslut din Nextcloud-instans, inklusive egna servrar. NeoAgent öppnar Nextclouds egen inloggningssida så att du kan logga in med lösenord, SSO eller 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Anslut din egen värd NeoRecall-server. NeoAgent får skrivskyddad åtkomst till lokal sökning, minnen och avskriftsbevis efter att du har godkänt OAuth-skärmen.';

  @override
  String get connected => 'Ansluten';

  @override
  String get connectedAccount => 'Anslutet konto';

  @override
  String connectedArg1(Object? arg1) {
    return 'Ansluten $arg1';
  }

  @override
  String get connectedInstance => 'Ansluten instans';

  @override
  String get connectedNeorecallUser => 'Ansluten NeoRecall-användare';

  @override
  String get connectedNextcloudUser => 'Ansluten Nextcloud-användare';

  @override
  String get connectedServer => 'Ansluten server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Ansluter till liveröstmodellen...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Anslutning #$arg1';
  }

  @override
  String get connectionId => 'Anslutnings-ID';

  @override
  String get connectionLooksGood => 'Anslutningen ser bra ut.';

  @override
  String get connectionMethod => 'Anslutningsmetod';

  @override
  String get containsTextOptional => 'Innehåller text (valfritt)';

  @override
  String get content => 'Innehåll';

  @override
  String get contentSecurityPolicy => 'innehållssäkerhetspolicy';

  @override
  String get continue2 => 'Fortsätt';

  @override
  String get continueFullSetup => 'Fortsätt med hela installationen';

  @override
  String get continueRun => 'Fortsätt springa';

  @override
  String get continueToSetup => 'Fortsätt till installationen';

  @override
  String get controlSurface => 'KONTROLLYTA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Styr åtkomst till $arg1-verktyg.';
  }

  @override
  String get conversation => 'Konversation';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Konversations-ID används när den här agenten startar en chatt.';

  @override
  String get cookieSetup => 'Cookie-inställning';

  @override
  String get cookiesNotConfigured => 'Cookies inte konfigurerade';

  @override
  String get copiedAsCsv => 'Kopierat som CSV';

  @override
  String get copiedDebugInfo => 'Kopierade felsökningsinformation';

  @override
  String get copiedExportForTheLast5 =>
      'Kopierad export för de senaste 5 meddelandena';

  @override
  String get copiedFullPrompt => 'Kopierade hela uppmaningen';

  @override
  String get copiedLogs => 'Kopierade loggar';

  @override
  String get copiedRunId => 'Kopierade körnings-ID';

  @override
  String get copy => 'Kopiera';

  @override
  String get copyAll => 'Kopiera alla';

  @override
  String get copyCodes => 'Kopiera koder';

  @override
  String get copyCsv => 'Kopiera CSV';

  @override
  String get copyDebugInfo => 'Kopiera felsökningsinformation';

  @override
  String get copyLink => 'Kopiera länk';

  @override
  String get copyLogs => 'Kopiera loggar';

  @override
  String get copyPrompt => 'Kopiera uppmaning';

  @override
  String get copyResponse => 'Kopiera svar';

  @override
  String get copyRunId => 'Kopiera kör-ID';

  @override
  String get copyWebhookUrl => 'Kopiera webhook-URL';

  @override
  String get core => 'Kärna';

  @override
  String get coreMemory => 'kärnminne';

  @override
  String get coreServicesThisServerDependsOn =>
      'Kärntjänster som denna server beror på.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domän https offentliga url ursprung';

  @override
  String get couldHelp => 'Skulle kunna hjälpa';

  @override
  String get couldNotApproveQrLogin => 'Kunde inte godkänna QR-inloggning.';

  @override
  String get couldNotApproveQrPairing => 'Kunde inte godkänna QR-koppling.';

  @override
  String get couldNotConnect => 'Kunde inte ansluta.';

  @override
  String get couldNotCreateBinding => 'Det gick inte att skapa bindning.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Kunde inte ta bort ditt konto: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Kunde inte koppla bort Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Det gick inte att koppla bort Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall => 'Kunde inte koppla från NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'Kunde inte koppla från Nextcloud.';

  @override
  String get couldNotDisconnectTrello =>
      'Det gick inte att koppla från Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Kunde inte exportera dina data: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Det gick inte att ladda beslut';

  @override
  String get couldNotLoadUsageData =>
      'Det gick inte att läsa in användningsdata.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Kunde inte öppna Linux-inställningarna automatiskt.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Det gick inte att öppna leverantörens länksida.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Det gick inte att öppna leverantörens inloggningssida.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Det gick inte att öppna releasetillgången.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Det gick inte att öppna Trello i din webbläsare.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Det gick inte att öppna nedladdningen av arbetsytefilen.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Det gick inte att läsa Android-apppaketet.';

  @override
  String get couldNotReadTheApk => 'Det gick inte att läsa APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Kunde inte ta bort nyckel: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Det gick inte att spara agenten.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Det gick inte att spara Bitwarden-installationen.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Det gick inte att spara Home Assistant-konfigurationen.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Det gick inte att spara NeoRecall-installationen.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Det gick inte att spara Nextcloud-installationen.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Det gick inte att spara Trello-installationen.';

  @override
  String get couldNotSendConfirmationEmail =>
      'kunde inte skicka bekräftelsemail';

  @override
  String get couldNotStart => 'Kunde inte starta';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Skapa';

  @override
  String get createAPasswordFirstToChange =>
      'Skapa ett lösenord först för att ändra ditt kontos e-postadress.';

  @override
  String get createAPasswordOrLinkAnother =>
      'skapa ett lösenord eller länka till en annan leverantör innan du tar bort den här inloggningsmetoden';

  @override
  String get createATaskWhileThisAgent =>
      'Skapa en uppgift medan denna agent är vald.';

  @override
  String get createLink => 'Skapa länk';

  @override
  String get createOrModifyFilesInYour =>
      'Skapa eller ändra filer i din arbetsyta.';

  @override
  String get createPassword => 'Skapa lösenord';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Skapa specialistrobotar med separata minne, inställningar, verktyg och kontotilldelningar.';

  @override
  String get createTheFirstAccount => 'Skapa det första kontot';

  @override
  String get createUpdateOrDeleteSkills =>
      'Skapa, uppdatera eller ta bort färdigheter.';

  @override
  String get creatingYourSkill => 'Skapar din färdighet...';

  @override
  String get credentialBindings => 'Behörighetsbindningar';

  @override
  String get credentialUse => 'Användning av legitimation';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron-baserade återkommande körningar och engångsutförande.';

  @override
  String get cronExpression => 'Cron uttryck';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter kör frågan.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Mellanslag';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Aktuell e-post: $arg1';
  }

  @override
  String get currentPassword => 'Aktuellt lösenord';

  @override
  String get currentPasswordIsIncorrect => 'nuvarande lösenord är felaktigt';

  @override
  String get currentTwoStepLoginCode => 'Aktuell tvåstegs inloggningskod';

  @override
  String get customAccess => 'Anpassad åtkomst';

  @override
  String get customCron => 'Anpassad Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron måste ha 5 fält.';

  @override
  String get customEndpoint => 'anpassad slutpunkt';

  @override
  String get customField => 'Anpassat fält';

  @override
  String get customHeader => 'Anpassad rubrik';

  @override
  String get customHeadersJson => 'Anpassade rubriker (JSON)';

  @override
  String get customOpenaiCompatible => 'Anpassad OpenAI-kompatibel';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Anpassad OpenAI-kompatibel slutpunkt';

  @override
  String get customOutgoingUrl => 'Anpassad utgående URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Dagligen';

  @override
  String get dailyRecap => 'Daglig sammanfattning';

  @override
  String get databaseQuerySelectCsvTemplates => 'databasfråga välj csv-mallar';

  @override
  String dayArg1(Object? arg1) {
    return 'Dag $arg1';
  }

  @override
  String get dayOfMonth => 'Dag i månaden';

  @override
  String get decideWhichToolsYourAgentMay =>
      'bestäm vilka verktyg din agent kan använda. De ser ditt namn och ';

  @override
  String get decisionHigherUpTheChainWins =>
      'beslut högre upp vinner kedjan och visar ett lås med ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Beslut visas här när $arg1 läser godkända $arg2-grupper. Endast de senaste 30 behålls och de återställs när servern startar om.';
  }

  @override
  String get decline => 'Avböja';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'djuplöpning · steg $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram-nyckel';

  @override
  String get default2 => 'Standard';

  @override
  String get default3 => 'STANDARD';

  @override
  String defaultArg1(Object? arg1) {
    return 'Standard ($arg1)';
  }

  @override
  String get defaultConversation => 'Standardkonversation';

  @override
  String get defaultForNewGroups => 'Standard för nya grupper';

  @override
  String get defaultGroupParticipation => 'Standardgruppdeltagande';

  @override
  String get defaultNeoagentWorkspace => 'Standard arbetsyta för NeoAgent';

  @override
  String get defaultOpenai => 'Standard (OpenAI)';

  @override
  String get defaultRateLimits => 'Standardhastighetsgränser';

  @override
  String get defaultRateLimitsSaved => 'Standardhastighetsgränser sparade.';

  @override
  String get defaultRecommended => 'Standard (rekommenderas)';

  @override
  String get defaultRouting => 'Standardrouting';

  @override
  String get defaultSpace => 'Standardutrymme';

  @override
  String get delete => 'Ta bort';

  @override
  String get deleteAccount => 'Ta bort konto';

  @override
  String get deleteAccountPermanently => 'Ta bort konto permanent?';

  @override
  String get deleteAnAccount => 'Ta bort ett konto';

  @override
  String deleteArg1(Object? arg1) {
    return 'Ta bort @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Ta bort ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Ta bort $arg1 $arg2 permanent?';
  }

  @override
  String get deleteBinding => 'Ta bort bindning';

  @override
  String get deleteCoreMemoryEntry => 'Ta bort kärnminnespost?';

  @override
  String get deleteForever => 'Ta bort för alltid';

  @override
  String get deleteMcpServer => 'Ta bort MCP-server?';

  @override
  String get deleteMemory => 'Radera minne?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Ta bort raderar permanent ett konto och alla dess data ';

  @override
  String get deleteRun => 'Ta bort körning?';

  @override
  String get deleteRun2 => 'Ta bort körning';

  @override
  String get deleteSelectedMemories => 'Radera valda minnen?';

  @override
  String get deleteSession => 'Ta bort session?';

  @override
  String get deleteSkill => 'Ta bort färdighet?';

  @override
  String get deleteTask => 'Ta bort uppgift?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Raderade \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Raderade @$arg1 och alla deras data.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Radering tar bort alla dina konversationer, minnen, filer, uppgifter och ';

  @override
  String get deliverableArtifactProduced => 'Leveransbar artefakt producerad';

  @override
  String get deliverableCompleted => 'Leverans färdig';

  @override
  String get deliverableExecutionStarted => 'Levererbart utförande startade';

  @override
  String get deliverableSelected => 'Leverans vald';

  @override
  String get deliverableValidationFailed =>
      'Validering av leveransen misslyckades';

  @override
  String get deliverableValidationStarted => 'Leveransvalidering har påbörjats';

  @override
  String get deny => 'Förneka';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Beskriv resultatet och demonstrera det sedan på skrivbordet';

  @override
  String get describeWhatToBuildOrChange =>
      'Beskriv vad du ska bygga eller ändra...';

  @override
  String get description => 'Beskrivning';

  @override
  String get desktopApp => 'Skrivbordsapp';

  @override
  String get desktopAppControlsAvailable =>
      'Skrivbordsappkontroller tillgängliga';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Skrivbordsinspelning är inte tillgänglig på den här plattformen.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Uppladdning av skrivbordskommandot avbröts.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Skrivbordskommandot avbröts.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Skrivbordsföljande anslutning tog timeout.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Timeout för handskakning för datorkompanjon.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Desktop companion är inte tillgänglig här.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Skrivbordskompanjonen är pausad lokalt.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Hantering av kompletterande meddelanden på skrivbordet misslyckades: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Behörighetsinställningar för datorkompanjoner är inte tillgängliga på webben.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Behörighetsinställningar för skrivbordsföljare är inte tillgängliga på den här plattformen.';

  @override
  String get desktopCompanionRejected => 'Skrivbordskompanjon avvisades.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Skrivbordsföljande svar misslyckades: $arg1';
  }

  @override
  String get desktopControl => 'Skrivbordskontroll';

  @override
  String get desktopFailedToStart => 'Det gick inte att starta skrivbordet';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Skrivbordsströmavläsning misslyckades: $arg1';
  }

  @override
  String get destinationId => 'Destinations-ID';

  @override
  String get deviceAccess => 'Enhetsåtkomst';

  @override
  String get deviceSettings => 'Enhetsinställningar';

  @override
  String get devices => 'Enheter';

  @override
  String get diagnosticsSaved => 'Diagnostiken har sparats.';

  @override
  String get directBluebubblesImessageBridge =>
      'Direkt BlueBubbles iMessage-brygga';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Direktmeddelanden förblir responsiva. Tillåtna grupper använder deltagandeläget nedan.';

  @override
  String get directoryDoesNotExist => 'Katalog finns inte.';

  @override
  String get disable2fa => 'Inaktivera 2FA';

  @override
  String get disableAll => 'Inaktivera alla';

  @override
  String get discard => 'Släng';

  @override
  String get disconnect => 'Koppla från';

  @override
  String get disconnectHomeAssistant => 'Koppla bort Home Assistant?';

  @override
  String get disconnectNeorecall => 'Koppla bort NeoRecall?';

  @override
  String get disconnectNextcloud => 'Koppla bort Nextcloud?';

  @override
  String get disconnectPlatform => 'Koppla bort plattformen';

  @override
  String get disconnectTrello => 'Koppla bort Trello?';

  @override
  String get discoveryFailed => 'Upptäckten misslyckades';

  @override
  String get dismiss => 'Avvisa';

  @override
  String get displayIdIsRequired => 'Visnings-ID krävs.';

  @override
  String get displayName => 'Visningsnamn';

  @override
  String get displayNameMustBe64Characters =>
      'Visningsnamnet måste vara 64 tecken eller färre.';

  @override
  String get displayNameSaved => 'Visningsnamnet har sparats.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Inkludera inte ditt användarnamn eller e-postadress.';

  @override
  String get done => 'Klart';

  @override
  String get downloadACopyOfYourData =>
      'Ladda ner en kopia av dina uppgifter. Det går inte att radera administratörskonton ';

  @override
  String get downloadACopyOfYourData2 =>
      'Ladda ner en kopia av dina uppgifter eller ta bort ditt konto permanent. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Ladda ner $arg1';
  }

  @override
  String get downloadUpdate => 'Ladda ner uppdatering';

  @override
  String get downloadingTheNeoagentBackend => 'Laddar ner NeoAgent-backend';

  @override
  String get draft => 'Utkast';

  @override
  String get dragIsNotSupportedOnThis =>
      'drag stöds inte på den här plattformen.';

  @override
  String get draggedOnTheScreen => 'Dras på skärmen';

  @override
  String get dropAnApkOrApkBundle =>
      'Släpp ett APK- eller APK-paket här för att installera det';

  @override
  String get dropApkOrApksHere => 'Släpp APK eller .apks här';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Hållbara instruktioner för röst och interaktionsstil. Säkerhet och utföranderegler har fortfarande prioritet.';

  @override
  String get eGAlexSLaptop => 'till exempel Alexs bärbara dator';

  @override
  String get eGMyLocalServer => 't.ex. Min lokala server';

  @override
  String get edit => 'Redigera';

  @override
  String get editAgent => 'Redigera agent';

  @override
  String get editCoreMemoryEntry => 'Redigera Core Memory Entry';

  @override
  String get editInstructions => 'Redigera instruktioner';

  @override
  String get editMcpServer => 'Redigera MCP-server';

  @override
  String get editTask => 'Redigera uppgift';

  @override
  String editedArg1(Object? arg1) {
    return 'Redigerat $arg1';
  }

  @override
  String get email => 'E-post';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-postkontoägare om inloggningar som ser ovanliga ut.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'E-postkontoägare när deras kontouppgifter ändras.';

  @override
  String get emailCode => 'E-postkod';

  @override
  String get emailConfirmationRequired => 'e-postbekräftelse krävs';

  @override
  String get emailIsAlreadyInUse => 'e-post används redan';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-post har sparats. Om bekräftelse krävs, kontrollera den nya adressen för en NeoAgent-bekräftelselänk.';

  @override
  String get emailSettingsSaved => 'E-postinställningar sparade.';

  @override
  String get emailUnverified => 'E-post ej verifierad';

  @override
  String get empty => 'Tom';

  @override
  String get emptyFile => 'Tom fil';

  @override
  String get emptyFolder => 'Tom mapp';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty använder serverns standardvärde ($arg1).';
  }

  @override
  String get enable2fa => 'Aktivera 2FA';

  @override
  String get enableAll => 'Aktivera alla';

  @override
  String get enableBehaviorModules => 'Aktivera beteendemoduler';

  @override
  String get enableOrDisableModels => 'Aktivera eller inaktivera modeller';

  @override
  String get enabled => 'Aktiverad';

  @override
  String get encryptedPrivateToYourAccount =>
      'Krypterad, privat för ditt konto';

  @override
  String get end => 'Slut';

  @override
  String get endCall => 'Avsluta samtalet';

  @override
  String get endVoiceCall => 'Vill du avsluta röstsamtal?';

  @override
  String get endpoint => 'Slutpunkt';

  @override
  String get enterAPassword => 'Ange ett lösenord.';

  @override
  String get enterAUsername => 'Ange ett användarnamn.';

  @override
  String get enterAValidEmailAddress => 'Ange en giltig e-postadress.';

  @override
  String get enterAnAddressManually => 'Ange en adress manuellt';

  @override
  String get enterAnApiKeyFirst => 'Ange en API-nyckel först.';

  @override
  String get enterInviteLink => 'Ange inbjudningslänk';

  @override
  String get enterTheAddressOfANeoagent =>
      'Ange adressen till en NeoAgent-server.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Ange informationen $arg1 gav dig så att $arg2 kan skicka och ta emot meddelanden.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Ange din 2FA- eller återställningskod.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Ange ditt nuvarande lösenord för att ändra det.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Ange ditt nuvarande lösenord för att spara e-poständringar.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Ange dina NeoAgent-kontouppgifter.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Ange ditt användarnamn eller kontots e-postadress. NeoAgent skickar en återställningslänk om den kan matcha kontot.';

  @override
  String get enterYourUsernameOrEmail =>
      'Ange ditt användarnamn eller e-postadress.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entitet: $arg1';
  }

  @override
  String get environment => 'Miljö';

  @override
  String get error => 'Fel';

  @override
  String errorArg1(Object? arg1) {
    return '\nfel: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Fel från den senaste loggen, grupperade efter meddelande.';

  @override
  String get errorsProblemsFailures => 'fel problem misslyckanden';

  @override
  String get eventTypesCommaSeparated => 'Händelsetyper (kommaseparerade)';

  @override
  String get every15Minutes => 'Var 15:e minut';

  @override
  String get every30Minutes => 'Var 30:e minut';

  @override
  String get everyAccountOnThisServerLoses =>
      'Varje konto på den här servern förlorar denna delade nyckel. konton ';

  @override
  String get everyAccountOnThisServerUses =>
      'Varje konto på denna server använder denna adress för ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Varje aktiv session för detta konto avslutas. De kan logga in ';

  @override
  String get everyDay0800 => 'Varje dag · 08:00';

  @override
  String get everyDay2000 => 'Varje dag · 20:00';

  @override
  String get everyHour => 'Varje timme';

  @override
  String get everyRunOnThisServerAll =>
      'Varje körning på den här servern, hela tiden.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Varje känsligt verktyg kräver godkännande, varje gång.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Varje verktyg går utan att fråga, förutom de som personen ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Alla i dessa grupper, kanaler eller rum kan prata med $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Alla i denna grupp';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Allt som $arg1 stängt av för din agent kommer ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Allt annat är avstängt.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Allt är tillgängligt från skrivbordet.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Allt som agenten kan använda: officiella integrationer, MCP-servrar och färdigheter.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Allt du stängde av för $arg1 kommer tillbaka ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Exakta webbursprung som tillåts göra förfrågningar över gränserna, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Kör JavaScript i din webbläsarsession.';

  @override
  String get execution => 'Utförande';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Exekveringsdetaljer är inte tillgängliga för denna körning.';

  @override
  String get executionPlanCreated => 'Utförandeplan skapad.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Träna $arg1-pass';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[avsluta $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Upphör att gälla $arg1';
  }

  @override
  String get explainThisProject => 'Förklara detta projekt';

  @override
  String exploredArg1(Object? arg1) {
    return 'Utforskade $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Utforskade $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Utforskade arbetsytan';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Export misslyckades: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exportera de senaste 5 meddelandena';

  @override
  String get exportMyData => 'Exportera mina data';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Extern webbläsarstart misslyckades med utgångskoden $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Extern webbläsarstart stöds inte på den här plattformen.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Tidsgränsen för start av extern webbläsare.';

  @override
  String get externalMcpTools => 'Externa & MCP-verktyg';

  @override
  String get extraButtons => 'Extra knappar';

  @override
  String get extractingTheNeoagentRuntime => 'Extraherar NeoAgent-körtiden';

  @override
  String get failed => 'Misslyckades';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Det gick inte att ansluta: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Det gick inte att ansluta $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Det gick inte att ta bort \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'misslyckades med att hämta';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Det gick inte att generera prompt: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Det gick inte att starta extern webbläsare via url_launcher.';

  @override
  String get failedToLaunchOauthFlow =>
      'Det gick inte att starta OAuth-flödet.';

  @override
  String get failedToLoadPolicies => 'Det gick inte att läsa in policyer';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Det gick inte att spara: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Det gick inte att spara MCP-servern.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Det gick inte att spara val: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Det gick inte att skicka meddelande till backend: $arg1';
  }

  @override
  String get fair => 'Rättvist';

  @override
  String get fasterReplies => 'Snabbare svar';

  @override
  String get fewerModelCalls => 'Färre modellsamtal';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'fältet är tomt för att återställa den inbyggda standardinställningen.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Filen överskrider redigeringsgränsen på 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Filen överskrider storleksgränsen som stöds.';

  @override
  String get fileWrites => 'Fil skriver';

  @override
  String get filename => 'Filnamn';

  @override
  String get files => 'Filer';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Filer som NeoAgent skriver eller redigerar i den här sessionen visas här.';

  @override
  String get filesSavedByAllUsers => 'Filer sparade av alla användare';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Fyll i godkända inloggningar eller autentisera förfrågningar utan att visa hemligheter för AI.';

  @override
  String get finalResponse => 'Slutligt svar';

  @override
  String get findAPlatform => 'Hitta en plattform';

  @override
  String get findAndFixABug => 'Hitta och fixa en bugg';

  @override
  String get findRecentChats => 'Hitta senaste chattar';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Att hitta rätt NeoAgent-körtid';

  @override
  String get finish => 'Avsluta';

  @override
  String get finishAtTheScheduledTime => 'Avsluta på utsatt tid';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Slutför inloggningen på $arg1 i din webbläsare och anslut sedan igen.';
  }

  @override
  String get flowGraph => 'Flödesdiagram';

  @override
  String get flutterApp => 'Flutter-appen';

  @override
  String get focusedExecutionProfile => 'Fokuserad utförandeprofil';

  @override
  String get folderIdOptional => 'Mapp-ID (valfritt)';

  @override
  String get folderUnavailable => 'Mappen är inte tillgänglig';

  @override
  String get forExampleHttpsMatrixOrg => 'Till exempel https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'För värdbaserade eller avancerade nätverksinställningar';

  @override
  String get forLinksInEmailsBlankUses =>
      'För länkar i mejl. Blank använder serverns offentliga URL.';

  @override
  String get forgotPassword => 'Glömt lösenordet?';

  @override
  String get frameUnavailable => 'Ramen är inte tillgänglig';

  @override
  String freshnessArg1(Object? arg1) {
    return 'färskhet: $arg1';
  }

  @override
  String get fridays1700 => 'Fredagar · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Från BotFather efter att du skapat boten.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Från och med nu bestämmer $arg1 vilka verktyg din agent får använda. De ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Från Discord Developer Portal, under din bot.';

  @override
  String get fromTheLineDevelopersConsole => 'Från LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Från Matrix-klienten eller botkontot.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Från twitchapps.com/tmi eller din Twitch-utvecklarapp.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Full uppmaning';

  @override
  String get fullSetup => 'Fullständig installation';

  @override
  String get general => 'Allmänt';

  @override
  String get generalSettings => 'Allmänna inställningar';

  @override
  String get generalSettingsSaved => 'Allmänna inställningar sparade.';

  @override
  String get generateAPromptForAnotherAi =>
      'Generera en prompt för en annan AI, klistra in svaret här för att importera minnen.';

  @override
  String get generatePrompt => 'Generera prompt';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geofence-spårningsfel: $arg1';
  }

  @override
  String get getInspired => 'Låt dig inspireras';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot och OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHub ärendet öppnat';

  @override
  String get neorecallMemoryCreated => 'NeoRecall-minne skapat';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Utgivningskontrollen av GitHub misslyckades med HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'GitHub release nyttolast var inte en release lista.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub användarnamn som öppnade problemet';

  @override
  String get globalSecurityMode => 'Globalt säkerhetsläge';

  @override
  String get gmailMessageReceived => 'Gmail-meddelande mottaget';

  @override
  String get good => 'Bra';

  @override
  String get goodAfternoon => 'God eftermiddag';

  @override
  String get goodEvening => 'God kväll';

  @override
  String get goodMorning => 'God morgon';

  @override
  String get goodPasswordALittleMoreLength =>
      'Bra lösenord. Lite mer längd gör den starkare.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live använder din OpenAI API-nyckel, Gemini Live din Google AI-nyckel. Ändringar gäller för nästa samtal.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Ge Health Connect-behörigheter innan synkronisering.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupp, kanal eller rum';

  @override
  String get groupType => 'Grupptyp';

  @override
  String get groupsAndChannels => 'Grupper och kanaler';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupper: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupper $arg1 inte har sett än kommer att följa detta.';
  }

  @override
  String get handlesDirectTasksItself => 'Hanterar direkta uppgifter själv';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Handsfree (prata fritt, avbryt när som helst)';

  @override
  String get headerName => 'Rubrikens namn';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Rubriker om de ämnen du bryr dig om, filtrerade efter signal.';

  @override
  String get health => 'Hälsa';

  @override
  String get healthChecks => 'Hälsokontroller';

  @override
  String get healthConnect => 'hälsa koppla';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect är inte tillgängligt på den här enheten.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health Connect-synkroniseringsstatus och lagrad backend-statistik.';

  @override
  String get healthStatusIsUnavailable => 'Hälsostatus är inte tillgänglig.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Hälsosynkronisering är endast tillgänglig på Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Heart $arg1 rekord';
  }

  @override
  String get heldBack => 'Höll tillbaka';

  @override
  String get helper => 'Hjälpare';

  @override
  String helperArg1(Object? arg1) {
    return 'Hjälpare: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'här. Återkalla admin med \'neoagent admin återkalla $arg1\' först.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Högre värden gör NeoAgent mer selektiv i grupper.';

  @override
  String get highlyRecommended => 'Rekommenderas varmt';

  @override
  String get holdButton131ForTheAssistant =>
      'Håll ned knappen 131 för assistenten.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Håll ned Ctrl+Skift+Mellanslag för att prata';

  @override
  String get holdToTalk => 'Håll för att prata.';

  @override
  String get holdToTalk2 => 'Håll för att prata';

  @override
  String get home => 'Hem';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Home Assistant Long-Lived Access Token krävs.';

  @override
  String get homeAssistantSetup => 'Home Assistant Setup';

  @override
  String get homeAssistantUrl => 'Home Assistant URL';

  @override
  String get homeAssistantUrlIsRequired => 'Home Assistant URL krävs.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Hemserver-token med rumsundersökning';

  @override
  String get homeserverUrl => 'Hemserverns URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'värdtjänst). Dina nycklar är krypterade och kan endast användas av ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Värdnamn för IRC-nätverket, till exempel irc.libera.chat';

  @override
  String get hourly => 'Varje timme';

  @override
  String get hourlyInboxCheck => 'Inkorgskontroll varje timme';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Hur länge bekräftelselänkar är giltiga.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Hur ofta den här agenten letar efter nya rumsmeddelanden.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Hur ofta den här agenten letar efter nya signalmeddelanden.';

  @override
  String get howTeamsWork => 'Hur team fungerar';

  @override
  String get howThisServerIsReachedPlus =>
      'Hur denna server nås, plus serveromfattande switchar.';

  @override
  String get httpsSessionCookie => 'https session cookie';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Jag kunde inte slutföra den begäran just nu. Försök igen om ett ögonblick.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inaktiv';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Om $arg1 ber om en webhook-URL, klistra in denna så att meddelanden kan nå $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Om kontot har en bekräftad e-post kommer NeoAgent att skicka en länk för återställning av lösenord.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Om tjänsten kräver en token vid utgående förfrågningar.';

  @override
  String get ignoreGroups => 'Ignorera grupper';

  @override
  String get ignoreThisChat => 'Ignorera den här chatten';

  @override
  String get ignoredChannels => 'Ignorerade kanaler';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ignorerat missformat skrivbordsföljande meddelande: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implementera planen ovan.';

  @override
  String get implementThisPlan => 'Genomför denna plan';

  @override
  String get implicitTls => 'Implicit TLS';

  @override
  String get import => 'Importera';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import misslyckades: $arg1';
  }

  @override
  String get importFromComputer => 'Importera från datorn';

  @override
  String get importMemoryTransfer => 'Importera minnesöverföring?';

  @override
  String get importance => 'Betydelse';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importerade $arg1-minnen, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'I @${arg1}s team';
  }

  @override
  String get inBackground => 'bakgrund';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Inkommande och utgående kanalmeddelanden visas här.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Inkommande röstsamtal i appen från NeoAgent';

  @override
  String get incomingMessages => 'Inkommande meddelanden';

  @override
  String get incomingNeoagentCall => 'Inkommande NeoAgent-samtal';

  @override
  String get incomingNeoagentCall2 => 'INKOMMANDE NEOAGENTSAMTAL';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Support för inkommande webhook och utgående återuppringning';

  @override
  String get incorporatingSteering => 'Inbyggd styrning';

  @override
  String get input => 'Ingång';

  @override
  String get inputMode => 'Inmatningsläge';

  @override
  String get insertATemplate => 'Infoga en mall';

  @override
  String get install => 'Installera';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installera en signerad, fristående runtime. Node.js, npm, Git och terminalkommandon krävs inte.';

  @override
  String get installApk => 'Installera APK';

  @override
  String get installApkBundle => 'Installera APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Installera APK — klicka eller släpp en .apk-fil';

  @override
  String get installNeoagent => 'Installera NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installera NeoAgent på den här datorn utan terminal, eller anslut till en som redan körs.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installera nya versioner och välj vilken kanal den här servern följer.';

  @override
  String get installTheBackend => 'Installera backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installera kärnan med extra valfri inställning. AI-leverantörsnycklar läggs till efteråt, samma som snabbstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installera den säkra kärnan och skapa sedan ditt konto. Lägg till AI-leverantörsnycklar efteråt.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Installerad: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Installerad: $arg1 • Senast kontrollerad: $arg2';
  }

  @override
  String get instructions => 'Instruktioner';

  @override
  String get integration => 'Integration';

  @override
  String get integrationConnections => 'Integrationsanslutningar';

  @override
  String get integrationSettingsSaved => 'Integrationsinställningarna sparade.';

  @override
  String get integrations => 'Integrationer';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrationer/oauth/återuppringning, och registrera detsamma ';

  @override
  String get interruptAi => 'Avbryt AI';

  @override
  String get invalid2fa => 'ogiltig 2fa';

  @override
  String get invalidArgumentS => 'Ogiltigt argument: ';

  @override
  String get invalidCredentials => 'ogiltiga autentiseringsuppgifter';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Ogiltigt NeoAgent-körtidsmanifest.';

  @override
  String get inviteLink => 'Inbjudningslänk';

  @override
  String get inviteLinkReady => 'Inbjudningslänken är klar';

  @override
  String get inviteLinks => 'Bjud in länkar';

  @override
  String get iphoneApp => 'iPhone app';

  @override
  String get issues => 'frågor';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Problem dyker upp när loggen laddas.';

  @override
  String get itCanTBeUndone => 'Det går inte att ångra.';

  @override
  String get itMayHaveBeenDeleted => 'Det kan ha tagits bort.';

  @override
  String get javaRuntime => 'java körtid';

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
    return 'Gick med i $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Har gått med under de senaste 7 dagarna';

  @override
  String get joiningATeam => 'Gå med i ett team';

  @override
  String get joiningIsOffHere => 'Det går inte att gå med här';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON-fält som innehåller meddelandetexten. Vanligtvis text.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON-fält som identifierar vem meddelandet är till.';

  @override
  String get jumpToLatest => 'Hoppa till senaste';

  @override
  String get justNow => 'just nu';

  @override
  String get keepNeoagentRunning => 'Hålla NeoAgent igång?';

  @override
  String get keepRunning => 'Fortsätt springa';

  @override
  String get keepTaskRunning => 'Fortsätt köra uppgiften';

  @override
  String get keepTheVaultAvailable => 'Håll valvet tillgängligt';

  @override
  String get keepThisLauncherUpToDate => 'Håll startprogrammet uppdaterat.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Håll denna panel öppen tills plattformen bekräftar anslutningen.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Håll den här sessionens dator synlig';

  @override
  String get keepTrackOfYourAiUsage =>
      'Håll koll på din AI-användning. Begränsningar tillämpas för att säkerställa rättvis användning över hela plattformen.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Fortsätt använda dina appar normalt. NeoAgent fungerar på samma skärm och frågar när den behöver ny åtkomst.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Håller den här enheten ansluten';

  @override
  String get key => 'Nyckel';

  @override
  String get keyIsRequired => 'Nyckel krävs.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Nyckel-värde-par som består över konversationer.';

  @override
  String get knowledgeGraph => 'Kunskapsdiagram';

  @override
  String get knowledgeView => 'Kunskapsvy';

  @override
  String get labelOnlyYouSeeIt => 'Etikett (bara du ser den)';

  @override
  String get labelsOptional => 'Etiketter (valfritt)';

  @override
  String get last24Hours => 'Senaste 24 timmarna';

  @override
  String get last7Days => 'Senaste 7 dagarna';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Senaste 7 dagarna: $arg1-tokens i $arg2-körningar';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Senaste $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Senaste: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Senaste icke-tom synkronisering · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Senaste körningen: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Senast sett $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Senaste inloggningen $arg1';
  }

  @override
  String get lastSyncSummary => 'Sammanfattning av senaste synkronisering';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Senast använd: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Senaste fönstret avslutades $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'senare start avstängd också.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Senaste körningen · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Starta skrivbordsappar stöds inte på den här plattformen.';

  @override
  String get learnRoomNorms => 'Lär dig rumsnormer';

  @override
  String get leave => 'Lämna';

  @override
  String get leaveARedirectUriBlankTo =>
      'Lämna en omdirigerings-URI tom för att använda <public URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Lämna ${arg1}s team?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Lämna som standard om du inte har anpassat BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Lämna token tom för att behålla den för närvarande lagrade token.';

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
    return 'Låt $arg1 hantera mig';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Låt alla i den här gruppen prata med $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Låt det fungera medan\ndu inte gör det.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Låt NeoAgent klicka, skriva och gå igenom dina appar.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Låt NeoAgent förstå vad som syns på din skärm.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Låt någon du arbetar med bestämma vilka verktyg din agent får ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Låt den här personen skicka ett en-till-en-meddelande till $arg1.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Låt den här personen prata med $arg1 här, men inte i privata chattar eller andra grupper.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Låt den här personen prata med $arg1 i privata chattar och i vilken grupp de delar.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Nivå $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Länk $arg1';
  }

  @override
  String get linkCopied => 'Länken har kopierats';

  @override
  String get linkExpiresAfter => 'Länken upphör efter';

  @override
  String get linkLifetimeHours => 'Länkens livslängd (timmar)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Länkens livslängd måste vara från 1 till 8760 timmar.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Länk giltig till $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Länkade inloggningsleverantörer';

  @override
  String get linuxApp => 'Linux app';

  @override
  String listedArg1(Object? arg1) {
    return 'Listad $arg1/';
  }

  @override
  String get listening => 'Lyssnar';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Live exekveringshistorik, verktygssteg och svar.';

  @override
  String get liveModel => 'Levande modell';

  @override
  String get liveModelProvider => 'Leverantör av livemodeller';

  @override
  String get liveRun => 'Live kör';

  @override
  String get liveVoice => 'Levande röst';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Live röstanslutning är inte tillgänglig.';

  @override
  String get liveVoiceConnectionWasClosed => 'Live röstanslutning stängdes.';

  @override
  String get liveVoiceDefaults => 'Live röst standardinställningar';

  @override
  String get liveVoiceFailed => 'Live röst misslyckades.';

  @override
  String get llmMemoryExportResponse => 'LLM-minnesexportsvar';

  @override
  String get loadFailed => 'laddningen misslyckades';

  @override
  String get loadingExecutionDetails => 'Laddar exekveringsdetaljer...';

  @override
  String get loadingNeoagent => 'Laddar NeoAgent';

  @override
  String get loadingRunFlow => 'Laddar körflöde...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokala och privata nätverksadresser stöds när NeoAgent-servern kan nå dem. Ljud utsätts aldrig för NeoAgent.';

  @override
  String get localApp => 'lokal app';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokal backend-installation är inte tillgänglig på den här plattformen.';

  @override
  String get localBaseImagePath => 'Lokal basbildsökväg';

  @override
  String get localComputerControlIsAvailableIn =>
      'Lokal datorstyrning är tillgänglig i NeoAgent-skrivbordsappen på macOS, Windows och Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokal datorstyrning är inte tillgänglig här.';

  @override
  String get localModelsUrl => 'lokala modeller url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokal NeoAgent-upptäckt är inte tillgänglig för tillfället.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokala preferenser för NeoAgent-applikationen. Datorkontroll körs alltid genom den enhetliga molndatorn.';

  @override
  String get localSetup => 'LOKAL INSTÄLLNING';

  @override
  String get locationCityOrPlace => 'Plats (stad eller plats)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Plats krävs för utlösare av väderhändelser';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'LocationService-initiering misslyckades: $arg1';
  }

  @override
  String get logCopied => 'Loggen kopierad';

  @override
  String get loginPassword => 'Inloggningslösenord';

  @override
  String get logout => 'Logga ut';

  @override
  String get logs => 'Loggar';

  @override
  String get logsCopied => 'Loggar kopierade.';

  @override
  String get logsOnThisComputer => 'Loggar på den här datorn';

  @override
  String get longLivedAccessToken => 'Långlivad åtkomsttoken';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Långsiktigt återkallande, strukturerad fakta och kunskapsgraf.';

  @override
  String get lookedAtTheScreen => 'Tittade på skärmen';

  @override
  String get lookingOnThisComputerAndYour =>
      'Tittar på den här datorn och ditt lokala nätverk...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Ser framåt på morgondagens möten så inget förvånar dig.';

  @override
  String get loopExecution => 'Slingutförande';

  @override
  String get loopPaused => 'Slingan pausad';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS-tillgänglighet beviljas inte NeoAgent. Tillåt det i Systeminställningar › Sekretess och säkerhet › Tillgänglighet.';

  @override
  String get macosApp => 'macOS-appen';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'macOS-skärminspelning beviljas inte för NeoAgent. Tillåt det i Systeminställningar › Sekretess och säkerhet › Skärminspelning och öppna sedan NeoAgent igen.';

  @override
  String get mailServersThatNeedAPassword =>
      'E-postservrar som behöver ett lösenord kommer att vägra skicka förrän ett nytt ';

  @override
  String get main => 'Main';

  @override
  String get makeDefault => 'Gör som standard';

  @override
  String get manage => 'Hantera';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Hantera ditt kontos e-post, tvåfaktorsautentisering och aktiva sessioner.';

  @override
  String get managedBy => 'Hanteras av';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Chefer kan ha egna chefer (upp till fyra nivåer). A ';

  @override
  String get managing => 'Hantera';

  @override
  String get manualDestination => 'Manuell destination';

  @override
  String get manualTrigger => 'Manuell avtryckare';

  @override
  String get masterPassword => 'Huvudlösenord';

  @override
  String get matchThisDevice => 'Matcha den här enheten';

  @override
  String get matchedAgainstTitleAndBody => 'Matchade mot titel och kropp';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Matchar det gamla NeoAgent MCP-flödet: URL plus auth-metoden.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP-server';

  @override
  String get mcpServer2 => 'MCP-server';

  @override
  String get mcpServerUrl => 'MCP Server URL';

  @override
  String get mcpServers => 'MCP-servrar';

  @override
  String get meantForSomeoneElse => 'Menad för någon annan';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Uppmätt modellkostnad: $arg1';
  }

  @override
  String get memories => 'Minnen';

  @override
  String get memory => 'Minne';

  @override
  String memoryArg1(Object? arg1) {
    return 'Minne: $arg1';
  }

  @override
  String get memoryInjected => 'Minnet injiceras';

  @override
  String get mentionOrReplyOnly => 'Nämn eller svara endast';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Sammanslagna server- och Flutter-körtidsloggar för den här appsessionen.';

  @override
  String get messageBodyTemplateJson => 'Mall för meddelandetext (JSON)';

  @override
  String get messageNeedsAccess => 'Meddelandet behöver åtkomst';

  @override
  String get messageTextField => 'Meddelandetextfält';

  @override
  String get messaging => 'Meddelanden';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging API push- och webhook-händelser';

  @override
  String get messagingConnectionNeedsAttention =>
      'Meddelandeanslutning behöver uppmärksamhet';

  @override
  String get messagingConnections => 'Meddelandeanslutningar';

  @override
  String get messagingDelivery => 'Meddelanden leverans';

  @override
  String get messagingErrorPleaseTryAgain => 'Meddelandefel. Försök igen.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Mikrofoninspelningen avbröts oväntat. Försök igen.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofonfel: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon avstängd. Tryck för att slå på ljudet.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Mikrofontillstånd krävs för liveröst.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minsta bidragsvärde: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobilinstallationen misslyckades.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobilinstallationen misslyckades eftersom Java inte är tillgängligt på maskinen som kör NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobilinstallationen misslyckades eftersom Java inte är tillgängligt på maskinen som kör NeoAgent. Installera en JDK och försök igen.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobilinstallationen misslyckades. Kontrollera att Android-verktygen är korrekt installerade och försök igen.';

  @override
  String modeArg1(Object? arg1) {
    return 'läge: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Läget låses medan en löpning är aktiv.';

  @override
  String get model => 'Modell';

  @override
  String modelArg1(Object? arg1) {
    return 'Modell: $arg1';
  }

  @override
  String get modelAvailability => 'Modelltillgänglighet';

  @override
  String get modelAvailabilitySaved => 'Modelltillgänglighet sparad.';

  @override
  String get modelForThisSession => 'Modell för denna session';

  @override
  String get modelOverride => 'Åsidosätt modell';

  @override
  String get modelPending => 'Modell väntar';

  @override
  String get modelTurn => 'Modellsvarv';

  @override
  String get modelTurnCompleted => 'Modellvändning avslutad';

  @override
  String get modelTurnStarted => 'Modellvändningen startade';

  @override
  String get modelVisibilityHideShowList => 'modell synlighet dölj visa lista';

  @override
  String get models => 'Modeller';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modeller, beteende, röst och arbetsyta';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modeller, webbläsare, röst, diagnostik...';

  @override
  String get modelsRouting => 'Modeller & routing';

  @override
  String get monthly => 'Månadsvis';

  @override
  String get moreActions => 'Fler åtgärder';

  @override
  String get morningBriefing => 'Briefing på morgonen';

  @override
  String get mostUsedAgents => 'Mest använda medel';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Mest använda modellerna i den senaste $arg1.';
  }

  @override
  String get mouseKeyboard => 'Mus & tangentbord';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove stöds inte på den här plattformen.';

  @override
  String get mustBeReachableOnThePublic =>
      'Måste vara tillgänglig på det offentliga internet - lokalt och ';

  @override
  String get n24Hours => '24 timmar';

  @override
  String get n2faOrRecoveryCode => '2FA eller återställningskod';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA kräver att SESSION_SECRET konfigureras på den här NeoAgent-distributionen.';

  @override
  String get n30Days => '30 dagar';

  @override
  String get n365Days => '365 dagar';

  @override
  String get n4HourLimitTokens => '4-timmarsgräns (tokens)';

  @override
  String get n4HourUsage => '4 timmars användning';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h gräns $arg1';
  }

  @override
  String get n7DayUsage => '7 dagars användning';

  @override
  String get n7Days => '7 dagar';

  @override
  String get n90Days => '90 dagar';

  @override
  String get name => 'Namn';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnamn: New Skill\nbeskrivning: Beskriv vad denna färdighet gör\n---\nSkriv instruktionerna för denna färdighet här.\n';

  @override
  String get nameOfWhoeverMadeIt => 'namnet på den som gjort den.';

  @override
  String get nameOptional => 'Namn (valfritt)';

  @override
  String get nativeAndWebhookChannels => 'Native och webhook-kanaler';

  @override
  String get naturalBubbles => 'Naturliga bubblor';

  @override
  String get nearbyNeoagentServers => 'Närliggande NeoAgent-servrar';

  @override
  String get needANewAccountRegister =>
      'Behöver du ett nytt konto? Registrera dig';

  @override
  String get needAnIdea => 'Behöver du en idé?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Behöver svara · $arg1% för att tala';
  }

  @override
  String get needsAttention => 'Behöver uppmärksamhet';

  @override
  String get needsInput => 'Behöver input';

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
      'NeoAgent kunde inte kontrollera den tillgängliga backend-körtiden.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent kunde inte slutföra den lokala installationen.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent kunde inte slutföra den lokala installationen. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent felsökningsinformation';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installerar den senaste $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent är installerat och körs.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent är inte installerat på den här datorn.';

  @override
  String get neoagentIsReady => 'NeoAgent är redo';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent arbetar fortfarande med en uppgift. Avsluta samtalet och få resultatet i chatten, eller avbryt uppgiften också.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent förvandlar din demonstration till ett anpassningsbart arbetsflöde.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent väntar medan du använder skrivbordet.';

  @override
  String get neoagentIsWorking => 'NeoAgent fungerar';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux-dator';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT BEHÖVER ETT BESLUT';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'NeoAgent runtime-nedladdningar kräver en säker adress.';

  @override
  String get neoagentServerAddress => 'NeoAgent-serveradress';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgent-tjänstens e-post är inte redo. Be serveroperatören kontrollera inställningarna för e-postmiljön.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'NeoAgent-installationen kunde inte slutföras.';

  @override
  String get neoagentUser => 'NeoAgent-användare';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent använder den här datorn automatiskt och frågar innan den använder din skärm, mus, tangentbord, filer eller kommandorad.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent använder din ungefärliga bakgrundsplats för att utlösa geofence-påminnelser (t.ex. \"Påminn mig om att köpa mjölk när jag går förbi stormarknaden\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent arbetsyta';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stack] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall Backend URL';

  @override
  String get neorecallBackendUrlIsRequired => 'NeoRecall backend-URL krävs.';

  @override
  String get neorecallSetup => 'NeoRecall-inställning';

  @override
  String get networkRequestFailed => 'nätverksbegäran misslyckades';

  @override
  String get networkWriteRequests => 'Nätverksskrivförfrågningar';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'räknas aldrig mot gränserna för delad användning.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Nya konton bekräftar sin e-postadress innan de loggar in.';

  @override
  String get newAccountsPerDay => 'Nya konton per dag';

  @override
  String get newChat => 'Ny chatt';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nya grupper förblir tysta om inte någon taggar $arg1, tills du slår på dem.';
  }

  @override
  String get newLink => 'Ny länk';

  @override
  String get newPasswordsDoNotMatch => 'Nya lösenord matchar inte.';

  @override
  String get newRecoveryCodes => 'Nya återställningskoder';

  @override
  String get newSession => 'Ny session';

  @override
  String get newSessionN => 'Ny session (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Ny session med samma setup';

  @override
  String get newSkill => 'Ny färdighet';

  @override
  String get newSkill2 => 'Ny färdighet';

  @override
  String get newThisWeek => 'Nytt denna vecka';

  @override
  String get newsDigest => 'Nyhetssammanfattning';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Nästa försök igen: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud-inloggningsflöde';

  @override
  String get nextcloudSetup => 'Nextcloud-installation';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloud URL krävs.';

  @override
  String get nickname => 'Smeknamn';

  @override
  String get noAccountsConnectedYet => 'Inga konton anslutna än.';

  @override
  String get noAccountsFound => 'Inga konton hittades.';

  @override
  String get noActiveSessionsFound => 'Inga aktiva sessioner hittades.';

  @override
  String get noAgentsYet => 'Inga agenter än';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Ingen AI-leverantör är konfigurerad, så chatta och skicka meddelanden ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Inga godkännandemeddelanden – agenten körs utan avbrott.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Ingen $arg1 releasetillgång matchade den här plattformen.';
  }

  @override
  String get noArguments => '(inga argument)';

  @override
  String get noAuth => 'Ingen autentisering';

  @override
  String get noBindingsYet => 'Inga bindningar ännu.';

  @override
  String get noChangesYet => 'Inga ändringar ännu';

  @override
  String get noChannelsFound => 'Inga kanaler hittades';

  @override
  String get noCloudComputerSlotIsFree =>
      'Ingen molndatorslot är ledig just nu. Försök igen om ett ögonblick.';

  @override
  String get noCoreMemoryEntriesYet => 'Inga kärnminnesposter än.';

  @override
  String get noDescription => 'Ingen beskrivning';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Inga skrivbordsskärmar är tillgängliga för närvarande.';

  @override
  String get noDetailAvailable => 'Ingen detalj tillgänglig';

  @override
  String get noDetailedSyncSummaryYet =>
      'Ingen detaljerad synkroniseringsöversikt ännu.';

  @override
  String get noDetailsCaptured => 'Inga detaljer fångas.';

  @override
  String get noEmailLinked => 'Ingen e-post länkad';

  @override
  String get noExternalSignInProvidersLinked =>
      'Inga externa inloggningsleverantörer länkade.';

  @override
  String get noGroupMessagesYet => 'Inga gruppmeddelanden än';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Inga gruppspecifika personer har lagts till ännu.';

  @override
  String get noGroupsAddedYet => 'Inga grupper har lagts till ännu.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Inga grupper hittades ännu. När $arg1 ser ett gruppmeddelande använder du Hitta senaste chattar så kommer de att dyka upp här.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Inga grupper hittades ännu. När $arg1 ser ett gruppmeddelande använder du Hitta senaste chattar.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Ingen hälsodatanyttolast returnerades.';

  @override
  String get noHealthSamplesStoredYet => 'Inga hälsoprover lagrade än.';

  @override
  String get noHttpClientImplementationForThis =>
      'Ingen HTTP-klientimplementering för den här plattformen.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Ingen ingång eller utgång registrerades för detta steg.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Inga integrationer matchar denna sökning.';

  @override
  String get noLimit => 'Ingen gräns';

  @override
  String get noLocalPasswordIsSetYet =>
      'Inget lokalt lösenord är inställt ännu. Skapa en för att aktivera användarnamn/lösenordsinloggning.';

  @override
  String get noLogEntries => 'Inga loggposter.';

  @override
  String get noMatchingSettings => 'Inga matchande inställningar';

  @override
  String get noMcpServersMatchThisSearch =>
      'Inga MCP-servrar matchar denna sökning.';

  @override
  String get noMemoryEntriesFound => 'Inga minnesposter hittades.';

  @override
  String get noMemorySync => 'Ingen minnessynkronisering';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Läser en gång igenom viktiga och skickade mejl från de senaste 12 månaderna så att agenten känner till dina kontakter och projekt.';

  @override
  String get emailMemory => 'E-postminne';

  @override
  String get importNow => 'Importera nu';

  @override
  String get importOnConnect => 'Importera tidigare mejl när ett konto ansluts';

  @override
  String get sweepStarting => 'Förbereder…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Läser mejl · $done av $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Läser mejl · $count hittade';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Lär sig av mejl · $done av $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Senaste import: $emails mejl · $memories nya minnen';
  }

  @override
  String get sweepNothingNew => 'Inga nya mejl att importera';

  @override
  String sweepFailed(String error) {
    return 'Importen misslyckades: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Ingen modell matchar \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Ingen modellbegäran registrerades för denna körning.';

  @override
  String get noModelsDiscoveredYet => 'Inga modeller har upptäckts ännu';

  @override
  String get noModelsSelected => 'Inga modeller har valts';

  @override
  String get noModelsYet => 'Inga modeller än';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'inget neoagent-konto är länkat till denna leverantör';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Ingen NeoAgent backend-körtid är tillgänglig för den här datorn.';

  @override
  String get noNetworkConnection => 'Ingen nätverksanslutning';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Ingen nätverksanslutning. Anslut för att fortsätta använda NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Ingen nätverksanslutning. Återanslut för att söka efter uppdateringar.';

  @override
  String get noOne => 'Ingen';

  @override
  String get noOneAddedYet => 'Ingen har lagts till ännu.';

  @override
  String get noOneCanMessage => 'Ingen kan skicka meddelanden';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Ingen annan NeoAgent-server hittades. Du kan söka igen eller ange en adress manuellt.';

  @override
  String get noPeopleAddedYet => 'Inga personer har lagts till ännu.';

  @override
  String get noPlatformsMatch => 'Inga plattformar matchar';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Inga leverantörer är tillgängliga att konfigurera ännu.';

  @override
  String get noRecentChannelActivity => 'Ingen ny kanalaktivitet';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Inga resultat för \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Inga körningar i detta intervall.';

  @override
  String get noRunsMatchTheseFilters => 'Inga körningar matchar dessa filter';

  @override
  String get noRunsYet => 'Inga löpningar än';

  @override
  String get noRunsYet2 => 'Inga löpningar än.';

  @override
  String get noSecurityKeyWasProvided =>
      'Ingen säkerhetsnyckel tillhandahölls.';

  @override
  String get noServerUrlSet => 'Ingen server-URL inställd';

  @override
  String get noSessionMatchesThatSearch =>
      'Ingen session matchar den sökningen.';

  @override
  String get noSessionsYet => 'Inga sessioner än';

  @override
  String get noSkillsMatchTheseFilters =>
      'Inga färdigheter matchar dessa filter.';

  @override
  String get noStepsWereRecordedForThis =>
      'Inga steg registrerades för denna körning.';

  @override
  String get noSummaryAvailable => 'Ingen sammanfattning tillgänglig.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Inga uppgifter för $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Inget verktyg matchar \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Ingen uppdatering körs';

  @override
  String get noUsageYet => 'Ingen användning ännu.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Ingen verifierad NeoAgent backend-körtid är tillgänglig ännu.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Ingen kan använda den längre. Folk som redan gått med ';

  @override
  String get none => 'Inga';

  @override
  String get notApprovedYet => 'inte godkänt ännu';

  @override
  String get notAuthenticated => 'inte autentiserat';

  @override
  String get notCheckedYet => 'Inte kontrollerat än';

  @override
  String get notConfigured => 'Ej konfigurerad';

  @override
  String get notConnected => 'Ej ansluten';

  @override
  String get notConnected2 => 'Ej ansluten';

  @override
  String get notInstalled => 'Ej installerad';

  @override
  String get notNeeded => 'Behövs inte';

  @override
  String get notNeededEnough => 'Behövs inte tillräckligt';

  @override
  String get notNow => 'Inte nu';

  @override
  String get notNow2 => 'Inte nu';

  @override
  String get notSet => 'Inte inställt';

  @override
  String get notSetUp => 'Ej inställd';

  @override
  String get notTheSameAsAdmin => 'Inte samma sak som admin';

  @override
  String get nothingFound => 'Inget hittades';

  @override
  String get nothingHereYet => 'Inget här ännu.';

  @override
  String get nothingHereYet2 => 'Inget här ännu';

  @override
  String get nothingMatches => 'Inget matchar';

  @override
  String get nothingStoredYet => 'Inget lagrat ännu.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'OAuth-klient-ID';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth klient-id hemlig omdirigering api-nyckel';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth klient-id hemlig omdirigering gmail-kalenderenhet';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth-lansering stöds inte på den här plattformen.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook hyresgäst klient-id hemligt';

  @override
  String get oauthToken => 'OAuth-token';

  @override
  String get oauthWithPkce => 'OAuth med PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'av $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'sin egen. Den visas aldrig igen efter att ha sparats.';

  @override
  String get off => 'Av';

  @override
  String get officialIntegration => 'Officiell integration';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Officiell integration returnerade ingen anslutnings-URL.';

  @override
  String get on => 'På';

  @override
  String get onASignedInAndroidDevice =>
      'På en inloggad Android-enhet öppnar du Inställningar › Inloggning och säkerhet, skanna den här koden och godkänn inloggningen.';

  @override
  String get onByDefaultForNewGroups => 'På som standard för nya grupper';

  @override
  String get onDemand => 'På begäran';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'På för $arg1 av $arg2-grupper';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'på. De kan bara gå med igen med en ny inbjudningslänk.';

  @override
  String get onYourOwnTheDefault => 'På egen hand (standard)';

  @override
  String get once => 'En gång';

  @override
  String get oneIsSavedOtherChangesIn =>
      'en är räddad. Andra ändringar i detta formulär sparas också.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Ett eller flera konton har löpt ut. Återanslut det berörda kontot för att återställa verktygsåtkomst.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'En körning styr persona, gruppturtagning, rumsminne, normer, Theory of Mind och leverans.';

  @override
  String get oneTimeRun => 'Engångskörning';

  @override
  String get onlyApkOrApksFilesCan =>
      'Endast .apk- eller .apks-filer kan installeras.';

  @override
  String get onlyInThisGroup => 'Endast i denna grupp';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Behövs endast om tjänsten ber om extra HTTP-huvuden.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Behövs bara om du vill omforma den utgående nyttolasten.';

  @override
  String get onlyTheyCanChangeIt => 'Bara de kan ändra det.';

  @override
  String get open => 'Öppna';

  @override
  String get openAccountSettingsOnASigned =>
      'Öppna Inställningar › Inloggning och säkerhet på en inloggad Android-enhet, skanna den här koden och godkänn inloggningen.';

  @override
  String get openComputer => 'Öppna datorn';

  @override
  String get openDashboard => 'Öppna instrumentpanelen';

  @override
  String get openFolder => 'Öppna mappen...';

  @override
  String get openInWorkbench => 'Öppen i arbetsbänk';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Öppna NeoAgent och återanslut $arg1 för att återställa meddelanden.';
  }

  @override
  String get openTimeSettings => 'Öppna tidsinställningar';

  @override
  String get openToAnyone => 'Öppen för vem som helst';

  @override
  String get openTrello => 'Öppna Trello';

  @override
  String get openVoiceAssistant => 'Öppna röstassistenten';

  @override
  String get openWiFiSettings => 'Öppna Wi-Fi-inställningar';

  @override
  String get openWithTheDefaultApp => 'Öppna med standardappen';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai-kompatibel';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-kompatibel slutpunkt (din egen server eller annan ';

  @override
  String openedArg1(Object? arg1) {
    return 'Öppnade $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Det går inte att öppna webbadresser för skrivbordet på den här plattformen.';

  @override
  String get openingYourSavedDesktop => 'Öppnar ditt sparade skrivbord.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Öppnar ditt sparade skrivbord. Normala starter tar mindre än 10 sekunder.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Valfri extra hemlighet om du skyddar den inkommande webbhooken.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Valfri åsidosättning om webhook-URL:n inte räcker.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Valfri hemlighet för att verifiera inkommande chatthändelser.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Valfri hemlighet för att verifiera inkommande händelser.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Valfri hemlighet för att verifiera inkommande iMessage-händelser.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Valfri hemlighet för att verifiera inkommande LINE-händelser.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Valfri hemlighet för att verifiera inkommande Mattermost-händelser.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Valfri hemlighet för att verifiera inkommande Teams-evenemang.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Valfritt. Agenten har redan sin egen personlighet. Allt du lägger till om ton läggs i lager ovanpå det, så du behöver aldrig definiera en.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Valfritt. När den är inställd används den istället för URL:en.';

  @override
  String get orAnswerInYourOwnWords => 'Eller svara med dina egna ord';

  @override
  String get orBuildYourOwnTask => 'Eller bygg din egen uppgift';

  @override
  String get orContinueWith => 'eller fortsätt med';

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
  String get originNotAllowed => 'ursprung ej tillåtet';

  @override
  String get outgoingMessage => 'Utgående meddelande';

  @override
  String get outgoingWebhookUrl => 'Utgående webhook-URL';

  @override
  String get outlookEmailReceived => 'Outlook-e-post mottagen';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Skriv över beteendeanteckningar från importen.';

  @override
  String get ownModel => 'egen modell';

  @override
  String get packageName => 'Paketnamn';

  @override
  String get pairWithQrCode => 'Para ihop med QR-kod';

  @override
  String get password => 'Lösenord';

  @override
  String get password2faAndActiveSessions =>
      'Lösenord, 2FA och aktiva sessioner';

  @override
  String get passwordCreated => 'Lösenord skapat.';

  @override
  String get passwordIsTooWeak => 'lösenordet är för svagt';

  @override
  String get passwordMin8 => 'lösenord min 8';

  @override
  String get passwordOrApiKey => 'Lösenord eller API-nyckel';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Lösenordsstyrka: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Lösenord stämmer inte överens.';

  @override
  String get pasteAKey => 'Klistra in en nyckel.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Klistra in en ny nyckel för att ersätta $arg1';
  }

  @override
  String get pasteTheKey => 'Klistra in nyckeln';

  @override
  String get pasteYourAccountToken => 'Klistra in ditt kontotoken';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Klistra in din $arg1 API-nyckel nedan. Det är ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Sökvägen måste stanna inom NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Sökvägen måste stanna i arbetsytans mapp.';

  @override
  String get pauseLiveUpdates => 'Pausa liveuppdateringar';

  @override
  String get pauseTaskLoop => 'Pausa uppgiftsslingan';

  @override
  String get paused => 'Pausad';

  @override
  String peakArg1(Object? arg1) {
    return 'topp $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Människor i privata chattar';

  @override
  String get perAccountRateLimits => 'Räntegränser per konto';

  @override
  String get perCategoryPermissions => 'Behörigheter per kategori';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Behörighetspolicyer per verktyg, godkännandeportar och processisolering för skalexekvering.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Tillstånd krävs: $arg1';
  }

  @override
  String get permissionsNeeded => 'Behörigheter behövs';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Behörigheter. Ingen annan kan ändra på det.';

  @override
  String get personOrChat => 'Person eller chatt';

  @override
  String get personaBehaviorNotes => 'Persona beteende anteckningar';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Personlig åtkomsttoken för Mattermost-boten.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Personliga kanaler och direkta stödytor.';

  @override
  String get personalSelfChat => 'Personlig självchatt';

  @override
  String get phoneNumber => 'Telefonnummer';

  @override
  String get pickARunFromTheList =>
      'Välj en löptur från listan för att se dess steg.';

  @override
  String get pickARunFromTheList2 =>
      'Välj en löptur från listan till vänster för att utforska dess flöde.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Välj bland de senaste $arg1-chattar, eller lägg till en person eller grupp själv.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Välj hur $arg1 använder detta konto.';
  }

  @override
  String get pickOneToFillInThe =>
      'Välj en att fylla i uppgiften. Du kan justera allt efteråt.';

  @override
  String get picksUpWhereYouLeftOff => 'Fortsätter där du slutade';

  @override
  String get plan => 'Planera';

  @override
  String get planning => 'Planering';

  @override
  String get platform => 'Plattform';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Plattform $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Välj ett schema.';

  @override
  String get pleaseEnterAFilename => 'Vänligen ange ett filnamn.';

  @override
  String get pleaseEnterAKey => 'Vänligen ange en nyckel.';

  @override
  String get pleaseEnterAPrompt => 'Vänligen ange en uppmaning.';

  @override
  String get pleaseEnterATaskName => 'Ange ett uppgiftsnamn.';

  @override
  String get pleaseEnterTheMemoryContent => 'Ange minnesinnehållet.';

  @override
  String get pleaseEnterWhenTheTaskShould => 'Ange när uppgiften ska köras.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Välj ett konto eller ange ett giltigt anslutnings-ID.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Peka NeoAgent på alla OpenAI-kompatibla chattavslutningar ';

  @override
  String get pointTheCameraAtTheCode =>
      'Rikta kameran mot koden som visas på den utloggade enheten. Godkännandet kvarstår på den här telefonen.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env public url trust proxy säker distribution av cookies';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Premiumautomatisering med schema och integrationstriggers.';

  @override
  String get prepareQrCode => 'Förbered QR-kod';

  @override
  String get preparingNeoagent => 'Förbereder NeoAgent...';

  @override
  String get preparingNeoagent2 => 'Förbereder NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Tryck och håll ned för snabb inspelning';

  @override
  String get pressKeysIsNotSupportedOn =>
      'tryckknappar stöds inte på denna plattform.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Tryckte $arg1';
  }

  @override
  String get priceUnknown => 'Pris okänt';

  @override
  String get primaryDisplay => 'Primär display';

  @override
  String get privateChat => 'Privat chatt';

  @override
  String get privateChats => 'Privata chattar';

  @override
  String get privateChats2 => 'privata chattar';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privata chattar: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privata chattar $arg1 · grupper $arg2';
  }

  @override
  String get privateChatsOnly => 'Endast privata chattar';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privata nätverksadresser är inte tillåtna.';

  @override
  String get profileEmailAndPersonalData =>
      'Profil, e-post och personuppgifter';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Fråga innan NeoAgent stannar kvar i systemfältet.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Snabbcache: $arg1 cachade tokens ';
  }

  @override
  String get promptCopied => 'Uppmaning kopierad.';

  @override
  String get promptOrSchedule => 'uppmaning eller schema.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Uppmaning att klistra in i en annan AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Det gick inte att starta leverantörslänkning.';

  @override
  String get providerSignInCouldNotBe =>
      'Det gick inte att starta leverantörsinloggning.';

  @override
  String get providers => 'Leverantörer';

  @override
  String get providersEachAccountCanStillPick =>
      'Leverantörer; varje konto kan fortfarande välja sin egen modell i Inställningar. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Leverantörer, integrationer, röst och valfria funktioner kan fullföljas från Inställningar när som helst.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Trådar för offentliga frågor och pull-förfrågningar, besvaras endast för godkända personer.';

  @override
  String get publicUrl => 'Offentlig URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Offentlig URL och tillåtna ursprung';

  @override
  String get publicUrlOverride => 'Åsidosättande av offentlig webbadress';

  @override
  String get pullsTogetherTheDayAhead => 'Drar ihop dagen framför sig';

  @override
  String get pushToTalk => 'Tryck-och-tala';

  @override
  String get qrBasedPhoneLinking => 'QR-baserad telefonlänkning';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR-inloggning slutförd, men NeoAgent kunde inte behålla sessionen. Försök igen.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR-inloggning kunde inte startas.';

  @override
  String get qrLoginRequestHasExpired => 'qr-inloggningsbegäran har löpt ut';

  @override
  String get qrLoginRequestWasNotFound =>
      'qr-inloggningsförfrågan hittades inte';

  @override
  String get qrPairing => 'QR-koppling';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'frågor körs; allt som skriver avvisas.';

  @override
  String get queryFilter => 'Fråga / Filter';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'I kö som styrning för den aktuella körningen: $arg1';
  }

  @override
  String get quickstart => 'Snabbstart';

  @override
  String get quit => 'Avsluta';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'regn_start, vind_varning';

  @override
  String get ranAScriptInThePage => 'Körde ett skript på sidan';

  @override
  String ranArg1(Object? arg1) {
    return 'Körde $arg1';
  }

  @override
  String get rateLimits => 'Prisgränser';

  @override
  String get readAnArtifact => 'Läs en artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Läs och redigera filer i din NeoAgent Workspace-mapp.';

  @override
  String readArg1(Object? arg1) {
    return 'Läs $arg1';
  }

  @override
  String get readError => 'Läsfel';

  @override
  String get readFiles => 'Läs filer';

  @override
  String get readOnly => 'Endast läs';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Läs mappen och sammanfatta stacken, ingångspunkter och hur du kör den.';

  @override
  String get readThePage => 'Läs sidan';

  @override
  String get readTheUiTree => 'Läs UI-trädet';

  @override
  String get readWrite => 'Läs/skriv';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Läser steg, puls, sömn, träning och vikt.';

  @override
  String get ready => 'Klar';

  @override
  String get readyForFirstTimeSetup => 'Klar för förstagångsinstallation';

  @override
  String get readyToConnect => 'Klar att ansluta';

  @override
  String get recentChannelActivity => 'Senaste kanalaktivitet';

  @override
  String get recentChats => 'Senaste chattar';

  @override
  String get recentDecisions => 'Senaste besluten';

  @override
  String get recentFailedRuns => 'De senaste misslyckade körningarna';

  @override
  String get recentGroupDecisions => 'Senaste gruppbeslut';

  @override
  String get recentRuns => 'Senaste körningarna';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'De senaste körningarna tar ungefär $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Senaste serverutdata, senaste först.';

  @override
  String get recentUsage4Hours => 'Senaste användning (4 timmar)';

  @override
  String get recents => 'Senaste';

  @override
  String get recipientField => 'Mottagarefält';

  @override
  String get reconnectOrFinishSetup =>
      'Återanslut eller avsluta installationen';

  @override
  String get reconnectingThisDevice => 'Återansluter den här enheten...';

  @override
  String get recurring => 'Återkommande';

  @override
  String get redirectUri => 'Omdirigera URI';

  @override
  String get redoOnboarding => 'Gör om onboarding';

  @override
  String get refresh => 'Uppdatera';

  @override
  String get refreshCode => 'Uppdatera koden';

  @override
  String get refreshNow => 'Uppdatera nu';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Uppdatera Android-skärmen för att försöka igen.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Vägra att skicka om inte anslutningen uppgraderas till TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'oavsett inställningar per kategori nedan.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registrera $arg1 för assistentinkallningsflödet.';
  }

  @override
  String get registrationIsClosed => 'registreringen är stängd';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registrering registrera nya konton tillåter registrering';

  @override
  String get rejectInvalidTlsCertificates => 'Avvisa ogiltiga TLS-certifikat';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'släpp och startar om. Anslutna appar ansluter igen när de är tillbaka.';

  @override
  String get releaseChannel => 'Släpp kanal';

  @override
  String get releaseCommitBranchNode => 'release commit branch nod';

  @override
  String get releaseWhenYouAreDone => 'Släpp när du är klar.';

  @override
  String get reloadNow => 'Ladda om nu';

  @override
  String get rememberThisChoice => 'Kom ihåg detta val';

  @override
  String get remove => 'Ta bort';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Ta bort \"$arg1\" och dess inspelade steg från körhistoriken?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Ta bort \"$arg1\" från kärnminnet.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Ta bort $arg1 nyckel?';
  }

  @override
  String get removeEraseGdprUser => 'ta bort radera gdpr-användare';

  @override
  String get removeSmtpPassword => 'Ta bort SMTP-lösenord';

  @override
  String get removeTheSmtpPassword => 'Ta bort SMTP-lösenordet?';

  @override
  String get rename => 'Byt namn';

  @override
  String get renameSecurityKey => 'Byt namn på säkerhetsnyckel';

  @override
  String get renameSession => 'Byt namn på session';

  @override
  String get repairAndRetry => 'Reparera och försök igen';

  @override
  String get repairDesktop => 'Reparera skrivbordet';

  @override
  String get repeat => 'Upprepa';

  @override
  String get repliesWhenTagged => 'Svarar när taggad';

  @override
  String get replyToAddress => 'Svars-till-adress';

  @override
  String replyToArg1(Object? arg1) {
    return 'Svara till $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Lagret måste vara i formatet ägare/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Återskapa buggen jag beskriver, hitta grundorsaken och fixa den med ett regressionstest.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'begäran misslyckades med http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Begäran misslyckades med HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Begär behörigheter';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Begäran till $arg1 misslyckades innan backend svarade.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Begärt $arg1';
  }

  @override
  String get requireStarttls => 'Kräv STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Krävs bakom HTTPS eller en TLS-proxy. Gäller efter en server ';

  @override
  String get requiredExampleBerlinDe => 'Obligatoriskt. Exempel: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Obligatoriskt. Format: ägare/repo';

  @override
  String get reserveAssistantHotkey => 'Snabbknapp för reservassistent';

  @override
  String get reset => 'Återställ';

  @override
  String get resetPassword => 'Återställ lösenord';

  @override
  String get resetView => 'Återställ vyn';

  @override
  String get responsibilities => 'Ansvar';

  @override
  String get restart => 'Starta om';

  @override
  String get restartToFinishTheUpdate =>
      ' Starta om för att slutföra uppdateringen.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Återställer den tidigare NeoAgent-körtiden';

  @override
  String get restrictDelegationTargets => 'Begränsa delegeringsmål';

  @override
  String get result => 'Resultat';

  @override
  String get resultDelivery => 'Resultat leverans';

  @override
  String get resultOneClickAddsOneYou =>
      'resultat. Ett klick lägger till en; du kan redigera den senare.';

  @override
  String get results => 'Resultat';

  @override
  String get retry => 'Försök igen';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Återanvändbar · använd $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Granska oengagerade ändringar';

  @override
  String get revoke => 'Återkalla';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Återkalla admin med \'neoagent admin återkalla $arg1\' först';
  }

  @override
  String get revokeThisLink => 'Återkalla denna länk?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Rumsbatchfönster: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Rotera för att fortsätta';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rader. Lägg till en LIMIT eller en smalare WHERE-sats för att se ';

  @override
  String get rule => 'Regel';

  @override
  String get run => 'Körning';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Kör godtyckliga kommandon på din dator eller virtuella dator.';

  @override
  String get runAt => 'Kör kl';

  @override
  String get runCompleted => 'Körningen avslutad';

  @override
  String get runFailed => 'Körningen misslyckades';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Kör git diff, granska de oengagerade ändringarna för buggar och stilproblem och sammanfatta vad du hittar.';

  @override
  String get runNotFound => 'Körning hittades inte';

  @override
  String get runNow => 'Kör nu';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Kör på inkommande personliga WhatsApp-meddelanden.';

  @override
  String get runQuery => 'Kör fråga';

  @override
  String get runShellCommandsOrInstallApps =>
      'Kör skalkommandon eller installera appar på din Android-enhet.';

  @override
  String get runStarted => 'Löpningen började';

  @override
  String get runStatus => 'Körstatus';

  @override
  String get runStopped => 'Run stoppad';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Kör terminalkommandon och öppna appar eller webbsidor.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Kör den här servern: konton, uppdateringar, leverantörer, konfiguration ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Kör när ett matchande Gmail-meddelande kommer.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Kör när ett matchande Outlook-e-postmeddelande kommer.';

  @override
  String get runWhenANewIssueMatching =>
      'Kör när ett nytt problem som matchar dina filter öppnas i ett arkiv.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Kör när ett nytt NeoRecall-minne som matchar dina filter skapas.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Kör när en avisering kommer till din enhet.';

  @override
  String get runWhenASlackMessageMatches =>
      'Kör när ett Slack-meddelande matchar det valda omfånget.';

  @override
  String get runWhenATeamsChatMessage =>
      'Kör när ett Teams chattmeddelande matchar det valda omfånget.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Kör när konfigurerade väderhändelser prognostiseras för en plats.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'sikt. Medan alla modeller är avstängda, lägger modeller som leverantörer till ';

  @override
  String get running => 'Pågår';

  @override
  String runningArg1(Object? arg1) {
    return 'Kör $arg1';
  }

  @override
  String get runningTask => 'Löpande uppgift';

  @override
  String get runningTool => 'Löpverktyg';

  @override
  String get runs => 'Körningar';

  @override
  String get runsEveryDayAtTheSelected => 'Körs varje dag vid vald tid.';

  @override
  String get runsFourTimesPerHour => 'Går fyra gånger i timmen.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— körningar, meddelanden, minnen, integrationer, filer och ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'körningar, meddelanden, minnen, integrationer, filer och sessioner. ';

  @override
  String get runsMondayThroughFriday => 'Pågår måndag till fredag.';

  @override
  String get runsOnSelectedWeekdays => 'Körs på utvalda vardagar.';

  @override
  String get runsOncePerHour => 'Går en gång i timmen.';

  @override
  String get runsOncePerMonthOnThe => 'Körs en gång i månaden den valda dagen.';

  @override
  String get runsOnlyWhenYouPressRun => 'Körs endast när du trycker på Kör nu.';

  @override
  String get runsPerDay => 'Kör per dag';

  @override
  String get runsPerDay30Days => 'Körningar per dag (30 dagar)';

  @override
  String get runsThatCompleted => 'Körningar som är klara';

  @override
  String get runsThisWeek => 'Kör den här veckan';

  @override
  String get runsToday => 'Springer idag';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Löpningar, verktyg, minne, schemaläggning, färdigheter och MCP är alla tillgängliga här.';

  @override
  String get runsTwicePerHour => 'Går två gånger i timmen.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Körningar kommer att falla tillbaka till den delade servernyckeln för $arg1, om en sådan är konfigurerad. Detta kan inte ångras.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Körtid $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Körtid: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Körtidsinställningar som denna server började med. Redigera dem under ';

  @override
  String get runtimeSetupRequired => 'Körtidsinställning krävs';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Offentlig nyckel för runtime-signering måste vara 32 byte.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Spara';

  @override
  String get saveATrelloApiKeyFor =>
      'Spara en Trello API-nyckel för denna agent och anslut sedan ett Trello-konto på ett säkert sätt. Kontotokenen lagras på servern och används endast för denna agent.';

  @override
  String get saveAccount => 'Spara konto';

  @override
  String get saveChanges => 'Spara ändringar';

  @override
  String get saveCloudComputerSettings => 'Spara molndatorinställningar';

  @override
  String get saveConnect => 'Spara och anslut';

  @override
  String get saveDefaults => 'Spara standardinställningar';

  @override
  String get saveDiagnosticReport => 'Spara diagnostisk rapport';

  @override
  String get saveEmail => 'Spara e-post';

  @override
  String get saveEmailSettings => 'Spara e-postinställningar';

  @override
  String get saveGeneralSettings => 'Spara allmänna inställningar';

  @override
  String get saveName => 'Spara namn';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Spara NeoAgent-installationsdiagnostik';

  @override
  String get saveOnly => 'Endast spara';

  @override
  String get saveSetup => 'Spara inställningar';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Spara dessa återställningskoder nu. De kommer inte att visas igen.';

  @override
  String get savedDeliveryDestination => 'Sparad leveransdestination';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Sparade hastighetsgränser för @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Skanna en NeoAgent-inloggnings-QR';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skanna en NeoAgent-parnings-QR från en annan enhet och godkänn den från den här startsessionen.';

  @override
  String get scanLoginQr => 'Skanna inloggning QR';

  @override
  String get scanPairingQr => 'Scan parning QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skanna QR-inloggningsförfrågningar från utloggade enheter och godkänn dem från denna autentiserade mobilsession.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skanna för att avsluta $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Skanna med NeoAgent på din telefon';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skannar ny e-post och pingar dig bara när något är viktigt.';

  @override
  String get schedule => 'Schema';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'schemalagd tid. När körningarna är uppmätta kommer den att starta tidigare.';

  @override
  String get screen => 'Skärm';

  @override
  String get screenAction => 'skärmåtgärd';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scroll stöds inte på den här plattformen.';

  @override
  String get scrollToBottom => 'Bläddra till botten';

  @override
  String get search => 'Sök';

  @override
  String get search2 => 'Sök...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Sök administratörsinställningar (t.ex. SMTP, Ollama, loggar)';

  @override
  String get searchAgain => 'Sök igen';

  @override
  String get searchByUsernameOrEmail => 'Sök på användarnamn eller e-post';

  @override
  String get searchChannels => 'Sök efter kanaler';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Sök efter upptäckta meddelandekanaler, kontakter, grupper och senaste konversationer.';

  @override
  String get searchGroups => 'Sök efter grupper';

  @override
  String get searchMemory => 'Sök minne';

  @override
  String get searchModelsOrProviders => 'Sök efter modeller eller leverantörer';

  @override
  String get searchModelsOrProviders2 =>
      'Sök efter modeller eller leverantörer...';

  @override
  String get searchRecentPeopleAndGroups =>
      'Sök efter senaste personer och grupper';

  @override
  String get searchSessions => 'Sök sessioner';

  @override
  String get searchSettings => 'Sökinställningar';

  @override
  String get searchTitleModelTriggerRunId =>
      'Sök titel, modell, trigger, kör-ID';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Sökverktyg, integrationer och färdigheter';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Sökte kod efter \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Sökte filer efter \"$arg1\"';
  }

  @override
  String get secretField => 'Hemligt fält';

  @override
  String get secureCookies => 'Säkra cookies';

  @override
  String get security => 'Säkerhet';

  @override
  String get securityKey => 'Säkerhetsnyckel';

  @override
  String get securityKeyPromptWasDismissed =>
      'Uppmaningen om säkerhetsnyckel avvisades.';

  @override
  String get securityKeySignInCompletedBut =>
      'Inloggning med säkerhetsnyckel slutförd, men NeoAgent kunde inte behålla webbläsarsessionen. Logga in igen.';

  @override
  String get securityKeySignInCouldNot =>
      'Det gick inte att starta inloggning med säkerhetsnyckel.';

  @override
  String get securityKeys => 'Säkerhetsnycklar';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Säkerhetsnycklar är endast tillgängliga i NeoAgent-webbappen.';

  @override
  String get seeAll => 'Se alla';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Se vilken NeoAgent-server som det här fönstret använder och kör backend på den här datorn.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'se ditt användarnamn och dessa inställningar, aldrig dina chattar, minnen ';

  @override
  String get selectARun => 'Välj en löpning';

  @override
  String get selectASessionToSeeIts =>
      'Välj en session för att se dess dator, filer och ändringar.';

  @override
  String get selectAll => 'Välj alla';

  @override
  String get selectAll2 => 'Välj Alla';

  @override
  String selectArg1(Object? arg1) {
    return 'Välj $arg1';
  }

  @override
  String get selectTrigger => 'Välj Trigger';

  @override
  String get send => 'Skicka (⌘↵)';

  @override
  String get send2 => 'Skicka';

  @override
  String get sendATaskFromChatAnd =>
      'Skicka en uppgift från chatten och dess exekveringshistorik kommer att visas här.';

  @override
  String get sendItToATeammateWith =>
      'skicka den till en lagkamrat med ett konto på denna server.';

  @override
  String get sendLink => 'Skicka länk';

  @override
  String get sendPath => 'Skicka sökväg';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Skicka POST/PUT/DELETE-förfrågningar till externa API:er.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Skicka denna länk endast till personen den är avsedd för. Det visas en gång; ';

  @override
  String get senderAddress => 'Avsändarens adress';

  @override
  String get senderFilterOptional => 'Avsändarfilter (valfritt)';

  @override
  String get sentSharedAttachments => 'Skickade delade bilagor.';

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
      'Serverstandard för röstsamtal i appen. Samtal körs live ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'själva servern: konton, leverantörer och konfiguration.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, nick, kanal och valfri TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'varningsfel från serverutgångskonsolen kopieras';

  @override
  String get serverProviderCredentials => 'Serverleverantörsuppgifter';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Serveranvändningsgränser gäller inte för modeller som körs på din egen nyckel.';

  @override
  String get serviceEmail => 'Servicemail';

  @override
  String get serviceEmailIsNotConfigured =>
      'tjänstens e-post är inte konfigurerad';

  @override
  String get serviceEmailSmtp => 'Tjänste-e-post (SMTP)';

  @override
  String get sessionActions => 'Sessionsåtgärder';

  @override
  String get sessions => 'Sessioner';

  @override
  String get sessions2 => 'SESSIONER';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sessioner fästs till en mapp och en dator. Börja en för att planera, bygga, testa och skicka härifrån.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sessioner (GDPR art. 17). Administratörskonton kan inte tas bort ';

  @override
  String get sessionsLogoutRevokeForce =>
      'sessioner utloggning återkalla kraft';

  @override
  String get setBlockAskAllowPerTool =>
      'Ställ in blockera / fråga / tillåt per verktygskategori, eller välj ett globalt läge.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Konfigurera NeoAgent på den här datorn';

  @override
  String get setUpOrConnectNeoagent => 'Konfigurera eller anslut NeoAgent';

  @override
  String get setUrl => 'Ange URL';

  @override
  String get settings => 'Inställningar';

  @override
  String get settingsAndCannotBeUndone => 'inställningar och kan inte ångras.';

  @override
  String get settingsArea => 'Inställningsområde';

  @override
  String get settingsAreas => 'Inställningsområden';

  @override
  String get setup => 'Inställning';

  @override
  String get setupDetails => 'Inställningsdetaljer';

  @override
  String get setupRequired => 'Installation krävs';

  @override
  String get setupWasCancelled => 'Installationen avbröts.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Delade bilagor från NeoAgent-klienten:';

  @override
  String get sharedFromAnotherApp => 'Delas från en annan app';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Delade leverantörsnycklar konfigureras på servern. För att använda din egen API-nyckel eller en anpassad slutpunkt istället, gå till Avancerat → Ta med din egen nyckel.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Delas med NeoAgent-chatten och dess minne.';

  @override
  String get shellCommands => 'Skalkommandon';

  @override
  String showAllArg1(Object? arg1) {
    return 'Visa alla $arg1';
  }

  @override
  String get showEarlier => 'Visa tidigare';

  @override
  String get showEveryStep => 'Visa varje steg';

  @override
  String get showTools => 'Visa verktyg';

  @override
  String get showWorkbenchJ => 'Visa arbetsbänk (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Visar den första $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Visas i sidofältet. Lämna tomt för att använda ditt användarnamn.';

  @override
  String get signIn => 'Logga in';

  @override
  String get signInCompletedButNeoagentCould =>
      'Inloggningen slutförd, men NeoAgent kunde inte behålla webbläsarsessionen. Logga in igen. Om detta fortsätter att hända, kontrollera backend-sessionens cookieinställningar.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Inloggningen slutförd, men NeoAgent kunde inte behålla webbläsarsessionen. Logga in igen. Om detta fortsätter att hända kommer backend-sessionscookien sannolikt inte att behållas.';

  @override
  String get signInToThisNeoagentServer =>
      'Logga in på den här NeoAgent-servern innan du skannar en QR-kod för ihopkoppling.';

  @override
  String get signInWithAHardwareKey =>
      'Logga in med en hårdvarunyckel eller lösenord istället för ditt lösenord. ';

  @override
  String get signInWithASecurityKey => 'Logga in med en säkerhetsnyckel';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Logga in med $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Godkänn NeoAgent i ditt $arg1-konto. Ingen nyckel att kopiera.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Väntar på $arg1. Avsluta i din webbläsare.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Klistra in $arg1-koden';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Efter att du godkänt NeoAgent visade $arg1 en engångskod. Klistra in den här.';
  }

  @override
  String get signInCode => 'Inloggningskod';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Inloggad med $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Inloggning misslyckades: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Logga in med samma e-postadress och huvudlösenord som du använder i Bitwarden. Huvudlösenordet och tvåstegskoden används endast för inloggning och lagras eller skickas aldrig till AI.';

  @override
  String get signOut => 'Logga ut';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Logga ut @$arg1 överallt?';
  }

  @override
  String get signOutEverywhere => 'Logga ut överallt';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API-brygga';

  @override
  String get signalCliServerUrl => 'signal-cli server URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Signerade @$arg1 av varje session.';
  }

  @override
  String get signedInDevices => 'Inloggade enheter';

  @override
  String get signedInWithin24Hours => 'Inloggad inom 24 timmar';

  @override
  String get signingSecret => 'Undertecknande hemlighet';

  @override
  String sinceArg1(Object? arg1) {
    return 'Sedan $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'sedan $arg1';
  }

  @override
  String get singleMessage => 'Ett enda meddelande';

  @override
  String get singleUse => 'Engångsbruk';

  @override
  String get skill => 'Skicklighet';

  @override
  String get skillChanges => 'Skicklighetsförändringar';

  @override
  String get skillContent => 'Skicklighetsinnehåll';

  @override
  String get skills => 'Färdigheter';

  @override
  String get skip => 'Hoppa över';

  @override
  String get skipForNow => 'Hoppa över nu';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Hoppa över den här uppgiften innan den anropar modellen.';

  @override
  String get slackMessageReceived => 'Slack meddelande mottaget';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Sömn $arg1 sessioner';
  }

  @override
  String get smartSelector => 'smart väljare';

  @override
  String get smartSelector2 => 'Smart väljare';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP-värd';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail avsändare lösenord tls bekräftelsemeddelanden återställs';

  @override
  String get smtpPassword => 'SMTP-lösenord';

  @override
  String get smtpPort => 'SMTP-port';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP-porten måste vara ett heltal från 1 till 65535.';

  @override
  String get smtpUsername => 'SMTP-användarnamn';

  @override
  String get soTheRunStartsThatMuch =>
      'så löpningen börjar så mycket tidigare.';

  @override
  String get socialBehaviorOff => 'Socialt beteende avstängt';

  @override
  String get socialIntelligence => 'social intelligens';

  @override
  String get socialIntelligence2 => 'Social intelligens';

  @override
  String get socialObservability => 'Social observerbarhet';

  @override
  String get socialReach => 'social räckvidd';

  @override
  String get socialReach2 => 'Social räckvidd';

  @override
  String get socialReach3 => 'Social räckvidd';

  @override
  String get socialReachUpdated => 'Social Reach uppdaterad.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenter för sociala källor kan läsa direkt, inklusive flöden, arkiv, Reddit, X, videor och marknadsdata med stöd av cookies.';

  @override
  String get somethingWentWrongPleaseTryAgain => 'Något gick fel. Försök igen.';

  @override
  String get source => 'Källa';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Mellanslag eller chatt-ID används när den här agenten startar en konversation.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook och app-återuppringningsstöd';

  @override
  String get speaking => 'Talar';

  @override
  String get speechToSpeechModelUsingThe =>
      'tal-till-tal-modell med OpenAI- eller Google-tangenten under ';

  @override
  String get speechToText => 'Tal till text';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Tal-till-text transkriberar röstanteckningar och diktering. Auto använder OpenAI, Gemini eller Deepgram, beroende på vilken som har en API-nyckel. Röstsvarsmodellen är chattmodellen som svarar på röstanteckningar.';

  @override
  String get sqlConsole => 'SQL-konsol';

  @override
  String get stable => 'Stabil';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable installerar den senaste publicerade backend-versionen.';

  @override
  String get stackTrace => 'stack spår';

  @override
  String get standard => 'Standard';

  @override
  String get standardView => 'Standardvy';

  @override
  String get start => 'Starta';

  @override
  String get startASessionToPlanOr =>
      'Starta en session för att planera eller bygga med NeoAgent.';

  @override
  String get startAndroid => 'Starta Android';

  @override
  String get startComputer => 'Starta datorn';

  @override
  String get startFullSetup => 'Starta hela installationen';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Starta installationen';

  @override
  String get startTalking => 'Börja prata';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Starta Android-telefonen först och släpp sedan en .apk- eller .apks-fil här.';

  @override
  String get startTheServerLaterFromThe =>
      'Starta servern senare från listan när konfigurationen har sparats.';

  @override
  String get startWithARecommendedTask => 'Börja med en rekommenderad uppgift';

  @override
  String get startingAndroid => 'Startar Android';

  @override
  String get startingYourComputer => 'Startar din dator';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Börjar med xoxb-. Från dina Slack-appreferenser.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting-fel: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistik kör tokens användare diagram framgångsfrekvens';

  @override
  String get status => 'Status';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'statusdatabas runtime vm-leverantörer';

  @override
  String get statusIsNotLoadedYet => 'Status är inte laddad än.';

  @override
  String get stayManagedByYou => 'förbli hanterad av dig.';

  @override
  String get stayOnTheCall => 'Håll samtalet';

  @override
  String get stayedQuiet => 'Var tyst';

  @override
  String get steering => 'STYRNING';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'STEG $arg1 AV $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Steg $arg1';
  }

  @override
  String get stop => 'Stoppa';

  @override
  String get stop2 => 'Stopp (⌘.)';

  @override
  String get stopManaging => 'Sluta hantera';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Sluta hantera $arg1?';
  }

  @override
  String get stopRun => 'Sluta springa';

  @override
  String get stopSpeaking => 'Sluta prata';

  @override
  String get stoppedBeforeCompletion => 'Stoppade innan färdigställandet';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Error: $arg1';
  }

  @override
  String get storage => 'Förvaring';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'lagras krypterad och används endast för dina egna körningar.';

  @override
  String get storedMetrics => 'Lagrade mätvärden';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Lagrar endast Bitwarden-sessionsnyckeln krypterad på den här servern, så att anslutningarna överlever omstarter. Du kan låsa den när som helst.';

  @override
  String get strong => 'Stark';

  @override
  String get strongPassword => 'Starkt lösenord.';

  @override
  String get subAgent => 'Underagent';

  @override
  String get subagentUpdate => 'Subagent uppdatering';

  @override
  String get subagentUpdate2 => 'Subagent uppdatering.';

  @override
  String get successRate => 'Framgångsfrekvens';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Förslag: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Sammanfatta min senaste körning';

  @override
  String get supportUrl => 'Support URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Stöds: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Byt agent';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Symboliska länkar är inte tillåtna i NeoAgent Workspace-sökvägar.';

  @override
  String get syncNow => 'Synkronisera nu';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Systemets sekretessinställningar';

  @override
  String get tableInfoUsers => 'Tabellinformation (användare)';

  @override
  String get tagsOnly => 'Endast taggar';

  @override
  String get tasks => 'Uppgifter';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Uppgifterna körs av sig själva och skickar ett meddelande till dig ';

  @override
  String get teach => 'Undervisa';

  @override
  String get teachingInProgress => 'Undervisning pågår';

  @override
  String get team => 'Team';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Teamlänkar gör aldrig någon till serveradministratör. Administratörer kör ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Teamutrymmen, rum, kanaler och live-gemenskaper.';

  @override
  String get teamsMessageReceived => 'Teams meddelande mottaget';

  @override
  String get templates => 'Mallar';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Tillfälliga installationsfiler kommer att rensas upp senare.';

  @override
  String get tenantId => 'Hyresgäst ID';

  @override
  String get testConnection => 'Testa anslutningen';

  @override
  String get testConnection2 => 'Testa anslutningen';

  @override
  String get textChat => 'Sms och chatt';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'som lagt till sin egen nyckel fortsätter att använda den.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Det e-postmeddelandet tillhör redan ett befintligt konto. Logga in först och länka sedan Google från kontoinställningarna.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Det e-postmeddelandet är redan länkat till ett annat konto.';

  @override
  String get thatQrCodeIsNotA =>
      'Den QR-koden är inte en NeoAgent-inloggningsförfrågan.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Den QR-koden är inte en NeoAgent-parningsförfrågan.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Den säkerhetsnyckeln är redan registrerad på det här kontot.';

  @override
  String get theAddress => 'Adressen';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adressen till din BlueBubbles-server.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adressen personer och OAuth-leverantörer använder för att nå ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agenten läser tider du nämner och kör schemalagda uppgifter i denna tidszon.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agenten kommer att fråga före varje känsligt verktyg, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Agenten kommer att ignorera denna färdighet.';

  @override
  String get theAppCouldNotReachThis =>
      'Appen kunde inte nå den här NeoAgent-distributionen. Kontrollera din nätverksanslutning eller bekräfta att tjänstens URL är korrekt.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Webbläsaren blockerade en begäran till $arg1 på grund av innehållssäkerhetspolicy.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Webbläsaren blockerade en obligatorisk begäran på grund av innehållssäkerhetspolicy.';

  @override
  String get theCloudWorkspace => 'molnets arbetsyta';

  @override
  String get theComputerCouldNotStart => 'Datorn kunde inte starta';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Datorn behöver mer ledigt diskutrymme på NeoAgent-värden. Frigör lite utrymme och försök sedan igen.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Datorns körtid behöver repareras. Kör NeoAgent Doctor och försök sedan igen.';

  @override
  String get theConnectionTestFailed => 'Anslutningstestet misslyckades.';

  @override
  String get theDesktopDidNotStart => 'Skrivbordet startade inte';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Den upptäckta NeoAgenten returnerade ofullständig identitetsdata.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Den upptäckta NeoAgent använder ett installationsprotokoll som inte stöds.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Den upptäckta tjänsten är inte NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Den nedladdade NeoAgent-körtiden klarade inte verifieringen.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook för Google Chat-utrymme som denna agent bör göra inlägg till.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Installationsprogrammet är inte längre tillgängligt.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Det interaktiva Linux-skrivbordet är tillgängligt i NeoAgent-webbappen.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Introduktionen är inte tillgänglig på den här enheten.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Den senaste körs över alla konton.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Det senaste synkroniseringsfönstret avslutade $arg1 och hittade inga nya Health Connect-poster. Lagrade mätvärden nedan kom från tidigare synkroniseringar.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Den grafiska Linux-sessionen körs inte.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Live-röstmodellen svarade inte. Försök igen.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Det lokala NeoAgent-kommandot avslutades med koden $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Det lokala NeoAgent-kommandot tog timeout.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Den lokala NeoAgent-körtiden behöver repareras.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Den lokala körtiden behöver repareras ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Den lokala användarens hemkatalog är inte tillgänglig.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'E-postkontot NeoAgent skickar registreringsbekräftelser, inloggning ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Huvudagenten skapas automatiskt vid behov.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Den matchande NeoAgent-körtiden saknas i den här versionen.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Den viktigaste inkommande webbhooken som denna agent bör skicka inlägg till.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'De modeller som Smart Selector växlar mellan automatiskt.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'NeoAgent-backend-nedladdningen matchade inte manifestet.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Nedladdningen av NeoAgent-backend var ofullständig.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'NeoAgent-backend på den här datorn svarar inte på porten ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Det gick inte att ladda ner NeoAgent-backend-körtiden.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'NeoAgent-backend tog för lång tid att svara för $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'NeoAgent-distributionen svarade med HTTP 402 istället för den normala 401 för ogiltiga autentiseringsuppgifter. Kontrollera omvänd proxy, autentiseringsgateway eller betalningsrelaterade regler på den servern.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'NeoAgent-distributionen svarade med HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'NeoAgent-distributionen svarade med HTTP 402. Kontrollera omvänd proxy, autentiseringsgateway eller betalningsrelaterade regler på den servern.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'NeoAgent-instansen som denna app är ansluten till.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'NeoAgent-releasetjänsten returnerade ogiltiga data.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'NeoAgent runtime-artefaktens metadata är ogiltig.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'NeoAgent runtime-manifestet klarade inte signaturverifieringen.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'NeoAgent runtime-manifestet har inga artefakter.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'NeoAgent runtime-manifestsignaturen är ogiltig.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Lösenordet du anger i BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'De människor du hanterar stannar hos dig.';

  @override
  String get theProviderAnswers => 'svarar leverantören.';

  @override
  String get theQueryReturnedNoRows => 'Frågan returnerade inga rader.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Den begärda skrivbordsskärmen är inte tillgänglig.';

  @override
  String get theRest => 'resten.';

  @override
  String get theRestEndpointForYourSignal =>
      'REST-slutpunkten för din signal-cli-instans.';

  @override
  String get theRunIsPausedUntilYou => 'Löpningen pausas tills du svarar.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Löpningen startar vid schemalagd tid.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Körtiden är ett lätt Debian Linux-skrivbord med Chromium, PCManFM, Mousepad, LXTerminal, Python, Git och vanliga kommandoradsverktyg. Dess kapacitet hanteras av NeoAgent-värden.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Det gick inte att starta säkerhetsnyckelregistreringen.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'servern behåller bara ett fingeravtryck av det.';

  @override
  String get theServerOnThisComputerIs => 'Servern på den här datorn körs inte';

  @override
  String get theServerReportedNoHealthChecks =>
      'Servern rapporterade inga hälsokontroller.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Signaltelefonnumret som denna bot använder.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Teams inkommande webhook som den här agenten ska skicka till.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Tvåfaktorsutmaningen löpte ut. Logga in igen.';

  @override
  String get theTwoFactorCodeIsNot => 'Tvåfaktorskoden är inte giltig.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Det verifierade körtidspaketet kunde inte markeras som körbart.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Det verifierade runtime-paketet saknar nödvändiga filer.';

  @override
  String get theWebAppCouldNotReach =>
      'Webbappen kunde inte nå NeoAgent-backend.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Webbappen kunde inte nå NeoAgent-backend på $arg1. Kontrollera webbläsarkonsolen och omvänd proxy/nätverkskonfiguration.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'själva; serveroperatören tar bort admin först med ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Dessa kanaler förblir tysta. För att höra från dem igen, lägg till dem under Vem kan meddelanden för den plattformen.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Dessa listor är valfria såvida inte ett avsnitt ovan är inställt på enbart godkänd.';

  @override
  String get thesePeopleAnywhere => 'Dessa människor, var som helst';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Dessa personer kan skicka meddelanden till $arg1 i privata chattar och i vilken grupp de delar.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Dessa personer kan skicka meddelanden till $arg1 en-till-en. Detta låter dem inte tala i grupp.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Dessa personer kan bara skicka meddelanden till $arg1 i gruppen du valt.';
  }

  @override
  String get thesePeopleInOneGroup => 'Dessa människor, i en grupp';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'dessa switchar, aldrig dina chattar, minnen eller filer.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Detta konto kommer att låsa upp NeoAgent på den här maskinen.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Denna agent kan delegera till alla berättigade mottagande agenter.';

  @override
  String get thisAgentIsUsingAServer =>
      'Den här agenten använder en serverhanterad Trello API-nyckel. Du behöver bara auktorisera ett kontotoken nedan.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Den här versionen får inte prata med den här NeoAgent-distributionen.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Den här koden tillhör en annan NeoAgent-server: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Detta skrivbord är anslutet';

  @override
  String get thisDevice => 'Denna enhet';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Denna enhet: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Den här enheten kan inte registrera säkerhetsnycklar. Öppna NeoAgent i en webbläsare över HTTPS för att lägga till en.';

  @override
  String get thisDeviceUnavailable => 'Den här enheten — inte tillgänglig';

  @override
  String get thisFileHasNoContent => 'Den här filen har inget innehåll.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Detta döljer \"$arg1\" från routing och val.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Denna integration stöder för närvarande ett anslutet konto per agent. Öppna inställningen igen för att ersätta den.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Denna integration är inte längre tillgänglig.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Detta intro är designat för liggande uppspelning i helskärm.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Detta är en hanterad distribution. Dess operatör rullar ut ';

  @override
  String get thisMayTakeAMoment => 'Detta kan ta en stund.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Denna MCP-server är inte längre konfigurerad.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Detta minne kommer att tas bort permanent.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Denna NeoAgent-build är inte konfigurerad för att verifiera backend-körtider.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Detta raderar permanent all din data och kan inte vara det ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Detta raderar permanent kontot och allt det äger: ';

  @override
  String get thisPersonAnywhere => 'Den här personen, var som helst';

  @override
  String get thisPersonInOneGroup => 'Den här personen, i en grupp';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Denna QR-inloggningsförfrågan har löpt ut. Skapa en ny kod och försök igen.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'denna qr-inloggningsförfrågan har löpt ut';

  @override
  String get thisQrLoginRequestIsStill =>
      'Denna QR-inloggningsförfrågan väntar fortfarande på godkännande.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Denna QR-inloggningsförfrågan har redan använts.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Detta tar bort Home Assistant-konfigurationen och den anslutna instansen för denna agent.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Detta tar bort NeoRecall backend-URL och alla anslutna NeoRecall-konton för denna agent.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Detta tar bort Nextcloud URL och alla anslutna Nextcloud-konton för denna agent.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Detta tar bort Trello-konfigurationen och anslutna konton för denna agent.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Detta kräver en autentiserad session på samma NeoAgent-server.';

  @override
  String get thisRunDidNotProduceA =>
      'Den här körningen gav inget svar mot användaren.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Denna körning har inga registrerade stegdata.';

  @override
  String get thisServer => 'denna server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Denna server rapporterar inga leverantörsinställningar.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Denna färdighet är inte längre installerad.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Den här uppgiften har ingen slutförd körning ännu, så den börjar fortfarande vid ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Den här uppgiften körs bara när du trycker på Kör nu.';

  @override
  String get thisWeek => 'Denna vecka';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Detta kommer att importera svaret till $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Detta tar bort \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Detta tar bort \"$arg1\" från serverlistan.';
  }

  @override
  String get time => 'Tid';

  @override
  String get timeZone => 'tidszon';

  @override
  String get timeZone2 => 'Tidszon';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Tidsgräns $arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Kunde inte lista tidszoner: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Kunde inte läsa enhetens tidszon: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Det gick inte att spara enhetens tidszon: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'till $arg1';
  }

  @override
  String get toUseTheServerDefault => 'för att använda serverns standard.';

  @override
  String get today => 'Idag';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Tokenbudget för @$arg1. Lämna ett fält tomt ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Tokenbudget för varje konto utan egen åsidosättning. Lämna en ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'token budgetgräns 4 timmar per vecka kvotanvändare';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token budgetgräns 4 timmars veckokvot globalt';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Tokenanvändning är inte tillgänglig på den här serverversionen.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokens kan alla konton använda inom 4 timmar.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens kan alla konton använda inom 7 dagar.';

  @override
  String get tokensPerDay => 'Poletter per dag';

  @override
  String get tokensPerRun => 'Poletter per körning';

  @override
  String get tokensToday => 'Tokens idag';

  @override
  String get tokensUsed => ' polletter som används';

  @override
  String get tomorrowPrep => 'Förberedelser imorgon';

  @override
  String get tooManyAttempts => 'för många försök';

  @override
  String get tooManySignInAttemptsPlease =>
      'För många inloggningsförsök. Vänta och försök igen.';

  @override
  String get tool => 'Verktyg';

  @override
  String get toolApproval => 'Verktygsgodkännande';

  @override
  String get toolApprovalRequired => 'Verktygsgodkännande krävs';

  @override
  String get toolCompleted => 'Verktyget färdigt';

  @override
  String get toolFailed => 'Verktyget misslyckades';

  @override
  String get toolPermissions => 'Verktygsbehörigheter';

  @override
  String get toolStarted => 'Verktyget startat';

  @override
  String get tools => 'Verktyg';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Verktyg som inte är inbyggda i NeoAgent, inklusive anslutna MCP-servrar och anpassade verktygsleverantörer.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Erbjudna verktyg ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Verktyg som det hanterade kontot kan använda';

  @override
  String get topUsers => 'Toppanvändare';

  @override
  String get topUsersAndRecentRuns => 'Toppanvändare och senaste körningar';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Totalt: $arg1-tokens över $arg2-körningar';
  }

  @override
  String get totalRuns => 'Totalt antal körningar';

  @override
  String get totalTokens => 'Totalt tokens';

  @override
  String get totalUsers => 'Totalt antal användare';

  @override
  String get transcript => 'Avskrift';

  @override
  String get transcript2 => 'TRANSKRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkription misslyckades: $arg1';
  }

  @override
  String get transfer => 'Överföring';

  @override
  String get trelloApiKey => 'Trello API-nyckel';

  @override
  String get trelloApiKeyIsRequired => 'Trello API-nyckel krävs.';

  @override
  String get trelloSetup => 'Trello-inställning';

  @override
  String get triggerType => 'Triggertyp';

  @override
  String get tryABroaderSearchLikeModels =>
      'Prova en bredare sökning som modeller, webbläsare eller röst.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Prova ett leverantörsnamn, \"e-post\", \"gränser\", \"uppdatering\" eller \"loggar\".';

  @override
  String get tryAgain => 'Försök igen';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Försök igen. Om detta fortsätter att hända, kör NeoAgent Doctor för att kontrollera datorns körtid.';

  @override
  String get tryAgainInAMoment => 'Försök igen om ett ögonblick.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Försök igen eller kör NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Försök med en annan sökning, anslut en meddelandeplattform eller ange ett destinations-ID manuellt.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Aktivera en grupp om $arg1 också ska läsa meddelanden som inte taggar den.';
  }

  @override
  String get turnOffComputer => 'Stäng av datorn';

  @override
  String get turnOffOnlyForAMail =>
      'Stäng endast av för en e-postserver med ett självsignerat certifikat.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Slå på om Signal ska fortsätta leta efter inkommande chattar.';

  @override
  String get turnTaking => 'turtagning';

  @override
  String get turnTakingModel => 'Turneringsmodell';

  @override
  String get turnTakingOff => 'Sväng-start';

  @override
  String get turnThisOffToKeepThis =>
      'Stäng av detta för att hålla denna agent helt åtskild från andra agenter.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Avstängd av $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Avstängd av $arg1, som hanterar detta konto. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Avstängd för dig av $arg1 — bara de kan ändra det';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Avstängd för dig, så du kan inte dela ut den';

  @override
  String get twitchChatOverIrc => 'Twitch chatt över IRC';

  @override
  String get twoFactorAuthentication => 'Tvåfaktorsautentisering';

  @override
  String get twoFactorChallengeExpired => 'tvåfaktorsutmaningen har löpt ut';

  @override
  String get twoFactorCode => 'tvåfaktorskod';

  @override
  String get twoFactorSignInCompletedBut =>
      'Tvåfaktorsinloggning slutförd, men NeoAgent kunde inte behålla webbläsarsessionen. Logga in igen.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Tvåstegsinloggning (endast om aktiverat)';

  @override
  String get type => 'Typ';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Skriv $arg1 för att bekräfta';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'typ text stöds inte på den här plattformen.';

  @override
  String get typedInTheBrowser => 'Skrivet i webbläsaren';

  @override
  String get typedText => 'Skriven text';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'det går inte att hitta en Java-runtime';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Det går inte att öppna tidsinställningarna på den här versionen.';

  @override
  String get unableToOpenWiFiSettings =>
      'Det går inte att öppna Wi-Fi-inställningarna på den här versionen.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Det går inte att bevara den valda skrivbordsvisningen.';

  @override
  String get unclearWhoItWasFor => 'Oklart vem det var till';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'ogjort. Skriv ditt användarnamn för att bekräfta.';

  @override
  String get unknownAccount => 'Okänt konto';

  @override
  String get unknownAgent => 'Okänd agent';

  @override
  String get unknownBrowser => 'Okänd webbläsare';

  @override
  String get unknownDevice => 'Okänd enhet';

  @override
  String get unknownError => 'okänt fel';

  @override
  String get unknownLocalComputerPermission => 'Okänd lokal datorbehörighet.';

  @override
  String get unknownLocation => 'Okänd plats';

  @override
  String get unknownPublishTime => 'Okänd publiceringstid';

  @override
  String get unknownSize => 'Okänd storlek';

  @override
  String get unlink => 'Ta bort länken';

  @override
  String get unreadOnly => 'Endast oläst';

  @override
  String get unsavedChanges => 'Osparade ändringar';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Skrivbordskommando som inte stöds: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Metod som inte stöds: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Ovanliga inloggningsvarningar';

  @override
  String updateArg1(Object? arg1) {
    return 'Uppdatera $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Uppdatera kärnminnesposter från importen.';

  @override
  String get updateNow => 'Uppdatera nu';

  @override
  String get updateReady => 'Uppdatering klar';

  @override
  String get updateSetup => 'Uppdatera inställningar';

  @override
  String get updateTheAccessListToAllow =>
      'Uppdatera åtkomstlistan för att tillåta svar.';

  @override
  String get updateTheServer => 'Uppdatera servern?';

  @override
  String get updateTheServer2 => 'Uppdatera servern';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Uppdatera tidszonen automatiskt från enheten du använder.';

  @override
  String updatedArg1(Object? arg1) {
    return 'uppdaterad $arg1';
  }

  @override
  String get updates => 'Uppdateringar';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Uppdateringar är inte konfigurerade för denna version.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'uppdateringar, så självuppdatering och kanaländringar är avstängda här.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'uppgraderingsuppdatering släpper nu kanalstabil beta';

  @override
  String get usageAnalytics => 'Användningsanalys';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Användnings- och hälsosignaler som hjälper till att förklara aktuellt körtidsbeteende utan att först gräva igenom loggar.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Användningen återställs helt i $arg1';
  }

  @override
  String get usageLeaderboard => 'topplista för användning';

  @override
  String get usageLimits => 'Användning & gränser';

  @override
  String get usageLimits2 => 'Användning & gränser';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Använd 8+ tecken. Längre lösenfraser fungerar bra.';

  @override
  String get useADateAndTimeFor =>
      'Använd ett datum och en tid, till exempel 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Använd ett namn, telefonnummer eller chatt-ID.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Använd en NeoRecall-URL som NeoAgent-servern kan nå. NeoAgents PUBLIC_URL måste också vara tillgänglig från den här webbläsaren för OAuth-återuppringning.';

  @override
  String get useANewPasswordWithAt =>
      'Använd ett nytt lösenord med minst 8 tecken.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Använd en Nextcloud-URL som NeoAgent-servern kan nå, till exempel https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Använd ett lösenord med minst 8 tecken.';

  @override
  String get useASecureConnectionTls => 'Använd en säker anslutning (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Använd en autentiseringsapp som Authy, 1Password eller Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Använd minst 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Max minne per dator (MB)';

  @override
  String get maxVcpusPerComputer => 'Max vCPU:er per dator';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Åtminstone $arg1. Datorer blir mindre när värden är upptagen.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Max minne måste vara minst $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Använd minst 8 tecken.';

  @override
  String get useDefault => 'Använd standard';

  @override
  String get useDefaultChannel => 'Använd standardkanal';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Använd standard (NeoAgent Workspace)';

  @override
  String get useFor => 'Använd för';

  @override
  String get useManualDestination => 'Använd manuell destination';

  @override
  String get useOrDoTheSameFor =>
      'använda, eller gör samma sak för dina lagkamrater.';

  @override
  String get usePerCategorySettingsBelow =>
      'Använd inställningarna per kategori nedan.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Använd standardinställningar ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Använd servern på den här datorn';

  @override
  String get useTheseForContextIfA =>
      'Använd dessa för sammanhang. Om en lokal URI inte är direkt tillgänglig från servern, be mig att tillhandahålla filen via en tillgänglig arbetsyta.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Använd detta för orkestratoragenter. Sluta för isolerade arbetsrobotar som borde avsluta direktmeddelanden själva.';

  @override
  String get useTlsFromTheStartOf =>
      'Använd TLS från början av anslutningen, vanligtvis på port 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Använd din egen API-nyckel för en leverantör, eller anslut en anpassad ';

  @override
  String get usedByEveryAccountOnThis =>
      'Används av alla konton på denna server som inte har någon nyckel ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Används för att verifiera att inkommande Slack-evenemang är äkta.';

  @override
  String get userSummary => 'Användarsammanfattning';

  @override
  String get username => 'Användarnamn';

  @override
  String get usernameOrEmail => 'Användarnamn eller e-post';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'användare människor söker e-post användarnamn admin badge hanterat team';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Använder chattmodellen som konfigurerats i Inställningar';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Använder den installerade NeoAgent runtime';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Ser vanligtvis ut som @bot:matrix.org';

  @override
  String get validEmail => 'giltig e-post';

  @override
  String get value => 'Värde';

  @override
  String get vaultLocked => 'Valv låst';

  @override
  String get vaultOperationFailed => 'Valvdrift misslyckades.';

  @override
  String get verification => 'Verifiering';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verifiering: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verifiering: $arg1';
  }

  @override
  String get verificationCompleted => 'Verifiering slutförd.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Verifieringsstatus: $arg1';
  }

  @override
  String get verifiedTheResult => 'Verifierade resultatet';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Verifierar den nedladdade körtiden';

  @override
  String get versionAndUptime => 'Version och drifttid';

  @override
  String versionArg1(Object? arg1) {
    return 'Version $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Version $arg1 är installerad, men $arg2 körs fortfarande.';
  }

  @override
  String get videoLinks => 'Videolänkar';

  @override
  String get viewDesktop => 'Visa skrivbordet';

  @override
  String get viewLastRun => 'Se senaste körningen';

  @override
  String get viewLogs => 'Visa loggar';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'vm bildminne cpu qemu runtime';

  @override
  String get voice => 'Röst';

  @override
  String get voiceAssistant => 'Röstassistent';

  @override
  String get voiceCall => 'RÖSTANrop';

  @override
  String get voiceCall2 => 'Röstsamtal';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'röstsamtal gpt-live gemini live modell tal realtid';

  @override
  String get voiceCallsRunOnALive =>
      'Röstsamtal körs på en levande tal-till-tal-modell med samma persona, minne och chatthistorik som NeoAgent. Den svarar direkt och ger verkligt arbete till den vanliga agenten, som fortsätter att köra i bakgrunden.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'röstanteckning tal transkription api-nyckel';

  @override
  String get voiceNotesAndDictation => 'Röstanteckningar och diktering';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Röstuppspelning är inte tillgänglig på den här enheten.';

  @override
  String get voiceReplyModel => 'Röstsvarsmodell';

  @override
  String get waitingForApproval => 'Väntar på godkännande: ';

  @override
  String get waitingForCode => 'Väntar på kod';

  @override
  String get waitingForInput => 'Väntar på input';

  @override
  String get waitingForServerOrFlutterLog =>
      'Väntar på server- eller Flutter-loggutdata...';

  @override
  String get waitingForTaskEvents => 'Väntar på uppgiftshändelser...';

  @override
  String get waitingForYou => 'väntar på dig';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Ville ha svar från $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Vill prata med dig · ${arg1}s';
  }

  @override
  String get weak => 'Svag';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Väder, kalender och prioriteringar innan din dag börjar.';

  @override
  String get weatherEvent => 'Väderhändelse';

  @override
  String get web => 'Webb';

  @override
  String get webBrowser => 'Webbläsare';

  @override
  String get webSearchApiKey => 'webbsökning API-nyckel';

  @override
  String get webhookOrRestChannelPosting => 'Webhook eller REST-kanalinlägg';

  @override
  String get webhookSecret => 'Webhook hemlighet';

  @override
  String get webhookUrlCopied => 'Webhook URL kopierad';

  @override
  String get weekdays => 'Vardagar';

  @override
  String get weekdays0730 => 'Vardagar · 07:30';

  @override
  String get weekdays1800 => 'Vardagar · 18:00';

  @override
  String get weekly => 'Varje vecka';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Veckogräns $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Veckogräns (tokens)';

  @override
  String get weeklyReview => 'Veckoöversyn';

  @override
  String get weeklyUsage => 'Veckovis användning';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Vikt $arg1 rekord';
  }

  @override
  String get welcomeToNeoagent => 'VÄLKOMMEN TILL NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Välkommen\ntill NeoAgent';

  @override
  String get whatAreYouAdding => 'Vad lägger du till?';

  @override
  String get whatIsOnTomorrow => 'Vad händer imorgon?';

  @override
  String get whatShouldNeoagentLearn => 'Vad ska NeoAgent lära sig?';

  @override
  String get whatShouldWeBuild => 'Vad ska vi bygga?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Det du och NeoAgent säger visas här och i chatten.';

  @override
  String get whatsappPersonalMessageReceived =>
      'WhatsApp personligt meddelande mottaget';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'När du väljer endast godkänd lägger du till personer eller grupper nedan.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies => 'Dit ombudet ska skicka svar.';

  @override
  String get whoCanMessage => 'Vem kan skicka meddelanden';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Vem kan skicka meddelanden på $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Vem kan skicka ett en-till-en-meddelande till $arg1.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Vem kan prata med $arg1 i en grupp, kanal eller rum.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'vem som hanterar detta konto avstängt: ';

  @override
  String get whoManagesWhom => 'Vem styr vem';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Den som accepterar en länk går med i ditt team med bara verktygen den ';

  @override
  String get wholeGroup => 'Hela gruppen';

  @override
  String get wholeGroups => 'Hela grupper';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Varför $arg1 svarade eller var tyst i $arg2-grupper.';
  }

  @override
  String get windowsApp => 'Windows-appen';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Arbetskonto';

  @override
  String get workOnAProjectWithNeoagent =>
      'Arbeta med ett projekt med NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Arbetsflöde: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Arbetar i $arg1 på molndatorn. NeoAgent läser och redigerar filer där och kan köra kommandon och en webbläsare.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Arbetar i bakgrunden: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Arbetsplatskonfiguration och kontosäkerhet på ett ställe.';

  @override
  String get workspaceFiles => 'Arbetsyta filer';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Arbetsyta, modeller och diagnostikkontroller.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Åsidosättande av arbetsyta måste vara en absolut väg.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Skrev $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest-fel';

  @override
  String get yesterday => 'Igår';

  @override
  String get youAreInControl => 'Du har kontroll';

  @override
  String get youCanFollowAlongOnThe => 'Du kan följa med på skrivbordet.';

  @override
  String get youCanLeaveATeamAt =>
      'Du kan lämna ett lag när som helst; dina egna inställningar gäller igen.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Du kan lämna när som helst från Team-sidan.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Du bestämmer vilka verktyg din agent får använda, under Inställningar › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Du hanterar ingen ännu. Skapa en inbjudningslänk nedan och ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Du har osparade inställningar. Vad skulle du vilja göra?';

  @override
  String get youReOnYourOwnYou =>
      'Du är på egen hand: du bestämmer vilka verktyg din agent får använda. Om ';

  @override
  String get yourAccountAndUsageOnA =>
      'ditt konto -- och användning på en modell som backas upp av din egen nyckel ';

  @override
  String get yourAccountHasBeenDeleted => 'Ditt konto har raderats.';

  @override
  String get yourAgentWillBeAllowed => 'Din agent kommer att tillåtas:';

  @override
  String get yourAppsAndFilesAreSaved => 'Dina appar och filer sparas.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Dina appar och filer förblir sparade.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Din $arg1 nyckel';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Ditt assistentlager för fångst, sammanhang och handling.';

  @override
  String get yourComputerIsAsleep => 'Din dator ligger i viloläge';

  @override
  String get yourComputerIsOff => 'Din dator är avstängd';

  @override
  String get yourComputerIsReady => 'Din dator är klar';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Ditt nuvarande lösenord är felaktigt.';

  @override
  String get yourData => 'Dina data';

  @override
  String get yourDataExportWasCopiedTo =>
      'Din dataexport kopierades till urklipp.';

  @override
  String get yourDesktopIsReady => 'Ditt skrivbord är klart';

  @override
  String get yourLinuxComputer => 'Din Linux-dator';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Din plats spåras aldrig kontinuerligt eller lagras på våra servrar. Vi använder det bara lokalt för att kontrollera dina aktiva uppgifter.';

  @override
  String get yourManager => 'din chef';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Din Mattermost-webbadress, om du använder REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Din session löpte ut eller behölls inte av webbläsaren. Logga in igen.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Din session har löpt ut. Logga in igen.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Ditt användarnamn eller lösenord är felaktigt.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Översikt';

  @override
  String get sectionDiagnostics => 'Diagnostik';

  @override
  String get sectionVolume => 'Volym';

  @override
  String get sectionSession => 'Session';

  @override
  String get sectionDeliverable => 'Levereras';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Den lokala körtiden har inte skrivit någon loggfil ännu.';

  @override
  String get thisComputer => 'Den här datorn';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta installerar den senaste förversionen av backend. Räkna med grova kanter.';

  @override
  String get copiedFinalResponse => 'Kopierade slutsvar';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Det sista svaret visas här när körningen är klar.';

  @override
  String get waitingForTheFirstStep => 'Väntar på första steget...';

  @override
  String get loadingPrompt => 'Laddar uppmaning...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Inget slutligt svar fångades för denna körning.';

  @override
  String get readyToSignIn => 'Klar att logga in';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Byt till \"Standard\" eller \"Fråga alltid\" för att återaktivera godkännandekontroller.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Skicka en styruppdatering eller nästa notering för den aktuella körningen...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Ingen nätverksanslutning. NeoAgent kommer att återansluta när enheten är online igen.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Tillämpade den senaste styruppdateringen på den aktuella körningen.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Förbereder den privata röstsessionen...';

  @override
  String get preparingYourComputer => 'Förbereder din dator';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent laddar ner och förbereder det säkra Linux-systemet. Detta händer bara första gången.';

  @override
  String get moreFreeSpaceIsNeeded => 'Mer ledigt utrymme behövs';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Frigör lite diskutrymme på NeoAgent-värden och försök sedan igen. Din befintliga datordata är säker.';

  @override
  String get androidReady => 'Android redo';

  @override
  String get startingAndroid2 => 'Startar Android...';

  @override
  String get androidStopped => 'Android stannade';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Den första starten laddar ner Android SDK och systemavbildning, vilket kan ta flera minuter.';

  @override
  String get androidIsStopped => 'Android är stoppat';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Starta den hanterade Android-miljön när du behöver den.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Låt NeoAgent arbeta på den här datorn';

  @override
  String get firstTimeSetupIsInProgress => 'Förstagångsinstallationen pågår.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent kan använda den åtkomst du tillåter.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Frigör lite värdlagring och försök igen.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Börja när du vill att NeoAgent ska hjälpa till här.';

  @override
  String get systemPermissionMissing => 'Systembehörighet saknas';

  @override
  String get connectingThisDevice => 'Ansluter den här enheten';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Den säkra lokala anslutningen upprättas.';

  @override
  String get recordingYourDemonstration => 'Spelar in din demonstration';

  @override
  String get noErrorsInTheRecentLog => 'Inga fel i den senaste loggen.';

  @override
  String get loadingAccounts => 'Läser in konton...';

  @override
  String get neverSignedIn => 'Aldrig inloggad';

  @override
  String get emptyUsesTheServerDefault => 'Empty använder serverns standard.';

  @override
  String get followTheSelectedSession => 'Följ den valda sessionen';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Endast planläge inspekterar. Växla till agentläge för att låta NeoAgent redigera filer.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Krävs för att lägga till eller ändra e-postadressen för ditt konto.';

  @override
  String get confirmNewPassword => 'Bekräfta nytt lösenord';

  @override
  String get passwordChanged => 'Lösenord ändrat.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Denna begäran har redan använts.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Denna begäran har upphört att gälla. Be den andra enheten att generera en ny kod.';

  @override
  String get startQuickstart => 'Starta snabbstart';

  @override
  String get createYourAccount => 'Skapa ditt konto';

  @override
  String get showWorkAsSummaries => 'Visa arbete som sammanfattningar';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokens som används av den senaste körningen';

  @override
  String get listedTheWorkspaceRoot => 'Listade arbetsytans rot';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Inga officiella integrationer är tillgängliga ännu.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Inga MCP-servrar har konfigurerats ännu. Lägg till en för att exponera dess verktyg.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Lägg till en MCP-server eller installera en färdighet för att komma igång.';

  @override
  String get setUp => 'Ställ in';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Lämna tomt för att behålla det lagrade värdet';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Detta tar bort adressen för varje konto på denna server.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Prata bara. Du kan avbryta när som helst. Tryck för att stänga av ljudet.';

  @override
  String get tapAgainWhenYouAreDone => 'Tryck igen när du är klar.';

  @override
  String get workingOnATaskInTheBackground =>
      'Arbetar med en uppgift i bakgrunden.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Tal-till-tal med samma minne, verktyg och chatthistorik som NeoAgent.';

  @override
  String get checkLink => 'Kolla länken';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Din agent kommer inte att tillåtas något av de kontrollerade verktygen.';

  @override
  String get notYoursToChange => 'Inte din att ändra';

  @override
  String get setByYou => 'Set av dig';

  @override
  String get noTools => 'Inga verktyg';

  @override
  String get untitledLink => 'Namnlös länk';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Slutar fungera efter att en person har löst in det.';

  @override
  String get theOperator => 'Operatören';

  @override
  String get smartSelectorOn => 'Smart väljare på';

  @override
  String get startASessionToBegin => 'Starta en session för att börja';

  @override
  String get steerTheActiveRun => 'Styr den aktiva körningen...';

  @override
  String get describeWhatToPlan => 'Beskriv vad du ska planera...';

  @override
  String get stopDictation => 'Sluta diktera';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Meddelanden styr den aktuella körningen · ⌘↵ skicka · ⌘. sluta';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Planläge inspekterar endast; ingenting ändras förrän du implementerar · ⌘↵ skicka';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agenten redigerar arbetsytan. Plan endast inspekterar.';

  @override
  String get defaultModel => 'Standardmodell';

  @override
  String get openingScanner => 'Öppnar skanner...';

  @override
  String get theAgentCanUseThisSkill => 'Agenten kan använda denna färdighet.';

  @override
  String get allSelected => 'Alla valda';

  @override
  String get addCoreMemoryEntry => 'Lägg till kärnminne';

  @override
  String get channelId => 'Kanal-ID';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'AI-skapade och ospecificerade uppgifter använder den nuvarande standarden.';

  @override
  String get waitingForRunEvents => 'Väntar på körevenemang...';

  @override
  String get hideSteps => 'Dölj steg';

  @override
  String get commitTheActiveLiveCapture => 'Begå den aktiva liveinspelningen';

  @override
  String get stopCaptureAndSubmit => 'Sluta fånga och skicka in';

  @override
  String get clickTheMicToStartSpeaking =>
      'Klicka på mikrofonen för att börja tala';

  @override
  String get connectACustomEndpoint => 'Anslut en anpassad slutpunkt';

  @override
  String get hostedProvider => 'värdleverantör.';

  @override
  String get muted => ' • avstängd';

  @override
  String get addWhoCanMessage => 'Lägg till vem som kan meddelande';

  @override
  String get joinsGroupConversations => 'Går med i gruppkonversationer';

  @override
  String get label1PersonOrGroupAdded => '1 person eller grupp har lagts till';

  @override
  String get inProgress => 'Pågår';

  @override
  String get waitingForUpdateJobOutput => 'Väntar på uppdateringsjobb...';

  @override
  String get taskTrigger => 'Uppgiftsutlösare';

  @override
  String get bearerToken => 'Bärartoken';

  @override
  String get bearerToken2 => 'Bearer Token';

  @override
  String get notRecorded => 'Ej inspelat';

  @override
  String get sessionCookie => 'Sessionskaka';

  @override
  String get neverUsed => 'Aldrig använd';

  @override
  String get linkedRecently => 'Länkade nyligen';

  @override
  String get notUsedYet => 'Inte använd ännu';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Ett eller flera konton har löpt ut. Återanslut för att återställa åtkomst. Om detta fortsätter att hända kan din Google Cloud OAuth-app vara i testläge – publicera den till produktion i Google Cloud Console för att få långlivade tokens.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Valv anslutet och tillgängligt efter omstart';

  @override
  String get vaultConnectedForThisSession =>
      'Arkiv anslutet för den här sessionen';

  @override
  String get connectAnotherAccount => 'Anslut ett annat konto';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Klistra in ersättande Long-Lived Access Token';

  @override
  String get updateInstance => 'Uppdatera instans';

  @override
  String get pasteAReplacementToken => 'Klistra in en ersättningstoken';

  @override
  String get replaceAccount => 'Byt konto';

  @override
  String get addAccount => 'Lägg till konto';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Kan delegera till alla mottagande ombud';

  @override
  String get canReceiveDelegatedTasks2 => 'kan ta emot delegerade uppgifter';

  @override
  String get noSyncYet => 'Ingen synkronisering ännu';

  @override
  String get noNewData => 'Inga nya uppgifter';

  @override
  String get syncOnceToSeedYourBackend =>
      'Synkronisera en gång för att se din backend.';

  @override
  String get lastWindowEndIsUnknown => 'Sista fönsterslutet är okänt.';

  @override
  String get lastNonEmptySync => 'Senaste icke-tom synkronisering';

  @override
  String get stopTranscribe => 'Stoppa och transkribera';

  @override
  String get steeringMode => 'Styrläge';

  @override
  String get noMessageText => 'Ingen meddelandetext';

  @override
  String get reconnectingToServer => 'Återansluter till servern...';

  @override
  String get signingIn => 'Loggar in...';

  @override
  String get noGroupsFoundYet => 'Inga grupper hittades ännu';

  @override
  String get onForNewGroupsOnly => 'Endast på för nya grupper';

  @override
  String get noGroupsInThisCategory => 'Inga grupper i denna kategori';

  @override
  String get groupOrChannel => 'Grupp eller kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Anteckningar du skriver till dig själv startar en löprunda och svar landar i samma chatt. Tillståndslistan gäller inte här.';

  @override
  String get needToReply => 'Behöver svara';

  @override
  String get enter2faCode => 'Ange 2FA-kod';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Öppna din autentiseringsapp och ange den aktuella NeoAgent-koden.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Har du redan ett konto? Logga in';

  @override
  String get serverOnThisComputer => 'Server på den här datorn';

  @override
  String get showQrCode => 'Visa QR-kod';

  @override
  String get createAnotherNeoagentAccount => 'Skapa ett annat NeoAgent-konto.';

  @override
  String get canCoordinateDelegatedWork => 'Kan samordna delegerat arbete';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'NeoAgent runtime-arkivet kunde inte extraheras.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'NeoAgent-körtidsarkivet kunde inte läsas.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'NeoAgent runtime-arkivet innehåller en osäker sökväg.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'NeoAgent runtime-arkivet innehåller en osäker länk.';

  @override
  String get installingAppPackageOnThePhone =>
      'Installerar apppaket på telefonen...';

  @override
  String get dragAndDropAApkOrApks =>
      'Dra och släpp en .apk- eller .apks-fil här, eller klicka för att bläddra.';

  @override
  String get releaseToInstallThisPackage =>
      'Släpp för att installera det här paketet';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Säkerhetsnyckeln kunde inte användas.';

  @override
  String get connecting => 'Ansluter...';

  @override
  String get changes => 'Ändringar';

  @override
  String get runtimeReady => 'Körtid klar';

  @override
  String get saving => 'Sparar...';

  @override
  String get earlier => 'Tidigare';

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
  String get steeringWord => 'Styrning';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Detta växlar backend från $arg1-kanalen till $arg2-kanalen.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1 cookies importerade';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '$arg1 sedan';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Köstyrning: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Webbappen kunde inte nå NeoAgent-backend.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Webbläsaren blockerade en obligatorisk begäran på grund av innehållssäkerhetspolicy.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 av 4 tillåtna';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Arbeta igenom uppgiften som vanligt.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Ändringar · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Denna enhet · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Gränsen nådd $arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 återställningskoder är fortfarande tillgängliga.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Säkerhetsnyckel $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Aktuell session';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nSenast använd: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Arbetar i $arg1 på den här enheten. NeoAgent läser och redigerar mappen direkt och kan köra kommandon, öppna appar och använda skärmen.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Har jobbat för $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Tillåtet av $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 inbjudningslänkar från $arg2 återkallades';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Lägg till personerna och grupperna $arg1 ska prata med';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Lägg till personer och grupper $arg1 får prata med.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Där $arg1 lyssnar';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 tittar på dessa platser för omnämnanden. Alla kan göra inlägg här, så folk behöver fortfarande sitt eget godkännande nedan.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Dessa personer kan fråga $arg1 var de än taggar den. Roller räknas endast på de platser som anges ovan.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Endast när $arg1 är taggad';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'På för alla $arg1-grupper';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 hör fortfarande bara personer och grupper som du redan har godkänt. Detta låter bara $arg1 gå med i vanlig chatt där, inte bara taggar och svar.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 hör fortfarande bara personer och grupper som du redan har godkänt. Detta väljer bara vilken av dessa grupper den ska gå med i.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Om någon taggar $arg1 eller svarar svarar $arg1 alltid. Aktivera detta om $arg1 också skulle höra in på vanlig gruppchatt.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nya grupper låter $arg1 gå med i vanlig chatt med godkända personer, tills du stänger av dem.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nya grupper låter $arg1 gå med i vanlig chatt tills du stänger av dem.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nya grupper förblir tysta om inte en godkänd person taggar $arg1, tills du slår på dem.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Endast när en godkänd person taggar $arg1, såvida du inte aktiverar en grupp';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Endast när $arg1 är taggad, såvida du inte aktiverar en grupp';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 av $arg2-grupper går med i vanlig chatt med godkända personer';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Detta godkänner inte nya människor. Taggar och svar från godkända personer får alltid svar. Slå på en grupp om $arg1 också ska gå med i vanlig chatt där.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Detta godkänner inte nya människor. Aktivera en grupp om $arg1 ska gå med i vanlig chatt med personer som du redan har godkänt.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Taggar och svar får alltid ett svar. Slå på en grupp om $arg1 också ska gå med i vanlig chatt där.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 går med i vanlig chatt med godkända personer';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 kan gå med i vanlig chatt';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 svarar bara när en godkänd person taggar den';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Inget extra behövs. Anslut för att börja använda $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Uppdaterar i ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registrera dig med $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Inga minnen kopplade till \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (standard)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filial: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 går endast med i de grupper och kanaler du lägger till nedan.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 krävs för att lokalisera NeoAgent runtime-data.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[trunkerad förhandsvisning, totalt $arg1 byte]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakt begränsad, $arg1 byte totalt]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' i $arg1';
  }

  @override
  String get worldNews => 'Världsnyheter';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Kör när nya världsrubriker dyker upp. Din uppmaning avgör om du vill meddela dig.';

  @override
  String get newsKeywordsOptional => 'Sökord (valfritt)';

  @override
  String get worldNewsSetup => 'World News Setup';

  @override
  String get connectWorldNewsWithGnews =>
      'Lägg till en GNews API-nyckel (gratis plan tillgängligt på gnews.io). Den lagras krypterad och används för att ställa frågor om topprubriker efter World News-utlösare.';

  @override
  String get gnewsApiKey => 'GNews API-nyckel';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Klistra in ersättningsnyckel för GNews API';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Lämna nyckeln tom för att behålla den för närvarande lagrade nyckeln.';

  @override
  String get gnewsApiKeyIsRequired => 'En GNews API-nyckel krävs.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Det gick inte att spara World News-inställningarna.';

  @override
  String get disconnectWorldNews => 'Koppla bort World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Detta tar bort den lagrade GNews API-nyckeln. World News triggers kommer att sluta aktiveras tills du lägger till en nyckel igen.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Det gick inte att koppla bort World News.';

  @override
  String get systemOneModels => 'SystemOne-modeller';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Väljer den bästa tillgängliga SystemOne-modellen';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Chattmodellen fattar dessa beslut';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Beslutsmodeller som gör samtalen bakom kulisserna på en bråkdel av en sekund: turtagning i gruppchatt och webbläsarsteg. Din chattmodell skriver fortfarande varje svar.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'SystemOne-modellen bestämmer när den ska tala medan den är på; denna modell är en reserv.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 gjorde mål av SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne gjorde det här meddelandet direkt. Ingen språkmodell körde.';

  @override
  String get systemOneUnavailable => 'SystemOne är inte tillgänglig';

  @override
  String get systemOneAdminAvailability =>
      'Beslutsmodeller som agenter kan välja under Inställningar › Modeller. En modell som är avstängd här lämnar plockaren och agenter som valde den faller tillbaka till Auto. Medan alla modeller är avstängda, startar SystemOne-modeller som leverantörer lägger till senare också avstängda.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Inga SystemOne-modeller än. Lägg till en TypeSafe- eller OpenRouter-nyckel under Providers, eller dra en beslutsmodell som nimble i Ollama 0.35 eller senare.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Ingen SystemOne-modell är tillgänglig ännu. Lägg till en TypeSafe- eller OpenRouter-nyckel under Inställningar › Modeller › Ta med din egen nyckel, eller dra en beslutsmodell som till exempel kvick i Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system ett beslut modeller jev typesafe openrouter ollama tillgänglighet aktivera inaktivera';

  @override
  String get chatModels => 'Chattmodeller';

  @override
  String get disabled => 'Inaktiverad';

  @override
  String get enableShown => 'Aktivera visas';

  @override
  String get disableShown => 'Inaktivera visas';

  @override
  String get expandAll => 'Utöka alla';

  @override
  String get collapseAll => 'Komprimera alla';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 osparade ändringar';
  }

  @override
  String get settingsScopeAllAgents => 'Alla agenter';

  @override
  String get settingsScopeAgent => 'Denna agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'Samma överallt där du loggar in';

  @override
  String get settingsScopeAllAgentsHint => 'Delas av alla dina agenter';

  @override
  String get settingsAppliesTo => 'Gäller';

  @override
  String get settingsSaving => 'Sparar...';

  @override
  String get settingsSavedAutomatically => 'Ändringar sparas automatiskt';

  @override
  String get settingsSearchHint => 'Sök i alla inställningar';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Inloggning och säkerhet';

  @override
  String get settingsPageUsage => 'Användning';

  @override
  String get settingsPagePermissions => 'Behörigheter';

  @override
  String get settingsPageComputer => 'Dator & webb';

  @override
  String get settingsPageBehavior => 'Beteende';

  @override
  String get settingsPageSystem => 'System';

  @override
  String get settingsPagePlatforms => 'Plattformar';

  @override
  String get settingsPageProfileDescription =>
      'Ditt namn och e-postadress, en kopia av dina uppgifter och utloggning.';

  @override
  String get settingsPageSecurityDescription =>
      'Lösenord, tvåfaktorsautentisering, säkerhetsnycklar och var du är inloggad.';

  @override
  String get settingsPageUsageDescription =>
      'Dina gränser och tokenutgifter, allt på ett ställe.';

  @override
  String get settingsPageAgentsDescription =>
      'Skapa agenter och välj vilken som svarar som standard.';

  @override
  String get settingsPagePermissionsDescription =>
      'Vad dina agenter kan göra utan att fråga dig först.';

  @override
  String get settingsPageComputerDescription =>
      'Datorn som dina agenter arbetar på och de webbplatser de kan läsa som du.';

  @override
  String get settingsPageModelsDescription =>
      'Vilka modeller den här agenten använder och vilka API-nycklar som betalar för dem.';

  @override
  String get settingsPageBehaviorDescription =>
      'Hur den här agenten pratar och hur den läser en gruppchatt.';

  @override
  String get settingsPageVoiceDescription =>
      'Livesamtal, diktering och talade svar för denna agent.';

  @override
  String get settingsPageMessagingDescription =>
      'Var människor kan nå den här agenten och hur den beter sig i chattar.';

  @override
  String get settingsPageGeneralDescription =>
      'Utseende, språk, tidszon och vad den här appen gör i bakgrunden.';

  @override
  String get settingsPageSystemDescription =>
      'Servern som det här fönstret använder, den på den här datorn och appuppdateringar.';

  @override
  String get settingsYourAgents => 'Dina agenter';

  @override
  String get settingsChatModel => 'Chattmodell';

  @override
  String get settingsChatModelDescription => 'Svarar på dina meddelanden.';

  @override
  String get settingsSubAgentModel => 'Underagentmodell';

  @override
  String get settingsSubAgentModelDescription =>
      'Kör arbete som lämnats över under en uppgift.';

  @override
  String get settingsDefaultModels => 'Standardmodeller';

  @override
  String get settingsDefaultModelsDescription =>
      'Används när en chatt eller uppgift inte väljer sin egen modell.';

  @override
  String get settingsModelPool => 'Modell pool';

  @override
  String get settingsApiKeysDescription =>
      'Använd dina egna nycklar eller slutpunkt för denna agent. Nycklar är krypterade och visas aldrig igen.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Finjustering';

  @override
  String get settingsFineTuningDescription =>
      'Behövs sällan. Standardinställningarna passar de flesta chattar.';

  @override
  String get settingsShow => 'Visa';

  @override
  String get settingsHide => 'Göm';

  @override
  String get settingsMinimumContribution => 'Minsta bidragsvärde';

  @override
  String get settingsBatchWindow => 'Rumssatsfönster';

  @override
  String get settingsBatchWindowDescription =>
      'Väntar så här länge för att behandla snabba meddelanden som en sväng.';

  @override
  String get settingsHandsFree => 'Handsfree';

  @override
  String get settingsHandsFreeDescription =>
      'Prata fritt och avbryt när som helst.';

  @override
  String get settingsPushToTalkDescription =>
      'Håll för att prata, släpp för att skicka.';

  @override
  String get settingsLiveVoice => 'Levande röst';

  @override
  String get settingsChannels => 'Kanaler';

  @override
  String get settingsGroupChats => 'I gruppchattar';

  @override
  String get settingsGroupChatsDescription =>
      'Hur den här agenten beter sig i grupper på varje kanal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Aktivera beteendemoduler i Beteende för att ändra dessa.';

  @override
  String get settingsParticipationAutomatic => 'Automatisk';

  @override
  String get settingsParticipationMentionOnly => 'Nämn endast';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Läser rummet och hänger med när det har något nyttigt att tillföra.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Svarar endast när de nämns eller besvaras.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Svarar på varje meddelande.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Delar upp längre svar i korta meddelanden, som en person skulle göra.';

  @override
  String get settingsDeliverySingleDescription =>
      'Skickar varje svar som ett meddelande.';

  @override
  String get settingsComputerStatus => 'Status';

  @override
  String get settingsTest => 'Testa';

  @override
  String get settingsAppearance => 'Utseende';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Ljust';

  @override
  String get settingsThemeDark => 'Mörkt';

  @override
  String get settingsCloseWindow => 'När du stänger fönstret';

  @override
  String get settingsCloseAsk => 'Fråga';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent fortsätter att köras i bakgrunden och förblir nåbar.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent slutar helt.';

  @override
  String get settingsPhoneTriggers => 'Telefonutlösare';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signaler som den här telefonen skickar till dina agenter så att uppgifter kan reagera på dem.';

  @override
  String get settingsLocationTriggers => 'Platsutlösare';

  @override
  String get settingsLocationTriggersDescription =>
      'Kontrollerar din ungefärliga plats med några minuters mellanrum mot de platser som dina uppgifter tittar på.';

  @override
  String get settingsNotificationTriggers => 'Aviseringsutlösare';

  @override
  String get settingsNotificationTriggersDescription =>
      'Vidarebefordrar aviseringar från andra appar på den här telefonen till dina agenter.';

  @override
  String get settingsSetup => 'Inställning';

  @override
  String get settingsOnboarding => 'Onboarding';

  @override
  String get settingsOnboardingDescription =>
      'Gå igenom första körningen igen. Inget du ställer in går förlorat.';

  @override
  String get settingsUsernameDescription =>
      'Används för att logga in. Det går inte att ändra.';

  @override
  String get settingsExport => 'Exportera';

  @override
  String get settingsLeave => 'Logga ut och ta bort';

  @override
  String get settingsSignOutDescription =>
      'Loggar endast ut dig på den här enheten.';

  @override
  String get settingsDeleteAccountDescription =>
      'Raderar ditt konto, agenter, minne och inställningar. Detta kan inte ångras.';

  @override
  String get settingsTokenUsage => 'Tokenanvändning';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Ingen inställning matchar \"$query\".';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count träffar',
      one: '$count träff',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Avancerade modellinställningar';

  @override
  String get settingsAdvancedModelsDescription =>
      'Valfritt. Fäst en modell till en typ av arbete; det tar över närhelst agenten använder dessa verktyg. Allt som är kvar på standard följer chattmodellen.';

  @override
  String get settingsTaskModelDefault => 'Standard';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Följer chattmodellen';

  @override
  String get settingsTaskModelCoding => 'Kodning';

  @override
  String get settingsTaskModelCodingDescription =>
      'Skriva, redigera och felsöka kod.';

  @override
  String get settingsTaskModelComputerUse => 'Datoranvändning';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Kör webbläsaren och skrivbordet.';

  @override
  String get settingsTaskModelAndroidUse => 'Android-användning';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Använda appar på en Android-enhet eller emulator.';

  @override
  String get settingsTaskModelResearch => 'Forskning';

  @override
  String get settingsTaskModelResearchDescription =>
      'Söka, läsa och sammanfatta källor.';

  @override
  String get knowledgeGraphHint =>
      'Dina mest nämnda enheter, färgade efter kluster. Linjer förbinder enheter som förekommer i samma minnen. Tryck på en för att se dess länkar och minnen; dra för att panorera, nypa eller Ctrl/⌘-rulla för att zooma.';

  @override
  String get linkedEntities => 'Länkade enheter';

  @override
  String get noLinkedEntities => 'Inte länkad till andra enheter ännu.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 nämner';
  }

  @override
  String get entityKindConcept => 'Koncept';

  @override
  String get entityKindDomain => 'Domän';

  @override
  String get entityKindEmail => 'E-post';

  @override
  String get entityKindLink => 'Länk';

  @override
  String get entityKindFile => 'Arkiv';

  @override
  String get entityKindAcronym => 'Akronym';

  @override
  String get entityKindIdentifier => 'Identifierare';

  @override
  String get entityKindVersion => 'Version';

  @override
  String get openFullscreen => 'Öppna helskärm';

  @override
  String get zoomIn => 'Zooma in';

  @override
  String get zoomOut => 'Zooma ut';

  @override
  String get searchEntities => 'Hitta en enhet';

  @override
  String get incomingCall => 'Inkommande samtal';

  @override
  String get answerCall => 'Svara';

  @override
  String get callMeLater => 'Ring mig senare';

  @override
  String get callingEllipsis => 'Ringer...';

  @override
  String get reconnectingCall => 'Återansluter';

  @override
  String get agentWorking => 'Arbetar';

  @override
  String get micMuted => 'Dämpad';

  @override
  String get speakerphone => 'Högtalare';

  @override
  String get muteMic => 'Ljud av';

  @override
  String get unmuteMic => 'Slå på ljudet';

  @override
  String get releaseToSend => 'Släpp för att skicka';

  @override
  String get callEnded => 'Samtalet avslutades';

  @override
  String get openConversation => 'Öppna konversation';

  @override
  String get callBack => 'Ring tillbaka';

  @override
  String get letCallsReachYou => 'Låt samtal nå dig';

  @override
  String get callPermissionsIntro =>
      'Dina agenter kan ringa dig. För att ringa som ett telefonsamtal medan NeoAgent är i bakgrunden eller din telefon är låst behöver den dessa.';

  @override
  String get showOverOtherApps => 'Visa över andra appar';

  @override
  String get showOverOtherAppsDetail => 'Får upp samtalsskärmen var du än är.';

  @override
  String get fullScreenCalls => 'Helskärmssamtal';

  @override
  String get fullScreenCallsDetail => 'Ringer över låsskärmen.';

  @override
  String get unrestrictedBattery => 'Obegränsat batteri';

  @override
  String get unrestrictedBatteryDetail =>
      'Håller NeoAgent uppkopplad så att samtal kommer fram.';

  @override
  String get permissionAllowed => 'Tillåtet';

  @override
  String get triggerSectionCalendar => 'Kalender';

  @override
  String get triggerSectionFiles => 'Filer och dokument';

  @override
  String get triggerSectionHome => 'Hem och media';

  @override
  String get triggerSectionDevices => 'Enheter och platser';

  @override
  String get triggerSectionTasks => 'Uppgifter';

  @override
  String get messagingMemberJoined => 'Medlem gick med';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Kör när någon går med i en Discord-server, Telegram- eller WhatsApp-grupp, Slack-kanal eller Matrix-rum.';

  @override
  String get messagingMemberLeft => 'Medlem lämnade';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Kör när någon lämnar en Discord-server, Telegram- eller WhatsApp-grupp, Slack-kanal eller Matrix-rum.';

  @override
  String get messagingReactionAdded => 'Reaktion tillagd';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Kör när en tillåten person reagerar på ett meddelande i en privat chatt.';

  @override
  String get messagingPlatformDisconnected => 'Meddelanden har kopplats bort';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Kör när en meddelandeanslutning stoppas och behöver dig, till exempel efter en utloggning.';

  @override
  String get googleCalendarEventStarting => 'Google Kalender-händelse startar';

  @override
  String get googleCalendarEventCreated => 'Google Kalender-händelse skapad';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Kör när en ny händelse eller inbjudan dyker upp.';

  @override
  String get outlookCalendarEventStarting =>
      'Outlook-kalenderhändelsen startar';

  @override
  String get nextcloudCalendarEventStarting =>
      'Nextcloud Kalender-händelse startar';

  @override
  String get runMinutesBeforeEachEvent =>
      'Kör ett visst antal minuter före varje evenemang.';

  @override
  String get googleDriveFileAdded => 'Google Drive-fil har lagts till';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Kör när en fil läggs till på Drive eller en mapp i den.';

  @override
  String get googleSheetsRowAdded => 'Google Kalkylark-raden har lagts till';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Kör när nya rader dyker upp i ett ark.';

  @override
  String get onedriveFileAdded => 'OneDrive-fil har lagts till';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Kör när en fil läggs till i en OneDrive-mapp.';

  @override
  String get nextcloudFileAdded => 'Nextcloud-filen har lagts till';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Kör när en fil läggs till i en Nextcloud-mapp.';

  @override
  String get nextcloudShareReceived => 'Nextcloud-fil delad med dig';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Kör när någon delar en fil eller mapp med dig.';

  @override
  String get notionItemAdded => 'Begreppsdatabasobjekt har lagts till';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Kör när ett objekt läggs till i en Notion-databas.';

  @override
  String get notionItemUpdated => 'Begreppsdatabasobjekt uppdaterat';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Kör när ett objekt i en Notion-databas ändras.';

  @override
  String get trelloCardEnteredList => 'Trello-kort har lagts till i listan';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Kör när ett kort skapas i eller flyttas till en lista.';

  @override
  String get figmaCommentAdded => 'Figma kommentar tillagd';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Kör när någon kommenterar en Figma-fil.';

  @override
  String get githubPrOpened => 'GitHub pull-begäran har öppnats';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Kör när en ny pull-begäran öppnas i ett arkiv.';

  @override
  String get githubWorkflowRunFailed =>
      'Körningen av GitHub-arbetsflödet misslyckades';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Kör när en GitHub Actions-körning misslyckas.';

  @override
  String get githubCommitPushed => 'GitHub commit pushad';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Kör när nya commits når en filial.';

  @override
  String get mcpServerFailed => 'MCP-servern misslyckades';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Kör när en MCP-server som fungerade misslyckas eller behöver logga in.';

  @override
  String get homeAssistantStateChanged =>
      'Hemassistentens tillstånd har ändrats';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Kör när en enhet ändras, når ett tillstånd eller korsar ett värde.';

  @override
  String get spotifyTrackChanged => 'Spotify-spåret har ändrats';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Kör när ett annat spår börjar spelas.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecall daglig sammanfattning klar';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Kör när sammanfattningen av en dag är slutgiltig.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall-konversation inspelad';

  @override
  String get runWhenARecordedConversationEnds =>
      'Kör när en inspelad konversation avslutas.';

  @override
  String get geofenceTrigger => 'Plats geofence';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Kör när din telefon kommer till eller lämnar en plats. Behöver platsspårning på telefonen.';

  @override
  String get healthMetricRecorded => 'Hälsomått registrerat';

  @override
  String get runWhenAHealthReadingArrives =>
      'Kör när en synkroniserad hälsoavläsning kommer, eventuellt över eller under ett värde.';

  @override
  String get wearableConnectionChanged => 'Bärbar ansluten eller frånkopplad';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Kör när din bärbara ansluts eller kopplas bort.';

  @override
  String get taskRunFinished => 'Ännu en uppgift avslutad';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Kör efter att en annan uppgift har slutförts, lyckats eller misslyckats.';

  @override
  String get appPackageOptional => 'Apppaket (valfritt)';

  @override
  String get appPackageHelper => 'Till exempel com.whatsapp';

  @override
  String get anyPlatform => 'Vilken plattform som helst';

  @override
  String get spaceIdOptional =>
      'Server-, grupp-, kanal- eller rums-ID (valfritt)';

  @override
  String get spaceIdHelper => 'Empty bevakar alla som boten är i.';

  @override
  String get emojiOptional => 'Emoji (valfritt)';

  @override
  String get chatIdOptional => 'Chatt-ID (valfritt)';

  @override
  String get platformOptional => 'Plattform (valfritt)';

  @override
  String get platformOptionalHelper =>
      'Till exempel whatsapp. Tom klockor alla.';

  @override
  String get minutesBefore => 'Minuter innan';

  @override
  String get calendarIdOptional => 'Kalender-ID (valfritt)';

  @override
  String get calendarIdHelper => 'Empty använder din primära kalender.';

  @override
  String get invitesOnly => 'Endast inbjudningar från andra';

  @override
  String get nextcloudCalendarPath => 'Kalender';

  @override
  String get nextcloudCalendarPathHelper =>
      'Dess namn i Nextcloud-kalenderlistan, till exempel personligt';

  @override
  String get folderIdOptionalHelperDrive => 'Empty bevakar hela Drive.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty bevakar rotmappen.';

  @override
  String get driveFolderIdOptional => 'Mapp-ID (valfritt)';

  @override
  String get spreadsheetId => 'Kalkylarks-ID';

  @override
  String get sheetRange => 'Räckvidd';

  @override
  String get sheetRangeHelper => 'Tabellens kolumner, till exempel Sheet1!A:E';

  @override
  String get folderPathOptional => 'Mappsökväg (valfritt)';

  @override
  String get folderPathHelper => 'Till exempel dokument';

  @override
  String get notionDatabaseId => 'Databas-ID';

  @override
  String get trelloListId => 'List-ID';

  @override
  String get figmaFileKey => 'Filnyckel';

  @override
  String get figmaFileKeyHelper =>
      'Från fillänken: figma.com/file/<nyckel>/...';

  @override
  String get githubRepository => 'Förvar';

  @override
  String get workflowOptional => 'Arbetsflöde (valfritt)';

  @override
  String get workflowHelper => 'Filnamn som ci.yml';

  @override
  String get branchOptional => 'Filial (valfritt)';

  @override
  String get branchHelper => 'Empty använder standardgrenen.';

  @override
  String get mcpServerIdOptional => 'MCP-server-ID (valfritt)';

  @override
  String get entityId => 'Enhets-ID';

  @override
  String get entityIdHelper => 'Till exempel binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Målstatus (valfritt)';

  @override
  String get targetStateHelper => 'Till exempel på';

  @override
  String get aboveOptional => 'Ovan (valfritt)';

  @override
  String get belowOptional => 'Nedan (valfritt)';

  @override
  String get placeName => 'Ortsnamn';

  @override
  String get latitude => 'Latitud';

  @override
  String get longitude => 'Longitud';

  @override
  String get radiusMeters => 'Radie i meter';

  @override
  String get geofenceTransition => 'När';

  @override
  String get arriving => 'Anländer';

  @override
  String get leaving => 'Lämnar';

  @override
  String get healthMetric => 'Hälsomått';

  @override
  String get healthMetricHelper => 'Till exempel hjärtfrekvens, steg, vikt';

  @override
  String get wearableTransition => 'När den bärbara';

  @override
  String get wearableConnects => 'Ansluter';

  @override
  String get wearableDisconnects => 'Kopplar bort';

  @override
  String get sourceTask => 'Efter uppgift';

  @override
  String get taskOutcome => 'Resultat';

  @override
  String get anyOutcome => 'Vilket resultat som helst';

  @override
  String get succeeded => 'Lyckades';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 saknas eller är ogiltig.';
  }

  @override
  String get triggerSectionMessaging => 'Meddelanden';

  @override
  String get triggerSectionDeveloper => 'Utvecklare';

  @override
  String get triggerSectionMemory => 'Minne';

  @override
  String get triggerSectionNews => 'Nyheter';

  @override
  String get triggerSectionSystem => 'System';

  @override
  String get searchTriggersHint => 'Sök utlösare, appar eller händelser';

  @override
  String get noTriggersMatch => 'Ingen trigger matchar din sökning.';

  @override
  String get triggerAccountMissing => 'Inget konto ännu';

  @override
  String get pickTriggerKeyboardHint => 'Enter väljer det första resultatet';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 triggers';
  }

  @override
  String get addFromSkillsSh => 'Lägg till från skills.sh';

  @override
  String get skillsShHint =>
      'Sök ovan för att hitta färdigheter på skills.sh, eller klistra in en skills.sh-länk eller ett `npx skills add`-kommando.';

  @override
  String get noSkillsShMatches =>
      'Inga skills.sh-kunskaper matchar den här sökningen.';

  @override
  String get installingSkill => 'Installerar...';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Installerad $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 installeras';
  }

  @override
  String get authVerify => 'Verifiera';

  @override
  String get authCreateAccount => 'Skapa konto';

  @override
  String get authNewInviteLink => 'Ny inbjudningslänk';

  @override
  String get authShowPassword => 'Visa lösenord';

  @override
  String get authHidePassword => 'Dölj lösenord';

  @override
  String get authPasswordWillBeRejected => 'för svag, kommer att avvisas';

  @override
  String get authUsernameTooShort => 'Användarnamn behöver minst 3 tecken.';

  @override
  String get authUsernameTaken => 'Det användarnamnet är redan upptaget.';

  @override
  String get authSignupsClosed =>
      'Registreringar är stängda på denna server. Be administratören om ett konto.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Den här servern accepterar endast inloggningar över HTTPS. Öppna $arg1 istället.';
  }

  @override
  String get authInsecureTransport =>
      'Den här servern accepterar endast inloggningar över HTTPS. Anslut till den med en https://-adress.';

  @override
  String get authAccountNotFound => 'Det kontot finns inte längre.';

  @override
  String get authQrRateLimited =>
      'För många QR-inloggningsförfrågningar. Vänta ett ögonblick och uppdatera sedan koden.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Glömt ditt lösenord? Be din serveradministratör att återställa den i Admin → Användare.';

  @override
  String get authChangeServer => 'Byt server';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Loggar in på $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Den här adressen svarar inte som en NeoAgent-server. Kontrollera webbadressen och försök igen.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Det gick inte att öppna en säker (HTTPS) anslutning till $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Kunde inte nå $arg1 över HTTPS, och vanlig HTTP svarade inte heller. Kontrollera adressen och porten.';
  }

  @override
  String get adminResetPassword => 'Återställ lösenord';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Återställ lösenordet för $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Välj ett nytt lösenord för $arg1. De kommer att loggas ut på varje enhet och logga in igen med detta lösenord.';
  }

  @override
  String get adminNewPassword => 'Nytt lösenord';

  @override
  String get adminSetPassword => 'Ange lösenord';

  @override
  String get authMissingFields => 'Fyll i alla obligatoriska fält.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 återställ lösenordet för $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Lösenordet uppdaterat; användaren loggades ut överallt.';

  @override
  String get authSignInTitle => 'Logga in på NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Skanna med din telefon eller använd ditt lösenord.';

  @override
  String get authOrUsePassword => 'eller använd ditt lösenord';

  @override
  String get qrLoginWaitingTitle => 'Godkänn på din telefon';

  @override
  String get qrLoginWaitingBody =>
      'Din telefon skannade koden. Bekräfta inloggningen där för att slutföra inloggningen.';

  @override
  String get qrLoginSigningInOn => 'Loggar in på';

  @override
  String get qrLoginLocation => 'Plats';

  @override
  String get qrLoginWaitingForApproval => 'Väntar på godkännande';

  @override
  String get qrLoginCancelAndUsePassword => 'Avbryt och använd ett lösenord';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Inloggningen avvisades på din telefon. Skanna den nya koden för att försöka igen.';

  @override
  String get signupKey => 'Registreringsnyckel';

  @override
  String get signupKeyStepSubtitle =>
      'Nya konton på den här servern kräver en registreringsnyckel. Ange den du fick av en administratör.';

  @override
  String get signupKeyChange => 'Ändra';

  @override
  String get signupKeyRequiredError => 'Ange din registreringsnyckel.';

  @override
  String get signupKeyInvalidError =>
      'Registreringsnyckeln är ogiltig. Kontrollera den och försök igen.';

  @override
  String get signupKeyUsedError =>
      'Registreringsnyckeln har redan använts. Be en administratör om en ny.';

  @override
  String get adminRequireSignupKey => 'Kräv en registreringsnyckel';

  @override
  String get adminRequireSignupKeyHint =>
      'Nya konton kräver en engångsnyckel från en administratör. När det är av kan alla som når den här servern registrera sig. Det första kontot behöver aldrig någon nyckel.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Nya konton kräver nu en registreringsnyckel.';

  @override
  String get adminSignupOpenNotice => 'Nu kan vem som helst registrera sig.';

  @override
  String get signupKeys => 'Registreringsnycklar';

  @override
  String get signupKeysDescription =>
      'Engångsnycklar för registrering så länge en nyckel krävs. Varje nyckel skapar exakt ett konto.';

  @override
  String get signupKeysNew => 'Nya nycklar';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Oanvända · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Använda · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Återkallade · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Alla · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Oanvänd';

  @override
  String get signupKeyStatusUsed => 'Använd';

  @override
  String get signupKeyStatusRevoked => 'Återkallad';

  @override
  String get signupKeysExport => 'Exportera .txt';

  @override
  String get signupKeysCopied => 'Nycklar kopierade';

  @override
  String get signupKeyCopied => 'Nyckel kopierad';

  @override
  String get signupKeysEmpty => 'Inga nycklar i den här listan.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Skapad $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Använd av $arg1 den $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Använd den $arg1 av ett konto som sedan har raderats';
  }

  @override
  String get signupKeyRevokeTitle => 'Återkalla den här nyckeln?';

  @override
  String get signupKeyRevokeMessage =>
      'Ingen kommer att kunna registrera sig med den. Det går inte att ångra.';

  @override
  String get signupKeyRevoked => 'Nyckeln återkallades.';

  @override
  String signupKeysShowMore(int count) {
    return 'Visa $count till';
  }

  @override
  String get signupKeysCreateTitle => 'Skapa registreringsnycklar';

  @override
  String get signupKeysCount => 'Antal nycklar';

  @override
  String get signupKeysCountHelper => '1 till 500';

  @override
  String get signupKeysCountInvalid => 'Ange ett tal från 1 till 500.';

  @override
  String get signupKeysLabel => 'Etikett (valfri)';

  @override
  String get signupKeysLabelHint => 't.ex. Betatestare våren';

  @override
  String signupKeysCreateAction(int count) {
    return 'Skapa ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Nycklar klara: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Ge varje nyckel till en person. Oanvända nycklar finns kvar i listan så att du kan kopiera eller exportera dem igen senare.';

  @override
  String get signupKeysSaveDialogTitle => 'Spara registreringsnycklar';

  @override
  String get signupKeysExported => 'Nycklarna exporterades.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor skapade registreringsnycklar ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor återkallade en registreringsnyckel';
  }

  @override
  String get providerChooseUsername => 'Välj ditt användarnamn';

  @override
  String get providerChooseUsernameBody =>
      'Välj ett ledigt användarnamn för att slutföra ditt konto.';

  @override
  String get dataSharingTitle => 'Dela användningsdata';

  @override
  String get dataSharingDescription =>
      'Hjälp de som driver den här servern att förbättra den. Delar hur du använder NeoAgent, aldrig vad du skriver eller sparar.';

  @override
  String dataSharingSince(String date) {
    return 'Delar sedan $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Vad som delas';

  @override
  String get dataSharingIncluded => 'Delas';

  @override
  String get dataSharingExcluded => 'Delas aldrig';

  @override
  String get dataSharingIncludedDevice => 'Enhetstyp och appversion';

  @override
  String get dataSharingIncludedLocale =>
      'Appspråk och tidszonsregion, till exempel Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Vilka funktioner du har konfigurerat, som uppgifter, skills och integrationer';

  @override
  String get dataSharingIncludedRuns =>
      'Vilka verktyg och modeller dina körningar använder, med tider och antal tokens';

  @override
  String get dataSharingIncludedActivity =>
      'När du använder NeoAgent, per veckodag och timme';

  @override
  String get dataSharingExcludedContent => 'Meddelanden, prompter och svar';

  @override
  String get dataSharingExcludedRuns =>
      'Körningstitlar, verktygsindata och -resultat';

  @override
  String get dataSharingExcludedFiles =>
      'Filer, minnen och allt annat du sparar';

  @override
  String get dataSharingExcludedIdentity =>
      'Ditt namn, din e-post, IP-adress och plats';

  @override
  String get dataSharingExcludedAccounts =>
      'Kontona du kopplar integrationer med';

  @override
  String get dataSharingPooledNote =>
      'Administratörer ser bara summor över alla som delar, aldrig dig ensam. Stäng av när du vill så försvinner du direkt ur summorna.';

  @override
  String get dataSharingConfirmTitle => 'Dela användningsdata?';

  @override
  String get dataSharingConfirmAction => 'Dela';

  @override
  String get sharedUsageTitle => 'Delad användning';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Konton som delar användningsdata: $sharing av $total. Bara summor, inget innehåll.';
  }

  @override
  String get sharedUsageEmpty =>
      'Ingen delar användningsdata ännu. Det går att slå på under Inställningar, Profil, Dina data.';

  @override
  String get sharedUsageRuns => 'Delade körningar';

  @override
  String get sharedUsageAvgDuration => 'Snittid';

  @override
  String get sharedUsageCompletedRuns => 'Slutförda körningar';

  @override
  String get sharedUsageStepsPerRun => 'Steg per körning';

  @override
  String get sharedUsageDevices => 'Enheter';

  @override
  String get sharedUsageAppVersions => 'Appversioner';

  @override
  String get sharedUsageLanguages => 'Språk';

  @override
  String get sharedUsageRegions => 'Regioner';

  @override
  String get sharedUsageFeatures => 'Funktionsanvändning';

  @override
  String get sharedUsageFeaturesDescription =>
      'Andel av de delande kontona som har konfigurerat den.';

  @override
  String get sharedUsageTools => 'Verktyg';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Mest anropade verktyg ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Anrop: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Misslyckade: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integrationer';

  @override
  String get sharedUsageMessaging => 'Meddelandekanaler';

  @override
  String get sharedUsageTriggers => 'Hur körningar startar';

  @override
  String get sharedUsageActivity => 'När det används';

  @override
  String get sharedUsageActivityDescription =>
      'Körningar per veckodag och timme, UTC.';

  @override
  String get sharedUsageModels => 'Modellprestanda';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'snitt $latency · $cached % cachat · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Konton: $count';
  }

  @override
  String get sharedUsageNoData => 'Inget under den här perioden.';

  @override
  String get sharedUsageNotReported => 'Inte rapporterat än';

  @override
  String get sharedUsageFeatureAgents => 'Fler än en agent';

  @override
  String get sharedUsageFeatureTasks => 'Schemalagda uppgifter';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'MCP-servrar';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrationer';

  @override
  String get sharedUsageFeatureMessaging => 'Meddelandekanaler';

  @override
  String get sharedUsageFeatureMemory => 'Minne';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in datadelning telemetri enheter funktioner verktyg modeller aktivitet';

  @override
  String get yourOAuthApp => 'Din OAuth-app';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Din OAuth-app för $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Den här servern har ingen global $provider-app, så du ansluter med en OAuth-app som du registrerar själv. Klienthemligheten lagras krypterad och visas aldrig igen.';
  }

  @override
  String get oauthAppStepCreate => '1. Skapa appen';

  @override
  String get openDeveloperConsole => 'Öppna utvecklarkonsolen';

  @override
  String get oauthAppStepCallback => '2. Registrera den här callback-URL:en';

  @override
  String get callbackUrlCopied => 'Callback-URL kopierad';

  @override
  String get oauthAppScopes => 'Scopes att tillåta';

  @override
  String get scopesCopied => 'Scopes kopierade';

  @override
  String get oauthAppStepCredentials => '3. Klistra in appens uppgifter';

  @override
  String get couldNotSaveOAuthApp => 'Det gick inte att spara OAuth-appen.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Ta bort din $provider-app?';
  }

  @override
  String get removeOAuthAppBody =>
      'Anslutna konton finns kvar i listan men slutar fungera tills du lägger till en app igen.';

  @override
  String get globalIntegrationConfiguration =>
      'Global integrationskonfiguration';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Valfria OAuth-appar för hela servern. När en integration har en använder alla konton den och kan inte lägga till en egen. Lämna en integration tom så konfigurerar varje användare sin egen app. Hemligheter är skrivskyddade: lämna tomt för att behålla det sparade värdet.';

  @override
  String get globalStatus => 'Global';

  @override
  String get perUserStatus => 'Per användare';

  @override
  String get phoneSyncGuidance =>
      'Dela den här telefonens kalendrar och kontakter med din agent. Det fungerar med alla konton som redan finns på telefonen.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Öppna NeoAgent på telefonen och slå på delning där. Din agent ser då kalendrar och kontakter för alla konton på telefonen.';

  @override
  String get manageOnThisPhone => 'Hantera på den här telefonen';

  @override
  String get setUpOnThisPhone => 'Konfigurera på den här telefonen';

  @override
  String get setUpOnPhone => 'Konfigurera på din telefon';

  @override
  String emailConnectedArg1(String email) {
    return '$email ansluten';
  }

  @override
  String get couldNotConnectEmail => 'Kontot kunde inte anslutas.';

  @override
  String get emailSetupTitle => 'Anslut e-post och kalender';

  @override
  String get emailChecking => 'Kontrollerar din brevlåda…';

  @override
  String get emailSetupIntro =>
      'Använd ett applösenord från din e-postleverantör. Ingen utvecklarkonsol, klart på några minuter.';

  @override
  String emailOpenArg1(String provider) {
    return 'Öppna $provider';
  }

  @override
  String get emailStepServers => '1. Ange dina servrar';

  @override
  String get emailStepPassword => '1. Skapa ett applösenord';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Öppna applösenord hos $provider';
  }

  @override
  String get emailStepSignIn => '2. Logga in';

  @override
  String get appPassword => 'Applösenord';

  @override
  String get appPasswordHelper =>
      'Mellanslag spelar ingen roll. NeoAgent sparar det krypterat.';

  @override
  String get emailUsernameOptional =>
      'Användarnamn, om det inte är din e-postadress';

  @override
  String get emailIncludeCalendar => 'Ta med kalender';

  @override
  String get emailIncludeContacts => 'Ta med kontakter';

  @override
  String get imapServer => 'IMAP-server';

  @override
  String get smtpServer => 'SMTP-server';

  @override
  String get caldavUrlOptional => 'CalDAV-URL (valfri)';

  @override
  String get carddavUrlOptional => 'CardDAV-URL (valfri)';

  @override
  String get alternativeEmail =>
      'Anslut din brevlåda med ett applösenord, eller din kalender via dess iCal-länk. Klart på några minuter.';

  @override
  String get alternativePhone =>
      'Dela kalendern och kontakterna som redan finns på telefonen via NeoAgent-appen.';

  @override
  String get alternativePhoneElsewhere =>
      'Dela kalendern och kontakterna som redan finns på telefonen. Konfigurera det i NeoAgent-appen på telefonen.';

  @override
  String get skipTheDeveloperConsole => 'Hoppa över utvecklarkonsolen';

  @override
  String get phoneSyncPromptTitle => 'Får din agent se din kalender?';

  @override
  String get phoneSyncPromptBody =>
      'Dela den här telefonens kalendrar och kontakter så att din agent kan planera kring din dag. Du kan ändra det när som helst under Verktyg › Integrationer.';

  @override
  String get phoneSyncTitle => 'Dela telefonens kalender och kontakter';

  @override
  String get phoneSyncIntro =>
      'Din agent ser kalendrar och kontakter för alla konton på telefonen. Ingen utvecklarkonsol, ingen extra inloggning.';

  @override
  String get phoneSyncPointAccounts =>
      'Fungerar med Google-, Outlook-, iCloud- och Exchange-kontona på telefonen.';

  @override
  String get phoneSyncPointPrivate =>
      'Delas bara med din NeoAgent-server, där det lagras krypterat.';

  @override
  String get phoneSyncPointWrites =>
      'Händelser som agenten lägger till skapas av telefonen och synkas som vanligt.';

  @override
  String get phoneSyncCalendarHint =>
      'Händelser från 30 dagar bakåt till 90 dagar framåt';

  @override
  String get phoneSyncContacts => 'Kontakter';

  @override
  String get phoneSyncContactsHint => 'Namn, e-postadresser och telefonnummer';

  @override
  String get phoneSyncOtherAgent =>
      'Telefonen delar med en annan agent. Att dela här flyttar den till den här agenten.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent har inte åtkomst än. Tillåt det i Inställningar och kom sedan tillbaka.';

  @override
  String get openPhoneSettings => 'Öppna Inställningar';

  @override
  String get phoneSyncShare => 'Dela med NeoAgent';

  @override
  String get phoneSyncStop => 'Sluta dela';

  @override
  String get phoneSyncWaiting => 'Väntar på första synkroniseringen…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Senast synkad $time';
  }

  @override
  String get calendarLink => 'Kalenderlänk';

  @override
  String get calendarLinkHelper =>
      'Kalenderns iCal-adress. Alla som har den kan läsa kalendern, så håll den privat.';

  @override
  String get calendarLinkName => 'Namn (valfritt)';

  @override
  String get calendarLinkAdded => 'Kalendern har lagts till';

  @override
  String get toolsApps => 'Appar';

  @override
  String get reconnect => 'Anslut igen';

  @override
  String get reconnectNeeded => 'Behöver anslutas igen';

  @override
  String get mixedAccess => 'Blandad åtkomst';

  @override
  String disconnectAccountTitle(String account) {
    return 'Koppla från $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agenten förlorar åtkomsten till $apps via det här kontot.';
  }

  @override
  String get neoRouterServerDescription =>
      'Anslut din NeoRouter en gång så använder alla konton här den för uppgifterna som är påslagna nedan.';

  @override
  String get neoRouterUserDescription =>
      'Använd ditt eget NeoRouter-konto för uppgifterna som är påslagna nedan i stället för serverns leverantörer.';

  @override
  String get neoRouterAddress => 'NeoRouter-adress';

  @override
  String get neoRouterConnect => 'Anslut NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Godkänn NeoAgent i NeoRouter. Där visas koden $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Öppna igen';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Ansluten till $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter går inte att nå just nu.';

  @override
  String get neoRouterDisconnect => 'Koppla från';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent slutar använda den här NeoRoutern. Återkalla även nyckeln under API-nycklar i NeoRouter.';

  @override
  String neoRouterServerInUseArg1(Object? arg1) {
    return 'Den här servern använder redan NeoRouter på $arg1. Anslut ditt eget konto där för egna modeller och egen budget.';
  }

  @override
  String get neoRouterConnected => 'NeoRouter är ansluten.';

  @override
  String get neoRouterRoleChat => 'Chatt och bildigenkänning';

  @override
  String get neoRouterRoleSystemOne => 'System One-beslut';

  @override
  String get neoRouterRoleTranscription => 'Tal till text';

  @override
  String get neoRouterRoleLive => 'Liveröst';

  @override
  String get neoRouterRoleEmbeddings => 'Sökning i minnet';

  @override
  String get neoRouterRoleImages => 'Bildgenerering';

  @override
  String get neoRouterRoleSearch => 'Webbsökning';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return '$arg1 tillgängliga i din NeoRouter';
  }

  @override
  String get neoRouterNoModels => 'Inget är tillgängligt i din NeoRouter än.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter väljer modellen för varje förfrågan, så den här poolen används inte.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return '$arg1 i din NeoRouter, men NeoAgents nyckel får inte använda dem än (t.ex. betalda). Tillåt dem för NeoAgent under API-nycklar i NeoRouter.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Kräver beslutsmodeller som Jev. Säkerhetsklassificerare kan inte svara på de här frågorna.';
}
