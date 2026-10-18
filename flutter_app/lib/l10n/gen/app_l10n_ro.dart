// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppL10nRo extends AppL10n {
  AppL10nRo([String locale = 'ro']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Bun venit';

  @override
  String get onboardingEyebrowCommunication => 'Comunicare';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligența';

  @override
  String get onboardingEyebrowComputer => 'Computer';

  @override
  String get onboardingEyebrowAutomation => 'Automatizare';

  @override
  String get onboardingNext => 'În continuare';

  @override
  String get onboardingIntroCouldNotLoad =>
      'Introducerea nu a putut fi încărcată.';

  @override
  String get onboardingModelDescription =>
      'Alegeți modelul pe care NeoAgent ar trebui să-l folosească în mod implicit sau lăsați-l să aleagă automat.';

  @override
  String get onboardingLoadingModels => 'Se încarcă modelele...';

  @override
  String get noAiModelTitle => 'Încă nu este configurat niciun model AI';

  @override
  String get noAiModelBody =>
      'Adăugați o cheie API de la un furnizor precum OpenAI, Anthropic sau Google. NeoAgent arată apoi modelele pe care le puteți utiliza.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent are nevoie de un model AI pentru a răspunde. Adăugați o cheie API de la un furnizor precum OpenAI, Anthropic sau Google.';

  @override
  String get noAiModelAdminHint =>
      'În calitate de administrator, puteți, de asemenea, să configurați furnizori pentru toată lumea sub Administrator → Furnizori.';

  @override
  String get addApiKey => 'Adăugați cheia API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform este conectat.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Se așteaptă conectarea $platform...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Configurarea nu a putut fi salvată: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Gata';

  @override
  String get onboardingStepRequired => 'Obligatoriu';

  @override
  String get onboardingStepOptional => 'Opțional';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud sau local';

  @override
  String get onboardingStepComputer => 'Computer';

  @override
  String get onboardingStepRoutines => 'Rutine';

  @override
  String get onboardingComputerChoiceTitle => 'Unde ar trebui\nsă funcționeze?';

  @override
  String get onboardingComputerChoiceDescription => 'Puteți comuta pe sesiune.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Cutie cu nisip privat · mereu pornit';

  @override
  String get onboardingThisComputer => 'Acest computer';

  @override
  String get onboardingThisComputerSubtitle =>
      'Fișierele, aplicațiile și browserul dvs';

  @override
  String get onboardingSearchApps => 'Căutați aplicații...';

  @override
  String get onboardingRoutinesDescription =>
      'Rezultatele ajung în chat-urile dvs.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Rezultatele ajung sub formă de notificări.';

  @override
  String get onboardingNotifications => 'Notificări';

  @override
  String get onboardingReadyTitle => 'Totul este\ngata.';

  @override
  String get onboardingReadyDescription => 'Trimite primul tău mesaj.';

  @override
  String get onboardingMessageNeoagent => 'Trimite mesajul NeoAgent';

  @override
  String get onboardingAskAnything => 'Întreabă orice…';

  @override
  String get onboardingOpenNeoagent => 'Deschideți NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planificați o excursie de weekend';

  @override
  String get onboardingStarterLanding => 'Creați o pagină de destinație';

  @override
  String onboardingQuickSteps(int count) {
    return '$count pași rapizi';
  }

  @override
  String get taskNeedsEmail => 'Conectați mai întâi e-mailul';

  @override
  String get taskNeedsCalendar => 'Conectați mai întâi un calendar';

  @override
  String get taskNeedsModel => 'Configurați mai întâi un model AI';

  @override
  String get taskPromptDailyRecap =>
      'Recapitulați ziua: rezumați conversațiile, munca terminată și deciziile de astăzi, apoi enumerați orice ar trebui să urmăresc mâine. Ține-l scurt și trimite-mi-l.';

  @override
  String get taskPromptInboxCheck =>
      'Verificați-mi căsuța de e-mail pentru mesajele sosite de la ultima verificare. Trimite-mi mesaje numai despre e-mailurile care sunt urgente sau au nevoie de un răspuns, cu un rezumat pe o linie fiecare. Dacă nimic nu are nevoie de atenția mea, nu trimite nimic.';

  @override
  String get taskPromptMorningBriefing =>
      'Pregătește-mi briefing-ul de dimineață: vremea de astăzi unde mă aflu, evenimentele din calendarul meu și cele mai importante articole deschise despre care știu. Trimiteți-l ca mesaj scurt, care poate fi scanat.';

  @override
  String get taskPromptTomorrowPrep =>
      'Uită-te la calendarul meu pentru mâine. Pentru fiecare întâlnire, spuneți-mi despre ce este vorba, cine este implicat și orice ar trebui să pregătesc. Dacă mâine este gol, nu trimite nimic.';

  @override
  String get taskPromptNewsDigest =>
      'Căutați pe web cele mai importante știri de astăzi despre subiectele care îmi pasă (folosește ceea ce îți amintești despre interesele mele). Trimite-mi un rezumat de până la cinci articole cu câte o propoziție și un link.';

  @override
  String get taskPromptWeeklyReview =>
      'Revizuiește-mi săptămâna: ce s-a făcut, ce a alunecat și ce este încă deschis. Sugerați cele mai importante trei lucruri pe care să vă concentrați săptămâna viitoare.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Conectați un număr de telefon care aparține agentului. Oricine îi permiteți poate discuta cu acesta, în chat-uri directe și grupuri.';

  @override
  String get whatsappSelfChatDescription =>
      'Conectați-vă propriul număr și discutați cu agentul în chat-ul dvs. „Mesajați-vă singur”. Toate celelalte chat și grupuri din acest cont sunt ignorate.';

  @override
  String get chatSendHintMac => '⌘↵ pentru a trimite';

  @override
  String get chatSendHintOther => 'Ctrl+Enter pentru a trimite';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Este necesară o adresă URL de bază pentru acest punct final.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'O adresă de e-mail schimbată este confirmată înainte de a fi utilizată.';

  @override
  String get aDecisionHigherUpTheChain => 'O decizie mai sus în lanț câștigă.';

  @override
  String get aDeletedAccount => 'un cont șters';

  @override
  String get aFridayLookBackAtThe =>
      'O privire de vineri în urmă asupra săptămânii și un plan pentru următoarea.';

  @override
  String get aKeyThatAsksForA =>
      'O cheie care solicită codul PIN sau amprenta digitală înlocuiește și codul cu doi factori.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Un model de limbă a apreciat acest mesaj deoarece SystemOne este oprit.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Un fișier de metadate de configurare NeoAgent și-a depășit limita de dimensiune sigură.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'O versiune web mai nouă este disponibilă pe server. Reîncărcați pentru a prelua cel mai recent pachet.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Un desktop privat cu Chromium, fișiere, un editor de text, terminal și Python. Lucrarea dvs. rămâne salvată între sesiuni.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Un computer Linux privat sau un dispozitiv Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Un fișier de configurare NeoAgent necesar nu a putut fi descărcat.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Un coechipier vă trimite un link de invitație. Odată ce o accepți, ei ';

  @override
  String get aTeammateSentYouAnInvite =>
      'un coechipier v-a trimis un link de invitație, introduceți-l aici pentru a vă alătura echipei.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'O descărcare temporară va fi curățată ulterior.';

  @override
  String get aValueIsStored => 'O valoare este stocată.';

  @override
  String get access => 'Acces';

  @override
  String get accessActivity => 'Activitate de acces';

  @override
  String accessArg1(Object? arg1) {
    return 'Acces: $arg1';
  }

  @override
  String get accessMode => 'Mod de acces';

  @override
  String get accessPermissions => 'Permisiuni de acces';

  @override
  String get accessToken => 'jeton de acces';

  @override
  String get accessToken2 => 'Jeton de acces';

  @override
  String get account => 'Cont';

  @override
  String accountArg1(Object? arg1) {
    return 'Contul #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Alerte de schimbare a contului';

  @override
  String get accountEmail => 'E-mailul contului';

  @override
  String get accountEmailIsOffUntilThese =>
      'E-mailul contului este dezactivat până când acestea sunt setate: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent folosește acest limbaj peste tot în aplicație. Prima dată când vă conectați, urmărește acest dispozitiv. După aceea, alegerea este salvată în contul dvs. și utilizată pe fiecare dispozitiv.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nu s-a putut schimba limba: $error';
  }

  @override
  String get accountLanguageTitle => 'Limba';

  @override
  String get accountNumber => 'Numărul contului';

  @override
  String get accountSettings => 'Setările contului';

  @override
  String get accounts => 'Conturi';

  @override
  String get accountsByTokensUsedAllTime =>
      'Conturi pe jetoane folosite, tot timpul.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'computerele cloud ale conturilor. Modificările se aplică după un server ';

  @override
  String get accountsOnThisServer => 'Conturi pe acest server';

  @override
  String get active => 'Activ';

  @override
  String get activeSessions => 'Sesiuni active';

  @override
  String get activeToday => 'Activ astăzi';

  @override
  String get add => 'Adăugați';

  @override
  String get addAProviderCredentialFirstIts =>
      'Adăugați mai întâi acreditările de furnizor. Modelele sale apar aici o dată ';

  @override
  String get addAgent => 'Adăugați agent';

  @override
  String get addAnotherSignInMethodBefore =>
      'Adăugați o altă metodă de conectare înainte de a o elimina pe aceasta.';

  @override
  String get addBinding => 'Adăugați legături';

  @override
  String get addByNameOrId => 'Adăugați după nume sau ID';

  @override
  String get addByNameOrIdInstead => 'Adăugați în schimb după nume sau ID';

  @override
  String get addCredentialBinding => 'Adăugați legarea acreditărilor';

  @override
  String get addEntry => 'Adăugați intrare';

  @override
  String get addKey => 'Adăugați cheia';

  @override
  String get addMcpServer => 'Adăugați server MCP';

  @override
  String get addMemory => 'Adăugați memorie';

  @override
  String get memoryReview => 'Revizuiește';

  @override
  String get memoryReviewPrompt =>
      'Revizuiește toate amintirile mele și fă ordine: arhivează duplicatele, faptele depășite și tot ce nu are valoare de durată. Apoi spune-mi pe scurt ce ai schimbat.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Adăugați mai multă lungime sau alt tip de caracter.';

  @override
  String get addPeopleOrGroups => 'Adăugați persoane sau grupuri';

  @override
  String get addSecurityKey => 'Adăugați cheia de securitate';

  @override
  String get addSomeoneOrAGroup => 'Adăugați pe cineva sau un grup';

  @override
  String get addTask => 'Adăugați o sarcină';

  @override
  String get addTests => 'Adăugați teste';

  @override
  String get addTestsForThePartsOf =>
      'Adăugați teste pentru părțile acestui proiect care au cea mai mică acoperire, apoi rulați-le.';

  @override
  String get addTheirOwnKeysInSettings => 'adăugați propriile chei în Setări.';

  @override
  String get addToPrompt => 'Adăugați la prompt';

  @override
  String get added => 'Adăugat';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Adăugat $arg1 · Ultima utilizare $arg2';
  }

  @override
  String get addressWithTheProvider => 'adresa cu furnizorul.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Reglați volumul difuzorului, revizuiți setările implicite ale butonului hardware și gestionați această sesiune de lansare.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Reglați filtrul de căutare sau de stare pentru a vedea mai multe canale de mesagerie.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Reglați aici volumul difuzorului.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Administrator › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Subvențiile de administrator, linkurile de invitație și modificările de management apar aici.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Program manual avansat pentru cazuri speciale.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avansat: minut oră zi lună ziua săptămânii.';

  @override
  String get againRightAway => 'din nou imediat.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Apeluri de agent';

  @override
  String get agentCommunication => 'Comunicarea agentului';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Comunicare agent: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Modul agent editează spațiul de lucru · ⌘↵ trimite · ⌘N sesiune nouă';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agentul se oprește și îți cere permisiunea înainte de a începe execuția.';

  @override
  String get agentProfile => 'Profilul agentului';

  @override
  String get agentVisibleName => 'Nume vizibil pentru agent';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agentul dorește să folosească $arg1. Atingeți pentru a decide.';
  }

  @override
  String get agents => 'Agenți';

  @override
  String get aiAnswerUnreadable => 'Răspunsul AI nu poate fi citit';

  @override
  String get aiProviderKeys => 'Cheile furnizorului AI';

  @override
  String get aiUnavailable => 'AI indisponibil';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'alerte și alte e-mailuri de cont de la.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Alerte atunci când o conexiune de mesagerie necesită atenția utilizatorului';

  @override
  String get all => 'Toate';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Toți agenții ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Toate $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Toate sloturile cloud-computer sunt în prezent în uz. Încercați din nou peste un moment.';

  @override
  String get allComputerSlotsAreBusy =>
      'Toate sloturile computerelor sunt ocupate';

  @override
  String get allTables => 'Toate mesele';

  @override
  String get allTime => 'Tot timpul';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Toate instrumentele sunt permise - agentul poate folosi orice capacitate fără a cere. ';

  @override
  String get allow => 'Permite';

  @override
  String get allowedRunsWithoutAsking => 'Permis. Aleargă fără să întrebe.';

  @override
  String get allowAll => 'Permiteți totul';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Permiteți „Instalați aplicații necunoscute” pentru NeoAgent, apoi încercați din nou actualizarea.';

  @override
  String get allowOnce => 'Permite o dată';

  @override
  String get allowSender => 'Permite expeditorului';

  @override
  String get allowSession => 'Permite sesiune';

  @override
  String get allowTheAgentToStartAn =>
      'Permiteți agentului să inițieze un apel vocal în aplicație cu dvs.';

  @override
  String get allowedOrigins => 'Origini permise';

  @override
  String get allowedPathPrefix => 'Prefixul de cale permis';

  @override
  String get allowsYouCanChangeThatPer =>
      'permite. Puteți schimba asta de persoană mai târziu. Link-urile nu acordă niciodată ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'aparține deja unui cont existent';

  @override
  String get alreadyLinkedToAnotherAccount => 'deja conectat la alt cont';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'conectat deja la un alt cont neoagent';

  @override
  String get alreadyUsed => 'deja folosit';

  @override
  String get always => 'Întotdeauna';

  @override
  String get alwaysAllow => 'Permite întotdeauna';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '„Permiteți întotdeauna” salvează permanent politica — o puteți modifica în Setări.';

  @override
  String get alwaysAsk => 'Întreabă mereu';

  @override
  String get alwaysEngage => 'Angajează-te mereu';

  @override
  String get alwaysJoins => 'Întotdeauna se alătură';

  @override
  String get anApiKeyIsRequired => 'Este necesară o cheie API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Un rezumat de seară despre ceea ce s-a întâmplat și despre ce trebuie urmărit.';

  @override
  String get anHttpOrHttpsUrlIs => 'Este necesară o adresă URL http sau https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'și analitice. Link-uri pentru echipe live pe pagina Echipa.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Instalarea APK-ului Android nu este disponibilă pe această platformă.';

  @override
  String get androidApp => 'aplicație pentru Android';

  @override
  String get androidControl => 'Control Android';

  @override
  String get androidCouldNotStart => 'Android nu a putut porni';

  @override
  String get androidNotificationReceived => 'Notificare Android primită';

  @override
  String get androidOnly => 'Numai Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Programul de instalare a pachetelor Android nu a putut fi deschis.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Ecran Android — atingeți pentru a atinge, trageți pentru a glisa';

  @override
  String get androidSdk => 'Android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Răspunde la @mențiuni despre probleme și solicitări de tragere';

  @override
  String get anyone => 'Oricine';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Oricine de pe această platformă poate trimite mesaje $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Oricine de pe această platformă poate trimite mesaje $arg1 în $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Oricine poate accesa acest cont poate vorbi cu $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Oricine are linkul se poate alătura până când expiră sau îl revocați.';

  @override
  String get apiHttpsOrigin => 'Origine HTTPS API';

  @override
  String get apiKey => 'cheie API';

  @override
  String get apiKey2 => 'cheia api';

  @override
  String get apiKey3 => 'Cheia API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'cheie api antropică claude openai gpt xai grok google gemini minimax nvidia nim acreditări openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Chei API și puncte finale pentru furnizorii de AI, căutare și voce. Ei ';

  @override
  String get apiRequest => 'Solicitare API';

  @override
  String get apiYourOwnServerASelf =>
      'API -- propriul dvs. server, un model auto-găzduit sau altul ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Descărcarea APK-ului a eșuat cu HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Numele aplicației este obligatoriu.';

  @override
  String get appUpdates => 'Actualizări ale aplicației';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Actualizările aplicației nu sunt configurate pentru această versiune.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'S-au aplicat actualizările de direcție în coadă $arg1 la rularea curentă.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Actualizări aplicate de direcție $arg1.';
  }

  @override
  String get apply => 'Aplicați';

  @override
  String get applyBehaviorNotes => 'Aplicați note de comportament';

  @override
  String get applyCoreMemory => 'Aplicați memoria de bază';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Solicitări de aprobare pentru instrumente sensibile pentru agenți';

  @override
  String get approvalRequired => 'Este necesară aprobarea';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Aprobarea rămâne în sesiunea dvs. mobilă autentificată și fiecare cod expiră automat după o scurtă fereastră.';

  @override
  String get approveLogin => 'Aprobați autentificarea';

  @override
  String get approveQrLogin => 'Aprobați autentificarea QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Aprobați acest lucru numai dacă ați început autentificarea pe acel dispozitiv chiar acum.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Autentificare aprobată pentru $arg1.';
  }

  @override
  String get approvedOnly => 'Doar aprobat';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Împerechere aprobată pentru $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Persoane și grupuri aprobate';

  @override
  String get approvedPeopleOnly => 'Doar persoane aprobate';

  @override
  String get archive => 'Arhiva';

  @override
  String get archiveAgent => 'Agent de arhivă?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arhivă ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arhiva $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arhivați amintirile selectate?';

  @override
  String get areSharedByEveryAccountOn =>
      'sunt partajate de fiecare cont de pe acest server; conturile mai pot ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M intrare';
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
    return 'Este necesar accesul $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'conturi $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 activ';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 adăugat. Editați-l oricând pentru a schimba ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1” și istoricul rulării sale vor fi șterse definitiv. Orice alergare activă va fi oprită. Fișierele din spațiul de lucru nu sunt atinse.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Este necesară aprobarea $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 aplicații active';
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
    return '$arg1 (instrumente active $arg2)';
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
    return '$arg1 $arg2 la $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 schimbat';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 caractere';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Creat $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [uri local: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 se potrivește cu „$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent spațiu de lucru';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 conturi noi';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 rulează · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 mostre';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 direcție în coadă';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nJetoane $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Jetoane $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 la $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 a devenit administrator ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 octeți';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Canalul $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 caractere';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 a fost șters.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 configurat';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 conectat. Alegeți depozite și persoane de sub Cine poate trimite mesaje.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 intrări de bază.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 a creat un link de invitație';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 desktop';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 evenimente';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 a eșuat';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 a eșuat';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 eșuează';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 pentru $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 grupuri etichetate numai';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h în urmă';
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
    return '$arg1 ajutoare';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(Rata de accesare $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 este un administrator, deci contul nu poate fi șters ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 este blocat pe $arg2. Actualizați lista de acces pentru a permite răspunsuri.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 este conectat și răspunde.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 nu mai este administrator ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 nu este disponibil pe $arg2 (lipsește permisiunea de rulare sau dependența).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 s-a alăturat sub $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 judecat de LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Tasta $arg1$arg2 configurată';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Cheia $arg1 a fost eliminată.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 a plecat';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 a părăsit $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 conectat';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m în urmă';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Asigurați-vă că funcționează, apoi încercați din nou.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 gestionează acest cont';
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
    return 'Modele $arg1 gata';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 mai mult';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 mai mulți pași în istoricul rulării';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 a fost mutat de la $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 trebuie să fie un număr finit.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 trebuie să fie o adresă http:// sau https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 are nevoie de atenție';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent Workspace';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 conturi noi în ultimul $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · mesaje noi conduc această cursă';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 rulări noi';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 gestionează acum acest cont.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 din 4 permisiuni permise. Fișierele sunt limitate la folderul NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 din $arg2 activat';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 din grupurile $arg2 se alătură chatului obișnuit';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 a modelelor $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 a modelelor $arg2 gata';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return 'Set $arg1 de $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Instrumentele $arg1 ale $arg2 sunt permise';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 în ziua $arg2 la $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 răspunde numai persoanelor pe care le adăugați mai jos.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 răspunde numai atunci când este etichetat';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 vorbește numai cu persoanele și grupurile pe care le aprobați';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 persoane sau grupuri adăugate';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 planificare';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'furnizorii $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 gata';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 înregistrează';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI de redirecționare $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 înregistrat';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 a răspuns';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 a revocat un link de invitație';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 rulează';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 rulează · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 rulează în ultimul $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 salvat.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sec';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 selectat';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 afișat';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 a rămas tăcut';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 direcție $arg2 în coadă';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 pas$arg2 · atingeți un nod pentru a inspecta';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 pași';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 a încetat să mai gestioneze $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Jetoane $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Jetoane $arg1 în ultimul $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 instrumente';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (modificare salvată indisponibilă)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% folosit · $arg2 rămas';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 vrea să vorbească cu tine.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '„$arg1” va fi eliminat definitiv.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 va gestiona acest cont';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 nu va răspunde pe această platformă';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 nu va răspunde la $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Stocarea artefactelor de către utilizator';

  @override
  String get askAQuestionOrStartA => 'Pune o întrebare sau începe o sarcină...';

  @override
  String get askBeforeClosingToBackground =>
      'Întrebați înainte de a închide pe fundal';

  @override
  String get askMe => 'Întreabă-mă';

  @override
  String get assignedAgent => 'Agent desemnat';

  @override
  String get assignedAgent2 => 'Agent desemnat';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Agent desemnat: $arg1';
  }

  @override
  String get assigneeOptional => 'Cesionar (opțional)';

  @override
  String get assistant => 'Asistent';

  @override
  String get assistantKey131 => 'Tasta asistent 131';

  @override
  String get atLeast1 => 'Cel putin 1.';

  @override
  String get attachFiles => 'Atașați fișiere';

  @override
  String attentionArg1(Object? arg1) {
    return 'Atentie $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'jurnal de audit admin acord revocare invitare istoricul echipei';

  @override
  String get authMethod => 'Metoda de autentificare';

  @override
  String get authServerUrl => 'Adresa URL a serverului de autentificare';

  @override
  String get authentication => 'Autentificare';

  @override
  String get authenticationFailed => 'Autentificarea eșuată.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Autentificarea este încă în așteptare. Terminați fluxul browserului și încercați din nou.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Autentificarea este încă în așteptare. Terminați fluxul browserului și reîmprospătați.';

  @override
  String get authenticationTimedOut => 'Timpul de autentificare a expirat.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentificarea a fost anulată înainte de finalizare.';

  @override
  String get authenticatorApp => 'Aplicația de autentificare';

  @override
  String get authenticatorCode => 'Cod de autentificare';

  @override
  String get authorOptional => 'Autor (opțional)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (primul furnizor cu o cheie API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Rute automate către cel mai bun model disponibil';

  @override
  String get automaticFast => 'automat (rapid)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automat citește camera și, în mod normal, reține. Mention-only nu face niciun apel de decizie până când nu este adresat direct.';

  @override
  String get automaticReserved => 'Automat, rezervat';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Derularea automată necesită o reîncercare din ecranul de configurare.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatic selectează un model rapid prin catalogul de modele normal.';

  @override
  String get automation => 'Automatizare';

  @override
  String get available => 'Disponibil';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Disponibil din nou în $arg1';
  }

  @override
  String get availableAgainShortly => 'Disponibil din nou în scurt timp';

  @override
  String get availableInTheDesktopAppFor =>
      'Disponibil în aplicația desktop pentru macOS, Windows și Linux';

  @override
  String get availableToTheAgent => 'Disponibil pentru agent';

  @override
  String get averageAllTime => 'Mediu, tot timpul';

  @override
  String get avgImp => 'Imp. medie';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Media/run: jetoane $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Evitați caracterele repetate și secvențele evidente.';

  @override
  String get awaitingScan => 'Se așteaptă scanarea';

  @override
  String get back => 'Înapoi';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count în fundal';
  }

  @override
  String get backgroundTasks => 'Sarcini de fundal';

  @override
  String get backOn => 'înapoi pe.';

  @override
  String get backToChat => 'Înapoi la chat';

  @override
  String get backToFolder => 'Înapoi la dosar';

  @override
  String get backToSignIn => 'Înapoi pentru a vă conecta';

  @override
  String get backendChannel => 'Canalul de backend';

  @override
  String get backendOnThisComputer => 'Backend pe acest computer';

  @override
  String get backendSync => 'Sincronizare backend';

  @override
  String get backgroundLocationNeeded => 'Este necesară locația de fundal';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Sincronizarea în fundal rămâne programată pe Android';

  @override
  String get badState => 'Stare proastă: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Imaginea de bază și dimensiunea mașinilor virtuale QEMU care rulează ';

  @override
  String get baseUrlOptional => 'URL de bază (opțional)';

  @override
  String get baseUrlTokenLocal => 'jeton URL de bază local';

  @override
  String get basicAuthentication => 'Autentificare de bază';

  @override
  String get behaviorModules => 'Module de comportament';

  @override
  String get behaviorNotes => 'note de comportament';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Broker de acreditări Bitwarden';

  @override
  String get bitwardenItem => 'Element Bitwarden';

  @override
  String get bitwardenServer => 'Server Bitwarden';

  @override
  String get blankUsesCommon => 'Blank folosește „comun”';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank folosește apelarea implicită';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Valorile necompletate folosesc valorile prestabilite ale furnizorului.';

  @override
  String get block => 'Blocați';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Mesaj primit de la $arg1 blocat.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Pod compatibil BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'Adresa URL a serverului BlueBubbles';

  @override
  String get botToken => 'Jeton de bot';

  @override
  String get botTokenAndApprovedChats => 'Token bot și chaturi aprobate';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token bot și acces la server/canal';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token pentru bot, API pentru evenimente și acces la canal';

  @override
  String get botUserId => 'ID utilizator bot';

  @override
  String get botUsername => 'Nume de utilizator bot';

  @override
  String get brandName => 'Nume de marcă';

  @override
  String get braveSearch => 'Căutare curajoasă';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Bridge orice furnizor care poate posta și primi încărcături utile webhook.';

  @override
  String get bringYourOwnKey => 'aduceți-vă propria cheie';

  @override
  String get bringYourOwnKey2 => 'Adu-ți propria cheie';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Browserul, desktopul Linux, fișierele, terminalul și Python partajează un computer persistent în cloud.';

  @override
  String get browserLogin => 'Conectare la browser';

  @override
  String get browserScripting => 'Scripturi de browser';

  @override
  String get call => 'Sună';

  @override
  String get callAgent => 'Apelați agentul';

  @override
  String get callUser => 'Apelați utilizatorul';

  @override
  String get calledByName => 'Chemat pe nume';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Poate delega sarcini altor agenți';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Se poate delega la $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Poate primi sarcini delegate';

  @override
  String get cancel => 'Anulează';

  @override
  String get cancelTask => 'Anulați sarcina';

  @override
  String get cannotPreview => 'Nu se poate previzualiza';

  @override
  String get cannotReceiveDelegatedTasks => 'nu pot primi sarcini delegate';

  @override
  String get cannotRunYet => 'nu pot rula încă.';

  @override
  String get capturedThePage => 'A capturat pagina';

  @override
  String get category => 'categorie';

  @override
  String chainArg1(Object? arg1) {
    return 'Lanț: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Schimbați modul de configurare';

  @override
  String get channel => 'Canalul';

  @override
  String get channelAccessToken => 'Indicativ de acces la canal';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Canal: $arg1$arg2 | Versiune de actualizare: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Memorie socială în funcție de canal';

  @override
  String get channels => 'Canale';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'ID chat';

  @override
  String get chatMode => 'Modul chat';

  @override
  String get chatModel => 'Model de chat';

  @override
  String get checkAutomaticallyOnLaunch => 'Verificați automat la lansare';

  @override
  String get checkForMessagesEveryMs => 'Verificați mesajele la fiecare (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Verificați automat mesajele noi';

  @override
  String get checkNow => 'Verificați acum';

  @override
  String get checkYourEmailToConfirmYour =>
      'Verificați e-mailul pentru a vă confirma contul NeoAgent înainte de a vă conecta.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Bifat $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Alegeți o categorie sau căutați în toate setările.';

  @override
  String get chooseAPerson => 'Alegeți o persoană';

  @override
  String get chooseAProjectFolder => 'Alegeți un folder de proiect';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Alegeți valorile implicite pentru chat, agenți, comportament de rezervă și rutare inteligentă.';

  @override
  String get chooseGroups => 'Alegeți grupuri';

  @override
  String get chooseHowMuchYouWantTo =>
      'Alegeți cât de mult doriți să configurați acum. Ambele opțiuni pot fi modificate ulterior.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Alegeți cum ar trebui să înceapă această sarcină. Funcționează manual numai pe Run Now. Programul este bazat pe timp. Integrarea declanșează incendiul din aplicațiile oficiale conectate.';

  @override
  String get chooseOneToGetStartedNow =>
      'Alegeți unul pentru a începe acum. Puteți adăuga mai multe mai târziu.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Alegeți modelul live și vocea din Setări.';

  @override
  String get chooseTheirGroup => 'Alege-le grupul';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Alegeți unde ar trebui să i se permită acestei persoane să vorbească cu $arg1. Puteți modifica acest lucru mai târziu, sub Cine poate trimite mesaje.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Alegeți ce grupuri ar trebui să se alăture $arg1 chiar și atunci când nimeni nu îl etichetează. Este posibil ca această platformă să nu deosebească etichetele de mesajele obișnuite.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Alegeți ce modele poate alege fiecare cont de pe acest server și ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Alege cu cine vorbește $arg1 și când se alătură conversațiilor de grup.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Alegeți cine poate contacta $arg1, apoi salvați modificările.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Alegeți cine poate trimite mesaje agentului cu „Cine poate trimite mesaje” pe cardul WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Alegeți modelul\ndvs. implicit.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, fișierele, editorul de text și terminalul sunt toate disponibile de pe desktopul Linux.';

  @override
  String get claudeCode => 'Claude Cod';

  @override
  String get clear => 'Șterge';

  @override
  String get clearAll => 'Ștergeți totul';

  @override
  String clearArg1(Object? arg1) {
    return 'Ștergeți $arg1?';
  }

  @override
  String get clearFilter => 'Șterge filtrul';

  @override
  String get clearFilters => 'Ștergeți filtrele';

  @override
  String get clearSearch => 'Ștergeți căutarea';

  @override
  String get clearView => 'Vedere clară';

  @override
  String get cliSession => 'sesiune CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'click nu este acceptat pe această platformă.';

  @override
  String get clickOnceToBeginCapturing =>
      'Faceți clic o dată pentru a începe capturarea';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Faceți clic, tastați și interacționați cu aplicațiile desktop.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'S-a făcut clic la ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'S-a făcut clic în browser';

  @override
  String get clientId => 'ID client';

  @override
  String get clientSecret => 'Secretul clientului';

  @override
  String get close => 'Închide';

  @override
  String get closeJ => 'Închidere (⌘J)';

  @override
  String get closeTeachMode => 'Închideți modul Teach';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Închiderea ferestrei poate fie menține NeoAgent să ruleze în fundal cu acces la tavă, fie să iasă complet din timpul de rulare a desktopului.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Instanțele cloud și auto-găzduite sunt acceptate. Adresele URL locale și private funcționează atunci când NeoAgent le poate ajunge.';

  @override
  String get cloudComputer => 'Computer cloud';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Computer cloud · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Setările computerului în cloud au fost salvate. Reporniți serverul pentru a le aplica.';

  @override
  String get cloudComputerVm => 'Computer cloud (VM)';

  @override
  String get cloudComputers => 'Calculatoare cloud';

  @override
  String get codeHosting => 'Găzduire cod';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Nume de canale separate prin virgulă, fără #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Separate prin virgulă, de exemplu #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Despărțite prin virgulă. Problema trebuie să le aibă pe toate.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Comanda a eșuat ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Este necesară comanda.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Acumulatorul de ieșire de comandă nu este activ.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Încărcarea ieșirii comenzii a eșuat ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Încărcarea ieșirii comenzii a fost omisă metadatele artefactelor.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Ieșirea comenzii a fost deja finalizată.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Comenzi și aplicații';

  @override
  String get commandsRunInTheSamePersistent =>
      'Comenzile rulează în același computer persistent utilizat de desktopul vizibil.';

  @override
  String get communityChatops => 'Comunitate și ChatOps';

  @override
  String get completeSetup => 'Configurare completă';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Finalizați fluxul de lucru pe desktop.';

  @override
  String get completed => 'Terminat';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Blocat complet — agentul nu poate folosi această categorie.';

  @override
  String get computerShell => 'Carcasa computerului';

  @override
  String get computerUsedByThisSession => 'Computer folosit de această sesiune';

  @override
  String get computerWorkspace => 'Spațiu de lucru pe computer';

  @override
  String get configurablePersonalWebhookBridge =>
      'Punte webhook personală configurabilă';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Releu configurabil sau punte webhook';

  @override
  String get configurableTalkWebhookBridge =>
      'Punte webhook Talk configurabilă';

  @override
  String get configurableWebInboxBridge => 'Punte de intrare web configurabilă';

  @override
  String get configurableWebhookBridge => 'Punte webhook configurabilă';

  @override
  String get configurableWebhooks => 'Webhook-uri configurabile';

  @override
  String get configurationOrInTheEnvFile => 'Configurare sau în fișierul .env.';

  @override
  String get configure => 'Configurați';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configurați comportamentul spațiului de lucru și valorile implicite ale modelului.';

  @override
  String configuredArg1(Object? arg1) {
    return '$arg1 configurat';
  }

  @override
  String get confirmEmailChanges => 'Confirmați modificările de e-mail';

  @override
  String get confirmNewSignUps => 'Confirmați noile înscrieri';

  @override
  String get confirmPassword => 'Confirmați parola';

  @override
  String get confirmPassword2 => 'Confirmați parola';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Confirmați-vă e-mailul înainte de a vă conecta. Verificați mesajul de e-mail al serviciului de la NeoAgent.';

  @override
  String get connect => 'Conectați-vă';

  @override
  String get connectAMessagingPlatform =>
      'Conectați o platformă\nde mesagerie.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Conectați un punct final public HTTPS Home Assistant cu un token de acces cu durată lungă de viață. Adresele rețelei locale, loopback și private sunt blocate de server.';

  @override
  String get connectAccount => 'Conectați contul';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Conectați conturile de aplicație individual, astfel încât AI să poată folosi contul potrivit pentru fiecare integrare oficială.';

  @override
  String connectArg1(Object? arg1) {
    return 'Conectați $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Conectați câte conturi doriți. Fiecare aplicație poate folosi un cont diferit.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Conectați canalele, alegeți cu cine vorbește $arg1 și urmăriți activitatea recentă.';
  }

  @override
  String get connectInstance => 'Conectați instanța';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Conectați mai întâi această integrare pentru a alege un cont.';

  @override
  String get connectToThisServer => 'Conectați-vă la acest server';

  @override
  String get connectWhatsapp => 'Conectați WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Conectați-vă instanța Nextcloud, inclusiv serverele auto-găzduite. NeoAgent deschide propria pagină de conectare a Nextcloud, astfel încât să vă puteți conecta cu parolă, SSO sau 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Conectați-vă serverul NeoRecall auto-găzduit. NeoAgent primește acces numai în citire la căutarea locală, amintiri și dovezi ale transcripției după ce ați aprobat ecranul OAuth.';

  @override
  String get connected => 'Conectat';

  @override
  String get connectedAccount => 'Cont conectat';

  @override
  String connectedArg1(Object? arg1) {
    return 'Conectat $arg1';
  }

  @override
  String get connectedInstance => 'Instanță conectată';

  @override
  String get connectedNeorecallUser => 'Utilizator NeoRecall conectat';

  @override
  String get connectedNextcloudUser => 'Utilizator Nextcloud conectat';

  @override
  String get connectedServer => 'Server conectat';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Se conectează la modelul de voce live...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Conexiunea #$arg1';
  }

  @override
  String get connectionId => 'ID conexiune';

  @override
  String get connectionLooksGood => 'Conexiunea arată bine.';

  @override
  String get connectionMethod => 'Metoda de conectare';

  @override
  String get containsTextOptional => 'Conține text (opțional)';

  @override
  String get content => 'Conținut';

  @override
  String get contentSecurityPolicy => 'politica de securitate a conținutului';

  @override
  String get continue2 => 'Continuă';

  @override
  String get continueFullSetup => 'Continuați configurarea completă';

  @override
  String get continueRun => 'Continuați să alergați';

  @override
  String get continueToSetup => 'Continuați configurarea';

  @override
  String get controlSurface => 'SUPRAFAȚA DE CONTROL';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Controlează accesul la instrumentele $arg1.';
  }

  @override
  String get conversation => 'Conversație';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID de conversație folosit când acest agent începe o conversație prin chat.';

  @override
  String get cookieSetup => 'Configurare cookie';

  @override
  String get cookiesNotConfigured => 'Cookie-urile nu sunt configurate';

  @override
  String get copiedAsCsv => 'Copiat ca CSV';

  @override
  String get copiedDebugInfo => 'Informații de depanare copiate';

  @override
  String get copiedExportForTheLast5 =>
      'Export copiat pentru ultimele 5 mesaje';

  @override
  String get copiedFullPrompt => 'Solicitarea completă a fost copiată';

  @override
  String get copiedLogs => 'Jurnalele copiate';

  @override
  String get copiedRunId => 'ID de rulare copiat';

  @override
  String get copy => 'Copiere';

  @override
  String get copyAll => 'Copiați tot';

  @override
  String get copyCodes => 'Copiați coduri';

  @override
  String get copyCsv => 'Copiați CSV';

  @override
  String get copyDebugInfo => 'Copiați informațiile de depanare';

  @override
  String get copyLink => 'Copiați linkul';

  @override
  String get copyLogs => 'Copiați jurnalele';

  @override
  String get copyPrompt => 'Copiere prompt';

  @override
  String get copyResponse => 'Copiați răspunsul';

  @override
  String get copyRunId => 'Copiați ID-ul rulării';

  @override
  String get copyWebhookUrl => 'Copiați URL-ul webhook';

  @override
  String get core => 'Miez';

  @override
  String get coreMemory => 'memorie de bază';

  @override
  String get coreServicesThisServerDependsOn =>
      'Serviciile de bază de care depinde acest server.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https origini URL publice';

  @override
  String get couldHelp => 'Ar putea ajuta';

  @override
  String get couldNotApproveQrLogin => 'Nu s-a putut aproba conectarea QR.';

  @override
  String get couldNotApproveQrPairing => 'Nu s-a putut aproba asocierea QR.';

  @override
  String get couldNotConnect => 'Nu s-a putut conecta.';

  @override
  String get couldNotCreateBinding => 'Nu s-a putut crea legături.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nu s-a putut șterge contul dvs.: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Bitwarden nu a putut fi deconectat.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Nu s-a putut deconecta Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall =>
      'NeoRecall nu a putut fi deconectat.';

  @override
  String get couldNotDisconnectNextcloud => 'Nu s-a putut deconecta Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Nu s-a putut deconecta Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nu s-au putut exporta datele dvs.: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Nu s-au putut încărca deciziile';

  @override
  String get couldNotLoadUsageData =>
      'Nu s-au putut încărca datele de utilizare.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nu s-au putut deschide automat setările Linux.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Nu s-a putut deschide pagina de conectare a furnizorului.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nu s-a putut deschide pagina de conectare a furnizorului.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Nu s-a putut deschide materialul de lansare.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nu s-a putut deschide Trello în browser.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nu s-a putut deschide descărcarea fișierului spațiu de lucru.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Nu s-a putut citi pachetul aplicației Android.';

  @override
  String get couldNotReadTheApk => 'Nu s-a putut citi APK-ul.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nu s-a putut elimina cheia: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agentul nu a putut fi salvat.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nu s-a putut salva configurarea Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nu s-a putut salva configurarea Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nu s-a putut salva configurarea NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nu s-a putut salva configurarea Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nu s-a putut salva configurarea Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nu a putut trimite e-mail de confirmare';

  @override
  String get couldNotStart => 'Nu a putut începe';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Creați';

  @override
  String get createAPasswordFirstToChange =>
      'Creați mai întâi o parolă pentru a vă schimba adresa de e-mail a contului.';

  @override
  String get createAPasswordOrLinkAnother =>
      'creați o parolă sau conectați un alt furnizor înainte de a elimina această metodă de conectare';

  @override
  String get createATaskWhileThisAgent =>
      'Creați o sarcină în timp ce acest agent este selectat.';

  @override
  String get createLink => 'Creați link';

  @override
  String get createOrModifyFilesInYour =>
      'Creați sau modificați fișiere în spațiul dvs. de lucru.';

  @override
  String get createPassword => 'Creați parola';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Creați roboți specialiști cu memorie, setări, instrumente și atribuiri de cont separate.';

  @override
  String get createTheFirstAccount => 'Creați primul cont';

  @override
  String get createUpdateOrDeleteSkills =>
      'Creați, actualizați sau ștergeți competențe.';

  @override
  String get creatingYourSkill => 'Creându-ți abilitățile…';

  @override
  String get credentialBindings => 'Legături de acreditări';

  @override
  String get credentialUse => 'Utilizarea acreditărilor';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Execuții recurente bazate pe Cron și execuție cronometrată unică.';

  @override
  String get cronExpression => 'Expresia cron';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter rulează interogarea.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Spațiu';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'E-mail curent: $arg1';
  }

  @override
  String get currentPassword => 'Parola curentă';

  @override
  String get currentPasswordIsIncorrect => 'parola curentă este incorectă';

  @override
  String get currentTwoStepLoginCode => 'Cod de conectare curent în doi pași';

  @override
  String get customAccess => 'Acces personalizat';

  @override
  String get customCron => 'Cron personalizat';

  @override
  String get customCronMustHave5Fields =>
      'Cron personalizat trebuie să aibă 5 câmpuri.';

  @override
  String get customEndpoint => 'punct final personalizat';

  @override
  String get customField => 'Câmp personalizat';

  @override
  String get customHeader => 'Antet personalizat';

  @override
  String get customHeadersJson => 'Antete personalizate (JSON)';

  @override
  String get customOpenaiCompatible => 'Compatibil cu OpenAI personalizat';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Punct final personalizat compatibil cu OpenAI';

  @override
  String get customOutgoingUrl => 'Adresă URL de ieșire personalizată';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Zilnic';

  @override
  String get dailyRecap => 'Recapitulare zilnică';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'interogarea bazei de date selectați șabloane csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Ziua $arg1';
  }

  @override
  String get dayOfMonth => 'Ziua lunii';

  @override
  String get decideWhichToolsYourAgentMay =>
      'decideți ce instrumente poate folosi agentul dvs. Ei văd numele tău și ';

  @override
  String get decisionHigherUpTheChainWins =>
      'decizia mai sus în lanț câștigă și arată o blocare cu ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Deciziile apar aici, deoarece $arg1 citește grupurile aprobate $arg2. Sunt păstrate doar ultimele 30 și se resetează atunci când serverul repornește.';
  }

  @override
  String get decline => 'Declin';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'alergare adâncă · pas $arg1';
  }

  @override
  String get deepgramKey => 'Tasta Deepgram';

  @override
  String get default2 => 'Implicit';

  @override
  String get default3 => 'IMPLICIT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Implicit ($arg1)';
  }

  @override
  String get defaultConversation => 'Conversație implicită';

  @override
  String get defaultForNewGroups => 'Implicit pentru grupuri noi';

  @override
  String get defaultGroupParticipation => 'Participarea implicită a grupului';

  @override
  String get defaultNeoagentWorkspace => 'Spațiul de lucru NeoAgent implicit';

  @override
  String get defaultOpenai => 'Implicit (OpenAI)';

  @override
  String get defaultRateLimits => 'Limite implicite ale ratei';

  @override
  String get defaultRateLimitsSaved =>
      'Limitele implicite ale ratei au fost salvate.';

  @override
  String get defaultRecommended => 'Implicit (recomandat)';

  @override
  String get defaultRouting => 'Rutare implicită';

  @override
  String get defaultSpace => 'Spațiu implicit';

  @override
  String get delete => 'Ștergeți';

  @override
  String get deleteAccount => 'Ștergeți contul';

  @override
  String get deleteAccountPermanently => 'Ștergeți contul definitiv?';

  @override
  String get deleteAnAccount => 'Ștergeți un cont';

  @override
  String deleteArg1(Object? arg1) {
    return 'Ștergeți @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Ștergeți ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Ștergeți $arg1 $arg2 definitiv?';
  }

  @override
  String get deleteBinding => 'Ștergeți legarea';

  @override
  String get deleteCoreMemoryEntry => 'Ștergeți intrarea din memoria de bază?';

  @override
  String get deleteForever => 'Ștergeți pentru totdeauna';

  @override
  String get deleteMcpServer => 'Ștergeți serverul MCP?';

  @override
  String get deleteMemory => 'Ștergeți memoria?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Ștergerea șterge definitiv un cont și toate datele acestuia ';

  @override
  String get deleteRun => 'Ștergeți alergarea?';

  @override
  String get deleteRun2 => 'Șterge alergarea';

  @override
  String get deleteSelectedMemories => 'Ștergeți amintirile selectate?';

  @override
  String get deleteSession => 'Ștergeți sesiunea?';

  @override
  String get deleteSkill => 'Ștergeți abilitate?';

  @override
  String get deleteTask => 'Ștergeți sarcina?';

  @override
  String deletedArg1(Object? arg1) {
    return '„$arg1” a fost șters.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'S-a șters @$arg1 și toate datele lor.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Ștergerea vă elimină toate conversațiile, amintirile, fișierele, sarcinile și ';

  @override
  String get deliverableArtifactProduced => 'Artefact livrabil produs';

  @override
  String get deliverableCompleted => 'Livrabil finalizat';

  @override
  String get deliverableExecutionStarted => 'Execuția livrabilă a început';

  @override
  String get deliverableSelected => 'Livrabil selectat';

  @override
  String get deliverableValidationFailed => 'Validarea livrabilului a eșuat';

  @override
  String get deliverableValidationStarted => 'A început validarea livrabilului';

  @override
  String get deny => 'Negați';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Descrieți rezultatul, apoi demonstrați-l pe desktop';

  @override
  String get describeWhatToBuildOrChange =>
      'Descrieți ce să construiți sau să schimbați...';

  @override
  String get description => 'Descriere';

  @override
  String get desktopApp => 'Aplicație desktop';

  @override
  String get desktopAppControlsAvailable =>
      'Comenzi pentru aplicația desktop disponibile';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Captura desktop nu este disponibilă pe această platformă.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Încărcarea ieșirii comenzii de pe desktop a fost anulată.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Comanda pentru desktop a fost anulată.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Conexiunea pentru desktop a expirat.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Strângerea de mână pentru computerul însoțitor a expirat.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Companionul pentru desktop nu este disponibil aici.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Companionul desktop este întrerupt local.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Gestionarea mesajelor însoțitoare desktop a eșuat: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Setările de permisiuni pentru computerul însoțitor nu sunt disponibile pe web.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Setările de permisiuni pentru desktop însoțitor nu sunt disponibile pe această platformă.';

  @override
  String get desktopCompanionRejected => 'Companionul desktop a fost respins.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Răspunsul computerului însoțitor a eșuat: $arg1';
  }

  @override
  String get desktopControl => 'Controlul desktopului';

  @override
  String get desktopFailedToStart => 'Desktopul nu a pornit';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Captarea fluxului de pe desktop a eșuat: $arg1';
  }

  @override
  String get destinationId => 'ID destinație';

  @override
  String get deviceAccess => 'Acces la dispozitiv';

  @override
  String get deviceSettings => 'Setări dispozitiv';

  @override
  String get devices => 'Dispozitive';

  @override
  String get diagnosticsSaved => 'Diagnosticare salvată.';

  @override
  String get directBluebubblesImessageBridge =>
      'Direct BlueBubbles iMessage bridge';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Mesajele directe rămân receptive. Grupurile permise folosesc modul de participare de mai jos.';

  @override
  String get directoryDoesNotExist => 'Directorul nu există.';

  @override
  String get disable2fa => 'Dezactivați 2FA';

  @override
  String get disableAll => 'Dezactivează toate';

  @override
  String get discard => 'Aruncă';

  @override
  String get disconnect => 'Deconectați-vă';

  @override
  String get disconnectHomeAssistant => 'Deconectați Home Assistant?';

  @override
  String get disconnectNeorecall => 'Deconectați NeoRecall?';

  @override
  String get disconnectNextcloud => 'Deconectați Nextcloud?';

  @override
  String get disconnectPlatform => 'Deconectați platforma';

  @override
  String get disconnectTrello => 'Deconectați Trello?';

  @override
  String get discoveryFailed => 'Descoperirea a eșuat';

  @override
  String get dismiss => 'Respingeți';

  @override
  String get displayIdIsRequired => 'ID-ul de afișare este necesar.';

  @override
  String get displayName => 'Nume afișat';

  @override
  String get displayNameMustBe64Characters =>
      'Numele afișat trebuie să aibă 64 de caractere sau mai puțin.';

  @override
  String get displayNameSaved => 'Numele afișat a fost salvat.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Nu includeți numele dvs. de utilizator sau adresa de e-mail.';

  @override
  String get done => 'Gata';

  @override
  String get downloadACopyOfYourData =>
      'Descărcați o copie a datelor dvs. Conturile de administrator nu se pot șterge ';

  @override
  String get downloadACopyOfYourData2 =>
      'Descărcați o copie a datelor dvs. sau ștergeți-vă definitiv contul. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Descărcați $arg1';
  }

  @override
  String get downloadUpdate => 'Descărcați actualizarea';

  @override
  String get downloadingTheNeoagentBackend =>
      'Descărcarea backend-ului NeoAgent';

  @override
  String get draft => 'Ciornă';

  @override
  String get dragIsNotSupportedOnThis =>
      'glisarea nu este acceptată pe această platformă.';

  @override
  String get draggedOnTheScreen => 'Trasat pe ecran';

  @override
  String get dropAnApkOrApkBundle =>
      'Aruncă aici un APK sau un pachet APK pentru a-l instala';

  @override
  String get dropApkOrApksHere => 'Aruncă APK sau .apk-uri aici';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Instrucțiuni durabile pentru voce și stil de interacțiune. Regulile de siguranță și execuție au în continuare prioritate.';

  @override
  String get eGAlexSLaptop => 'de ex. Laptopul lui Alex';

  @override
  String get eGMyLocalServer => 'de ex. Serverul meu local';

  @override
  String get edit => 'Editați';

  @override
  String get editAgent => 'Editați agentul';

  @override
  String get editCoreMemoryEntry => 'Editați intrarea memoriei de bază';

  @override
  String get editInstructions => 'Editați instrucțiunile';

  @override
  String get editMcpServer => 'Editați serverul MCP';

  @override
  String get editTask => 'Editați sarcina';

  @override
  String editedArg1(Object? arg1) {
    return 'Editat $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'E-mail proprietarilor de conturi despre conectări care par neobișnuite.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Trimiteți e-mail proprietarilor de cont atunci când detaliile contului lor se modifică.';

  @override
  String get emailCode => 'Cod de e-mail';

  @override
  String get emailConfirmationRequired =>
      'este necesară confirmarea prin e-mail';

  @override
  String get emailIsAlreadyInUse => 'e-mailul este deja utilizat';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail salvat. Dacă este necesară confirmarea, verificați noua adresă pentru un link de confirmare NeoAgent.';

  @override
  String get emailSettingsSaved => 'Setările de e-mail au fost salvate.';

  @override
  String get emailUnverified => 'E-mail neverificat';

  @override
  String get empty => 'Gol';

  @override
  String get emptyFile => 'Fișier gol';

  @override
  String get emptyFolder => 'Dosar gol';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty folosește serverul implicit ($arg1).';
  }

  @override
  String get enable2fa => 'Activați 2FA';

  @override
  String get enableAll => 'Activează-le pe toate';

  @override
  String get enableBehaviorModules => 'Activați modulele de comportament';

  @override
  String get enableOrDisableModels => 'Activați sau dezactivați modelele';

  @override
  String get enabled => 'Activat';

  @override
  String get encryptedPrivateToYourAccount =>
      'Criptat, privat pentru contul dvs';

  @override
  String get end => 'Sfârșit';

  @override
  String get endCall => 'Încheiați apelul';

  @override
  String get endVoiceCall => 'Încheiați apelul vocal?';

  @override
  String get endpoint => 'Punct final';

  @override
  String get enterAPassword => 'Introduceți o parolă.';

  @override
  String get enterAUsername => 'Introduceți un nume de utilizator.';

  @override
  String get enterAValidEmailAddress =>
      'Introduceți o adresă de e-mail validă.';

  @override
  String get enterAnAddressManually => 'Introduceți o adresă manual';

  @override
  String get enterAnApiKeyFirst => 'Introduceți mai întâi o cheie API.';

  @override
  String get enterInviteLink => 'Introduceți linkul de invitație';

  @override
  String get enterTheAddressOfANeoagent =>
      'Introduceți adresa unui server NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Introduceți detaliile pe care le-a dat $arg1, astfel încât $arg2 să poată trimite și primi mesaje.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Introduceți codul 2FA sau de recuperare.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Introduceți parola curentă pentru a o schimba.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Introduceți parola curentă pentru a salva modificările de e-mail.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Introduceți detaliile contului dvs. NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Introduceți numele de utilizator sau adresa de e-mail a contului. NeoAgent va trimite un link de resetare dacă se poate potrivi cu contul.';

  @override
  String get enterYourUsernameOrEmail =>
      'Introduceți numele de utilizator sau adresa de e-mail.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entitate: $arg1';
  }

  @override
  String get environment => 'Mediul';

  @override
  String get error => 'Eroare';

  @override
  String errorArg1(Object? arg1) {
    return '\neroare: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Erori din jurnalul recent, grupate după mesaj.';

  @override
  String get errorsProblemsFailures => 'erori probleme eșecuri';

  @override
  String get eventTypesCommaSeparated =>
      'Tipuri de evenimente (separate prin virgulă)';

  @override
  String get every15Minutes => 'La fiecare 15 minute';

  @override
  String get every30Minutes => 'La fiecare 30 de minute';

  @override
  String get everyAccountOnThisServerLoses =>
      'Fiecare cont de pe acest server pierde această cheie partajată. Conturi ';

  @override
  String get everyAccountOnThisServerUses =>
      'Fiecare cont de pe acest server folosește această adresă pentru ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Fiecare sesiune activă pentru acest cont se încheie. Se pot conecta ';

  @override
  String get everyDay0800 => 'În fiecare zi · 08:00';

  @override
  String get everyDay2000 => 'În fiecare zi · 20:00';

  @override
  String get everyHour => 'În fiecare oră';

  @override
  String get everyRunOnThisServerAll =>
      'Fiecare rulare pe acest server, tot timpul.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Fiecare instrument sensibil necesită aprobare, de fiecare dată.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Fiecare instrument rulează fără să întrebe, cu excepția celor pe care o persoană ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Toți cei din aceste grupuri, canale sau săli pot vorbi cu $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Toți cei din acest grup';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Tot ce a dezactivat $arg1 pentru agentul dvs. vine ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Orice altceva este oprit.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Totul este disponibil de pe desktop.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Tot ce poate folosi agentul: integrări oficiale, servere MCP și abilități.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Tot ce ai dezactivat pentru $arg1 revine ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Originile web exacte au permisiunea de a face solicitări cu origini încrucișate, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Executați JavaScript în interiorul sesiunii de browser.';

  @override
  String get execution => 'Executarea';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Detaliile de execuție nu sunt disponibile pentru această rulare.';

  @override
  String get executionPlanCreated => 'Planul de execuție creat.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Sesiuni de exerciții $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[ieșire din $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Expiră $arg1';
  }

  @override
  String get explainThisProject => 'Explicați acest proiect';

  @override
  String exploredArg1(Object? arg1) {
    return 'Explorat $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Explorat $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Am explorat spațiul de lucru';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Export eșuat: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exportați ultimele 5 mesaje';

  @override
  String get exportMyData => 'Exportați datele mele';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Lansarea browserului extern a eșuat cu codul de ieșire $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Lansarea browserului extern nu este acceptată pe această platformă.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Lansarea browserului extern a expirat.';

  @override
  String get externalMcpTools => 'Instrumente externe și MCP';

  @override
  String get extraButtons => 'Butoane suplimentare';

  @override
  String get extractingTheNeoagentRuntime => 'Extragerea runtime-ului NeoAgent';

  @override
  String get failed => 'A eșuat';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Conectarea eșuată: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nu s-a putut conecta $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nu s-a șters „$arg1”: $arg2';
  }

  @override
  String get failedToFetch => 'nu a reușit să preia';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Nu s-a generat promptul: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Nu s-a putut lansa browserul extern prin url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Lansarea fluxului OAuth a eșuat.';

  @override
  String get failedToLoadPolicies => 'Politicile nu au putut fi încărcate';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Salvare eșuată: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Nu s-a salvat serverul MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Nu s-a salvat selecția: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Nu s-a putut trimite notificarea către backend: $arg1';
  }

  @override
  String get fair => 'Corect';

  @override
  String get fasterReplies => 'Răspunsuri mai rapide';

  @override
  String get fewerModelCalls => 'Mai puține apeluri de model';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'câmp gol pentru a restabili valoarea implicită încorporată.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Fișierul depășește limita editorului de 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Fișierul depășește limita de dimensiune acceptată.';

  @override
  String get fileWrites => 'Fișier scrieri';

  @override
  String get filename => 'Nume fișier';

  @override
  String get files => 'Fișiere';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Fișierele pe care NeoAgent le scrie sau editează în această sesiune apar aici.';

  @override
  String get filesSavedByAllUsers => 'Fișierele salvate de toți utilizatorii';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Completați datele de conectare aprobate sau autentificați cererile fără a afișa secrete AI.';

  @override
  String get finalResponse => 'Răspunsul final';

  @override
  String get findAPlatform => 'Găsiți o platformă';

  @override
  String get findAndFixABug => 'Găsiți și remediați o eroare';

  @override
  String get findRecentChats => 'Găsiți chat-uri recente';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Găsirea timpului de rulare corect al NeoAgent';

  @override
  String get finish => 'Termină';

  @override
  String get finishAtTheScheduledTime => 'Terminați la ora programată';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Finalizați conectarea la $arg1 în browser, apoi conectați-vă din nou.';
  }

  @override
  String get flowGraph => 'Graficul fluxului';

  @override
  String get flutterApp => 'Aplicația Flutter';

  @override
  String get focusedExecutionProfile => 'Profil de execuție concentrat';

  @override
  String get folderIdOptional => 'ID dosar (opțional)';

  @override
  String get folderUnavailable => 'Folder indisponibil';

  @override
  String get forExampleHttpsMatrixOrg => 'De exemplu https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Pentru configurații de rețea găzduite sau avansate';

  @override
  String get forLinksInEmailsBlankUses =>
      'Pentru link-uri în e-mailuri. Blank utilizează adresa URL publică a serverului.';

  @override
  String get forgotPassword => 'Aţi uitat parola?';

  @override
  String get frameUnavailable => 'Cadrul indisponibil';

  @override
  String freshnessArg1(Object? arg1) {
    return 'prospețime: $arg1';
  }

  @override
  String get fridays1700 => 'Vineri · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Din BotFather după ce creați botul.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'De acum încolo, $arg1 decide ce instrumente poate folosi agentul dvs. Ei ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Din portalul pentru dezvoltatori Discord, sub botul dvs.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Din Consola pentru dezvoltatori LINE.';

  @override
  String get fromTheMatrixClientOrBot => 'Din contul client sau bot Matrix.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'De pe twitchapps.com/tmi sau din aplicația pentru dezvoltatori Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Solicitare completă';

  @override
  String get fullSetup => 'Configurare completă';

  @override
  String get general => 'general';

  @override
  String get generalSettings => 'Setări generale';

  @override
  String get generalSettingsSaved => 'Setări generale salvate.';

  @override
  String get generateAPromptForAnotherAi =>
      'Generați o solicitare pentru un alt AI, inserați răspunsul aici pentru a importa amintiri.';

  @override
  String get generatePrompt => 'Generați prompt';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Eroare de urmărire a gardului geografic: $arg1';
  }

  @override
  String get getInspired => 'Inspiră-te';

  @override
  String get githubCopilot => 'Copilotul GitHub';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot și OpenAI Codex';

  @override
  String get githubIssueOpened => 'Problema GitHub a fost deschisă';

  @override
  String get neorecallMemoryCreated => 'Memorie NeoRecall creată';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Verificarea lansării GitHub a eșuat cu HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Sarcina utilă de lansare GitHub nu a fost o listă de lansări.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Numele de utilizator GitHub care a deschis problema';

  @override
  String get globalSecurityMode => 'Modul de securitate globală';

  @override
  String get gmailMessageReceived => 'Mesaj Gmail primit';

  @override
  String get good => 'Bun';

  @override
  String get goodAfternoon => 'Bună seara';

  @override
  String get goodEvening => 'Bună seara';

  @override
  String get goodMorning => 'Bună dimineața';

  @override
  String get goodPasswordALittleMoreLength =>
      'Parolă bună. Un pic mai multă lungime o face mai puternică.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live folosește cheia API OpenAI, Gemini Live cheia Google AI. Modificările se aplică la următorul apel.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Acordați permisiuni Health Connect înainte de sincronizare.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grup, canal sau cameră';

  @override
  String get groupType => 'Tip de grup';

  @override
  String get groupsAndChannels => 'Grupuri și canale';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupuri: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupurile $arg1 nu le-a văzut încă vor urma.';
  }

  @override
  String get handlesDirectTasksItself => 'Se ocupă singur de sarcinile directe';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Mâini libere (vorbește liber, întrerupe oricând)';

  @override
  String get headerName => 'Nume antet';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titluri despre subiectele care vă interesează, filtrate pentru semnal.';

  @override
  String get health => 'Sănătate';

  @override
  String get healthChecks => 'Controale de sănătate';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect nu este disponibil pe acest dispozitiv.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Starea de sincronizare Health Connect și valorile backend stocate.';

  @override
  String get healthStatusIsUnavailable =>
      'Starea de sănătate este indisponibilă.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Sincronizarea sănătății este disponibilă numai pe Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Înregistrările inimii $arg1';
  }

  @override
  String get heldBack => 'Reţinut';

  @override
  String get helper => 'Ajutor';

  @override
  String helperArg1(Object? arg1) {
    return 'Ajutor: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'aici. Revocați administratorul cu `neoagent admin revoke $arg1` mai întâi.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Valorile mai mari fac NeoAgent mai selectiv în grupuri.';

  @override
  String get highlyRecommended => 'Foarte recomandat';

  @override
  String get holdButton131ForTheAssistant =>
      'Țineți apăsat butonul 131 pentru asistent.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Țineți apăsat Ctrl+Shift+Space pentru a vorbi';

  @override
  String get holdToTalk => 'Țineți să vorbiți.';

  @override
  String get holdToTalk2 => 'Țineți să vorbiți';

  @override
  String get home => 'Acasă';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Este necesar un jeton de acces de lungă durată pentru Home Assistant.';

  @override
  String get homeAssistantSetup => 'Configurare Home Assistant';

  @override
  String get homeAssistantUrl => 'Adresa URL a Asistentului de acasă';

  @override
  String get homeAssistantUrlIsRequired =>
      'Este necesară adresa URL a Home Assistant.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token Homeserver cu sondaj de cameră';

  @override
  String get homeserverUrl => 'Adresa URL a serverului de domiciliu';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'serviciu găzduit). Cheile dvs. sunt criptate și pot fi utilizate numai de către ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Numele de gazdă al rețelei IRC, de exemplu irc.libera.chat';

  @override
  String get hourly => 'Orar';

  @override
  String get hourlyInboxCheck => 'Verificare orară a căsuței primite';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Cât timp rămân valabile linkurile de confirmare.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Cât de des caută acest agent mesaje noi în cameră.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Cât de des caută acest agent mesaje Signal noi.';

  @override
  String get howTeamsWork => 'Cum funcționează echipele';

  @override
  String get howThisServerIsReachedPlus =>
      'Cum se ajunge la acest server, plus comutatoare la nivel de server.';

  @override
  String get httpsSessionCookie => 'Cookie de sesiune https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Nu am putut completa acea cerere chiar acum. Vă rugăm să încercați din nou peste un moment.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inactiv';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Dacă $arg1 solicită o adresă URL de webhook, inserați aceasta astfel încât mesajele să poată ajunge la $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Dacă acel cont are un e-mail confirmat, NeoAgent va trimite un link de resetare a parolei.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Dacă serviciul necesită un token pentru cererile trimise.';

  @override
  String get ignoreGroups => 'Ignorați grupurile';

  @override
  String get ignoreThisChat => 'Ignorați acest chat';

  @override
  String get ignoredChannels => 'Canale ignorate';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Mesaj însoțitor de desktop malformat ignorat: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implementați planul de mai sus.';

  @override
  String get implementThisPlan => 'Implementați acest plan';

  @override
  String get implicitTls => 'TLS implicit';

  @override
  String get import => 'Import';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Importul eșuat: $arg1';
  }

  @override
  String get importFromComputer => 'Import de pe computer';

  @override
  String get importMemoryTransfer => 'Import de transfer de memorie?';

  @override
  String get importance => 'importanță';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Amintiri $arg1 importate, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'În echipa lui @$arg1';
  }

  @override
  String get inBackground => 'fundal';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Mesajele canalului primite și trimise vor apărea aici.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Apeluri vocale primite în aplicație de la NeoAgent';

  @override
  String get incomingMessages => 'Mesaje primite';

  @override
  String get incomingNeoagentCall => 'Apel NeoAgent primit';

  @override
  String get incomingNeoagentCall2 => 'APEL NEOAGENT SOSTE';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Webhook de intrare și suport pentru apel invers';

  @override
  String get incorporatingSteering => 'Încorporând direcția';

  @override
  String get input => 'Intrare';

  @override
  String get inputMode => 'Modul de intrare';

  @override
  String get insertATemplate => 'Introduceți un șablon';

  @override
  String get install => 'Instalați';

  @override
  String get installASignedSelfContainedRuntime =>
      'Instalați un runtime semnat, autonom. Comenzile Node.js, npm, Git și terminal nu sunt necesare.';

  @override
  String get installApk => 'Instalați APK';

  @override
  String get installApkBundle => 'Instalați APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Instalați APK - faceți clic sau plasați un fișier .apk';

  @override
  String get installNeoagent => 'Instalați NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Instalați NeoAgent pe acest computer fără terminal sau conectați-vă la unul care rulează deja.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Instalați versiuni noi și alegeți canalul pe care îl urmează acest server.';

  @override
  String get installTheBackend => 'Instalați backend-ul';

  @override
  String get installTheCoreWithExtraOptional =>
      'Instalați nucleul cu o configurare suplimentară opțională. Cheile furnizorului AI sunt adăugate ulterior, la fel ca Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Instalați nucleul securizat, apoi creați-vă contul. Adăugați apoi cheile furnizorului AI.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Instalat: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Instalat: $arg1 • Ultima verificare: $arg2';
  }

  @override
  String get instructions => 'Instrucțiuni';

  @override
  String get integration => 'Integrarea';

  @override
  String get integrationConnections => 'Conexiuni de integrare';

  @override
  String get integrationSettingsSaved =>
      'Setările de integrare au fost salvate.';

  @override
  String get integrations => 'Integrari';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrări/oauth/callback și înregistrați același lucru ';

  @override
  String get interruptAi => 'Întrerupeți AI';

  @override
  String get invalid2fa => '2fa invalid';

  @override
  String get invalidArgumentS => 'Argument(e) nevalid(e): ';

  @override
  String get invalidCredentials => 'acreditări nevalide';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Manifest de rulare NeoAgent nevalid.';

  @override
  String get inviteLink => 'Link de invitație';

  @override
  String get inviteLinkReady => 'Link de invitație gata';

  @override
  String get inviteLinks => 'Linkuri de invitație';

  @override
  String get iphoneApp => 'aplicație pentru iPhone';

  @override
  String get issues => 'Probleme';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Problemele apar odată ce se încarcă jurnalul.';

  @override
  String get itCanTBeUndone => 'Nu poate fi anulat.';

  @override
  String get itMayHaveBeenDeleted => 'Este posibil să fi fost șters.';

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
    return 'S-a alăturat $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'S-a alăturat în ultimele 7 zile';

  @override
  String get joiningATeam => 'Alăturarea unei echipe';

  @override
  String get joiningIsOffHere => 'Alăturarea este oprită aici';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Câmp JSON care conține textul mesajului. De obicei text.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Câmp JSON care identifică cui este mesajul.';

  @override
  String get jumpToLatest => 'Salt la cel mai recent';

  @override
  String get justNow => 'tocmai acum';

  @override
  String get keepNeoagentRunning => 'Păstrați NeoAgent să ruleze?';

  @override
  String get keepRunning => 'Continuă să alergi';

  @override
  String get keepTaskRunning => 'Continuați să ruleze sarcina';

  @override
  String get keepTheVaultAvailable => 'Păstrați seiful disponibil';

  @override
  String get keepThisLauncherUpToDate => 'Țineți acest lansator la zi.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Țineți acest panou deschis până când platforma confirmă conexiunea.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Păstrați vizibil computerul acestei sesiuni';

  @override
  String get keepTrackOfYourAiUsage =>
      'Urmăriți utilizarea AI. Limitele sunt impuse pentru a asigura o utilizare corectă pe platformă.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Continuați să utilizați aplicațiile în mod normal. NeoAgent funcționează pe același ecran și întreabă ori de câte ori are nevoie de acces nou.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Păstrând acest dispozitiv conectat';

  @override
  String get key => 'cheie';

  @override
  String get keyIsRequired => 'Este necesară cheia.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Perechi cheie-valoare care persistă în conversații.';

  @override
  String get knowledgeGraph => 'Graficul de cunoștințe';

  @override
  String get knowledgeView => 'Vedere de cunoștințe';

  @override
  String get labelOnlyYouSeeIt => 'Etichetă (doar tu o vezi)';

  @override
  String get labelsOptional => 'Etichete (opțional)';

  @override
  String get last24Hours => 'Ultimele 24 de ore';

  @override
  String get last7Days => 'Ultimele 7 zile';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Ultimele 7 zile: jetoanele $arg1 în $arg2 rulează';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Ultimul $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Ultimul: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Ultima sincronizare non-vide · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Ultima rulare: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Văzut ultima dată $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Ultima conectare $arg1';
  }

  @override
  String get lastSyncSummary => 'Rezumatul ultimei sincronizari';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Ultima utilizare: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Ultima fereastră sa încheiat $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'pornirea mai târziu s-a oprit.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Ultima rulare · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Lansarea aplicațiilor desktop nu este acceptată pe această platformă.';

  @override
  String get learnRoomNorms => 'Învață normele camerei';

  @override
  String get leave => 'Pleacă';

  @override
  String get leaveARedirectUriBlankTo =>
      'Lăsați un URI de redirecționare necompletat pentru a utiliza <public URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Părăsiți echipa lui $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Lăsați ca implicit, dacă nu ați personalizat BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Lăsați tokenul gol pentru a păstra jetonul stocat în prezent.';

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
    return 'Lasă-l pe $arg1 să mă gestioneze';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Permiteți tuturor din acest grup să vorbească cu $arg1.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Lasă-l să funcționeze în\ntimp ce tu nu o faci.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Lăsați NeoAgent să facă clic, să tastați și să se deplaseze prin aplicațiile dvs.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Lăsați NeoAgent să înțeleagă ce este vizibil pe ecran.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Lăsați pe cineva cu care lucrați să decidă ce instrumente poate fi agentul dvs ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Permiteți acestei persoane să trimită lui $arg1 un mesaj unu-la-unu.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Lăsați această persoană să vorbească cu $arg1 aici, dar nu în chaturi private sau în alte grupuri.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Lăsați această persoană să vorbească cu $arg1 în chat-urile private și în orice grup pe care îl împărtășește.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Nivelul $arg1/$arg2$arg3';
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
  String get linkCopied => 'Link copiat';

  @override
  String get linkExpiresAfter => 'Linkul expiră după';

  @override
  String get linkLifetimeHours => 'Durata de viață a conexiunii (ore)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Durata de viață a conexiunii trebuie să fie de la 1 la 8760 de ore.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link valabil până la $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Furnizori de conectare conectați';

  @override
  String get linuxApp => 'aplicația Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Listat $arg1/';
  }

  @override
  String get listening => 'Ascultând';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Istoricul execuției în direct, pașii instrumentului și răspunsurile.';

  @override
  String get liveModel => 'Model live';

  @override
  String get liveModelProvider => 'Furnizor de modele live';

  @override
  String get liveRun => 'Alerga live';

  @override
  String get liveVoice => 'Voce live';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Conexiunea vocală live nu este disponibilă.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Conexiunea vocală live a fost închisă.';

  @override
  String get liveVoiceDefaults => 'Valori implicite pentru voce live';

  @override
  String get liveVoiceFailed => 'Vocea live a eșuat.';

  @override
  String get llmMemoryExportResponse => 'Răspuns la exportul memoriei LLM';

  @override
  String get loadFailed => 'încărcarea a eșuat';

  @override
  String get loadingExecutionDetails => 'Se încarcă detaliile de execuție...';

  @override
  String get loadingNeoagent => 'Se încarcă NeoAgent';

  @override
  String get loadingRunFlow => 'Se încarcă fluxul de rulare...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Adresele URL locale și private sunt acceptate atunci când serverul NeoAgent le poate ajunge. Audio nu este niciodată expus la NeoAgent.';

  @override
  String get localApp => 'aplicație locală';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Instalarea backend locală nu este disponibilă pe această platformă.';

  @override
  String get localBaseImagePath => 'Calea imaginii de bază locală';

  @override
  String get localComputerControlIsAvailableIn =>
      'Controlul computerului local este disponibil în aplicația desktop NeoAgent pe macOS, Windows și Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Controlul computerului local nu este disponibil aici.';

  @override
  String get localModelsUrl => 'url model local';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Descoperirea NeoAgent locală este temporar indisponibilă.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Preferințe locale pentru aplicația NeoAgent. Controlul computerului rulează întotdeauna prin computerul cloud unificat.';

  @override
  String get localSetup => 'CONFIGURARE LOCALĂ';

  @override
  String get locationCityOrPlace => 'Locație (oraș sau loc)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Locația este necesară pentru declanșarea evenimentelor meteorologice';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inițializarea LocationService nu a reușit: $arg1';
  }

  @override
  String get logCopied => 'Jurnalul a fost copiat';

  @override
  String get loginPassword => 'Parola de conectare';

  @override
  String get logout => 'Deconectare';

  @override
  String get logs => 'Bușteni';

  @override
  String get logsCopied => 'Jurnalele copiate.';

  @override
  String get logsOnThisComputer => 'Logare pe acest computer';

  @override
  String get longLivedAccessToken => 'Token de acces cu viață lungă';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Reamintire pe termen lung, fapte structurate și grafic de cunoștințe.';

  @override
  String get lookedAtTheScreen => 'M-am uitat la ecran';

  @override
  String get lookingOnThisComputerAndYour =>
      'Se caută pe acest computer și pe rețeaua dvs. locală...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Privește în viitor la întâlnirile de mâine, așa că nimic nu te surprinde.';

  @override
  String get loopExecution => 'Execuția buclei';

  @override
  String get loopPaused => 'Bucla întreruptă';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Accesibilitatea macOS nu este acordată lui NeoAgent. Permiteți acest lucru în Setări sistem › Confidențialitate și securitate › Accesibilitate.';

  @override
  String get macosApp => 'aplicația macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Înregistrarea ecranului macOS nu este acordată lui NeoAgent. Permiteți acest lucru în Setări sistem › Confidențialitate și securitate › Înregistrare ecran, apoi redeschideți NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Serverele de e-mail care au nevoie de o parolă vor refuza să trimită până la o nouă ';

  @override
  String get main => 'Principal';

  @override
  String get makeDefault => 'Setați implicit';

  @override
  String get manage => 'Gestionează';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Gestionați e-mailul contului, autentificarea cu doi factori și sesiunile active.';

  @override
  String get managedBy => 'Gestionat de';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Managerii pot avea proprii manageri (până la patru niveluri). A ';

  @override
  String get managing => 'Gestionarea';

  @override
  String get manualDestination => 'Destinație manuală';

  @override
  String get manualTrigger => 'Declanșare manuală';

  @override
  String get masterPassword => 'Parola principală';

  @override
  String get matchThisDevice => 'Potriviți acest dispozitiv';

  @override
  String get matchedAgainstTitleAndBody => 'Se potrivește cu titlul și corpul';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Se potrivește cu vechiul flux NeoAgent MCP: URL plus metoda de autentificare.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'Server MCP';

  @override
  String get mcpServer2 => 'Server MCP';

  @override
  String get mcpServerUrl => 'Adresa URL a serverului MCP';

  @override
  String get mcpServers => 'servere MCP';

  @override
  String get meantForSomeoneElse => 'Destinat altcuiva';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Costul modelului măsurat: $arg1';
  }

  @override
  String get memories => 'Amintiri';

  @override
  String get memory => 'Memorie';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memorie: $arg1';
  }

  @override
  String get memoryInjected => 'Memorie injectată';

  @override
  String get mentionOrReplyOnly => 'Menționați sau răspundeți doar';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Serverul îmbinat și jurnalele de rulare Flutter pentru această sesiune de aplicație.';

  @override
  String get messageBodyTemplateJson => 'Șablon pentru corpul mesajului (JSON)';

  @override
  String get messageNeedsAccess => 'Mesajul necesită acces';

  @override
  String get messageTextField => 'Câmp text mesaj';

  @override
  String get messaging => 'Mesaje';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Evenimente push și webhook API de mesagerie';

  @override
  String get messagingConnectionNeedsAttention =>
      'Conexiunea de mesagerie necesită atenție';

  @override
  String get messagingConnections => 'Conexiuni de mesagerie';

  @override
  String get messagingDelivery => 'Livrarea mesajelor';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Eroare de mesaje. Vă rugăm să încercați din nou.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Captarea microfonului s-a oprit în mod neașteptat. Încearcă din nou.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Eroare la microfon: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Microfonul este dezactivat. Atingeți pentru a activa sunetul.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Este necesară permisiunea microfonului pentru vocea live.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Valoarea minimă a contribuției: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Configurarea mobilului a eșuat.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Configurarea mobilă a eșuat deoarece Java nu este disponibil pe mașina care rulează NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Configurarea mobilă a eșuat deoarece Java nu este disponibil pe mașina care rulează NeoAgent. Instalați un JDK și încercați din nou.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Configurarea mobilului a eșuat. Verificați dacă instrumentele Android sunt instalate corect și încercați din nou.';

  @override
  String modeArg1(Object? arg1) {
    return 'mod: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Modul se blochează în timp ce o alergare este activă.';

  @override
  String get model => 'Model';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Disponibilitatea modelului';

  @override
  String get modelAvailabilitySaved =>
      'Disponibilitatea modelului a fost salvată.';

  @override
  String get modelForThisSession => 'Model pentru această sesiune';

  @override
  String get modelOverride => 'Modificare model';

  @override
  String get modelPending => 'Model în așteptare';

  @override
  String get modelTurn => 'Întoarcerea modelului';

  @override
  String get modelTurnCompleted => 'Turnul modelului a fost finalizat';

  @override
  String get modelTurnStarted => 'A început întoarcerea modelului';

  @override
  String get modelVisibilityHideShowList =>
      'vizibilitatea modelului ascunde lista de afișare';

  @override
  String get models => 'Modele';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modele, comportament, voce și spațiu de lucru';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modele, browser, voce, diagnosticare...';

  @override
  String get modelsRouting => 'Modele și rutare';

  @override
  String get monthly => 'Lunar';

  @override
  String get moreActions => 'Mai multe acțiuni';

  @override
  String get morningBriefing => 'Briefing de dimineață';

  @override
  String get mostUsedAgents => 'Cei mai folosiți agenți';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Cele mai folosite modele din ultimul $arg1.';
  }

  @override
  String get mouseKeyboard => 'Mouse și tastatură';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove nu este acceptat pe această platformă.';

  @override
  String get mustBeReachableOnThePublic =>
      'Trebuie să fie accesibil pe internetul public -- local și ';

  @override
  String get n24Hours => '24 de ore';

  @override
  String get n2faOrRecoveryCode => '2FA sau cod de recuperare';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA necesită configurarea SESSION_SECRET pentru această implementare NeoAgent.';

  @override
  String get n30Days => '30 de zile';

  @override
  String get n365Days => '365 de zile';

  @override
  String get n4HourLimitTokens => 'Limită de 4 ore (jetoane)';

  @override
  String get n4HourUsage => '4 ore de utilizare';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Limită de 4 ore $arg1';
  }

  @override
  String get n7DayUsage => '7 zile de utilizare';

  @override
  String get n7Days => '7 zile';

  @override
  String get n90Days => '90 de zile';

  @override
  String get name => 'Nume';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnume: New Skill\ndescriere: Descrieți ce face această abilitate\n---\nScrieți instrucțiunile pentru această abilitate aici.\n';

  @override
  String get nameOfWhoeverMadeIt => 'numele celui care a făcut-o.';

  @override
  String get nameOptional => 'Nume (opțional)';

  @override
  String get nativeAndWebhookChannels => 'Canale native și webhook';

  @override
  String get naturalBubbles => 'Bule naturale';

  @override
  String get nearbyNeoagentServers => 'Servere NeoAgent din apropiere';

  @override
  String get needANewAccountRegister =>
      'Ai nevoie de un cont nou? Înregistrează-te';

  @override
  String get needAnIdea => 'Ai nevoie de o idee?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Trebuie să răspund · $arg1% pentru a vorbi';
  }

  @override
  String get needsAttention => 'Necesită atenție';

  @override
  String get needsInput => 'Necesita input';

  @override
  String get neoagentApp => 'Aplicația NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Asistent NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent nu a putut verifica timpul de execuție backend disponibil.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent nu a putut finaliza configurarea locală.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent nu a putut finaliza configurarea locală. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informații de depanare NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent instalează cel mai recent $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent este instalat și rulează.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent nu este instalat pe acest computer.';

  @override
  String get neoagentIsReady => 'NeoAgent este gata';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent încă lucrează la o sarcină. Încheiați apelul și obțineți rezultatul în chat sau anulați și sarcina.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent transformă demonstrația dvs. într-un flux de lucru adaptabil.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent așteaptă în timp ce utilizați desktopul.';

  @override
  String get neoagentIsWorking => 'NeoAgent funcționează';

  @override
  String get neoagentLinuxComputer => 'computer NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT ARE NEVOIE DE O DECIZIE';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Descărcările de rulare NeoAgent necesită o adresă sigură.';

  @override
  String get neoagentServerAddress => 'Adresa serverului NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'E-mailul serviciului NeoAgent nu este pregătit. Cereți operatorului serverului să verifice setările mediului de e-mail.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Configurarea NeoAgent nu s-a putut finaliza.';

  @override
  String get neoagentUser => 'Utilizator NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent folosește acest computer în mod automat și întreabă înainte de a utiliza ecranul, mouse-ul, tastatura, fișierele sau linia de comandă.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent folosește locația dvs. aproximativă de fundal pentru a declanșa mementouri de gard geografic (de exemplu, „Amintește-mi să cumpăr lapte când trec pe lângă supermarket”).\n\n';

  @override
  String get neoagentWorkspace => 'Spațiul de lucru NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stiva] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'URL de backend NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Este necesară adresa URL de backend NeoRecall.';

  @override
  String get neorecallSetup => 'Configurare NeoRecall';

  @override
  String get networkRequestFailed => 'cererea de rețea a eșuat';

  @override
  String get networkWriteRequests => 'Cereri de scriere în rețea';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nu se ia niciodată în calcul în limitele de utilizare partajate.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Conturile noi își confirmă adresa de e-mail înainte de a se conecta.';

  @override
  String get newAccountsPerDay => 'Conturi noi pe zi';

  @override
  String get newChat => 'Chat nou';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Noile grupuri rămân liniștite dacă cineva nu etichetează $arg1, până când le activați.';
  }

  @override
  String get newLink => 'Link nou';

  @override
  String get newPasswordsDoNotMatch => 'Parolele noi nu se potrivesc.';

  @override
  String get newRecoveryCodes => 'Noi coduri de recuperare';

  @override
  String get newSession => 'Sesiune nouă';

  @override
  String get newSessionN => 'Sesiune nouă (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Sesiune nouă cu aceeași configurație';

  @override
  String get newSkill => 'Noua abilitate';

  @override
  String get newSkill2 => 'Noua abilitate';

  @override
  String get newThisWeek => 'Nou săptămâna aceasta';

  @override
  String get newsDigest => 'Rezumat de știri';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Următoarea reîncercare: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Flux de conectare Nextcloud';

  @override
  String get nextcloudSetup => 'Configurare Nextcloud';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'URL Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'URL-ul Nextcloud este obligatoriu.';

  @override
  String get nickname => 'Pseudonim';

  @override
  String get noAccountsConnectedYet => 'Niciun cont conectat încă.';

  @override
  String get noAccountsFound => 'Nu s-au găsit conturi.';

  @override
  String get noActiveSessionsFound => 'Nu s-au găsit sesiuni active.';

  @override
  String get noAgentsYet => 'Încă nu există agenți';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nu este configurat niciun furnizor AI, așa că chat și mesagerie ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Fără solicitări de aprobare — agentul rulează fără întrerupere.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Niciun material de lansare $arg1 nu se potrivea cu această platformă.';
  }

  @override
  String get noArguments => '(fara argumente)';

  @override
  String get noAuth => 'Fără autentificare';

  @override
  String get noBindingsYet => 'Încă nu există legături.';

  @override
  String get noChangesYet => 'Nicio modificare încă';

  @override
  String get noChannelsFound => 'Nu s-au găsit canale';

  @override
  String get noCloudComputerSlotIsFree =>
      'Niciun slot pentru cloud-computer nu este gratuit în acest moment. Încercați din nou peste un moment.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Nu există încă intrări de memorie de bază.';

  @override
  String get noDescription => 'Fără descriere';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'În prezent, nu sunt disponibile ecrane desktop.';

  @override
  String get noDetailAvailable => 'Nu există detalii disponibile';

  @override
  String get noDetailedSyncSummaryYet =>
      'Nu există încă un rezumat detaliat de sincronizare.';

  @override
  String get noDetailsCaptured => 'Nu au fost capturate detalii.';

  @override
  String get noEmailLinked => 'Niciun e-mail legat';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nu sunt conectați furnizori externi de conectare.';

  @override
  String get noGroupMessagesYet => 'Niciun mesaj de grup încă';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Nu s-au adăugat încă persoane specifice grupului.';

  @override
  String get noGroupsAddedYet => 'Niciun grup adăugat încă.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Nu au fost găsite grupuri încă. După ce $arg1 vede un mesaj de grup, utilizați Găsiți chat-uri recente și acestea vor apărea aici.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Nu au fost găsite grupuri încă. După ce $arg1 vede un mesaj de grup, utilizați Găsiți conversații recente.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nu s-a returnat nicio încărcătură de date de sănătate.';

  @override
  String get noHealthSamplesStoredYet =>
      'Nu au fost încă stocate mostre de sănătate.';

  @override
  String get noHttpClientImplementationForThis =>
      'Nu există implementare client HTTP pentru această platformă.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Nu a fost înregistrată nicio intrare sau ieșire pentru acest pas.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Nicio integrare nu corespunde acestei căutări.';

  @override
  String get noLimit => 'Fără limită';

  @override
  String get noLocalPasswordIsSetYet =>
      'Nu este setată încă o parolă locală. Creați unul pentru a activa conectarea cu numele de utilizator/parola.';

  @override
  String get noLogEntries => 'Fără intrări de jurnal.';

  @override
  String get noMatchingSettings => 'Nu există setări care se potrivesc';

  @override
  String get noMcpServersMatchThisSearch =>
      'Niciun server MCP nu corespunde acestei căutări.';

  @override
  String get noMemoryEntriesFound => 'Nu s-au găsit intrări de memorie.';

  @override
  String get noMemorySync => 'Fără sincronizare de memorie';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Citește o singură dată e-mailurile importante și trimise din ultimele 12 luni, ca agentul să-ți cunoască contactele și proiectele.';

  @override
  String get emailMemory => 'Memorie din e-mail';

  @override
  String get importNow => 'Importă acum';

  @override
  String get importOnConnect =>
      'Importă mesajele vechi la conectarea unui cont';

  @override
  String get sweepStarting => 'Se pregătește…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Se citesc e-mailurile · $done din $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Se citesc e-mailurile · $count găsite';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Învață din e-mailuri · $done din $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Ultimul import: $emails e-mailuri · $memories amintiri noi';
  }

  @override
  String get sweepNothingNew => 'Nu există e-mailuri noi de importat';

  @override
  String sweepFailed(String error) {
    return 'Importul a eșuat: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Niciun model nu se potrivește cu „$arg1”.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Nu a fost înregistrată nicio cerere de model pentru această rulare.';

  @override
  String get noModelsDiscoveredYet => 'Nu au fost descoperite modele încă';

  @override
  String get noModelsSelected => 'Niciun model selectat';

  @override
  String get noModelsYet => 'Încă nu există modele';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'niciun cont neoagent nu este conectat la acest furnizor';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Nu este disponibil niciun timp de rulare backend NeoAgent pentru acest computer.';

  @override
  String get noNetworkConnection => 'Fără conexiune la rețea';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Fără conexiune la rețea. Conectați-vă pentru a continua să utilizați NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Fără conexiune la rețea. Reconectați-vă pentru a verifica dacă există actualizări.';

  @override
  String get noOne => 'Nimeni';

  @override
  String get noOneAddedYet => 'Nimeni nu a adăugat încă.';

  @override
  String get noOneCanMessage => 'Nimeni nu poate trimite mesaje';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nu a fost găsit niciun alt server NeoAgent. Puteți căuta din nou sau puteți introduce manual o adresă.';

  @override
  String get noPeopleAddedYet => 'Nicio persoană adăugată încă.';

  @override
  String get noPlatformsMatch => 'Nicio platformă nu se potrivește';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Niciun furnizor nu este încă disponibil pentru configurație.';

  @override
  String get noRecentChannelActivity => 'Nicio activitate recentă pe canal';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Niciun rezultat pentru „$arg1”';
  }

  @override
  String get noRunsInThisRange => 'Nu există curse în acest interval.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nicio rulare nu corespunde acestor filtre';

  @override
  String get noRunsYet => 'Încă nu există curse';

  @override
  String get noRunsYet2 => 'Încă nu există curse.';

  @override
  String get noSecurityKeyWasProvided =>
      'Nu a fost furnizată nicio cheie de securitate.';

  @override
  String get noServerUrlSet => 'Nu a fost setată nicio adresă URL a serverului';

  @override
  String get noSessionMatchesThatSearch =>
      'Nicio sesiune nu corespunde acestei căutări.';

  @override
  String get noSessionsYet => 'Nicio sesiune încă';

  @override
  String get noSkillsMatchTheseFilters =>
      'Nicio abilitate nu se potrivește cu aceste filtre.';

  @override
  String get noStepsWereRecordedForThis =>
      'Nu au fost înregistrate pași pentru această cursă.';

  @override
  String get noSummaryAvailable => 'Nu este disponibil un rezumat.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Nicio sarcină pentru $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Nicio unealtă nu se potrivește cu „$arg1”.';
  }

  @override
  String get noUpdateRunning => 'Nu rulează nicio actualizare';

  @override
  String get noUsageYet => 'Nicio utilizare încă.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Nu este disponibil încă nicio durată de rulare backend NeoAgent verificată.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nimeni nu-l mai poate folosi. Oameni care s-au alăturat deja ';

  @override
  String get none => 'Niciuna';

  @override
  String get notApprovedYet => 'neaprobat încă';

  @override
  String get notAuthenticated => 'neautentificat';

  @override
  String get notCheckedYet => 'Nu a fost verificat încă';

  @override
  String get notConfigured => 'Neconfigurat';

  @override
  String get notConnected => 'Nu este conectat';

  @override
  String get notConnected2 => 'Nu este conectat';

  @override
  String get notInstalled => 'Neinstalat';

  @override
  String get notNeeded => 'Nu este necesar';

  @override
  String get notNeededEnough => 'Nu este suficient';

  @override
  String get notNow => 'Nu acum';

  @override
  String get notNow2 => 'Nu acum';

  @override
  String get notSet => 'Nu setat';

  @override
  String get notSetUp => 'Nu este configurat';

  @override
  String get notTheSameAsAdmin => 'Nu la fel cu admin';

  @override
  String get nothingFound => 'Nu s-a găsit nimic';

  @override
  String get nothingHereYet => 'Nimic aici încă.';

  @override
  String get nothingHereYet2 => 'Nimic aici încă';

  @override
  String get nothingMatches => 'Nimic nu se potrivește';

  @override
  String get nothingStoredYet => 'Nimic încă stocat.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID client OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth client id secret redirecționare cheie API';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth client id secret redirecționare gmail calendar drive';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Lansarea OAuth nu este acceptată pe această platformă.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'Secretul de identificare a clientului locatarului oauth Outlook';

  @override
  String get oauthToken => 'Jeton OAuth';

  @override
  String get oauthWithPkce => 'OAuth cu PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'din $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'propriilor sale. Nu se mai afișează niciodată după salvare.';

  @override
  String get off => 'Oprit';

  @override
  String get officialIntegration => 'Integrare oficială';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Integrarea oficială nu a returnat o adresă URL de conectare.';

  @override
  String get on => 'Pornit';

  @override
  String get onASignedInAndroidDevice =>
      'Pe un dispozitiv Android conectat, deschide Setări › Conectare și securitate, scanează acest cod și aprobă autentificarea.';

  @override
  String get onByDefaultForNewGroups =>
      'Activat în mod implicit pentru grupuri noi';

  @override
  String get onDemand => 'La cerere';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Activat pentru grupurile $arg1 sau $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'pe. Se pot alătura din nou numai cu un nou link de invitație.';

  @override
  String get onYourOwnTheDefault => 'Pe cont propriu (prestabilit)';

  @override
  String get once => 'Odată';

  @override
  String get oneIsSavedOtherChangesIn =>
      'unul este salvat. Sunt salvate și alte modificări din acest formular.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Unul sau mai multe conturi au expirat. Reconectați contul afectat pentru a restabili accesul la instrument.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Un timp de rulare controlează persoana, turnarea în grup, memoria camerei, normele, teoria minții și livrarea.';

  @override
  String get oneTimeRun => 'Aleargă o singură dată';

  @override
  String get onlyApkOrApksFilesCan =>
      'Numai fișierele .apk sau .apks pot fi instalate.';

  @override
  String get onlyInThisGroup => 'Doar in acest grup';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Este necesar doar dacă serviciul solicită antete HTTP suplimentare.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Este necesar doar dacă doriți să remodelați sarcina utilă de ieșire.';

  @override
  String get onlyTheyCanChangeIt => 'Numai ei o pot schimba.';

  @override
  String get open => 'Deschide';

  @override
  String get openAccountSettingsOnASigned =>
      'Deschide Setări › Conectare și securitate pe un dispozitiv Android conectat, scanează acest cod și aprobă autentificarea.';

  @override
  String get openComputer => 'Deschide computerul';

  @override
  String get openDashboard => 'Deschide tabloul de bord';

  @override
  String get openFolder => 'Deschide folderul...';

  @override
  String get openInWorkbench => 'Deschis în bancul de lucru';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Deschideți NeoAgent și reconectați $arg1 pentru a restabili mesajele.';
  }

  @override
  String get openTimeSettings => 'Deschideți setările de timp';

  @override
  String get openToAnyone => 'Deschis oricui';

  @override
  String get openTrello => 'Deschide Trello';

  @override
  String get openVoiceAssistant => 'Deschideți asistentul vocal';

  @override
  String get openWiFiSettings => 'Deschideți setările Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Deschideți cu aplicația implicită';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'compatibil openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Punct final compatibil cu OpenAI (propriul dvs. server sau altul ';

  @override
  String openedArg1(Object? arg1) {
    return 'S-a deschis $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Deschiderea adreselor URL de pe desktop nu este acceptată pe această platformă.';

  @override
  String get openingYourSavedDesktop => 'Deschiderea desktopului salvat.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Deschiderea desktopului salvat. Pornirile normale durează mai puțin de 10 secunde.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Opțional suplimentar secret dacă protejați webhook-ul de intrare.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Suprascriere opțională dacă URL-ul webhook nu este suficient.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Secret opțional pentru a verifica evenimentele de chat primite.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Secret opțional pentru a verifica evenimentele primite.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Secret opțional pentru a verifica evenimentele iMessage primite.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Secret opțional pentru a verifica evenimentele LINE primite.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Secret opțional pentru a verifica evenimentele Mattermost primite.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Secret opțional pentru a verifica evenimentele Teams primite.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Opțional. Agentul are deja propria personalitate. Orice adăugați despre ton este stratificat deasupra, așa că nu trebuie să definiți niciodată unul.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Opțional. Când este setat, este folosit în locul adresei URL.';

  @override
  String get orAnswerInYourOwnWords => 'Sau răspunde cu cuvintele tale';

  @override
  String get orBuildYourOwnTask => 'Sau construiește-ți propria sarcină';

  @override
  String get orContinueWith => 'sau continua cu';

  @override
  String get orFiles => 'sau fișiere.';

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
  String get originNotAllowed => 'originea nu este permisă';

  @override
  String get outgoingMessage => 'Mesaj trimis';

  @override
  String get outgoingWebhookUrl => 'Adresa URL webhook de ieșire';

  @override
  String get outlookEmailReceived => 'E-mail Outlook primit';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Suprascrie notele de comportament din import.';

  @override
  String get ownModel => 'propriul model';

  @override
  String get packageName => 'Numele pachetului';

  @override
  String get pairWithQrCode => 'Asociați cu codul QR';

  @override
  String get password => 'Parolă';

  @override
  String get password2faAndActiveSessions => 'Parolă, 2FA și sesiuni active';

  @override
  String get passwordCreated => 'Parola creată.';

  @override
  String get passwordIsTooWeak => 'parola este prea slabă';

  @override
  String get passwordMin8 => 'parola min 8';

  @override
  String get passwordOrApiKey => 'Parolă sau cheie API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Puterea parolei: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Parolele nu se potrivesc.';

  @override
  String get pasteAKey => 'Lipiți o cheie.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Lipiți o cheie nouă pentru a înlocui $arg1';
  }

  @override
  String get pasteTheKey => 'Lipiți cheia';

  @override
  String get pasteYourAccountToken => 'Lipiți indicativul de cont';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Lipiți mai jos cheia dvs. API $arg1. Este ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Calea trebuie să rămână în interiorul NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Calea trebuie să rămână în folderul spațiului de lucru.';

  @override
  String get pauseLiveUpdates => 'Întrerupeți actualizările live';

  @override
  String get pauseTaskLoop => 'Întrerupeți bucla sarcinii';

  @override
  String get paused => 'Întrerupt';

  @override
  String peakArg1(Object? arg1) {
    return 'vârful $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Oameni în chat-uri private';

  @override
  String get perAccountRateLimits => 'Limitele ratelor pe cont';

  @override
  String get perCategoryPermissions => 'Permisiuni pe categorie';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Politici de permisiuni per instrument, porți de aprobare și izolarea proceselor pentru execuția shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Permisiune necesară: $arg1';
  }

  @override
  String get permissionsNeeded => 'Permisiuni necesare';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Permisiuni. Nimeni altcineva nu poate schimba asta.';

  @override
  String get personOrChat => 'Persoană sau chat';

  @override
  String get personaBehaviorNotes => 'Note de comportament ale personajului';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Token de acces personal pentru botul Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Canale personale și suprafețe de sprijin direct.';

  @override
  String get personalSelfChat => 'Auto-chat personal';

  @override
  String get phoneNumber => 'Număr de telefon';

  @override
  String get pickARunFromTheList =>
      'Alegeți o cursă din listă pentru a-i vedea pașii.';

  @override
  String get pickARunFromTheList2 =>
      'Alegeți o cursă din lista din stânga pentru a-i explora fluxul.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Alegeți dintre discuțiile recente $arg1 sau adăugați o persoană sau un grup.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Alegeți modul în care $arg1 utilizează acest cont.';
  }

  @override
  String get pickOneToFillInThe =>
      'Alegeți unul pentru a completa sarcina. Puteți modifica totul după aceea.';

  @override
  String get picksUpWhereYouLeftOff => 'Reia de unde ai rămas';

  @override
  String get plan => 'Planifică';

  @override
  String get planning => 'Planificarea';

  @override
  String get platform => 'Platformă';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Vă rugăm să alegeți un program.';

  @override
  String get pleaseEnterAFilename =>
      'Vă rugăm să introduceți un nume de fișier.';

  @override
  String get pleaseEnterAKey => 'Vă rugăm să introduceți o cheie.';

  @override
  String get pleaseEnterAPrompt => 'Vă rugăm să introduceți o solicitare.';

  @override
  String get pleaseEnterATaskName =>
      'Vă rugăm să introduceți un nume de activitate.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Vă rugăm să introduceți conținutul memoriei.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Vă rugăm să introduceți când trebuie să ruleze sarcina.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Selectați un cont sau introduceți un ID de conexiune valid.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Indicați NeoAgent la orice finalizări de chat compatibile cu OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Îndreptați camera către codul afișat pe dispozitivul deconectat. Aprobarea rămâne pe acest telefon.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env public url încredere proxy implementare securizată cookie-uri';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Automatizare premium cu programare și declanșatoare de integrare.';

  @override
  String get prepareQrCode => 'Pregătiți codul QR';

  @override
  String get preparingNeoagent => 'Se pregătește NeoAgent...';

  @override
  String get preparingNeoagent2 => 'Pregătirea NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Apăsați lung pentru a captura rapid';

  @override
  String get pressKeysIsNotSupportedOn =>
      'apăsarea tastelor nu este acceptată pe această platformă.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Apăsat $arg1';
  }

  @override
  String get priceUnknown => 'Preț necunoscut';

  @override
  String get primaryDisplay => 'Afișaj primar';

  @override
  String get privateChat => 'Chat privat';

  @override
  String get privateChats => 'Chaturi private';

  @override
  String get privateChats2 => 'chat-uri private';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Chaturi private: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Chaturi private $arg1 · grupuri $arg2';
  }

  @override
  String get privateChatsOnly => 'Numai chaturi private';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'adresele de rețea privată nu sunt permise.';

  @override
  String get profileEmailAndPersonalData => 'Profil, e-mail și date personale';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Solicitați înainte ca NeoAgent să rămână rezident în bara de sistem.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Prompt cache: jetoane $arg1 stocate în cache ';
  }

  @override
  String get promptCopied => 'Solicitarea a fost copiată.';

  @override
  String get promptOrSchedule => 'prompt sau program.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Solicitați inserarea într-un alt AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Conectarea furnizorului nu a putut fi pornită.';

  @override
  String get providerSignInCouldNotBe =>
      'Conectarea furnizorului nu a putut fi începută.';

  @override
  String get providers => 'Furnizorii';

  @override
  String get providersEachAccountCanStillPick =>
      'Furnizori; fiecare cont își poate alege în continuare propriul model în Setări. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Furnizorii, integrările, vocea și capabilitățile opționale pot fi completate oricând din Setări.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Probleme publice și fire de solicitare de tragere, răspunsuri numai pentru persoanele aprobate.';

  @override
  String get publicUrl => 'Adresă URL publică';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Adresa URL publică și originile permise';

  @override
  String get publicUrlOverride => 'Înlocuirea adresei URL publice';

  @override
  String get pullsTogetherTheDayAhead => 'Reunește ziua care urmează';

  @override
  String get pushToTalk => 'Apăsați pentru a vorbi';

  @override
  String get qrBasedPhoneLinking => 'Conectarea telefonului bazată pe QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Conectarea QR a fost finalizată, dar NeoAgent nu a putut păstra sesiunea. Vă rugăm să încercați din nou.';

  @override
  String get qrLoginCouldNotBeStarted => 'Conectarea QR nu a putut fi pornită.';

  @override
  String get qrLoginRequestHasExpired =>
      'Solicitarea de conectare qr a expirat';

  @override
  String get qrLoginRequestWasNotFound =>
      'Cererea de conectare qr nu a fost găsită';

  @override
  String get qrPairing => 'Împerecherea QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'interogările rulează; orice scrie este respins.';

  @override
  String get queryFilter => 'Interogare / Filtru';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Așezat în coadă ca direcție pentru rularea curentă: $arg1';
  }

  @override
  String get quickstart => 'Pornire rapidă';

  @override
  String get quit => 'Renunță';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'A rulat un script în pagină';

  @override
  String ranArg1(Object? arg1) {
    return 'A rulat $arg1';
  }

  @override
  String get rateLimits => 'Limitele ratelor';

  @override
  String get readAnArtifact => 'Citiți un artefact';

  @override
  String get readAndEditFilesInsideYour =>
      'Citiți și editați fișierele din dosarul dvs. NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Citiți $arg1';
  }

  @override
  String get readError => 'Eroare de citire';

  @override
  String get readFiles => 'Citiți fișiere';

  @override
  String get readOnly => 'Numai citire';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Citiți folderul și rezumați stiva, punctele de intrare și cum să-l rulați.';

  @override
  String get readThePage => 'Citiți pagina';

  @override
  String get readTheUiTree => 'Citiți arborele UI';

  @override
  String get readWrite => 'Citește/Scrie';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Citește pași, ritm cardiac, somn, exerciții fizice și greutate.';

  @override
  String get ready => 'Gata';

  @override
  String get readyForFirstTimeSetup => 'Gata pentru prima configurare';

  @override
  String get readyToConnect => 'Gata de conectare';

  @override
  String get recentChannelActivity => 'Activitate recentă a canalului';

  @override
  String get recentChats => 'Chat-uri recente';

  @override
  String get recentDecisions => 'Deciziile recente';

  @override
  String get recentFailedRuns => 'Execuții eșuate recente';

  @override
  String get recentGroupDecisions => 'Deciziile recente ale grupului';

  @override
  String get recentRuns => 'Curse recente';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Execuțiile recente durează aproximativ $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Ieșire recentă de server, cel mai nou primul.';

  @override
  String get recentUsage4Hours => 'Utilizare recentă (4 ore)';

  @override
  String get recents => 'Recente';

  @override
  String get recipientField => 'Câmpul destinatarului';

  @override
  String get reconnectOrFinishSetup =>
      'Reconectați sau finalizați configurarea';

  @override
  String get reconnectingThisDevice => 'Se reconecta acest dispozitiv...';

  @override
  String get recurring => 'Recurente';

  @override
  String get redirectUri => 'URI de redirecționare';

  @override
  String get redoOnboarding => 'Refaceți integrarea';

  @override
  String get refresh => 'Reîmprospătați';

  @override
  String get refreshCode => 'Actualizează codul';

  @override
  String get refreshNow => 'Actualizează acum';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Actualizează ecranul Android pentru a încerca din nou.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Refuzați trimiterea decât dacă conexiunea se face upgrade la TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'indiferent de setările pentru fiecare categorie de mai jos.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Înregistrați $arg1 pentru fluxul de convocare a asistentului.';
  }

  @override
  String get registrationIsClosed => 'înregistrarea este închisă';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'înregistrarea înregistrare conturi noi permit înscrierea';

  @override
  String get rejectInvalidTlsCertificates =>
      'Respinge certificatele TLS nevalide';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'eliberați și repornește. Aplicațiile conectate se reconectează odată ce revin.';

  @override
  String get releaseChannel => 'Lansați canalul';

  @override
  String get releaseCommitBranchNode => 'eliberați nodul de ramură de comitere';

  @override
  String get releaseWhenYouAreDone => 'Eliberați-vă când ați terminat.';

  @override
  String get reloadNow => 'Reîncărcați acum';

  @override
  String get rememberThisChoice => 'Amintiți-vă de această alegere';

  @override
  String get remove => 'Eliminați';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Eliminați „$arg1” și pașii săi înregistrați din istoricul rulărilor?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Eliminați „$arg1” din memoria de bază.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Eliminați cheia $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'eliminați ștergeți utilizatorul gdpr';

  @override
  String get removeSmtpPassword => 'Eliminați parola SMTP';

  @override
  String get removeTheSmtpPassword => 'Eliminați parola SMTP?';

  @override
  String get rename => 'Redenumiți';

  @override
  String get renameSecurityKey => 'Redenumiți cheia de securitate';

  @override
  String get renameSession => 'Redenumiți sesiunea';

  @override
  String get repairAndRetry => 'Reparați și reîncercați';

  @override
  String get repairDesktop => 'Reparați desktopul';

  @override
  String get repeat => 'Repetați';

  @override
  String get repliesWhenTagged => 'Răspunsuri când sunt etichetate';

  @override
  String get replyToAddress => 'Adresă de răspuns';

  @override
  String replyToArg1(Object? arg1) {
    return 'Răspunde la $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Depozitul trebuie să fie în formatul proprietar/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproduceți eroarea pe care o descriu, găsiți cauza principală și remediați-o cu un test de regresie.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'cererea a eșuat cu http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Solicitarea a eșuat cu HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Solicitați permisiuni';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Solicitarea către $arg1 a eșuat înainte ca backend-ul să răspundă.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Solicitat $arg1';
  }

  @override
  String get requireStarttls => 'Necesită STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Necesar în spatele HTTPS sau a unui proxy TLS. Se aplică după un server ';

  @override
  String get requiredExampleBerlinDe => 'Necesar. Exemplu: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Necesar. Format: proprietar/repo';

  @override
  String get reserveAssistantHotkey => 'Tasta rapidă a asistentului de rezervă';

  @override
  String get reset => 'Resetați';

  @override
  String get resetPassword => 'Resetează parola';

  @override
  String get resetView => 'Resetați vizualizarea';

  @override
  String get responsibilities => 'Responsabilitati';

  @override
  String get restart => 'Reporniți';

  @override
  String get restartToFinishTheUpdate =>
      ' Reporniți pentru a finaliza actualizarea.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Restaurarea timpului de rulare anterior al NeoAgent';

  @override
  String get restrictDelegationTargets =>
      'Restricționați obiectivele de delegare';

  @override
  String get result => 'Rezultat';

  @override
  String get resultDelivery => 'Livrarea rezultatelor';

  @override
  String get resultOneClickAddsOneYou =>
      'rezultat. Un clic adaugă unul; îl poți edita mai târziu.';

  @override
  String get results => 'Rezultate';

  @override
  String get retry => 'Reîncercați';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Reutilizabil · folosit $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Examinați modificările neangajate';

  @override
  String get revoke => 'Revocați';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Revocați administratorul cu `neoagent admin revoke $arg1` mai întâi';
  }

  @override
  String get revokeThisLink => 'Revocați acest link?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Fereastra lot de cameră: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Rotiți pentru a continua';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rânduri. Adăugați o clauză LIMIT sau WHERE mai restrânsă pentru a vedea ';

  @override
  String get rule => 'Regula';

  @override
  String get run => 'Execuție';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Rulați comenzi arbitrare pe mașina dvs. sau pe VM.';

  @override
  String get runAt => 'Alerga la';

  @override
  String get runCompleted => 'Executare finalizată';

  @override
  String get runFailed => 'Executarea a eșuat';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Rulați git diff, examinați modificările necommise pentru erori și probleme de stil și rezumați ceea ce găsiți.';

  @override
  String get runNotFound => 'Run nu a fost găsit';

  @override
  String get runNow => 'Execută acum';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Rulați pe mesajele WhatsApp personale de intrare.';

  @override
  String get runQuery => 'Rulați interogarea';

  @override
  String get runShellCommandsOrInstallApps =>
      'Rulați comenzi shell sau instalați aplicații pe dispozitivul dvs. Android.';

  @override
  String get runStarted => 'A început alergarea';

  @override
  String get runStatus => 'Starea rulării';

  @override
  String get runStopped => 'Alergarea oprită';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Rulați comenzile terminalului și deschideți aplicații sau pagini web.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Rulați acest server: conturi, actualizări, furnizori, configurare ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Rulați când sosește un mesaj Gmail potrivit.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Rulați când sosește un e-mail Outlook corespunzător.';

  @override
  String get runWhenANewIssueMatching =>
      'Rulați atunci când o nouă problemă care se potrivește cu filtrele dvs. este deschisă într-un depozit.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Rulați când este creată o nouă memorie NeoRecall care se potrivește cu filtrele dvs.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Rulați când sosește o notificare pe dispozitiv.';

  @override
  String get runWhenASlackMessageMatches =>
      'Rulați când un mesaj Slack se potrivește cu domeniul selectat.';

  @override
  String get runWhenATeamsChatMessage =>
      'Rulați când un mesaj de chat Teams se potrivește cu domeniul selectat.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Rulați când sunt prognozate evenimente meteo configurate pentru o locație.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'alerga. În timp ce orice model este dezactivat, modelele pe care furnizorii le adaugă ';

  @override
  String get running => 'În curs';

  @override
  String runningArg1(Object? arg1) {
    return 'Rulează $arg1';
  }

  @override
  String get runningTask => 'Sarcina de rulare';

  @override
  String get runningTool => 'Instrument de alergare';

  @override
  String get runs => 'Execuții';

  @override
  String get runsEveryDayAtTheSelected =>
      'Se rulează în fiecare zi la ora selectată.';

  @override
  String get runsFourTimesPerHour => 'Aleargă de patru ori pe oră.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— rulări, mesaje, amintiri, integrări, fișiere și ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'rulări, mesaje, amintiri, integrări, fișiere și sesiuni. ';

  @override
  String get runsMondayThroughFriday => 'Funcționează de luni până vineri.';

  @override
  String get runsOnSelectedWeekdays =>
      'Se rulează în anumite zile ale săptămânii.';

  @override
  String get runsOncePerHour => 'Se execută o dată pe oră.';

  @override
  String get runsOncePerMonthOnThe =>
      'Se rulează o dată pe lună în ziua selectată.';

  @override
  String get runsOnlyWhenYouPressRun => 'Rulează numai când apăsați Run Now.';

  @override
  String get runsPerDay => 'Aleargă pe zi';

  @override
  String get runsPerDay30Days => 'Se execută pe zi (30 de zile)';

  @override
  String get runsThatCompleted => 'Execuții care s-au finalizat';

  @override
  String get runsThisWeek => 'Se rulează săptămâna aceasta';

  @override
  String get runsToday => 'Aleargă astăzi';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Rulele, instrumentele, memoria, programarea, abilitățile și MCP sunt toate disponibile aici.';

  @override
  String get runsTwicePerHour => 'Se execută de două ori pe oră.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Rulele vor reveni la cheia de server partajată pentru $arg1, dacă este configurată una. Acest lucru nu poate fi anulat.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Runtime $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Timp de rulare: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Setări de rulare cu care a început acest server. Editați-le sub ';

  @override
  String get runtimeSetupRequired =>
      'Este necesară configurarea timpului de execuție';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Cheia publică de semnare în timpul executării trebuie să aibă 32 de octeți.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Salvați';

  @override
  String get saveATrelloApiKeyFor =>
      'Salvați o cheie API Trello pentru acest agent, apoi conectați un cont Trello în siguranță. Indicatorul de cont este stocat pe server și folosit numai pentru acest agent.';

  @override
  String get saveAccount => 'Salvați contul';

  @override
  String get saveChanges => 'Salvați modificările';

  @override
  String get saveCloudComputerSettings =>
      'Salvați setările computerului în cloud';

  @override
  String get saveConnect => 'Salvați și conectați-vă';

  @override
  String get saveDefaults => 'Salvați valorile implicite';

  @override
  String get saveDiagnosticReport => 'Salvați raportul de diagnosticare';

  @override
  String get saveEmail => 'Salvați e-mailul';

  @override
  String get saveEmailSettings => 'Salvați setările de e-mail';

  @override
  String get saveGeneralSettings => 'Salvați setările generale';

  @override
  String get saveName => 'Salvați numele';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Salvați diagnosticele de configurare NeoAgent';

  @override
  String get saveOnly => 'Doar Salvați';

  @override
  String get saveSetup => 'Salvați configurația';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Salvați aceste coduri de recuperare acum. Nu vor fi afișate din nou.';

  @override
  String get savedDeliveryDestination => 'Destinație de livrare salvată';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Limitele ratelor salvate pentru @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Scanați un QR de conectare NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scanați un QR de asociere NeoAgent de pe alt dispozitiv și aprobați-l din această sesiune de lansare.';

  @override
  String get scanLoginQr => 'Scanați QR de conectare';

  @override
  String get scanPairingQr => 'Scanați QR de asociere';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scanează solicitările de conectare QR de la dispozitivele deconectate și aprobă-le din această sesiune mobilă autentificată.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scanați pentru a finaliza $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone => 'Scanați cu NeoAgent pe telefon';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Scanează e-mailuri noi și vă trimite un ping doar când ceva contează.';

  @override
  String get schedule => 'Program';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'ora programata. Odată ce rulările sunt măsurate, va începe mai devreme.';

  @override
  String get screen => 'Ecran';

  @override
  String get screenAction => 'acțiunea ecranului';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scroll nu este acceptat pe această platformă.';

  @override
  String get scrollToBottom => 'Derulați în jos';

  @override
  String get search => 'Caută';

  @override
  String get search2 => 'Cauta...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Căutați setări de administrator (de exemplu, SMTP, Ollama, jurnale)';

  @override
  String get searchAgain => 'Caută din nou';

  @override
  String get searchByUsernameOrEmail =>
      'Căutați după nume de utilizator sau e-mail';

  @override
  String get searchChannels => 'Căutați canale';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Căutați canale de mesagerie, persoane de contact, grupuri și conversații recente descoperite.';

  @override
  String get searchGroups => 'Căutați grupuri';

  @override
  String get searchMemory => 'Căutați în memorie';

  @override
  String get searchModelsOrProviders => 'Căutați modele sau furnizori';

  @override
  String get searchModelsOrProviders2 => 'Căutați modele sau furnizori...';

  @override
  String get searchRecentPeopleAndGroups =>
      'Căutați persoane și grupuri recente';

  @override
  String get searchSessions => 'Sesiuni de căutare';

  @override
  String get searchSettings => 'Setări de căutare';

  @override
  String get searchTitleModelTriggerRunId =>
      'Căutați titlul, modelul, declanșatorul, ID-ul de rulare';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Instrumente de căutare, integrări și abilități';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Codul căutat pentru „$arg1”';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Fișiere căutate pentru „$arg1”';
  }

  @override
  String get secretField => 'Câmp secret';

  @override
  String get secureCookies => 'Cookie-uri securizate';

  @override
  String get security => 'Securitate';

  @override
  String get securityKey => 'Cheie de securitate';

  @override
  String get securityKeyPromptWasDismissed =>
      'Solicitarea cheii de securitate a fost respinsă.';

  @override
  String get securityKeySignInCompletedBut =>
      'Conectarea cu cheia de securitate a fost finalizată, dar NeoAgent nu a putut păstra sesiunea de browser. Vă rugăm să vă conectați din nou.';

  @override
  String get securityKeySignInCouldNot =>
      'Conectarea cu cheia de securitate nu a putut fi pornită.';

  @override
  String get securityKeys => 'Chei de securitate';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Cheile de securitate sunt disponibile numai în aplicația web NeoAgent.';

  @override
  String get seeAll => 'Vezi toate';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Vedeți ce server NeoAgent folosește această fereastră și rulați backend-ul pe acest computer.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'vezi numele tău de utilizator și aceste setări, niciodată chat-urile, amintirile tale ';

  @override
  String get selectARun => 'Selectați o alergare';

  @override
  String get selectASessionToSeeIts =>
      'Selectați o sesiune pentru a vedea computerul, fișierele și modificările acesteia.';

  @override
  String get selectAll => 'Selectați toate';

  @override
  String get selectAll2 => 'Selectați Toate';

  @override
  String selectArg1(Object? arg1) {
    return 'Selectați $arg1';
  }

  @override
  String get selectTrigger => 'Selectați Declanșare';

  @override
  String get send => 'Trimite (⌘↵)';

  @override
  String get send2 => 'Trimite';

  @override
  String get sendATaskFromChatAnd =>
      'Trimiteți o sarcină din chat și istoricul executării acesteia va apărea aici.';

  @override
  String get sendItToATeammateWith =>
      'trimite-l unui coechipier cu un cont pe acest server.';

  @override
  String get sendLink => 'Trimite link';

  @override
  String get sendPath => 'Trimite calea';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Trimiteți solicitări POST / PUT / DELETE către API-uri externe.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Trimiteți acest link numai persoanei căreia îi este destinat. Se arată o dată; ';

  @override
  String get senderAddress => 'Adresa expeditorului';

  @override
  String get senderFilterOptional => 'Filtru expeditor (opțional)';

  @override
  String get sentSharedAttachments => 'A trimis atașamente partajate.';

  @override
  String get separateAccount => 'Cont separat';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Implicit server ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Serverul implicit pentru apelurile vocale în aplicație. Apelurile rulează în direct ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'serverul în sine: conturi, furnizori și configurație.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, pseudonim, canal și TLS opțional';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'server de ieșire consola avertismente erori de copiere';

  @override
  String get serverProviderCredentials => 'Acreditările furnizorului de server';

  @override
  String get serverUrl => 'Adresa URL a serverului';

  @override
  String get serverUsageLimitsDonTApply =>
      'Limitele de utilizare a serverului nu se aplică modelelor care rulează pe propria cheie.';

  @override
  String get serviceEmail => 'E-mail de serviciu';

  @override
  String get serviceEmailIsNotConfigured =>
      'e-mailul de serviciu nu este configurat';

  @override
  String get serviceEmailSmtp => 'E-mail de serviciu (SMTP)';

  @override
  String get sessionActions => 'Acțiuni de sesiune';

  @override
  String get sessions => 'Sesiuni';

  @override
  String get sessions2 => 'SESIUNI';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sesiunile sunt fixate într-un folder și pe un computer. Începeți unul pentru a planifica, construi, testa și expediați de aici.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sesiuni (GDPR Art. 17). Conturile de administrator nu pot fi șterse ';

  @override
  String get sessionsLogoutRevokeForce =>
      'deconectarea sesiunilor revoca forța';

  @override
  String get setBlockAskAllowPerTool =>
      'Setați blocarea / solicitarea / permisiunea pentru fiecare categorie de instrumente sau alegeți un mod global.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Configurați NeoAgent pe acest computer';

  @override
  String get setUpOrConnectNeoagent => 'Configurați sau conectați NeoAgent';

  @override
  String get setUrl => 'Setați adresa URL';

  @override
  String get settings => 'Setări';

  @override
  String get settingsAndCannotBeUndone => 'setări și nu poate fi anulată.';

  @override
  String get settingsArea => 'Zona de setări';

  @override
  String get settingsAreas => 'Zone de setări';

  @override
  String get setup => 'Configurare';

  @override
  String get setupDetails => 'Detalii de configurare';

  @override
  String get setupRequired => 'Configurare necesară';

  @override
  String get setupWasCancelled => 'Configurarea a fost anulată.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Atașamente partajate de la clientul NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Partajat din altă aplicație';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Cheile de furnizor partajate sunt configurate pe server. Pentru a utiliza propria cheie API sau un punct final personalizat, accesați Avansat → Aduceți propria cheie.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Partajat cu chat-ul NeoAgent și memoria acestuia.';

  @override
  String get shellCommands => 'Comenzi Shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Afișați toate $arg1';
  }

  @override
  String get showEarlier => 'Arată mai devreme';

  @override
  String get showEveryStep => 'Arată fiecare pas';

  @override
  String get showTools => 'Arată instrumentele';

  @override
  String get showWorkbenchJ => 'Afișați bancul de lucru (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Se afișează primul $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Afișat în bara laterală. Lăsați necompletat pentru a vă folosi numele de utilizator.';

  @override
  String get signIn => 'Conectați-vă';

  @override
  String get signInCompletedButNeoagentCould =>
      'Conectarea a fost finalizată, dar NeoAgent nu a putut păstra sesiunea de browser. Vă rugăm să vă conectați din nou. Dacă acest lucru continuă să se întâmple, verificați setările cookie-urilor sesiunii de backend.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Conectarea a fost finalizată, dar NeoAgent nu a putut păstra sesiunea de browser. Vă rugăm să vă conectați din nou. Dacă acest lucru continuă să se întâmple, cookie-ul de sesiune de backend este probabil să nu fie reținut.';

  @override
  String get signInToThisNeoagentServer =>
      'Conectați-vă la acest server NeoAgent înainte de a scana un cod QR de asociere.';

  @override
  String get signInWithAHardwareKey =>
      'Conectați-vă cu o cheie hardware sau o cheie de acces în loc de parola dvs. ';

  @override
  String get signInWithASecurityKey => 'Conectați-vă cu o cheie de securitate';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Conectați-vă cu $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Aprobați NeoAgent în contul dvs. $arg1. Nicio cheie de copiat.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Se așteaptă $arg1. Terminați în browser.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Lipiți codul $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'După ce ați aprobat NeoAgent, $arg1 a afișat un cod unic. Lipiți-l aici.';
  }

  @override
  String get signInCode => 'Cod de conectare';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Conectat cu $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Conectarea nu a reușit: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Conectați-vă cu aceeași e-mail și aceeași parolă principală pe care o utilizați în Bitwarden. Parola principală și codul în doi pași sunt folosite numai pentru conectare și nu sunt niciodată stocate sau trimise către AI.';

  @override
  String get signOut => 'Deconectați-vă';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Deconectați-vă @$arg1 peste tot?';
  }

  @override
  String get signOutEverywhere => 'Deconectați-vă peste tot';

  @override
  String get signalCliRestApiBridge => 'puntea semnal-cli REST API';

  @override
  String get signalCliServerUrl => 'URL-ul serverului signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Semnat @$arg1 din fiecare sesiune.';
  }

  @override
  String get signedInDevices => 'Dispozitive conectate';

  @override
  String get signedInWithin24Hours => 'Conectat în 24 de ore';

  @override
  String get signingSecret => 'Secret de semnare';

  @override
  String sinceArg1(Object? arg1) {
    return 'De la $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'din $arg1';
  }

  @override
  String get singleMessage => 'Un singur mesaj';

  @override
  String get singleUse => 'Utilizare unică';

  @override
  String get skill => 'Îndemânare';

  @override
  String get skillChanges => 'Schimbări de aptitudini';

  @override
  String get skillContent => 'Conținut de aptitudini';

  @override
  String get skills => 'Abilități';

  @override
  String get skip => 'Sari peste';

  @override
  String get skipForNow => 'Sari peste moment';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Omiteți această sarcină înainte de a apela modelul.';

  @override
  String get slackMessageReceived => 'Mesaj Slack primit';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Sesiuni de somn $arg1';
  }

  @override
  String get smartSelector => 'selector inteligent';

  @override
  String get smartSelector2 => 'Selector inteligent';

  @override
  String get smartSelectorPool => 'Pool Selector inteligent';

  @override
  String get smtpHost => 'gazdă SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail expeditor parola tls confirmare notificări resetate';

  @override
  String get smtpPassword => 'Parola SMTP';

  @override
  String get smtpPort => 'Port SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Portul SMTP trebuie să fie un număr întreg de la 1 la 65535.';

  @override
  String get smtpUsername => 'nume de utilizator SMTP';

  @override
  String get soTheRunStartsThatMuch =>
      'deci alergarea începe cu mult mai devreme.';

  @override
  String get socialBehaviorOff => 'Comportamentul social oprit';

  @override
  String get socialIntelligence => 'inteligența socială';

  @override
  String get socialIntelligence2 => 'Inteligența socială';

  @override
  String get socialObservability => 'Observabilitate socială';

  @override
  String get socialReach => 'acoperire socială';

  @override
  String get socialReach2 => 'Aria socială';

  @override
  String get socialReach3 => 'Atingerea socială';

  @override
  String get socialReachUpdated => 'Acoperirea socială a fost actualizată.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenții surselor sociale pot citi direct, inclusiv fluxuri, depozite, Reddit, X, videoclipuri și date de piață susținute de cookie-uri.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Ceva a mers prost. Vă rugăm să încercați din nou.';

  @override
  String get source => 'Sursa';

  @override
  String get spaceOrChatIdUsedWhen =>
      'ID de spațiu sau chat folosit când acest agent începe o conversație.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Asistență pentru aplicația webhook și apel invers spațial';

  @override
  String get speaking => 'Vorbind';

  @override
  String get speechToSpeechModelUsingThe =>
      'modelul de vorbire la vorbire folosind tasta OpenAI sau Google sub ';

  @override
  String get speechToText => 'Vorbire în text';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Speech-to-text transcrie notele vocale și dictarea. Auto folosește OpenAI, Gemini sau Deepgram, oricare dintre ele are o cheie API. Modelul de răspuns vocal este modelul de chat care răspunde la notele vocale.';

  @override
  String get sqlConsole => 'Consola SQL';

  @override
  String get stable => 'Stabil';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable instalează cea mai recentă versiune backend publicată.';

  @override
  String get stackTrace => 'urme de stivă';

  @override
  String get standard => 'Standard';

  @override
  String get standardView => 'Vedere standard';

  @override
  String get start => 'Începeți';

  @override
  String get startASessionToPlanOr =>
      'Începeți o sesiune pentru a planifica sau a construi cu NeoAgent.';

  @override
  String get startAndroid => 'Porniți Android';

  @override
  String get startComputer => 'Porniți computerul';

  @override
  String get startFullSetup => 'Începeți configurarea completă';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Începeți configurarea';

  @override
  String get startTalking => 'Începe să vorbești';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Porniți mai întâi telefonul Android, apoi plasați un fișier .apk sau .apks aici.';

  @override
  String get startTheServerLaterFromThe =>
      'Porniți serverul mai târziu din listă odată ce configurația este salvată.';

  @override
  String get startWithARecommendedTask => 'Începeți cu o sarcină recomandată';

  @override
  String get startingAndroid => 'Pornește Android';

  @override
  String get startingYourComputer => 'Pornirea computerului';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Începe cu xoxb-. Din acreditările aplicației Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'eroare startTelecomCallRouting: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistici rulează jetoane utilizatorii grafice rata de succes';

  @override
  String get status => 'Stare';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'furnizorii de VM de rulare a bazei de date de stare';

  @override
  String get statusIsNotLoadedYet => 'Starea nu este încă încărcată.';

  @override
  String get stayManagedByYou => 'rămâne gestionat de tine.';

  @override
  String get stayOnTheCall => 'Rămâi la apel';

  @override
  String get stayedQuiet => 'A stat liniștit';

  @override
  String get steering => 'DIRECȚIA';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'PASUL $arg1 AL $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Pașii $arg1';
  }

  @override
  String get stop => 'Oprește';

  @override
  String get stop2 => 'Opriți (⌘.)';

  @override
  String get stopManaging => 'Nu mai gestiona';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Nu mai gestionați $arg1?';
  }

  @override
  String get stopRun => 'Opriți alergatul';

  @override
  String get stopSpeaking => 'Nu mai vorbi';

  @override
  String get stoppedBeforeCompletion => 'S-a oprit înainte de finalizare';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'Eroare stopTelecomCallRouting: $arg1';
  }

  @override
  String get storage => 'Depozitare';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'stocat criptat și folosit numai pentru propriile rulări.';

  @override
  String get storedMetrics => 'Valori stocate';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Stochează doar cheia de sesiune Bitwarden criptată pe acest server, astfel încât conexiunile să supraviețuiască repornirilor. Îl poți bloca oricând.';

  @override
  String get strong => 'Puternic';

  @override
  String get strongPassword => 'Parolă puternică.';

  @override
  String get subAgent => 'Sub-agent';

  @override
  String get subagentUpdate => 'Actualizare subagent';

  @override
  String get subagentUpdate2 => 'Actualizare subagent.';

  @override
  String get successRate => 'Rata de succes';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Sugestii: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Rezumă ultima mea cursă';

  @override
  String get supportUrl => 'URL de suport';

  @override
  String get supportedRainStartSnowStartWind =>
      'Acceptat: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Schimbați agent';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Legăturile simbolice nu sunt permise în căile NeoAgent Workspace.';

  @override
  String get syncNow => 'Sincronizează acum';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings =>
      'Setările de confidențialitate ale sistemului';

  @override
  String get tableInfoUsers => 'Informații din tabel (utilizatori)';

  @override
  String get tagsOnly => 'Doar etichete';

  @override
  String get tasks => 'Sarcini';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Sarcinile rulează pe cont propriu și îți trimit mesaje ';

  @override
  String get teach => 'Învățați';

  @override
  String get teachingInProgress => 'Predare în curs';

  @override
  String get team => 'Echipa';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Linkurile de echipă nu fac niciodată pe nimeni administrator de server. Administratorii rulează ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Spații de echipă, camere, canale și comunități live.';

  @override
  String get teamsMessageReceived => 'Mesaj echipe primit';

  @override
  String get templates => 'Șabloane';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Fișierele de configurare temporare vor fi curățate ulterior.';

  @override
  String get tenantId => 'ID locatar';

  @override
  String get testConnection => 'Testați conexiunea';

  @override
  String get testConnection2 => 'Testează conexiunea';

  @override
  String get textChat => 'Text și chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'care și-au adăugat propria cheie continuă să o folosească.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Acel e-mail aparține deja unui cont existent. Conectați-vă mai întâi, apoi conectați Google din setările contului.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Acel e-mail este deja conectat la alt cont.';

  @override
  String get thatQrCodeIsNotA =>
      'Acest cod QR nu este o solicitare de conectare la NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Codul QR nu este o solicitare de asociere NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Cheia de securitate este deja înregistrată în acest cont.';

  @override
  String get theAddress => 'Adresa';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adresa serverului dvs. BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adresa pe care oamenii și furnizorii OAuth o folosesc pentru a ajunge ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agentul citește orele pe care le menționați și execută activități programate în acest fus orar.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agentul va întreba înainte de fiecare instrument sensibil, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Agentul va ignora această abilitate.';

  @override
  String get theAppCouldNotReachThis =>
      'Aplicația nu a putut ajunge la această implementare NeoAgent. Verificați conexiunea la rețea sau confirmați că adresa URL a serviciului este corectă.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Browserul a blocat o solicitare către $arg1 din cauza Politicii de securitate a conținutului.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Browserul a blocat o solicitare necesară din cauza Politicii de securitate a conținutului.';

  @override
  String get theCloudWorkspace => 'spațiul de lucru în cloud';

  @override
  String get theComputerCouldNotStart => 'Computerul nu a putut porni';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Computerul are nevoie de mai mult spațiu liber pe disc pe gazda NeoAgent. Eliberați spațiu, apoi încercați din nou.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Timpul de rulare a computerului necesită reparații. Rulați NeoAgent Doctor, apoi încercați din nou.';

  @override
  String get theConnectionTestFailed => 'Testul de conectare a eșuat.';

  @override
  String get theDesktopDidNotStart => 'Desktopul nu a pornit';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'NeoAgent descoperit a returnat date de identitate incomplete.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'NeoAgent descoperit folosește un protocol de configurare neacceptat.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Serviciul descoperit nu este NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Timpul de rulare NeoAgent descărcat nu a trecut verificarea.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook-ul spațiului Google Chat în care ar trebui să posteze acest agent.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Programul de instalare nu mai este disponibil.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Desktopul interactiv Linux este disponibil în aplicația web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Introducerea nu este disponibilă pe acest dispozitiv.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Cele mai recente rulează în fiecare cont.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Cea mai recentă fereastră de sincronizare s-a încheiat cu $arg1 și nu a găsit nicio înregistrare nouă Health Connect. Valorile stocate mai jos provin din sincronizări anterioare.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Sesiunea grafică Linux nu rulează.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Modelul de voce live nu a răspuns. Încearcă din nou.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Comanda locală NeoAgent a ieșit cu codul $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Comanda locală NeoAgent a expirat.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Runtime-ul local NeoAgent necesită reparații.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Timpul de rulare local necesită reparații ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Directorul principal al utilizatorului local este indisponibil.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Contul de e-mail NeoAgent trimite confirmări de înregistrare, conectare ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Agentul principal este creat automat atunci când este necesar.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Timpul de rulare NeoAgent potrivit lipsește din această versiune.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Webhook-ul Mattermost în care ar trebui să posteze acest agent.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modelele între care selectorul inteligent se direcționează automat.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Descărcarea backend NeoAgent nu s-a potrivit cu manifestul său.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Descărcarea backend NeoAgent a fost incompletă.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Backend-ul NeoAgent de pe acest computer nu răspunde pe port ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Runtime-ul de backend NeoAgent nu a putut fi descărcat.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Backend-ul NeoAgent a durat prea mult să răspundă pentru $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Implementarea NeoAgent a răspuns cu HTTP 402 în loc de 401 normal pentru acreditările nevalide. Verificați proxy invers, gateway de autentificare sau regulile legate de plată pe acel server.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Implementarea NeoAgent a răspuns cu HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Implementarea NeoAgent a răspuns cu HTTP 402. Verificați proxy invers, gateway de autentificare sau regulile legate de plăți pe acel server.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Instanța NeoAgent la care este conectată această aplicație.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Serviciul de lansare NeoAgent a returnat date nevalide.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Metadatele artefactului de rulare NeoAgent sunt nevalide.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Manifestul de rulare NeoAgent nu a trecut verificarea semnăturii.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Manifestul de rulare NeoAgent nu are artefacte.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Semnătura manifestului de rulare NeoAgent este nevalidă.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Parola pe care ați setat-o ​​în BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Oamenii pe care îi gestionați rămân cu voi.';

  @override
  String get theProviderAnswers => 'raspunde furnizorul.';

  @override
  String get theQueryReturnedNoRows => 'Interogarea nu a returnat niciun rând.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Afișajul desktop solicitat nu este disponibil.';

  @override
  String get theRest => 'restul.';

  @override
  String get theRestEndpointForYourSignal =>
      'Punctul final REST pentru instanța dvs. de semnal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Cursa este întreruptă până când răspundeți.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Executarea începe la ora programată.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Runtime este un desktop Debian Linux ușor, cu Chromium, PCManFM, Mousepad, LXTerminal, Python, Git și instrumente standard de linie de comandă. Capacitatea sa este gestionată de gazda NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Înregistrarea cheii de securitate nu a putut fi începută.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'serverul păstrează doar o amprentă a acestuia.';

  @override
  String get theServerOnThisComputerIs =>
      'Serverul de pe acest computer nu rulează';

  @override
  String get theServerReportedNoHealthChecks =>
      'Serverul nu a raportat verificări de sănătate.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Numărul de telefon Signal pe care îl folosește acest bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Webhook-ul de intrare Teams în care ar trebui să posteze acest agent.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Provocarea cu doi factori a expirat. Conectați-vă din nou.';

  @override
  String get theTwoFactorCodeIsNot => 'Codul cu doi factori nu este valid.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Pachetul de rulare verificat nu a putut fi marcat ca executabil.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Din pachetul de rulare verificat lipsesc fișierele necesare.';

  @override
  String get theWebAppCouldNotReach =>
      'Aplicația web nu a putut ajunge la backend-ul NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Aplicația web nu a putut ajunge la backend-ul NeoAgent la $arg1. Verificați consola browserului și configurația reverse-proxy/rețea.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'se; operatorul de server elimină admin mai întâi cu ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Aceste canale rămân tăcute. Pentru a afla din nou de la ei, adaugă-i sub Cine poate trimite mesaje pentru platforma respectivă.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Aceste liste sunt opționale, cu excepția cazului în care o secțiune de mai sus este setată doar ca aprobată.';

  @override
  String get thesePeopleAnywhere => 'Acești oameni, oriunde';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Aceste persoane pot trimite mesaje cu $arg1 în chat-urile private și în orice grup pe care îl partajează.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Aceste persoane pot trimite mesaje $arg1 unu-la-unu. Acest lucru nu îi permite să vorbească în grupuri.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Aceste persoane pot trimite mesaje numai cu $arg1 în grupul pe care l-ați ales.';
  }

  @override
  String get thesePeopleInOneGroup => 'Acești oameni, într-un singur grup';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'aceste comutatoare, niciodată chat-urile, amintirile sau fișierele dvs.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Acest cont va debloca NeoAgent pe această mașină.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Acest agent poate delega oricărui agent de primire eligibil.';

  @override
  String get thisAgentIsUsingAServer =>
      'Acest agent folosește o cheie API Trello gestionată de server. Trebuie doar să autorizați un simbol de cont mai jos.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Această versiune nu are voie să vorbească cu această implementare NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Acest cod aparține unui alt server NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Acest desktop este conectat';

  @override
  String get thisDevice => 'Acest dispozitiv';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Acest dispozitiv: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Acest dispozitiv nu poate înregistra cheile de securitate. Deschideți NeoAgent într-un browser prin HTTPS pentru a adăuga unul.';

  @override
  String get thisDeviceUnavailable => 'Acest dispozitiv — indisponibil';

  @override
  String get thisFileHasNoContent => 'Acest fișier nu are conținut.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Aceasta ascunde „$arg1” de rutare și selecție.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Această integrare acceptă în prezent un cont conectat pentru fiecare agent. Redeschideți configurația pentru a o înlocui.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Această integrare nu mai este disponibilă.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Această introducere este concepută pentru redarea peisajului pe tot ecranul.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Aceasta este o implementare gestionată. Operatorul său se lansează ';

  @override
  String get thisMayTakeAMoment => 'Acest lucru poate dura un moment.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Acest server MCP nu mai este configurat.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Această memorie va fi eliminată definitiv.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Această versiune NeoAgent nu este configurată pentru a verifica timpii de execuție backend.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Acest lucru șterge definitiv toate datele dvs. și nu poate fi ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Acest lucru șterge definitiv contul și tot ce deține: ';

  @override
  String get thisPersonAnywhere => 'Această persoană, oriunde';

  @override
  String get thisPersonInOneGroup => 'Această persoană, într-un singur grup';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Această solicitare de conectare QR a expirat. Generați un cod nou și încercați din nou.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'această solicitare de conectare QR a expirat';

  @override
  String get thisQrLoginRequestIsStill =>
      'Această solicitare de conectare QR încă așteaptă aprobare.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Această solicitare de conectare QR a fost deja utilizată.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Aceasta elimină configurarea Home Assistant și instanța conectată pentru acest agent.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Aceasta elimină adresa URL de backend NeoRecall și toate conturile NeoRecall conectate pentru acest agent.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Aceasta elimină adresa URL Nextcloud și toate conturile Nextcloud conectate pentru acest agent.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Aceasta elimină configurarea Trello și conturile conectate pentru acest agent.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Acest lucru necesită o sesiune autentificată pe același server NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Această rulare nu a produs un răspuns orientat către utilizator.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Această rulare nu are date de pas înregistrate.';

  @override
  String get thisServer => 'acest server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Acest server nu raportează setări ale furnizorului.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Această abilitate nu mai este instalată.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Această sarcină nu are încă o rulare finalizată, așa că începe încă la ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Această sarcină va rula numai când apăsați Run Now.';

  @override
  String get thisWeek => 'Săptămâna aceasta';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Acest lucru va importa răspunsul în $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Aceasta va elimina „$arg1”.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Aceasta va elimina „$arg1” din lista de servere.';
  }

  @override
  String get time => 'timpul';

  @override
  String get timeZone => 'fus orar';

  @override
  String get timeZone2 => 'Fus orar';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Timp expirat$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Nu s-au putut enumera fusurile orare: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nu s-a putut citi fusul orar al dispozitivului: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nu s-a putut salva fusul orar al dispozitivului: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'la $arg1';
  }

  @override
  String get toUseTheServerDefault => 'pentru a utiliza implicit serverul.';

  @override
  String get today => 'Astăzi';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Bugetul indicativ pentru @$arg1. Lăsați un câmp gol ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Bugetul indicativ pentru fiecare cont fără propria sa anulare. Lasă o ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'limită de buget indicativ 4 ore pe săptămână utilizator cotă';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'limită de buget indicativ 4 ore cotă săptămânală globală';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Utilizarea token-ului nu este disponibilă pe această versiune de server.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Jetoane orice cont poate folosi în 4 ore.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Jetoane orice cont poate folosi în 7 zile.';

  @override
  String get tokensPerDay => 'Jetoane pe zi';

  @override
  String get tokensPerRun => 'Jetoane per cursă';

  @override
  String get tokensToday => 'Jetoane astăzi';

  @override
  String get tokensUsed => ' jetoane folosite';

  @override
  String get tomorrowPrep => 'Mâine pregătire';

  @override
  String get tooManyAttempts => 'prea multe încercări';

  @override
  String get tooManySignInAttemptsPlease =>
      'Prea multe încercări de conectare. Vă rugăm să așteptați și să încercați din nou.';

  @override
  String get tool => 'Instrument';

  @override
  String get toolApproval => 'Aprobarea instrumentului';

  @override
  String get toolApprovalRequired => 'Este necesară aprobarea instrumentului';

  @override
  String get toolCompleted => 'Instrument finalizat';

  @override
  String get toolFailed => 'Instrumentul a eșuat';

  @override
  String get toolPermissions => 'Permisiuni pentru instrumente';

  @override
  String get toolStarted => 'Instrumentul a pornit';

  @override
  String get tools => 'Instrumente';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Instrumente care nu sunt integrate în NeoAgent, inclusiv servere MCP conectate și furnizori de instrumente personalizate.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Instrumente oferite ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Instrumente pe care contul gestionat le poate folosi';

  @override
  String get topUsers => 'Utilizatori de top';

  @override
  String get topUsersAndRecentRuns => 'Utilizatori de top și rulări recente';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Total: jetoane $arg1 în cursele $arg2';
  }

  @override
  String get totalRuns => 'Total alergări';

  @override
  String get totalTokens => 'Total de jetoane';

  @override
  String get totalUsers => 'Total utilizatori';

  @override
  String get transcript => 'Transcriere';

  @override
  String get transcript2 => 'TRANSCRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transcrierea eșuată: $arg1';
  }

  @override
  String get transfer => 'Transfer';

  @override
  String get trelloApiKey => 'Cheia API Trello';

  @override
  String get trelloApiKeyIsRequired => 'Cheia API Trello este necesară.';

  @override
  String get trelloSetup => 'Configurare Trello';

  @override
  String get triggerType => 'Tip de declanșare';

  @override
  String get tryABroaderSearchLikeModels =>
      'Încercați o căutare mai largă, cum ar fi modele, browser sau voce.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Încercați un nume de furnizor, „e-mail”, „limite”, „actualizare” sau „jurnal”.';

  @override
  String get tryAgain => 'Încercați din nou';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Încercați din nou. Dacă acest lucru continuă să se întâmple, rulați NeoAgent Doctor pentru a verifica timpul de rulare a computerului.';

  @override
  String get tryAgainInAMoment => 'Încercați din nou peste un moment.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Încercați din nou sau rulați NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Încercați o altă căutare, conectați o platformă de mesagerie sau introduceți manual un ID de destinație.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Activați un grup dacă $arg1 ar trebui să citească și mesaje care nu îl etichetează.';
  }

  @override
  String get turnOffComputer => 'Opriți computerul';

  @override
  String get turnOffOnlyForAMail =>
      'Dezactivați numai pentru un server de e-mail cu un certificat autosemnat.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Activați dacă Signal ar trebui să continue să caute chat-urile primite.';

  @override
  String get turnTaking => 'luarea pe rând';

  @override
  String get turnTakingModel => 'Model pe rând';

  @override
  String get turnTakingOff => 'Viraj-decolare';

  @override
  String get turnThisOffToKeepThis =>
      'Dezactivați această opțiune pentru a păstra acest agent complet separat de alți agenți.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Dezactivat de $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Dezactivat de $arg1, care gestionează acest cont. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Dezactivat pentru dvs. de $arg1 — numai ei îl pot schimba';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Dezactivat pentru tine, așa că nu îl poți distribui';

  @override
  String get twitchChatOverIrc => 'Chat Twitch prin IRC';

  @override
  String get twoFactorAuthentication => 'Autentificare cu doi factori';

  @override
  String get twoFactorChallengeExpired => 'provocarea cu doi factori a expirat';

  @override
  String get twoFactorCode => 'cod cu doi factori';

  @override
  String get twoFactorSignInCompletedBut =>
      'Conectarea cu doi factori a fost finalizată, dar NeoAgent nu a putut păstra sesiunea de browser. Vă rugăm să vă conectați din nou.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Conectare în doi pași (doar dacă este activată)';

  @override
  String get type => 'Tip';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Tastați $arg1 pentru a confirma';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'tip text nu este acceptat pe această platformă.';

  @override
  String get typedInTheBrowser => 'Tastat în browser';

  @override
  String get typedText => 'Text tastat';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'nu se poate localiza un timp de rulare java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Nu se pot deschide setările de timp pentru această versiune.';

  @override
  String get unableToOpenWiFiSettings =>
      'Nu se pot deschide setările Wi-Fi pe această versiune.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nu se poate persista afișarea desktopului selectată.';

  @override
  String get unclearWhoItWasFor => 'Nu este clar pentru cine a fost';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'anulat. Introduceți numele de utilizator pentru a confirma.';

  @override
  String get unknownAccount => 'Cont necunoscut';

  @override
  String get unknownAgent => 'Agent necunoscut';

  @override
  String get unknownBrowser => 'Browser necunoscut';

  @override
  String get unknownDevice => 'Dispozitiv necunoscut';

  @override
  String get unknownError => 'eroare necunoscută';

  @override
  String get unknownLocalComputerPermission =>
      'Permisiune necunoscută pentru computerul local.';

  @override
  String get unknownLocation => 'Locație necunoscută';

  @override
  String get unknownPublishTime => 'Ora de publicare necunoscută';

  @override
  String get unknownSize => 'Dimensiune necunoscută';

  @override
  String get unlink => 'Deconectați';

  @override
  String get unreadOnly => 'Numai necitit';

  @override
  String get unsavedChanges => 'Modificări nesalvate';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Comandă însoțitoare desktop neacceptată: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Metodă neacceptată: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Alerte de conectare neobișnuite';

  @override
  String updateArg1(Object? arg1) {
    return 'Actualizați $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Actualizați intrările din memoria de bază de la import.';

  @override
  String get updateNow => 'Actualizați acum';

  @override
  String get updateReady => 'Actualizare gata';

  @override
  String get updateSetup => 'Actualizați configurarea';

  @override
  String get updateTheAccessListToAllow =>
      'Actualizați lista de acces pentru a permite răspunsuri.';

  @override
  String get updateTheServer => 'Actualizați serverul?';

  @override
  String get updateTheServer2 => 'Actualizați serverul';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Actualizați automat fusul orar de pe dispozitivul pe care îl utilizați.';

  @override
  String updatedArg1(Object? arg1) {
    return 'actualizat $arg1';
  }

  @override
  String get updates => 'Actualizări';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Actualizările nu sunt configurate pentru această versiune.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'actualizări, așa că autoactualizarea și modificările canalului sunt dezactivate aici.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'actualizare de actualizare lansează acum canal beta stabil';

  @override
  String get usageAnalytics => 'Analiza utilizării';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Semnale de utilizare și sănătate care ajută la explicarea comportamentului curent de rulare fără a căuta mai întâi jurnalele.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Utilizarea se resetează complet în $arg1';
  }

  @override
  String get usageLeaderboard => 'clasament de utilizare';

  @override
  String get usageLimits => 'Utilizare și limite';

  @override
  String get usageLimits2 => 'Utilizare și limite';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Folosiți peste 8 caractere. Frazele de acces mai lungi funcționează bine.';

  @override
  String get useADateAndTimeFor =>
      'Utilizați o dată și o oră, de exemplu 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Utilizați un nume, un număr de telefon sau un ID de chat.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Utilizați o adresă URL NeoRecall la care poate ajunge serverul NeoAgent. PUBLIC_URL-ul lui NeoAgent trebuie să fie accesibil și din acest browser pentru apelarea OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Utilizați o nouă parolă cu cel puțin 8 caractere.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Utilizați o adresă URL Nextcloud la care poate ajunge serverul NeoAgent, de exemplu https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Utilizați o parolă cu cel puțin 8 caractere.';

  @override
  String get useASecureConnectionTls =>
      'Utilizați o conexiune securizată (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Utilizați o aplicație de autentificare, cum ar fi Authy, 1Password sau Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Utilizați cel puțin 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Memoria maximă pe computer (MB)';

  @override
  String get maxVcpusPerComputer => 'Max vCPU-uri pe computer';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Cel puțin $arg1. Calculatoarele devin mai puține atunci când gazda este ocupată.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Memoria maximă trebuie să fie de cel puțin $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Utilizați cel puțin 8 caractere.';

  @override
  String get useDefault => 'Utilizați implicit';

  @override
  String get useDefaultChannel => 'Utilizați canalul implicit';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Utilizați implicit (NeoAgent Workspace)';

  @override
  String get useFor => 'Utilizați pentru';

  @override
  String get useManualDestination => 'Utilizați destinația manuală';

  @override
  String get useOrDoTheSameFor =>
      'folosiți sau faceți același lucru pentru colegii dvs. de echipă.';

  @override
  String get usePerCategorySettingsBelow =>
      'Utilizați setările pentru fiecare categorie de mai jos.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Utilizați setările implicite ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Utilizați serverul de pe acest computer';

  @override
  String get useTheseForContextIfA =>
      'Folosiți-le pentru context. Dacă un URI local nu este accesibil direct de pe server, cereți-mi să furnizez fișierul printr-un spațiu de lucru accesibil.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Utilizați acest lucru pentru agenții orchestratori. Lăsați-l pe roboții de lucru izolați care ar trebui să termine singuri mesajele directe.';

  @override
  String get useTlsFromTheStartOf =>
      'Utilizați TLS de la începutul conexiunii, de obicei pe portul 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Utilizați propria cheie API pentru un furnizor sau conectați o cheie personalizată ';

  @override
  String get usedByEveryAccountOnThis =>
      'Folosit de fiecare cont de pe acest server care nu are cheie ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Folosit pentru a verifica dacă evenimentele Slack primite sunt autentice.';

  @override
  String get userSummary => 'Rezumatul utilizatorului';

  @override
  String get username => 'Nume de utilizator';

  @override
  String get usernameOrEmail => 'Nume de utilizator sau e-mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'utilizatori oameni caută e-mail nume utilizator insigna admin echipa gestionată';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Utilizează modelul de chat configurat în Setări';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Folosind timpul de execuție NeoAgent instalat';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'De obicei arată ca @bot:matrix.org';

  @override
  String get validEmail => 'e-mail valabil';

  @override
  String get value => 'Valoare';

  @override
  String get vaultLocked => 'Seif blocat';

  @override
  String get vaultOperationFailed => 'Operarea seifului a eșuat.';

  @override
  String get verification => 'Verificare';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verificare: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verificare: $arg1';
  }

  @override
  String get verificationCompleted => 'Verificare finalizată.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Starea de verificare: $arg1';
  }

  @override
  String get verifiedTheResult => 'Verificat rezultatul';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Verificarea timpului de rulare descărcat';

  @override
  String get versionAndUptime => 'Versiune și timp de funcționare';

  @override
  String versionArg1(Object? arg1) {
    return 'Versiunea $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Versiunea $arg1 este instalată, dar $arg2 încă rulează.';
  }

  @override
  String get videoLinks => 'Link-uri video';

  @override
  String get viewDesktop => 'Vizualizare desktop';

  @override
  String get viewLastRun => 'Vezi ultima rulare';

  @override
  String get viewLogs => 'Vizualizați jurnalele';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'memorie vm imagine cpu qemu runtime';

  @override
  String get voice => 'Vocea';

  @override
  String get voiceAssistant => 'Asistent vocal';

  @override
  String get voiceCall => 'APEL VOCAL';

  @override
  String get voiceCall2 => 'Apel vocal';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'apel vocal gpt-live gemeni live model vorbire în timp real';

  @override
  String get voiceCallsRunOnALive =>
      'Apelurile vocale rulează pe un model live de vorbire la vorbire cu aceeași persoană, memorie și istoric de chat ca NeoAgent. Răspunde imediat și predă o muncă reală agentului normal, care continuă să ruleze în fundal.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'nota vocală transcrierea vorbirii cheia api';

  @override
  String get voiceNotesAndDictation => 'Note vocale și dictare';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Redarea vocii nu este disponibilă pe acest dispozitiv.';

  @override
  String get voiceReplyModel => 'Model de răspuns vocal';

  @override
  String get waitingForApproval => 'În așteptarea aprobării: ';

  @override
  String get waitingForCode => 'Se așteaptă codul';

  @override
  String get waitingForInput => 'Se așteaptă intrarea';

  @override
  String get waitingForServerOrFlutterLog =>
      'Se așteaptă rezultatul serverului sau al jurnalului Flutter...';

  @override
  String get waitingForTaskEvents => 'Se așteaptă evenimente de sarcină...';

  @override
  String get waitingForYou => 'te asteapta';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Am vrut un răspuns de la $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Vrea să vorbească cu dvs. · ${arg1}s';
  }

  @override
  String get weak => 'Slab';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Vremea, calendarul și prioritățile înainte de începerea zilei.';

  @override
  String get weatherEvent => 'Eveniment meteo';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'browser web';

  @override
  String get webSearchApiKey => 'cheia API de căutare web';

  @override
  String get webhookOrRestChannelPosting => 'Postare webhook sau canal REST';

  @override
  String get webhookSecret => 'Webhook secret';

  @override
  String get webhookUrlCopied => 'Adresa URL a webhook a fost copiată';

  @override
  String get weekdays => 'Zilele lucrătoare';

  @override
  String get weekdays0730 => 'În zilele lucrătoare · 07:30';

  @override
  String get weekdays1800 => 'În zilele lucrătoare · 18:00';

  @override
  String get weekly => 'Săptămânal';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Limită săptămânală $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Limită săptămânală (jetoane)';

  @override
  String get weeklyReview => 'Revizuire săptămânală';

  @override
  String get weeklyUsage => 'Utilizare săptămânală';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Greutate $arg1 înregistrări';
  }

  @override
  String get welcomeToNeoagent => 'Bine ați venit la NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Bun venit\nla NeoAgent';

  @override
  String get whatAreYouAdding => 'Ce mai adaugi?';

  @override
  String get whatIsOnTomorrow => 'Ce se întâmplă mâine?';

  @override
  String get whatShouldNeoagentLearn => 'Ce ar trebui să învețe NeoAgent?';

  @override
  String get whatShouldWeBuild => 'Ce ar trebui să construim?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Ceea ce spuneți dvs. și NeoAgent apare aici și în chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Mesaj personal WhatsApp primit';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Când alegeți numai aprobat, adăugați mai jos persoane sau grupuri.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Unde acest agent ar trebui să trimită răspunsuri.';

  @override
  String get whoCanMessage => 'Cine poate trimite mesaje';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Cine poate trimite mesaje pe $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Cine poate trimite lui $arg1 un mesaj unu-la-unu.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Cine poate vorbi cu $arg1 într-un grup, canal sau cameră.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'cine gestionează acest cont a dezactivat: ';

  @override
  String get whoManagesWhom => 'Cine administrează pe cine';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Cine acceptă un link se alătură echipei tale doar cu instrumentele pe care le are ';

  @override
  String get wholeGroup => 'Întregul grup';

  @override
  String get wholeGroups => 'Grupuri întregi';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'De ce $arg1 a răspuns sau a rămas tăcut în grupurile $arg2.';
  }

  @override
  String get windowsApp => 'aplicația Windows';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Cont de serviciu';

  @override
  String get workOnAProjectWithNeoagent => 'Lucrați la un proiect cu NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Flux de lucru: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Lucrul în $arg1 pe computerul cloud. NeoAgent citește și editează fișierele acolo și poate rula comenzi și un browser.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Lucrează în fundal: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Configurarea spațiului de lucru și securitatea contului într-un singur loc.';

  @override
  String get workspaceFiles => 'Fișierele spațiului de lucru';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Spațiu de lucru, modele și comenzi de diagnosticare.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Suprascrierea spațiului de lucru trebuie să fie o cale absolută.';

  @override
  String wroteArg1(Object? arg1) {
    return 'A scris $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'eroare xmlhttprequest';

  @override
  String get yesterday => 'Ieri';

  @override
  String get youAreInControl => 'Ești în control';

  @override
  String get youCanFollowAlongOnThe => 'Puteți urmări pe desktop.';

  @override
  String get youCanLeaveATeamAt =>
      'Puteți părăsi o echipă în orice moment; propriile setări se aplică din nou.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Puteți pleca oricând de pe pagina Echipa.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Tu decizi ce instrumente poate folosi agentul tău, în Setări › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Încă nu gestionați pe nimeni. Creați un link de invitație mai jos și ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Aveți setări nesalvate. Ce ai vrea sa faci?';

  @override
  String get youReOnYourOwnYou =>
      'Ești singur: tu decizi ce instrumente poate folosi agentul tău. Dacă ';

  @override
  String get yourAccountAndUsageOnA =>
      'contul dvs. -- și utilizarea pe un model susținut de propria dvs. cheie ';

  @override
  String get yourAccountHasBeenDeleted => 'Contul dvs. a fost șters.';

  @override
  String get yourAgentWillBeAllowed =>
      'Agentului dumneavoastră i se va permite:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Aplicațiile și fișierele dvs. sunt salvate.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Aplicațiile și fișierele dvs. rămân salvate.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Cheia dvs. $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Stratul de asistent pentru captură, context și acțiune.';

  @override
  String get yourComputerIsAsleep => 'Computerul dvs. este adormit';

  @override
  String get yourComputerIsOff => 'Computerul dvs. este oprit';

  @override
  String get yourComputerIsReady => 'Computerul dvs. este gata';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Parola dvs. actuală este incorectă.';

  @override
  String get yourData => 'Datele dvs';

  @override
  String get yourDataExportWasCopiedTo =>
      'Exportul dvs. de date a fost copiat în clipboard.';

  @override
  String get yourDesktopIsReady => 'Desktopul dvs. este gata';

  @override
  String get yourLinuxComputer => 'Computerul dvs. Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Locația dvs. nu este niciodată urmărită în mod continuu sau stocată pe serverele noastre. Îl folosim doar local pentru a verifica sarcinile dvs. active.';

  @override
  String get yourManager => 'managerul tău';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Adresa URL a site-ului dvs. Mattermost, dacă utilizați API-ul REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Sesiunea dvs. a expirat sau nu a fost reținută de browser. Vă rugăm să vă conectați din nou.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Sesiunea dvs. a expirat. Vă rugăm să vă conectați din nou.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Numele dvs. de utilizator sau parola sunt incorecte.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,...';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Prezentare generală';

  @override
  String get sectionDiagnostics => 'Diagnosticare';

  @override
  String get sectionVolume => 'Volumul';

  @override
  String get sectionSession => 'Sesiune';

  @override
  String get sectionDeliverable => 'Livrabil';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Runtime-ul local nu a scris încă un fișier jurnal.';

  @override
  String get thisComputer => 'Acest computer';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta instalează cel mai nou backend de prelansare. Așteptați-vă la margini aspre.';

  @override
  String get copiedFinalResponse => 'Răspunsul final a fost copiat';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Răspunsul final apare aici când rularea se termină.';

  @override
  String get waitingForTheFirstStep => 'Așteptând primul pas…';

  @override
  String get loadingPrompt => 'Se încarcă promptul...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Nu a fost înregistrat niciun răspuns final pentru această rulare.';

  @override
  String get readyToSignIn => 'Gata de conectare';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Comutați la „Implicit” sau „Întotdeauna întrebați” pentru a reactiva verificările de aprobare.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Trimiteți o actualizare a direcției sau o notă următoare pentru rularea curentă...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Fără conexiune la rețea. NeoAgent se va reconecta când dispozitivul este din nou online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'S-a aplicat cea mai recentă actualizare a direcției la rularea curentă.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Se pregătește sesiunea de voce privată...';

  @override
  String get preparingYourComputer => 'Pregătirea computerului';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent descarcă și pregătește sistemul securizat Linux. Acest lucru se întâmplă doar prima dată.';

  @override
  String get moreFreeSpaceIsNeeded => 'Este nevoie de mai mult spațiu liber';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Eliberați spațiu pe disc pe gazda NeoAgent, apoi încercați din nou. Datele existente de pe computer sunt în siguranță.';

  @override
  String get androidReady => 'Android gata';

  @override
  String get startingAndroid2 => 'Se pornește Android...';

  @override
  String get androidStopped => 'Android s-a oprit';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Prima pornire descarcă SDK-ul Android și imaginea sistemului, ceea ce poate dura câteva minute.';

  @override
  String get androidIsStopped => 'Android este oprit';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Porniți mediul Android gestionat când aveți nevoie de el.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Lăsați NeoAgent să lucreze pe acest computer';

  @override
  String get firstTimeSetupIsInProgress =>
      'Configurarea pentru prima dată este în curs.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent poate folosi accesul pe care îl permiteți.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Eliberați spațiu de stocare gazdă și încercați din nou.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Începeți când doriți ca NeoAgent să vă ajute aici.';

  @override
  String get systemPermissionMissing => 'Lipsește permisiunea de sistem';

  @override
  String get connectingThisDevice => 'Conectarea acestui dispozitiv';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Se stabilește conexiunea locală securizată.';

  @override
  String get recordingYourDemonstration => 'Înregistrarea demonstrației dvs';

  @override
  String get noErrorsInTheRecentLog => 'Nu există erori în jurnalul recent.';

  @override
  String get loadingAccounts => 'Se încarcă conturile...';

  @override
  String get neverSignedIn => 'Nu te-ai conectat niciodată';

  @override
  String get emptyUsesTheServerDefault => 'Empty folosește serverul implicit.';

  @override
  String get followTheSelectedSession => 'Urmați sesiunea selectată';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Modul plan inspectează numai. Comutați la modul Agent pentru a permite lui NeoAgent să editeze fișiere.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Este necesar să adăugați sau să schimbați adresa de e-mail a contului.';

  @override
  String get confirmNewPassword => 'Confirmați noua parolă';

  @override
  String get passwordChanged => 'Parola schimbată.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Această solicitare a fost deja folosită.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Această solicitare a expirat. Solicitați celuilalt dispozitiv să genereze un cod nou.';

  @override
  String get startQuickstart => 'Porniți Quickstart';

  @override
  String get createYourAccount => 'Creați-vă contul';

  @override
  String get showWorkAsSummaries => 'Afișați munca ca rezumate';

  @override
  String get tokensUsedByTheLatestRun => 'Jetoane utilizate de ultima rulare';

  @override
  String get listedTheWorkspaceRoot => 'A enumerat rădăcina spațiului de lucru';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Nu sunt încă disponibile integrări oficiale.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Nu au fost încă configurate servere MCP. Adăugați unul pentru a-și expune instrumentele.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Adăugați un server MCP sau instalați o abilitate pentru a începe.';

  @override
  String get setUp => 'Configurați';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Lăsați necompletat pentru a păstra valoarea stocată';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Aceasta elimină adresa pentru fiecare cont de pe acest server.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Doar vorbește. Puteți întrerupe oricând. Atingeți pentru a dezactiva sunetul.';

  @override
  String get tapAgainWhenYouAreDone => 'Atingeți din nou când ați terminat.';

  @override
  String get workingOnATaskInTheBackground => 'Lucrul la o sarcină în fundal.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Conversație vocală cu aceeași memorie, instrumente și istoric de chat ca și NeoAgent.';

  @override
  String get checkLink => 'Verificați linkul';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Agentului dvs. nu i se va permite niciunul dintre instrumentele controlate.';

  @override
  String get notYoursToChange => 'Nu ai să te schimbi';

  @override
  String get setByYou => 'Setat de tine';

  @override
  String get noTools => 'Fără unelte';

  @override
  String get untitledLink => 'Link fără titlu';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Nu mai funcționează după ce o persoană îl răscumpără.';

  @override
  String get theOperator => 'Operatorul';

  @override
  String get smartSelectorOn => 'Selector inteligent activat';

  @override
  String get startASessionToBegin => 'Începeți o sesiune pentru a începe';

  @override
  String get steerTheActiveRun => 'Dirijați alergarea activă...';

  @override
  String get describeWhatToPlan => 'Descrieți ce să planificați...';

  @override
  String get stopDictation => 'Opriți dictarea';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Mesajele conduc rularea curentă · ⌘↵ trimite · ⌘. opriți';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Numai inspectează modul plan; nimic nu se schimbă până când implementezi · ⌘↵ trimite';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agentul editează spațiul de lucru. Planificarea doar inspectează.';

  @override
  String get defaultModel => 'Model implicit';

  @override
  String get openingScanner => 'Se deschide scanerul...';

  @override
  String get theAgentCanUseThisSkill =>
      'Agentul poate folosi această abilitate.';

  @override
  String get allSelected => 'Toate Selectate';

  @override
  String get addCoreMemoryEntry => 'Adăugați o intrare de memorie de bază';

  @override
  String get channelId => 'ID canal';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Sarcinile create de AI și nespecificate folosesc valoarea implicită curentă.';

  @override
  String get waitingForRunEvents =>
      'În așteptarea evenimentelor de alergare...';

  @override
  String get hideSteps => 'Ascundeți pașii';

  @override
  String get commitTheActiveLiveCapture => 'Efectuați captura live activă';

  @override
  String get stopCaptureAndSubmit => 'Opriți captarea și trimiteți';

  @override
  String get clickTheMicToStartSpeaking =>
      'Faceți clic pe microfon pentru a începe să vorbiți';

  @override
  String get connectACustomEndpoint => 'Conectați un punct final personalizat';

  @override
  String get hostedProvider => 'furnizor găzduit.';

  @override
  String get muted => ' • dezactivat';

  @override
  String get addWhoCanMessage => 'Adăugați cine poate trimite mesaje';

  @override
  String get joinsGroupConversations => 'Se alătură conversațiilor de grup';

  @override
  String get label1PersonOrGroupAdded => '1 persoană sau grup adăugat';

  @override
  String get inProgress => 'În curs';

  @override
  String get waitingForUpdateJobOutput =>
      'Se așteaptă actualizarea rezultatelor lucrării...';

  @override
  String get taskTrigger => 'Declanșator de sarcină';

  @override
  String get bearerToken => 'Jeton de purtător';

  @override
  String get bearerToken2 => 'Jeton de purtător';

  @override
  String get notRecorded => 'Neînregistrat';

  @override
  String get sessionCookie => 'Cookie de sesiune';

  @override
  String get neverUsed => 'Nu a fost folosit niciodată';

  @override
  String get linkedRecently => 'Conectat recent';

  @override
  String get notUsedYet => 'Nu este folosit încă';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Unul sau mai multe conturi au expirat. Reconectați-vă pentru a restabili accesul. Dacă acest lucru continuă să se întâmple, aplicația dvs. Google Cloud OAuth poate fi în modul Testare - publicați-o în Production în Google Cloud Console pentru a obține token-uri de lungă durată.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Seif conectat și disponibil după repornire';

  @override
  String get vaultConnectedForThisSession =>
      'Seif conectat pentru această sesiune';

  @override
  String get connectAnotherAccount => 'Conectați un alt cont';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Lipiți token de acces cu viață lungă de înlocuire';

  @override
  String get updateInstance => 'Actualizați Instanța';

  @override
  String get pasteAReplacementToken => 'Lipiți un jeton de înlocuire';

  @override
  String get replaceAccount => 'Înlocuiește contul';

  @override
  String get addAccount => 'Adăugați un cont';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Poate delega oricărui agent primitor';

  @override
  String get canReceiveDelegatedTasks2 => 'pot primi sarcini delegate';

  @override
  String get noSyncYet => 'Nicio sincronizare încă';

  @override
  String get noNewData => 'Nu există date noi';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sincronizați o dată pentru a vă genera backend-ul.';

  @override
  String get lastWindowEndIsUnknown =>
      'Sfârșitul ultimei ferestre este necunoscut.';

  @override
  String get lastNonEmptySync => 'Ultima sincronizare non-vide';

  @override
  String get stopTranscribe => 'Opriți și transcrieți';

  @override
  String get steeringMode => 'Modul de direcție';

  @override
  String get noMessageText => 'Niciun mesaj text';

  @override
  String get reconnectingToServer => 'Se reconecta la server...';

  @override
  String get signingIn => 'Conectare...';

  @override
  String get noGroupsFoundYet => 'Nu au fost găsite grupuri încă';

  @override
  String get onForNewGroupsOnly => 'Activat numai pentru grupuri noi';

  @override
  String get noGroupsInThisCategory => 'Nu există grupuri în această categorie';

  @override
  String get groupOrChannel => 'Grup sau canal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Notele pe care ți le scrii încep o alergare, iar răspunsurile ajung în același chat. Lista permisă nu se aplică aici.';

  @override
  String get needToReply => 'Trebuie să răspund';

  @override
  String get enter2faCode => 'Introdu codul 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Deschideți aplicația de autentificare și introduceți codul actual NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Aveți deja un cont? Conectați-vă';

  @override
  String get serverOnThisComputer => 'Server pe acest computer';

  @override
  String get showQrCode => 'Afișați codul QR';

  @override
  String get createAnotherNeoagentAccount => 'Creați un alt cont NeoAgent.';

  @override
  String get canCoordinateDelegatedWork => 'Poate coordona munca delegată';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Arhiva de rulare NeoAgent nu a putut fi extrasă.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Arhiva de rulare NeoAgent nu a putut fi citită.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Arhiva de rulare NeoAgent conține o cale nesigură.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Arhiva de rulare NeoAgent conține o legătură nesigură.';

  @override
  String get installingAppPackageOnThePhone =>
      'Se instalează pachetul de aplicații pe telefon...';

  @override
  String get dragAndDropAApkOrApks =>
      'Trageți și plasați un fișier .apk sau .apks aici sau faceți clic pentru a răsfoi.';

  @override
  String get releaseToInstallThisPackage =>
      'Eliberați pentru a instala acest pachet';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Cheia de securitate nu a putut fi folosită.';

  @override
  String get connecting => 'Se conectează…';

  @override
  String get changes => 'Schimbări';

  @override
  String get runtimeReady => 'Timp de rulare gata';

  @override
  String get saving => 'Se salvează...';

  @override
  String get earlier => 'Mai devreme';

  @override
  String get monthJan => 'ian';

  @override
  String get monthFeb => 'feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'apr';

  @override
  String get monthMay => 'mai';

  @override
  String get monthJun => 'Iun';

  @override
  String get monthJul => 'iul';

  @override
  String get monthAug => 'aug';

  @override
  String get monthSep => 'sept';

  @override
  String get monthOct => 'oct';

  @override
  String get monthNov => 'nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get steeringWord => 'Direcție';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Aceasta comută backend-ul de la canalul $arg1 la canalul $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1 cookie-uri importate';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '$arg1 acum';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Direcție în coadă: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Aplicația web nu a putut ajunge la backend-ul NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Browserul a blocat o solicitare necesară din cauza Politicii de securitate a conținutului.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 din 4 permise';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Efectuați sarcina așa cum ați proceda în mod normal.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Modificări · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Acest dispozitiv · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limita atinsă$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Codurile de recuperare $arg1 sunt încă disponibile.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Cheie de securitate $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Sesiunea curentă';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nUltima utilizare: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Se lucrează în $arg1 pe acest dispozitiv. NeoAgent citește și editează folderul direct și poate rula comenzi, deschide aplicații și poate folosi ecranul.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'A lucrat pentru $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Permis de $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Linkurile de invitație $arg1 de la $arg2 au fost revocate';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Adăugați persoanele și grupurile cu care ar trebui să vorbească $arg1';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Adăugați persoanele și grupurile cu care $arg1 are voie să vorbească.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Unde ascultă $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 urmărește aceste locuri pentru mențiuni. Oricine poate posta aici, așa că oamenii au nevoie de aprobarea lor mai jos.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Acești oameni îl pot întreba pe $arg1 oriunde îl etichetă. Rolurile contează numai în locurile enumerate mai sus.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Numai când $arg1 este etichetat';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Activat pentru toate grupurile $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 încă aude doar persoanele și grupurile pe care le-ați aprobat deja. Acest lucru îi permite doar lui $arg1 să se alăture chatului obișnuit acolo, nu numai etichetelor și răspunsurilor.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 încă aude doar persoanele și grupurile pe care le-ați aprobat deja. Aceasta alege doar la care dintre acele grupuri ar trebui să se alăture.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Dacă cineva etichetează $arg1 sau răspunde, $arg1 răspunde întotdeauna. Activați această opțiune dacă $arg1 ar trebui să intervină și în chatul obișnuit de grup.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Noile grupuri îi vor permite pe $arg1 să se alăture chatului obișnuit cu persoane aprobate, până când le dezactivați.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Noile grupuri îi vor permite pe $arg1 să se alăture chatului obișnuit până când le dezactivați.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Noile grupuri rămân liniștite cu excepția cazului în care o persoană aprobată etichetează $arg1, până când le activați.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Doar atunci când o persoană aprobată etichetează $arg1, cu excepția cazului în care activați un grup';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Numai când $arg1 este etichetat, cu excepția cazului în care activați un grup';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 din grupurile $arg2 se alătură chatului obișnuit cu persoane aprobate';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Acest lucru nu aprobă oameni noi. Etichetele și răspunsurile de la persoanele aprobate primesc întotdeauna un răspuns. Activați un grup dacă și $arg1 ar trebui să se alăture chatului obișnuit acolo.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Acest lucru nu aprobă oameni noi. Activați un grup dacă $arg1 ar trebui să se alăture chatului obișnuit cu persoane pe care le-ați aprobat deja.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Etichetele și răspunsurile primesc întotdeauna un răspuns. Activați un grup dacă și $arg1 ar trebui să se alăture chatului obișnuit acolo.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 se alătură chatului obișnuit cu persoane aprobate';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 se poate alătura chatului obișnuit';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 răspunde numai atunci când o persoană aprobată îl etichetează';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nu este nevoie de nimic suplimentar. Conectați-vă pentru a începe să utilizați $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Actualizează în $arg1-uri';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Înregistrați-vă cu $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Nicio memorie legată de „$arg1”.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (implicit)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filiala: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 se alătură numai grupurilor și canalelor pe care le adăugați mai jos.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 este necesar pentru a localiza datele de rulare NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[previzualizare trunchiată, $arg1 octeți în total]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefactul delimitat, $arg1 octeți în total]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' în $arg1';
  }

  @override
  String get worldNews => 'Știri Mondiale';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Rulați când apar titluri despre lume. Solicitarea dvs. decide dacă vă anunță.';

  @override
  String get newsKeywordsOptional => 'Cuvinte cheie (opțional)';

  @override
  String get worldNewsSetup => 'Configurare World News';

  @override
  String get connectWorldNewsWithGnews =>
      'Adăugați o cheie API GNews (plan gratuit disponibil la gnews.io). Este stocat criptat și folosit pentru a sonda titlurile de top pentru declanșatoarele de Știri Mondiale.';

  @override
  String get gnewsApiKey => 'Cheia API GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Inserați cheia API GNews de înlocuire';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Lăsați cheia goală pentru a păstra cheia stocată în prezent.';

  @override
  String get gnewsApiKeyIsRequired => 'Este necesară o cheie API GNews.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nu s-a putut salva configurarea World News.';

  @override
  String get disconnectWorldNews => 'Deconectați Știrile Mondiale';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Aceasta elimină cheia API GNews stocată. Declanșatoarele World News se vor opri până când adăugați din nou o cheie.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Nu s-a putut deconecta World News.';

  @override
  String get systemOneModels => 'Modele SystemOne';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Alege cel mai bun model SystemOne disponibil';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Modelul de chat ia aceste decizii';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modele de decizie care efectuează apeluri din culise într-o fracțiune de secundă: turnarea în chat de grup și pașii din browser. Modelul dvs. de chat scrie în continuare fiecare răspuns.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Modelul SystemOne decide când să vorbească în timp ce este pornit; acest model este alternativa.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 marcat de SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne a marcat direct acest mesaj. Nu a rulat niciun model de limbă.';

  @override
  String get systemOneUnavailable => 'SystemOne indisponibil';

  @override
  String get systemOneAdminAvailability =>
      'Agenții de modele de decizie pot alege din Setări › Modele. Un model dezactivat aici părăsește acel selector, iar agenții care l-au ales revin la Auto. În timp ce orice model este dezactivat, modelele SystemOne pe care furnizorii le adaugă mai târziu încep și ele oprite.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Nu există încă modele SystemOne. Adăugați o cheie TypeSafe sau OpenRouter la Furnizori sau trageți un model de decizie, cum ar fi nimble în Ollama 0.35 sau o versiune ulterioară.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Niciun model SystemOne nu este disponibil încă. Adăugați o cheie TypeSafe sau OpenRouter în Setări › Modele › Aduceți propria cheie sau trageți un model de decizie, cum ar fi nimble în Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistem o decizie modele jev typesafe openrouter ollama disponibilitate activare dezactivare';

  @override
  String get chatModels => 'Modele de chat';

  @override
  String get disabled => 'Dezactivat';

  @override
  String get enableShown => 'Activați afișat';

  @override
  String get disableShown => 'Dezactivați afișat';

  @override
  String get expandAll => 'Extindeți-le pe toate';

  @override
  String get collapseAll => 'Restrângeți totul';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 modificări nesalvate';
  }

  @override
  String get settingsScopeAllAgents => 'Toți agenții';

  @override
  String get settingsScopeAgent => 'Acest agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'Același oriunde vă conectați';

  @override
  String get settingsScopeAllAgentsHint => 'Partajat de toți agenții dvs';

  @override
  String get settingsAppliesTo => 'Se aplică la';

  @override
  String get settingsSaving => 'Se salvează…';

  @override
  String get settingsSavedAutomatically => 'Modificările se salvează automat';

  @override
  String get settingsSearchHint => 'Căutați toate setările';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Conectare și securitate';

  @override
  String get settingsPageUsage => 'Utilizare';

  @override
  String get settingsPagePermissions => 'Permisiuni';

  @override
  String get settingsPageComputer => 'Computer și web';

  @override
  String get settingsPageBehavior => 'Comportament';

  @override
  String get settingsPageSystem => 'Sistem';

  @override
  String get settingsPagePlatforms => 'Platforme';

  @override
  String get settingsPageProfileDescription =>
      'Numele și adresa dvs. de e-mail, o copie a datelor dvs. și deconectarea.';

  @override
  String get settingsPageSecurityDescription =>
      'Parola, autentificarea cu doi factori, cheile de securitate și locul în care sunteți conectat.';

  @override
  String get settingsPageUsageDescription =>
      'Limitele și cheltuielile tale simbol, toate într-un singur loc.';

  @override
  String get settingsPageAgentsDescription =>
      'Creați agenți și alegeți care răspunde implicit.';

  @override
  String get settingsPagePermissionsDescription =>
      'Ce pot face agenții tăi fără să te întrebe mai întâi.';

  @override
  String get settingsPageComputerDescription =>
      'Computerul pe care lucrează agenții tăi și site-urile pe care le pot citi ca tine.';

  @override
  String get settingsPageModelsDescription =>
      'Ce modele folosește acest agent și cheile API care plătesc pentru ele.';

  @override
  String get settingsPageBehaviorDescription =>
      'Cum vorbește acest agent și cum citește un chat de grup.';

  @override
  String get settingsPageVoiceDescription =>
      'Apeluri live, dictare și răspunsuri vocale pentru acest agent.';

  @override
  String get settingsPageMessagingDescription =>
      'Unde pot ajunge oamenii la acest agent și cum se comportă acesta în chat.';

  @override
  String get settingsPageGeneralDescription =>
      'Aspect, limba, fusul orar și ceea ce face această aplicație în fundal.';

  @override
  String get settingsPageSystemDescription =>
      'Serverul pe care îl folosește această fereastră, cel de pe acest computer și actualizările aplicației.';

  @override
  String get settingsYourAgents => 'Agenții tăi';

  @override
  String get settingsChatModel => 'Model de chat';

  @override
  String get settingsChatModelDescription => 'Răspunde la mesajele dvs.';

  @override
  String get settingsSubAgentModel => 'Model de sub-agent';

  @override
  String get settingsSubAgentModelDescription =>
      'Execută munca predată în timpul unei sarcini.';

  @override
  String get settingsDefaultModels => 'Modele implicite';

  @override
  String get settingsDefaultModelsDescription =>
      'Folosit ori de câte ori un chat sau o sarcină nu își alege propriul model.';

  @override
  String get settingsModelPool => 'Model piscina';

  @override
  String get settingsApiKeysDescription =>
      'Utilizați propriile chei sau punctul final pentru acest agent. Cheile sunt criptate și nu se mai afișează niciodată.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Reglaj fin';

  @override
  String get settingsFineTuningDescription =>
      'Rar necesar. Valorile implicite se potrivesc majorității chat-urilor.';

  @override
  String get settingsShow => 'Arată';

  @override
  String get settingsHide => 'Ascunde';

  @override
  String get settingsMinimumContribution => 'Valoarea minimă a contribuției';

  @override
  String get settingsBatchWindow => 'Fereastra lotului camerei';

  @override
  String get settingsBatchWindowDescription =>
      'Așteaptă atât de mult pentru a trata mesajele rapide ca pe o singură rânduială.';

  @override
  String get settingsHandsFree => 'Mâini libere';

  @override
  String get settingsHandsFreeDescription =>
      'Vorbiți liber și întrerupeți oricând.';

  @override
  String get settingsPushToTalkDescription =>
      'Țineți pentru a vorbi, eliberați pentru a trimite.';

  @override
  String get settingsLiveVoice => 'Voce live';

  @override
  String get settingsChannels => 'Canale';

  @override
  String get settingsGroupChats => 'În conversațiile de grup';

  @override
  String get settingsGroupChatsDescription =>
      'Cum se comportă acest agent în grupuri pe fiecare canal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Activați modulele de comportament în Comportament pentru a le modifica.';

  @override
  String get settingsParticipationAutomatic => 'automată';

  @override
  String get settingsParticipationMentionOnly => 'Numai menționați';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Citește camera și se alătură atunci când are ceva util de adăugat.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Răspunde numai atunci când este menționat sau la care se răspunde.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Răspunsuri la fiecare mesaj.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Împarte răspunsurile mai lungi în mesaje scurte, așa cum ar face o persoană.';

  @override
  String get settingsDeliverySingleDescription =>
      'Trimite fiecare răspuns ca un singur mesaj.';

  @override
  String get settingsComputerStatus => 'Stare';

  @override
  String get settingsTest => 'Testează';

  @override
  String get settingsAppearance => 'Aspectul';

  @override
  String get settingsTheme => 'Temă';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsThemeLight => 'Luminoasă';

  @override
  String get settingsThemeDark => 'Întunecată';

  @override
  String get settingsCloseWindow => 'Când închizi fereastra';

  @override
  String get settingsCloseAsk => 'Întreabă';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent continuă să ruleze în fundal și rămâne accesibil.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent se închide complet.';

  @override
  String get settingsPhoneTriggers => 'Declanșează telefonul';

  @override
  String get settingsPhoneTriggersDescription =>
      'Semnale pe care acest telefon le trimite agenților dvs., astfel încât sarcinile să poată reacționa la ele.';

  @override
  String get settingsLocationTriggers => 'Declanșează locația';

  @override
  String get settingsLocationTriggersDescription =>
      'Verifică locația dvs. aproximativă la fiecare câteva minute față de locurile vizionate de sarcinile dvs.';

  @override
  String get settingsNotificationTriggers => 'Declanșatoare de notificare';

  @override
  String get settingsNotificationTriggersDescription =>
      'Redirecționează notificările de la alte aplicații de pe acest telefon către agenții dvs.';

  @override
  String get settingsSetup => 'Configurare';

  @override
  String get settingsOnboarding => 'Onboarding';

  @override
  String get settingsOnboardingDescription =>
      'Parcurgeți din nou configurarea la prima rulare. Nimic din ce ai configurat nu se pierde.';

  @override
  String get settingsUsernameDescription =>
      'Folosit pentru a vă conecta. Nu poate fi schimbat.';

  @override
  String get settingsExport => 'Exportați';

  @override
  String get settingsLeave => 'Deconectați-vă și ștergeți';

  @override
  String get settingsSignOutDescription =>
      'Te deconectează numai pe acest dispozitiv.';

  @override
  String get settingsDeleteAccountDescription =>
      'Vă șterge contul, agenții, memoria și setările. Acest lucru nu poate fi anulat.';

  @override
  String get settingsTokenUsage => 'Utilizarea jetoanelor';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Nicio setare nu se potrivește cu „$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de rezultate',
      few: '$count rezultate',
      one: '$count rezultat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Setări avansate ale modelului';

  @override
  String get settingsAdvancedModelsDescription =>
      'Opțional. Fixați un model pe un fel de lucrare; preia de fiecare dată când agentul folosește acele instrumente. Orice a rămas implicit urmează modelul de chat.';

  @override
  String get settingsTaskModelDefault => 'Implicit';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Urmează modelul de chat';

  @override
  String get settingsTaskModelCoding => 'Codificare';

  @override
  String get settingsTaskModelCodingDescription =>
      'Scrierea, editarea și depanarea codului.';

  @override
  String get settingsTaskModelComputerUse => 'Utilizarea calculatorului';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Conducerea browserului și a desktopului.';

  @override
  String get settingsTaskModelAndroidUse => 'Utilizarea Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Operarea aplicațiilor pe un dispozitiv sau emulator Android.';

  @override
  String get settingsTaskModelResearch => 'Cercetare';

  @override
  String get settingsTaskModelResearchDescription =>
      'Căutarea, citirea și rezumarea surselor.';

  @override
  String get knowledgeGraphHint =>
      'Cele mai menționate entități ale tale, colorate după cluster. Liniile conectează entități care apar în aceleași amintiri. Atingeți unul pentru a vedea legăturile și amintirile sale; trageți pentru a deplasa, ciupiți sau Ctrl/⌘-defilați pentru a mări.';

  @override
  String get linkedEntities => 'Entități legate';

  @override
  String get noLinkedEntities => 'Nu este încă legat de alte entități.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 mențiuni';
  }

  @override
  String get entityKindConcept => 'Concept';

  @override
  String get entityKindDomain => 'Domeniul';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'Fișier';

  @override
  String get entityKindAcronym => 'Acronim';

  @override
  String get entityKindIdentifier => 'Identificator';

  @override
  String get entityKindVersion => 'Versiune';

  @override
  String get openFullscreen => 'Deschide ecran complet';

  @override
  String get zoomIn => 'Măriți';

  @override
  String get zoomOut => 'Micșorați';

  @override
  String get searchEntities => 'Găsiți o entitate';

  @override
  String get incomingCall => 'Apel primit';

  @override
  String get answerCall => 'Raspunde';

  @override
  String get callMeLater => 'Sună-mă mai târziu';

  @override
  String get callingEllipsis => 'Apelând…';

  @override
  String get reconnectingCall => 'Reconectare';

  @override
  String get agentWorking => 'De lucru';

  @override
  String get micMuted => 'Dezactivat';

  @override
  String get speakerphone => 'Difuzor';

  @override
  String get muteMic => 'Mut';

  @override
  String get unmuteMic => 'Activați sunetul';

  @override
  String get releaseToSend => 'Eliberați pentru a trimite';

  @override
  String get callEnded => 'Apel încheiat';

  @override
  String get openConversation => 'Deschide conversația';

  @override
  String get callBack => 'Sună înapoi';

  @override
  String get letCallsReachYou => 'Lăsați apelurile să vă ajungă';

  @override
  String get callPermissionsIntro =>
      'Agenții tăi te pot suna. Pentru a suna ca un apel telefonic în timp ce NeoAgent este în fundal sau telefonul este blocat, are nevoie de acestea.';

  @override
  String get showOverOtherApps => 'Afișați peste alte aplicații';

  @override
  String get showOverOtherAppsDetail =>
      'Afișează ecranul de apel oriunde v-ați afla.';

  @override
  String get fullScreenCalls => 'Apeluri pe ecran complet';

  @override
  String get fullScreenCallsDetail => 'Sună peste ecranul de blocare.';

  @override
  String get unrestrictedBattery => 'Baterie nerestricționată';

  @override
  String get unrestrictedBatteryDetail =>
      'Menține NeoAgent conectat, astfel încât să ajungă apelurile.';

  @override
  String get permissionAllowed => 'Permis';

  @override
  String get triggerSectionCalendar => 'Calendar';

  @override
  String get triggerSectionFiles => 'Dosare și documente';

  @override
  String get triggerSectionHome => 'Acasă și mass-media';

  @override
  String get triggerSectionDevices => 'Dispozitive și locuri';

  @override
  String get triggerSectionTasks => 'Sarcini';

  @override
  String get messagingMemberJoined => 'Membru s-a alăturat';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Rulați când cineva se alătură unui server Discord, grup Telegram sau WhatsApp, canal Slack sau cameră Matrix.';

  @override
  String get messagingMemberLeft => 'Membru a plecat';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Rulați când cineva părăsește un server Discord, un grup Telegram sau WhatsApp, un canal Slack sau o cameră Matrix.';

  @override
  String get messagingReactionAdded => 'Reacția adăugată';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Rulați când o persoană autorizată reacționează la un mesaj într-un chat privat.';

  @override
  String get messagingPlatformDisconnected => 'Mesaje deconectate';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Rulați când o conexiune de mesagerie se oprește și are nevoie de dvs., cum ar fi după o deconectare.';

  @override
  String get googleCalendarEventStarting =>
      'Începe evenimentul Google Calendar';

  @override
  String get googleCalendarEventCreated =>
      'S-a creat evenimentul Google Calendar';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Rulați când apare un eveniment sau o invitație nouă.';

  @override
  String get outlookCalendarEventStarting =>
      'Începe evenimentul Outlook Calendar';

  @override
  String get nextcloudCalendarEventStarting =>
      'Începe evenimentul Nextcloud Calendar';

  @override
  String get runMinutesBeforeEachEvent =>
      'Rulați un anumit număr de minute înainte de fiecare eveniment.';

  @override
  String get googleDriveFileAdded => 'Fișierul Google Drive a fost adăugat';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Rulați când un fișier este adăugat în Drive sau într-un dosar din acesta.';

  @override
  String get googleSheetsRowAdded => 'S-a adăugat un rând Foi de calcul Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Rulați când apar rânduri noi într-o foaie.';

  @override
  String get onedriveFileAdded => 'Fișierul OneDrive a fost adăugat';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Rulați când un fișier este adăugat într-un folder OneDrive.';

  @override
  String get nextcloudFileAdded => 'Fișierul Nextcloud a fost adăugat';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Rulați când un fișier este adăugat într-un folder Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Fișier Nextcloud partajat cu dvs';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Rulați când cineva vă partajează un fișier sau un dosar.';

  @override
  String get notionItemAdded =>
      'A fost adăugat elementul bazei de date de noțiuni';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Rulați atunci când un articol este adăugat la o bază de date Notion.';

  @override
  String get notionItemUpdated =>
      'Element din baza de date de noțiuni actualizat';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Rulați când se modifică un element dintr-o bază de date Notion.';

  @override
  String get trelloCardEnteredList => 'Card Trello adăugat la listă';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Rulați când un card este creat sau mutat într-o listă.';

  @override
  String get figmaCommentAdded => 'Comentariul Figma a fost adăugat';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Rulați când cineva comentează un fișier Figma.';

  @override
  String get githubPrOpened =>
      'Solicitarea de extragere GitHub a fost deschisă';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Rulați când o nouă cerere de extragere este deschisă într-un depozit.';

  @override
  String get githubWorkflowRunFailed =>
      'Executarea fluxului de lucru GitHub a eșuat';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Rulați când o rulare GitHub Actions eșuează.';

  @override
  String get githubCommitPushed => 'Comitarea GitHub a fost împinsă';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Rulați când noi comiteri ajung la o ramură.';

  @override
  String get mcpServerFailed => 'Serverul MCP a eșuat';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Rulați când un server MCP care funcționa eșuează sau necesită conectare.';

  @override
  String get homeAssistantStateChanged =>
      'Starea Asistentului de acasă s-a schimbat';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Rulați atunci când o entitate se schimbă, ajunge la o stare sau depășește o valoare.';

  @override
  String get spotifyTrackChanged => 'S-a schimbat melodia Spotify';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Rulați când începe redarea unei piese diferite.';

  @override
  String get neorecallDailySummaryReady =>
      'Rezumatul zilnic NeoRecall este gata';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Rulați când rezumatul unei zile este final.';

  @override
  String get neorecallConversationRecorded =>
      'Conversația NeoRecall a fost înregistrată';

  @override
  String get runWhenARecordedConversationEnds =>
      'Rulați când se termină o conversație înregistrată.';

  @override
  String get geofenceTrigger => 'Geogard de locație';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Rulați când telefonul ajunge sau părăsește un loc. Necesita urmărirea locației pe telefon.';

  @override
  String get healthMetricRecorded => 'Valoarea sănătății a fost înregistrată';

  @override
  String get runWhenAHealthReadingArrives =>
      'Rulați când sosește o citire de sănătate sincronizată, opțional deasupra sau sub o valoare.';

  @override
  String get wearableConnectionChanged => 'purtabil conectat sau deconectat';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Alergați atunci când purtatorul dvs. se conectează sau se deconectează.';

  @override
  String get taskRunFinished => 'O altă sarcină terminată';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Rulați după ce o altă sarcină se termină, reușește sau eșuează.';

  @override
  String get appPackageOptional => 'Pachetul aplicației (opțional)';

  @override
  String get appPackageHelper => 'De exemplu com.whatsapp';

  @override
  String get anyPlatform => 'Orice platformă';

  @override
  String get spaceIdOptional => 'ID server, grup, canal sau cameră (opțional)';

  @override
  String get spaceIdHelper =>
      'Ceasuri goale pentru fiecare în care se află botul.';

  @override
  String get emojiOptional => 'Emoji (opțional)';

  @override
  String get chatIdOptional => 'ID de chat (opțional)';

  @override
  String get platformOptional => 'Platformă (opțional)';

  @override
  String get platformOptionalHelper =>
      'De exemplu whatsapp. Ceasuri goale toate.';

  @override
  String get minutesBefore => 'Cu minute înainte';

  @override
  String get calendarIdOptional => 'ID calendar (opțional)';

  @override
  String get calendarIdHelper => 'Empty folosește calendarul dvs. principal.';

  @override
  String get invitesOnly => 'Doar invitații de la alții';

  @override
  String get nextcloudCalendarPath => 'Calendar';

  @override
  String get nextcloudCalendarPathHelper =>
      'Numele său în lista de calendare Nextcloud, de exemplu personal';

  @override
  String get folderIdOptionalHelperDrive => 'Ceasuri goale tot Drive.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Empty urmărește folderul rădăcină.';

  @override
  String get driveFolderIdOptional => 'ID dosar (opțional)';

  @override
  String get spreadsheetId => 'ID-ul foii de calcul';

  @override
  String get sheetRange => 'Gama';

  @override
  String get sheetRangeHelper => 'Coloanele tabelului, de exemplu Sheet1!A:E';

  @override
  String get folderPathOptional => 'Calea dosarului (opțional)';

  @override
  String get folderPathHelper => 'De exemplu Documente';

  @override
  String get notionDatabaseId => 'ID-ul bazei de date';

  @override
  String get trelloListId => 'ID-ul listei';

  @override
  String get figmaFileKey => 'Tasta de fișier';

  @override
  String get figmaFileKeyHelper =>
      'Din linkul fișierului: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Depozitul';

  @override
  String get workflowOptional => 'Flux de lucru (opțional)';

  @override
  String get workflowHelper => 'Numele fișierului, cum ar fi ci.yml';

  @override
  String get branchOptional => 'Filiala (optional)';

  @override
  String get branchHelper => 'Empty folosește ramura implicită.';

  @override
  String get mcpServerIdOptional => 'ID server MCP (opțional)';

  @override
  String get entityId => 'ID entitate';

  @override
  String get entityIdHelper => 'De exemplu binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Stare țintă (opțional)';

  @override
  String get targetStateHelper => 'De exemplu pe';

  @override
  String get aboveOptional => 'Mai sus (opțional)';

  @override
  String get belowOptional => 'Mai jos (opțional)';

  @override
  String get placeName => 'Numele locului';

  @override
  String get latitude => 'Latitudine';

  @override
  String get longitude => 'Longitudine';

  @override
  String get radiusMeters => 'Raza în metri';

  @override
  String get geofenceTransition => 'Când';

  @override
  String get arriving => 'Sosind';

  @override
  String get leaving => 'Plecând';

  @override
  String get healthMetric => 'Valoarea sănătății';

  @override
  String get healthMetricHelper =>
      'De exemplu, ritmul cardiac, pașii, greutatea';

  @override
  String get wearableTransition => 'Când purtabilul';

  @override
  String get wearableConnects => 'Se conectează';

  @override
  String get wearableDisconnects => 'Se deconectează';

  @override
  String get sourceTask => 'După sarcină';

  @override
  String get taskOutcome => 'Rezultatul';

  @override
  String get anyOutcome => 'Orice rezultat';

  @override
  String get succeeded => 'Reușit';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 lipsește sau nu este valid.';
  }

  @override
  String get triggerSectionMessaging => 'Mesaje';

  @override
  String get triggerSectionDeveloper => 'Dezvoltator';

  @override
  String get triggerSectionMemory => 'Memorie';

  @override
  String get triggerSectionNews => 'Știri';

  @override
  String get triggerSectionSystem => 'Sistem';

  @override
  String get searchTriggersHint =>
      'Căutați declanșatoare, aplicații sau evenimente';

  @override
  String get noTriggersMatch =>
      'Niciun declanșator nu corespunde căutării dvs.';

  @override
  String get triggerAccountMissing => 'Niciun cont încă';

  @override
  String get pickTriggerKeyboardHint => 'Enter alege primul rezultat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 declanșează';
  }

  @override
  String get addFromSkillsSh => 'Adăugați de la skills.sh';

  @override
  String get skillsShHint =>
      'Căutați mai sus pentru a găsi competențe pe skills.sh sau inserați un link skills.sh sau o comandă „npx skills add”.';

  @override
  String get noSkillsShMatches =>
      'Nicio abilitate skills.sh nu corespunde acestei căutări.';

  @override
  String get installingSkill => 'Se instalează…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Instalat $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 se instalează';
  }

  @override
  String get authVerify => 'Verificați';

  @override
  String get authCreateAccount => 'Creați cont';

  @override
  String get authNewInviteLink => 'Link nou de invitație';

  @override
  String get authShowPassword => 'Afișați parola';

  @override
  String get authHidePassword => 'Ascunde parola';

  @override
  String get authPasswordWillBeRejected => 'prea slab, va fi respins';

  @override
  String get authUsernameTooShort =>
      'Numele de utilizator au nevoie de cel puțin 3 caractere.';

  @override
  String get authUsernameTaken => 'Acel nume de utilizator este deja luat.';

  @override
  String get authSignupsClosed =>
      'Înscrierile sunt închise pe acest server. Cereți-i administratorului un cont.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Acest server acceptă doar conectări prin HTTPS. În schimb, deschideți $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Acest server acceptă doar conectări prin HTTPS. Conectați-vă la acesta cu o adresă https://.';

  @override
  String get authAccountNotFound => 'Acel cont nu mai exista.';

  @override
  String get authQrRateLimited =>
      'Prea multe solicitări de conectare QR. Așteptați un moment, apoi reîmprospătați codul.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Ați uitat parola? Solicitați administratorului serverului să îl resetați în Administrator → Utilizatori.';

  @override
  String get authChangeServer => 'Schimbați serverul';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Conectarea la $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Această adresă nu răspunde ca un server NeoAgent. Verificați adresa URL și încercați din nou.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nu s-a putut deschide o conexiune securizată (HTTPS) la $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nu s-a putut ajunge la $arg1 prin HTTPS și nici HTTP simplu nu a răspuns. Verificați adresa și portul.';
  }

  @override
  String get adminResetPassword => 'Resetează parola';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Resetați parola pentru $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Alegeți o nouă parolă pentru $arg1. Se vor deconecta de pe fiecare dispozitiv și se vor conecta din nou cu această parolă.';
  }

  @override
  String get adminNewPassword => 'Parolă nouă';

  @override
  String get adminSetPassword => 'Setați parola';

  @override
  String get authMissingFields => 'Completați fiecare câmp obligatoriu.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 resetează parola lui $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Parola actualizată; utilizatorul a fost deconectat peste tot.';

  @override
  String get authSignInTitle => 'Conectați-vă la NeoAgent';

  @override
  String get authSignInSubtitle => 'Scanați cu telefonul sau folosiți parola.';

  @override
  String get authOrUsePassword => 'sau folosește-ți parola';

  @override
  String get qrLoginWaitingTitle => 'Aprobați pe telefonul dvs';

  @override
  String get qrLoginWaitingBody =>
      'Telefonul dvs. a scanat codul. Confirmați autentificarea acolo pentru a finaliza conectarea.';

  @override
  String get qrLoginSigningInOn => 'Conectare';

  @override
  String get qrLoginLocation => 'Locație';

  @override
  String get qrLoginWaitingForApproval => 'În așteptarea aprobării';

  @override
  String get qrLoginCancelAndUsePassword => 'Anulați și utilizați o parolă';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Conectarea a fost refuzată pe telefonul dvs. Scanați noul cod pentru a încerca din nou.';

  @override
  String get signupKey => 'Cheie de înregistrare';

  @override
  String get signupKeyStepSubtitle =>
      'Conturile noi de pe acest server necesită o cheie de înregistrare. Introduceți cheia primită de la un administrator.';

  @override
  String get signupKeyChange => 'Schimbați';

  @override
  String get signupKeyRequiredError => 'Introduceți cheia de înregistrare.';

  @override
  String get signupKeyInvalidError =>
      'Această cheie de înregistrare nu este validă. Verificați-o și încercați din nou.';

  @override
  String get signupKeyUsedError =>
      'Această cheie de înregistrare a fost deja folosită. Cereți una nouă unui administrator.';

  @override
  String get adminRequireSignupKey => 'Solicită o cheie de înregistrare';

  @override
  String get adminRequireSignupKeyHint =>
      'Conturile noi necesită o cheie de unică folosință de la un administrator. Când este dezactivat, oricine poate accesa acest server se poate înregistra. Primul cont nu are niciodată nevoie de cheie.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Conturile noi necesită acum o cheie de înregistrare.';

  @override
  String get adminSignupOpenNotice => 'Acum oricine se poate înregistra.';

  @override
  String get signupKeys => 'Chei de înregistrare';

  @override
  String get signupKeysDescription =>
      'Chei de unică folosință pentru înregistrare cât timp este necesară o cheie. Fiecare cheie creează exact un cont.';

  @override
  String get signupKeysNew => 'Chei noi';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Nefolosite · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Folosite · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Revocate · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Toate · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Nefolosită';

  @override
  String get signupKeyStatusUsed => 'Folosită';

  @override
  String get signupKeyStatusRevoked => 'Revocată';

  @override
  String get signupKeysExport => 'Exportați .txt';

  @override
  String get signupKeysCopied => 'Chei copiate';

  @override
  String get signupKeyCopied => 'Cheie copiată';

  @override
  String get signupKeysEmpty => 'Nu există chei în această listă.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Creată pe $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Folosită de $arg1 pe $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Folosită pe $arg1 de un cont șters între timp';
  }

  @override
  String get signupKeyRevokeTitle => 'Revocați această cheie?';

  @override
  String get signupKeyRevokeMessage =>
      'Nimeni nu se va mai putea înregistra cu ea. Acțiunea nu poate fi anulată.';

  @override
  String get signupKeyRevoked => 'Cheie revocată.';

  @override
  String signupKeysShowMore(int count) {
    return 'Afișați încă $count';
  }

  @override
  String get signupKeysCreateTitle => 'Creați chei de înregistrare';

  @override
  String get signupKeysCount => 'Număr de chei';

  @override
  String get signupKeysCountHelper => 'Între 1 și 500';

  @override
  String get signupKeysCountInvalid => 'Introduceți un număr între 1 și 500.';

  @override
  String get signupKeysLabel => 'Etichetă (opțional)';

  @override
  String get signupKeysLabelHint => 'de ex. Testeri beta de primăvară';

  @override
  String signupKeysCreateAction(int count) {
    return 'Creați ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Chei pregătite: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Dați fiecare cheie unei singure persoane. Cheile nefolosite rămân în listă, astfel încât le puteți copia sau exporta din nou mai târziu.';

  @override
  String get signupKeysSaveDialogTitle => 'Salvați cheile de înregistrare';

  @override
  String get signupKeysExported => 'Chei exportate.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor a creat chei de înregistrare ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor a revocat o cheie de înregistrare';
  }

  @override
  String get providerChooseUsername => 'Alege-ți numele de utilizator';

  @override
  String get providerChooseUsernameBody =>
      'Alege un nume de utilizator disponibil pentru a finaliza crearea contului.';

  @override
  String get dataSharingTitle => 'Partajează datele de utilizare';

  @override
  String get dataSharingDescription =>
      'Ajută-i pe cei care administrează acest server să-l îmbunătățească. Partajează cum folosești NeoAgent, niciodată ce scrii sau stochezi.';

  @override
  String dataSharingSince(String date) {
    return 'Partajat din $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Ce se partajează';

  @override
  String get dataSharingIncluded => 'Se partajează';

  @override
  String get dataSharingExcluded => 'Nu se partajează niciodată';

  @override
  String get dataSharingIncludedDevice =>
      'Tipul dispozitivului și versiunea aplicației';

  @override
  String get dataSharingIncludedLocale =>
      'Limba aplicației și regiunea fusului orar, de exemplu Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Ce funcții ai configurat, cum ar fi sarcini, skilluri și integrări';

  @override
  String get dataSharingIncludedRuns =>
      'Ce instrumente și modele folosesc rulările tale, cu durate și număr de tokenuri';

  @override
  String get dataSharingIncludedActivity =>
      'Când folosești NeoAgent, pe zile ale săptămânii și ore';

  @override
  String get dataSharingExcludedContent => 'Mesaje, prompturi și răspunsuri';

  @override
  String get dataSharingExcludedRuns =>
      'Titlurile rulărilor, intrările și rezultatele instrumentelor';

  @override
  String get dataSharingExcludedFiles =>
      'Fișiere, amintiri și orice altceva stochezi';

  @override
  String get dataSharingExcludedIdentity =>
      'Numele, e-mailul, adresa IP și locația ta';

  @override
  String get dataSharingExcludedAccounts =>
      'Conturile cu care conectezi integrări';

  @override
  String get dataSharingPooledNote =>
      'Administratorii văd doar totaluri pentru toți cei care partajează, niciodată pe tine separat. Dezactivează oricând și ieși imediat din totaluri.';

  @override
  String get dataSharingConfirmTitle => 'Partajezi datele de utilizare?';

  @override
  String get dataSharingConfirmAction => 'Partajează';

  @override
  String get sharedUsageTitle => 'Utilizare partajată';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Conturi care partajează date de utilizare: $sharing din $total. Doar totaluri, fără conținut.';
  }

  @override
  String get sharedUsageEmpty =>
      'Nimeni nu partajează încă date de utilizare. Se poate activa din Setări, Profil, Datele dvs.';

  @override
  String get sharedUsageRuns => 'Rulări partajate';

  @override
  String get sharedUsageAvgDuration => 'Durată medie';

  @override
  String get sharedUsageCompletedRuns => 'Rulări finalizate';

  @override
  String get sharedUsageStepsPerRun => 'Pași per rulare';

  @override
  String get sharedUsageDevices => 'Dispozitive';

  @override
  String get sharedUsageAppVersions => 'Versiuni ale aplicației';

  @override
  String get sharedUsageLanguages => 'Limbi';

  @override
  String get sharedUsageRegions => 'Regiuni';

  @override
  String get sharedUsageFeatures => 'Adoptarea funcțiilor';

  @override
  String get sharedUsageFeaturesDescription =>
      'Proporția conturilor care partajează și au configurat-o.';

  @override
  String get sharedUsageTools => 'Instrumente';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Cele mai apelate instrumente ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Apeluri: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Eșuate: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integrări';

  @override
  String get sharedUsageMessaging => 'Canale de mesagerie';

  @override
  String get sharedUsageTriggers => 'Cum pornesc rulările';

  @override
  String get sharedUsageActivity => 'Când este folosit';

  @override
  String get sharedUsageActivityDescription =>
      'Rulări pe zile ale săptămânii și ore, UTC.';

  @override
  String get sharedUsageModels => 'Performanța modelelor';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'medie $latency · $cached% din cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Conturi: $count';
  }

  @override
  String get sharedUsageNoData => 'Nimic în această perioadă.';

  @override
  String get sharedUsageNotReported => 'Încă neraportat';

  @override
  String get sharedUsageFeatureAgents => 'Mai mult de un agent';

  @override
  String get sharedUsageFeatureTasks => 'Sarcini programate';

  @override
  String get sharedUsageFeatureSkills => 'Skilluri';

  @override
  String get sharedUsageFeatureMcp => 'Servere MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrări';

  @override
  String get sharedUsageFeatureMessaging => 'Canale de mesagerie';

  @override
  String get sharedUsageFeatureMemory => 'Memorie';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in partajare date telemetrie dispozitive funcții instrumente modele activitate';

  @override
  String get yourOAuthApp => 'Aplicația ta OAuth';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Aplicația ta OAuth $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Acest server nu are o aplicație $provider globală, așa că te conectezi cu o aplicație OAuth pe care o înregistrezi tu. Secretul clientului este stocat criptat și nu mai este afișat niciodată.';
  }

  @override
  String get oauthAppStepCreate => '1. Creează aplicația';

  @override
  String get openDeveloperConsole => 'Deschide consola pentru dezvoltatori';

  @override
  String get oauthAppStepCallback => '2. Înregistrează acest URL de callback';

  @override
  String get callbackUrlCopied => 'URL de callback copiat';

  @override
  String get oauthAppScopes => 'Scope-uri de permis';

  @override
  String get scopesCopied => 'Scope-uri copiate';

  @override
  String get oauthAppStepCredentials =>
      '3. Lipește datele de autentificare ale aplicației';

  @override
  String get couldNotSaveOAuthApp => 'Aplicația OAuth nu a putut fi salvată.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Elimini aplicația ta $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Conturile conectate rămân în listă, dar nu mai funcționează până nu adaugi din nou o aplicație.';

  @override
  String get globalIntegrationConfiguration =>
      'Configurație globală a integrărilor';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Aplicații OAuth opționale pentru tot serverul. Când o integrare are una, fiecare cont o folosește și nu își poate adăuga propria aplicație. Lasă o integrare nesetată și fiecare utilizator își configurează propria aplicație. Secretele pot fi doar scrise: lasă gol pentru a păstra valoarea stocată.';

  @override
  String get globalStatus => 'Global';

  @override
  String get perUserStatus => 'Per utilizator';
}
