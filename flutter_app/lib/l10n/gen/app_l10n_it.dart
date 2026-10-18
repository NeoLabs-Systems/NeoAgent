// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppL10nIt extends AppL10n {
  AppL10nIt([String locale = 'it']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Benvenuto';

  @override
  String get onboardingEyebrowCommunication => 'Comunicazione';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligenza';

  @override
  String get onboardingEyebrowComputer => 'Computer';

  @override
  String get onboardingEyebrowAutomation => 'Automazione';

  @override
  String get onboardingNext => 'Avanti';

  @override
  String get onboardingIntroCouldNotLoad =>
      'Impossibile caricare l\'introduzione.';

  @override
  String get onboardingModelDescription =>
      'Scegli il modello che NeoAgent dovrebbe utilizzare per impostazione predefinita o lascia che lo scelga automaticamente.';

  @override
  String get onboardingLoadingModels => 'Caricamento modelli…';

  @override
  String get noAiModelTitle =>
      'Nessun modello di intelligenza artificiale è stato ancora impostato';

  @override
  String get noAiModelBody =>
      'Aggiungi una chiave API da un provider come OpenAI, Anthropic o Google. NeoAgent mostra quindi i modelli che puoi utilizzare.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent ha bisogno di un modello di intelligenza artificiale per rispondere. Aggiungi una chiave API da un provider come OpenAI, Anthropic o Google.';

  @override
  String get noAiModelAdminHint =>
      'Come amministratore puoi anche impostare fornitori per tutti in Amministratore → Provider.';

  @override
  String get addApiKey => 'Aggiungi chiave API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform è connesso.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'In attesa della connessione di $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Impossibile salvare la configurazione: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Pronto';

  @override
  String get onboardingStepRequired => 'Obbligatorio';

  @override
  String get onboardingStepOptional => 'Facoltativo';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud o locale';

  @override
  String get onboardingStepComputer => 'Computer';

  @override
  String get onboardingStepRoutines => 'Routine';

  @override
  String get onboardingComputerChoiceTitle => 'Dove deve\nlavorare?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Puoi cambiare computer per ogni sessione.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Sandbox privata · sempre attiva';

  @override
  String get onboardingThisComputer => 'Questo computer';

  @override
  String get onboardingThisComputerSubtitle => 'I tuoi file, app e browser';

  @override
  String get onboardingSearchApps => 'Cerca app...';

  @override
  String get onboardingRoutinesDescription =>
      'I risultati arrivano nelle tue chat.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'I risultati arrivano come notifiche.';

  @override
  String get onboardingNotifications => 'Notifiche';

  @override
  String get onboardingReadyTitle => 'È tutto\npronto.';

  @override
  String get onboardingReadyDescription => 'Invia il tuo primo messaggio.';

  @override
  String get onboardingMessageNeoagent => 'Invia un messaggio a NeoAgent';

  @override
  String get onboardingAskAnything => 'Chiedi qualsiasi cosa...';

  @override
  String get onboardingOpenNeoagent => 'Apri NeoAgent';

  @override
  String get onboardingStarterTrip => 'Pianifica un viaggio nel fine settimana';

  @override
  String get onboardingStarterLanding =>
      'Costruisci una pagina di destinazione';

  @override
  String onboardingQuickSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passaggi rapidi',
      one: '$count passaggio rapido',
    );
    return '$_temp0';
  }

  @override
  String get taskNeedsEmail => 'Collega prima l\'e-mail';

  @override
  String get taskNeedsCalendar => 'Collega prima un calendario';

  @override
  String get taskNeedsModel => 'Configura prima un modello AI';

  @override
  String get taskPromptDailyRecap =>
      'Riepiloga la mia giornata: riassumi le conversazioni, il lavoro finito e le decisioni di oggi, quindi elenca tutto ciò a cui dovrei dare seguito domani. Sii breve e mandamelo.';

  @override
  String get taskPromptInboxCheck =>
      'Controlla la mia casella di posta elettronica per i messaggi arrivati ​​dall\'ultimo controllo. Inviami messaggi solo per e-mail urgenti o che richiedono una risposta, con un riepilogo di una riga ciascuna. Se niente richiede la mia attenzione, non inviare nulla.';

  @override
  String get taskPromptMorningBriefing =>
      'Prepara il mio briefing mattutino: il meteo di oggi nel luogo in cui mi trovo, gli eventi nel mio calendario e le voci aperte più importanti di cui sono a conoscenza. Invialo come messaggio breve e scansionabile.';

  @override
  String get taskPromptTomorrowPrep =>
      'Guarda il mio calendario per domani. Per ogni incontro, dimmi di cosa si tratta, chi è coinvolto e cosa dovrei preparare. Se domani è vuoto, non inviare nulla.';

  @override
  String get taskPromptNewsDigest =>
      'Cerca sul web le notizie più importanti di oggi sugli argomenti che mi interessano (usa ciò che ricordi dei miei interessi). Inviami un riassunto di un massimo di cinque elementi con una frase ciascuno e un collegamento.';

  @override
  String get taskPromptWeeklyReview =>
      'Rivedi la mia settimana: cosa è stato fatto, cosa è sfuggito e cosa è ancora aperto. Suggerisci le tre cose più importanti su cui concentrarti la prossima settimana.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Collega un numero di telefono che appartiene all\'agente. Chiunque consenti a te può chattare con esso, nelle chat dirette e nei gruppi.';

  @override
  String get whatsappSelfChatDescription =>
      'Collega il tuo numero e parla con l\'agente nella chat \"Invia messaggi a te stesso\". Ogni altra chat e gruppo su questo account viene ignorato.';

  @override
  String get chatSendHintMac => '⌘↵ per inviare';

  @override
  String get chatSendHintOther => 'Ctrl+Invio per inviare';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Per questo endpoint è richiesto un URL di base.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Un indirizzo email modificato viene confermato prima di essere utilizzato.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Vince una decisione più in alto nella catena.';

  @override
  String get aDeletedAccount => 'un account eliminato';

  @override
  String get aFridayLookBackAtThe =>
      'Un venerdì ripercorriamo la settimana e un piano per quella successiva.';

  @override
  String get aKeyThatAsksForA =>
      'Una chiave che richiede un PIN o un\'impronta digitale sostituisce anche il codice a due fattori.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Un modello linguistico ha valutato questo messaggio perché SystemOne è disattivato.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Un file di metadati di installazione di NeoAgent ha superato il limite di dimensione sicura.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Sul server è disponibile una build Web più recente. Ricarica per recuperare l\'ultimo pacchetto.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Un desktop privato con Chromium, file, un editor di testo, terminale e Python. Il tuo lavoro rimane salvato tra una sessione e l\'altra.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Un computer Linux privato o un dispositivo Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Non è stato possibile scaricare un file di installazione di NeoAgent richiesto.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Un compagno di squadra ti invia un collegamento di invito. Una volta che lo accetti, loro ';

  @override
  String get aTeammateSentYouAnInvite =>
      'un compagno di squadra ti ha inviato un link di invito, inseriscilo qui per unirti al suo team.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Un download temporaneo verrà ripulito in seguito.';

  @override
  String get aValueIsStored => 'Viene memorizzato un valore.';

  @override
  String get access => 'Accesso';

  @override
  String get accessActivity => 'Accedi all\'attività';

  @override
  String accessArg1(Object? arg1) {
    return 'Accesso: $arg1';
  }

  @override
  String get accessMode => 'Modalità di accesso';

  @override
  String get accessPermissions => 'Autorizzazioni di accesso';

  @override
  String get accessToken => 'token di accesso';

  @override
  String get accessToken2 => 'Token di accesso';

  @override
  String get account => 'Account';

  @override
  String accountArg1(Object? arg1) {
    return 'Conto n.$arg1';
  }

  @override
  String get accountChangeAlerts => 'Avvisi di modifica dell\'account';

  @override
  String get accountEmail => 'E-mail dell\'account';

  @override
  String get accountEmailIsOffUntilThese =>
      'L\'e-mail dell\'account è disattivata finché non vengono impostati questi elementi: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent usa questa lingua in tutta l’app. Al primo accesso usa la lingua di questo dispositivo. In seguito, la scelta viene salvata nel tuo account e applicata su tutti i dispositivi.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Impossibile cambiare la lingua: $error';
  }

  @override
  String get accountLanguageTitle => 'Lingua';

  @override
  String get accountNumber => 'Numero di conto';

  @override
  String get accountSettings => 'Impostazioni dell\'account';

  @override
  String get accounts => 'Account';

  @override
  String get accountsByTokensUsedAllTime =>
      'Conti per token utilizzati, sempre.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'computer cloud degli account. Le modifiche si applicano dopo un server ';

  @override
  String get accountsOnThisServer => 'Account su questo server';

  @override
  String get active => 'Attivo';

  @override
  String get activeSessions => 'Sessioni attive';

  @override
  String get activeToday => 'Attivo oggi';

  @override
  String get add => 'Aggiungi';

  @override
  String get addAProviderCredentialFirstIts =>
      'Aggiungi prima le credenziali del fornitore. I suoi modelli compaiono qui una volta ';

  @override
  String get addAgent => 'Aggiungi agente';

  @override
  String get addAnotherSignInMethodBefore =>
      'Aggiungi un altro metodo di accesso prima di rimuovere questo.';

  @override
  String get addBinding => 'Aggiungi rilegatura';

  @override
  String get addByNameOrId => 'Aggiungi per nome o ID';

  @override
  String get addByNameOrIdInstead => 'Aggiungi invece per nome o ID';

  @override
  String get addCredentialBinding => 'Aggiungi associazione di credenziali';

  @override
  String get addEntry => 'Aggiungi voce';

  @override
  String get addKey => 'Aggiungi chiave';

  @override
  String get addMcpServer => 'Aggiungi il server MCP';

  @override
  String get addMemory => 'Aggiungi memoria';

  @override
  String get memoryReview => 'Rivedi';

  @override
  String get memoryReviewPrompt =>
      'Rivedi tutti i miei ricordi e mettili in ordine: archivia i duplicati, i fatti obsoleti e tutto ciò che non ha valore duraturo. Poi dimmi brevemente cosa hai cambiato.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Aggiungi più lunghezza o un altro tipo di carattere.';

  @override
  String get addPeopleOrGroups => 'Aggiungi persone o gruppi';

  @override
  String get addSecurityKey => 'Aggiungi chiave di sicurezza';

  @override
  String get addSomeoneOrAGroup => 'Aggiungi qualcuno o un gruppo';

  @override
  String get addTask => 'Aggiungi attività';

  @override
  String get addTests => 'Aggiungi test';

  @override
  String get addTestsForThePartsOf =>
      'Aggiungi test per le parti di questo progetto che hanno la copertura minore, quindi eseguili.';

  @override
  String get addTheirOwnKeysInSettings =>
      'aggiungere le proprie chiavi in ​​Impostazioni.';

  @override
  String get addToPrompt => 'Aggiungi al prompt';

  @override
  String get added => 'Aggiunto';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Aggiunto $arg1 · Ultimo $arg2 utilizzato';
  }

  @override
  String get addressWithTheProvider => 'indirizzo con il fornitore.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Regola il volume dell\'altoparlante, esamina le impostazioni predefinite dei pulsanti hardware e gestisci questa sessione di avvio.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Modifica il filtro di ricerca o di stato per visualizzare più canali di messaggistica.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Regola qui il volume dell\'altoparlante.';

  @override
  String get admin => 'Amministratore';

  @override
  String adminArg1(Object? arg1) {
    return 'Amministratore › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Le concessioni amministrative, i collegamenti di invito e le modifiche alla gestione vengono visualizzati qui.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Programmazione manuale avanzata per casi particolari.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avanzato: minuto ora giorno mese giorno feriale.';

  @override
  String get againRightAway => 'di nuovo subito.';

  @override
  String get agent => 'Agente';

  @override
  String agentArg1(Object? arg1) {
    return 'Agente: $arg1';
  }

  @override
  String get agentCalls => 'L\'agente chiama';

  @override
  String get agentCommunication => 'Comunicazione dell\'agente';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Comunicazione dell\'agente: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'La modalità agente modifica lo spazio di lavoro · ⌘↵ invia · ⌘N nuova sessione';

  @override
  String get agentPausesAndAsksYouBefore =>
      'L’agente si ferma e ti chiede il permesso prima di avviare l’esecuzione.';

  @override
  String get agentProfile => 'Profilo dell\'agente';

  @override
  String get agentVisibleName => 'Nome visibile all\'agente';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'L\'agente vuole utilizzare $arg1. Tocca per decidere.';
  }

  @override
  String get agents => 'Agenti';

  @override
  String get aiAnswerUnreadable => 'Risposta dell\'IA illeggibile';

  @override
  String get aiProviderKeys =>
      'Chiavi del fornitore di intelligenza artificiale';

  @override
  String get aiUnavailable => 'IA non disponibile';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'avvisi e altre email dell\'account da.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Avvisa quando una connessione di messaggistica richiede l\'attenzione dell\'utente';

  @override
  String get all => 'Tutto';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Tutti gli agenti ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Tutti $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Tutti gli slot dei computer cloud sono attualmente utilizzati. Riprova tra un attimo.';

  @override
  String get allComputerSlotsAreBusy =>
      'Tutti gli slot del computer sono occupati';

  @override
  String get allTables => 'Tutti i tavoli';

  @override
  String get allTime => 'Tutto il tempo';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Tutti gli strumenti sono consentiti: l\'agente può utilizzare qualsiasi funzionalità senza chiedere. ';

  @override
  String get allow => 'Consenti';

  @override
  String get allowedRunsWithoutAsking => 'Consentito. Funziona senza chiedere.';

  @override
  String get allowAll => 'Consenti tutto';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Consenti \"Installa app sconosciute\" per NeoAgent, quindi riprova l\'aggiornamento.';

  @override
  String get allowOnce => 'Consenti una volta';

  @override
  String get allowSender => 'Consenti mittente';

  @override
  String get allowSession => 'Consenti sessione';

  @override
  String get allowTheAgentToStartAn =>
      'Consenti all\'agente di avviare una chiamata vocale in-app con te.';

  @override
  String get allowedOrigins => 'Origini consentite';

  @override
  String get allowedPathPrefix => 'Prefisso del percorso consentito';

  @override
  String get allowsYouCanChangeThatPer =>
      'permette. Puoi modificarlo per persona in seguito. I collegamenti non concedono mai ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'appartiene già a un account esistente';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'già collegato a un altro account';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'già collegato a un altro account neoagent';

  @override
  String get alreadyUsed => 'già utilizzato';

  @override
  String get always => 'Sempre';

  @override
  String get alwaysAllow => 'Consenti sempre';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Consenti sempre\" salva la policy in modo permanente: puoi modificarla in Impostazioni.';

  @override
  String get alwaysAsk => 'Chiedi sempre';

  @override
  String get alwaysEngage => 'Impegnarsi sempre';

  @override
  String get alwaysJoins => 'Si unisce sempre';

  @override
  String get anApiKeyIsRequired => 'È richiesta una chiave API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Un riepilogo serale di quello che è successo e cosa seguire.';

  @override
  String get anHttpOrHttpsUrlIs => 'È richiesto un URL http o https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'e analisi. I collegamenti al team sono disponibili nella pagina Team.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'L\'installazione dell\'APK Android non è disponibile su questa piattaforma.';

  @override
  String get androidApp => 'Applicazione Android';

  @override
  String get androidControl => 'Controllo Android';

  @override
  String get androidCouldNotStart => 'Impossibile avviare Android';

  @override
  String get androidNotificationReceived => 'Notifica Android ricevuta';

  @override
  String get androidOnly => 'Solo Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Impossibile aprire il programma di installazione del pacchetto Android.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Schermata Android: tocca per toccare, trascina per scorrere';

  @override
  String get androidSdk => 'SDK di Android';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Risposte a @menzioni su problemi e richieste pull';

  @override
  String get anyone => 'Chiunque';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Chiunque su questa piattaforma può inviare messaggi a $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Chiunque su questa piattaforma può inviare messaggi a $arg1 in $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Chiunque possa raggiungere questo account può parlare con $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Chiunque abbia il collegamento può iscriversi fino alla scadenza o fino alla revoca.';

  @override
  String get apiHttpsOrigin => 'Origine API HTTPS';

  @override
  String get apiKey => 'Chiave API';

  @override
  String get apiKey2 => 'chiave API';

  @override
  String get apiKey3 => 'Chiave API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api key antropic claude openai gpt xai grok google gemini minimax nvidia nim credenziali openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Chiavi API ed endpoint per fornitori di intelligenza artificiale, ricerca e voce. Loro ';

  @override
  String get apiRequest => 'Richiesta API';

  @override
  String get apiYourOwnServerASelf =>
      'API: il tuo server, un modello self-hosted o altro ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Download dell\'APK non riuscito con HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Il nome dell\'app è obbligatorio.';

  @override
  String get appUpdates => 'Aggiornamenti dell\'app';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Gli aggiornamenti dell\'app non sono configurati per questa build.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Applicati gli aggiornamenti dello sterzo in coda $arg1 alla corsa corrente.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Aggiornamenti dello sterzo $arg1 applicati.';
  }

  @override
  String get apply => 'Applicare';

  @override
  String get applyBehaviorNotes => 'Applicare note comportamentali';

  @override
  String get applyCoreMemory => 'Applicare la memoria principale';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Richieste di approvazione per strumenti agente sensibili';

  @override
  String get approvalRequired => 'È necessaria l\'approvazione';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'L\'approvazione rimane all\'interno della tua sessione mobile autenticata e ogni codice scade automaticamente dopo un breve periodo.';

  @override
  String get approveLogin => 'Approva l\'accesso';

  @override
  String get approveQrLogin => 'Approva l\'accesso QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Approvalo solo se hai avviato l\'accesso su quel dispositivo proprio ora.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Accesso approvato per $arg1.';
  }

  @override
  String get approvedOnly => 'Solo approvato';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Abbinamento approvato per $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Persone e gruppi approvati';

  @override
  String get approvedPeopleOnly => 'Solo persone approvate';

  @override
  String get archive => 'Archivio';

  @override
  String get archiveAgent => 'Agente d\'archivio?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archivio ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archivio $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Archiviare i ricordi selezionati?';

  @override
  String get areSharedByEveryAccountOn =>
      'sono condivisi da ogni account su questo server; i conti possono ancora ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return 'Ingresso \$$arg1 / 1M';
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
    return 'È necessario l\'accesso $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Conti $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 attivo';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 aggiunto. Modificalo in qualsiasi momento per cambiare il file ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '\"$arg1\" e la relativa cronologia delle corse verranno eliminati definitivamente. Qualsiasi corsa attiva verrà interrotta. I file nell\'area di lavoro non vengono toccati.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'È necessaria l\'approvazione $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'App $arg1 attive';
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
    return '$arg1 ($arg2 utensili attivi)';
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
    return '$arg1 $arg2 a $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 è cambiato';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 caratteri';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Creato $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [URI locale: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 corrispondente a “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}Area di lavoro NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 nuovi account';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 corre · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return 'Campioni $arg1 · $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 sterzo in coda';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nGettoni $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Gettoni $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 a $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 è diventato amministratore ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 byte';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Canale $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return 'Caratteri $arg1';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 cancellato.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 configurato';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 collegato. Scegli repository e persone in Chi può inviare messaggi.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Voci principali $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 ha creato un collegamento di invito';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Desktop $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Eventi $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 non riuscito';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 non è riuscito';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 fallito';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 per $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '${arg1}GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Gruppi $arg1 solo contrassegnati';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h fa';
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
    return 'Aiutanti $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(Rapporto di successo $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 è un amministratore, quindi l\'account non può essere eliminato ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 è bloccato su $arg2. Aggiorna l\'elenco di accesso per consentire le risposte.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 è connesso e risponde.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 non è più un amministratore ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 non è disponibile su $arg2 (autorizzazione o dipendenza di runtime mancante).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 si è unito sotto $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 giudicato da LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '${arg1}KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Tasto $arg1$arg2 configurato';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Chiave $arg1 rimossa.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 a sinistra';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 sinistra $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 collegato';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m fa';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Assicurati che sia in esecuzione, quindi riprova.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 gestisce questo account';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '${arg1}min';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 min $arg2 sec';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Modelli $arg1 pronti';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 altro';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 ulteriori passaggi nella cronologia di esecuzione';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 si è spostato da $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 deve essere un numero finito.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 deve essere un indirizzo http:// o https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 ha bisogno di attenzione';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/Area di lavoro NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nuovi account nell\'ultimo $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nuovi messaggi guidano questa corsa';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nuove corse';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 ora gestisce questo account.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 di 4 autorizzazioni consentite. I file sono limitati alla cartella NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 di $arg2 abilitato';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 dei gruppi $arg2 si unisce alla chat ordinaria';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 dei modelli $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 dei modelli $arg2 pronti';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 del set $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 degli utensili $arg2 consentiti';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 il giorno $arg2 alle ore $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 risponde solo alle persone che aggiungi di seguito.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 risponde solo quando taggato';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 parla solo con le persone e i gruppi che approvi';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 persone o gruppi aggiunti';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Pianificazione $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Fornitori $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 pronto';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Record $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI di reindirizzamento $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registrato';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 ha risposto';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 ha revocato un collegamento di invito';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 corre';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 corre · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 viene eseguito nell\'ultimo $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 salvato.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sec';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 selezionato';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 mostrato';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 rimase in silenzio';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 sterzo $arg2 in coda';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 passo$arg2 · toccare un nodo da ispezionare';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 passi';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 ha smesso di gestire $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Gettoni $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Gettoni $arg1 nell\'ultimo $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Strumenti $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (override salvato non disponibile)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% utilizzato · $arg2 rimanente';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 vuole parlare con te.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" verrà rimosso definitivamente.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 gestirà questo account';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 non risponderà su questa piattaforma';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 non risponderà a $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Archiviazione degli artefatti per utente';

  @override
  String get askAQuestionOrStartA => 'Fai una domanda o avvia un\'attività...';

  @override
  String get askBeforeClosingToBackground =>
      'Chiedi prima di passare allo sfondo';

  @override
  String get askMe => 'Chiedimelo';

  @override
  String get assignedAgent => 'Agente assegnato';

  @override
  String get assignedAgent2 => 'Agente assegnato';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Agente assegnato: $arg1';
  }

  @override
  String get assigneeOptional => 'Assegnatario (facoltativo)';

  @override
  String get assistant => 'Assistente';

  @override
  String get assistantKey131 => 'Tasto assistente 131';

  @override
  String get atLeast1 => 'Almeno 1.';

  @override
  String get attachFiles => 'Allega file';

  @override
  String attentionArg1(Object? arg1) {
    return 'Attenzione $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'l\'amministratore del registro di controllo concede la revoca della cronologia degli inviti al team';

  @override
  String get authMethod => 'Metodo di autenticazione';

  @override
  String get authServerUrl => 'URL del server di autenticazione';

  @override
  String get authentication => 'Autenticazione';

  @override
  String get authenticationFailed => 'Autenticazione non riuscita.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'L’autenticazione è ancora in sospeso. Completa la procedura nel browser e riprova.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'L’autenticazione è ancora in sospeso. Completa la procedura nel browser e aggiorna.';

  @override
  String get authenticationTimedOut => 'Autenticazione scaduta.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'L\'autenticazione è stata annullata prima del completamento.';

  @override
  String get authenticatorApp => 'Applicazione di autenticazione';

  @override
  String get authenticatorCode => 'Codice dell\'autenticatore';

  @override
  String get authorOptional => 'Autore (facoltativo)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (primo provider con una chiave API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Percorsi automatici verso il miglior modello disponibile';

  @override
  String get automaticFast => 'Automatico (veloce)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatico legge la stanza e normalmente trattiene. La sola menzione non prende alcuna decisione finché non viene indirizzata direttamente.';

  @override
  String get automaticReserved => 'Automatico, riservato';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Il rollback automatico richiede un nuovo tentativo dalla schermata di configurazione.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatico seleziona un modello veloce attraverso il normale catalogo modelli.';

  @override
  String get automation => 'Automazione';

  @override
  String get available => 'Disponibile';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Di nuovo disponibile in $arg1';
  }

  @override
  String get availableAgainShortly => 'Di nuovo disponibile a breve';

  @override
  String get availableInTheDesktopAppFor =>
      'Disponibile nell\'app desktop per macOS, Windows e Linux';

  @override
  String get availableToTheAgent => 'A disposizione dell\'agente';

  @override
  String get averageAllTime => 'Nella media, sempre';

  @override
  String get avgImp => 'Imp. media';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Media/esecuzione: token $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Evita caratteri ripetuti e sequenze ovvie.';

  @override
  String get awaitingScan => 'In attesa di scansione';

  @override
  String get back => 'Indietro';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count sullo sfondo';
  }

  @override
  String get backgroundTasks => 'Attività in background';

  @override
  String get backOn => 'riaccendersi.';

  @override
  String get backToChat => 'Torniamo alla chat';

  @override
  String get backToFolder => 'Torna alla cartella';

  @override
  String get backToSignIn => 'Torna per accedere';

  @override
  String get backendChannel => 'Canale di back-end';

  @override
  String get backendOnThisComputer => 'Backend su questo computer';

  @override
  String get backendSync => 'Sincronizzazione del back-end';

  @override
  String get backgroundLocationNeeded => 'Posizione dello sfondo necessaria';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'La sincronizzazione in background rimane pianificata su Android';

  @override
  String get badState => 'Cattivo stato: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Immagine di base e dimensione delle macchine virtuali QEMU in esecuzione ';

  @override
  String get baseUrlOptional => 'URL di base (facoltativo)';

  @override
  String get baseUrlTokenLocal => 'token URL di base locale';

  @override
  String get basicAuthentication => 'Autenticazione di base';

  @override
  String get behaviorModules => 'Moduli comportamentali';

  @override
  String get behaviorNotes => 'note comportamentali';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Broker di credenziali Bitwarden';

  @override
  String get bitwardenItem => 'Articolo Bitwarden';

  @override
  String get bitwardenServer => 'Server Bitwarden';

  @override
  String get blankUsesCommon => 'Lo spazio vuoto usa \"comune\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Vuoto utilizza la richiamata predefinita';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'I valori vuoti utilizzano le impostazioni predefinite del provider.';

  @override
  String get block => 'Blocca';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Messaggio in arrivo bloccato da $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge =>
      'Bridge compatibile con BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL del server BlueBubbles';

  @override
  String get botToken => 'Gettone bot';

  @override
  String get botTokenAndApprovedChats => 'Token bot e chat approvate';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token bot e accesso al server/canale';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token bot, API Eventi e accesso al canale';

  @override
  String get botUserId => 'ID utente del bot';

  @override
  String get botUsername => 'Nome utente del bot';

  @override
  String get brandName => 'Marchio';

  @override
  String get braveSearch => 'Ricerca coraggiosa';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Collega qualsiasi provider in grado di pubblicare e ricevere payload webhook.';

  @override
  String get bringYourOwnKey => 'porta la tua chiave';

  @override
  String get bringYourOwnKey2 => 'Porta la tua chiave';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Browser, desktop Linux, file, terminale e Python condividono un computer cloud persistente.';

  @override
  String get browserLogin => 'Accesso al browser';

  @override
  String get browserScripting => 'Script del browser';

  @override
  String get call => 'Chiama';

  @override
  String get callAgent => 'Chiama l\'agente';

  @override
  String get callUser => 'Chiama utente';

  @override
  String get calledByName => 'Chiamato per nome';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Può delegare compiti ad altri agenti';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Può delegare a $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Può ricevere compiti delegati';

  @override
  String get cancel => 'Annulla';

  @override
  String get cancelTask => 'Annulla attività';

  @override
  String get cannotPreview => 'Impossibile visualizzare l\'anteprima';

  @override
  String get cannotReceiveDelegatedTasks => 'non può ricevere compiti delegati';

  @override
  String get cannotRunYet => 'non è ancora possibile eseguire.';

  @override
  String get capturedThePage => 'Catturato la pagina';

  @override
  String get category => 'Categoria';

  @override
  String chainArg1(Object? arg1) {
    return 'Catena: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Cambia la modalità di configurazione';

  @override
  String get channel => 'Canale';

  @override
  String get channelAccessToken => 'Token di accesso al canale';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Canale: $arg1$arg2 | Versione aggiornata: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory =>
      'Memoria sociale con ambito di canale';

  @override
  String get channels => 'Canali';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'ID chat';

  @override
  String get chatMode => 'Modalità chat';

  @override
  String get chatModel => 'Modello di chat';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Controlla automaticamente all\'avvio';

  @override
  String get checkForMessagesEveryMs => 'Controlla i messaggi ogni (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Controlla automaticamente la presenza di nuovi messaggi';

  @override
  String get checkNow => 'Controlla ora';

  @override
  String get checkYourEmailToConfirmYour =>
      'Controlla la tua email per confermare il tuo account NeoAgent prima di accedere.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Controllato $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Scegli una categoria o cerca in tutte le impostazioni.';

  @override
  String get chooseAPerson => 'Scegli una persona';

  @override
  String get chooseAProjectFolder => 'Scegli una cartella di progetto';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Scegli le impostazioni predefinite per chat, agenti, comportamento di fallback e routing intelligente.';

  @override
  String get chooseGroups => 'Scegli i gruppi';

  @override
  String get chooseHowMuchYouWantTo =>
      'Scegli quanto vuoi configurare adesso. Entrambe le opzioni possono essere modificate in seguito.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Scegli come dovrebbe iniziare questa attività. Il manuale viene eseguito solo in Esegui ora. Il programma è basato sul tempo. L\'integrazione attiva l\'attivazione delle app ufficiali connesse.';

  @override
  String get chooseOneToGetStartedNow =>
      'Scegline uno per iniziare subito. Puoi aggiungerne altri in seguito.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Scegli la modella dal vivo e la voce nelle Impostazioni.';

  @override
  String get chooseTheirGroup => 'Scegli il loro gruppo';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Scegli dove consentire a questa persona di parlare con $arg1. Puoi modificarlo in seguito in Chi può inviare messaggi.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Scegli a quali gruppi $arg1 dovrebbe unirsi anche quando nessuno lo tagga. Questa piattaforma potrebbe non distinguere i tag dai normali messaggi.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Scegli quali modelli può scegliere ogni account su questo server e ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Scegli con chi $arg1 parlare e quando partecipare alle chat di gruppo.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Scegli chi può raggiungere $arg1, quindi salva le modifiche.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Scegli chi può inviare messaggi all\'agente con \"Chi può inviare messaggi\" sulla scheda WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Scegli il tuo\nmodello predefinito.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, i file, l\'editor di testo e il terminale sono tutti disponibili dal desktop Linux.';

  @override
  String get claudeCode => 'Codice Claudio';

  @override
  String get clear => 'Cancella';

  @override
  String get clearAll => 'Cancella tutto';

  @override
  String clearArg1(Object? arg1) {
    return 'Cancella $arg1?';
  }

  @override
  String get clearFilter => 'Cancella filtro';

  @override
  String get clearFilters => 'Cancella filtri';

  @override
  String get clearSearch => 'Cancella ricerca';

  @override
  String get clearView => 'Visione chiara';

  @override
  String get cliSession => 'Sessione CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'il clic non è supportato su questa piattaforma.';

  @override
  String get clickOnceToBeginCapturing =>
      'Fare clic una volta per iniziare l\'acquisizione';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Fai clic, digita e interagisci con le app desktop.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Cliccato su ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Cliccato nel browser';

  @override
  String get clientId => 'ID cliente';

  @override
  String get clientSecret => 'Segreto del cliente';

  @override
  String get close => 'Chiudi';

  @override
  String get closeJ => 'Chiudi (⌘J)';

  @override
  String get closeTeachMode => 'Chiudere la modalità di apprendimento';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Chiudendo la finestra è possibile mantenere NeoAgent in esecuzione in background con accesso al vassoio o uscire completamente dal runtime del desktop.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Sono supportate istanze cloud e self-hosted. Gli URL di rete locale e privata funzionano quando NeoAgent può raggiungerli.';

  @override
  String get cloudComputer => 'Computer nel cloud';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Computer cloud · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Impostazioni del computer cloud salvate. Riavviare il server per applicarli.';

  @override
  String get cloudComputerVm => 'Computer cloud (VM)';

  @override
  String get cloudComputers => 'Computer nella nuvola';

  @override
  String get codeHosting => 'Hosting del codice';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Nomi dei canali separati da virgole, senza #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Separati da virgole, ad esempio #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Separati da virgole. Il problema deve riguardarli tutti.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Comando fallito ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'È necessario il comando.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'L\'accumulatore dell\'uscita di comando non è attivo.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Caricamento dell\'output del comando non riuscito ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Il caricamento dell\'output del comando ha omesso i metadati dell\'artefatto.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'L\'output del comando era già finalizzato.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Comandi e app';

  @override
  String get commandsRunInTheSamePersistent =>
      'I comandi vengono eseguiti nello stesso computer persistente utilizzato dal desktop visibile.';

  @override
  String get communityChatops => 'Comunità e ChatOps';

  @override
  String get completeSetup => 'Configurazione completa';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Completa il flusso di lavoro sul desktop.';

  @override
  String get completed => 'Completato';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Completamente bloccato: l\'agente non può utilizzare questa categoria.';

  @override
  String get computerShell => 'Guscio del computer';

  @override
  String get computerUsedByThisSession =>
      'Computer utilizzato da questa sessione';

  @override
  String get computerWorkspace => 'Area di lavoro del computer';

  @override
  String get configurablePersonalWebhookBridge =>
      'Bridge webhook personale configurabile';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Relè configurabile o bridge webhook';

  @override
  String get configurableTalkWebhookBridge =>
      'Bridge webhook Talk configurabile';

  @override
  String get configurableWebInboxBridge =>
      'Bridge di posta in arrivo web configurabile';

  @override
  String get configurableWebhookBridge => 'Bridge webhook configurabile';

  @override
  String get configurableWebhooks => 'Webhook configurabili';

  @override
  String get configurationOrInTheEnvFile => 'Configurazione o nel file .env.';

  @override
  String get configure => 'Configura';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configurare il comportamento dell\'area di lavoro e le impostazioni predefinite del modello.';

  @override
  String configuredArg1(Object? arg1) {
    return '$arg1 configurato';
  }

  @override
  String get confirmEmailChanges => 'Conferma le modifiche all\'e-mail';

  @override
  String get confirmNewSignUps => 'Conferma nuove iscrizioni';

  @override
  String get confirmPassword => 'Conferma la password';

  @override
  String get confirmPassword2 => 'Conferma password';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Conferma la tua email prima di accedere. Controlla il messaggio email di servizio di NeoAgent.';

  @override
  String get connect => 'Connettiti';

  @override
  String get connectAMessagingPlatform =>
      'Connetti una piattaforma\ndi messaggistica.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Connetti un endpoint HTTPS Home Assistant pubblico con un token di accesso di lunga durata. Gli indirizzi di rete locale, di loopback e privata sono bloccati dal server.';

  @override
  String get connectAccount => 'Connetti conto';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Collega gli account delle app individualmente in modo che l\'IA possa utilizzare l\'account giusto per ogni integrazione ufficiale.';

  @override
  String connectArg1(Object? arg1) {
    return 'Collega $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Connetti tutti gli account che desideri. Ogni app può utilizzare un account diverso.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Collega i canali, scegli con chi parlare $arg1 e guarda le attività recenti.';
  }

  @override
  String get connectInstance => 'Connetti l\'istanza';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Collega prima questa integrazione per scegliere un account.';

  @override
  String get connectToThisServer => 'Connettiti a questo server';

  @override
  String get connectWhatsapp => 'Collega WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Connetti la tua istanza Nextcloud, inclusi i server self-hosted. NeoAgent apre la pagina di accesso di Nextcloud in modo da poter accedere con password, SSO o 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Connetti il ​​tuo server NeoRecall self-hosted. NeoAgent riceve accesso di sola lettura alla ricerca locale, ai ricordi e alle prove di trascrizione dopo aver approvato la schermata OAuth.';

  @override
  String get connected => 'Connesso';

  @override
  String get connectedAccount => 'Conto connesso';

  @override
  String connectedArg1(Object? arg1) {
    return 'Connesso $arg1';
  }

  @override
  String get connectedInstance => 'Istanza connessa';

  @override
  String get connectedNeorecallUser => 'Utente NeoRecall connesso';

  @override
  String get connectedNextcloudUser => 'Utente Nextcloud connesso';

  @override
  String get connectedServer => 'Server connesso';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Connessione al modello vocale dal vivo...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Connessione #$arg1';
  }

  @override
  String get connectionId => 'ID di connessione';

  @override
  String get connectionLooksGood => 'La connessione sembra buona.';

  @override
  String get connectionMethod => 'Metodo di connessione';

  @override
  String get containsTextOptional => 'Contiene testo (facoltativo)';

  @override
  String get content => 'Contenuto';

  @override
  String get contentSecurityPolicy => 'politica di sicurezza dei contenuti';

  @override
  String get continue2 => 'Continua';

  @override
  String get continueFullSetup => 'Continua la configurazione completa';

  @override
  String get continueRun => 'Continua a correre';

  @override
  String get continueToSetup => 'Continua con la configurazione';

  @override
  String get controlSurface => 'SUPERFICIE DI CONTROLLO';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Controlla l\'accesso agli strumenti $arg1.';
  }

  @override
  String get conversation => 'Conversazione';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID conversazione utilizzato quando questo agente avvia una chat.';

  @override
  String get cookieSetup => 'Configurazione dei cookie';

  @override
  String get cookiesNotConfigured => 'Cookie non configurati';

  @override
  String get copiedAsCsv => 'Copiato come CSV';

  @override
  String get copiedDebugInfo => 'Informazioni di debug copiate';

  @override
  String get copiedExportForTheLast5 =>
      'Esportazione copiata per gli ultimi 5 messaggi';

  @override
  String get copiedFullPrompt => 'Richiesta completa copiata';

  @override
  String get copiedLogs => 'Registri copiati';

  @override
  String get copiedRunId => 'ID esecuzione copiato';

  @override
  String get copy => 'Copia';

  @override
  String get copyAll => 'Copia tutto';

  @override
  String get copyCodes => 'Copia codici';

  @override
  String get copyCsv => 'Copia CSV';

  @override
  String get copyDebugInfo => 'Copia le informazioni di debug';

  @override
  String get copyLink => 'Copia collegamento';

  @override
  String get copyLogs => 'Copia i log';

  @override
  String get copyPrompt => 'Copia richiesta';

  @override
  String get copyResponse => 'Copia la risposta';

  @override
  String get copyRunId => 'Copia ID esecuzione';

  @override
  String get copyWebhookUrl => 'Copia l\'URL del webhook';

  @override
  String get core => 'Nucleo';

  @override
  String get coreMemory => 'memoria centrale';

  @override
  String get coreServicesThisServerDependsOn =>
      'Servizi principali da cui dipende questo server.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'dominio cors origini URL pubbliche https';

  @override
  String get couldHelp => 'Potrebbe aiutare';

  @override
  String get couldNotApproveQrLogin => 'Impossibile approvare l\'accesso QR.';

  @override
  String get couldNotApproveQrPairing =>
      'Impossibile approvare l\'associazione QR.';

  @override
  String get couldNotConnect => 'Impossibile connettersi.';

  @override
  String get couldNotCreateBinding => 'Impossibile creare l\'associazione.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Impossibile eliminare il tuo account: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Impossibile disconnettere Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Impossibile disconnettere Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Impossibile disconnettere NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Impossibile disconnettere Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Impossibile disconnettere Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Impossibile esportare i tuoi dati: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Impossibile caricare le decisioni';

  @override
  String get couldNotLoadUsageData =>
      'Impossibile caricare i dati di utilizzo.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Impossibile aprire automaticamente le impostazioni Linux.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Impossibile aprire la pagina di collegamento del provider.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Impossibile aprire la pagina di accesso del provider.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Impossibile aprire la risorsa di rilascio.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Impossibile aprire Trello nel tuo browser.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Impossibile aprire il download del file dell\'area di lavoro.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Impossibile leggere il pacchetto dell\'app Android.';

  @override
  String get couldNotReadTheApk => 'Impossibile leggere l\'APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Impossibile rimuovere la chiave: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Impossibile salvare l\'agente.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Impossibile salvare la configurazione di Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Impossibile salvare la configurazione di Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Impossibile salvare la configurazione di NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Impossibile salvare la configurazione di Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Impossibile salvare la configurazione di Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'impossibile inviare l\'e-mail di conferma';

  @override
  String get couldNotStart => 'Impossibile avviare';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Crea';

  @override
  String get createAPasswordFirstToChange =>
      'Crea prima una password per modificare l\'e-mail del tuo account.';

  @override
  String get createAPasswordOrLinkAnother =>
      'crea una password o collega un altro provider prima di rimuovere questo metodo di accesso';

  @override
  String get createATaskWhileThisAgent =>
      'Crea un\'attività mentre questo agente è selezionato.';

  @override
  String get createLink => 'Crea collegamento';

  @override
  String get createOrModifyFilesInYour =>
      'Crea o modifica file nel tuo spazio di lavoro.';

  @override
  String get createPassword => 'Crea password';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Crea bot specializzati con memoria, impostazioni, strumenti e assegnazioni di account separati.';

  @override
  String get createTheFirstAccount => 'Crea il primo account';

  @override
  String get createUpdateOrDeleteSkills =>
      'Creare, aggiornare o eliminare competenze.';

  @override
  String get creatingYourSkill => 'Creare la tua abilità...';

  @override
  String get credentialBindings => 'Associazioni di credenziali';

  @override
  String get credentialUse => 'Utilizzo delle credenziali';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Esecuzioni ricorrenti basate su cron ed esecuzione temporizzata una tantum.';

  @override
  String get cronExpression => 'Espressione cron';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Invio esegue la query.';

  @override
  String get ctrlShiftSpace => 'Ctrl+Maiusc+Spazio';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'E-mail attuale: $arg1';
  }

  @override
  String get currentPassword => 'Password attuale';

  @override
  String get currentPasswordIsIncorrect => 'la password attuale non è corretta';

  @override
  String get currentTwoStepLoginCode =>
      'Attuale codice di accesso in due passaggi';

  @override
  String get customAccess => 'Accesso personalizzato';

  @override
  String get customCron => 'Cronologia personalizzata';

  @override
  String get customCronMustHave5Fields =>
      'Il Cron personalizzato deve avere 5 campi.';

  @override
  String get customEndpoint => 'endpoint personalizzato';

  @override
  String get customField => 'Campo personalizzato';

  @override
  String get customHeader => 'Intestazione personalizzata';

  @override
  String get customHeadersJson => 'Intestazioni personalizzate (JSON)';

  @override
  String get customOpenaiCompatible => 'Compatibile con OpenAI personalizzato';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Endpoint personalizzato compatibile con OpenAI';

  @override
  String get customOutgoingUrl => 'URL in uscita personalizzato';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Ogni giorno';

  @override
  String get dailyRecap => 'Riepilogo giornaliero';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'query sul database seleziona modelli CSV';

  @override
  String dayArg1(Object? arg1) {
    return 'Giorno $arg1';
  }

  @override
  String get dayOfMonth => 'Giorno del mese';

  @override
  String get decideWhichToolsYourAgentMay =>
      'decidere quali strumenti può utilizzare il tuo agente. Vedono il tuo nome e ';

  @override
  String get decisionHigherUpTheChainWins =>
      'la decisione più in alto nella catena vince e mostra un lucchetto con il ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Le decisioni vengono visualizzate qui mentre $arg1 legge i gruppi $arg2 approvati. Vengono mantenuti solo gli ultimi 30 e vengono reimpostati al riavvio del server.';
  }

  @override
  String get decline => 'Rifiutare';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'corsa profonda · passo $arg1';
  }

  @override
  String get deepgramKey => 'Chiave di Deepgram';

  @override
  String get default2 => 'Predefinito';

  @override
  String get default3 => 'PREDEFINITO';

  @override
  String defaultArg1(Object? arg1) {
    return 'Predefinito ($arg1)';
  }

  @override
  String get defaultConversation => 'Conversazione predefinita';

  @override
  String get defaultForNewGroups => 'Predefinito per i nuovi gruppi';

  @override
  String get defaultGroupParticipation =>
      'Partecipazione al gruppo predefinita';

  @override
  String get defaultNeoagentWorkspace =>
      'Area di lavoro predefinita di NeoAgent';

  @override
  String get defaultOpenai => 'Predefinito (OpenAI)';

  @override
  String get defaultRateLimits => 'Limiti di tasso predefiniti';

  @override
  String get defaultRateLimitsSaved => 'Limiti di tariffa predefiniti salvati.';

  @override
  String get defaultRecommended => 'Predefinito (consigliato)';

  @override
  String get defaultRouting => 'Itinerario predefinito';

  @override
  String get defaultSpace => 'Spazio predefinito';

  @override
  String get delete => 'Elimina';

  @override
  String get deleteAccount => 'Elimina account';

  @override
  String get deleteAccountPermanently =>
      'Eliminare l\'account in modo permanente?';

  @override
  String get deleteAnAccount => 'Elimina un account';

  @override
  String deleteArg1(Object? arg1) {
    return 'Eliminare @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Elimina ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Eliminare $arg1 $arg2 in modo permanente?';
  }

  @override
  String get deleteBinding => 'Elimina l\'associazione';

  @override
  String get deleteCoreMemoryEntry =>
      'Eliminare la voce della memoria principale?';

  @override
  String get deleteForever => 'Elimina per sempre';

  @override
  String get deleteMcpServer => 'Eliminare il server MCP?';

  @override
  String get deleteMemory => 'Eliminare la memoria?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Elimina cancella definitivamente un account e tutti i suoi dati ';

  @override
  String get deleteRun => 'Eliminare la corsa?';

  @override
  String get deleteRun2 => 'Elimina corsa';

  @override
  String get deleteSelectedMemories => 'Eliminare i ricordi selezionati?';

  @override
  String get deleteSession => 'Eliminare la sessione?';

  @override
  String get deleteSkill => 'Eliminare la competenza?';

  @override
  String get deleteTask => 'Eliminare l\'attività?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Eliminato \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Eliminato @$arg1 e tutti i suoi dati.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'L\'eliminazione rimuove tutte le tue conversazioni, ricordi, file, attività e ';

  @override
  String get deliverableArtifactProduced => 'Artefatto consegnabile prodotto';

  @override
  String get deliverableCompleted => 'Consegna completata';

  @override
  String get deliverableExecutionStarted =>
      'È iniziata l\'esecuzione del deliverable';

  @override
  String get deliverableSelected => 'Prodotto selezionato';

  @override
  String get deliverableValidationFailed =>
      'La convalida del risultato finale non è riuscita';

  @override
  String get deliverableValidationStarted =>
      'È iniziata la convalida dei risultati finali';

  @override
  String get deny => 'Rifiuta';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Descrivi il risultato, quindi dimostralo sul desktop';

  @override
  String get describeWhatToBuildOrChange =>
      'Descrivi cosa costruire o modificare...';

  @override
  String get description => 'Descrizione';

  @override
  String get desktopApp => 'Applicazione desktop';

  @override
  String get desktopAppControlsAvailable =>
      'Controlli dell\'app desktop disponibili';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'L\'acquisizione desktop non è disponibile su questa piattaforma.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Caricamento dell\'output del comando desktop annullato.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Il comando del compagno desktop è stato annullato.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Connessione al desktop complementare scaduta.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'L\'handshake del compagno desktop è scaduto.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Il compagno desktop non è disponibile qui.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Il compagno desktop è in pausa localmente.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Gestione dei messaggi associati al desktop non riuscita: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Le impostazioni delle autorizzazioni del compagno desktop non sono disponibili sul Web.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Le impostazioni delle autorizzazioni del compagno desktop non sono disponibili su questa piattaforma.';

  @override
  String get desktopCompanionRejected => 'Compagno desktop rifiutato.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Risposta del compagno desktop non riuscita: $arg1';
  }

  @override
  String get desktopControl => 'Controllo del desktop';

  @override
  String get desktopFailedToStart => 'Impossibile avviare il desktop';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Acquisizione del flusso desktop non riuscita: $arg1';
  }

  @override
  String get destinationId => 'Identificativo di destinazione';

  @override
  String get deviceAccess => 'Accesso al dispositivo';

  @override
  String get deviceSettings => 'Impostazioni del dispositivo';

  @override
  String get devices => 'Dispositivi';

  @override
  String get diagnosticsSaved => 'Diagnostica salvata.';

  @override
  String get directBluebubblesImessageBridge =>
      'Bridge iMessage BlueBubbles diretto';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'I messaggi diretti rimangono reattivi. I gruppi consentiti utilizzano la modalità di partecipazione riportata di seguito.';

  @override
  String get directoryDoesNotExist => 'La directory non esiste.';

  @override
  String get disable2fa => 'Disabilita 2FA';

  @override
  String get disableAll => 'Disabilita tutto';

  @override
  String get discard => 'Scartare';

  @override
  String get disconnect => 'Disconnetti';

  @override
  String get disconnectHomeAssistant =>
      'Disconnettere l\'Assistente Domestico?';

  @override
  String get disconnectNeorecall => 'Disconnettere NeoRecall?';

  @override
  String get disconnectNextcloud => 'Disconnettere Nextcloud?';

  @override
  String get disconnectPlatform => 'Disconnetti la piattaforma';

  @override
  String get disconnectTrello => 'Disconnettere Trello?';

  @override
  String get discoveryFailed => 'La scoperta non è riuscita';

  @override
  String get dismiss => 'Ignora';

  @override
  String get displayIdIsRequired => 'L\'ID visualizzato è obbligatorio.';

  @override
  String get displayName => 'Nome visualizzato';

  @override
  String get displayNameMustBe64Characters =>
      'Il nome visualizzato deve contenere al massimo 64 caratteri.';

  @override
  String get displayNameSaved => 'Nome visualizzato salvato.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Non includere il tuo nome utente o la tua email.';

  @override
  String get done => 'Fatto';

  @override
  String get downloadACopyOfYourData =>
      'Scarica una copia dei tuoi dati. Gli account amministratore non possono essere eliminati ';

  @override
  String get downloadACopyOfYourData2 =>
      'Scarica una copia dei tuoi dati o elimina definitivamente il tuo account. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Scarica $arg1';
  }

  @override
  String get downloadUpdate => 'Scarica l\'aggiornamento';

  @override
  String get downloadingTheNeoagentBackend => 'Download del backend NeoAgent';

  @override
  String get draft => 'Bozza';

  @override
  String get dragIsNotSupportedOnThis =>
      'il trascinamento non è supportato su questa piattaforma.';

  @override
  String get draggedOnTheScreen => 'Trascinato sullo schermo';

  @override
  String get dropAnApkOrApkBundle =>
      'Rilascia qui un APK o un pacchetto APK per installarlo';

  @override
  String get dropApkOrApksHere => 'Rilascia APK o .apks qui';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Istruzioni durevoli per lo stile vocale e di interazione. Le norme di sicurezza e di esecuzione continuano ad avere la priorità.';

  @override
  String get eGAlexSLaptop => 'per esempio. Il portatile di Alex';

  @override
  String get eGMyLocalServer => 'ad es. Il mio server locale';

  @override
  String get edit => 'Modifica';

  @override
  String get editAgent => 'Modifica agente';

  @override
  String get editCoreMemoryEntry => 'Modifica voce memoria principale';

  @override
  String get editInstructions => 'Modifica istruzioni';

  @override
  String get editMcpServer => 'Modifica server MCP';

  @override
  String get editTask => 'Modifica attività';

  @override
  String editedArg1(Object? arg1) {
    return 'Modificato $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Proprietari di account email relativi ad accessi che sembrano insoliti.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Invia email ai proprietari degli account quando cambiano i dettagli del loro account.';

  @override
  String get emailCode => 'Codice e-mail';

  @override
  String get emailConfirmationRequired =>
      'è richiesta la conferma tramite e-mail';

  @override
  String get emailIsAlreadyInUse => 'l\'e-mail è già in uso';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail salvata. Se è richiesta una conferma, controllare il nuovo indirizzo per un collegamento di conferma di NeoAgent.';

  @override
  String get emailSettingsSaved => 'Impostazioni e-mail salvate.';

  @override
  String get emailUnverified => 'E-mail non verificata';

  @override
  String get empty => 'Vuoto';

  @override
  String get emptyFile => 'File vuoto';

  @override
  String get emptyFolder => 'Cartella vuota';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Vuoto utilizza l\'impostazione predefinita del server ($arg1).';
  }

  @override
  String get enable2fa => 'Abilita 2FA';

  @override
  String get enableAll => 'Abilita tutto';

  @override
  String get enableBehaviorModules => 'Abilita i moduli di comportamento';

  @override
  String get enableOrDisableModels => 'Abilita o disabilita i modelli';

  @override
  String get enabled => 'Abilitato';

  @override
  String get encryptedPrivateToYourAccount =>
      'Crittografato, privato per il tuo account';

  @override
  String get end => 'Fine';

  @override
  String get endCall => 'Termina chiamata';

  @override
  String get endVoiceCall => 'Terminare la chiamata vocale?';

  @override
  String get endpoint => 'Punto finale';

  @override
  String get enterAPassword => 'Inserisci una password.';

  @override
  String get enterAUsername => 'Inserisci un nome utente.';

  @override
  String get enterAValidEmailAddress => 'Inserisci un indirizzo email valido.';

  @override
  String get enterAnAddressManually => 'Inserisci un indirizzo manualmente';

  @override
  String get enterAnApiKeyFirst => 'Inserisci prima una chiave API.';

  @override
  String get enterInviteLink => 'Inserisci il link di invito';

  @override
  String get enterTheAddressOfANeoagent =>
      'Immettere l\'indirizzo di un server NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Inserisci i dettagli che $arg1 ti ha fornito in modo che $arg2 possa inviare e ricevere messaggi.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Inserisci il tuo codice 2FA o di ripristino.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Inserisci la tua password attuale per cambiarla.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Inserisci la tua password attuale per salvare le modifiche all\'e-mail.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Inserisci i dettagli del tuo account NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Inserisci il tuo nome utente o l\'e-mail dell\'account. NeoAgent invierà un collegamento di reimpostazione se può corrispondere all\'account.';

  @override
  String get enterYourUsernameOrEmail =>
      'Inserisci il tuo nome utente o la tua email.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entità: $arg1';
  }

  @override
  String get environment => 'Ambiente';

  @override
  String get error => 'Errore';

  @override
  String errorArg1(Object? arg1) {
    return '\nerrore: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Errori dal registro recente, raggruppati per messaggio.';

  @override
  String get errorsProblemsFailures => 'errori problemi fallimenti';

  @override
  String get eventTypesCommaSeparated => 'Tipi di eventi (separati da virgole)';

  @override
  String get every15Minutes => 'Ogni 15 minuti';

  @override
  String get every30Minutes => 'Ogni 30 minuti';

  @override
  String get everyAccountOnThisServerLoses =>
      'Ogni account su questo server perde questa chiave condivisa. Conti ';

  @override
  String get everyAccountOnThisServerUses =>
      'Ogni account su questo server utilizza questo indirizzo per ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Ogni sessione attiva per questo account termina. Possono accedere ';

  @override
  String get everyDay0800 => 'Tutti i giorni · 08:00';

  @override
  String get everyDay2000 => 'Tutti i giorni · 20:00';

  @override
  String get everyHour => 'Ogni ora';

  @override
  String get everyRunOnThisServerAll =>
      'Ogni esecuzione su questo server, sempre.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Ogni strumento sensibile richiede sempre l\'approvazione.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Tutti gli strumenti vengono eseguiti senza chiedere nulla, tranne quelli della persona ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Tutti in questi gruppi, canali o stanze possono parlare con $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Tutti in questo gruppo';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Tutto ciò che $arg1 ha disattivato per il tuo agente arriva ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Tutto il resto è spento.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Tutto è disponibile dal desktop.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Tutto ciò che l\'agente può utilizzare: integrazioni ufficiali, server MCP e competenze.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Tutto ciò che hai disattivato per $arg1 ritorna ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Le origini web esatte consentono di effettuare richieste multiorigine, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Esegui JavaScript all\'interno della sessione del browser.';

  @override
  String get execution => 'Esecuzione';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'I dettagli dell\'esecuzione non sono disponibili per questa esecuzione.';

  @override
  String get executionPlanCreated => 'Piano di esecuzione creato.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Sessioni di esercizi $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[esci $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Scade $arg1';
  }

  @override
  String get explainThisProject => 'Spiega questo progetto';

  @override
  String exploredArg1(Object? arg1) {
    return 'Esplorato $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Esplorato $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Esplorato l\'area di lavoro';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Esportazione non riuscita: $arg1';
  }

  @override
  String get exportLast5Messages => 'Esporta gli ultimi 5 messaggi';

  @override
  String get exportMyData => 'Esporta i miei dati';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'L\'avvio del browser esterno non è riuscito con il codice di uscita $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Il lancio del browser esterno non è supportato su questa piattaforma.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Timeout per l\'avvio del browser esterno.';

  @override
  String get externalMcpTools => 'Strumenti esterni e MCP';

  @override
  String get extraButtons => 'Pulsanti aggiuntivi';

  @override
  String get extractingTheNeoagentRuntime => 'Estrazione del runtime NeoAgent';

  @override
  String get failed => 'Fallito';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Impossibile connettersi: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Impossibile connettere $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Impossibile eliminare \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'impossibile recuperare';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Impossibile generare il prompt: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Impossibile avviare il browser esterno tramite url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Impossibile avviare il flusso OAuth.';

  @override
  String get failedToLoadPolicies => 'Impossibile caricare le policy';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Impossibile salvare: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Impossibile salvare il server MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Impossibile salvare la selezione: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Impossibile inviare la notifica al backend: $arg1';
  }

  @override
  String get fair => 'Giusto';

  @override
  String get fasterReplies => 'Risposte più veloci';

  @override
  String get fewerModelCalls => 'Meno chiamate di modelli';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'campo vuoto per ripristinare l\'impostazione predefinita integrata.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Il file supera il limite dell\'editor di 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Il file supera il limite di dimensione supportato.';

  @override
  String get fileWrites => 'Scritture di file';

  @override
  String get filename => 'Nome file';

  @override
  String get files => 'File';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'I file che NeoAgent scrive o modifica in questa sessione vengono visualizzati qui.';

  @override
  String get filesSavedByAllUsers => 'File salvati da tutti gli utenti';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Compila gli accessi approvati o autentica le richieste senza mostrare segreti all\'IA.';

  @override
  String get finalResponse => 'Risposta finale';

  @override
  String get findAPlatform => 'Trova una piattaforma';

  @override
  String get findAndFixABug => 'Trova e correggi un bug';

  @override
  String get findRecentChats => 'Trova le chat recenti';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Trovare il runtime NeoAgent corretto';

  @override
  String get finish => 'Finisci';

  @override
  String get finishAtTheScheduledTime => 'Termina all\'orario previsto';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Completa l\'accesso a $arg1 nel browser, quindi connettiti di nuovo.';
  }

  @override
  String get flowGraph => 'Grafico del flusso';

  @override
  String get flutterApp => 'Applicazione svolazzante';

  @override
  String get focusedExecutionProfile => 'Profilo di esecuzione mirato';

  @override
  String get folderIdOptional => 'ID cartella (facoltativo)';

  @override
  String get folderUnavailable => 'Cartella non disponibile';

  @override
  String get forExampleHttpsMatrixOrg => 'Ad esempio https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Per configurazioni di rete ospitate o avanzate';

  @override
  String get forLinksInEmailsBlankUses =>
      'Per i collegamenti nelle e-mail. Vuoto utilizza l\'URL pubblico del server.';

  @override
  String get forgotPassword => 'Ha dimenticato la password?';

  @override
  String get frameUnavailable => 'Cornice non disponibile';

  @override
  String freshnessArg1(Object? arg1) {
    return 'freschezza: $arg1';
  }

  @override
  String get fridays1700 => 'Venerdì · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Da BotFather dopo aver creato il bot.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'D\'ora in poi $arg1 decide quali strumenti può utilizzare il tuo agente. Loro ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Dal portale per sviluppatori Discord, sotto il tuo bot.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Dalla Console per sviluppatori LINE.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Dal client Matrix o dall\'account bot.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Da twitchapps.com/tmi o dalla tua app per sviluppatori Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Richiesta completa';

  @override
  String get fullSetup => 'Configurazione completa';

  @override
  String get general => 'Generale';

  @override
  String get generalSettings => 'Impostazioni generali';

  @override
  String get generalSettingsSaved => 'Impostazioni generali salvate.';

  @override
  String get generateAPromptForAnotherAi =>
      'Genera un prompt per un\'altra IA, incolla qui la risposta per importare i ricordi.';

  @override
  String get generatePrompt => 'Genera richiesta';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Errore di tracciamento del recinto geografico: $arg1';
  }

  @override
  String get getInspired => 'Lasciati ispirare';

  @override
  String get githubCopilot => 'Copilota GitHub';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot e Codice OpenAI';

  @override
  String get githubIssueOpened => 'Problema GitHub aperto';

  @override
  String get neorecallMemoryCreated => 'Memoria NeoRecall creata';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Il controllo della versione di GitHub non è riuscito con HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Il payload della versione GitHub non era un elenco di versioni.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Nome utente GitHub che ha aperto il problema';

  @override
  String get globalSecurityMode => 'Modalità di sicurezza globale';

  @override
  String get gmailMessageReceived => 'Messaggio Gmail ricevuto';

  @override
  String get good => 'Bene';

  @override
  String get goodAfternoon => 'Buon pomeriggio';

  @override
  String get goodEvening => 'Buonasera';

  @override
  String get goodMorning => 'Buongiorno';

  @override
  String get goodPasswordALittleMoreLength =>
      'Buona parola d\'ordine. Un po\' più di lunghezza lo rende più forte.';

  @override
  String get googleChat => 'GoogleChat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live utilizza la tua chiave API OpenAI, Gemini Live la tua chiave AI di Google. Le modifiche si applicano alla chiamata successiva.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Concedere le autorizzazioni di Health Connect prima della sincronizzazione.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Gruppo, canale o stanza';

  @override
  String get groupType => 'Tipo di gruppo';

  @override
  String get groupsAndChannels => 'Gruppi e canali';

  @override
  String groupsArg1(Object? arg1) {
    return 'Gruppi: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'I gruppi che $arg1 non ha ancora visto lo seguiranno.';
  }

  @override
  String get handlesDirectTasksItself =>
      'Gestisce autonomamente le attività dirette';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Vivavoce (parla liberamente, interrompi in qualsiasi momento)';

  @override
  String get headerName => 'Nome dell\'intestazione';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titoli sugli argomenti che ti interessano, filtrati in base al segnale.';

  @override
  String get health => 'Salute';

  @override
  String get healthChecks => 'Controlli sanitari';

  @override
  String get healthConnect => 'connessione sanitaria';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect non è disponibile su questo dispositivo.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Stato di sincronizzazione di Health Connect e metriche di backend archiviate.';

  @override
  String get healthStatusIsUnavailable =>
      'Lo stato di salute non è disponibile.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'La sincronizzazione della salute è disponibile solo su Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Record del cuore $arg1';
  }

  @override
  String get heldBack => 'Trattenuto';

  @override
  String get helper => 'Aiutante';

  @override
  String helperArg1(Object? arg1) {
    return 'Aiutante: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'qui. Revocare prima l\'amministratore con `neoagent admin revoke $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Valori più alti rendono NeoAgent più selettivo nei gruppi.';

  @override
  String get highlyRecommended => 'Altamente raccomandato';

  @override
  String get holdButton131ForTheAssistant =>
      'Tieni premuto il pulsante 131 per l\'assistente.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Tieni premuto Ctrl+Maiusc+Spazio per parlare';

  @override
  String get holdToTalk => 'Aspetta a parlare.';

  @override
  String get holdToTalk2 => 'Aspetta a parlare';

  @override
  String get home => 'Casa';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'È richiesto il token di accesso di lunga durata dell\'assistente domestico.';

  @override
  String get homeAssistantSetup => 'Configurazione dell\'assistente domestico';

  @override
  String get homeAssistantUrl => 'URL dell\'assistente domestico';

  @override
  String get homeAssistantUrlIsRequired =>
      'L\'URL dell\'assistente domestico è obbligatorio.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token del server domestico con polling della stanza';

  @override
  String get homeserverUrl => 'URL del server domestico';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'servizio ospitato). Le tue chiavi sono crittografate e utilizzabili solo da ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Nome host della rete IRC, ad esempio irc.libera.chat';

  @override
  String get hourly => 'Ogni ora';

  @override
  String get hourlyInboxCheck => 'Controllo orario della posta in arrivo';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Per quanto tempo i link di conferma rimangono validi.';

  @override
  String get howOftenThisAgentLooksFor =>
      'La frequenza con cui questo agente cerca nuovi messaggi nella stanza virtuale.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'La frequenza con cui questo agente cerca nuovi messaggi Signal.';

  @override
  String get howTeamsWork => 'Come funzionano i team';

  @override
  String get howThisServerIsReachedPlus =>
      'Come viene raggiunto questo server, oltre ai cambiamenti a livello di server.';

  @override
  String get httpsSessionCookie => 'cookie di sessione https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Non ho potuto completare la richiesta in questo momento. Per favore riprova tra poco.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inattivo';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Se $arg1 richiede un URL webhook, incollalo in modo che i messaggi possano raggiungere $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Se quell\'account ha un\'e-mail confermata, NeoAgent invierà un collegamento per la reimpostazione della password.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Se il servizio richiede un token sulle richieste in uscita.';

  @override
  String get ignoreGroups => 'Ignora gruppi';

  @override
  String get ignoreThisChat => 'Ignora questa chat';

  @override
  String get ignoredChannels => 'Canali ignorati';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Messaggio complementare desktop non valido ignorato: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Attuare il piano di cui sopra.';

  @override
  String get implementThisPlan => 'Implementa questo piano';

  @override
  String get implicitTls => 'TLS implicito';

  @override
  String get import => 'Importa';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Importazione non riuscita: $arg1';
  }

  @override
  String get importFromComputer => 'Importa dal computer';

  @override
  String get importMemoryTransfer => 'Importare il trasferimento di memoria?';

  @override
  String get importance => 'Importanza';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Memorie $arg1 importate, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'Nella squadra di @$arg1';
  }

  @override
  String get inBackground => 'sfondo';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'I messaggi del canale in entrata e in uscita appariranno qui.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Chiamate vocali in-app in entrata da NeoAgent';

  @override
  String get incomingMessages => 'Messaggi in arrivo';

  @override
  String get incomingNeoagentCall => 'Chiamata NeoAgent in arrivo';

  @override
  String get incomingNeoagentCall2 => 'CHIAMATA A NEOAGENT IN ARRIVO';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Supporto per webhook in entrata e richiamata in uscita';

  @override
  String get incorporatingSteering => 'Incorpora lo sterzo';

  @override
  String get input => 'Ingresso';

  @override
  String get inputMode => 'Modalità di ingresso';

  @override
  String get insertATemplate => 'Inserisci un modello';

  @override
  String get install => 'Installa';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installare un runtime firmato e autonomo. Node.js, npm, Git e i comandi del terminale non sono richiesti.';

  @override
  String get installApk => 'Installa l\'APK';

  @override
  String get installApkBundle => 'Installa APK/pacchetto';

  @override
  String get installApkClickOrDropA =>
      'Installa APK: fai clic o rilascia un file .apk';

  @override
  String get installNeoagent => 'Installa NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installa NeoAgent su questo computer senza terminale o connettiti a uno già in esecuzione.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installa le nuove versioni e scegli quale canale segue questo server.';

  @override
  String get installTheBackend => 'Installa il back-end';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installa il core con una configurazione opzionale aggiuntiva. Le chiavi del provider AI vengono aggiunte in seguito, come nel Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installa il secure core, quindi crea il tuo account. Aggiungi le chiavi del provider AI in seguito.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Installato: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Installato: $arg1 • Ultimo controllo: $arg2';
  }

  @override
  String get instructions => 'Istruzioni';

  @override
  String get integration => 'Integrazione';

  @override
  String get integrationConnections => 'Connessioni di integrazione';

  @override
  String get integrationSettingsSaved =>
      'Impostazioni di integrazione salvate.';

  @override
  String get integrations => 'Integrazioni';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrazioni/oauth/callback e registralo stesso ';

  @override
  String get interruptAi => 'Interrompi l\'IA';

  @override
  String get invalid2fa => '2fa non valido';

  @override
  String get invalidArgumentS => 'Argomenti non validi: ';

  @override
  String get invalidCredentials => 'credenziali non valide';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Manifesto runtime NeoAgent non valido.';

  @override
  String get inviteLink => 'Collegamento di invito';

  @override
  String get inviteLinkReady => 'Link di invito pronto';

  @override
  String get inviteLinks => 'Collegamenti di invito';

  @override
  String get iphoneApp => 'Applicazione per iPhone';

  @override
  String get issues => 'Problemi';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'I problemi vengono visualizzati una volta caricato il registro.';

  @override
  String get itCanTBeUndone => 'Non può essere annullato.';

  @override
  String get itMayHaveBeenDeleted => 'Potrebbe essere stato cancellato.';

  @override
  String get javaRuntime => 'tempo di esecuzione Java';

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
    return 'Iscritto a $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Iscritto negli ultimi 7 giorni';

  @override
  String get joiningATeam => 'Unirsi a una squadra';

  @override
  String get joiningIsOffHere => 'La partecipazione è disattivata qui';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Campo JSON che contiene il testo del messaggio. Di solito testo.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Campo JSON che identifica a chi è rivolto il messaggio.';

  @override
  String get jumpToLatest => 'Vai all\'ultimo';

  @override
  String get justNow => 'proprio adesso';

  @override
  String get keepNeoagentRunning => 'Mantenere NeoAgent in esecuzione?';

  @override
  String get keepRunning => 'Continua a correre';

  @override
  String get keepTaskRunning => 'Mantieni l\'attività in esecuzione';

  @override
  String get keepTheVaultAvailable => 'Mantieni il caveau disponibile';

  @override
  String get keepThisLauncherUpToDate => 'Mantieni aggiornato questo launcher.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Tieni questo pannello aperto finché la piattaforma non conferma la connessione.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Mantieni visibile il computer di questa sessione';

  @override
  String get keepTrackOfYourAiUsage =>
      'Tieni traccia del tuo utilizzo dell\'intelligenza artificiale. Vengono applicati limiti per garantire un utilizzo corretto su tutta la piattaforma.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Continua a utilizzare le tue app normalmente. NeoAgent funziona sulla stessa schermata e chiede ogni volta che è necessario un nuovo accesso.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Mantenere questo dispositivo connesso';

  @override
  String get key => 'Chiave';

  @override
  String get keyIsRequired => 'La chiave è obbligatoria.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Coppie chiave-valore che persistono nelle conversazioni.';

  @override
  String get knowledgeGraph => 'Grafico della conoscenza';

  @override
  String get knowledgeView => 'Vista della conoscenza';

  @override
  String get labelOnlyYouSeeIt => 'Etichetta (solo tu la vedi)';

  @override
  String get labelsOptional => 'Etichette (facoltative)';

  @override
  String get last24Hours => 'Ultime 24 ore';

  @override
  String get last7Days => 'Ultimi 7 giorni';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Ultimi 7 giorni: vengono eseguiti i token $arg1 in $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Ultimo $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Ultimo: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Ultima sincronizzazione non vuota · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Ultima corsa: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Visto l\'ultima volta $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Ultimo accesso $arg1';
  }

  @override
  String get lastSyncSummary => 'Riepilogo dell\'ultima sincronizzazione';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Ultimo utilizzo: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'L\'ultima finestra è terminata $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'successivamente si avvia anche spento.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Ultima corsa · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'L\'avvio di app desktop non è supportato su questa piattaforma.';

  @override
  String get learnRoomNorms => 'Impara le norme della stanza';

  @override
  String get leave => 'Lascia';

  @override
  String get leaveARedirectUriBlankTo =>
      'Lascia vuoto un URI di reindirizzamento per utilizzare <URL pubblico>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Lasciare la squadra di $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Lascia l\'impostazione predefinita a meno che tu non abbia personalizzato BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Lascia il token vuoto per mantenere il token attualmente memorizzato.';

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
    return 'Lascia che sia $arg1 a gestirmi';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Lascia che tutti in questo gruppo parlino con $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Lascia che funzioni\nmentre tu no.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Lascia che NeoAgent faccia clic, digiti e si sposti tra le tue app.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Lascia che NeoAgent capisca cosa è visibile sul tuo schermo.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Lascia che qualcuno con cui lavori decida quali strumenti può utilizzare il tuo agente ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Consenti a questa persona di inviare a $arg1 un messaggio uno a uno.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Lascia che questa persona parli con $arg1 qui, ma non in chat private o altri gruppi.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Consenti a questa persona di parlare con $arg1 nelle chat private e in qualsiasi gruppo condivida.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Livello $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Collegamento $arg1';
  }

  @override
  String get linkCopied => 'Collegamento copiato';

  @override
  String get linkExpiresAfter => 'Il collegamento scade dopo';

  @override
  String get linkLifetimeHours => 'Durata del collegamento (ore)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'La durata del collegamento deve essere compresa tra 1 e 8760 ore.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link valido fino al $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Provider di accesso collegati';

  @override
  String get linuxApp => 'Applicazione Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Inserito $arg1/';
  }

  @override
  String get listening => 'Ascolto';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Cronologia delle esecuzioni in tempo reale, passaggi dello strumento e risposte.';

  @override
  String get liveModel => 'Modello dal vivo';

  @override
  String get liveModelProvider => 'Fornitore di modelli dal vivo';

  @override
  String get liveRun => 'Corsa dal vivo';

  @override
  String get liveVoice => 'Voce dal vivo';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'La connessione vocale dal vivo non è disponibile.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'La connessione vocale dal vivo è stata chiusa.';

  @override
  String get liveVoiceDefaults =>
      'Impostazioni predefinite per la voce dal vivo';

  @override
  String get liveVoiceFailed => 'La voce dal vivo non è riuscita.';

  @override
  String get llmMemoryExportResponse =>
      'Risposta di esportazione della memoria LLM';

  @override
  String get loadFailed => 'caricamento non riuscito';

  @override
  String get loadingExecutionDetails =>
      'Caricamento dei dettagli di esecuzione...';

  @override
  String get loadingNeoagent => 'Caricamento di NeoAgent';

  @override
  String get loadingRunFlow => 'Caricamento flusso di esecuzione…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Gli URL di rete locale e privata sono supportati quando il server NeoAgent può raggiungerli. L\'audio non viene mai esposto a NeoAgent.';

  @override
  String get localApp => 'app locale';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'L\'installazione del backend locale non è disponibile su questa piattaforma.';

  @override
  String get localBaseImagePath => 'Percorso dell\'immagine di base locale';

  @override
  String get localComputerControlIsAvailableIn =>
      'Il controllo del computer locale è disponibile nell\'app desktop NeoAgent su macOS, Windows e Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Il controllo del computer locale non è disponibile qui.';

  @override
  String get localModelsUrl => 'URL dei modelli locali';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Il rilevamento locale di NeoAgent è temporaneamente non disponibile.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Preferenze locali per l\'applicazione NeoAgent. Il controllo del computer avviene sempre attraverso il computer cloud unificato.';

  @override
  String get localSetup => 'IMPOSTAZIONE LOCALE';

  @override
  String get locationCityOrPlace => 'Posizione (città o luogo)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'La posizione è obbligatoria per l\'attivazione di eventi meteorologici';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inizializzazione LocationService non riuscita: $arg1';
  }

  @override
  String get logCopied => 'Registro copiato';

  @override
  String get loginPassword => 'Password di accesso';

  @override
  String get logout => 'Esci';

  @override
  String get logs => 'Registri';

  @override
  String get logsCopied => 'Registri copiati.';

  @override
  String get logsOnThisComputer => 'Accede a questo computer';

  @override
  String get longLivedAccessToken => 'Token di accesso di lunga durata';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Richiamo a lungo termine, fatti strutturati e grafico della conoscenza.';

  @override
  String get lookedAtTheScreen => 'Guardò lo schermo';

  @override
  String get lookingOnThisComputerAndYour =>
      'Guardando su questo computer e sulla tua rete locale...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Guarda avanti agli incontri di domani perché nulla ti sorprenda.';

  @override
  String get loopExecution => 'Esecuzione del ciclo';

  @override
  String get loopPaused => 'Ciclo in pausa';

  @override
  String get macOsX => 'mac osx';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'L\'accessibilità macOS non è concessa a NeoAgent. Consentilo in Impostazioni di sistema > Privacy e sicurezza > Accessibilità.';

  @override
  String get macosApp => 'applicazione macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'La registrazione dello schermo macOS non è concessa a NeoAgent. Consentilo in Impostazioni di sistema › Privacy e sicurezza › Registrazione schermo, quindi riapri NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'I server di posta che necessitano di una password si rifiuteranno di inviare fino a una nuova ';

  @override
  String get main => 'Principale';

  @override
  String get makeDefault => 'Rendi predefinito';

  @override
  String get manage => 'Gestisci';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Gestisci l\'e-mail del tuo account, l\'autenticazione a due fattori e le sessioni attive.';

  @override
  String get managedBy => 'Gestito da';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'I manager possono avere manager propri (fino a quattro livelli). A ';

  @override
  String get managing => 'Gestire';

  @override
  String get manualDestination => 'Destinazione manuale';

  @override
  String get manualTrigger => 'Attivazione manuale';

  @override
  String get masterPassword => 'Parola d\'ordine principale';

  @override
  String get matchThisDevice => 'Abbina questo dispositivo';

  @override
  String get matchedAgainstTitleAndBody => 'Confrontato con titolo e corpo';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Corrisponde al vecchio flusso MCP NeoAgent: URL più metodo di autenticazione.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'server MCP';

  @override
  String get mcpServer2 => 'Server MCP';

  @override
  String get mcpServerUrl => 'URL del server MCP';

  @override
  String get mcpServers => 'server MCP';

  @override
  String get meantForSomeoneElse => 'Destinato a qualcun altro';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Costo del modello misurato: $arg1';
  }

  @override
  String get memories => 'Ricordi';

  @override
  String get memory => 'Memoria';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memoria: $arg1';
  }

  @override
  String get memoryInjected => 'Memoria iniettata';

  @override
  String get mentionOrReplyOnly => 'Solo menzionare o rispondere';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Log del server e di runtime Flutter uniti per questa sessione dell\'app.';

  @override
  String get messageBodyTemplateJson =>
      'Modello del corpo del messaggio (JSON)';

  @override
  String get messageNeedsAccess => 'Il messaggio richiede l\'accesso';

  @override
  String get messageTextField => 'Campo testo messaggio';

  @override
  String get messaging => 'Messaggistica';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Eventi push ed webhook dell\'API di messaggistica';

  @override
  String get messagingConnectionNeedsAttention =>
      'La connessione di messaggistica richiede attenzione';

  @override
  String get messagingConnections => 'Connessioni di messaggistica';

  @override
  String get messagingDelivery => 'Consegna dei messaggi';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Errore di messaggistica. Per favore riprova.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'L\'acquisizione del microfono si è interrotta inaspettatamente. Riprova.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Errore del microfono: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Microfono disattivato. Tocca per riattivare l\'audio.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Per la voce dal vivo è necessaria l\'autorizzazione del microfono.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Valore minimo del contributo: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'La configurazione del dispositivo mobile non è riuscita.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'La configurazione mobile non è riuscita perché Java non è disponibile sulla macchina che esegue NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'La configurazione mobile non è riuscita perché Java non è disponibile sulla macchina che esegue NeoAgent. Installa un JDK e riprova.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'La configurazione del dispositivo mobile non è riuscita. Verifica che gli strumenti Android siano installati correttamente e riprova.';

  @override
  String modeArg1(Object? arg1) {
    return 'modalità: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'La modalità si blocca mentre è attiva una corsa.';

  @override
  String get model => 'Modello';

  @override
  String modelArg1(Object? arg1) {
    return 'Modello: $arg1';
  }

  @override
  String get modelAvailability => 'Disponibilità del modello';

  @override
  String get modelAvailabilitySaved => 'Disponibilità del modello salvata.';

  @override
  String get modelForThisSession => 'Modello per questa sessione';

  @override
  String get modelOverride => 'Sostituzione del modello';

  @override
  String get modelPending => 'Modello in attesa';

  @override
  String get modelTurn => 'Giro del modello';

  @override
  String get modelTurnCompleted => 'Turno del modello completato';

  @override
  String get modelTurnStarted => 'È iniziata la svolta del modello';

  @override
  String get modelVisibilityHideShowList =>
      'visibilità del modello nascondi mostra elenco';

  @override
  String get models => 'Modelli';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modelli, comportamento, voce e spazio di lavoro';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modelli, browser, voce, diagnostica...';

  @override
  String get modelsRouting => 'Modelli e percorsi';

  @override
  String get monthly => 'Mensile';

  @override
  String get moreActions => 'Più azioni';

  @override
  String get morningBriefing => 'Briefing mattutino';

  @override
  String get mostUsedAgents => 'Agenti più utilizzati';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Modelli più utilizzati negli ultimi $arg1.';
  }

  @override
  String get mouseKeyboard => 'Mouse e tastiera';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove non è supportato su questa piattaforma.';

  @override
  String get mustBeReachableOnThePublic =>
      'Deve essere raggiungibile sull\'Internet pubblica: locale e ';

  @override
  String get n24Hours => '24 ore';

  @override
  String get n2faOrRecoveryCode => '2FA o codice di ripristino';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA richiede la configurazione di SESSION_SECRET su questa distribuzione NeoAgent.';

  @override
  String get n30Days => '30 giorni';

  @override
  String get n365Days => '365 giorni';

  @override
  String get n4HourLimitTokens => 'Limite di 4 ore (token)';

  @override
  String get n4HourUsage => 'Utilizzo di 4 ore';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Limite di 4 ore $arg1';
  }

  @override
  String get n7DayUsage => 'Utilizzo di 7 giorni';

  @override
  String get n7Days => '7 giorni';

  @override
  String get n90Days => '90 giorni';

  @override
  String get name => 'Nome';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnome: Nuova abilità\ndescription: Descrivi cosa fa questa abilità\n---\nScrivi qui le istruzioni per questa abilità.\n';

  @override
  String get nameOfWhoeverMadeIt => 'nome di chi l\'ha realizzato.';

  @override
  String get nameOptional => 'Nome (facoltativo)';

  @override
  String get nativeAndWebhookChannels => 'Canali nativi e webhook';

  @override
  String get naturalBubbles => 'Bolle naturali';

  @override
  String get nearbyNeoagentServers => 'Server NeoAgent nelle vicinanze';

  @override
  String get needANewAccountRegister =>
      'Hai bisogno di un nuovo account? Registrati';

  @override
  String get needAnIdea => 'Hai bisogno di un\'idea?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'È necessario rispondere · $arg1% per parlare';
  }

  @override
  String get needsAttention => 'Ha bisogno di attenzione';

  @override
  String get needsInput => 'Ha bisogno di input';

  @override
  String get neoagentApp => 'Applicazione NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgente, $arg1';
  }

  @override
  String get neoagentAssistant => 'Assistente NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent non è riuscito a verificare il runtime di backend disponibile.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent non è riuscito a completare la configurazione locale.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent non è riuscito a completare la configurazione locale. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informazioni di debug di NeoAgent';

  @override
  String get neoagentDesktopInstaller =>
      'Programma di installazione desktop di NeoAgent';

  @override
  String get neoagentFlutterUpdater => 'Aggiornamento di NeoAgent Flutter';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installa l\'ultimo $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent è installato e in esecuzione.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent non è installato su questo computer.';

  @override
  String get neoagentIsReady => 'NeoAgent è pronto';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent sta ancora lavorando su un\'attività. Termina la chiamata e ottieni il risultato in chat oppure annulla anche l\'attività.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent sta trasformando la tua dimostrazione in un flusso di lavoro adattabile.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent è in attesa mentre usi il desktop.';

  @override
  String get neoagentIsWorking => 'NeoAgent sta funzionando';

  @override
  String get neoagentLinuxComputer => 'Computer NeoAgent Linux';

  @override
  String get neoagentNeedsADecision =>
      'IL NEOAGENT HA BISOGNO DI UNA DECISIONE';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'I download del runtime di NeoAgent richiedono un indirizzo sicuro.';

  @override
  String get neoagentServerAddress => 'Indirizzo del server NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'L\'e-mail del servizio NeoAgent non è pronta. Chiedere all\'operatore del server di verificare le impostazioni dell\'ambiente di posta elettronica.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Impossibile completare la configurazione di NeoAgent.';

  @override
  String get neoagentUser => 'Utente NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent utilizza questo computer automaticamente e chiede prima di utilizzare lo schermo, il mouse, la tastiera, i file o la riga di comando.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent utilizza la tua posizione approssimativa in background per attivare promemoria di geofence (ad esempio \"Ricordami di comprare il latte quando passo davanti al supermercato\").\n\n';

  @override
  String get neoagentWorkspace => 'Area di lavoro NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag] [$arg1] [stack] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'URL del back-end NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'L\'URL del backend NeoRecall è obbligatorio.';

  @override
  String get neorecallSetup => 'Configurazione NeoRecall';

  @override
  String get networkRequestFailed => 'richiesta di rete non riuscita';

  @override
  String get networkWriteRequests => 'Richieste di scrittura in rete';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'non viene mai conteggiato nei limiti di utilizzo condiviso.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'I nuovi account confermano il proprio indirizzo email prima di accedere.';

  @override
  String get newAccountsPerDay => 'Nuovi account al giorno';

  @override
  String get newChat => 'Nuova chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'I nuovi gruppi restano silenziosi a meno che qualcuno non tagghi $arg1, finché non li attivi.';
  }

  @override
  String get newLink => 'Nuovo collegamento';

  @override
  String get newPasswordsDoNotMatch => 'Le nuove password non corrispondono.';

  @override
  String get newRecoveryCodes => 'Nuovi codici di ripristino';

  @override
  String get newSession => 'Nuova sessione';

  @override
  String get newSessionN => 'Nuova sessione (⌘N)';

  @override
  String get newSessionWithSameSetup =>
      'Nuova sessione con la stessa configurazione';

  @override
  String get newSkill => 'Nuova abilità';

  @override
  String get newSkill2 => 'Nuova abilità';

  @override
  String get newThisWeek => 'Novità questa settimana';

  @override
  String get newsDigest => 'Raccolta di notizie';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Prossimo tentativo: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Flusso di accesso a Nextcloud';

  @override
  String get nextcloudSetup => 'Configurazione di Nextcloud';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'URL di Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'L\'URL di Nextcloud è obbligatorio.';

  @override
  String get nickname => 'Soprannome';

  @override
  String get noAccountsConnectedYet => 'Nessun account ancora collegato.';

  @override
  String get noAccountsFound => 'Nessun account trovato.';

  @override
  String get noActiveSessionsFound => 'Nessuna sessione attiva trovata.';

  @override
  String get noAgentsYet => 'Nessun agente ancora';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nessun provider AI è configurato, quindi chat e messaggistica ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Nessuna richiesta di approvazione: l\'agente viene eseguito senza interruzioni.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Nessuna risorsa di rilascio $arg1 corrispondeva a questa piattaforma.';
  }

  @override
  String get noArguments => '(senza argomenti)';

  @override
  String get noAuth => 'Nessuna autenticazione';

  @override
  String get noBindingsYet => 'Ancora nessun legame.';

  @override
  String get noChangesYet => 'Nessuna modifica ancora';

  @override
  String get noChannelsFound => 'Nessun canale trovato';

  @override
  String get noCloudComputerSlotIsFree =>
      'Nessuno slot per computer cloud è libero in questo momento. Riprova tra un attimo.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Ancora nessuna voce nella memoria principale.';

  @override
  String get noDescription => 'Nessuna descrizione';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Al momento non sono disponibili display desktop.';

  @override
  String get noDetailAvailable => 'Nessun dettaglio disponibile';

  @override
  String get noDetailedSyncSummaryYet =>
      'Nessun riepilogo dettagliato della sincronizzazione ancora.';

  @override
  String get noDetailsCaptured => 'Nessun dettaglio catturato.';

  @override
  String get noEmailLinked => 'Nessuna e-mail collegata';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nessun provider di accesso esterno collegato.';

  @override
  String get noGroupMessagesYet => 'Nessun messaggio di gruppo ancora';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Nessuna persona specifica del gruppo è stata ancora aggiunta.';

  @override
  String get noGroupsAddedYet => 'Nessun gruppo ancora aggiunto.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Nessun gruppo ancora trovato. Dopo che $arg1 vede un messaggio di gruppo, utilizza Trova le chat recenti e verranno visualizzate qui.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Nessun gruppo ancora trovato. Dopo che $arg1 vede un messaggio di gruppo, utilizza Trova chat recenti.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nessun payload di dati sanitari restituito.';

  @override
  String get noHealthSamplesStoredYet =>
      'Nessun campione sanitario ancora archiviato.';

  @override
  String get noHttpClientImplementationForThis =>
      'Nessuna implementazione client HTTP per questa piattaforma.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Nessun input o output è stato registrato per questo passaggio.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Nessuna integrazione corrisponde a questa ricerca.';

  @override
  String get noLimit => 'Nessun limite';

  @override
  String get noLocalPasswordIsSetYet =>
      'Nessuna password locale è stata ancora impostata. Creane uno per abilitare l\'accesso con nome utente/password.';

  @override
  String get noLogEntries => 'Nessuna voce di registro.';

  @override
  String get noMatchingSettings => 'Nessuna impostazione corrispondente';

  @override
  String get noMcpServersMatchThisSearch =>
      'Nessun server MCP corrisponde a questa ricerca.';

  @override
  String get noMemoryEntriesFound => 'Nessuna voce di memoria trovata.';

  @override
  String get noMemorySync => 'Nessuna sincronizzazione della memoria';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Legge una sola volta la posta importante e inviata degli ultimi 12 mesi, così l\'agente conosce i tuoi contatti e progetti.';

  @override
  String get emailMemory => 'Memoria email';

  @override
  String get importNow => 'Importa ora';

  @override
  String get importOnConnect =>
      'Importa la posta passata quando colleghi un account';

  @override
  String get sweepStarting => 'Preparazione…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Lettura email · $done di $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Lettura email · $count trovate';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Apprendimento dalle email · $done di $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Ultima importazione: $emails email · $memories nuovi ricordi';
  }

  @override
  String get sweepNothingNew => 'Nessuna nuova email da importare';

  @override
  String sweepFailed(String error) {
    return 'Importazione non riuscita: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Nessun modello corrisponde a \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Per questa corsa non è stata registrata alcuna richiesta di modello.';

  @override
  String get noModelsDiscoveredYet => 'Nessun modello ancora scoperto';

  @override
  String get noModelsSelected => 'Nessun modello selezionato';

  @override
  String get noModelsYet => 'Nessun modello ancora';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'nessun account neoagent è collegato a questo fornitore';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Per questo computer non è disponibile alcun runtime backend NeoAgent.';

  @override
  String get noNetworkConnection => 'Nessuna connessione di rete';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Nessuna connessione di rete. Connettiti per continuare a utilizzare NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Nessuna connessione di rete. Riconnettiti per verificare la presenza di aggiornamenti.';

  @override
  String get noOne => 'Nessuno';

  @override
  String get noOneAddedYet => 'Nessuno ha ancora aggiunto.';

  @override
  String get noOneCanMessage => 'Nessuno può inviare messaggi';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Non è stato trovato nessun altro server NeoAgent. Puoi effettuare nuovamente la ricerca o inserire un indirizzo manualmente.';

  @override
  String get noPeopleAddedYet => 'Nessuna persona ancora aggiunta.';

  @override
  String get noPlatformsMatch => 'Nessuna piattaforma corrisponde';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Nessun provider è ancora disponibile per la configurazione.';

  @override
  String get noRecentChannelActivity => 'Nessuna attività recente sul canale';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Nessun risultato per \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Nessuna corsa in questo intervallo.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nessuna esecuzione corrisponde a questi filtri';

  @override
  String get noRunsYet => 'Nessuna corsa ancora';

  @override
  String get noRunsYet2 => 'Nessuna corsa ancora.';

  @override
  String get noSecurityKeyWasProvided =>
      'Non è stata fornita alcuna chiave di sicurezza.';

  @override
  String get noServerUrlSet => 'Nessun URL del server impostato';

  @override
  String get noSessionMatchesThatSearch =>
      'Nessuna sessione corrisponde a quella ricerca.';

  @override
  String get noSessionsYet => 'Nessuna sessione ancora';

  @override
  String get noSkillsMatchTheseFilters =>
      'Nessuna competenza corrisponde a questi filtri.';

  @override
  String get noStepsWereRecordedForThis =>
      'Nessun passo è stato registrato per questa corsa.';

  @override
  String get noSummaryAvailable => 'Nessun riepilogo disponibile.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Nessuna attività per $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Nessuno strumento corrisponde a \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Nessun aggiornamento in esecuzione';

  @override
  String get noUsageYet => 'Nessun utilizzo ancora.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Non è ancora disponibile alcun runtime backend NeoAgent verificato.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nessuno potrà più usarlo. Persone che hanno già aderito ';

  @override
  String get none => 'Nessuno';

  @override
  String get notApprovedYet => 'non ancora approvato';

  @override
  String get notAuthenticated => 'non autenticato';

  @override
  String get notCheckedYet => 'Non ancora controllato';

  @override
  String get notConfigured => 'Non configurato';

  @override
  String get notConnected => 'Non connesso';

  @override
  String get notConnected2 => 'Non connesso';

  @override
  String get notInstalled => 'Non installato';

  @override
  String get notNeeded => 'Non necessario';

  @override
  String get notNeededEnough => 'Non abbastanza necessario';

  @override
  String get notNow => 'Non ora';

  @override
  String get notNow2 => 'Non adesso';

  @override
  String get notSet => 'Non impostato';

  @override
  String get notSetUp => 'Non impostato';

  @override
  String get notTheSameAsAdmin => 'Non è la stessa cosa dell\'amministratore';

  @override
  String get nothingFound => 'Niente trovato';

  @override
  String get nothingHereYet => 'Niente qui ancora.';

  @override
  String get nothingHereYet2 => 'Niente qui ancora';

  @override
  String get nothingMatches => 'Niente corrisponde';

  @override
  String get nothingStoredYet => 'Niente ancora memorizzato.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Nozione, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID cliente OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'Chiave API di reindirizzamento segreto dell\'ID client oauth';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth client id reindirizzamento segreto unità calendario Gmail';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Il lancio di OAuth non è supportato su questa piattaforma.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'Segreto dell\'ID client del tenant di Outlook di OAuth';

  @override
  String get oauthToken => 'Token OAuth';

  @override
  String get oauthWithPkce => 'OAuth con PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'di $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'di suo. Non verrà mai più visualizzato dopo il salvataggio.';

  @override
  String get off => 'Disattivo';

  @override
  String get officialIntegration => 'Integrazione ufficiale';

  @override
  String get officialIntegrationDidNotReturnA =>
      'L\'integrazione ufficiale non ha restituito un URL di connessione.';

  @override
  String get on => 'Attivo';

  @override
  String get onASignedInAndroidDevice =>
      'Su un dispositivo Android su cui è stato effettuato l\'accesso, apri Impostazioni › Accesso e sicurezza, scansiona questo codice e approva l\'accesso.';

  @override
  String get onByDefaultForNewGroups =>
      'Attivo per impostazione predefinita per i nuovi gruppi';

  @override
  String get onDemand => 'Su richiesta';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Acceso per $arg1 dei gruppi $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'su. Possono unirsi nuovamente solo con un nuovo collegamento di invito.';

  @override
  String get onYourOwnTheDefault => 'Da solo (impostazione predefinita)';

  @override
  String get once => 'Una volta';

  @override
  String get oneIsSavedOtherChangesIn =>
      'uno è salvato. Vengono salvate anche le altre modifiche in questo modulo.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Uno o più account sono scaduti. Ricollega l\'account interessato per ripristinare l\'accesso allo strumento.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Un runtime controlla la persona, i turni di gruppo, la memoria della stanza, le norme, la teoria della mente e la consegna.';

  @override
  String get oneTimeRun => 'Corsa una tantum';

  @override
  String get onlyApkOrApksFilesCan =>
      'È possibile installare solo file .apk o .apks.';

  @override
  String get onlyInThisGroup => 'Solo in questo gruppo';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Necessario solo se il servizio richiede intestazioni HTTP aggiuntive.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Necessario solo se vuoi rimodellare il carico utile in uscita.';

  @override
  String get onlyTheyCanChangeIt => 'Solo loro possono cambiarlo.';

  @override
  String get open => 'Apri';

  @override
  String get openAccountSettingsOnASigned =>
      'Apri Impostazioni › Accesso e sicurezza su un dispositivo Android su cui hai effettuato l\'accesso, scansiona questo codice e approva l\'accesso.';

  @override
  String get openComputer => 'Apri il computer';

  @override
  String get openDashboard => 'Apri il cruscotto';

  @override
  String get openFolder => 'Apri cartella...';

  @override
  String get openInWorkbench => 'Aperto nel banco di lavoro';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Apri NeoAgent e ricollega $arg1 per ripristinare la messaggistica.';
  }

  @override
  String get openTimeSettings => 'Apri le impostazioni dell\'ora';

  @override
  String get openToAnyone => 'Aperto a chiunque';

  @override
  String get openTrello => 'Apri Trello';

  @override
  String get openVoiceAssistant => 'Apri l\'assistente vocale';

  @override
  String get openWiFiSettings => 'Apri le impostazioni Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Apri con l\'app predefinita';

  @override
  String get openaiCodex => 'Codice OpenAI';

  @override
  String get openaiCompatible => 'compatibile con openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Endpoint compatibile con OpenAI (il tuo server o un altro ';

  @override
  String openedArg1(Object? arg1) {
    return '$arg1 aperto';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'L\'apertura degli URL desktop non è supportata su questa piattaforma.';

  @override
  String get openingYourSavedDesktop => 'Apertura del desktop salvato.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Apertura del desktop salvato. Gli avviamenti normali richiedono meno di 10 secondi.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Segreto aggiuntivo facoltativo se proteggi il webhook in entrata.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Override facoltativo se l\'URL del webhook non è sufficiente.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Segreto facoltativo per verificare gli eventi di chat in arrivo.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Segreto facoltativo per verificare gli eventi in entrata.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Segreto facoltativo per verificare gli eventi iMessage in arrivo.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Segreto facoltativo per verificare gli eventi LINE in entrata.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Segreto facoltativo per verificare gli eventi Mattermost in arrivo.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Segreto facoltativo per verificare gli eventi di Teams in arrivo.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Facoltativo. L\'agente ha già una propria personalità. Tutto ciò che aggiungi sul tono viene sovrapposto ad esso, quindi non devi mai definirne uno.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Facoltativo. Se impostato, viene utilizzato al posto dell\'URL.';

  @override
  String get orAnswerInYourOwnWords => 'Oppure rispondi con parole tue';

  @override
  String get orBuildYourOwnTask => 'Oppure crea il tuo compito';

  @override
  String get orContinueWith => 'o continuare con';

  @override
  String get orFiles => 'o file.';

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
  String get originNotAllowed => 'origine non consentita';

  @override
  String get outgoingMessage => 'Messaggio in uscita';

  @override
  String get outgoingWebhookUrl => 'URL del webhook in uscita';

  @override
  String get outlookEmailReceived => 'E-mail di Outlook ricevuta';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Sovrascrivi le note sul comportamento dall\'importazione.';

  @override
  String get ownModel => 'proprio modello';

  @override
  String get packageName => 'Nome del pacchetto';

  @override
  String get pairWithQrCode => 'Accoppia con il codice QR';

  @override
  String get password => 'Password';

  @override
  String get password2faAndActiveSessions => 'Password, 2FA e sessioni attive';

  @override
  String get passwordCreated => 'Password creata.';

  @override
  String get passwordIsTooWeak => 'la password è troppo debole';

  @override
  String get passwordMin8 => 'parola d\'ordine minimo 8';

  @override
  String get passwordOrApiKey => 'Password o chiave API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Sicurezza della password: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Le password non corrispondono.';

  @override
  String get pasteAKey => 'Incolla una chiave.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Incolla una nuova chiave per sostituire $arg1';
  }

  @override
  String get pasteTheKey => 'Incolla la chiave';

  @override
  String get pasteYourAccountToken => 'Incolla il token del tuo account';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Incolla la tua chiave API $arg1 di seguito. Lo è ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Il percorso deve rimanere all\'interno dell\'area di lavoro NeoAgent.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Il percorso deve rimanere all\'interno della cartella dell\'area di lavoro.';

  @override
  String get pauseLiveUpdates =>
      'Metti in pausa gli aggiornamenti in tempo reale';

  @override
  String get pauseTaskLoop => 'Metti in pausa il ciclo delle attività';

  @override
  String get paused => 'In pausa';

  @override
  String peakArg1(Object? arg1) {
    return 'picco $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Persone nelle chat private';

  @override
  String get perAccountRateLimits => 'Limiti di tasso per account';

  @override
  String get perCategoryPermissions => 'Autorizzazioni per categoria';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Policy di autorizzazione per strumento, gate di approvazione e isolamento dei processi per l\'esecuzione della shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Autorizzazione richiesta: $arg1';
  }

  @override
  String get permissionsNeeded => 'Autorizzazioni necessarie';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Autorizzazioni. Nessun altro può cambiarlo.';

  @override
  String get personOrChat => 'Persona o chat';

  @override
  String get personaBehaviorNotes => 'Note sul comportamento delle persone';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Token di accesso personale per il bot Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Canali personali e superfici di supporto diretto.';

  @override
  String get personalSelfChat => 'Chat personale';

  @override
  String get phoneNumber => 'Numero di telefono';

  @override
  String get pickARunFromTheList =>
      'Scegli una corsa dall\'elenco per visualizzarne i passaggi.';

  @override
  String get pickARunFromTheList2 =>
      'Scegli una corsa dall\'elenco a sinistra per esplorarne il flusso.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Scegli dalle chat $arg1 recenti oppure aggiungi tu stesso una persona o un gruppo.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Scegli come $arg1 utilizza questo account.';
  }

  @override
  String get pickOneToFillInThe =>
      'Scegline uno per completare l\'attività. Puoi modificare tutto in seguito.';

  @override
  String get picksUpWhereYouLeftOff => 'Riprende da dove eri rimasto';

  @override
  String get plan => 'Piano';

  @override
  String get planning => 'Pianificazione';

  @override
  String get platform => 'Piattaforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Piattaforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Scegli un programma.';

  @override
  String get pleaseEnterAFilename => 'Inserisci un nome file.';

  @override
  String get pleaseEnterAKey => 'Inserisci una chiave.';

  @override
  String get pleaseEnterAPrompt => 'Inserisci una richiesta.';

  @override
  String get pleaseEnterATaskName => 'Inserisci un nome per l\'attività.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Inserisci il contenuto della memoria.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Inserisci quando deve essere eseguita l\'attività.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Seleziona un account o inserisci un ID di connessione valido.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Indica NeoAgent a qualsiasi completamento chat compatibile con OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Punta la fotocamera verso il codice mostrato sul dispositivo disconnesso. L\'approvazione rimane su questo telefono.';

  @override
  String get port => 'Porto';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'porta node_env URL pubblico trust proxy distribuzione dei cookie sicuri';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Automazione premium con pianificazione e trigger di integrazione.';

  @override
  String get prepareQrCode => 'Preparare il codice QR';

  @override
  String get preparingNeoagent => 'Preparazione di NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Preparazione di NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Tieni premuto per una cattura rapida';

  @override
  String get pressKeysIsNotSupportedOn =>
      'la pressione dei tasti non è supportata su questa piattaforma.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Premuto $arg1';
  }

  @override
  String get priceUnknown => 'Prezzo sconosciuto';

  @override
  String get primaryDisplay => 'Visualizzazione principale';

  @override
  String get privateChat => 'Chatta privata';

  @override
  String get privateChats => 'Chat private';

  @override
  String get privateChats2 => 'chat private';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Chat private: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Chat private $arg1 · gruppi $arg2';
  }

  @override
  String get privateChatsOnly => 'Solo chat private';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'gli indirizzi di rete privata non sono consentiti.';

  @override
  String get profileEmailAndPersonalData => 'Profilo, email e dati personali';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Richiedi conferma prima che NeoAgent rimanga residente nella barra delle applicazioni.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Cache dei prompt: token memorizzati nella cache $arg1 ';
  }

  @override
  String get promptCopied => 'Richiesta copiata.';

  @override
  String get promptOrSchedule => 'prompt o pianificazione.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Richiedi di incollare in un\'altra IA';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Impossibile avviare il collegamento del provider.';

  @override
  String get providerSignInCouldNotBe =>
      'Impossibile avviare l\'accesso del fornitore.';

  @override
  String get providers => 'Fornitori';

  @override
  String get providersEachAccountCanStillPick =>
      'Fornitori; ogni account può comunque scegliere il proprio modello in Impostazioni. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Provider, integrazioni, funzionalità vocali e opzionali possono essere completati da Impostazioni in qualsiasi momento.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Discussioni su problemi pubblici e richieste pull, risposte solo per le persone approvate.';

  @override
  String get publicUrl => 'URL pubblico';

  @override
  String get publicUrlAndAllowedOrigins => 'URL pubblico e origini consentite';

  @override
  String get publicUrlOverride => 'Sostituzione dell\'URL pubblico';

  @override
  String get pullsTogetherTheDayAhead => 'Mette insieme la giornata a venire';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Collegamento telefonico basato su QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Accesso QR completato, ma NeoAgent non è riuscito a mantenere la sessione. Per favore riprova.';

  @override
  String get qrLoginCouldNotBeStarted => 'Impossibile avviare l\'accesso QR.';

  @override
  String get qrLoginRequestHasExpired => 'La richiesta di accesso qr è scaduta';

  @override
  String get qrLoginRequestWasNotFound =>
      'La richiesta di accesso qr non è stata trovata';

  @override
  String get qrPairing => 'Associazione QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'vengono eseguite le query; tutto ciò che scrive viene rifiutato.';

  @override
  String get queryFilter => 'Interroga/Filtra';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'In coda come timone per la corsa corrente: $arg1';
  }

  @override
  String get quickstart => 'Avvio rapido';

  @override
  String get quit => 'Esci';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'inizio_pioggia, avviso_vento';

  @override
  String get ranAScriptInThePage => 'Ha eseguito uno script nella pagina';

  @override
  String ranArg1(Object? arg1) {
    return 'Corse $arg1';
  }

  @override
  String get rateLimits => 'Limiti di tariffa';

  @override
  String get readAnArtifact => 'Leggere un artefatto';

  @override
  String get readAndEditFilesInsideYour =>
      'Leggere e modificare i file all\'interno della cartella NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Leggi $arg1';
  }

  @override
  String get readError => 'Errore di lettura';

  @override
  String get readFiles => 'Leggere file';

  @override
  String get readOnly => 'Sola lettura';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Leggi la cartella e riepiloga lo stack, i punti di ingresso e come eseguirlo.';

  @override
  String get readThePage => 'Leggi la pagina';

  @override
  String get readTheUiTree => 'Leggi l\'albero dell\'interfaccia utente';

  @override
  String get readWrite => 'Leggere/Scrivere';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Legge passi, frequenza cardiaca, sonno, esercizio fisico e peso.';

  @override
  String get ready => 'Pronto';

  @override
  String get readyForFirstTimeSetup => 'Pronto per la prima configurazione';

  @override
  String get readyToConnect => 'Pronto per la connessione';

  @override
  String get recentChannelActivity => 'Attività recente del canale';

  @override
  String get recentChats => 'Chat recenti';

  @override
  String get recentDecisions => 'Decisioni recenti';

  @override
  String get recentFailedRuns => 'Esecuzioni recenti non riuscite';

  @override
  String get recentGroupDecisions => 'Decisioni recenti del gruppo';

  @override
  String get recentRuns => 'Esecuzioni recenti';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Le corse recenti richiedono circa $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Output recente del server, prima il più recente.';

  @override
  String get recentUsage4Hours => 'Utilizzo recente (4 ore)';

  @override
  String get recents => 'Recenti';

  @override
  String get recipientField => 'Campo destinatario';

  @override
  String get reconnectOrFinishSetup =>
      'Riconnettiti o completa la configurazione';

  @override
  String get reconnectingThisDevice => 'Riconnessione di questo dispositivo…';

  @override
  String get recurring => 'Ricorrente';

  @override
  String get redirectUri => 'Reindirizzare l\'URI';

  @override
  String get redoOnboarding => 'Rifare l\'onboarding';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get refreshCode => 'Aggiorna il codice';

  @override
  String get refreshNow => 'Aggiorna ora';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Aggiorna lo schermo Android per riprovare.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Rifiuta di inviare a meno che la connessione non venga aggiornata a TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'indipendentemente dalle impostazioni per categoria riportate di seguito.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registra $arg1 per il flusso di convocazione dell\'assistente.';
  }

  @override
  String get registrationIsClosed => 'la registrazione è chiusa';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registrazione registrare nuovi account consentire la registrazione';

  @override
  String get rejectInvalidTlsCertificates =>
      'Rifiuta i certificati TLS non validi';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'rilasciare e riavviare. Le app connesse si riconnettono una volta ripristinate.';

  @override
  String get releaseChannel => 'Canale di rilascio';

  @override
  String get releaseCommitBranchNode => 'rilasciare il nodo del ramo di commit';

  @override
  String get releaseWhenYouAreDone => 'Rilascia quando hai finito.';

  @override
  String get reloadNow => 'Ricarica ora';

  @override
  String get rememberThisChoice => 'Ricorda questa scelta';

  @override
  String get remove => 'Rimuovi';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Rimuovere \"$arg1\" e i relativi passi registrati dalla cronologia delle corse?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Rimuovere \"$arg1\" dalla memoria principale.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Rimuovere la chiave $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'rimuovi cancella utente gdpr';

  @override
  String get removeSmtpPassword => 'Rimuovi la password SMTP';

  @override
  String get removeTheSmtpPassword => 'Rimuovere la password SMTP?';

  @override
  String get rename => 'Rinominare';

  @override
  String get renameSecurityKey => 'Rinominare la chiave di sicurezza';

  @override
  String get renameSession => 'Rinominare la sessione';

  @override
  String get repairAndRetry => 'Riparare e riprovare';

  @override
  String get repairDesktop => 'Ripara il desktop';

  @override
  String get repeat => 'Ripeti';

  @override
  String get repliesWhenTagged => 'Risponde quando taggato';

  @override
  String get replyToAddress => 'Indirizzo di risposta';

  @override
  String replyToArg1(Object? arg1) {
    return 'Rispondi a $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Il repository deve essere nel formato proprietario/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Riproduci il bug che descrivo, trova la causa principale e risolvila con un test di regressione.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'richiesta non riuscita con http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Richiesta non riuscita con HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Richiedi autorizzazioni';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'La richiesta a $arg1 non è riuscita prima che il backend rispondesse.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Richiesto $arg1';
  }

  @override
  String get requireStarttls => 'Richiedi STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Richiesto dietro HTTPS o un proxy TLS. Si applica dopo un server ';

  @override
  String get requiredExampleBerlinDe => 'Obbligatorio. Esempio: Berlino, DE';

  @override
  String get requiredFormatOwnerRepo =>
      'Obbligatorio. Formato: proprietario/repo';

  @override
  String get reserveAssistantHotkey =>
      'Prenota il tasto di scelta rapida dell\'assistente';

  @override
  String get reset => 'Ripristina';

  @override
  String get resetPassword => 'Reimposta la password';

  @override
  String get resetView => 'Reimposta vista';

  @override
  String get responsibilities => 'Responsabilità';

  @override
  String get restart => 'Ricominciare';

  @override
  String get restartToFinishTheUpdate =>
      ' Riavviare per completare l\'aggiornamento.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Ripristino del runtime NeoAgent precedente';

  @override
  String get restrictDelegationTargets => 'Limitare gli obiettivi della delega';

  @override
  String get result => 'Risultato';

  @override
  String get resultDelivery => 'Consegna dei risultati';

  @override
  String get resultOneClickAddsOneYou =>
      'risultato. Un clic ne aggiunge uno; puoi modificarlo in seguito.';

  @override
  String get results => 'Risultati';

  @override
  String get retry => 'Riprova';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Riutilizzabile · usato $arg1×';
  }

  @override
  String get reviewUncommittedChanges =>
      'Esaminare le modifiche non confermate';

  @override
  String get revoke => 'Revoca';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Revocare prima l\'amministratore con `neoagent admin revoke $arg1`';
  }

  @override
  String get revokeThisLink => 'Revocare questo collegamento?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Finestra lotto camera: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Ruota per continuare';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'righe. Aggiungi un LIMIT o una clausola WHERE più ristretta per vedere ';

  @override
  String get rule => 'Regola';

  @override
  String get run => 'Esecuzione';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Esegui comandi arbitrari sul tuo computer o VM.';

  @override
  String get runAt => 'Corri a';

  @override
  String get runCompleted => 'Corsa completata';

  @override
  String get runFailed => 'Esecuzione fallita';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Esegui git diff, esamina le modifiche non confermate per individuare bug e problemi di stile e riepiloga ciò che trovi.';

  @override
  String get runNotFound => 'Corsa non trovata';

  @override
  String get runNow => 'Esegui ora';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Esegui sui messaggi WhatsApp personali in entrata.';

  @override
  String get runQuery => 'Esegui interrogazione';

  @override
  String get runShellCommandsOrInstallApps =>
      'Esegui comandi shell o installa app sul tuo dispositivo Android.';

  @override
  String get runStarted => 'La corsa è iniziata';

  @override
  String get runStatus => 'Stato esecuzione';

  @override
  String get runStopped => 'Corsa interrotta';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Esegui comandi del terminale e apri app o pagine Web.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Esegui questo server: account, aggiornamenti, provider, configurazione ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Esegui quando arriva un messaggio Gmail corrispondente.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Esegui quando arriva un\'e-mail di Outlook corrispondente.';

  @override
  String get runWhenANewIssueMatching =>
      'Esegui quando un nuovo problema corrispondente ai tuoi filtri viene aperto in un repository.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Esegui quando viene creata una nuova memoria NeoRecall corrispondente ai filtri.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Esegui quando arriva una notifica sul tuo dispositivo.';

  @override
  String get runWhenASlackMessageMatches =>
      'Esegui quando un messaggio Slack corrisponde all\'ambito selezionato.';

  @override
  String get runWhenATeamsChatMessage =>
      'Esegui quando un messaggio di chat di Teams corrisponde all\'ambito selezionato.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Esegui quando sono previsti eventi meteorologici configurati per una località.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'correre. Mentre qualsiasi modello è disattivato, i modelli aggiunti dai fornitori ';

  @override
  String get running => 'In corso';

  @override
  String runningArg1(Object? arg1) {
    return 'In esecuzione $arg1';
  }

  @override
  String get runningTask => 'Attività in esecuzione';

  @override
  String get runningTool => 'Strumento di corsa';

  @override
  String get runs => 'Esecuzioni';

  @override
  String get runsEveryDayAtTheSelected =>
      'Funziona ogni giorno all\'orario selezionato.';

  @override
  String get runsFourTimesPerHour => 'Funziona quattro volte all\'ora.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— corse, messaggi, ricordi, integrazioni, file e ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'corse, messaggi, ricordi, integrazioni, file e sessioni. ';

  @override
  String get runsMondayThroughFriday => 'Funziona dal lunedì al venerdì.';

  @override
  String get runsOnSelectedWeekdays =>
      'Funziona nei giorni feriali selezionati.';

  @override
  String get runsOncePerHour => 'Funziona una volta all\'ora.';

  @override
  String get runsOncePerMonthOnThe =>
      'Viene eseguito una volta al mese nel giorno selezionato.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Viene eseguito solo quando si preme Esegui ora.';

  @override
  String get runsPerDay => 'Corse al giorno';

  @override
  String get runsPerDay30Days => 'Corse al giorno (30 giorni)';

  @override
  String get runsThatCompleted => 'Esegue quello completato';

  @override
  String get runsThisWeek => 'Esce questa settimana';

  @override
  String get runsToday => 'Corre oggi';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Esecuzioni, strumenti, memoria, pianificazione, competenze e MCP sono tutti disponibili qui.';

  @override
  String get runsTwicePerHour => 'Funziona due volte all\'ora.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Le esecuzioni torneranno alla chiave del server condiviso per $arg1, se ne è configurata una. L\'operazione non può essere annullata.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Tempo di esecuzione $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Durata: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Impostazioni di runtime con cui è stato avviato questo server. Modificali sotto ';

  @override
  String get runtimeSetupRequired =>
      'È richiesta la configurazione del runtime';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'La chiave pubblica della firma runtime deve essere di 32 byte.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Salva';

  @override
  String get saveATrelloApiKeyFor =>
      'Salva una chiave API Trello per questo agente, quindi collega un account Trello in modo sicuro. Il token dell\'account viene archiviato sul server e utilizzato solo per questo agente.';

  @override
  String get saveAccount => 'Salva conto';

  @override
  String get saveChanges => 'Salva modifiche';

  @override
  String get saveCloudComputerSettings =>
      'Salva le impostazioni del computer cloud';

  @override
  String get saveConnect => 'Salva e connetti';

  @override
  String get saveDefaults => 'Salva le impostazioni predefinite';

  @override
  String get saveDiagnosticReport => 'Salva rapporto diagnostico';

  @override
  String get saveEmail => 'Salva e-mail';

  @override
  String get saveEmailSettings => 'Salva le impostazioni e-mail';

  @override
  String get saveGeneralSettings => 'Salva le impostazioni generali';

  @override
  String get saveName => 'Salva nome';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Salva la diagnostica di configurazione di NeoAgent';

  @override
  String get saveOnly => 'Salva solo';

  @override
  String get saveSetup => 'Salva configurazione';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Salva questi codici di ripristino adesso. Non verranno mostrati nuovamente.';

  @override
  String get savedDeliveryDestination => 'Destinazione di consegna salvata';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Limiti di velocità salvati per @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Scansiona un QR di accesso a NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scansiona un QR di abbinamento NeoAgent da un altro dispositivo e approvalo da questa sessione di avvio.';

  @override
  String get scanLoginQr => 'Scansiona il QR di accesso';

  @override
  String get scanPairingQr => 'Scansiona il QR di abbinamento';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scansiona le richieste di accesso QR dai dispositivi disconnessi e approvale da questa sessione mobile autenticata.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scansione per finire $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Scansiona con NeoAgent sul tuo telefono';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Esegue la scansione delle nuove email e ti invia un ping solo quando qualcosa conta.';

  @override
  String get schedule => 'Programma';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'orario previsto. Una volta misurate le corse, queste inizieranno prima.';

  @override
  String get screen => 'Schermo';

  @override
  String get screenAction => 'azione sullo schermo';

  @override
  String get scrollIsNotSupportedOnThis =>
      'lo scorrimento non è supportato su questa piattaforma.';

  @override
  String get scrollToBottom => 'Scorri fino in fondo';

  @override
  String get search => 'Cerca';

  @override
  String get search2 => 'Cerca...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Cerca nelle impostazioni dell\'amministratore (ad esempio SMTP, Ollama, registri)';

  @override
  String get searchAgain => 'Cerca di nuovo';

  @override
  String get searchByUsernameOrEmail => 'Cerca per nome utente o e-mail';

  @override
  String get searchChannels => 'Cerca canali';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'La ricerca ha scoperto canali di messaggistica, contatti, gruppi e conversazioni recenti.';

  @override
  String get searchGroups => 'Cerca gruppi';

  @override
  String get searchMemory => 'Cerca nella memoria';

  @override
  String get searchModelsOrProviders => 'Cerca modelli o fornitori';

  @override
  String get searchModelsOrProviders2 => 'Cerca modelli o fornitori...';

  @override
  String get searchRecentPeopleAndGroups => 'Cerca persone e gruppi recenti';

  @override
  String get searchSessions => 'Sessioni di ricerca';

  @override
  String get searchSettings => 'Impostazioni di ricerca';

  @override
  String get searchTitleModelTriggerRunId =>
      'Cerca titolo, modello, trigger, ID esecuzione';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Strumenti di ricerca, integrazioni e competenze';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Codice cercato per \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'File cercati per \"$arg1\"';
  }

  @override
  String get secretField => 'Campo segreto';

  @override
  String get secureCookies => 'Cookie sicuri';

  @override
  String get security => 'Sicurezza';

  @override
  String get securityKey => 'Chiave di sicurezza';

  @override
  String get securityKeyPromptWasDismissed =>
      'La richiesta della chiave di sicurezza è stata ignorata.';

  @override
  String get securityKeySignInCompletedBut =>
      'Accesso alla chiave di sicurezza completato, ma NeoAgent non è riuscito a mantenere la sessione del browser. Per favore accedi di nuovo.';

  @override
  String get securityKeySignInCouldNot =>
      'Impossibile avviare l\'accesso con il token di sicurezza.';

  @override
  String get securityKeys => 'Chiavi di sicurezza';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Le chiavi di sicurezza sono disponibili solo nell\'app Web NeoAgent.';

  @override
  String get seeAll => 'Vedi tutto';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Scopri quale server NeoAgent utilizza questa finestra ed esegui il backend su questo computer.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'vedere il tuo nome utente e queste impostazioni, mai le tue chat, i tuoi ricordi ';

  @override
  String get selectARun => 'Seleziona una corsa';

  @override
  String get selectASessionToSeeIts =>
      'Seleziona una sessione per visualizzarne il computer, i file e le modifiche.';

  @override
  String get selectAll => 'Seleziona tutto';

  @override
  String get selectAll2 => 'Seleziona tutto';

  @override
  String selectArg1(Object? arg1) {
    return 'Selezionare $arg1';
  }

  @override
  String get selectTrigger => 'Seleziona Attiva';

  @override
  String get send => 'Invia (⌘↵)';

  @override
  String get send2 => 'Invia';

  @override
  String get sendATaskFromChatAnd =>
      'Invia un\'attività dalla chat e la sua cronologia di esecuzione verrà visualizzata qui.';

  @override
  String get sendItToATeammateWith =>
      'invialo a un compagno di squadra con un account su questo server.';

  @override
  String get sendLink => 'Invia collegamento';

  @override
  String get sendPath => 'Invia percorso';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Invia richieste POST/PUT/DELETE ad API esterne.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Invia questo collegamento solo alla persona a cui è destinato. Viene mostrato una volta; ';

  @override
  String get senderAddress => 'Indirizzo del mittente';

  @override
  String get senderFilterOptional => 'Filtro mittente (facoltativo)';

  @override
  String get sentSharedAttachments => 'Inviati allegati condivisi.';

  @override
  String get separateAccount => 'Conto separato';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Impostazione predefinita del server ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Le impostazioni predefinite del server per le chiamate vocali in-app. Le chiamate vengono eseguite in diretta ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'server stesso: account, provider e configurazione.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, nick, canale e TLS opzionale';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'copia degli errori degli avvisi della console di output del server';

  @override
  String get serverProviderCredentials =>
      'Credenziali del fornitore del server';

  @override
  String get serverUrl => 'URL del server';

  @override
  String get serverUsageLimitsDonTApply =>
      'I limiti di utilizzo del server non si applicano ai modelli in esecuzione sulla tua chiave.';

  @override
  String get serviceEmail => 'E-mail di servizio';

  @override
  String get serviceEmailIsNotConfigured =>
      'l\'e-mail di servizio non è configurata';

  @override
  String get serviceEmailSmtp => 'E-mail di servizio (SMTP)';

  @override
  String get sessionActions => 'Azioni della sessione';

  @override
  String get sessions => 'Sessioni';

  @override
  String get sessions2 => 'SESSIONI';

  @override
  String get sessionsArePinnedToAFolder =>
      'Le sessioni vengono fissate a una cartella e a un computer. Avviane uno per pianificare, costruire, testare e spedire da qui.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sessioni (GDPR art. 17). Gli account amministratore non possono essere eliminati ';

  @override
  String get sessionsLogoutRevokeForce =>
      'revoca delle sessioni di disconnessione';

  @override
  String get setBlockAskAllowPerTool =>
      'Imposta blocca/chiedi/consenti per categoria di strumento o scegli una modalità globale.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Configura NeoAgent su questo computer';

  @override
  String get setUpOrConnectNeoagent => 'Configura o connetti NeoAgent';

  @override
  String get setUrl => 'Imposta l\'URL';

  @override
  String get settings => 'Impostazioni';

  @override
  String get settingsAndCannotBeUndone =>
      'impostazioni e non può essere annullata.';

  @override
  String get settingsArea => 'Area Impostazioni';

  @override
  String get settingsAreas => 'Aree delle impostazioni';

  @override
  String get setup => 'Installazione';

  @override
  String get setupDetails => 'Dettagli di installazione';

  @override
  String get setupRequired => 'Configurazione richiesta';

  @override
  String get setupWasCancelled => 'L\'installazione è stata annullata.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Allegati condivisi dal client NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Condiviso da un\'altra app';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Le chiavi del provider condiviso sono configurate sul server. Per utilizzare invece la tua chiave API o un endpoint personalizzato, vai su Avanzate → Porta la tua chiave.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Condiviso con la chat di NeoAgent e la sua memoria.';

  @override
  String get shellCommands => 'Comandi della shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Mostra tutto $arg1';
  }

  @override
  String get showEarlier => 'Mostra prima';

  @override
  String get showEveryStep => 'Mostra ogni passaggio';

  @override
  String get showTools => 'Mostra strumenti';

  @override
  String get showWorkbenchJ => 'Mostra banco di lavoro (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Mostrando il primo $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Mostrato nella barra laterale. Lascia vuoto per utilizzare il tuo nome utente.';

  @override
  String get signIn => 'Accedi';

  @override
  String get signInCompletedButNeoagentCould =>
      'Accesso completato, ma NeoAgent non è riuscito a mantenere la sessione del browser. Per favore accedi di nuovo. Se il problema persiste, controlla le impostazioni dei cookie della sessione backend.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Accesso completato, ma NeoAgent non è riuscito a mantenere la sessione del browser. Per favore accedi di nuovo. Se ciò continua a verificarsi, è probabile che il cookie della sessione backend non venga conservato.';

  @override
  String get signInToThisNeoagentServer =>
      'Accedi a questo server NeoAgent prima di scansionare un codice QR di accoppiamento.';

  @override
  String get signInWithAHardwareKey =>
      'Accedi con una chiave hardware o una passkey invece della password. ';

  @override
  String get signInWithASecurityKey => 'Accedi con una chiave di sicurezza';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Accedi con $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Approva NeoAgent nel tuo account $arg1. Nessuna chiave da copiare.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'In attesa di $arg1. Termina nel tuo browser.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Incolla il codice $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Dopo aver approvato NeoAgent, $arg1 ha mostrato un codice monouso. Incollalo qui.';
  }

  @override
  String get signInCode => 'Codice di accesso';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Accesso effettuato con $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Accesso non riuscito: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Accedi con la stessa email e password principale che usi in Bitwarden. La password principale e il codice in due passaggi vengono utilizzati solo per l\'accesso e non vengono mai archiviati o inviati all\'IA.';

  @override
  String get signOut => 'Esci';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Uscire da @$arg1 ovunque?';
  }

  @override
  String get signOutEverywhere => 'Esci ovunque';

  @override
  String get signalCliRestApiBridge => 'bridge API REST signal-cli';

  @override
  String get signalCliServerUrl => 'URL del server signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Firmato @$arg1 fuori da ogni sessione.';
  }

  @override
  String get signedInDevices =>
      'Dispositivi su cui è stato effettuato l\'accesso';

  @override
  String get signedInWithin24Hours => 'Accesso effettuato entro 24 ore';

  @override
  String get signingSecret => 'Firma segreta';

  @override
  String sinceArg1(Object? arg1) {
    return 'Dal $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'dal $arg1';
  }

  @override
  String get singleMessage => 'Messaggio singolo';

  @override
  String get singleUse => 'Monouso';

  @override
  String get skill => 'Abilità';

  @override
  String get skillChanges => 'Modifiche alle abilità';

  @override
  String get skillContent => 'Contenuto delle competenze';

  @override
  String get skills => 'Abilità';

  @override
  String get skip => 'Salta';

  @override
  String get skipForNow => 'Salta per ora';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Salta questa attività prima che chiami il modello.';

  @override
  String get slackMessageReceived => 'Messaggio lento ricevuto';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Sessioni di sonno $arg1';
  }

  @override
  String get smartSelector => 'selettore intelligente';

  @override
  String get smartSelector2 => 'Selettore intelligente';

  @override
  String get smartSelectorPool => 'Pool di selettori intelligenti';

  @override
  String get smtpHost => 'Ospite SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'reset della password del mittente della posta smtp, notifiche di conferma tls';

  @override
  String get smtpPassword => 'Password SMTP';

  @override
  String get smtpPort => 'Porta SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'La porta SMTP deve essere un numero intero compreso tra 1 e 65535.';

  @override
  String get smtpUsername => 'Nome utente SMTP';

  @override
  String get soTheRunStartsThatMuch => 'quindi la corsa inizia molto prima.';

  @override
  String get socialBehaviorOff => 'Comportamento sociale disattivato';

  @override
  String get socialIntelligence => 'intelligenza sociale';

  @override
  String get socialIntelligence2 => 'Intelligenza sociale';

  @override
  String get socialObservability => 'Osservabilità sociale';

  @override
  String get socialReach => 'portata sociale';

  @override
  String get socialReach2 => 'Portata sociale';

  @override
  String get socialReach3 => 'Portata sociale';

  @override
  String get socialReachUpdated => 'Copertura sociale aggiornata.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Gli agenti delle fonti social possono leggere direttamente, inclusi feed, repository, Reddit, X, video e dati di mercato supportati dai cookie.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Qualcosa è andato storto. Per favore riprova.';

  @override
  String get source => 'Fonte';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Spazio o ID chat utilizzato quando questo agente avvia una conversazione.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Supporto per webhook spaziale e callback dell\'app';

  @override
  String get speaking => 'Parlando';

  @override
  String get speechToSpeechModelUsingThe =>
      'modello di sintesi vocale utilizzando la chiave OpenAI o Google sotto ';

  @override
  String get speechToText => 'Discorso in testo';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'La sintesi vocale trascrive le note vocali e la dettatura. Auto utilizza OpenAI, Gemini o Deepgram, a seconda di quale abbia una chiave API. Il modello di risposta vocale è il modello di chat che risponde alle note vocali.';

  @override
  String get sqlConsole => 'Consolle SQL';

  @override
  String get stable => 'Stabile';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable installa l\'ultima versione del backend pubblicata.';

  @override
  String get stackTrace => 'traccia dello stack';

  @override
  String get standard => 'Norma';

  @override
  String get standardView => 'Visualizzazione standard';

  @override
  String get start => 'Inizia';

  @override
  String get startASessionToPlanOr =>
      'Avvia una sessione per pianificare o costruire con NeoAgent.';

  @override
  String get startAndroid => 'Avvia Android';

  @override
  String get startComputer => 'Avvia il computer';

  @override
  String get startFullSetup => 'Avvia la configurazione completa';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Avvia la configurazione';

  @override
  String get startTalking => 'Inizia a parlare';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Avvia prima il telefono Android, quindi rilascia qui un file .apk o .apks.';

  @override
  String get startTheServerLaterFromThe =>
      'Avviare il server più tardi dall\'elenco una volta salvata la configurazione.';

  @override
  String get startWithARecommendedTask => 'Inizia con un\'attività consigliata';

  @override
  String get startingAndroid => 'Avvio di Android';

  @override
  String get startingYourComputer => 'Avvio del computer';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Inizia con xoxb-. Dalle credenziali dell\'app Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'Errore di routing delle chiamate startTelecom: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'le statistiche eseguono i token, gli utenti, i grafici, la percentuale di successo';

  @override
  String get status => 'Stato';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'provider di macchine virtuali runtime del database di stato';

  @override
  String get statusIsNotLoadedYet => 'Lo stato non è ancora stato caricato.';

  @override
  String get stayManagedByYou => 'rimani gestito da te.';

  @override
  String get stayOnTheCall => 'Rimani in chiamata';

  @override
  String get stayedQuiet => 'Rimasi in silenzio';

  @override
  String get steering => 'STERZO';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'PASSO $arg1 DI $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Passaggi $arg1';
  }

  @override
  String get stop => 'Interrompi';

  @override
  String get stop2 => 'Fermare.)';

  @override
  String get stopManaging => 'Smettila di gestire';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Smettere di gestire $arg1?';
  }

  @override
  String get stopRun => 'Smettila di correre';

  @override
  String get stopSpeaking => 'Smettila di parlare';

  @override
  String get stoppedBeforeCompletion => 'Interrotto prima del completamento';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'Errore di stopTelecomCallRouting: $arg1';
  }

  @override
  String get storage => 'Stoccaggio';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'archiviati crittografati e utilizzati solo per le tue corse.';

  @override
  String get storedMetrics => 'Metriche memorizzate';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Memorizza solo la chiave di sessione Bitwarden crittografata su questo server, quindi le connessioni sopravvivono ai riavvii. Puoi bloccarlo in qualsiasi momento.';

  @override
  String get strong => 'Forte';

  @override
  String get strongPassword => 'Password complessa.';

  @override
  String get subAgent => 'Subagente';

  @override
  String get subagentUpdate => 'Aggiornamento del subagente';

  @override
  String get subagentUpdate2 => 'Aggiornamento del subagente.';

  @override
  String get successRate => 'Tasso di successo';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Suggerimenti: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Riassumi la mia ultima corsa';

  @override
  String get supportUrl => 'URL di supporto';

  @override
  String get supportedRainStartSnowStartWind =>
      'Supportati: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Cambia agente';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'I collegamenti simbolici non sono consentiti nei percorsi dell\'area di lavoro NeoAgent.';

  @override
  String get syncNow => 'Sincronizza ora';

  @override
  String get synologyChat => 'Chatta Synology';

  @override
  String get systemPrivacySettings => 'Impostazioni sulla privacy del sistema';

  @override
  String get tableInfoUsers => 'Informazioni sulla tabella (utenti)';

  @override
  String get tagsOnly => 'Solo tag';

  @override
  String get tasks => 'Compiti';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Le attività vengono eseguite da sole e ti inviano messaggi con il file ';

  @override
  String get teach => 'Insegna';

  @override
  String get teachingInProgress => 'Insegnamento in corso';

  @override
  String get team => 'Squadra';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'I collegamenti al team non rendono mai nessuno amministratore del server. Gli amministratori eseguono il file ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Spazi del team, stanze virtuali, canali e comunità live.';

  @override
  String get teamsMessageReceived => 'Messaggio del team ricevuto';

  @override
  String get templates => 'Modelli';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'I file di installazione temporanei verranno ripuliti in seguito.';

  @override
  String get tenantId => 'ID inquilino';

  @override
  String get testConnection => 'Testare la connessione';

  @override
  String get testConnection2 => 'Prova connessione';

  @override
  String get textChat => 'SMS e chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'che hanno aggiunto la propria chiave continuano a usarla.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Quell\'e-mail appartiene già a un account esistente. Accedi prima, quindi collega Google dalle impostazioni dell\'account.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Quell\'e-mail è già collegata a un altro account.';

  @override
  String get thatQrCodeIsNotA =>
      'Quel codice QR non è una richiesta di accesso a NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Quel codice QR non è una richiesta di abbinamento NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'La chiave di sicurezza è già registrata su questo account.';

  @override
  String get theAddress => 'L\'indirizzo';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'L\'indirizzo del tuo server BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'L\'indirizzo che le persone e i provider OAuth utilizzano per raggiungere ';

  @override
  String get theAgentReadsTimesYouMention =>
      'L\'agente legge gli orari menzionati ed esegue le attività pianificate in questo fuso orario.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'L\'agente chiederà prima di ogni strumento sensibile, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'L\'agente ignorerà questa abilità.';

  @override
  String get theAppCouldNotReachThis =>
      'L\'app non è riuscita a raggiungere questa distribuzione NeoAgent. Controlla la connessione di rete o verifica che l\'URL del servizio sia corretto.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Il browser ha bloccato una richiesta a $arg1 a causa della politica di sicurezza dei contenuti.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Il browser ha bloccato una richiesta obbligatoria a causa della politica di sicurezza dei contenuti.';

  @override
  String get theCloudWorkspace => 'lo spazio di lavoro nel cloud';

  @override
  String get theComputerCouldNotStart => 'Impossibile avviare il computer';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Il computer necessita di più spazio libero su disco sull\'host NeoAgent. Liberare spazio e riprovare.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Il runtime del computer necessita di riparazione. Esegui NeoAgent Doctor, quindi riprova.';

  @override
  String get theConnectionTestFailed =>
      'Il test di connessione non è riuscito.';

  @override
  String get theDesktopDidNotStart => 'Il desktop non è stato avviato';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Il NeoAgent scoperto ha restituito dati di identità incompleti.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Il NeoAgent rilevato utilizza un protocollo di installazione non supportato.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Il servizio scoperto non è NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Il runtime NeoAgent scaricato non ha superato la verifica.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Il webhook dello spazio Google Chat su cui questo agente dovrebbe postare.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Il programma di installazione non è più disponibile.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Il desktop Linux interattivo è disponibile nell\'app Web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'L\'introduzione non è disponibile su questo dispositivo.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'L\'ultima versione viene eseguita su ogni account.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'L\'ultima finestra di sincronizzazione è terminata con $arg1 e non è stato trovato alcun nuovo record di Health Connect. Le metriche memorizzate di seguito provengono da sincronizzazioni precedenti.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'La sessione grafica di Linux non è in esecuzione.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Il modello vocale dal vivo non ha risposto. Riprova.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Il comando NeoAgent locale è terminato con il codice $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Il comando NeoAgent locale è scaduto.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'È necessario riparare il runtime NeoAgent locale.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Il runtime locale necessita di riparazione ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'La directory home dell\'utente locale non è disponibile.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'L\'account di posta NeoAgent invia conferme di registrazione, accesso ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'L\'agente principale viene creato automaticamente quando necessario.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'In questa versione manca il runtime NeoAgent corrispondente.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Il webhook in entrata Mattermost su cui questo agente dovrebbe postare.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'I modelli tra cui lo Smart Selector instrada automaticamente.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Il download del backend di NeoAgent non corrispondeva al suo manifest.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Il download del backend di NeoAgent era incompleto.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Il backend NeoAgent su questo computer non risponde sulla porta ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Impossibile scaricare il runtime del backend NeoAgent.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Il backend NeoAgent ha impiegato troppo tempo per rispondere a $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'La distribuzione NeoAgent ha risposto con HTTP 402 invece del normale 401 per credenziali non valide. Controlla il proxy inverso, il gateway di autenticazione o le regole relative ai pagamenti su quel server.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'La distribuzione NeoAgent ha risposto con HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'La distribuzione di NeoAgent ha risposto con HTTP 402. Controlla il proxy inverso, il gateway di autenticazione o le regole relative ai pagamenti su quel server.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'L\'istanza NeoAgent a cui è connessa questa app.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Il servizio di rilascio di NeoAgent ha restituito dati non validi.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'I metadati dell\'artefatto runtime NeoAgent non sono validi.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Il manifest del runtime NeoAgent non ha superato la verifica della firma.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Il manifest del runtime NeoAgent non presenta artefatti.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'La firma del manifest del runtime NeoAgent non è valida.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'La password che hai impostato in BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Le persone che gestisci restano con te.';

  @override
  String get theProviderAnswers => 'risponde il fornitore.';

  @override
  String get theQueryReturnedNoRows => 'La query non ha restituito righe.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'La visualizzazione del desktop richiesta non è disponibile.';

  @override
  String get theRest => 'il riposo.';

  @override
  String get theRestEndpointForYourSignal =>
      'L\'endpoint REST per la tua istanza signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'La corsa viene sospesa finché non rispondi.';

  @override
  String get theRunStartsAtTheScheduled =>
      'La corsa inizia all\'orario previsto.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Il runtime è un desktop Debian Linux leggero con Chromium, PCManFM, Mousepad, LXTerminal, Python, Git e strumenti da riga di comando standard. La sua capacità è gestita dall\'host NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Impossibile avviare la registrazione della chiave di sicurezza.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'il server ne conserva solo un\'impronta digitale.';

  @override
  String get theServerOnThisComputerIs =>
      'Il server su questo computer non è in esecuzione';

  @override
  String get theServerReportedNoHealthChecks =>
      'Il server non ha segnalato controlli di integrità.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Il numero di telefono Signal utilizzato da questo bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Il webhook in entrata di Teams su cui questo agente dovrebbe postare.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'La sfida a due fattori è scaduta. Accedi di nuovo.';

  @override
  String get theTwoFactorCodeIsNot => 'Il codice a due fattori non è valido.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Impossibile contrassegnare il pacchetto runtime verificato come eseguibile.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Nel pacchetto runtime verificato mancano i file richiesti.';

  @override
  String get theWebAppCouldNotReach =>
      'L\'app Web non è riuscita a raggiungere il backend NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'L\'app Web non è riuscita a raggiungere il backend NeoAgent su $arg1. Controlla la console del browser e la configurazione del proxy inverso/di rete.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'loro stessi; l\'operatore del server rimuove prima l\'amministratore con ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Questi canali rimangono silenziosi. Per sentirli di nuovo, aggiungili in Chi può inviare messaggi per quella piattaforma.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Questi elenchi sono facoltativi a meno che una sezione precedente non sia impostata su Solo approvato.';

  @override
  String get thesePeopleAnywhere => 'Queste persone, ovunque';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Queste persone possono inviare messaggi a $arg1 nelle chat private e in qualsiasi gruppo che condividono.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Queste persone possono inviare messaggi $arg1 uno a uno. Ciò non consente loro di parlare in gruppo.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Queste persone possono inviare messaggi a $arg1 solo nel gruppo che hai scelto.';
  }

  @override
  String get thesePeopleInOneGroup => 'Queste persone, in un gruppo';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'questi interruttori, mai le tue chat, i tuoi ricordi o i tuoi file.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Questo account sbloccherà NeoAgent su questa macchina.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Questo agente può delegare qualsiasi agente ricevente idoneo.';

  @override
  String get thisAgentIsUsingAServer =>
      'Questo agente utilizza una chiave API Trello gestita dal server. Devi solo autorizzare un token dell\'account di seguito.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'A questa build non è consentito comunicare con questa distribuzione NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Questo codice appartiene a un diverso server NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Questo desktop è connesso';

  @override
  String get thisDevice => 'Questo dispositivo';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Questo dispositivo: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Questo dispositivo non può registrare le chiavi di sicurezza. Apri NeoAgent in un browser su HTTPS per aggiungerne uno.';

  @override
  String get thisDeviceUnavailable => 'Questo dispositivo: non disponibile';

  @override
  String get thisFileHasNoContent => 'Questo file non ha contenuto.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Ciò nasconde \"$arg1\" dal routing e dalla selezione.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Questa integrazione attualmente supporta un account connesso per agente. Riaprire la configurazione per sostituirlo.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Questa integrazione non è più disponibile.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Questa introduzione è progettata per la riproduzione orizzontale a schermo intero.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Questa è una distribuzione gestita. Il suo operatore esce ';

  @override
  String get thisMayTakeAMoment =>
      'L\'operazione potrebbe richiedere un momento.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Questo server MCP non è più configurato.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Questa memoria verrà rimossa permanentemente.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Questa build di NeoAgent non è configurata per verificare i runtime di backend.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Questo cancella permanentemente tutti i tuoi dati e non può essere ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Questo cancella permanentemente l\'account e tutto ciò che possiede: ';

  @override
  String get thisPersonAnywhere => 'Questa persona, ovunque';

  @override
  String get thisPersonInOneGroup => 'Questa persona, in un gruppo';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Questa richiesta di accesso QR è scaduta. Genera un nuovo codice e riprova.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'questa richiesta di accesso qr è scaduta';

  @override
  String get thisQrLoginRequestIsStill =>
      'Questa richiesta di accesso QR è ancora in attesa di approvazione.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Questa richiesta di accesso QR è già stata utilizzata.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Ciò rimuove la configurazione di Home Assistant e l\'istanza connessa per questo agente.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Ciò rimuove l\'URL di backend NeoRecall e tutti gli account NeoRecall collegati per questo agente.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Ciò rimuove l\'URL Nextcloud e tutti gli account Nextcloud connessi per questo agente.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Ciò rimuove la configurazione Trello e gli account collegati per questo agente.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Ciò richiede una sessione autenticata sullo stesso server NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Questa esecuzione non ha prodotto una risposta rivolta all\'utente.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Per questa corsa non sono presenti dati sui passi registrati.';

  @override
  String get thisServer => 'questo server.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Questo server non riporta alcuna impostazione del provider.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Questa abilità non è più installata.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Questa attività non è stata ancora completata, quindi inizia ancora da ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Questa attività verrà eseguita solo quando premi Esegui ora.';

  @override
  String get thisWeek => 'Questa settimana';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Ciò importerà la risposta in $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Questo rimuoverà \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Ciò rimuoverà \"$arg1\" dall\'elenco dei server.';
  }

  @override
  String get time => 'Tempo';

  @override
  String get timeZone => 'fuso orario';

  @override
  String get timeZone2 => 'Fuso orario';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Timeout$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Impossibile elencare i fusi orari: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Impossibile leggere il fuso orario del dispositivo: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Impossibile salvare il fuso orario del dispositivo: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'a $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'per utilizzare l\'impostazione predefinita del server.';

  @override
  String get today => 'Oggi';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Budget gettoni per @$arg1. Lascia un campo vuoto ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Budget token per ogni account senza il proprio override. Lascia un ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'Limite di budget del token: utente con quota settimanale di 4 ore';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'Limite di budget del token: quota settimanale globale di 4 ore';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Utilizzo del token non disponibile su questa versione del server.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Token che qualsiasi account può utilizzare in 4 ore.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Token che qualsiasi account può utilizzare in 7 giorni.';

  @override
  String get tokensPerDay => 'Gettoni al giorno';

  @override
  String get tokensPerRun => 'Gettoni per corsa';

  @override
  String get tokensToday => 'Gettoni oggi';

  @override
  String get tokensUsed => ' gettoni utilizzati';

  @override
  String get tomorrowPrep => 'Domani preparazione';

  @override
  String get tooManyAttempts => 'troppi tentativi';

  @override
  String get tooManySignInAttemptsPlease =>
      'Troppi tentativi di accesso. Attendi e riprova.';

  @override
  String get tool => 'Strumento';

  @override
  String get toolApproval => 'Approvazione dello strumento';

  @override
  String get toolApprovalRequired =>
      'È richiesta l\'approvazione dello strumento';

  @override
  String get toolCompleted => 'Strumento completato';

  @override
  String get toolFailed => 'Strumento non riuscito';

  @override
  String get toolPermissions => 'Autorizzazioni dello strumento';

  @override
  String get toolStarted => 'Strumento avviato';

  @override
  String get tools => 'Strumenti';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Strumenti non integrati in NeoAgent, inclusi server MCP connessi e fornitori di strumenti personalizzati.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Strumenti offerti ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Strumenti che l\'account gestito può utilizzare';

  @override
  String get topUsers => 'Utenti migliori';

  @override
  String get topUsersAndRecentRuns => 'Utenti principali e corse recenti';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Totale: token $arg1 nelle esecuzioni $arg2';
  }

  @override
  String get totalRuns => 'Corse totali';

  @override
  String get totalTokens => 'Gettoni totali';

  @override
  String get totalUsers => 'Utenti totali';

  @override
  String get transcript => 'Trascrizione';

  @override
  String get transcript2 => 'TRASCRIZIONE';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Trascrizione non riuscita: $arg1';
  }

  @override
  String get transfer => 'Trasferimento';

  @override
  String get trelloApiKey => 'Chiave API Trello';

  @override
  String get trelloApiKeyIsRequired => 'È richiesta la chiave API Trello.';

  @override
  String get trelloSetup => 'Configurazione di Trello';

  @override
  String get triggerType => 'Tipo di trigger';

  @override
  String get tryABroaderSearchLikeModels =>
      'Prova una ricerca più ampia come modelli, browser o voce.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Prova il nome di un provider, \"email\", \"limiti\", \"aggiornamento\" o \"log\".';

  @override
  String get tryAgain => 'Riprova';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Riprova. Se il problema persiste, esegui NeoAgent Doctor per verificare il tempo di esecuzione del computer.';

  @override
  String get tryAgainInAMoment => 'Riprova tra un attimo.';

  @override
  String get tryAgainOrRunNeoagentDoctor => 'Riprova o esegui NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Prova un\'altra ricerca, collega una piattaforma di messaggistica o inserisci manualmente un ID di destinazione.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Attiva un gruppo se $arg1 deve leggere anche i messaggi che non lo taggano.';
  }

  @override
  String get turnOffComputer => 'Spegni il computer';

  @override
  String get turnOffOnlyForAMail =>
      'Disattiva solo per un server di posta con un certificato autofirmato.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Attiva se Signal deve continuare a cercare le chat in arrivo.';

  @override
  String get turnTaking => 'prendere il turno';

  @override
  String get turnTakingModel => 'Modello a turni';

  @override
  String get turnTakingOff => 'Svolta in decollo';

  @override
  String get turnThisOffToKeepThis =>
      'Disattiva questa opzione per mantenere questo agente completamente separato dagli altri agenti.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Spento da $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Disattivato da $arg1, che gestisce questo account. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Disattivato per te da $arg1: solo loro possono cambiarlo';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Spento per te, quindi non puoi distribuirlo';

  @override
  String get twitchChatOverIrc => 'Chatta su Twitch su IRC';

  @override
  String get twoFactorAuthentication => 'Autenticazione a due fattori';

  @override
  String get twoFactorChallengeExpired => 'la sfida a due fattori è scaduta';

  @override
  String get twoFactorCode => 'codice a due fattori';

  @override
  String get twoFactorSignInCompletedBut =>
      'Accesso a due fattori completato, ma NeoAgent non è riuscito a mantenere la sessione del browser. Per favore accedi di nuovo.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Login in due passaggi (solo se abilitato)';

  @override
  String get type => 'Digitare';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Digita $arg1 per confermare';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'il tipo di testo non è supportato su questa piattaforma.';

  @override
  String get typedInTheBrowser => 'Digitato nel browser';

  @override
  String get typedText => 'Testo digitato';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'impossibile individuare un runtime Java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Impossibile aprire le impostazioni dell\'ora su questa build.';

  @override
  String get unableToOpenWiFiSettings =>
      'Impossibile aprire le impostazioni Wi-Fi su questa build.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Impossibile mantenere la visualizzazione del desktop selezionata.';

  @override
  String get unclearWhoItWasFor => 'Non è chiaro per chi fosse';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'annullato. Digita il tuo nome utente per confermare.';

  @override
  String get unknownAccount => 'Conto sconosciuto';

  @override
  String get unknownAgent => 'Agente sconosciuto';

  @override
  String get unknownBrowser => 'Browser sconosciuto';

  @override
  String get unknownDevice => 'Dispositivo sconosciuto';

  @override
  String get unknownError => 'errore sconosciuto';

  @override
  String get unknownLocalComputerPermission =>
      'Autorizzazione del computer locale sconosciuta.';

  @override
  String get unknownLocation => 'Posizione sconosciuta';

  @override
  String get unknownPublishTime => 'Orario di pubblicazione sconosciuto';

  @override
  String get unknownSize => 'Dimensioni sconosciute';

  @override
  String get unlink => 'Scollega';

  @override
  String get unreadOnly => 'Solo non letto';

  @override
  String get unsavedChanges => 'Modifiche non salvate';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Comando complementare desktop non supportato: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Metodo non supportato: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Avvisi di accesso insoliti';

  @override
  String updateArg1(Object? arg1) {
    return 'Aggiorna $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Aggiorna le voci della memoria principale dall\'importazione.';

  @override
  String get updateNow => 'Aggiorna ora';

  @override
  String get updateReady => 'Aggiornamento pronto';

  @override
  String get updateSetup => 'Aggiorna configurazione';

  @override
  String get updateTheAccessListToAllow =>
      'Aggiorna l\'elenco di accesso per consentire le risposte.';

  @override
  String get updateTheServer => 'Aggiornare il server?';

  @override
  String get updateTheServer2 => 'Aggiorna il server';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Aggiorna automaticamente il fuso orario dal dispositivo che stai utilizzando.';

  @override
  String updatedArg1(Object? arg1) {
    return 'aggiornato $arg1';
  }

  @override
  String get updates => 'Aggiornamenti';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Gli aggiornamenti non sono configurati per questa build.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'aggiornamenti, quindi l\'aggiornamento automatico e le modifiche al canale sono disattivati ​​qui.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'aggiornamento aggiornamento ora rilascia la beta stabile del canale';

  @override
  String get usageAnalytics => 'Analisi dell\'utilizzo';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Segnali di utilizzo e integrità che aiutano a spiegare il comportamento corrente del runtime senza prima analizzare i log.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'L\'utilizzo si ripristina completamente in $arg1';
  }

  @override
  String get usageLeaderboard => 'classifica di utilizzo';

  @override
  String get usageLimits => 'Utilizzo e limiti';

  @override
  String get usageLimits2 => 'Utilizzo e limiti';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Utilizza più di 8 caratteri. Le passphrase più lunghe funzionano bene.';

  @override
  String get useADateAndTimeFor =>
      'Utilizza una data e un\'ora, ad esempio 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Utilizza un nome, un numero di telefono o un ID chat.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Utilizzare un URL NeoRecall raggiungibile dal server NeoAgent. Anche il PUBLIC_URL di NeoAgent deve essere raggiungibile da questo browser per il callback OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Utilizza una nuova password con almeno 8 caratteri.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Utilizza un URL Nextcloud che il server NeoAgent può raggiungere, ad esempio https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Utilizzare una password con almeno 8 caratteri.';

  @override
  String get useASecureConnectionTls => 'Utilizza una connessione sicura (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Utilizza un\'app di autenticazione come Authy, 1Password o Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Utilizza almeno 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Memoria massima per computer (MB)';

  @override
  String get maxVcpusPerComputer => 'Numero massimo di vCPU per computer';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Almeno $arg1. I computer ottengono meno quando l\'host è occupato.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'La memoria massima deve essere almeno $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Utilizza almeno 8 caratteri.';

  @override
  String get useDefault => 'Utilizza predefinito';

  @override
  String get useDefaultChannel => 'Utilizza il canale predefinito';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Utilizza predefinito (Area di lavoro NeoAgent)';

  @override
  String get useFor => 'Utilizzare per';

  @override
  String get useManualDestination => 'Utilizza destinazione manuale';

  @override
  String get useOrDoTheSameFor =>
      'usa o fai lo stesso per i tuoi compagni di squadra.';

  @override
  String get usePerCategorySettingsBelow =>
      'Utilizza le impostazioni per categoria riportate di seguito.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Utilizza impostazioni predefinite ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Utilizza il server su questo computer';

  @override
  String get useTheseForContextIfA =>
      'Usali per il contesto. Se un URI locale non è direttamente accessibile dal server, chiedimi di fornire il file tramite uno spazio di lavoro accessibile.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Utilizzarlo per gli agenti dell\'orchestratore. Lascia perdere i bot di lavoro isolati che dovrebbero completare da soli i messaggi diretti.';

  @override
  String get useTlsFromTheStartOf =>
      'Utilizza TLS dall\'inizio della connessione, solitamente sulla porta 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Utilizza la tua chiave API per un provider o connetti una chiave API personalizzata ';

  @override
  String get usedByEveryAccountOnThis =>
      'Utilizzato da ogni account su questo server che non dispone di chiave ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Utilizzato per verificare che gli eventi Slack in arrivo siano autentici.';

  @override
  String get userSummary => 'Riepilogo utente';

  @override
  String get username => 'Nome utente';

  @override
  String get usernameOrEmail => 'Nome utente o e-mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'utenti persone ricerca email nome utente amministratore badge team gestito';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Utilizza il modello di chat configurato in Impostazioni';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Utilizzando il runtime NeoAgent installato';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Di solito assomiglia a @bot:matrix.org';

  @override
  String get validEmail => 'e-mail valida';

  @override
  String get value => 'Valore';

  @override
  String get vaultLocked => 'Deposito chiuso a chiave';

  @override
  String get vaultOperationFailed => 'L\'operazione del vault non è riuscita.';

  @override
  String get verification => 'Verifica';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verifica: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verifica: $arg1';
  }

  @override
  String get verificationCompleted => 'Verifica completata.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Stato di verifica: $arg1';
  }

  @override
  String get verifiedTheResult => 'Verificato il risultato';

  @override
  String get verifyingTheDownloadedRuntime => 'Verifica del runtime scaricato';

  @override
  String get versionAndUptime => 'Versione e tempo di attività';

  @override
  String versionArg1(Object? arg1) {
    return 'Versione $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'La versione $arg1 è installata, ma $arg2 è ancora in esecuzione.';
  }

  @override
  String get videoLinks => 'Collegamenti video';

  @override
  String get viewDesktop => 'Visualizza scrivania';

  @override
  String get viewLastRun => 'Visualizza l\'ultima corsa';

  @override
  String get viewLogs => 'Visualizza i registri';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'runtime qemu della CPU della memoria immagine VM';

  @override
  String get voice => 'Voce';

  @override
  String get voiceAssistant => 'Assistente vocale';

  @override
  String get voiceCall => 'CHIAMATA VOCALE';

  @override
  String get voiceCall2 => 'Chiamata vocale';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'chiamata vocale gpt-live gemini modello live discorso in tempo reale';

  @override
  String get voiceCallsRunOnALive =>
      'Le chiamate vocali vengono eseguite su un modello di sintesi vocale dal vivo con la stessa persona, memoria e cronologia chat di NeoAgent. Risponde immediatamente e affida il vero lavoro all\'agente normale, che continua a funzionare in background.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'Chiave API di trascrizione vocale delle note vocali';

  @override
  String get voiceNotesAndDictation => 'Note vocali e dettatura';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'La riproduzione vocale non è disponibile su questo dispositivo.';

  @override
  String get voiceReplyModel => 'Modello di risposta vocale';

  @override
  String get waitingForApproval => 'In attesa di approvazione: ';

  @override
  String get waitingForCode => 'In attesa del codice';

  @override
  String get waitingForInput => 'In attesa di input';

  @override
  String get waitingForServerOrFlutterLog =>
      'In attesa dell\'output del log del server o di Flutter…';

  @override
  String get waitingForTaskEvents => 'In attesa degli eventi dell\'attività...';

  @override
  String get waitingForYou => 'aspettandoti';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Volevo una risposta da $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Vuole parlare con te · ${arg1}s';
  }

  @override
  String get weak => 'Debole';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Meteo, calendario e priorità prima dell\'inizio della giornata.';

  @override
  String get weatherEvent => 'Evento meteorologico';

  @override
  String get web => 'Rete';

  @override
  String get webBrowser => 'Browser Web';

  @override
  String get webSearchApiKey => 'chiave API di ricerca web';

  @override
  String get webhookOrRestChannelPosting =>
      'Pubblicazione di webhook o canali REST';

  @override
  String get webhookSecret => 'Segreto del webhook';

  @override
  String get webhookUrlCopied => 'URL del webhook copiato';

  @override
  String get weekdays => 'Giorni feriali';

  @override
  String get weekdays0730 => 'Giorni feriali · 07:30';

  @override
  String get weekdays1800 => 'Giorni feriali · 18:00';

  @override
  String get weekly => 'Settimanale';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Limite settimanale $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Limite settimanale (token)';

  @override
  String get weeklyReview => 'Revisione settimanale';

  @override
  String get weeklyUsage => 'Utilizzo settimanale';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Record di peso $arg1';
  }

  @override
  String get welcomeToNeoagent => 'BENVENUTO IN NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Benvenuto\nin NeoAgent';

  @override
  String get whatAreYouAdding => 'Cosa stai aggiungendo?';

  @override
  String get whatIsOnTomorrow => 'Cosa c\'è domani?';

  @override
  String get whatShouldNeoagentLearn => 'Cosa dovrebbe imparare NeoAgent?';

  @override
  String get whatShouldWeBuild => 'Cosa dovremmo costruire?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Ciò che tu e NeoAgent dite appare qui e nella chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Messaggio personale WhatsApp ricevuto';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Quando scegli Solo approvati, aggiungi persone o gruppi di seguito.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Dove questo agente dovrebbe inviare le risposte.';

  @override
  String get whoCanMessage => 'Chi può inviare messaggi';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Chi può inviare messaggi su $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Chi può inviare a $arg1 un messaggio uno a uno.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Chi può parlare con $arg1 in un gruppo, canale o stanza.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'chi gestisce questo account disattivato: ';

  @override
  String get whoManagesWhom => 'Chi gestisce chi';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Chiunque accetti un collegamento si unisce al tuo team con i soli strumenti necessari ';

  @override
  String get wholeGroup => 'Intero gruppo';

  @override
  String get wholeGroups => 'Interi gruppi';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Perché $arg1 ha risposto o è rimasto in silenzio nei gruppi $arg2.';
  }

  @override
  String get windowsApp => 'Applicazione Windows';

  @override
  String get windowsNt => 'finestre nt';

  @override
  String get workAccount => 'Conto lavoro';

  @override
  String get workOnAProjectWithNeoagent => 'Lavora su un progetto con NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Flusso di lavoro: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Lavorando in $arg1 sul computer cloud. NeoAgent legge e modifica i file lì e può eseguire comandi e un browser.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Lavorare in background: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Configurazione dell\'area di lavoro e sicurezza dell\'account in un unico posto.';

  @override
  String get workspaceFiles => 'File dell\'area di lavoro';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Area di lavoro, modelli e controlli diagnostici.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'La sostituzione dell\'area di lavoro deve essere un percorso assoluto.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Ha scritto $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'errore xmlhttprequest';

  @override
  String get yesterday => 'Ieri';

  @override
  String get youAreInControl => 'Hai il controllo';

  @override
  String get youCanFollowAlongOnThe => 'Puoi seguirlo sul desktop.';

  @override
  String get youCanLeaveATeamAt =>
      'Puoi lasciare una squadra in qualsiasi momento; le tue impostazioni verranno nuovamente applicate.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Puoi lasciare in qualsiasi momento dalla pagina Team.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Sei tu a decidere quali strumenti può utilizzare il tuo agente, in Impostazioni › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Non gestisci ancora nessuno. Crea un collegamento di invito qui sotto e ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Hai impostazioni non salvate. Cosa ti piacerebbe fare?';

  @override
  String get youReOnYourOwnYou =>
      'Sei libero: decidi quali strumenti può utilizzare il tuo agente. Se ';

  @override
  String get yourAccountAndUsageOnA =>
      'il tuo account e l\'utilizzo su un modello supportato dalla tua chiave ';

  @override
  String get yourAccountHasBeenDeleted => 'Il tuo account è stato eliminato.';

  @override
  String get yourAgentWillBeAllowed => 'Al tuo agente sarà consentito:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Le tue app e i tuoi file vengono salvati.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Le tue app e i tuoi file rimangono salvati.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'La tua chiave $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Il tuo livello di assistente per l\'acquisizione, il contesto e l\'azione.';

  @override
  String get yourComputerIsAsleep =>
      'Il tuo computer è in modalità sospensione';

  @override
  String get yourComputerIsOff => 'Il tuo computer è spento';

  @override
  String get yourComputerIsReady => 'Il tuo computer è pronto';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'La tua password attuale non è corretta.';

  @override
  String get yourData => 'I tuoi dati';

  @override
  String get yourDataExportWasCopiedTo =>
      'L\'esportazione dei dati è stata copiata negli appunti.';

  @override
  String get yourDesktopIsReady => 'Il tuo desktop è pronto';

  @override
  String get yourLinuxComputer => 'Il tuo computer Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'La tua posizione non viene mai tracciata continuamente o memorizzata sui nostri server. Lo utilizziamo solo localmente per verificare le tue attività attive.';

  @override
  String get yourManager => 'il tuo manager';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'L\'URL del tuo sito Mattermost, se utilizzi l\'API REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'La tua sessione è scaduta o non è stata conservata dal browser. Per favore accedi di nuovo.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'La tua sessione è scaduta. Per favore accedi di nuovo.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Il tuo nome utente o la tua password non sono corretti.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook TouchID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personale';

  @override
  String get sectionOverview => 'Panoramica';

  @override
  String get sectionDiagnostics => 'Diagnostica';

  @override
  String get sectionVolume => 'Volume';

  @override
  String get sectionSession => 'Sessione';

  @override
  String get sectionDeliverable => 'Consegnabile';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Il runtime locale non ha ancora scritto un file di registro.';

  @override
  String get thisComputer => 'Questo computer';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'La versione beta installa il backend pre-release più recente. Aspettatevi bordi irregolari.';

  @override
  String get copiedFinalResponse => 'Risposta finale copiata';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'La risposta finale viene visualizzata qui al termine dell\'esecuzione.';

  @override
  String get waitingForTheFirstStep => 'In attesa del primo passo…';

  @override
  String get loadingPrompt => 'Richiesta di caricamento…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Per questa esecuzione non è stata acquisita alcuna risposta finale.';

  @override
  String get readyToSignIn => 'Pronto per accedere';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Passa a \"Predefinito\" o \"Chiedi sempre\" per riattivare i controlli di approvazione.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Invia un aggiornamento sullo sterzo o una nota successiva per la corsa corrente...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Nessuna connessione di rete. NeoAgent si ricollegherà quando il dispositivo sarà di nuovo online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Applicato l\'ultimo aggiornamento dello sterzo alla corsa corrente.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Preparazione della sessione vocale privata…';

  @override
  String get preparingYourComputer => 'Preparazione del computer';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent sta scaricando e preparando il sistema Linux sicuro. Questo accade solo la prima volta.';

  @override
  String get moreFreeSpaceIsNeeded => 'È necessario più spazio libero';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Liberare spazio su disco sull\'host NeoAgent, quindi riprovare. I dati del tuo computer esistente sono al sicuro.';

  @override
  String get androidReady => 'Pronto per Android';

  @override
  String get startingAndroid2 => 'Avvio di Android…';

  @override
  String get androidStopped => 'Android si è fermato';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Al primo avvio vengono scaricati l\'SDK di Android e l\'immagine di sistema, l\'operazione può richiedere diversi minuti.';

  @override
  String get androidIsStopped => 'Android è fermo';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Avvia l\'ambiente Android gestito quando ne hai bisogno.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Lascia che NeoAgent funzioni su questo computer';

  @override
  String get firstTimeSetupIsInProgress =>
      'È in corso la configurazione iniziale.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent può utilizzare l\'accesso consentito.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Liberare spazio di archiviazione sull\'host e riprovare.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Inizia quando vuoi che NeoAgent ti aiuti qui.';

  @override
  String get systemPermissionMissing => 'Manca l\'autorizzazione di sistema';

  @override
  String get connectingThisDevice => 'Collegamento di questo dispositivo';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'È in corso la creazione della connessione locale protetta.';

  @override
  String get recordingYourDemonstration => 'Registrare la tua dimostrazione';

  @override
  String get noErrorsInTheRecentLog => 'Nessun errore nel registro recente.';

  @override
  String get loadingAccounts => 'Caricamento account…';

  @override
  String get neverSignedIn => 'Mai effettuato l\'accesso';

  @override
  String get emptyUsesTheServerDefault =>
      'Vuoto utilizza l\'impostazione predefinita del server.';

  @override
  String get followTheSelectedSession => 'Segui la sessione selezionata';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'La modalità Plan effettua solo l\'ispezione. Passa alla modalità Agente per consentire a NeoAgent di modificare i file.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Necessario per aggiungere o modificare l\'e-mail del tuo account.';

  @override
  String get confirmNewPassword => 'Conferma la nuova password';

  @override
  String get passwordChanged => 'La password è cambiata.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Questa richiesta è già stata utilizzata.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Questa richiesta è scaduta. Chiedi all\'altro dispositivo di generare un nuovo codice.';

  @override
  String get startQuickstart => 'Avvia l\'avvio rapido';

  @override
  String get createYourAccount => 'Crea il tuo account';

  @override
  String get showWorkAsSummaries => 'Mostra il lavoro come riepilogo';

  @override
  String get tokensUsedByTheLatestRun =>
      'Token utilizzati dall\'ultima esecuzione';

  @override
  String get listedTheWorkspaceRoot =>
      'Elencata la radice dell\'area di lavoro';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Non sono ancora disponibili integrazioni ufficiali.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Nessun server MCP ancora configurato. Aggiungine uno per esporre i suoi strumenti.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Aggiungi un server MCP o installa una competenza per iniziare.';

  @override
  String get setUp => 'Configura';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Lasciare vuoto per mantenere il valore memorizzato';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Ciò rimuove l\'indirizzo per ogni account su questo server.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Parla e basta. Puoi interrompere in qualsiasi momento. Tocca per disattivare l\'audio.';

  @override
  String get tapAgainWhenYouAreDone => 'Tocca di nuovo quando hai finito.';

  @override
  String get workingOnATaskInTheBackground =>
      'Lavorare su un\'attività in background.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Discorso a voce con la stessa memoria, strumenti e cronologia chat di NeoAgent.';

  @override
  String get checkLink => 'Controlla il collegamento';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Al tuo agente non sarà consentito nessuno degli strumenti controllati.';

  @override
  String get notYoursToChange => 'Non spetta a te cambiare';

  @override
  String get setByYou => 'Impostato da te';

  @override
  String get noTools => 'Nessuno strumento';

  @override
  String get untitledLink => 'Collegamento senza titolo';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Smette di funzionare dopo che una persona lo ha riscattato.';

  @override
  String get theOperator => 'L\'operatore';

  @override
  String get smartSelectorOn => 'Selettore intelligente attivo';

  @override
  String get startASessionToBegin => 'Avvia una sessione per iniziare';

  @override
  String get steerTheActiveRun => 'Guida la corsa attiva...';

  @override
  String get describeWhatToPlan => 'Descrivi cosa pianificare...';

  @override
  String get stopDictation => 'Interrompi la dettatura';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'I messaggi guidano la corsa corrente · ⌘↵ invia · ⌘. fermare';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'La modalità Pianificazione esegue solo l\'ispezione; nulla viene cambiato finché non implementi · ⌘↵ send';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'L\'agente modifica l\'area di lavoro. Il piano effettua solo ispezioni.';

  @override
  String get defaultModel => 'Modello predefinito';

  @override
  String get openingScanner => 'Apertura dello scanner...';

  @override
  String get theAgentCanUseThisSkill =>
      'L\'agente può utilizzare questa abilità.';

  @override
  String get allSelected => 'Tutti selezionati';

  @override
  String get addCoreMemoryEntry => 'Aggiungi voce memoria principale';

  @override
  String get channelId => 'ID del canale';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Le attività create dall\'intelligenza artificiale e non specificate utilizzano l\'impostazione predefinita corrente.';

  @override
  String get waitingForRunEvents => 'In attesa degli eventi di corsa...';

  @override
  String get hideSteps => 'Nascondi passaggi';

  @override
  String get commitTheActiveLiveCapture =>
      'Impegna l\'acquisizione live attiva';

  @override
  String get stopCaptureAndSubmit => 'Interrompi l\'acquisizione e invia';

  @override
  String get clickTheMicToStartSpeaking =>
      'Fai clic sul microfono per iniziare a parlare';

  @override
  String get connectACustomEndpoint => 'Connetti un endpoint personalizzato';

  @override
  String get hostedProvider => 'fornitore ospitato.';

  @override
  String get muted => ' • disattivato';

  @override
  String get addWhoCanMessage => 'Aggiungi chi può inviare messaggi';

  @override
  String get joinsGroupConversations =>
      'Si unisce alle conversazioni di gruppo';

  @override
  String get label1PersonOrGroupAdded => '1 persona o gruppo aggiunto';

  @override
  String get inProgress => 'In corso';

  @override
  String get waitingForUpdateJobOutput =>
      'In attesa dell\'output del lavoro di aggiornamento...';

  @override
  String get taskTrigger => 'Trigger dell\'attività';

  @override
  String get bearerToken => 'Gettone al portatore';

  @override
  String get bearerToken2 => 'Gettone del portatore';

  @override
  String get notRecorded => 'Non registrato';

  @override
  String get sessionCookie => 'Cookie di sessione';

  @override
  String get neverUsed => 'Mai usato';

  @override
  String get linkedRecently => 'Collegato di recente';

  @override
  String get notUsedYet => 'Non ancora utilizzato';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Uno o più account sono scaduti. Riconnettiti per ripristinare l\'accesso. Se il problema persiste, la tua app Google Cloud OAuth potrebbe essere in modalità di test: pubblicala in Produzione in Google Cloud Console per ottenere token di lunga durata.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault connesso e disponibile dopo il riavvio';

  @override
  String get vaultConnectedForThisSession =>
      'Vault connesso per questa sessione';

  @override
  String get connectAnotherAccount => 'Connetti un altro account';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Incolla il token di accesso a lunga durata sostitutivo';

  @override
  String get updateInstance => 'Aggiorna istanza';

  @override
  String get pasteAReplacementToken => 'Incolla un token sostitutivo';

  @override
  String get replaceAccount => 'Sostituisci conto';

  @override
  String get addAccount => 'Aggiungi account';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Può delegare a qualsiasi agente ricevente';

  @override
  String get canReceiveDelegatedTasks2 => 'possono ricevere compiti delegati';

  @override
  String get noSyncYet => 'Nessuna sincronizzazione ancora';

  @override
  String get noNewData => 'Nessun nuovo dato';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sincronizza una volta per eseguire il seeding del tuo backend.';

  @override
  String get lastWindowEndIsUnknown =>
      'La fine dell\'ultima finestra è sconosciuta.';

  @override
  String get lastNonEmptySync => 'Ultima sincronizzazione non vuota';

  @override
  String get stopTranscribe => 'Interrompi e trascrivi';

  @override
  String get steeringMode => 'Modalità di sterzo';

  @override
  String get noMessageText => 'Nessun testo del messaggio';

  @override
  String get reconnectingToServer => 'Riconnessione al server…';

  @override
  String get signingIn => 'Accesso...';

  @override
  String get noGroupsFoundYet => 'Nessun gruppo ancora trovato';

  @override
  String get onForNewGroupsOnly => 'Attivo solo per i nuovi gruppi';

  @override
  String get noGroupsInThisCategory => 'Nessun gruppo in questa categoria';

  @override
  String get groupOrChannel => 'Gruppo o canale';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Le note che scrivi a te stesso iniziano una corsa e le risposte arrivano nella stessa chat. La lista consentita non si applica qui.';

  @override
  String get needToReply => 'Ho bisogno di rispondere';

  @override
  String get enter2faCode => 'Inserisci il codice 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Apri l\'app di autenticazione e inserisci il codice NeoAgent corrente.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Hai già un account? Accedi';

  @override
  String get serverOnThisComputer => 'Server su questo computer';

  @override
  String get showQrCode => 'Mostra il codice QR';

  @override
  String get createAnotherNeoagentAccount => 'Crea un altro account NeoAgent.';

  @override
  String get canCoordinateDelegatedWork => 'Può coordinare il lavoro delegato';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Impossibile estrarre l\'archivio runtime NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Impossibile leggere l\'archivio runtime NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'L\'archivio runtime NeoAgent contiene un percorso non sicuro.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'L\'archivio runtime NeoAgent contiene un collegamento non sicuro.';

  @override
  String get installingAppPackageOnThePhone =>
      'Installazione del pacchetto app sul telefono...';

  @override
  String get dragAndDropAApkOrApks =>
      'Trascina e rilascia un file .apk o .apks qui oppure fai clic per sfogliarlo.';

  @override
  String get releaseToInstallThisPackage =>
      'Rilascia per installare questo pacchetto';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Impossibile utilizzare la chiave di sicurezza.';

  @override
  String get connecting => 'Connessione…';

  @override
  String get changes => 'Cambiamenti';

  @override
  String get runtimeReady => 'Pronto per l\'esecuzione';

  @override
  String get saving => 'Salvataggio...';

  @override
  String get earlier => 'In precedenza';

  @override
  String get monthJan => 'Gen';

  @override
  String get monthFeb => 'Febbraio';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'aprile';

  @override
  String get monthMay => 'Maggio';

  @override
  String get monthJun => 'giugno';

  @override
  String get monthJul => 'Lug';

  @override
  String get monthAug => 'Agosto';

  @override
  String get monthSep => 'Settembre';

  @override
  String get monthOct => 'ottobre';

  @override
  String get monthNov => 'novembre';

  @override
  String get monthDec => 'dicembre';

  @override
  String get steeringWord => 'Sterzo';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Ciò cambia il backend dal canale $arg1 al canale $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Cookie $arg1 importati';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s fa';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Sterzo in coda: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'L\'app Web non è riuscita a raggiungere il backend NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Il browser ha bloccato una richiesta obbligatoria a causa della politica di sicurezza dei contenuti.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 di 4 consentiti';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Svolgi l\'attività come faresti normalmente.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Modifiche · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Questo dispositivo · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limite raggiunto$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'I codici di ripristino $arg1 sono ancora disponibili.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Chiave di sicurezza $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Sessione corrente';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nUltimo utilizzo: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Lavoro in $arg1 su questo dispositivo. NeoAgent legge e modifica direttamente la cartella e può eseguire comandi, aprire app e utilizzare lo schermo.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Ha lavorato per $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Consentito da $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'I collegamenti di invito $arg1 da $arg2 sono stati revocati';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Aggiungi le persone e i gruppi con cui $arg1 dovrebbe parlare';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Aggiungi le persone e i gruppi con cui $arg1 può parlare.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Dove $arg1 ascolta';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 controlla questi luoghi per le menzioni. Chiunque può postare qui, quindi le persone necessitano comunque della propria approvazione di seguito.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Queste persone possono chiedere $arg1 ovunque lo tagghino. I ruoli contano solo nei luoghi sopra elencati.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Solo quando viene taggato $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Attivo per tutti i gruppi $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 continua a sentire solo le persone e i gruppi che hai già approvato. Ciò consente semplicemente a $arg1 di partecipare alla normale chat lì, non solo ai tag e alle risposte.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 continua a sentire solo le persone e i gruppi che hai già approvato. Questo sceglie semplicemente a quale di questi gruppi dovrebbe unirsi.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Se qualcuno tagga $arg1 o risponde, $arg1 risponde sempre. Attiva questa opzione se $arg1 deve intervenire anche nella normale chat di gruppo.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'I nuovi gruppi consentiranno a $arg1 di partecipare alla chat ordinaria con persone approvate, finché non li disattivi.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'I nuovi gruppi consentiranno a $arg1 di partecipare alla chat ordinaria finché non li disattiverai.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'I nuovi gruppi restano silenziosi a meno che una persona approvata non tagghi $arg1, finché non li attivi.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Solo quando una persona approvata tagga $arg1, a meno che non attivi un gruppo';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Solo quando viene taggato $arg1, a meno che non attivi un gruppo';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return 'I gruppi $arg1 dei $arg2 si uniscono alla chat ordinaria con persone approvate';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Questo non approva le nuove persone. I tag e le risposte delle persone approvate ricevono sempre una risposta. Attiva un gruppo se anche $arg1 deve unirsi alla chat ordinaria lì.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Questo non approva le nuove persone. Attiva un gruppo se $arg1 deve unirsi alla chat ordinaria con persone che hai già approvato.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'I tag e le risposte ricevono sempre una risposta. Attiva un gruppo se anche $arg1 deve unirsi alla chat ordinaria lì.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 si unisce alla chat ordinaria con persone approvate';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 può partecipare alla chat ordinaria';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 risponde solo quando una persona approvata lo tagga';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Non è necessario nulla in più. Connettiti per iniziare a utilizzare $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Si aggiorna in ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registrati con $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Nessun ricordo legato a \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (predefinito)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filiale: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 si unisce solo ai gruppi e ai canali che aggiungi di seguito.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 è necessario per individuare i dati di runtime di NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[anteprima troncata, $arg1 byte totali]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefatto limitato, $arg1 byte totali]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' a $arg1';
  }

  @override
  String get worldNews => 'Notizie dal mondo';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Esegui quando compaiono nuovi titoli mondiali. Il tuo messaggio decide se notificarti.';

  @override
  String get newsKeywordsOptional => 'Parole chiave (facoltative)';

  @override
  String get worldNewsSetup => 'Impostazione delle notizie dal mondo';

  @override
  String get connectWorldNewsWithGnews =>
      'Aggiungi una chiave API GNews (piano gratuito disponibile su gnews.io). Viene archiviato crittografato e utilizzato per sondare i titoli principali per i trigger di World News.';

  @override
  String get gnewsApiKey => 'Chiave API GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Incolla la chiave API GNews sostitutiva';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Lasciare la chiave vuota per mantenere la chiave attualmente memorizzata.';

  @override
  String get gnewsApiKeyIsRequired => 'È richiesta una chiave API GNews.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Impossibile salvare la configurazione di World News.';

  @override
  String get disconnectWorldNews => 'Disconnetti le notizie dal mondo';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Ciò rimuove la chiave API GNews memorizzata. I trigger di World News smetteranno di attivarsi finché non aggiungerai nuovamente una chiave.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Impossibile disconnettere World News.';

  @override
  String get systemOneModels => 'Modelli SystemOne';

  @override
  String get systemOneAuto => 'Automatico';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Sceglie il miglior modello SystemOne disponibile';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Il modello di chat prende queste decisioni';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modelli decisionali che effettuano le chiamate dietro le quinte in una frazione di secondo: turni nelle chat di gruppo e passaggi nel browser. Il tuo modello di chat scrive comunque ogni risposta.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Il modello SystemOne decide quando parlare mentre è acceso; questo modello è il fallback.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 segnato da SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne ha segnato direttamente questo messaggio. Nessun modello linguistico funzionava.';

  @override
  String get systemOneUnavailable => 'SystemOne non disponibile';

  @override
  String get systemOneAdminAvailability =>
      'I modelli decisionali che gli agenti possono scegliere in Impostazioni › Modelli. Un modello disattivato qui lascia quel selettore e gli agenti che lo hanno scelto ricadono su Auto. Mentre qualsiasi modello è spento, anche i modelli SystemOne che i fornitori aggiungono in seguito si avviano spenti.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Nessun modello SystemOne ancora. Aggiungi una chiave TypeSafe o OpenRouter in Provider o esegui il pull di un modello decisionale come nimble in Ollama 0.35 o versione successiva.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Nessun modello SystemOne è ancora disponibile. Aggiungi una chiave TypeSafe o OpenRouter in Impostazioni › Modelli › Porta la tua chiave o utilizza un modello decisionale come agile in Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistema uno modelli decisionali jev typesafe openrouter ollama disponibilità abilita disabilita';

  @override
  String get chatModels => 'Modelli di chat';

  @override
  String get disabled => 'Disabilitato';

  @override
  String get enableShown => 'Abilita mostrato';

  @override
  String get disableShown => 'Disattiva mostrato';

  @override
  String get expandAll => 'Espandi tutto';

  @override
  String get collapseAll => 'Comprimi tutto';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 modifiche non salvate';
  }

  @override
  String get settingsScopeAllAgents => 'Tutti gli agenti';

  @override
  String get settingsScopeAgent => 'Questo agente';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'Lo stesso ovunque accedi';

  @override
  String get settingsScopeAllAgentsHint => 'Condiviso da tutti i tuoi agenti';

  @override
  String get settingsAppliesTo => 'Si applica a';

  @override
  String get settingsSaving => 'Salvataggio…';

  @override
  String get settingsSavedAutomatically =>
      'Le modifiche vengono salvate automaticamente';

  @override
  String get settingsSearchHint => 'Cerca tutte le impostazioni';

  @override
  String get settingsPageProfile => 'Profilo';

  @override
  String get settingsPageSecurity => 'Accesso e sicurezza';

  @override
  String get settingsPageUsage => 'Utilizzo';

  @override
  String get settingsPagePermissions => 'Autorizzazioni';

  @override
  String get settingsPageComputer => 'Informatica e rete';

  @override
  String get settingsPageBehavior => 'Comportamento';

  @override
  String get settingsPageSystem => 'Sistema';

  @override
  String get settingsPagePlatforms => 'Piattaforme';

  @override
  String get settingsPageProfileDescription =>
      'Il tuo nome ed email, una copia dei tuoi dati e la disconnessione.';

  @override
  String get settingsPageSecurityDescription =>
      'Password, autenticazione a due fattori, chiavi di sicurezza e dove hai effettuato l\'accesso.';

  @override
  String get settingsPageUsageDescription =>
      'I tuoi limiti e la spesa in token, tutto in un unico posto.';

  @override
  String get settingsPageAgentsDescription =>
      'Crea agenti e scegli quale risponde per impostazione predefinita.';

  @override
  String get settingsPagePermissionsDescription =>
      'Cosa possono fare i tuoi agenti senza prima chiedertelo.';

  @override
  String get settingsPageComputerDescription =>
      'Il computer su cui lavorano i tuoi agenti e i siti che possono leggere come te.';

  @override
  String get settingsPageModelsDescription =>
      'Quali modelli utilizza questo agente e le chiavi API che ne consentono il pagamento.';

  @override
  String get settingsPageBehaviorDescription =>
      'Come parla questo agente e come legge una chat di gruppo.';

  @override
  String get settingsPageVoiceDescription =>
      'Chiamate in tempo reale, dettatura e risposte vocali per questo agente.';

  @override
  String get settingsPageMessagingDescription =>
      'Dove le persone possono raggiungere questo agente e come si comporta nelle chat.';

  @override
  String get settingsPageGeneralDescription =>
      'Aspetto, lingua, fuso orario e cosa fa questa app in background.';

  @override
  String get settingsPageSystemDescription =>
      'Il server utilizzato da questa finestra, quello su questo computer e gli aggiornamenti dell\'app.';

  @override
  String get settingsYourAgents => 'I tuoi agenti';

  @override
  String get settingsChatModel => 'Modello di chat';

  @override
  String get settingsChatModelDescription => 'Risponde ai tuoi messaggi.';

  @override
  String get settingsSubAgentModel => 'Modello del sub-agente';

  @override
  String get settingsSubAgentModelDescription =>
      'Esegue il lavoro assegnato durante un\'attività.';

  @override
  String get settingsDefaultModels => 'Modelli predefiniti';

  @override
  String get settingsDefaultModelsDescription =>
      'Utilizzato ogni volta che una chat o un\'attività non sceglie il proprio modello.';

  @override
  String get settingsModelPool => 'Piscina modello';

  @override
  String get settingsApiKeysDescription =>
      'Utilizza le tue chiavi o endpoint per questo agente. Le chiavi vengono crittografate e mai più mostrate.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Messa a punto';

  @override
  String get settingsFineTuningDescription =>
      'Raramente necessario. Le impostazioni predefinite si adattano alla maggior parte delle chat.';

  @override
  String get settingsShow => 'Mostra';

  @override
  String get settingsHide => 'Nasconditi';

  @override
  String get settingsMinimumContribution => 'Valore minimo del contributo';

  @override
  String get settingsBatchWindow => 'Finestra batch della stanza';

  @override
  String get settingsBatchWindowDescription =>
      'Aspetta così a lungo per trattare i messaggi rapidi come un turno.';

  @override
  String get settingsHandsFree => 'A mani libere';

  @override
  String get settingsHandsFreeDescription =>
      'Parla liberamente e interrompi in qualsiasi momento.';

  @override
  String get settingsPushToTalkDescription =>
      'Tieni premuto per parlare, rilascia per inviare.';

  @override
  String get settingsLiveVoice => 'Voce dal vivo';

  @override
  String get settingsChannels => 'Canali';

  @override
  String get settingsGroupChats => 'Nelle chat di gruppo';

  @override
  String get settingsGroupChatsDescription =>
      'Come si comporta questo agente in gruppi su ogni canale.';

  @override
  String get settingsGroupChatsDisabled =>
      'Attiva i moduli di comportamento in Comportamento per modificarli.';

  @override
  String get settingsParticipationAutomatic => 'Automatico';

  @override
  String get settingsParticipationMentionOnly => 'Solo menzione';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Legge la stanza e si unisce quando ha qualcosa di utile da aggiungere.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Risponde solo quando menzionato o a cui viene risposto.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Risposte ad ogni messaggio.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Divide le risposte più lunghe in messaggi brevi, come farebbe una persona.';

  @override
  String get settingsDeliverySingleDescription =>
      'Invia ciascuna risposta come un unico messaggio.';

  @override
  String get settingsComputerStatus => 'Stato';

  @override
  String get settingsTest => 'Prova';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Chiaro';

  @override
  String get settingsThemeDark => 'Scuro';

  @override
  String get settingsCloseWindow => 'Quando chiudi la finestra';

  @override
  String get settingsCloseAsk => 'Chiedi';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent continua a funzionare in background e rimane raggiungibile.';

  @override
  String get settingsCloseQuitDescription =>
      'NeoAgent si chiude completamente.';

  @override
  String get settingsPhoneTriggers => 'Trigger del telefono';

  @override
  String get settingsPhoneTriggersDescription =>
      'Segnali che questo telefono invia ai tuoi agenti in modo che le attività possano reagire.';

  @override
  String get settingsLocationTriggers => 'Trigger di posizione';

  @override
  String get settingsLocationTriggersDescription =>
      'Controlla la tua posizione approssimativa ogni pochi minuti rispetto ai luoghi monitorati dalle tue attività.';

  @override
  String get settingsNotificationTriggers => 'Si attiva la notifica';

  @override
  String get settingsNotificationTriggersDescription =>
      'Inoltra le notifiche di altre app su questo telefono ai tuoi agenti.';

  @override
  String get settingsSetup => 'Installazione';

  @override
  String get settingsOnboarding => 'Onboarding';

  @override
  String get settingsOnboardingDescription =>
      'Esegui nuovamente la configurazione di prima esecuzione. Niente di ciò che hai impostato va perso.';

  @override
  String get settingsUsernameDescription =>
      'Utilizzato per accedere. Non può essere modificato.';

  @override
  String get settingsExport => 'Esportazione';

  @override
  String get settingsLeave => 'Esci ed elimina';

  @override
  String get settingsSignOutDescription =>
      'Ti disconnette solo su questo dispositivo.';

  @override
  String get settingsDeleteAccountDescription =>
      'Cancella il tuo account, agenti, memoria e impostazioni. L\'operazione non può essere annullata.';

  @override
  String get settingsTokenUsage => 'Utilizzo dei gettoni';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Nessuna impostazione corrisponde a “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati',
      one: '$count risultato',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Impostazioni avanzate del modello';

  @override
  String get settingsAdvancedModelsDescription =>
      'Facoltativo. Aggiungi un modello a un tipo di lavoro; subentra ogni volta che l\'agente utilizza tali strumenti. Tutto ciò che viene lasciato per impostazione predefinita segue il modello di chat.';

  @override
  String get settingsTaskModelDefault => 'Predefinito';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Segue il modello della chat';

  @override
  String get settingsTaskModelCoding => 'Codifica';

  @override
  String get settingsTaskModelCodingDescription =>
      'Scrittura, modifica e debug del codice.';

  @override
  String get settingsTaskModelComputerUse => 'Uso del computer';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Guidare il browser e il desktop.';

  @override
  String get settingsTaskModelAndroidUse => 'Utilizzo di Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Utilizzo di app su un dispositivo o emulatore Android.';

  @override
  String get settingsTaskModelResearch => 'Ricerca';

  @override
  String get settingsTaskModelResearchDescription =>
      'Ricerca, lettura e sintesi delle fonti.';

  @override
  String get knowledgeGraphHint =>
      'Le tue entità più menzionate, colorate per cluster. Le linee collegano entità che compaiono negli stessi ricordi. Toccane uno per vederne i collegamenti e i ricordi; trascina per eseguire la panoramica, pizzica o Ctrl/⌘-scorri per ingrandire.';

  @override
  String get linkedEntities => 'Enti collegati';

  @override
  String get noLinkedEntities => 'Non ancora collegato ad altre entità.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 menziona';
  }

  @override
  String get entityKindConcept => 'Concetto';

  @override
  String get entityKindDomain => 'Dominio';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Collegamento';

  @override
  String get entityKindFile => 'Archivio';

  @override
  String get entityKindAcronym => 'Acronimo';

  @override
  String get entityKindIdentifier => 'Identificatore';

  @override
  String get entityKindVersion => 'Versione';

  @override
  String get openFullscreen => 'Apri a schermo intero';

  @override
  String get zoomIn => 'Ingrandisci';

  @override
  String get zoomOut => 'Rimpicciolisci';

  @override
  String get searchEntities => 'Trova un\'entità';

  @override
  String get incomingCall => 'Chiamata in arrivo';

  @override
  String get answerCall => 'Rispondi';

  @override
  String get callMeLater => 'Chiamami più tardi';

  @override
  String get callingEllipsis => 'Chiamando…';

  @override
  String get reconnectingCall => 'Riconnessione';

  @override
  String get agentWorking => 'Funzionante';

  @override
  String get micMuted => 'Disattivato';

  @override
  String get speakerphone => 'Altoparlante';

  @override
  String get muteMic => 'Muto';

  @override
  String get unmuteMic => 'Riattiva';

  @override
  String get releaseToSend => 'Rilascia per inviare';

  @override
  String get callEnded => 'Chiamata terminata';

  @override
  String get openConversation => 'Conversazione aperta';

  @override
  String get callBack => 'Richiama';

  @override
  String get letCallsReachYou => 'Lascia che le chiamate ti raggiungano';

  @override
  String get callPermissionsIntro =>
      'I tuoi agenti possono chiamarti. Per squillare come una telefonata mentre NeoAgent è in background o il telefono è bloccato, ha bisogno di questi.';

  @override
  String get showOverOtherApps => 'Mostra su altre app';

  @override
  String get showOverOtherAppsDetail =>
      'Visualizza la schermata della chiamata ovunque tu sia.';

  @override
  String get fullScreenCalls => 'Chiamate a schermo intero';

  @override
  String get fullScreenCallsDetail => 'Suona sulla schermata di blocco.';

  @override
  String get unrestrictedBattery => 'Batteria illimitata';

  @override
  String get unrestrictedBatteryDetail =>
      'Mantiene NeoAgent connesso in modo che le chiamate arrivino.';

  @override
  String get permissionAllowed => 'Consentito';

  @override
  String get triggerSectionCalendar => 'Calendario';

  @override
  String get triggerSectionFiles => 'File e documenti';

  @override
  String get triggerSectionHome => 'Casa e media';

  @override
  String get triggerSectionDevices => 'Dispositivi e luoghi';

  @override
  String get triggerSectionTasks => 'Compiti';

  @override
  String get messagingMemberJoined => 'Membro iscritto';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Esegui quando qualcuno si unisce a un server Discord, a un gruppo Telegram o WhatsApp, a un canale Slack o a una stanza Matrix.';

  @override
  String get messagingMemberLeft => 'Il membro se n\'è andato';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Esegui quando qualcuno lascia un server Discord, un gruppo Telegram o WhatsApp, un canale Slack o una stanza Matrix.';

  @override
  String get messagingReactionAdded => 'Reazione aggiunta';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Esegui quando una persona autorizzata reagisce a un messaggio in una chat privata.';

  @override
  String get messagingPlatformDisconnected => 'Messaggistica disconnessa';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Esegui quando una connessione di messaggistica si interrompe e ha bisogno di te, ad esempio dopo un logout.';

  @override
  String get googleCalendarEventStarting =>
      'Avvio dell\'evento di Google Calendar';

  @override
  String get googleCalendarEventCreated => 'Evento di Google Calendar creato';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Esegui quando viene visualizzato un nuovo evento o invito.';

  @override
  String get outlookCalendarEventStarting =>
      'Avvio dell\'evento del calendario di Outlook';

  @override
  String get nextcloudCalendarEventStarting =>
      'Avvio dell\'evento del calendario Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Esegui un determinato numero di minuti prima di ogni evento.';

  @override
  String get googleDriveFileAdded => 'File di Google Drive aggiunto';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Esegui quando un file viene aggiunto a Drive o a una cartella al suo interno.';

  @override
  String get googleSheetsRowAdded => 'Aggiunta riga di Fogli Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Esegui quando vengono visualizzate nuove righe in un foglio.';

  @override
  String get onedriveFileAdded => 'File OneDrive aggiunto';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Esegui quando un file viene aggiunto a una cartella OneDrive.';

  @override
  String get nextcloudFileAdded => 'File Nextcloud aggiunto';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Esegui quando un file viene aggiunto a una cartella Nextcloud.';

  @override
  String get nextcloudShareReceived => 'File Nextcloud condiviso con te';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Esegui quando qualcuno condivide un file o una cartella con te.';

  @override
  String get notionItemAdded => 'Aggiunto elemento del database delle nozioni';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Esegui quando un elemento viene aggiunto a un database Notion.';

  @override
  String get notionItemUpdated =>
      'Elemento del database delle nozioni aggiornato';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Esegui quando un elemento in un database Notion cambia.';

  @override
  String get trelloCardEnteredList => 'Scheda Trello aggiunta all\'elenco';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Esegui quando una carta viene creata o spostata in un elenco.';

  @override
  String get figmaCommentAdded => 'Commento Figma aggiunto';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Esegui quando qualcuno commenta un file Figma.';

  @override
  String get githubPrOpened => 'Richiesta pull GitHub aperta';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Esegui quando viene aperta una nuova richiesta pull in un repository.';

  @override
  String get githubWorkflowRunFailed =>
      'L\'esecuzione del flusso di lavoro GitHub non è riuscita';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Esegui quando l\'esecuzione di GitHub Actions fallisce.';

  @override
  String get githubCommitPushed => 'Commit GitHub inviato';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Esegui quando i nuovi commit raggiungono un ramo.';

  @override
  String get mcpServerFailed => 'Il server MCP non è riuscito';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Esegui quando un server MCP funzionante si guasta o richiede l\'accesso.';

  @override
  String get homeAssistantStateChanged =>
      'Lo stato dell\'Assistente domestico è cambiato';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Esegui quando un\'entità cambia, raggiunge uno stato o supera un valore.';

  @override
  String get spotifyTrackChanged => 'La traccia Spotify è cambiata';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Esegui quando inizia la riproduzione di un brano diverso.';

  @override
  String get neorecallDailySummaryReady =>
      'Riepilogo giornaliero NeoRecall pronto';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Esegui quando il riepilogo di una giornata è definitivo.';

  @override
  String get neorecallConversationRecorded =>
      'Conversazione NeoRecall registrata';

  @override
  String get runWhenARecordedConversationEnds =>
      'Esegui al termine di una conversazione registrata.';

  @override
  String get geofenceTrigger => 'Geofence della posizione';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Esegui quando il tuo telefono arriva o lascia un luogo. Necessita del rilevamento della posizione sul telefono.';

  @override
  String get healthMetricRecorded => 'Metrica sanitaria registrata';

  @override
  String get runWhenAHealthReadingArrives =>
      'Esegui quando arriva una lettura della salute sincronizzata, facoltativamente al di sopra o al di sotto di un valore.';

  @override
  String get wearableConnectionChanged => 'Indossabile connesso o disconnesso';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Esegui quando il tuo dispositivo indossabile si connette o si disconnette.';

  @override
  String get taskRunFinished => 'Un altro compito è terminato';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Esegui dopo che un\'altra attività termina, ha esito positivo o fallisce.';

  @override
  String get appPackageOptional => 'Pacchetto app (facoltativo)';

  @override
  String get appPackageHelper => 'Ad esempio com.whatsapp';

  @override
  String get anyPlatform => 'Qualsiasi piattaforma';

  @override
  String get spaceIdOptional =>
      'ID server, gruppo, canale o sala (facoltativo)';

  @override
  String get spaceIdHelper => 'Svuota gli orologi in cui si trova il bot.';

  @override
  String get emojiOptional => 'Emoji (facoltativo)';

  @override
  String get chatIdOptional => 'ID chat (facoltativo)';

  @override
  String get platformOptional => 'Piattaforma (opzionale)';

  @override
  String get platformOptionalHelper =>
      'Ad esempio Whatsapp. Vuoto guarda tutto.';

  @override
  String get minutesBefore => 'Minuti prima';

  @override
  String get calendarIdOptional => 'ID calendario (facoltativo)';

  @override
  String get calendarIdHelper => 'Vuoto utilizza il tuo calendario principale.';

  @override
  String get invitesOnly => 'Solo inviti da altri';

  @override
  String get nextcloudCalendarPath => 'Calendario';

  @override
  String get nextcloudCalendarPathHelper =>
      'Il suo nome nell\'elenco dei calendari Nextcloud, ad esempio personale';

  @override
  String get folderIdOptionalHelperDrive => 'Vuoto osserva tutta Drive.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Vuoto controlla la cartella principale.';

  @override
  String get driveFolderIdOptional => 'ID cartella (facoltativo)';

  @override
  String get spreadsheetId => 'ID del foglio di calcolo';

  @override
  String get sheetRange => 'Gamma';

  @override
  String get sheetRangeHelper =>
      'Le colonne della tabella, ad esempio Foglio1!A:E';

  @override
  String get folderPathOptional => 'Percorso della cartella (facoltativo)';

  @override
  String get folderPathHelper => 'Ad esempio Documenti';

  @override
  String get notionDatabaseId => 'Identificativo della banca dati';

  @override
  String get trelloListId => 'Identificativo elenco';

  @override
  String get figmaFileKey => 'Chiave dell\'archivio';

  @override
  String get figmaFileKeyHelper =>
      'Dal collegamento al file: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Deposito';

  @override
  String get workflowOptional => 'Flusso di lavoro (facoltativo)';

  @override
  String get workflowHelper => 'Nome file come ci.yml';

  @override
  String get branchOptional => 'Ramo (facoltativo)';

  @override
  String get branchHelper => 'Vuoto utilizza il ramo predefinito.';

  @override
  String get mcpServerIdOptional => 'ID del server MCP (facoltativo)';

  @override
  String get entityId => 'Identificativo dell\'entità';

  @override
  String get entityIdHelper => 'Ad esempio binario_sensore.front_door';

  @override
  String get targetStateOptional => 'Stato di destinazione (facoltativo)';

  @override
  String get targetStateHelper => 'Ad esempio su';

  @override
  String get aboveOptional => 'Sopra (facoltativo)';

  @override
  String get belowOptional => 'Sotto (facoltativo)';

  @override
  String get placeName => 'Nome del luogo';

  @override
  String get latitude => 'Latitudine';

  @override
  String get longitude => 'Longitudine';

  @override
  String get radiusMeters => 'Raggio in metri';

  @override
  String get geofenceTransition => 'Quando';

  @override
  String get arriving => 'In arrivo';

  @override
  String get leaving => 'In partenza';

  @override
  String get healthMetric => 'Metrica della salute';

  @override
  String get healthMetricHelper => 'Ad esempio frequenza cardiaca, passi, peso';

  @override
  String get wearableTransition => 'Quando l\'indossabile';

  @override
  String get wearableConnects => 'Connette';

  @override
  String get wearableDisconnects => 'Si disconnette';

  @override
  String get sourceTask => 'Dopo il compito';

  @override
  String get taskOutcome => 'Risultato';

  @override
  String get anyOutcome => 'Qualsiasi risultato';

  @override
  String get succeeded => 'Riuscito';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 manca o non è valido.';
  }

  @override
  String get triggerSectionMessaging => 'Messaggistica';

  @override
  String get triggerSectionDeveloper => 'Sviluppatore';

  @override
  String get triggerSectionMemory => 'Memoria';

  @override
  String get triggerSectionNews => 'Novità';

  @override
  String get triggerSectionSystem => 'Sistema';

  @override
  String get searchTriggersHint => 'Cerca trigger, app o eventi';

  @override
  String get noTriggersMatch => 'Nessun trigger corrisponde alla tua ricerca.';

  @override
  String get triggerAccountMissing => 'Nessun account ancora';

  @override
  String get pickTriggerKeyboardHint => 'Invio sceglie il primo risultato';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 si attiva';
  }

  @override
  String get addFromSkillsSh => 'Aggiungi da skills.sh';

  @override
  String get skillsShHint =>
      'Cerca qui sopra per trovare le competenze su skills.sh oppure incolla un collegamento skills.sh o un comando `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Nessuna competenza di skills.sh corrisponde a questa ricerca.';

  @override
  String get installingSkill => 'Installazione…';

  @override
  String installedSkillArg1(Object? arg1) {
    return '$arg1 installato';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 si installa';
  }

  @override
  String get authVerify => 'Verifica';

  @override
  String get authCreateAccount => 'Crea un account';

  @override
  String get authNewInviteLink => 'Nuovo link di invito';

  @override
  String get authShowPassword => 'Mostra password';

  @override
  String get authHidePassword => 'Nascondi la password';

  @override
  String get authPasswordWillBeRejected => 'troppo debole, verrà rifiutata';

  @override
  String get authUsernameTooShort =>
      'I nomi utente devono contenere almeno 3 caratteri.';

  @override
  String get authUsernameTaken => 'Quel nome utente è già occupato.';

  @override
  String get authSignupsClosed =>
      'Le iscrizioni sono chiuse su questo server. Chiedi all\'amministratore un account.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Questo server accetta solo accessi tramite HTTPS. Apri invece $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Questo server accetta solo accessi tramite HTTPS. Collegati usando un indirizzo https://.';

  @override
  String get authAccountNotFound => 'Questo account non esiste più.';

  @override
  String get authQrRateLimited =>
      'Troppe richieste di accesso QR. Aspetta un attimo, quindi aggiorna il codice.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Hai dimenticato la password? Chiedi all’amministratore del server di reimpostarla in Amministratore → Utenti.';

  @override
  String get authChangeServer => 'Cambia server';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Accesso a $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Questo indirizzo non risponde come un server NeoAgent. Controlla l\'URL e riprova.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Impossibile aprire una connessione protetta (HTTPS) a $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Impossibile raggiungere $arg1 tramite HTTPS e nemmeno il semplice HTTP ha risposto. Controlla l\'indirizzo e la porta.';
  }

  @override
  String get adminResetPassword => 'Reimposta la password';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Reimposta la password per $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Scegli una nuova password per $arg1. Verranno disconnessi su ogni dispositivo e accederanno nuovamente con questa password.';
  }

  @override
  String get adminNewPassword => 'Nuova password';

  @override
  String get adminSetPassword => 'Imposta la password';

  @override
  String get authMissingFields => 'Compila ogni campo obbligatorio.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 reimposta la password di $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Password aggiornata; l\'utente è stato disconnesso ovunque.';

  @override
  String get authSignInTitle => 'Accedi a NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Esegui la scansione con il tuo telefono o utilizza la password.';

  @override
  String get authOrUsePassword => 'oppure usa la tua password';

  @override
  String get qrLoginWaitingTitle => 'Approva sul tuo telefono';

  @override
  String get qrLoginWaitingBody =>
      'Il tuo telefono ha scansionato il codice. Conferma l\'accesso lì per completare l\'accesso.';

  @override
  String get qrLoginSigningInOn => 'Accesso su';

  @override
  String get qrLoginLocation => 'Posizione';

  @override
  String get qrLoginWaitingForApproval => 'In attesa di approvazione';

  @override
  String get qrLoginCancelAndUsePassword => 'Annulla e utilizza una password';

  @override
  String get qrLoginDeclinedOnPhone =>
      'L\'accesso è stato rifiutato sul tuo telefono. Scansiona il nuovo codice per riprovare.';

  @override
  String get signupKey => 'Chiave di registrazione';

  @override
  String get signupKeyStepSubtitle =>
      'I nuovi account su questo server richiedono una chiave di registrazione. Inserisci quella ricevuta da un amministratore.';

  @override
  String get signupKeyChange => 'Cambia';

  @override
  String get signupKeyRequiredError =>
      'Inserisci la tua chiave di registrazione.';

  @override
  String get signupKeyInvalidError =>
      'Questa chiave di registrazione non è valida. Controllala e riprova.';

  @override
  String get signupKeyUsedError =>
      'Questa chiave di registrazione è già stata usata. Chiedine una nuova a un amministratore.';

  @override
  String get adminRequireSignupKey => 'Richiedi una chiave di registrazione';

  @override
  String get adminRequireSignupKeyHint =>
      'I nuovi account richiedono una chiave monouso fornita da un amministratore. Se disattivato, chiunque possa raggiungere questo server può registrarsi. Il primo account non richiede mai una chiave.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'I nuovi account ora richiedono una chiave di registrazione.';

  @override
  String get adminSignupOpenNotice => 'Ora chiunque può registrarsi.';

  @override
  String get signupKeys => 'Chiavi di registrazione';

  @override
  String get signupKeysDescription =>
      'Chiavi monouso per registrarsi quando è richiesta una chiave. Ogni chiave crea esattamente un account.';

  @override
  String get signupKeysNew => 'Nuove chiavi';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Non usate · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Usate · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Revocate · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Tutte · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Non usata';

  @override
  String get signupKeyStatusUsed => 'Usata';

  @override
  String get signupKeyStatusRevoked => 'Revocata';

  @override
  String get signupKeysExport => 'Esporta .txt';

  @override
  String get signupKeysCopied => 'Chiavi copiate';

  @override
  String get signupKeyCopied => 'Chiave copiata';

  @override
  String get signupKeysEmpty => 'Nessuna chiave in questo elenco.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Creata il $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Usata da $arg1 il $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Usata il $arg1 da un account poi eliminato';
  }

  @override
  String get signupKeyRevokeTitle => 'Revocare questa chiave?';

  @override
  String get signupKeyRevokeMessage =>
      'Nessuno potrà più registrarsi con questa chiave. L\'operazione non può essere annullata.';

  @override
  String get signupKeyRevoked => 'Chiave revocata.';

  @override
  String signupKeysShowMore(int count) {
    return 'Mostra altre $count';
  }

  @override
  String get signupKeysCreateTitle => 'Crea chiavi di registrazione';

  @override
  String get signupKeysCount => 'Numero di chiavi';

  @override
  String get signupKeysCountHelper => 'Da 1 a 500';

  @override
  String get signupKeysCountInvalid => 'Inserisci un numero da 1 a 500.';

  @override
  String get signupKeysLabel => 'Etichetta (facoltativa)';

  @override
  String get signupKeysLabelHint => 'es. Beta tester di primavera';

  @override
  String signupKeysCreateAction(int count) {
    return 'Crea ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Chiavi pronte: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Consegna ogni chiave a una sola persona. Le chiavi non usate restano nell\'elenco, così puoi copiarle o esportarle di nuovo in seguito.';

  @override
  String get signupKeysSaveDialogTitle => 'Salva chiavi di registrazione';

  @override
  String get signupKeysExported => 'Chiavi esportate.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor ha creato chiavi di registrazione ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor ha revocato una chiave di registrazione';
  }

  @override
  String get providerChooseUsername => 'Scegli il tuo nome utente';

  @override
  String get providerChooseUsernameBody =>
      'Scegli un nome utente disponibile per completare la creazione dell\'account.';

  @override
  String get dataSharingTitle => 'Condividi dati di utilizzo';

  @override
  String get dataSharingDescription =>
      'Aiuta chi gestisce questo server a migliorarlo. Condivide come usi NeoAgent, mai ciò che scrivi o salvi.';

  @override
  String dataSharingSince(String date) {
    return 'Condivisione attiva dal $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Cosa viene condiviso';

  @override
  String get dataSharingIncluded => 'Condiviso';

  @override
  String get dataSharingExcluded => 'Mai condiviso';

  @override
  String get dataSharingIncludedDevice =>
      'Tipo di dispositivo e versione dell\'app';

  @override
  String get dataSharingIncludedLocale =>
      'Lingua dell\'app e regione del fuso orario, ad esempio Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Quali funzioni hai configurato, come attività, skill e integrazioni';

  @override
  String get dataSharingIncludedRuns =>
      'Quali strumenti e modelli usano le tue esecuzioni, con tempi e numero di token';

  @override
  String get dataSharingIncludedActivity =>
      'Quando usi NeoAgent, per giorno della settimana e ora';

  @override
  String get dataSharingExcludedContent => 'Messaggi, prompt e risposte';

  @override
  String get dataSharingExcludedRuns =>
      'Titoli delle esecuzioni, input e risultati degli strumenti';

  @override
  String get dataSharingExcludedFiles => 'File, ricordi e tutto ciò che salvi';

  @override
  String get dataSharingExcludedIdentity =>
      'Il tuo nome, email, indirizzo IP e posizione';

  @override
  String get dataSharingExcludedAccounts =>
      'Gli account con cui colleghi le integrazioni';

  @override
  String get dataSharingPooledNote =>
      'Gli amministratori vedono solo totali su tutte le persone che condividono, mai te singolarmente. Puoi disattivarlo in qualsiasi momento ed esci subito dai totali.';

  @override
  String get dataSharingConfirmTitle => 'Condividere i dati di utilizzo?';

  @override
  String get dataSharingConfirmAction => 'Condividi';

  @override
  String get sharedUsageTitle => 'Utilizzo condiviso';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Account che condividono dati di utilizzo: $sharing su $total. Solo totali, nessun contenuto.';
  }

  @override
  String get sharedUsageEmpty =>
      'Nessuno condivide ancora dati di utilizzo. Si può attivare in Impostazioni, Profilo, I tuoi dati.';

  @override
  String get sharedUsageRuns => 'Esecuzioni condivise';

  @override
  String get sharedUsageAvgDuration => 'Durata media';

  @override
  String get sharedUsageCompletedRuns => 'Esecuzioni completate';

  @override
  String get sharedUsageStepsPerRun => 'Passaggi per esecuzione';

  @override
  String get sharedUsageDevices => 'Dispositivi';

  @override
  String get sharedUsageAppVersions => 'Versioni dell\'app';

  @override
  String get sharedUsageLanguages => 'Lingue';

  @override
  String get sharedUsageRegions => 'Regioni';

  @override
  String get sharedUsageFeatures => 'Adozione delle funzioni';

  @override
  String get sharedUsageFeaturesDescription =>
      'Quota di account che condividono e l\'hanno configurata.';

  @override
  String get sharedUsageTools => 'Strumenti';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Strumenti più chiamati ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Chiamate: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Errori: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integrazioni';

  @override
  String get sharedUsageMessaging => 'Canali di messaggistica';

  @override
  String get sharedUsageTriggers => 'Come iniziano le esecuzioni';

  @override
  String get sharedUsageActivity => 'Quando viene usato';

  @override
  String get sharedUsageActivityDescription =>
      'Esecuzioni per giorno della settimana e ora, UTC.';

  @override
  String get sharedUsageModels => 'Prestazioni dei modelli';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return '$latency in media · $cached% in cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Account: $count';
  }

  @override
  String get sharedUsageNoData => 'Niente in questo periodo.';

  @override
  String get sharedUsageNotReported => 'Non ancora segnalato';

  @override
  String get sharedUsageFeatureAgents => 'Più di un agente';

  @override
  String get sharedUsageFeatureTasks => 'Attività pianificate';

  @override
  String get sharedUsageFeatureSkills => 'Skill';

  @override
  String get sharedUsageFeatureMcp => 'Server MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrazioni';

  @override
  String get sharedUsageFeatureMessaging => 'Canali di messaggistica';

  @override
  String get sharedUsageFeatureMemory => 'Memoria';

  @override
  String get sharedUsageSearchKeywords =>
      'condivisione dati opt-in telemetria dispositivi funzioni strumenti modelli attività';

  @override
  String get yourOAuthApp => 'La tua app OAuth';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'La tua app OAuth $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Questo server non ha un’app $provider globale, quindi ti colleghi con un’app OAuth che registri tu. Il client secret viene salvato cifrato e non viene più mostrato.';
  }

  @override
  String get oauthAppStepCreate => '1. Crea l’app';

  @override
  String get openDeveloperConsole => 'Apri la console sviluppatori';

  @override
  String get oauthAppStepCallback => '2. Registra questo URL di callback';

  @override
  String get callbackUrlCopied => 'URL di callback copiato';

  @override
  String get oauthAppScopes => 'Scope da consentire';

  @override
  String get scopesCopied => 'Scope copiati';

  @override
  String get oauthAppStepCredentials => '3. Incolla le credenziali dell’app';

  @override
  String get couldNotSaveOAuthApp => 'Impossibile salvare l’app OAuth.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Rimuovere la tua app $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Gli account collegati restano in elenco ma smettono di funzionare finché non aggiungi di nuovo un’app.';

  @override
  String get globalIntegrationConfiguration =>
      'Configurazione globale delle integrazioni';

  @override
  String get globalIntegrationConfigurationDescription =>
      'App OAuth facoltative per tutto il server. Se un’integrazione ne ha una, ogni account la usa e non può aggiungerne una propria. Lascia un’integrazione vuota e ogni utente configurerà la propria app. I secret sono di sola scrittura: lascia vuoto per mantenere il valore salvato.';

  @override
  String get globalStatus => 'Globale';

  @override
  String get perUserStatus => 'Per utente';

  @override
  String get phoneSyncGuidance =>
      'Condividi calendari e contatti di questo telefono con il tuo agente. Funziona con ogni account già presente sul telefono.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Apri NeoAgent sul telefono e attiva lì la condivisione. Il tuo agente vedrà calendari e contatti di tutti gli account del telefono.';

  @override
  String get manageOnThisPhone => 'Gestisci su questo telefono';

  @override
  String get setUpOnThisPhone => 'Configura su questo telefono';

  @override
  String get setUpOnPhone => 'Configura sul tuo telefono';

  @override
  String emailConnectedArg1(String email) {
    return '$email collegato';
  }

  @override
  String get couldNotConnectEmail => 'Impossibile collegare questo account.';

  @override
  String get emailSetupTitle => 'Collega email e calendario';

  @override
  String get emailChecking => 'Controllo della casella…';

  @override
  String get emailSetupIntro =>
      'Usa una password per app del tuo provider email. Nessuna console sviluppatori, pronto in pochi minuti.';

  @override
  String emailOpenArg1(String provider) {
    return 'Apri $provider';
  }

  @override
  String get emailStepServers => '1. Inserisci i server';

  @override
  String get emailStepPassword => '1. Crea una password per app';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Apri le password per app di $provider';
  }

  @override
  String get emailStepSignIn => '2. Accedi';

  @override
  String get appPassword => 'Password per app';

  @override
  String get appPasswordHelper =>
      'Gli spazi non contano. NeoAgent la salva cifrata.';

  @override
  String get emailUsernameOptional => 'Nome utente, se diverso dall’email';

  @override
  String get emailIncludeCalendar => 'Includi calendario';

  @override
  String get emailIncludeContacts => 'Includi contatti';

  @override
  String get imapServer => 'Server IMAP';

  @override
  String get smtpServer => 'Server SMTP';

  @override
  String get caldavUrlOptional => 'URL CalDAV (facoltativo)';

  @override
  String get carddavUrlOptional => 'URL CardDAV (facoltativo)';

  @override
  String get alternativeEmail =>
      'Collega la casella con una password per app, o il calendario con il suo link iCal. Pronto in pochi minuti.';

  @override
  String get alternativePhone =>
      'Condividi calendario e contatti già sul telefono tramite l’app NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Condividi calendario e contatti già sul telefono. Configuralo nell’app NeoAgent del telefono.';

  @override
  String get skipTheDeveloperConsole => 'Senza console sviluppatori';

  @override
  String get phoneSyncPromptTitle =>
      'Il tuo agente può vedere il tuo calendario?';

  @override
  String get phoneSyncPromptBody =>
      'Condividi calendari e contatti di questo telefono così il tuo agente può organizzare la tua giornata. Puoi cambiarlo quando vuoi in Strumenti › Integrazioni.';

  @override
  String get phoneSyncTitle =>
      'Condividi calendario e contatti di questo telefono';

  @override
  String get phoneSyncIntro =>
      'Il tuo agente vede calendari e contatti di tutti gli account del telefono. Nessuna console sviluppatori, nessun accesso aggiuntivo.';

  @override
  String get phoneSyncPointAccounts =>
      'Funziona con gli account Google, Outlook, iCloud ed Exchange di questo telefono.';

  @override
  String get phoneSyncPointPrivate =>
      'Condiviso solo con il tuo server NeoAgent, che lo salva cifrato.';

  @override
  String get phoneSyncPointWrites =>
      'Gli eventi aggiunti dall’agente li crea questo telefono e si sincronizzano come sempre.';

  @override
  String get phoneSyncCalendarHint =>
      'Eventi da 30 giorni fa a 90 giorni avanti';

  @override
  String get phoneSyncContacts => 'Contatti';

  @override
  String get phoneSyncContactsHint =>
      'Nomi, indirizzi email e numeri di telefono';

  @override
  String get phoneSyncOtherAgent =>
      'Questo telefono condivide con un altro agente. Condividere qui lo sposta su questo agente.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent non ha ancora accesso. Consentilo nelle Impostazioni e torna qui.';

  @override
  String get openPhoneSettings => 'Apri Impostazioni';

  @override
  String get phoneSyncShare => 'Condividi con NeoAgent';

  @override
  String get phoneSyncStop => 'Interrompi condivisione';

  @override
  String get phoneSyncWaiting => 'In attesa della prima sincronizzazione…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Ultima sincronizzazione $time';
  }

  @override
  String get calendarLink => 'Link del calendario';

  @override
  String get calendarLinkHelper =>
      'L’indirizzo iCal del calendario. Chi lo conosce può leggere il calendario, quindi tienilo privato.';

  @override
  String get calendarLinkName => 'Nome (facoltativo)';

  @override
  String get calendarLinkAdded => 'Calendario aggiunto';
}
