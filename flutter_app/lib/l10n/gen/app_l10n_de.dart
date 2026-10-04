// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppL10nDe extends AppL10n {
  AppL10nDe([String locale = 'de']) : super(locale);

  @override
  String get aBaseUrlIsRequiredFor =>
      'Für diesen Endpunkt ist eine Basis-URL erforderlich.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Eine geänderte E-Mail-Adresse wird bestätigt, bevor sie verwendet wird.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Eine Entscheidung weiter oben in der Kette hat Vorrang.';

  @override
  String get aDeletedAccount => 'ein gelöschtes Konto';

  @override
  String get aFridayLookBackAtThe =>
      'Ein freitäglicher Blick zurück auf die Woche und ein Plan für die nächste.';

  @override
  String get aKeyThatAsksForA =>
      'Ein Schlüssel, der eine PIN oder einen Fingerabdruck verlangt, ersetzt auch Ihren Zwei-Faktor-Code.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Ein Sprachmodell hat diese Nachricht beurteilt, weil SystemOne ausgeschaltet ist.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Eine NeoAgent-Einrichtungs-Metadatendatei hat das sichere Größenlimit überschritten.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Auf dem Server ist ein neueres Web-Build verfügbar. Neu laden, um das aktuelle Bundle zu holen.';

  @override
  String get aPlanSIdCanT => 'Die ID eines Tarifs lässt sich nicht ändern.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Ein privater Desktop mit Chromium, Dateien, Texteditor, Terminal und Python. Ihre Arbeit bleibt zwischen Sitzungen gespeichert.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Ein privater Linux-Computer oder ein Android-Gerät.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Eine erforderliche NeoAgent-Einrichtungsdatei konnte nicht heruntergeladen werden.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Ein Teammitglied schickt Ihnen einen Einladungslink. Sobald Sie ihn annehmen, entscheidet ';

  @override
  String get aTeammateSentYouAnInvite =>
      'Ihnen ein Teammitglied einen Einladungslink geschickt hat, geben Sie ihn hier ein, um dem Team beizutreten.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Ein temporärer Download wird später bereinigt.';

  @override
  String get aValueIsStored => 'Ein Wert ist gespeichert.';

  @override
  String get aboutUseWhatYouRememberAbout =>
      'interessieren (nutze, was du über meine Interessen weißt). Sende mir einen Überblick ';

  @override
  String get access => 'Zugriff';

  @override
  String get accessActivity => 'Zugriffsaktivität';

  @override
  String accessArg1(Object? arg1) {
    return 'Zugriff: $arg1';
  }

  @override
  String get accessMode => 'Zugriffsmodus';

  @override
  String get accessPermissions => 'Zugriffsberechtigungen';

  @override
  String get accessToken => 'access token';

  @override
  String get accessToken2 => 'Zugriffstoken';

  @override
  String get account => 'Konto';

  @override
  String accountArg1(Object? arg1) {
    return 'Konto #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Hinweise zu Kontoänderungen';

  @override
  String get accountEmail => 'Konto-E-Mail';

  @override
  String get accountEmailIsOffUntilThese =>
      'Konto-E-Mail ist aus, bis Folgendes gesetzt ist: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent verwendet diese Sprache in der gesamten App. Beim ersten Anmelden übernimmt sie die Sprache dieses Geräts. Danach wird die Auswahl in Ihrem Konto gespeichert und auf allen Geräten verwendet.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Die Sprache konnte nicht geändert werden: $error';
  }

  @override
  String get accountLanguageTitle => 'Sprache';

  @override
  String get accountNumber => 'Kontonummer';

  @override
  String get accountSettings => 'Kontoeinstellungen';

  @override
  String get accounts => 'Konten';

  @override
  String get accountsByTokensUsedAllTime =>
      'Konten nach genutzten Tokens, insgesamt.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'Cloud-Computer der Konten ausführen. Änderungen gelten nach einem Server ';

  @override
  String get accountsOnThisServer => 'Konten auf diesem Server';

  @override
  String get active => 'Aktiv';

  @override
  String get activeSessions => 'Aktive Sitzungen';

  @override
  String get activeToday => 'Heute aktiv';

  @override
  String get add => 'Hinzufügen';

  @override
  String get addAProviderCredentialFirstIts =>
      'Fügen Sie zuerst Anbieterzugangsdaten hinzu. Dessen Modelle erscheinen hier, sobald ';

  @override
  String get addAgent => 'Agent hinzufügen';

  @override
  String get addAnotherSignInMethodBefore =>
      'Fügen Sie eine weitere Anmeldemethode hinzu, bevor Sie diese entfernen.';

  @override
  String get addBinding => 'Bindung hinzufügen';

  @override
  String get addByNameOrId => 'Per Name oder ID hinzufügen';

  @override
  String get addByNameOrIdInstead => 'Stattdessen per Name oder ID hinzufügen';

  @override
  String get addCredentialBinding => 'Anmeldedaten-Bindung hinzufügen';

  @override
  String get addEntry => 'Eintrag hinzufügen';

  @override
  String get addKey => 'Schlüssel hinzufügen';

  @override
  String get addMcpServer => 'MCP-Server hinzufügen';

  @override
  String get addMemory => 'Erinnerung hinzufügen';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Fügen Sie mehr Länge oder einen weiteren Zeichentyp hinzu.';

  @override
  String get addPeopleOrGroups => 'Personen oder Gruppen hinzufügen';

  @override
  String get addSecurityKey => 'Sicherheitsschlüssel hinzufügen';

  @override
  String get addSomeoneOrAGroup => 'Person oder Gruppe hinzufügen';

  @override
  String get addTask => 'Aufgabe hinzufügen';

  @override
  String get addTests => 'Tests hinzufügen';

  @override
  String get addTestsForThePartsOf =>
      'Fügen Sie Tests für die Teile dieses Projekts mit der geringsten Abdeckung hinzu und führen Sie sie aus.';

  @override
  String get addTheirOwnKeysInSettings =>
      'eigene Schlüssel in den Einstellungen hinzufügen.';

  @override
  String get addToPrompt => 'Zum Prompt hinzufügen';

  @override
  String get added => 'Hinzugefügt';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Hinzugefügt $arg1 · Zuletzt verwendet $arg2';
  }

  @override
  String get addressWithTheProvider => 'Adresse beim Anbieter.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Lautsprecherlautstärke anpassen, Standardbelegungen der Hardwaretasten prüfen und diese Launcher-Sitzung verwalten.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Passen Sie die Suche oder den Statusfilter an, um weitere Messaging-Kanäle zu sehen.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Passen Sie hier die Lautsprecherlautstärke an.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Admin › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Admin-Freigaben, Einladungslinks und Verwaltungsänderungen erscheinen hier.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Erweiterter manueller Zeitplan für Sonderfälle.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Erweitert: Minute Stunde Tag Monat Wochentag.';

  @override
  String get againRightAway => 'sofort wieder möglich.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Agentenanrufe';

  @override
  String get agentCommunication => 'Agentenkommunikation';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agentenkommunikation: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agentenmodus bearbeitet den Workspace · ⌘↵ senden · ⌘N neue Sitzung';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Der Agent pausiert und fragt Sie vor der Ausführung.';

  @override
  String get agentProfile => 'Agentenprofil';

  @override
  String get agentRuns7d => 'Agentenläufe (7 T.)';

  @override
  String get agentVisibleName => 'Für den Agenten sichtbarer Name';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Der Agent möchte $arg1 verwenden. Tippen Sie, um zu entscheiden.';
  }

  @override
  String get agents => 'Agenten';

  @override
  String get aiAnswerUnreadable => 'KI-Antwort unlesbar';

  @override
  String get aiProviderKeys => 'KI-Anbieterschlüssel';

  @override
  String get aiUnavailable => 'KI nicht verfügbar';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'hinweise und andere Konto-E-Mails sendet.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Benachrichtigungen, wenn eine Messaging-Verbindung Ihre Aufmerksamkeit braucht';

  @override
  String get all => 'Alle';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Alle Agenten ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Alle $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Alle Cloud-Computer-Slots sind derzeit belegt. Versuchen Sie es in einem Moment erneut.';

  @override
  String get allComputerSlotsAreBusy => 'Alle Computer-Slots sind belegt';

  @override
  String get allTables => 'Alle Tabellen';

  @override
  String get allTime => 'Gesamt';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Alle Tools sind erlaubt — der Agent kann jede Funktion ohne Nachfrage nutzen. ';

  @override
  String get allow => 'Erlauben';

  @override
  String get allowAll => 'Alles erlauben';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Erlauben Sie „Unbekannte Apps installieren“ für NeoAgent und versuchen Sie das Update erneut.';

  @override
  String get allowNewSignUps => 'Neue Registrierungen zulassen';

  @override
  String get allowOnce => 'Einmal erlauben';

  @override
  String get allowSender => 'Absender zulassen';

  @override
  String get allowSession => 'Für Sitzung erlauben';

  @override
  String get allowTheAgentToStartAn =>
      'Erlauben Sie dem Agenten, einen In-App-Sprachanruf mit Ihnen zu starten.';

  @override
  String get allowedForThisRunWillAsk =>
      'Für diese Ausführung erlaubt — fragt in der nächsten Sitzung erneut.';

  @override
  String get allowedModels => 'Erlaubte Modelle';

  @override
  String get allowedOrigins => 'Erlaubte Origins';

  @override
  String get allowedPathPrefix => 'Erlaubtes Pfadpräfix';

  @override
  String get allowsYouCanChangeThatPer =>
      'erlaubt. Später können Sie das pro Person ändern. Links vergeben nie ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'gehört bereits zu einem bestehenden Konto';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'bereits mit einem anderen Konto verknüpft';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'bereits mit einem anderen NeoAgent-Konto verknüpft';

  @override
  String get alreadyUsed => 'bereits verwendet';

  @override
  String get always => 'Immer';

  @override
  String get alwaysAllow => 'Immer erlauben';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '„Immer erlauben“ speichert die Richtlinie dauerhaft — Sie können sie in den Einstellungen ändern.';

  @override
  String get alwaysAsk => 'Immer nachfragen';

  @override
  String get alwaysEngage => 'Immer teilnehmen';

  @override
  String get alwaysJoins => 'Tritt immer bei';

  @override
  String get anApiKeyIsRequired => 'Ein API-Schlüssel ist erforderlich.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Eine abendliche Zusammenfassung dessen, was passiert ist und was nachzuverfolgen ist.';

  @override
  String get anHttpOrHttpsUrlIs =>
      'Eine http- oder https-URL ist erforderlich.';

  @override
  String get andBillingTeamLinksLiveOn =>
      'und Abrechnung. Team-Links finden Sie auf der Team-Seite.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Android-APK-Installation ist auf dieser Plattform nicht verfügbar.';

  @override
  String get androidApp => 'Android-App';

  @override
  String get androidControl => 'Android-Steuerung';

  @override
  String get androidCouldNotStart => 'Android konnte nicht gestartet werden';

  @override
  String get androidNotificationReceived =>
      'Android-Benachrichtigung empfangen';

  @override
  String get androidOnly => 'Nur Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Der Android-Paketinstaller konnte nicht geöffnet werden.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android-Bildschirm — tippen zum Berühren, ziehen zum Wischen';

  @override
  String get androidSdk => 'Android-SDK';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Beantwortet @-Erwähnungen in Issues und Pull Requests';

  @override
  String get anyone => 'Jeder';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Jeder auf dieser Plattform kann $arg1 schreiben';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Jeder auf dieser Plattform kann $arg1 in $arg2 schreiben.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Jeder, der dieses Konto erreichen kann, kann mit $arg1 sprechen.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Jeder mit dem Link kann beitreten, bis er abläuft oder Sie ihn widerrufen.';

  @override
  String get anyoneYouAllowCanChatWith =>
      'Alle, die Sie zulassen, können damit in Direktchats und Gruppen chatten.';

  @override
  String get apiHttpsOrigin => 'API-HTTPS-Ursprung';

  @override
  String get apiKey => 'API-Schlüssel';

  @override
  String get apiKey2 => 'API-Schlüssel';

  @override
  String get apiKey3 => 'API-Schlüssel';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api key anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter credentials';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API-Schlüssel und Endpunkte für KI-, Such- und Sprachanbieter. Sie ';

  @override
  String get apiRequest => 'API-Anfrage';

  @override
  String get apiYourOwnServerASelf =>
      'API -- Ihren eigenen Server, ein selbst gehostetes Modell oder einen anderen ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK-Download fehlgeschlagen mit HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'App-Name ist erforderlich.';

  @override
  String get appUpdates => 'App-Updates';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'App-Updates sind für diesen Build nicht konfiguriert.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return '$arg1 eingereihte Steuerungsaktualisierungen auf die aktuelle Ausführung angewendet.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return '$arg1 Steuerungsaktualisierung(en) angewendet.';
  }

  @override
  String get apply => 'Übernehmen';

  @override
  String get applyBehaviorNotes => 'Verhaltensnotizen übernehmen';

  @override
  String get applyCoreMemory => 'Kernspeicher übernehmen';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Freigabeanfragen für sensible Agenten-Tools';

  @override
  String get approvalRequired => 'Freigabe erforderlich';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Die Freigabe bleibt in Ihrer authentifizierten mobilen Sitzung; jeder Code läuft nach kurzer Zeit automatisch ab.';

  @override
  String get approveLogin => 'Anmeldung genehmigen';

  @override
  String get approveQrLogin => 'QR-Anmeldung genehmigen';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Genehmigen Sie dies nur, wenn Sie die Anmeldung auf diesem Gerät gerade gestartet haben.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Anmeldung für $arg1 genehmigt.';
  }

  @override
  String get approvedOnly => 'Nur Freigegebene';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Pairing für $arg1 freigegeben.';
  }

  @override
  String get approvedPeopleAndGroups => 'Freigegebene Personen und Gruppen';

  @override
  String get approvedPeopleOnly => 'Nur freigegebene Personen';

  @override
  String get archive => 'Archiv';

  @override
  String get archiveAgent => 'Agent archivieren?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archivieren ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 archivieren?';
  }

  @override
  String get archiveSelectedMemories => 'Ausgewählte Erinnerungen archivieren?';

  @override
  String get areSharedByEveryAccountOn =>
      'werden von jedem Konto auf diesem Server gemeinsam genutzt; Konten können weiterhin ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M Eingabe';
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
    return 'Zugriff auf $arg1 erforderlich';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 Konten';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktiv';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 hinzugefügt. Bearbeiten Sie jederzeit den ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1“ und der Laufverlauf werden dauerhaft gelöscht. Jeder aktive Lauf wird gestoppt. Dateien im Workspace bleiben unberührt.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Freigabe für $arg1 erforderlich';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 Apps aktiv';
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
  String arg1Arg29(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2';
  }

  @override
  String arg1Arg2ActiveTools(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2 aktive Tools)';
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
  String arg1Arg2Arg38(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 $arg3';
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
    return '$arg1 $arg2 um $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 geändert';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 Zeichen';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Erstellt $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [local uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 passend zu “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent Workspace';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 neue Konten';
  }

  @override
  String arg1Arg2OfArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1–$arg2 von $arg3';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 Läufe · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 Proben';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 Steuerung in Warteschlange';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 Tokens';
  }

  @override
  String arg1Arg2Tokens2(Object? arg1, Object? arg2) {
    return '$arg1: $arg2 Tokens';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 Token';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 um $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 wurde Admin ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 Bytes';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Kanal $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 Zeichen';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 gelöscht.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 konfiguriert';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 verbunden. Wählen Sie Repositories und Personen unter Wer darf schreiben.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 Kern-Einträge.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 hat einen Einladungslink erstellt';
  }

  @override
  String arg1Deactivated(Object? arg1) {
    return '$arg1 deaktiviert.';
  }

  @override
  String arg1Default(Object? arg1) {
    return '$arg1: Standard';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1-Desktop';
  }

  @override
  String arg1Entries(Object? arg1) {
    return '$arg1 Einträge';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 Ereignisse';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 fehlgeschlagen';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 fehlgeschlagen';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 fehlgeschlagen';
  }

  @override
  String arg1FeatureArg2(Object? arg1, Object? arg2) {
    return '$arg1 Funktion$arg2';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 für $arg2';
  }

  @override
  String arg1Forever(Object? arg1) {
    return '$arg1 für immer';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 Gruppen nur bei Erwähnung';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'vor $arg1 Std.';
  }

  @override
  String arg1HArg2M(Object? arg1, Object? arg2) {
    return '$arg1 Std. $arg2 Min.';
  }

  @override
  String arg1HArg2Min(Object? arg1, Object? arg2) {
    return '$arg1 Std. $arg2 Min.';
  }

  @override
  String arg1Helpers(Object? arg1) {
    return '$arg1 Helfer';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 Trefferquote)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 ist Administrator, daher kann das Konto hier nicht ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 ist auf $arg2 blockiert. Aktualisieren Sie die Zugriffsliste, um Antworten zu erlauben.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 ist verbunden und antwortet.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 ist kein Admin mehr ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 ist auf $arg2 nicht verfügbar (fehlende Laufzeitberechtigung oder Abhängigkeit).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 ist unter $arg2 beigetreten';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 von LLM beurteilt';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1-Schlüssel$arg2 konfiguriert';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1-Schlüssel entfernt.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 übrig';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 hat $arg2 verlassen';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 verknüpft';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'vor $arg1 Min.';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '$arg1 Min. $arg2 Sek.';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Stellen Sie sicher, dass es läuft, und versuchen Sie es erneut.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 verwaltet dieses Konto';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 Min.';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 Min. $arg2 Sek.';
  }

  @override
  String arg1ModelArg2(Object? arg1, Object? arg2) {
    return '$arg1 Modell$arg2';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return '$arg1 Modelle bereit';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 weitere';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 weitere Schritte im Laufverlauf';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 wurde von $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 muss eine endliche Zahl sein.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 muss eine http://- oder https://-Adresse sein.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 braucht Aufmerksamkeit';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent Workspace';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 neue Konten in den letzten $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · neue Nachrichten steuern diese Ausführung';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 neue Ausführungen';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 verwaltet jetzt dieses Konto.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 von 4 Berechtigungen erlaubt. Dateien sind auf Ihren NeoAgent-Workspace-Ordner beschränkt.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 aktiviert';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 Gruppen nehmen am normalen Chat teil';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 Modellen';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 Modellen bereit';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 festgelegt';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 Tools erlaubt';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 am Tag $arg2 um $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 antwortet nur den Personen, die Sie unten hinzufügen.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 antwortet nur bei Markierung';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 spricht nur mit Personen und Gruppen, die Sie freigeben';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 Personen oder Gruppen hinzugefügt';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 plant';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 Anbieter';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 bereit';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 Datensätze';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1-Redirect-URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registriert';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 hat geantwortet';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 hat einen Einladungslink widerrufen';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 Läufe';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 Läufe · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 Läufe in den letzten $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 gespeichert.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 Sek.';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 ausgewählt';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 angezeigt';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 ist still geblieben';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 Steuerung $arg2 in Warteschlange';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 Schritt$arg2 · tippen Sie auf einen Knoten zur Prüfung';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 Schritte';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 hat die Verwaltung von $arg2 beendet';
  }

  @override
  String arg1TalksToTheDeviceOn(Object? arg1) {
    return '$arg1 kommuniziert mit dem Gerät in Ihrem lokalen Netzwerk (standardmäßig Port 4403). Der Chat bleibt auf dem oben gewählten Kanal.';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 Tokens';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 Tokens in den letzten $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 Tools';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (gespeicherte Überschreibung nicht verfügbar)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% verbraucht · $arg2 verbleibend';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 möchte mit Ihnen sprechen.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 Web';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" wird dauerhaft entfernt.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 wird dieses Konto verwalten';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 antwortet auf dieser Plattform nicht';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 antwortet nicht auf $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Artefaktspeicher nach Nutzer';

  @override
  String get askAQuestionOrStartA =>
      'Stellen Sie eine Frage oder starten Sie eine Aufgabe...';

  @override
  String get askBeforeClosingToBackground =>
      'Vor dem Wechsel in den Hintergrund fragen';

  @override
  String get askMe => 'Mich fragen';

  @override
  String get assignAPlanToAnAccount => 'Tarif einem Konto zuweisen';

  @override
  String get assignPlan => 'Plan zuweisen';

  @override
  String get assignedAgent => 'Zugewiesener Agent';

  @override
  String get assignedAgent2 => 'Zugewiesener Agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Zugewiesener Agent: $arg1';
  }

  @override
  String assignedArg1(Object? arg1) {
    return '$arg1 zugewiesen.';
  }

  @override
  String get assigneeOptional => 'Zuständige Person (optional)';

  @override
  String get assistant => 'Assistent';

  @override
  String get assistantKey131 => 'Assistententaste 131';

  @override
  String get atLeast1 => 'Mindestens 1.';

  @override
  String get atLeast1000AppliesAfterA =>
      'Mindestens 1000. Gilt nach einem Serverneustart.';

  @override
  String get atLeast512 => 'Mindestens 512.';

  @override
  String get attachFiles => 'Dateien anhängen';

  @override
  String attentionArg1(Object? arg1) {
    return 'Aufmerksamkeit $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'audit log admin gewähren widerrufen einladen team verlauf';

  @override
  String get authMethod => 'Authentifizierungsmethode';

  @override
  String get authServerUrl => 'Auth-Server-URL';

  @override
  String get authentication => 'Authentifizierung';

  @override
  String get authenticationFailed => 'Authentifizierung fehlgeschlagen.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Die Authentifizierung steht noch aus. Schließen Sie den Browser-Ablauf ab und versuchen Sie es erneut.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Die Authentifizierung steht noch aus. Schließen Sie den Browser-Ablauf ab und aktualisieren Sie.';

  @override
  String get authenticationTimedOut => 'Authentifizierung ist abgelaufen.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Die Authentifizierung wurde vor dem Abschluss abgebrochen.';

  @override
  String get authenticatorApp => 'Authenticator-App';

  @override
  String get authenticatorCode => 'Authenticator-Code';

  @override
  String get authorOptional => 'Autor (optional)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (erster Anbieter mit API-Schlüssel)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Leitet automatisch an das beste verfügbare Modell weiter';

  @override
  String get automaticFast => 'Automatisch (schnell)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatisch liest den Raum und hält sich normalerweise zurück. Nur-Erwähnung trifft keine Entscheidung, bis direkt angesprochen.';

  @override
  String get automaticReserved => 'Automatisch, zurückhaltend';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Der automatische Rollback erfordert einen erneuten Versuch im Einrichtungsbildschirm.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatisch wählt ein schnelles Modell über den normalen Modellkatalog.';

  @override
  String get automaticallyChooseTheBestEnabledModel =>
      'Automatisch das beste aktivierte Modell für jeden Aufgabentyp wählen.';

  @override
  String get automation => 'Automatisierung';

  @override
  String get available => 'Verfügbar';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Wieder verfügbar in $arg1';
  }

  @override
  String get availableAgainShortly => 'In Kürze wieder verfügbar';

  @override
  String get availableInTheDesktopAppFor =>
      'Verfügbar in der Desktop-App für macOS, Windows und Linux';

  @override
  String get availableToTheAgent => 'Für den Agenten verfügbar';

  @override
  String get averageAllTime => 'Durchschnitt, insgesamt';

  @override
  String get avgImp => 'Ø Wicht.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Ø/Lauf: $arg1 Tokens';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Vermeiden Sie wiederholte Zeichen und offensichtliche Folgen.';

  @override
  String get awaitingScan => 'Warte auf Scan';

  @override
  String get back => 'Zurück';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count im Hintergrund';
  }

  @override
  String get backgroundTasks => 'Hintergrund-Aufgaben';

  @override
  String get backOn => 'wieder eingeschaltet.';

  @override
  String get backToChat => 'Zurück zum Chat';

  @override
  String get backToFolder => 'Zurück zum Ordner';

  @override
  String get backToSignIn => 'Zurück zur Anmeldung';

  @override
  String get backendChannel => 'Backend-Kanal';

  @override
  String get backendOnThisComputer => 'Backend auf diesem Computer';

  @override
  String get backendSync => 'Backend-Synchronisation';

  @override
  String get backgroundLocationNeeded => 'Hintergrundstandort erforderlich';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Hintergrundsynchronisation bleibt unter Android geplant';

  @override
  String get badState => 'Ungültiger Zustand: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Basis-Image und Größe der QEMU-VMs, die die ';

  @override
  String get baseImageUrl => 'Basis-Image-URL';

  @override
  String get baseUrlOptional => 'Basis-URL (optional)';

  @override
  String get baseUrlTokenLocal => 'base url token lokal';

  @override
  String get basicAuthentication => 'Basisauthentifizierung';

  @override
  String get behaviorModules => 'Verhaltensmodule';

  @override
  String get behaviorNotes => 'Verhaltensnotizen';

  @override
  String get beta => 'Beta';

  @override
  String get billedThroughStripeSoItCan =>
      'Wird über Stripe abgerechnet und kann hier nicht gekündigt werden.';

  @override
  String get billing => 'Abrechnung';

  @override
  String get billingEnabled => 'Abrechnung aktiviert';

  @override
  String get billingHistory => 'Abrechnungsverlauf';

  @override
  String get billingInterval => 'Abrechnungsintervall';

  @override
  String get billingIsOff => 'Abrechnung ist aus';

  @override
  String get billingIsTurnedOffButStill =>
      'Abrechnung ist deaktiviert, läuft aber noch. Starten Sie den ';

  @override
  String get billingIsTurnedOnButNot =>
      'Abrechnung ist aktiviert, läuft aber noch nicht. Starten Sie den ';

  @override
  String get billingSetupSaved => 'Abrechnungseinrichtung gespeichert.';

  @override
  String get billingStripeKeysWebhookSecretTrial =>
      'abrechnung stripe keys webhook secret trial aktivieren';

  @override
  String get billingSubscription => 'Abrechnung & Abonnement';

  @override
  String get bitwardenCredentialBroker => 'Bitwarden-Anmeldedaten-Broker';

  @override
  String get bitwardenItem => 'Bitwarden-Eintrag';

  @override
  String get bitwardenServer => 'Bitwarden-Server';

  @override
  String get blankUsesCommon => 'Leer verwendet \"common\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Leer verwendet den Standard-Callback';

  @override
  String get blankUsesTheServerDefault => 'Leer nutzt den Serverstandard.';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Leere Werte nutzen die Anbieterstandards.';

  @override
  String get block => 'Blockieren';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Eingehende Nachricht von $arg1 blockiert.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubbles-kompatible Brücke';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles-Server-URL';

  @override
  String get botToken => 'Bot-Token';

  @override
  String get botTokenAndApprovedChats => 'Bot-Token und freigegebene Chats';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bot-Token und Server-/Kanalzugriff';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot-Token, Events API und Kanalzugriff';

  @override
  String get botUserId => 'Bot-Benutzer-ID';

  @override
  String get botUsername => 'Bot-Benutzername';

  @override
  String get brandName => 'Markenname';

  @override
  String get braveSearch => 'Brave Search';

  @override
  String get breakdown => 'Aufschlüsselung:';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Brücken zu jedem Anbieter, der Webhook-Nutzlasten senden und empfangen kann.';

  @override
  String get bringYourOwnKey => 'eigenen Schlüssel mitbringen';

  @override
  String get bringYourOwnKey2 => 'Eigenen Schlüssel verwenden';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Browser, Linux-Desktop, Dateien, Terminal und Python teilen sich einen persistenten Cloud-Computer.';

  @override
  String get browserLogin => 'Browser-Anmeldung';

  @override
  String get browserScripting => 'Browser-Scripting';

  @override
  String get call => 'Anruf';

  @override
  String get callAgent => 'Agent anrufen';

  @override
  String get callUser => 'Benutzer anrufen';

  @override
  String get calledByName => 'Beim Namen genannt';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Kann Aufgaben an andere Agenten delegieren';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Kann an $arg1 delegieren';
  }

  @override
  String get canReceiveDelegatedTasks => 'Kann delegierte Aufgaben empfangen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get cancelSubscription => 'Abonnement kündigen';

  @override
  String get cancelTask => 'Aufgabe abbrechen';

  @override
  String get cancelsAtPeriodEnd => 'Wird zum Periodenende gekündigt';

  @override
  String candidateCountArg1(Object? arg1) {
    return 'Kandidatenanzahl: $arg1';
  }

  @override
  String get cannotPreview => 'Vorschau nicht möglich';

  @override
  String get cannotReceiveDelegatedTasks =>
      'kann keine delegierten Aufgaben empfangen';

  @override
  String get cannotRunYet => 'noch nicht laufen.';

  @override
  String get capturedThePage => 'Seite erfasst';

  @override
  String get category => 'Kategorie';

  @override
  String chainArg1(Object? arg1) {
    return 'Kette: $arg1. ';
  }

  @override
  String get changePlan => 'Tarif wechseln';

  @override
  String get changeSetupMode => 'Einrichtungsmodus ändern';

  @override
  String get channel => 'Kanal';

  @override
  String get channelAccessToken => 'Kanal-Zugriffstoken';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanal: $arg1$arg2 | Update-Version: $arg3$arg4$arg5';
  }

  @override
  String get channelNumber => 'Kanalnummer';

  @override
  String get channelScopedSocialMemory => 'Kanalbezogenes soziales Gedächtnis';

  @override
  String get channels => 'Kanäle';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'Chat-ID';

  @override
  String get chatMode => 'Chat-Modus';

  @override
  String get chatModel => 'Chat-Modell';

  @override
  String get checkAutomaticallyOnLaunch => 'Beim Start automatisch prüfen';

  @override
  String get checkForMessagesEveryMs => 'Nachrichten prüfen alle (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automatisch nach neuen Nachrichten suchen';

  @override
  String get checkMyEmailInboxForMessages =>
      'Prüfe meinen E-Mail-Posteingang auf Nachrichten seit der letzten Prüfung. ';

  @override
  String get checkNow => 'Jetzt prüfen';

  @override
  String get checkYourEmailToConfirmYour =>
      'Prüfen Sie Ihre E-Mail, um Ihr NeoAgent-Konto vor der Anmeldung zu bestätigen.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Geprüft $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Wählen Sie eine Kategorie oder suchen Sie in allen Einstellungen.';

  @override
  String get chooseAPerson => 'Person wählen';

  @override
  String get chooseAPlanToGetStarted =>
      'Wählen Sie einen Tarif, um zu starten.';

  @override
  String get chooseAProjectFolder => 'Projektordner wählen';

  @override
  String chooseArg1(Object? arg1) {
    return '$arg1 wählen';
  }

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Standards für Chat, Agenten, Fallback-Verhalten und Smart Routing wählen.';

  @override
  String get chooseGroups => 'Gruppen wählen';

  @override
  String get chooseHowMuchYouWantTo =>
      'Wählen Sie, wie viel Sie jetzt konfigurieren möchten. Beide Optionen lassen sich später ändern.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Wählen Sie, wie diese Aufgabe starten soll. Manuell läuft nur über Jetzt ausführen. Zeitplan ist zeitgesteuert. Integrationsauslöser reagieren auf verbundene offizielle Apps.';

  @override
  String get chooseOneToGetStartedNow =>
      'Wählen Sie eine, um jetzt zu starten. Weitere können Sie später hinzufügen.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Wählen Sie Live-Modell und Stimme in den Einstellungen.';

  @override
  String get chooseTheirGroup => 'Ihre Gruppe wählen';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Wählen Sie, wo diese Person mit $arg1 sprechen darf. Sie können das später unter Wer darf schreiben ändern.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Wählen Sie, welchen Gruppen $arg1 auch beitreten soll, wenn niemand es markiert. Diese Plattform unterscheidet Markierungen möglicherweise nicht von normalen Nachrichten.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Wählen Sie, welche Modelle jedes Konto auf diesem Server auswählen und ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Legen Sie fest, mit wem $arg1 spricht und wann es Gruppenchats beitritt.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Wählen Sie, wer $arg1 erreichen darf, und speichern Sie Ihre Änderungen.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Legen Sie unter „Wer darf schreiben“ auf der WhatsApp-Karte fest, wer dem Agenten schreiben darf.';

  @override
  String get chooseYourDefaultModel => 'Wählen Sie Ihr\nStandardmodell.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, Dateien, Texteditor und Terminal sind alle über den Linux-Desktop verfügbar.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Leeren';

  @override
  String get clearAll => 'Alles abwählen';

  @override
  String clearArg1(Object? arg1) {
    return '$arg1 löschen?';
  }

  @override
  String get clearFilter => 'Filter zurücksetzen';

  @override
  String get clearFilters => 'Filter löschen';

  @override
  String get clearSearch => 'Suche löschen';

  @override
  String get clearView => 'Ansicht leeren';

  @override
  String get cliSession => 'CLI-Sitzung';

  @override
  String get clickIsNotSupportedOnThis =>
      'click wird auf dieser Plattform nicht unterstützt.';

  @override
  String get clickOnceToBeginCapturing =>
      'Einmal tippen, um die Aufnahme zu starten';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klicken, tippen und mit Desktop-Apps interagieren.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Bei ($arg1, $arg2) geklickt';
  }

  @override
  String get clickedInTheBrowser => 'Im Browser geklickt';

  @override
  String get clientId => 'Client-ID';

  @override
  String get clientSecret => 'Client-Secret';

  @override
  String get close => 'Schließen';

  @override
  String get closeJ => 'Schließen (⌘J)';

  @override
  String get closeTeachMode => 'Einlernmodus schließen';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Beim Schließen des Fensters kann NeoAgent im Hintergrund mit Tray-Zugriff weiterlaufen oder die Desktop-Laufzeitumgebung vollständig beendet werden.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Cloud- und selbst gehostete Instanzen werden unterstützt. Lokale und private Netzwerk-URLs funktionieren, wenn NeoAgent sie erreichen kann.';

  @override
  String get cloudComputer => 'Cloud-Computer';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloud-Computer · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Cloud-Computer-Einstellungen gespeichert. Starten Sie den Server neu, um sie anzuwenden.';

  @override
  String get cloudComputerVm => 'Cloud-Computer (VM)';

  @override
  String get cloudComputers => 'Cloud-Computer';

  @override
  String get codeHosting => 'Code-Hosting';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Durch Kommas getrennte Kanalnamen, ohne #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Durch Kommas getrennt, zum Beispiel #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Kommagetrennt. Das Issue muss alle davon haben.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Befehl fehlgeschlagen ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Befehl ist erforderlich.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Der Befehlsausgaben-Akkumulator ist nicht aktiv.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Upload der Befehlsausgabe fehlgeschlagen ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Upload der Befehlsausgabe hat Artefakt-Metadaten ausgelassen.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Die Befehlsausgabe wurde bereits abgeschlossen.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Befehle & Apps';

  @override
  String get commandsRunInTheSamePersistent =>
      'Befehle laufen im selben persistenten Computer wie der sichtbare Desktop.';

  @override
  String get commasOrLeaveBlankForEvery =>
      'Kommas getrennt ein oder lassen Sie das Feld leer für jedes Modell.';

  @override
  String get communityChatops => 'Community & ChatOps';

  @override
  String get completeSetup => 'Einrichtung abschließen';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Schließen Sie den Workflow auf dem Desktop ab.';

  @override
  String get completed => 'Abgeschlossen';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Vollständig gesperrt — der Agent kann diese Kategorie nicht nutzen.';

  @override
  String get computerShell => 'Computer-Shell';

  @override
  String get computerUsedByThisSession =>
      'Von dieser Sitzung genutzter Computer';

  @override
  String get computerWorkspace => 'Computer-Arbeitsbereich';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurierbare persönliche Webhook-Brücke';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurierbare Relay- oder Webhook-Brücke';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigurierbare Talk-Webhook-Brücke';

  @override
  String get configurableWebInboxBridge =>
      'Konfigurierbare Web-Posteingangs-Brücke';

  @override
  String get configurableWebhookBridge => 'Konfigurierbare Webhook-Brücke';

  @override
  String get configurableWebhooks => 'Konfigurierbare Webhooks';

  @override
  String get configurationOrInTheEnvFile =>
      'Konfiguration oder in der .env-Datei.';

  @override
  String get configure => 'Konfigurieren';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Arbeitsbereichsverhalten und Modellstandards konfigurieren.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfiguriert $arg1';
  }

  @override
  String get confirmEmailChanges => 'E-Mail-Änderungen bestätigen';

  @override
  String get confirmNewSignUps => 'Neue Registrierungen bestätigen';

  @override
  String get confirmPassword => 'Passwort bestätigen';

  @override
  String get confirmPassword2 => 'Passwort bestätigen';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Bestätigen Sie Ihre E-Mail vor der Anmeldung. Prüfen Sie die Service-E-Mail von NeoAgent.';

  @override
  String get connect => 'Verbinden';

  @override
  String get connectAMessagingPlatform =>
      'Verbinden Sie eine\nMessaging-Plattform.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Verbinden Sie einen öffentlichen HTTPS-Home-Assistant-Endpunkt mit einem Long-Lived Access Token. Lokale, Loopback- und private Netzwerkadressen werden vom Server blockiert.';

  @override
  String get connectAccount => 'Konto verbinden';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Verbinden Sie App-Konten einzeln, damit die KI für jede offizielle Integration das richtige Konto nutzen kann.';

  @override
  String connectArg1(Object? arg1) {
    return '$arg1 verbinden';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Verbinden Sie so viele Konten, wie Sie möchten. Jede App kann ein anderes Konto verwenden.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Verbinden Sie Kanäle, wählen Sie, mit wem $arg1 spricht, und beobachten Sie die aktuelle Aktivität.';
  }

  @override
  String get connectInstance => 'Instanz verbinden';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Verbinden Sie diese Integration zuerst, um ein Konto auszuwählen.';

  @override
  String get connectToThisServer => 'Mit diesem Server verbinden';

  @override
  String get connectWhatsapp => 'WhatsApp verbinden';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Verbinden Sie Ihre Nextcloud-Instanz, einschließlich selbst gehosteter Server. NeoAgent öffnet die eigene Anmeldeseite von Nextcloud, damit Sie sich mit Passwort, SSO oder 2FA anmelden können.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Verbinden Sie Ihren selbst gehosteten NeoRecall-Server. NeoAgent erhält nach Freigabe des OAuth-Bildschirms Lesezugriff auf lokale Suche, Erinnerungen und Transkriptnachweise.';

  @override
  String get connected => 'Verbunden';

  @override
  String get connectedAccount => 'Verbundenes Konto';

  @override
  String connectedArg1(Object? arg1) {
    return 'Verbunden $arg1';
  }

  @override
  String get connectedInstance => 'Verbundene Instanz';

  @override
  String get connectedNeorecallUser => 'Verbundener NeoRecall-Benutzer';

  @override
  String get connectedNextcloudUser => 'Verbundener Nextcloud-Benutzer';

  @override
  String get connectedServer => 'Verbundener Server';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Verbindung zum Live-Sprachmodell...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Verbindung #$arg1';
  }

  @override
  String get connectionId => 'Verbindungs-ID';

  @override
  String get connectionLooksGood => 'Verbindung sieht gut aus.';

  @override
  String get connectionMethod => 'Verbindungsmethode';

  @override
  String get containsTextOptional => 'Enthält Text (optional)';

  @override
  String get content => 'Inhalt';

  @override
  String contentArg1(Object? arg1) {
    return 'Inhalt: $arg1';
  }

  @override
  String get contentSecurityPolicy => 'Content Security Policy';

  @override
  String get continue2 => 'Weiter';

  @override
  String get continueFullSetup => 'Vollständige Einrichtung fortsetzen';

  @override
  String get continueRun => 'Lauf fortsetzen';

  @override
  String get continueToSetup => 'Zur Einrichtung fortfahren';

  @override
  String get controlSurface => 'STEUEROBERFLÄCHE';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Steuert den Zugriff auf $arg1-Tools.';
  }

  @override
  String get conversation => 'Unterhaltung';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Unterhaltungs-ID, die verwendet wird, wenn dieser Agent einen Chat startet.';

  @override
  String get cookieSetup => 'Cookie-Einrichtung';

  @override
  String get cookiesNotConfigured => 'Cookies nicht konfiguriert';

  @override
  String get copiedAsCsv => 'Als CSV kopiert';

  @override
  String get copiedDebugInfo => 'Debug-Info kopiert';

  @override
  String get copiedExportForTheLast5 =>
      'Export der letzten 5 Nachrichten kopiert';

  @override
  String get copiedFullPrompt => 'Vollständiger Prompt kopiert';

  @override
  String get copiedLogs => 'Logs kopiert';

  @override
  String get copiedRunId => 'Ausführungs-ID kopiert';

  @override
  String get copy => 'Kopieren';

  @override
  String get copyAll => 'Alles kopieren';

  @override
  String get copyCodes => 'Codes kopieren';

  @override
  String get copyCsv => 'CSV kopieren';

  @override
  String get copyDebugInfo => 'Debug-Info kopieren';

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get copyLogs => 'Logs kopieren';

  @override
  String get copyPrompt => 'Prompt kopieren';

  @override
  String get copyResponse => 'Antwort kopieren';

  @override
  String get copyRunId => 'Ausführungs-ID kopieren';

  @override
  String get copyWebhookUrl => 'Webhook-URL kopieren';

  @override
  String get core => 'Kern';

  @override
  String get coreMemory => 'Kernspeicher';

  @override
  String get coreServicesThisServerDependsOn =>
      'Kerndienste, von denen dieser Server abhängt.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https public url origins';

  @override
  String get couldHelp => 'Könnte helfen';

  @override
  String get couldNotApproveQrLogin =>
      'QR-Anmeldung konnte nicht genehmigt werden.';

  @override
  String get couldNotApproveQrPairing =>
      'QR-Pairing konnte nicht freigegeben werden.';

  @override
  String get couldNotConnect => 'Verbindung fehlgeschlagen.';

  @override
  String get couldNotCreateBinding => 'Bindung konnte nicht erstellt werden.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Ihr Konto konnte nicht gelöscht werden: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Bitwarden konnte nicht getrennt werden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Home Assistant konnte nicht getrennt werden.';

  @override
  String get couldNotDisconnectNeorecall =>
      'NeoRecall konnte nicht getrennt werden.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Nextcloud konnte nicht getrennt werden.';

  @override
  String get couldNotDisconnectTrello => 'Trello konnte nicht getrennt werden.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Ihre Daten konnten nicht exportiert werden: $arg1';
  }

  @override
  String get couldNotLoadDecisions =>
      'Entscheidungen konnten nicht geladen werden';

  @override
  String get couldNotLoadUsageData =>
      'Nutzungsdaten konnten nicht geladen werden.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Linux-Einstellungen konnten nicht automatisch geöffnet werden.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Die Anbieterverknüpfungsseite konnte nicht geöffnet werden.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Die Anbieter-Anmeldeseite konnte nicht geöffnet werden.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Das Release-Asset konnte nicht geöffnet werden.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Trello konnte nicht in Ihrem Browser geöffnet werden.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Workspace-Datei-Download konnte nicht geöffnet werden.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Das Android-App-Paket konnte nicht gelesen werden.';

  @override
  String get couldNotReadTheApk => 'Die APK konnte nicht gelesen werden.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Schlüssel konnte nicht entfernt werden: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Agent konnte nicht gespeichert werden.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Bitwarden-Einrichtung konnte nicht gespeichert werden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Home-Assistant-Einrichtung konnte nicht gespeichert werden.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'NeoRecall-Einrichtung konnte nicht gespeichert werden.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nextcloud-Einrichtung konnte nicht gespeichert werden.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Trello-Einrichtung konnte nicht gespeichert werden.';

  @override
  String get couldNotSendConfirmationEmail =>
      'Bestätigungs-E-Mail konnte nicht gesendet werden';

  @override
  String get couldNotStart => 'Start fehlgeschlagen';

  @override
  String get couldNotStartCheckoutCheckStripe =>
      'Checkout konnte nicht gestartet werden. Prüfen Sie die Stripe-Konfiguration.';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Erstellen';

  @override
  String get createAPasswordFirstToChange =>
      'Erstellen Sie zuerst ein Passwort, um Ihre Konto-E-Mail zu ändern.';

  @override
  String get createAPasswordOrLinkAnother =>
      'legen Sie ein Passwort an oder verknüpfen Sie einen anderen Anbieter, bevor Sie diese Anmeldemethode entfernen';

  @override
  String get createATaskWhileThisAgent =>
      'Erstellen Sie eine Aufgabe, während dieser Agent ausgewählt ist.';

  @override
  String get createLink => 'Link erstellen';

  @override
  String get createOrModifyFilesInYour =>
      'Dateien in Ihrem Workspace erstellen oder ändern.';

  @override
  String get createPassword => 'Passwort erstellen';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Erstellen Sie Spezialisten-Bots mit eigenem Gedächtnis, eigenen Einstellungen, Werkzeugen und Kontenzuweisungen.';

  @override
  String get createTheFirstAccount => 'Erstes Konto erstellen';

  @override
  String get createUpdateOrDeleteSkills =>
      'Skills erstellen, aktualisieren oder löschen.';

  @override
  String get creatingYourSkill => 'Ihr Skill wird erstellt…';

  @override
  String get credentialBindings => 'Anmeldedaten-Bindungen';

  @override
  String get credentialUse => 'Anmeldedaten verwenden';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Wiederkehrende Cron-Läufe und einmalige zeitgesteuerte Ausführung.';

  @override
  String get cronExpression => 'Cron-Ausdruck';

  @override
  String get ctrlEnterRunsTheQuery => 'Strg/⌘ + Enter führt die Abfrage aus.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Space';

  @override
  String get currency => 'Währung';

  @override
  String get currencyMustBeA3Letter =>
      'Die Währung muss ein dreistelliger Code wie usd sein.';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Aktuelle E-Mail: $arg1';
  }

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get currentPasswordIsIncorrect => 'aktuelles Passwort ist falsch';

  @override
  String get currentPlan => 'Aktueller Plan';

  @override
  String get currentPlan2 => 'AKTUELLER TARIF';

  @override
  String get currentTwoStepLoginCode => 'Aktueller Zwei-Schritt-Anmeldecode';

  @override
  String get customAccess => 'Benutzerdefinierter Zugriff';

  @override
  String get customCron => 'Eigener Cron';

  @override
  String get customCronMustHave5Fields => 'Eigener Cron muss 5 Felder haben.';

  @override
  String get customEndpoint => 'benutzerdefinierter Endpunkt';

  @override
  String get customField => 'Benutzerdefiniertes Feld';

  @override
  String get customHeader => 'Benutzerdefinierter Header';

  @override
  String get customHeadersJson => 'Eigene Header (JSON)';

  @override
  String get customOpenaiCompatible => 'Eigene OpenAI-kompatible';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Eigener OpenAI-kompatibler Endpunkt';

  @override
  String get customOutgoingUrl => 'Eigene ausgehende URL';

  @override
  String get customersOverridePlanStatusCanceledTrialing =>
      'kunden überschreibung tarif status gekündigt testphase';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Täglich';

  @override
  String get dailyRecap => 'Täglicher Rückblick';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'datenbank abfrage select csv vorlagen';

  @override
  String dayArg1(Object? arg1) {
    return 'Tag $arg1';
  }

  @override
  String get dayOfMonth => 'Tag des Monats';

  @override
  String get deactivate => 'Deaktivieren';

  @override
  String deactivateArg1(Object? arg1) {
    return '$arg1 deaktivieren?';
  }

  @override
  String get decideWhichToolsYourAgentMay =>
      'es, welche Tools Ihr Agent nutzen darf. Es sieht Ihren Namen und ';

  @override
  String get decisionHigherUpTheChainWins =>
      'Entscheidung weiter oben in der Kette hat Vorrang und zeigt ein Schloss mit dem ';

  @override
  String get decisionsFromTodayThenListAnything =>
      'Entscheidungen von heute zusammen, und liste dann auf, was ich ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Entscheidungen erscheinen hier, während $arg1 freigegebene $arg2-Gruppen liest. Nur die letzten 30 werden behalten und beim Neustart des Servers zurückgesetzt.';
  }

  @override
  String get decline => 'Ablehnen';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'Deep-Lauf · Schritt $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram-Schlüssel';

  @override
  String get default2 => 'Standard';

  @override
  String get default3 => 'STANDARD';

  @override
  String defaultArg1(Object? arg1) {
    return 'Standard ($arg1)';
  }

  @override
  String get defaultConversation => 'Standardunterhaltung';

  @override
  String get defaultForNewGroups => 'Standard für neue Gruppen';

  @override
  String get defaultGroupParticipation => 'Standard-Gruppenteilnahme';

  @override
  String get defaultNeoagentWorkspace => 'Standard NeoAgent Workspace';

  @override
  String get defaultOpenai => 'Standard (OpenAI)';

  @override
  String get defaultRateLimits => 'Standard-Ratenlimits';

  @override
  String get defaultRateLimitsSaved => 'Standard-Ratenlimits gespeichert.';

  @override
  String get defaultRecommended => 'Standard (empfohlen)';

  @override
  String get defaultRouting => 'Standard-Routing';

  @override
  String get defaultSpace => 'Standard-Space';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountPermanently => 'Konto dauerhaft löschen?';

  @override
  String get deleteAnAccount => 'Konto löschen';

  @override
  String deleteArg1(Object? arg1) {
    return '@$arg1 löschen?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Löschen ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 dauerhaft löschen?';
  }

  @override
  String get deleteBinding => 'Bindung löschen';

  @override
  String get deleteCoreMemoryEntry => 'Kernspeicher-Eintrag löschen?';

  @override
  String get deleteForever => 'Endgültig löschen';

  @override
  String get deleteMcpServer => 'MCP-Server löschen?';

  @override
  String get deleteMemory => 'Erinnerung löschen?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Löschen entfernt ein Konto und alle zugehörigen Daten dauerhaft ';

  @override
  String get deleteRun => 'Ausführung löschen?';

  @override
  String get deleteRun2 => 'Ausführung löschen';

  @override
  String get deleteSelectedMemories => 'Ausgewählte Erinnerungen löschen?';

  @override
  String get deleteSession => 'Sitzung löschen?';

  @override
  String get deleteSkill => 'Skill löschen?';

  @override
  String get deleteTask => 'Aufgabe löschen?';

  @override
  String deletedArg1(Object? arg1) {
    return '\"$arg1\" gelöscht.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return '@$arg1 und alle zugehörigen Daten gelöscht.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Das Löschen entfernt alle Ihre Unterhaltungen, Erinnerungen, Dateien, Aufgaben und ';

  @override
  String get deliverableArtifactProduced =>
      'Artefakt des Liefergegenstands erzeugt';

  @override
  String get deliverableCompleted => 'Liefergegenstand abgeschlossen';

  @override
  String get deliverableExecutionStarted =>
      'Ausführung des Liefergegenstands gestartet';

  @override
  String get deliverableSelected => 'Liefergegenstand ausgewählt';

  @override
  String get deliverableValidationFailed =>
      'Validierung des Liefergegenstands fehlgeschlagen';

  @override
  String get deliverableValidationStarted =>
      'Validierung des Liefergegenstands gestartet';

  @override
  String get deny => 'Ablehnen';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Beschreiben Sie das Ergebnis und demonstrieren Sie es dann auf dem Desktop';

  @override
  String get describeWhatToBuildOrChange =>
      'Beschreiben Sie, was gebaut oder geändert werden soll…';

  @override
  String get description => 'Beschreibung';

  @override
  String get desktopApp => 'Desktop-App';

  @override
  String get desktopAppControlsAvailable => 'Desktop-App-Steuerung verfügbar';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Desktop-Aufnahme ist auf dieser Plattform nicht verfügbar.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Upload der Desktop-Befehlsausgabe abgebrochen.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Befehl des Desktop-Begleiters wurde abgebrochen.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Verbindung zum Desktop-Begleiter ist abgelaufen.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Handshake des Desktop-Begleiters ist abgelaufen.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Der Desktop-Begleiter ist hier nicht verfügbar.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Desktop-Begleiter ist lokal pausiert.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Verarbeitung der Desktop-Begleiter-Nachricht fehlgeschlagen: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Berechtigungseinstellungen des Desktop-Begleiters sind im Web nicht verfügbar.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Berechtigungseinstellungen des Desktop-Begleiters sind auf dieser Plattform nicht verfügbar.';

  @override
  String get desktopCompanionRejected => 'Desktop-Begleiter abgelehnt.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Antwort des Desktop-Begleiters fehlgeschlagen: $arg1';
  }

  @override
  String get desktopControl => 'Desktop-Steuerung';

  @override
  String get desktopFailedToStart => 'Desktop-Start fehlgeschlagen';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Desktop-Stream-Aufnahme fehlgeschlagen: $arg1';
  }

  @override
  String get desktopToFinishTheJob => 'Desktop, um die Aufgabe zu erledigen.';

  @override
  String get destinationId => 'Ziel-ID';

  @override
  String get detail => 'DETAILS';

  @override
  String get deviceAccess => 'Gerätezugriff';

  @override
  String get deviceIpAddress => 'Geräte-IP-Adresse';

  @override
  String get deviceSettings => 'Geräteeinstellungen';

  @override
  String get devices => 'Geräte';

  @override
  String get diagnosticsSaved => 'Diagnose gespeichert.';

  @override
  String get directBluebubblesImessageBridge =>
      'Direkte BlueBubbles-iMessage-Brücke';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Direktnachrichten bleiben reaktionsschnell. Freigeschaltete Gruppen nutzen den Teilnahmemodus unten.';

  @override
  String get directoryDoesNotExist => 'Verzeichnis existiert nicht.';

  @override
  String get disable2fa => '2FA deaktivieren';

  @override
  String get disableAll => 'Alle deaktivieren';

  @override
  String get discard => 'Verwerfen';

  @override
  String get disconnect => 'Trennen';

  @override
  String get disconnectHomeAssistant => 'Home Assistant trennen?';

  @override
  String get disconnectNeorecall => 'NeoRecall trennen?';

  @override
  String get disconnectNextcloud => 'Nextcloud trennen?';

  @override
  String get disconnectPlatform => 'Plattform trennen';

  @override
  String get disconnectTrello => 'Trello trennen?';

  @override
  String get discover => 'Entdecken';

  @override
  String get discoveryFailed => 'Erkennung fehlgeschlagen';

  @override
  String get dismiss => 'Schließen';

  @override
  String get displayIdIsRequired => 'Anzeige-ID ist erforderlich.';

  @override
  String get displayName => 'Anzeigename';

  @override
  String get displayNameMustBe64Characters =>
      'Der Anzeigename darf höchstens 64 Zeichen lang sein.';

  @override
  String get displayNameSaved => 'Anzeigename gespeichert.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Verwenden Sie nicht Ihren Benutzernamen oder Ihre E-Mail.';

  @override
  String get done => 'Fertig';

  @override
  String get downloadACopyOfYourData =>
      'Laden Sie eine Kopie Ihrer Daten herunter. Admin-Konten können sich nicht ';

  @override
  String get downloadACopyOfYourData2 =>
      'Laden Sie eine Kopie Ihrer Daten herunter oder löschen Sie Ihr Konto dauerhaft. ';

  @override
  String downloadArg1(Object? arg1) {
    return '$arg1 herunterladen';
  }

  @override
  String get downloadPdf => 'PDF herunterladen';

  @override
  String get downloadUpdate => 'Update herunterladen';

  @override
  String get downloadingTheNeoagentBackend =>
      'NeoAgent-Backend wird heruntergeladen';

  @override
  String get draft => 'Entwurf';

  @override
  String get dragIsNotSupportedOnThis =>
      'drag wird auf dieser Plattform nicht unterstützt.';

  @override
  String get draggedOnTheScreen => 'Auf dem Bildschirm gezogen';

  @override
  String get dropAnApkOrApkBundle =>
      'Legen Sie eine APK oder ein APK-Bundle hier ab, um sie zu installieren';

  @override
  String get dropApkOrApksHere => 'APK oder .apks hier ablegen';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Dauerhafte Anweisungen für Stimme und Interaktionsstil. Sicherheits- und Ausführungsregeln haben weiterhin Vorrang.';

  @override
  String get eGAlexSLaptop => 'z. B. Alex’ Laptop';

  @override
  String get eGMyLocalServer => 'z. B. Mein lokaler Server';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get editAgent => 'Agent bearbeiten';

  @override
  String editArg1(Object? arg1) {
    return '$arg1 bearbeiten';
  }

  @override
  String get editCoreMemoryEntry => 'Kernspeicher-Eintrag bearbeiten';

  @override
  String get editInstructions => 'Anweisungen bearbeiten';

  @override
  String get editMcpServer => 'MCP-Server bearbeiten';

  @override
  String get editTask => 'Aufgabe bearbeiten';

  @override
  String editedArg1(Object? arg1) {
    return '$arg1 bearbeitet';
  }

  @override
  String get email => 'E-Mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Kontoinhaber per E-Mail über ungewöhnlich wirkende Anmeldungen informieren.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Kontoinhaber per E-Mail benachrichtigen, wenn sich ihre Kontodetails ändern.';

  @override
  String get emailCode => 'E-Mail-Code';

  @override
  String get emailConfirmationRequired => 'E-Mail-Bestätigung erforderlich';

  @override
  String get emailIsAlreadyInUse => 'E-Mail wird bereits verwendet';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-Mail gespeichert. Falls eine Bestätigung nötig ist, prüfen Sie die neue Adresse auf einen NeoAgent-Bestätigungslink.';

  @override
  String get emailSettingsSaved => 'E-Mail-Einstellungen gespeichert.';

  @override
  String get emailUnverified => 'E-Mail nicht verifiziert';

  @override
  String get emailsAiActionsTasksAndRun =>
      'E-Mails, KI-Aktionen, Aufgaben und Laufaktivität in einem chronologischen Feed.';

  @override
  String get empty => 'Leer';

  @override
  String get emptyFile => 'Leere Datei';

  @override
  String get emptyFolder => 'Leerer Ordner';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Leer lässt den Server-Standard ($arg1).';
  }

  @override
  String get enable2fa => '2FA aktivieren';

  @override
  String get enableAll => 'Alle aktivieren';

  @override
  String get enableBehaviorModules => 'Verhaltensmodule aktivieren';

  @override
  String get enableOrDisableModels => 'Modelle aktivieren oder deaktivieren';

  @override
  String get enabled => 'Aktiviert';

  @override
  String get encryptedPrivateToYourAccount =>
      'Verschlüsselt, nur für Ihr Konto';

  @override
  String get end => 'Ende';

  @override
  String get endCall => 'Anruf beenden';

  @override
  String get endVoiceCall => 'Sprachanruf beenden?';

  @override
  String get endpoint => 'Endpunkt';

  @override
  String get enterAPassword => 'Geben Sie ein Passwort ein.';

  @override
  String get enterAUsername => 'Geben Sie einen Benutzernamen ein.';

  @override
  String get enterAValidEmailAddress =>
      'Geben Sie eine gültige E-Mail-Adresse ein.';

  @override
  String get enterAnAddressManually => 'Adresse manuell eingeben';

  @override
  String get enterAnApiKeyFirst => 'Geben Sie zuerst einen API-Schlüssel ein.';

  @override
  String get enterInviteLink => 'Einladungslink eingeben';

  @override
  String get enterTheAddressOfANeoagent =>
      'Geben Sie die Adresse eines NeoAgent-Servers ein.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Geben Sie die Angaben ein, die $arg1 Ihnen mitgeteilt hat, damit $arg2 Nachrichten senden und empfangen kann.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Geben Sie Ihren 2FA- oder Wiederherstellungscode ein.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Geben Sie Ihr aktuelles Passwort ein, um es zu ändern.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Geben Sie Ihr aktuelles Passwort ein, um E-Mail-Änderungen zu speichern.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Geben Sie Ihre NeoAgent-Kontodaten ein.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Geben Sie Ihren Benutzernamen oder Ihre Konto-E-Mail ein. NeoAgent sendet einen Zurücksetzungslink, wenn das Konto gefunden wird.';

  @override
  String get enterYourUsernameOrEmail =>
      'Geben Sie Ihren Benutzernamen oder Ihre E-Mail ein.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entität: $arg1';
  }

  @override
  String get environment => 'Umgebung';

  @override
  String get error => 'Fehler';

  @override
  String errorArg1(Object? arg1) {
    return '\nFehler: $arg1';
  }

  @override
  String errorArg12(Object? arg1) {
    return 'Fehler: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Fehler aus dem aktuellen Protokoll, nach Nachricht gruppiert.';

  @override
  String get errorsProblemsFailures => 'fehler probleme ausfälle';

  @override
  String get eventDetail => 'Ereignisdetail';

  @override
  String get eventTypesCommaSeparated => 'Ereignistypen (kommagetrennt)';

  @override
  String get every15Minutes => 'Alle 15 Minuten';

  @override
  String get every30Minutes => 'Alle 30 Minuten';

  @override
  String get everyAccountOnThisServerLoses =>
      'Jedes Konto auf diesem Server verliert diesen gemeinsamen Schlüssel. Konten, ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'jedes Konto auf diesem Server. Geheimnisse sind nur schreibbar: lassen Sie ';

  @override
  String get everyAccountOnThisServerUses =>
      'Jedes Konto auf diesem Server verwendet diese Adresse für ';

  @override
  String get everyAccountSSubscriptionMostRecently =>
      'Abonnement jedes Kontos, zuletzt geänderte zuerst. ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Jede aktive Sitzung für dieses Konto wird beendet. Die Anmeldung ist ';

  @override
  String get everyDay0800 => 'Täglich · 08:00';

  @override
  String get everyDay2000 => 'Täglich · 20:00';

  @override
  String get everyHour => 'Stündlich';

  @override
  String get everyModel => 'jedes Modell zu erlauben.';

  @override
  String get everyRunOnThisServerAll =>
      'Jeder Lauf auf diesem Server, insgesamt.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Jedes sensible Tool erfordert jedes Mal eine Freigabe.';

  @override
  String get everySessionGetsAPrivateCloud =>
      'Jede Sitzung erhält einen privaten Cloud-Computer, damit NeoAgent echte ';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Jedes Tool läuft ohne Nachfrage, außer denen, die die Person ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Alle in diesen Gruppen, Kanälen oder Räumen können mit $arg1 sprechen.';
  }

  @override
  String get everyoneInThisGroup => 'Alle in dieser Gruppe';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Alles, was $arg1 für Ihren Agenten ausgeschaltet hat, wird ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Alles andere ist ausgeschaltet.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Alles ist über den Desktop verfügbar.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Alles, was der Agent nutzen kann: offizielle Integrationen, MCP-Server und Skills.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Alles, was Sie für $arg1 ausgeschaltet haben, wird wieder ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Genaue Web-Origins, die Cross-Origin-Anfragen stellen dürfen, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'JavaScript in Ihrer Browser-Sitzung ausführen.';

  @override
  String get execution => 'Ausführung';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Ausführungsdetails sind für diesen Lauf nicht verfügbar.';

  @override
  String get executionPlanCreated => 'Ausführungsplan erstellt.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Training $arg1 Sitzungen';
  }

  @override
  String get existingSubscribersKeepAccessUntilTheir =>
      'bestehende Abonnenten behalten den Zugang bis zum Periodenende.';

  @override
  String exitArg1(Object? arg1) {
    return '[exit $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Läuft ab $arg1';
  }

  @override
  String get explainThisProject => 'Dieses Projekt erklären';

  @override
  String exploredArg1(Object? arg1) {
    return '$arg1 erkundet';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1$arg2 erkundet';
  }

  @override
  String get exploredTheWorkspace => 'Arbeitsbereich erkundet';

  @override
  String get exportAll => 'Alle exportieren';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Export fehlgeschlagen: $arg1';
  }

  @override
  String get exportLast5Messages => 'Letzte 5 Nachrichten exportieren';

  @override
  String get exportMyData => 'Meine Daten exportieren';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Start des externen Browsers fehlgeschlagen mit Exit-Code $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Das Starten eines externen Browsers wird auf dieser Plattform nicht unterstützt.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Start des externen Browsers ist abgelaufen.';

  @override
  String get externalMcpTools => 'Externe & MCP-Tools';

  @override
  String get extraButtons => 'Zusätzliche Tasten';

  @override
  String get extractingTheNeoagentRuntime => 'NeoAgent-Laufzeit wird entpackt';

  @override
  String get failed => 'Fehlgeschlagen';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Verbindung fehlgeschlagen: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Verbindung mit $arg1 fehlgeschlagen: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Löschen von \"$arg1\" fehlgeschlagen: $arg2';
  }

  @override
  String failedToDismissOnboardingArg1(Object? arg1) {
    return 'Onboarding konnte nicht geschlossen werden: $arg1';
  }

  @override
  String get failedToFetch => 'Abruf fehlgeschlagen';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Prompt konnte nicht erzeugt werden: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Externer Browser konnte über url_launcher nicht gestartet werden.';

  @override
  String get failedToLaunchOauthFlow =>
      'OAuth-Ablauf konnte nicht gestartet werden.';

  @override
  String get failedToLoadPolicies => 'Richtlinien konnten nicht geladen werden';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Speichern fehlgeschlagen: $arg1';
  }

  @override
  String get failedToSaveMcpServer =>
      'MCP-Server konnte nicht gespeichert werden.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Auswahl konnte nicht gespeichert werden: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Benachrichtigung an Backend konnte nicht gesendet werden: $arg1';
  }

  @override
  String get fair => 'Ausreichend';

  @override
  String get fasterReplies => 'Schnellere Antworten';

  @override
  String get features => 'Funktionen';

  @override
  String get fewerModelCalls => 'Weniger Modellaufrufe';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'Feld leer, um den integrierten Standard wiederherzustellen.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Datei überschreitet das 1-MiB-Editorlimit.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Datei überschreitet das unterstützte Größenlimit.';

  @override
  String get fileWrites => 'Dateischreiben';

  @override
  String get filename => 'Dateiname';

  @override
  String get files => 'Dateien';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Dateien, die NeoAgent in dieser Sitzung schreibt oder bearbeitet, erscheinen hier.';

  @override
  String get filesSavedByAllUsers => 'Von allen Nutzern gespeicherte Dateien';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Genehmigte Anmeldungen ausfüllen oder Anfragen authentifizieren, ohne Geheimnisse der KI zu zeigen.';

  @override
  String get finalResponse => 'Endgültige Antwort';

  @override
  String get findAPlatform => 'Plattform finden';

  @override
  String get findAndFixABug => 'Einen Fehler finden und beheben';

  @override
  String get findRecentChats => 'Letzte Chats finden';

  @override
  String get findTheseLaterInTasks => 'finden Sie sie später unter Aufgaben.';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Passende NeoAgent-Laufzeit wird gesucht';

  @override
  String get finish => 'Fertig';

  @override
  String get finishAtTheScheduledTime => 'Zur geplanten Zeit fertig sein';

  @override
  String get finishSetup => 'Einrichtung abschließen';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Schließen Sie die Anmeldung bei $arg1 in Ihrem Browser ab und verbinden Sie sich dann erneut.';
  }

  @override
  String get flowGraph => 'Ablaufdiagramm';

  @override
  String get flutterApp => 'Flutter-App';

  @override
  String get focusedExecutionProfile => 'Fokussiertes Ausführungsprofil';

  @override
  String get folderIdOptional => 'Ordner-ID (optional)';

  @override
  String get folderUnavailable => 'Ordner nicht verfügbar';

  @override
  String get forExampleHttpsMatrixOrg => 'Zum Beispiel https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Für gehostete oder erweiterte Netzwerkeinrichtungen';

  @override
  String get forLinksInEmailsBlankUses =>
      'Für Links in E-Mails. Leer lässt die öffentliche Server-URL gelten.';

  @override
  String get forgotPassword => 'Passwort vergessen?';

  @override
  String get frameUnavailable => 'Frame nicht verfügbar';

  @override
  String get freeTrialDays => 'Kostenlose Testphase (Tage)';

  @override
  String get freeTrialMustBeAWhole =>
      'Die kostenlose Testphase muss eine ganze Zahl an Tagen sein (0 oder mehr).';

  @override
  String freshnessArg1(Object? arg1) {
    return 'Aktualität: $arg1';
  }

  @override
  String get fridays1700 => 'Freitags · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Von BotFather, nachdem Sie den Bot erstellt haben.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Ab jetzt entscheidet $arg1, welche Tools Ihr Agent nutzen darf. Diese Person sieht ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Aus dem Discord Developer Portal unter Ihrem Bot.';

  @override
  String get fromTheLineDevelopersConsole => 'Aus der LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Aus dem Matrix-Client oder Bot-Konto.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Von twitchapps.com/tmi oder Ihrer Twitch-Entwickler-App.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Vollständiger Prompt';

  @override
  String get fullSetup => 'Vollständige Einrichtung';

  @override
  String fullTextFtsArg1(Object? arg1) {
    return 'Volltext (FTS): $arg1';
  }

  @override
  String get general => 'Allgemein';

  @override
  String get generalSettings => 'Allgemeine Einstellungen';

  @override
  String get generalSettingsSaved => 'Allgemeine Einstellungen gespeichert.';

  @override
  String get generateAPromptForAnotherAi =>
      'Erzeugen Sie einen Prompt für eine andere KI und fügen Sie die Antwort hier ein, um Erinnerungen zu importieren.';

  @override
  String get generatePrompt => 'Prompt erzeugen';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geofence-Tracking-Fehler: $arg1';
  }

  @override
  String get getInspired => 'Inspiration holen';

  @override
  String get gitCloneRepoNpmTest => 'git clone repo && npm test';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot und OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHub-Issue eröffnet';

  @override
  String get neorecallMemoryCreated => 'NeoRecall-Erinnerung erstellt';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'GitHub-Release-Prüfung fehlgeschlagen mit HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'GitHub-Release-Payload war keine Release-Liste.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub-Benutzername, der das Issue eröffnet hat';

  @override
  String get giveThePlanAName => 'Geben Sie dem Tarif einen Namen.';

  @override
  String get globalSecurityMode => 'Globaler Sicherheitsmodus';

  @override
  String get gmailMessageReceived => 'Gmail-Nachricht empfangen';

  @override
  String get good => 'Gut';

  @override
  String get goodAfternoon => 'Guten Tag';

  @override
  String get goodEvening => 'Guten Abend';

  @override
  String get goodMorning => 'Guten Morgen';

  @override
  String get goodPasswordALittleMoreLength =>
      'Gutes Passwort. Etwas mehr Länge macht es stärker.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live nutzt Ihren OpenAI-API-Schlüssel, Gemini Live Ihren Google-AI-Schlüssel. Änderungen gelten für den nächsten Anruf.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Erteilen Sie Health-Connect-Berechtigungen vor der Synchronisierung.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Gruppe, Kanal oder Raum';

  @override
  String get groupType => 'Gruppentyp';

  @override
  String get groupsAndChannels => 'Gruppen und Kanäle';

  @override
  String groupsArg1(Object? arg1) {
    return 'Gruppen: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Gruppen, die $arg1 noch nicht gesehen hat, folgen dieser Einstellung.';
  }

  @override
  String get handlesDirectTasksItself => 'Erledigt direkte Aufgaben selbst';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Freihändig (frei sprechen, jederzeit unterbrechen)';

  @override
  String get hardwareBridges => 'Hardware-Brücken';

  @override
  String get headerName => 'Header-Name';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Schlagzeilen zu Ihren Themen, gefiltert auf das Wesentliche.';

  @override
  String get health => 'Gesundheit';

  @override
  String get healthChecks => 'Gesundheitsprüfungen';

  @override
  String get healthConnect => 'Health Connect';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect ist auf diesem Gerät nicht verfügbar.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health-Connect-Synchronisationsstatus und gespeicherte Backend-Metriken.';

  @override
  String get healthStatusIsUnavailable =>
      'Gesundheitsstatus ist nicht verfügbar.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Gesundheitssynchronisierung ist nur unter Android verfügbar.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Herz $arg1 Einträge';
  }

  @override
  String get heldBack => 'Zurückgehalten';

  @override
  String get helper => 'Helfer';

  @override
  String helperArg1(Object? arg1) {
    return 'Helfer: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'gelöscht werden. Entziehen Sie zuerst die Admin-Rechte mit `neoagent admin revoke $arg1`.';
  }

  @override
  String get hereSecretsAreWriteOnlyLeave =>
      'hier ein. Geheimnisse sind nur schreibbar: lassen Sie eines leer, um es zu behalten.';

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Höhere Werte machen NeoAgent in Gruppen selektiver.';

  @override
  String get highlyRecommended => 'Sehr empfohlen';

  @override
  String get holdButton131ForTheAssistant =>
      'Taste 131 für den Assistenten gedrückt halten.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Ctrl+Shift+Space gedrückt halten zum Sprechen';

  @override
  String get holdToTalk => 'Gedrückt halten zum Sprechen.';

  @override
  String get holdToTalk2 => 'Gedrückt halten zum Sprechen';

  @override
  String get home => 'Start';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Home-Assistant Long-Lived Access Token ist erforderlich.';

  @override
  String get homeAssistantSetup => 'Home-Assistant-Einrichtung';

  @override
  String get homeAssistantUrl => 'Home-Assistant-URL';

  @override
  String get homeAssistantUrlIsRequired =>
      'Home-Assistant-URL ist erforderlich.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Homeserver-Token mit Raum-Abfrage';

  @override
  String get homeserverUrl => 'Homeserver-URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'gehosteten Dienst). Ihre Schlüssel werden verschlüsselt und sind nur für ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Hostname des IRC-Netzwerks, zum Beispiel irc.libera.chat';

  @override
  String get hourly => 'Stündlich';

  @override
  String get hourlyInboxCheck => 'Stündliche Posteingangsprüfung';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Wie lange Bestätigungslinks gültig bleiben.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Wie oft dieser Agent nach neuen Raumnachrichten sucht.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Wie oft dieser Agent nach neuen Signal-Nachrichten sucht.';

  @override
  String get howTeamsWork => 'So funktionieren Teams';

  @override
  String get howThisServerIsReachedPlus =>
      'Wie dieser Server erreichbar ist, plus serverseitige Schalter.';

  @override
  String get httpsSessionCookie => 'https sitzung cookie';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Diese Anfrage konnte gerade nicht abgeschlossen werden. Bitte versuchen Sie es in einem Moment erneut.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Untätig';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Wenn $arg1 eine Webhook-URL verlangt, fügen Sie diese ein, damit Nachrichten $arg2 erreichen.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Wenn für dieses Konto eine bestätigte E-Mail hinterlegt ist, sendet NeoAgent einen Link zum Zurücksetzen des Passworts.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Falls der Dienst ein Token bei ausgehenden Anfragen erfordert.';

  @override
  String get ignoreGroups => 'Gruppen ignorieren';

  @override
  String get ignoreThisChat => 'Diesen Chat ignorieren';

  @override
  String get ignoredChannels => 'Ignorierte Kanäle';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Fehlerhafte Desktop-Begleiter-Nachricht ignoriert: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Wicht. $arg1';
  }

  @override
  String get implementThePlanAbove => 'Setzen Sie den obigen Plan um.';

  @override
  String get implementThisPlan => 'Diesen Plan umsetzen';

  @override
  String get implicitTls => 'Implizites TLS';

  @override
  String get import => 'Importieren';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import fehlgeschlagen: $arg1';
  }

  @override
  String get importFromComputer => 'Vom Computer importieren';

  @override
  String get importMemoryTransfer => 'Speicherübertragung importieren?';

  @override
  String get importance => 'Wichtigkeit';

  @override
  String importedArg1Memories(Object? arg1) {
    return '$arg1 Erinnerungen importiert, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'Im Team von @$arg1';
  }

  @override
  String get inBackground => 'Hintergrund';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Eingehende und ausgehende Kanalnachrichten erscheinen hier.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Eingehende In-App-Sprachanrufe von NeoAgent';

  @override
  String get incomingMessages => 'Eingehende Nachrichten';

  @override
  String get incomingNeoagentCall => 'Eingehender NeoAgent-Anruf';

  @override
  String get incomingNeoagentCall2 => 'EINGEHENDER NEOAGENT-ANRUF';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Eingehender Webhook und ausgehender Callback';

  @override
  String get incorporatingSteering => 'Steuerung wird übernommen';

  @override
  String get input => 'Eingabe';

  @override
  String get inputMode => 'Eingabemodus';

  @override
  String get insertATemplate => 'Vorlage einfügen';

  @override
  String get inspect => 'Prüfen';

  @override
  String get install => 'Installieren';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installieren Sie eine signierte, eigenständige Runtime. Node.js, npm, Git und Terminalbefehle sind nicht erforderlich.';

  @override
  String get installApk => 'APK installieren';

  @override
  String get installApkBundle => 'APK / Bundle installieren';

  @override
  String get installApkClickOrDropA =>
      'APK installieren — klicken oder .apk-Datei ablegen';

  @override
  String get installNeoagent => 'NeoAgent installieren';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installieren Sie NeoAgent auf diesem Computer ohne Terminal, oder verbinden Sie sich mit einer bereits laufenden Instanz.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installieren Sie neue Versionen und wählen Sie, welchen Kanal dieser Server folgt.';

  @override
  String get installTheBackend => 'Backend installieren';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installieren Sie den Kern mit zusätzlicher optionaler Einrichtung. KI-Anbieterschlüssel werden danach hinzugefügt, wie beim Schnellstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installieren Sie den sicheren Kern und erstellen Sie anschließend Ihr Konto. KI-Anbieterschlüssel fügen Sie danach hinzu.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Installiert: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Installiert: $arg1 • Zuletzt geprüft: $arg2';
  }

  @override
  String get instructions => 'Anweisungen';

  @override
  String get integration => 'Integration';

  @override
  String get integrationApps => 'Integrations-Apps';

  @override
  String get integrationConnections => 'Integrationsverbindungen';

  @override
  String get integrationSettingsSaved =>
      'Integrationseinstellungen gespeichert.';

  @override
  String get integrations => 'Integrationen';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback zu verwenden, und registrieren Sie dieselbe ';

  @override
  String get interruptAi => 'KI unterbrechen';

  @override
  String get invalid2fa => 'ungültige 2FA';

  @override
  String get invalidArgumentS => 'Ungültige(s) Argument(e): ';

  @override
  String get invalidCredentials => 'ungültige Anmeldedaten';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Ungültiges NeoAgent-Laufzeitmanifest.';

  @override
  String get inviteLink => 'Einladungslink';

  @override
  String get inviteLinkReady => 'Einladungslink bereit';

  @override
  String get inviteLinks => 'Einladungslinks';

  @override
  String get iphoneApp => 'iPhone-App';

  @override
  String get isAboutWhoIsInvolvedAnd =>
      'es geht, wer beteiligt ist und was ich vorbereiten sollte. Wenn morgen ';

  @override
  String get isEmptyDoNotSendAnything => 'nichts ansteht, sende nichts.';

  @override
  String get issues => 'Probleme';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Probleme erscheinen, sobald das Protokoll geladen ist.';

  @override
  String get itCanTBeUndone => 'Dies kann nicht rückgängig gemacht werden.';

  @override
  String get itMayHaveBeenDeleted => 'Möglicherweise wurde sie gelöscht.';

  @override
  String get javaRuntime => 'Java-Runtime';

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
    return 'Beigetreten $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Beigetreten in den letzten 7 Tagen';

  @override
  String get joiningATeam => 'Einem Team beitreten';

  @override
  String get joiningIsOffHere => 'Beitreten ist hier aus';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON-Feld mit dem Nachrichtentext. Üblicherweise text.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON-Feld, das den Empfänger der Nachricht angibt.';

  @override
  String get jumpToLatest => 'Zur neuesten springen';

  @override
  String get justNow => 'gerade eben';

  @override
  String get keepNeoagentRunning => 'NeoAgent weiterlaufen lassen?';

  @override
  String get keepPlan => 'Tarif behalten';

  @override
  String get keepRunning => 'Weiterlaufen lassen';

  @override
  String get keepTaskRunning => 'Aufgabe weiterlaufen lassen';

  @override
  String get keepTheVaultAvailable => 'Tresor verfügbar halten';

  @override
  String get keepThisLauncherUpToDate =>
      'Halten Sie diesen Launcher auf dem neuesten Stand.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Lassen Sie dieses Panel geöffnet, bis die Plattform die Verbindung bestätigt.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Computer dieser Sitzung sichtbar halten';

  @override
  String get keepTrackOfYourAiUsage =>
      'Behalten Sie Ihre KI-Nutzung im Blick. Limits sorgen für eine faire Nutzung auf der Plattform.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Nutzen Sie Ihre Apps weiter wie gewohnt. NeoAgent arbeitet auf demselben Bildschirm und fragt nach, wenn neuer Zugriff nötig ist.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Dieses Gerät verbunden halten';

  @override
  String get key => 'Schlüssel';

  @override
  String get keyIsRequired => 'Taste ist erforderlich.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Schlüssel-Wert-Paare, die über Gespräche hinweg erhalten bleiben.';

  @override
  String get kind => 'ART';

  @override
  String get knowledgeGraph => 'Wissensgraph';

  @override
  String get knowledgeView => 'Wissensansicht';

  @override
  String get labelOnlyYouSeeIt => 'Bezeichnung (nur Sie sehen sie)';

  @override
  String get labelsOptional => 'Labels (optional)';

  @override
  String get last24Hours => 'Letzte 24 Stunden';

  @override
  String get last7Days => 'Letzte 7 Tage';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Letzte 7 Tage: $arg1 Tokens in $arg2 Läufen';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Letzte $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Zuletzt: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Letzte nicht leere Synchronisation · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Letzter Lauf: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Zuletzt gesehen $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Letzte Anmeldung $arg1';
  }

  @override
  String get lastSyncSummary => 'Zusammenfassung der letzten Synchronisation';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Zuletzt verwendet: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Letztes Fenster endete $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'hinzugefügte Modelle ebenfalls deaktiviert.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Letzter Lauf · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Das Starten von Desktop-Apps wird auf dieser Plattform nicht unterstützt.';

  @override
  String get learnRoomNorms => 'Raumnormen lernen';

  @override
  String get leave => 'Verlassen';

  @override
  String get leaveARedirectUriBlankTo =>
      'Lassen Sie eine Redirect-URI leer, um <public URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Team von $arg1 verlassen?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Beim Standard belassen, sofern Sie BlueBubbles nicht angepasst haben.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Lassen Sie das Token leer, um das aktuell gespeicherte Token beizubehalten.';

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
  String get letAccountsConnectMeshtasticRadios =>
      'Konten die Verbindung von Meshtastic-Radios erlauben.';

  @override
  String letArg1ManageMe(Object? arg1) {
    return '$arg1 soll mich verwalten';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Lassen Sie alle in dieser Gruppe mit $arg1 sprechen.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Lassen Sie es arbeiten,\nwährend Sie pausieren.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Lassen Sie NeoAgent klicken, tippen und durch Ihre Apps navigieren.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Lassen Sie NeoAgent verstehen, was auf Ihrem Bildschirm sichtbar ist.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Lassen Sie jemanden, mit dem Sie zusammenarbeiten, entscheiden, welche Tools Ihr Agent ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Lassen Sie diese Person $arg1 eine Eins-zu-eins-Nachricht senden.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Lassen Sie diese Person hier mit $arg1 sprechen, aber nicht in privaten Chats oder anderen Gruppen.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Lassen Sie diese Person in privaten Chats und in jeder gemeinsamen Gruppe mit $arg1 sprechen.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Stufe $arg1/$arg2$arg3';
  }

  @override
  String lexicalArg1(Object? arg1) {
    return 'Lexikalisch: $arg1';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String get linkAPhoneNumberThatBelongs =>
      'Verknüpfen Sie eine Telefonnummer, die dem Agenten gehört. ';

  @override
  String linkArg1(Object? arg1) {
    return '$arg1 verknüpfen';
  }

  @override
  String get linkCopied => 'Link kopiert';

  @override
  String get linkExpiresAfter => 'Link läuft ab nach';

  @override
  String get linkLifetimeHours => 'Linkgültigkeit (Stunden)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Die Linkgültigkeit muss zwischen 1 und 8760 Stunden liegen.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link gültig bis $arg1.';
  }

  @override
  String get linkYourOwnNumberAndTalk =>
      'Verknüpfen Sie Ihre eigene Nummer und sprechen Sie mit dem Agenten in Ihrem ';

  @override
  String get linkedSignInProviders => 'Verknüpfte Anmeldeanbieter';

  @override
  String get linuxApp => 'Linux-App';

  @override
  String listedArg1(Object? arg1) {
    return '$arg1/ aufgelistet';
  }

  @override
  String get listening => 'Hört zu';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Live-Ausführungsverlauf, Tool-Schritte und Antworten.';

  @override
  String get liveModel => 'Live-Modell';

  @override
  String get liveModelProvider => 'Live-Modell-Anbieter';

  @override
  String get liveRun => 'Live-Lauf';

  @override
  String get liveVoice => 'Live-Stimme';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Live-Sprachverbindung ist nicht verfügbar.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Live-Sprachverbindung wurde geschlossen.';

  @override
  String get liveVoiceDefaults => 'Live-Sprachstandards';

  @override
  String get liveVoiceFailed => 'Live-Sprache fehlgeschlagen.';

  @override
  String get llmMemoryExportResponse => 'LLM-Speicher-Exportantwort';

  @override
  String get loadFailed => 'Laden fehlgeschlagen';

  @override
  String get loadingExecutionDetails => 'Ausführungsdetails werden geladen...';

  @override
  String get loadingNeoagent => 'NeoAgent wird geladen';

  @override
  String get loadingRunFlow => 'Ausführungsablauf wird geladen…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Lokale und private Netzwerk-URLs werden unterstützt, wenn der NeoAgent-Server sie erreichen kann. Audio wird NeoAgent nie zugänglich gemacht.';

  @override
  String get localApp => 'lokale App';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Lokale Backend-Installation ist auf dieser Plattform nicht verfügbar.';

  @override
  String get localBaseImagePath => 'Lokaler Basis-Image-Pfad';

  @override
  String get localComputerControlIsAvailableIn =>
      'Lokale Computersteuerung ist in der NeoAgent-Desktop-App unter macOS, Windows und Linux verfügbar.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Lokale Computersteuerung ist hier nicht verfügbar.';

  @override
  String get localDeviceBridgesAndTcpConnected =>
      'Lokale Gerätebrücken und TCP-verbundene Integrationen.';

  @override
  String get localModelsUrl => 'lokale modelle url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Die lokale NeoAgent-Erkennung ist vorübergehend nicht verfügbar.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokale Einstellungen für die NeoAgent-Anwendung. Die Computersteuerung läuft immer über den einheitlichen Cloud-Computer.';

  @override
  String get localSetup => 'LOKALE EINRICHTUNG';

  @override
  String get locationCityOrPlace => 'Ort (Stadt oder Platz)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Ort ist für Wetterereignis-Auslöser erforderlich';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Initialisierung von LocationService fehlgeschlagen: $arg1';
  }

  @override
  String get logCopied => 'Protokoll kopiert';

  @override
  String get loginPassword => 'Anmeldepasswort';

  @override
  String get logout => 'Abmelden';

  @override
  String get logs => 'Protokolle';

  @override
  String get logsCopied => 'Protokolle kopiert.';

  @override
  String get logsOnThisComputer => 'Protokolle auf diesem Computer';

  @override
  String get longLivedAccessToken => 'Long-Lived Access Token';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Langzeitgedächtnis, strukturierte Fakten und Wissensgraph.';

  @override
  String get lookAtMyCalendarForTomorrow =>
      'Schau in meinen Kalender für morgen. Für jeden Termin sag mir, worum ';

  @override
  String get lookedAtTheScreen => 'Bildschirm angesehen';

  @override
  String get lookingOnThisComputerAndYour =>
      'Suche auf diesem Computer und in Ihrem lokalen Netzwerk…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Blickt auf die morgigen Termine, damit Sie nichts überrascht.';

  @override
  String get loopExecution => 'Schleifenausführung';

  @override
  String get loopPaused => 'Schleife pausiert';

  @override
  String get lowerNumbersAreListedFirst =>
      'Niedrigere Zahlen werden zuerst gelistet.';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS-Bedienungshilfen sind NeoAgent nicht gewährt. Erlauben Sie sie unter Systemeinstellungen › Datenschutz & Sicherheit › Bedienungshilfen.';

  @override
  String get macosApp => 'macOS-App';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'macOS-Bildschirmaufnahme ist NeoAgent nicht gewährt. Erlauben Sie sie unter Systemeinstellungen › Datenschutz & Sicherheit › Bildschirmaufnahme und öffnen Sie NeoAgent erneut.';

  @override
  String get mailServersThatNeedAPassword =>
      'Mailserver, die ein Passwort brauchen, verweigern den Versand, bis ein neues ';

  @override
  String get main => 'Hauptagent';

  @override
  String get makeDefault => 'Als Standard festlegen';

  @override
  String get manage => 'Verwalten';

  @override
  String get managePayment => 'Zahlung verwalten';

  @override
  String get manageViaStripeCustomerPortal =>
      'Über das Stripe-Kundenportal verwalten';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Verwalten Sie Ihre Konto-E-Mail, Zwei-Faktor-Authentifizierung und aktiven Sitzungen.';

  @override
  String get manageYourPlanTrackUsageUpdate =>
      'Verwalten Sie Ihren Tarif, verfolgen Sie die Nutzung, aktualisieren Sie die Zahlung und prüfen Sie Rechnungen.';

  @override
  String get manageYourPlanTrackUsageUpdate2 =>
      'Verwalten Sie Ihren Tarif, verfolgen Sie die Nutzung, aktualisieren Sie die Zahlung und prüfen Sie Rechnungen — alles an einem Ort.';

  @override
  String get managedBy => 'Verwaltet von';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Manager können selbst Manager haben (bis zu vier Ebenen). Eine ';

  @override
  String get managing => 'Verwaltung';

  @override
  String get manualDestination => 'Manuelles Ziel';

  @override
  String get manualRouting => 'Manuelle Weiterleitung';

  @override
  String get manualTrigger => 'Manueller Auslöser';

  @override
  String get masterPassword => 'Master-Passwort';

  @override
  String get matchThisDevice => 'An dieses Gerät anpassen';

  @override
  String get matchedAgainstTitleAndBody => 'Abgleich mit Titel und Inhalt';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Entspricht dem früheren NeoAgent-MCP-Ablauf: URL plus Authentifizierungsmethode.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP-Server';

  @override
  String get mcpServer2 => 'MCP-Server';

  @override
  String get mcpServerUrl => 'MCP-Server-URL';

  @override
  String get mcpServers => 'MCP-Server';

  @override
  String get meantForSomeoneElse => 'Für jemand anderen bestimmt';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Gemessene Modellkosten: $arg1';
  }

  @override
  String get memories => 'Erinnerungen';

  @override
  String get memory => 'Gedächtnis';

  @override
  String memoryArg1(Object? arg1) {
    return 'Gedächtnis: $arg1';
  }

  @override
  String get memoryImportSync => 'gedächtnis import sync';

  @override
  String get memoryIngestionInterval => 'Gedächtnis-Importintervall';

  @override
  String get memoryIngestionIntervalMs => 'Speicher-Ingestionsintervall (ms)';

  @override
  String get memoryIngestionIntervalMustBeAt =>
      'Das Speicher-Ingestionsintervall muss mindestens 1000 ms betragen.';

  @override
  String get memoryInjected => 'Gedächtnis eingefügt';

  @override
  String get memoryMb => 'Speicher (MB)';

  @override
  String get memoryMustBeAtLeast512 =>
      'Der Speicher muss mindestens 512 MB betragen.';

  @override
  String get mentionOrReplyOnly => 'Nur Erwähnung oder Antwort';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Zusammengeführte Server- und Flutter-Laufzeitlogs für diese App-Sitzung.';

  @override
  String get meshRadioMessaging => 'mesh funk messaging';

  @override
  String get messageBodyTemplateJson => 'Nachrichtenkörper-Vorlage (JSON)';

  @override
  String get messageNeedsAccess => 'Nachricht benötigt Zugriff';

  @override
  String get messageTextField => 'Nachrichtentextfeld';

  @override
  String get messageYouWithTheResultAdd =>
      'melden Ihnen dann das Ergebnis. Fügen Sie eine hinzu, um zu starten, oder überspringen Sie und ';

  @override
  String get messageYourselfChatEveryOtherChat =>
      '„Nachricht an mich selbst“-Chat. Alle anderen Chats und Gruppen auf ';

  @override
  String get messaging => 'Nachrichten';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging-API-Push und Webhook-Ereignisse';

  @override
  String get messagingConnectionNeedsAttention =>
      'Messaging-Verbindung braucht Aufmerksamkeit';

  @override
  String get messagingConnections => 'Messaging-Verbindungen';

  @override
  String get messagingDelivery => 'Messaging-Zustellung';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Messaging-Fehler. Bitte versuchen Sie es erneut.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Die Mikrofonaufnahme wurde unerwartet beendet. Versuchen Sie es erneut.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofonfehler: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon stummgeschaltet. Tippen zum Einschalten.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Für Live-Sprache ist die Mikrofonberechtigung erforderlich.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack und andere Integrationen verbinden können. Sie gelten für ';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Mindestbeitragswert: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobile Einrichtung fehlgeschlagen.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobile Einrichtung fehlgeschlagen, weil Java auf dem Rechner mit NeoAgent nicht verfügbar ist.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobile Einrichtung fehlgeschlagen, weil Java auf dem Rechner mit NeoAgent nicht verfügbar ist. Installieren Sie ein JDK und versuchen Sie es erneut.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobile Einrichtung fehlgeschlagen. Prüfen Sie, ob die Android-Tools korrekt installiert sind, und versuchen Sie es erneut.';

  @override
  String modeArg1(Object? arg1) {
    return 'Modus: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Der Modus ist gesperrt, solange ein Lauf aktiv ist.';

  @override
  String get model => 'Modell';

  @override
  String modelArg1(Object? arg1) {
    return 'Modell: $arg1';
  }

  @override
  String get modelAvailability => 'Modellverfügbarkeit';

  @override
  String get modelAvailabilitySaved => 'Modellverfügbarkeit gespeichert.';

  @override
  String get modelForThisSession => 'Modell für diese Sitzung';

  @override
  String get modelIds => 'Modell-IDs';

  @override
  String get modelOverride => 'Modellüberschreibung';

  @override
  String get modelPending => 'Modell ausstehend';

  @override
  String get modelTurn => 'Modellschritt';

  @override
  String get modelTurnCompleted => 'Modellzug abgeschlossen';

  @override
  String get modelTurnStarted => 'Modellzug begonnen';

  @override
  String get modelVisibilityHideShowList =>
      'modell sichtbarkeit ausblenden anzeigen liste';

  @override
  String get models => 'Modelle';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modelle, Verhalten, Sprache und Arbeitsbereich';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modelle, Browser, Stimme, Diagnose...';

  @override
  String get modelsRouting => 'Modelle & Routing';

  @override
  String get monthly => 'Monatlich';

  @override
  String get moreActions => 'Weitere Aktionen';

  @override
  String get morningBriefing => 'Morgenbriefing';

  @override
  String get mostUsedAgents => 'Meistgenutzte Agenten';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Meistgenutzte Modelle in den letzten $arg1.';
  }

  @override
  String get mouseKeyboard => 'Maus & Tastatur';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove wird auf dieser Plattform nicht unterstützt.';

  @override
  String get mustBeReachableOnThePublic =>
      'Muss über das öffentliche Internet erreichbar sein -- lokale und ';

  @override
  String get n0TurnsTrialsOff => '0 schaltet Testphasen aus.';

  @override
  String get n24Hours => '24 Stunden';

  @override
  String get n2faOrRecoveryCode => '2FA- oder Wiederherstellungscode';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA erfordert, dass SESSION_SECRET auf diesem NeoAgent-Deployment konfiguriert ist.';

  @override
  String get n30Days => '30 Tage';

  @override
  String get n365Days => '365 Tage';

  @override
  String get n42Passing => '✓ 42 bestanden';

  @override
  String get n4HourLimitTokens => '4-Stunden-Limit (Tokens)';

  @override
  String get n4HourTokenLimit => '4-Stunden-Token-Limit';

  @override
  String get n4HourUsage => '4-Stunden-Nutzung';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4-Std.-Limit $arg1';
  }

  @override
  String get n4hTokenWindow => '4-h-Token-Fenster';

  @override
  String get n7DayUsage => '7-Tage-Nutzung';

  @override
  String get n7Days => '7 Tage';

  @override
  String get n90Days => '90 Tage';

  @override
  String get name => 'Name';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nname: Neuer Skill\ndescription: Beschreiben Sie, was dieser Skill tut\n---\nSchreiben Sie hier die Anweisungen für diesen Skill.\n';

  @override
  String get nameOfWhoeverMadeIt => 'Namen der Person, die sie getroffen hat.';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get nativeAndWebhookChannels => 'Native und Webhook-Kanäle';

  @override
  String get naturalBubbles => 'Natürliche Blasen';

  @override
  String get nearbyNeoagentServers => 'NeoAgent-Server in der Nähe';

  @override
  String get needANewAccountRegister => 'Neues Konto nötig? Registrieren';

  @override
  String get needAnIdea => 'Brauchen Sie eine Idee?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Antwort nötig · $arg1% zum Sprechen';
  }

  @override
  String get needsAttention => 'Aufmerksamkeit erforderlich';

  @override
  String get needsInput => 'Eingabe erforderlich';

  @override
  String get neoagentApp => 'NeoAgent-App';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent-Assistent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent konnte die verfügbare Backend-Laufzeit nicht prüfen.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent konnte die lokale Einrichtung nicht abschließen.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent konnte die lokale Einrichtung nicht abschließen. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent-Debug-Info';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent-Desktop-Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String get neoagentHasItsOwnComputer =>
      'NeoAgent hat einen\neigenen Computer.';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installiert die neueste $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent ist installiert und läuft.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent ist auf diesem Computer nicht installiert.';

  @override
  String get neoagentIsReady => 'NeoAgent ist bereit';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent arbeitet noch an einer Aufgabe. Beenden Sie den Anruf und erhalten Sie das Ergebnis im Chat, oder brechen Sie die Aufgabe ebenfalls ab.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent verwandelt Ihre Demonstration in einen anpassbaren Workflow.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent wartet, während Sie den Desktop nutzen.';

  @override
  String get neoagentIsWorking => 'NeoAgent arbeitet';

  @override
  String get neoagentLinuxComputer => 'NeoAgent-Linux-Computer';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT BRAUCHT EINE ENTSCHEIDUNG';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Downloads der NeoAgent-Laufzeit erfordern eine sichere Adresse.';

  @override
  String get neoagentServerAddress => 'NeoAgent-Serveradresse';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'Die NeoAgent-Service-E-Mail ist nicht bereit. Bitten Sie den Serverbetreiber, die E-Mail-Umgebungseinstellungen zu prüfen.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Die NeoAgent-Einrichtung konnte nicht abgeschlossen werden.';

  @override
  String get neoagentUser => 'NeoAgent-Benutzer';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent nutzt diesen Computer automatisch und fragt nach, bevor Bildschirm, Maus, Tastatur, Dateien oder die Befehlszeile verwendet werden.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent nutzt Ihren ungefähren Hintergrundstandort, um Geofence-Erinnerungen auszulösen (z. B. „Erinnere mich, Milch zu kaufen, wenn ich am Supermarkt vorbeigehe“).\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent-Arbeitsbereich';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][stack] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall-Backend-URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'NeoRecall-Backend-URL ist erforderlich.';

  @override
  String get neorecallSetup => 'NeoRecall-Einrichtung';

  @override
  String get networkRequestFailed => 'Netzwerkanfrage fehlgeschlagen';

  @override
  String get networkWriteRequests => 'Schreibende Netzwerkanfragen';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'wird nicht auf die gemeinsamen Nutzungslimits angerechnet.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Neue Konten bestätigen ihre E-Mail-Adresse vor der Anmeldung.';

  @override
  String get newAccountsPerDay => 'Neue Konten pro Tag';

  @override
  String get newChat => 'Neuer Chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Neue Gruppen bleiben stumm, bis jemand $arg1 markiert oder Sie sie aktivieren.';
  }

  @override
  String get newLink => 'Neuer Link';

  @override
  String get newPasswordsDoNotMatch =>
      'Die neuen Passwörter stimmen nicht überein.';

  @override
  String get newPlan => 'Neuer Tarif';

  @override
  String get newRecoveryCodes => 'Neue Wiederherstellungscodes';

  @override
  String get newSession => 'Neue Sitzung';

  @override
  String get newSessionN => 'Neue Sitzung (⌘N)';

  @override
  String get newSessionWithSameSetup =>
      'Neue Sitzung mit derselben Einrichtung';

  @override
  String get newSkill => 'Neuer Skill';

  @override
  String get newSkill2 => 'Neuer Skill';

  @override
  String get newThisWeek => 'Neu diese Woche';

  @override
  String get newsDigest => 'Nachrichtenüberblick';

  @override
  String get nextEvent => 'Nächstes Ereignis';

  @override
  String get nextPage => 'Nächste Seite';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Nächster Versuch: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud-Anmeldeablauf';

  @override
  String get nextcloudSetup => 'Nextcloud-Einrichtung';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'Nextcloud-URL';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloud-URL ist erforderlich.';

  @override
  String get nickname => 'Spitzname';

  @override
  String get noAccountsConnectedYet => 'Noch keine Konten verbunden.';

  @override
  String get noAccountsFound => 'Keine Konten gefunden.';

  @override
  String get noActivePlansYetCreateOne =>
      'Noch keine aktiven Pläne. Erstellen Sie einen im Reiter Abrechnung.';

  @override
  String get noActiveSessionsFound => 'Keine aktiven Sitzungen gefunden.';

  @override
  String get noActiveSubscription => 'Kein aktives Abonnement';

  @override
  String get noAgentsYet => 'Noch keine Agenten';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Kein KI-Anbieter ist konfiguriert, daher können Chat und Messaging ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Keine Freigabeaufforderungen — der Agent läuft ohne Unterbrechung.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Kein $arg1-Release-Asset passte zu dieser Plattform.';
  }

  @override
  String noArg1Subscriptions(Object? arg1) {
    return 'Keine $arg1-Abonnements.';
  }

  @override
  String get noArguments => '(keine Argumente)';

  @override
  String get noAuth => 'Keine Authentifizierung';

  @override
  String get noAvailableModelsYetCheckBack =>
      'Noch keine Modelle verfügbar.\nSchauen Sie erneut nach, sobald ein Anbieter konfiguriert ist.';

  @override
  String get noBindingsYet => 'Noch keine Bindungen.';

  @override
  String get noChangesYet => 'Noch keine Änderungen';

  @override
  String get noChannelsFound => 'Keine Kanäle gefunden';

  @override
  String get noCloudComputerSlotIsFree =>
      'Derzeit ist kein Cloud-Computer-Slot frei. Versuchen Sie es in einem Moment erneut.';

  @override
  String get noCoreMemoryEntriesYet => 'Noch keine Kernspeicher-Einträge.';

  @override
  String get noDescription => 'Keine Beschreibung';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Derzeit sind keine Desktop-Anzeigen verfügbar.';

  @override
  String get noDetailAvailable => 'Keine Details verfügbar';

  @override
  String get noDetailedSyncSummaryYet =>
      'Noch keine detaillierte Synchronisationszusammenfassung.';

  @override
  String get noDetailsCaptured => 'Keine Details erfasst.';

  @override
  String get noEmailLinked => 'Keine E-Mail verknüpft';

  @override
  String get noExternalSignInProvidersLinked =>
      'Keine externen Anmeldeanbieter verknüpft.';

  @override
  String get noGroupMessagesYet => 'Noch keine Gruppennachrichten';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Noch keine gruppenspezifischen Personen hinzugefügt.';

  @override
  String get noGroupsAddedYet => 'Noch keine Gruppen hinzugefügt.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Noch keine Gruppen gefunden. Sobald $arg1 eine Gruppennachricht sieht, nutzen Sie Letzte Chats finden – dann erscheinen sie hier.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Noch keine Gruppen gefunden. Sobald $arg1 eine Gruppennachricht sieht, nutzen Sie Letzte Chats finden.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Keine Gesundheitsdaten zurückgegeben.';

  @override
  String get noHealthSamplesStoredYet =>
      'Noch keine Gesundheitsproben gespeichert.';

  @override
  String get noHttpClientImplementationForThis =>
      'Keine HTTP-Client-Implementierung für diese Plattform.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Für diesen Schritt wurden keine Ein- oder Ausgaben aufgezeichnet.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Keine Integrationen passen zu dieser Suche.';

  @override
  String get noInvoicesYet => 'Noch keine Rechnungen.';

  @override
  String get noLimit => 'Kein Limit';

  @override
  String get noLocalPasswordIsSetYet =>
      'Noch kein lokales Passwort festgelegt. Erstellen Sie eines, um die Anmeldung mit Benutzername/Passwort zu aktivieren.';

  @override
  String get noLogEntries => 'Keine Protokolleinträge.';

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String get noMatchingSettings => 'Keine passenden Einstellungen';

  @override
  String get noMcpServersMatchThisSearch =>
      'Keine MCP-Server passen zu dieser Suche.';

  @override
  String get noMemoryEntriesFound => 'Keine Speichereinträge gefunden.';

  @override
  String get noMemorySync => 'Keine Gedächtnis-Synchronisation';

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Kein Modell entspricht \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Für diese Ausführung wurde keine Modellanfrage aufgezeichnet.';

  @override
  String get noModelsAreAvailableYet => 'Noch keine Modelle verfügbar.';

  @override
  String get noModelsDiscoveredYet => 'Noch keine Modelle gefunden';

  @override
  String get noModelsSelected => 'Keine Modelle ausgewählt';

  @override
  String get noModelsYet => 'Noch keine Modelle';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'mit diesem Anbieter ist kein NeoAgent-Konto verknüpft';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Für diesen Computer ist keine NeoAgent-Backend-Laufzeit verfügbar.';

  @override
  String get noNetworkConnection => 'Keine Netzwerkverbindung';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Keine Netzwerkverbindung. Stellen Sie eine Verbindung her, um NeoAgent weiter zu nutzen.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Keine Netzwerkverbindung. Stellen Sie die Verbindung wieder her, um nach Updates zu suchen.';

  @override
  String get noOne => 'Niemand';

  @override
  String get noOneAddedYet => 'Noch niemand hinzugefügt.';

  @override
  String get noOneCanMessage => 'Niemand kann schreiben';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Kein anderer NeoAgent-Server gefunden. Sie können erneut suchen oder eine Adresse manuell eingeben.';

  @override
  String get noPeopleAddedYet => 'Noch keine Personen hinzugefügt.';

  @override
  String get noPlansConfiguredYet => 'Noch keine Tarife konfiguriert.';

  @override
  String get noPlansYet => 'Noch keine Tarife.';

  @override
  String get noPlatformsMatch => 'Keine passenden Plattformen';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Es sind noch keine Anbieter zum Konfigurieren verfügbar.';

  @override
  String get noRecentChannelActivity => 'Keine aktuelle Kanalaktivität';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Keine Ergebnisse für \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Keine Läufe in diesem Zeitraum.';

  @override
  String get noRunsMatchTheseFilters =>
      'Keine Ausführungen entsprechen diesen Filtern';

  @override
  String get noRunsYet => 'Noch keine Ausführungen';

  @override
  String get noRunsYet2 => 'Noch keine Läufe.';

  @override
  String get noSecurityKeyWasProvided =>
      'Es wurde kein Sicherheitsschlüssel angegeben.';

  @override
  String get noServerUrlSet => 'Keine Server-URL festgelegt';

  @override
  String get noSessionMatchesThatSearch =>
      'Keine Sitzung entspricht dieser Suche.';

  @override
  String get noSessionsYet => 'Noch keine Sitzungen';

  @override
  String get noSkillsMatchTheseFilters =>
      'Keine Skills passen zu diesen Filtern.';

  @override
  String get noStepsWereRecordedForThis =>
      'Für diese Ausführung wurden keine Schritte aufgezeichnet.';

  @override
  String get noStoreSkillsMatchThisSearch =>
      'Keine Store-Skills passen zu dieser Suche.';

  @override
  String get noSubscription => 'Kein Abonnement.';

  @override
  String get noSummary => 'Keine Zusammenfassung';

  @override
  String get noSummaryAvailable => 'Keine Zusammenfassung verfügbar.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Keine Aufgaben für $arg1';
  }

  @override
  String get noTimelineActivityYetForThe =>
      'Noch keine Zeitachsenaktivität für die gewählten Filter.';

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Kein Tool passt zu \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Kein Update läuft';

  @override
  String get noUsageYet => 'Noch keine Nutzung.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Es ist noch keine verifizierte NeoAgent-Backend-Laufzeit verfügbar.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Niemand kann ihn mehr nutzen. Personen, die bereits beigetreten sind, ';

  @override
  String get none => 'Keine';

  @override
  String get notApprovedYet => 'noch nicht freigegeben';

  @override
  String get notAuthenticated => 'nicht authentifiziert';

  @override
  String get notCheckedYet => 'Noch nicht geprüft';

  @override
  String get notConfigured => 'Nicht konfiguriert';

  @override
  String get notConnected => 'Nicht verbunden';

  @override
  String get notConnected2 => 'Nicht verbunden';

  @override
  String get notInstalled => 'Nicht installiert';

  @override
  String get notNeeded => 'Nicht erforderlich';

  @override
  String get notNeededEnough => 'Nicht nötig genug';

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String get notNow2 => 'Nicht jetzt';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String get notSetUp => 'Nicht eingerichtet';

  @override
  String get notTheSameAsAdmin => 'Nicht dasselbe wie Admin';

  @override
  String get nothingFound => 'Nichts gefunden';

  @override
  String get nothingHereYet => 'Hier ist noch nichts.';

  @override
  String get nothingHereYet2 => 'Hier ist noch nichts';

  @override
  String get nothingMatches => 'Keine Treffer';

  @override
  String get nothingStoredYet => 'Noch nichts gespeichert.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'OAuth-App-Zugangsdaten, mit denen Konten Google, ';

  @override
  String get oauthClientId => 'OAuth-Client-ID';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth client id secret redirect api key';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth client id secret redirect gmail calendar drive';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth-Start wird auf dieser Plattform nicht unterstützt.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook tenant client id secret';

  @override
  String get oauthToken => 'OAuth-Token';

  @override
  String get oauthWithPkce => 'OAuth mit PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'von $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'hat. Nach dem Speichern wird er nicht mehr angezeigt.';

  @override
  String get ofUpToFiveItemsWith =>
      'mit bis zu fünf Punkten, je einem Satz und einem Link.';

  @override
  String get off => 'Aus';

  @override
  String get offTakesEffectAfterAServer =>
      'wird nach einem Serverneustart wirksam.';

  @override
  String get offerSubscriptionPlansThroughStripeTurning =>
      'Abonnementtarife über Stripe anbieten. Ein- oder Ausschalten ';

  @override
  String get offeredToPeopleChoosingAPlan =>
      'Wird Personen angeboten, die einen Tarif wählen.';

  @override
  String get officialIntegration => 'Offizielle Integration';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Die offizielle Integration hat keine Verbindungs-URL zurückgegeben.';

  @override
  String get on => 'An';

  @override
  String get onASignedInAndroidDevice =>
      'Öffnen Sie auf einem angemeldeten Android-Gerät Einstellungen › Anmeldung & Sicherheit, scannen Sie diesen Code und bestätigen Sie die Anmeldung.';

  @override
  String get onAndTheServerHasRestarted =>
      'ist und der Server neu gestartet wurde.';

  @override
  String get onByDefaultForNewGroups => 'Standardmäßig an für neue Gruppen';

  @override
  String get onDemand => 'Bei Bedarf';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Aktiv für $arg1 von $arg2 Gruppen';
  }

  @override
  String get onMyCalendarAndTheMost =>
      'in meinem Kalender und die wichtigsten offenen Punkte, die ich kenne. ';

  @override
  String get onTheyCanJoinAgainOnly =>
      'eingeschaltet. Erneut beitreten geht nur mit einem neuen Einladungslink.';

  @override
  String get onYourOwnTheDefault => 'Auf sich gestellt (Standard)';

  @override
  String get once => 'Einmal';

  @override
  String get oneBlankToKeepWhatIs =>
      'ein Feld leer, um den gespeicherten Wert zu behalten.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'gespeichert ist. Andere Änderungen in diesem Formular werden ebenfalls gespeichert.';

  @override
  String get oneLineSummaryEachIfNothing =>
      'einzeiligen Zusammenfassung je Nachricht. Wenn nichts meine Aufmerksamkeit braucht, sende ';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Ein oder mehrere Konten sind abgelaufen. Verbinden Sie das betroffene Konto erneut, um den Werkzeugzugriff wiederherzustellen.';

  @override
  String get onePerLineShownOnThe =>
      'Eine pro Zeile, wird auf der Preisseite angezeigt.';

  @override
  String get oneRegister => 'Registrierung immer zu.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Eine Runtime steuert Persona, Gruppen-Rederecht, Raumgedächtnis, Normen, Theory of Mind und Zustellung.';

  @override
  String get oneTimeFree => 'Einmalig / kostenlos';

  @override
  String get oneTimeRun => 'Einmaliger Lauf';

  @override
  String get onlyApkOrApksFilesCan =>
      'Nur .apk- oder .apks-Dateien können installiert werden.';

  @override
  String get onlyInThisGroup => 'Nur in dieser Gruppe';

  @override
  String get onlyMessageMeAboutEmailsThat =>
      'Schreibe mir nur zu E-Mails, die dringend sind oder eine Antwort brauchen, mit einer ';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Nur nötig, wenn der Dienst zusätzliche HTTP-Header verlangt.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Nur nötig, wenn Sie die ausgehende Nutzlast umformen möchten.';

  @override
  String get onlyTheyCanChangeIt => 'Nur diese Person kann das ändern.';

  @override
  String get open => 'Öffnen';

  @override
  String get openAccountSettingsOnASigned =>
      'Öffnen Sie Einstellungen › Anmeldung & Sicherheit auf einem angemeldeten Android-Gerät, scannen Sie diesen Code und bestätigen Sie die Anmeldung.';

  @override
  String get openBrowserCheckingDocs => 'Browser öffnen → Docs prüfen';

  @override
  String get openComputer => 'Computer öffnen';

  @override
  String get openDashboard => 'Dashboard öffnen';

  @override
  String get openFolder => 'Ordner öffnen…';

  @override
  String get openInWorkbench => 'In der Workbench öffnen';

  @override
  String get openLinkedRun => 'Verknüpften Lauf öffnen';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Öffnen Sie NeoAgent und verbinden Sie $arg1 erneut, um Messaging wiederherzustellen.';
  }

  @override
  String get openRun => 'Lauf öffnen';

  @override
  String get openTheComputerTabNextTo =>
      'Öffnen Sie den Computer-Tab neben einer Sitzung, um den Bildschirm ';

  @override
  String get openTimeSettings => 'Zeiteinstellungen öffnen';

  @override
  String get openToAnyone => 'Für alle offen';

  @override
  String get openTrello => 'Trello öffnen';

  @override
  String get openVoiceAssistant => 'Sprachassistent öffnen';

  @override
  String get openWiFiSettings => 'Wi-Fi-Einstellungen öffnen';

  @override
  String get openWithTheDefaultApp => 'Mit Standard-App öffnen';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'OpenAI-kompatibel';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-kompatiblen Endpunkt (Ihren eigenen Server oder einen anderen ';

  @override
  String openedArg1(Object? arg1) {
    return '$arg1 geöffnet';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Das Öffnen von Desktop-URLs wird auf dieser Plattform nicht unterstützt.';

  @override
  String get openingYourSavedDesktop =>
      'Ihr gespeicherter Desktop wird geöffnet.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Ihr gespeicherter Desktop wird geöffnet. Normale Starts dauern weniger als 10 Sekunden.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Optionales zusätzliches Geheimnis, wenn Sie den eingehenden Webhook absichern.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Optionale Überschreibung, falls die Webhook-URL nicht ausreicht.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Optionales Geheimnis zur Überprüfung eingehender Chat-Ereignisse.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Optionales Geheimnis zur Überprüfung eingehender Ereignisse.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Optionales Geheimnis zur Überprüfung eingehender iMessage-Ereignisse.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Optionales Geheimnis zur Überprüfung eingehender LINE-Ereignisse.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Optionales Geheimnis zur Überprüfung eingehender Mattermost-Ereignisse.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Optionales Geheimnis zur Überprüfung eingehender Teams-Ereignisse.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Optional. Der Agent hat bereits eine eigene Persönlichkeit. Alles, was Sie zum Tonfall hinzufügen, wird darauf aufgesetzt – Sie müssen also keine eigene definieren.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Optional. Wenn gesetzt, wird er statt der URL verwendet.';

  @override
  String get orAnswerInYourOwnWords => 'Oder antworten Sie in eigenen Worten';

  @override
  String get orBuildYourOwnTask => 'Oder eigene Aufgabe erstellen';

  @override
  String get orContinueWith => 'oder fortfahren mit';

  @override
  String get orFiles => 'oder Dateien.';

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
  String get originNotAllowed => 'Ursprung nicht erlaubt';

  @override
  String get outgoingMessage => 'Ausgehende Nachricht';

  @override
  String get outgoingWebhookUrl => 'Ausgehende Webhook-URL';

  @override
  String get outlookEmailReceived => 'Outlook-E-Mail empfangen';

  @override
  String get overrideAssignsAPlanWithoutGoing =>
      'Überschreiben weist einen Tarif zu, ohne über Stripe zu gehen.';

  @override
  String get overridePlan => 'Tarif überschreiben';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Verhaltensnotizen aus dem Import überschreiben.';

  @override
  String get ownModel => 'eigenes Modell';

  @override
  String get packageName => 'Paketname';

  @override
  String get pairWithQrCode => 'Per QR-Code koppeln';

  @override
  String get password => 'Passwort';

  @override
  String get password2faAndActiveSessions =>
      'Passwort, 2FA und aktive Sitzungen';

  @override
  String get passwordCreated => 'Passwort erstellt.';

  @override
  String get passwordIsTooWeak => 'Passwort ist zu schwach';

  @override
  String get passwordMin8 => 'Passwort mindestens 8';

  @override
  String get passwordOrApiKey => 'Passwort oder API-Schlüssel';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Passwortstärke: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Die Passwörter stimmen nicht überein.';

  @override
  String get pastDue => 'Überfällig';

  @override
  String get pasteAKey => 'Schlüssel einfügen.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Neuen Schlüssel einfügen, um $arg1 zu ersetzen';
  }

  @override
  String get pasteTheKey => 'Schlüssel einfügen';

  @override
  String get pasteYourAccountToken => 'Kontotoken einfügen';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Fügen Sie Ihren $arg1-API-Schlüssel unten ein. Er wird ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Der Pfad muss innerhalb von NeoAgent Workspace bleiben.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Der Pfad muss innerhalb des Workspace-Ordners bleiben.';

  @override
  String get pauseLiveUpdates => 'Live-Updates pausieren';

  @override
  String get pauseTaskLoop => 'Aufgabenschleife pausieren';

  @override
  String get paused => 'Pausiert';

  @override
  String get paymentMethod => 'Zahlungsmethode';

  @override
  String peakArg1(Object? arg1) {
    return 'Spitze $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Personen in privaten Chats';

  @override
  String get perAccountRateLimits => 'Ratenlimits pro Konto';

  @override
  String get perCategoryPermissions => 'Berechtigungen nach Kategorie';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Berechtigungsrichtlinien pro Tool, Freigabeschritte und Prozessisolation für die Shell-Ausführung.';

  @override
  String periodEndsArg1(Object? arg1) {
    return 'Periode endet $arg1';
  }

  @override
  String get permanentlyAllowedNeverAsksAgain =>
      'Dauerhaft erlaubt — fragt nie wieder nach.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Berechtigung erforderlich: $arg1';
  }

  @override
  String get permissionsNeeded => 'Berechtigungen erforderlich';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Berechtigungen. Niemand sonst kann das ändern.';

  @override
  String get personOrChat => 'Person oder Chat';

  @override
  String get personaBehaviorNotes => 'Persona-Verhaltensnotizen';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Persönliches Zugriffstoken für den Mattermost-Bot.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Persönliche Kanäle und direkte Support-Oberflächen.';

  @override
  String get personalSelfChat => 'Persönlicher Selbst-Chat';

  @override
  String get phoneNumber => 'Telefonnummer';

  @override
  String get pickARunFromTheList =>
      'Wählen Sie eine Ausführung aus der Liste, um die Schritte zu sehen.';

  @override
  String get pickARunFromTheList2 =>
      'Wählen Sie links eine Ausführung, um den Ablauf zu erkunden.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Wählen Sie aus letzten $arg1-Chats oder fügen Sie selbst eine Person oder Gruppe hinzu.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Wählen Sie, wie $arg1 dieses Konto nutzt.';
  }

  @override
  String get pickOneToFillInThe =>
      'Wählen Sie eine Vorlage für die Aufgabe. Sie können danach alles anpassen.';

  @override
  String get pickTheModelNeoagentShouldUse =>
      'Wählen Sie das Modell, das NeoAgent standardmäßig nutzen soll. Anbieter werden auf dem Server konfiguriert.';

  @override
  String get picksUpWhereYouLeftOff =>
      'Macht dort weiter, wo Sie aufgehört haben';

  @override
  String get plan => 'Tarif';

  @override
  String planForArg1APlanAssigned(Object? arg1) {
    return 'Plan für @$arg1. Ein hier zugewiesener Plan ';
  }

  @override
  String get planId => 'Tarif-ID';

  @override
  String get planIdMayOnlyUseLetters =>
      'Die Tarif-ID darf nur Buchstaben, Zahlen, Unterstriche und Bindestriche enthalten.';

  @override
  String get planUsageAndAllowanceDetails =>
      'Plannutzung und Kontingentdetails';

  @override
  String get planning => 'Planung';

  @override
  String get plans => 'Tarife';

  @override
  String get plansAndSubscriptionsShowUpHere =>
      'Tarife und Abonnements erscheinen hier, sobald die Abrechnung aktiviert ';

  @override
  String get platform => 'Plattform';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Plattform $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Bitte wählen Sie einen Zeitplan.';

  @override
  String get pleaseEnterAFilename => 'Bitte geben Sie einen Dateinamen ein.';

  @override
  String get pleaseEnterAKey => 'Bitte geben Sie einen Schlüssel ein.';

  @override
  String get pleaseEnterAPrompt => 'Bitte geben Sie einen Prompt ein.';

  @override
  String get pleaseEnterATaskName => 'Bitte geben Sie einen Aufgabennamen ein.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Bitte geben Sie den Speicherinhalt ein.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Bitte geben Sie an, wann die Aufgabe laufen soll.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Bitte wählen Sie ein Konto oder geben Sie eine gültige Verbindungs-ID ein.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Richten Sie NeoAgent auf eine beliebige OpenAI-kompatible Chat Completions ';

  @override
  String get pointTheCameraAtTheCode =>
      'Richten Sie die Kamera auf den Code auf dem abgemeldeten Gerät. Die Genehmigung bleibt auf diesem Telefon.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env public url trust proxy secure cookies deployment';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Premium-Automatisierung mit Zeitplan- und Integrationsauslösern.';

  @override
  String get prepareMyMorningBriefingTodayS =>
      'Bereite mein Morgenbriefing vor: das heutige Wetter an meinem Standort, die Termine ';

  @override
  String get prepareQrCode => 'QR-Code vorbereiten';

  @override
  String get preparingNeoagent => 'NeoAgent wird vorbereitet…';

  @override
  String get preparingNeoagent2 => 'NeoAgent wird vorbereitet';

  @override
  String get pressAndHoldForQuickCapture =>
      'Gedrückt halten für Schnellaufnahme';

  @override
  String get pressKeysIsNotSupportedOn =>
      'press keys wird auf dieser Plattform nicht unterstützt.';

  @override
  String pressedArg1(Object? arg1) {
    return '$arg1 gedrückt';
  }

  @override
  String get previousEvent => 'Vorheriges Ereignis';

  @override
  String get previousPage => 'Vorherige Seite';

  @override
  String get priceInCents => 'Preis in Cent';

  @override
  String get priceMustBeAWholeNumber =>
      'Der Preis muss eine ganze Zahl in Cent sein (0 oder mehr).';

  @override
  String get priceUnknown => 'Preis unbekannt';

  @override
  String get pricingPriceSubscriptionTiersCreateEdit =>
      'preise preis abo stufen erstellen bearbeiten';

  @override
  String get primaryDisplay => 'Hauptanzeige';

  @override
  String get privateAndIsolated => 'Privat und isoliert';

  @override
  String get privateChat => 'Privater Chat';

  @override
  String get privateChats => 'Private Chats';

  @override
  String get privateChats2 => 'private Chats';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Private Chats: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Private Chats $arg1 · Gruppen $arg2';
  }

  @override
  String get privateChatsOnly => 'Nur private Chats';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'private Netzwerkadressen sind nicht erlaubt.';

  @override
  String get profileEmailAndPersonalData =>
      'Profil, E-Mail und personenbezogene Daten';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Nachfragen, bevor NeoAgent im Systembereich aktiv bleibt.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Prompt-Cache: $arg1 gecachte Tokens ';
  }

  @override
  String get promptCopied => 'Prompt kopiert.';

  @override
  String get promptOrSchedule => 'Prompt oder Zeitplan.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Prompt zum Einfügen in eine andere KI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Anbieterverknüpfung konnte nicht gestartet werden.';

  @override
  String get providerSignInCouldNotBe =>
      'Anbieter-Anmeldung konnte nicht gestartet werden.';

  @override
  String get providers => 'Anbieter';

  @override
  String get providersEachAccountCanStillPick =>
      'Anbieter; jedes Konto kann weiterhin in den Einstellungen ein eigenes Modell wählen. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Anbieter, Integrationen, Sprache und optionale Funktionen können jederzeit in den Einstellungen eingerichtet werden.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Öffentliche Issue- und Pull-Request-Threads, nur für freigegebene Personen beantwortet.';

  @override
  String get publicUrl => 'Öffentliche URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Öffentliche URL und erlaubte Origins';

  @override
  String get publicUrlApiBillingWebhookAnd =>
      '<public URL>/api/billing/webhook und fügen Sie das Signiergeheimnis ';

  @override
  String get publicUrlOverride => 'Öffentliche URL überschreiben';

  @override
  String get publishableKey => 'Veröffentlichbarer Schlüssel';

  @override
  String get pullsTogetherTheDayAhead => 'Fasst den kommenden Tag zusammen';

  @override
  String get pushToTalk => 'Push-to-Talk';

  @override
  String get qrBasedPhoneLinking => 'QR-basierte Telefonverknüpfung';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR-Anmeldung abgeschlossen, aber NeoAgent konnte die Sitzung nicht behalten. Bitte versuchen Sie es erneut.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'QR-Anmeldung konnte nicht gestartet werden.';

  @override
  String get qrLoginRequestHasExpired => 'QR-Anmeldeanfrage ist abgelaufen';

  @override
  String get qrLoginRequestWasNotFound =>
      'QR-Anmeldeanfrage wurde nicht gefunden';

  @override
  String get qrPairing => 'QR-Pairing';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'Abfragen ausgeführt; Schreibvorgänge werden abgelehnt.';

  @override
  String get query => 'Abfrage';

  @override
  String get queryFilter => 'Abfrage / Filter';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Als Steuerung für die aktuelle Ausführung eingereiht: $arg1';
  }

  @override
  String get quickstart => 'Schnellstart';

  @override
  String get quit => 'Beenden';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Skript auf der Seite ausgeführt';

  @override
  String ranArg1(Object? arg1) {
    return '$arg1 ausgeführt';
  }

  @override
  String get rateLimits => 'Ratenlimits';

  @override
  String get readAnArtifact => 'Artefakt gelesen';

  @override
  String get readAndEditFilesInsideYour =>
      'Dateien in Ihrem NeoAgent-Workspace-Ordner lesen und bearbeiten.';

  @override
  String readArg1(Object? arg1) {
    return '$arg1 gelesen';
  }

  @override
  String get readError => 'Lesefehler';

  @override
  String get readFiles => 'Dateien gelesen';

  @override
  String get readOnly => 'Nur Lesen';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Lesen Sie den Ordner und fassen Sie Stack, Einstiegspunkte und den Start zusammen.';

  @override
  String get readThePage => 'Seite gelesen';

  @override
  String get readTheUiTree => 'UI-Baum gelesen';

  @override
  String get readWrite => 'Lesen / Schreiben';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Liest Schritte, Herzfrequenz, Schlaf, Bewegung und Gewicht.';

  @override
  String get ready => 'Bereit';

  @override
  String get readyForFirstTimeSetup => 'Bereit für die Ersteinrichtung';

  @override
  String get readyToConnect => 'Bereit zur Verbindung';

  @override
  String get realWorkInsteadOfJustTalking =>
      'Arbeit erledigen kann, statt nur darüber zu sprechen.';

  @override
  String get recapMyDaySummarizeTheConversations =>
      'Fasse meinen Tag zusammen: fasse die Gespräche, erledigte Arbeit und ';

  @override
  String get recentChannelActivity => 'Letzte Kanalaktivität';

  @override
  String get recentChats => 'Letzte Chats';

  @override
  String get recentDecisions => 'Letzte Entscheidungen';

  @override
  String get recentFailedRuns => 'Aktuelle fehlgeschlagene Läufe';

  @override
  String get recentGroupDecisions => 'Letzte Gruppenentscheidungen';

  @override
  String get recentRuns => 'Aktuelle Läufe';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Aktuelle Läufe dauern etwa $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Aktuelle Serverausgabe, neueste zuerst.';

  @override
  String get recentUsage4Hours => 'Aktuelle Nutzung (4 Stunden)';

  @override
  String get recents => 'Zuletzt';

  @override
  String get recipientField => 'Empfängerfeld';

  @override
  String get recommended => 'EMPFOHLEN';

  @override
  String get reconnectOrFinishSetup =>
      'Erneut verbinden oder Einrichtung abschließen';

  @override
  String get reconnectingThisDevice => 'Dieses Gerät wird erneut verbunden…';

  @override
  String get recurring => 'Wiederkehrend';

  @override
  String get redirectUri => 'Weiterleitungs-URI';

  @override
  String get redoOnboarding => 'Onboarding wiederholen';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get refreshCode => 'Code aktualisieren';

  @override
  String get refreshNow => 'Jetzt aktualisieren';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Aktualisieren Sie den Android-Bildschirm, um es erneut zu versuchen.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Nur senden, wenn die Verbindung auf TLS umschaltet.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'unabhängig von den Kategorieeinstellungen unten.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return '$arg1 für das Aufrufen des Assistenten registrieren.';
  }

  @override
  String get registrationIsClosed => 'Registrierung ist geschlossen';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registrierung registrieren neue konten signup erlauben';

  @override
  String get rejectInvalidTlsCertificates =>
      'Ungültige TLS-Zertifikate ablehnen';

  @override
  String relationArg1(Object? arg1) {
    return 'Relation: $arg1';
  }

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'Version und startet neu. Verbundene Apps verbinden sich wieder, sobald er zurück ist.';

  @override
  String get releaseChannel => 'Release-Kanal';

  @override
  String get releaseCommitBranchNode => 'release commit branch node';

  @override
  String get releaseWhenYouAreDone => 'Loslassen, wenn Sie fertig sind.';

  @override
  String get reloadNow => 'Jetzt neu laden';

  @override
  String get rememberThisChoice => 'Diese Auswahl merken';

  @override
  String get remove => 'Entfernen';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return '„$arg1“ und die aufgezeichneten Schritte aus dem Ausführungsverlauf entfernen?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return '\"$arg1\" aus dem Kernspeicher entfernen.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return '$arg1-Schlüssel entfernen?';
  }

  @override
  String get removeEraseGdprUser => 'entfernen löschen dsgvo benutzer';

  @override
  String get removeSmtpPassword => 'SMTP-Passwort entfernen';

  @override
  String get removeTheSmtpPassword => 'SMTP-Passwort entfernen?';

  @override
  String get rename => 'Umbenennen';

  @override
  String get renameSecurityKey => 'Sicherheitsschlüssel umbenennen';

  @override
  String get renameSession => 'Sitzung umbenennen';

  @override
  String get repairAndRetry => 'Reparieren und erneut versuchen';

  @override
  String get repairDesktop => 'Desktop reparieren';

  @override
  String get repeat => 'Wiederholen';

  @override
  String get repliesWhenTagged => 'Antwortet bei Erwähnung';

  @override
  String get replyToAddress => 'Antwortadresse (Reply-To)';

  @override
  String replyToArg1(Object? arg1) {
    return 'Antwort an $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Repository muss im Format owner/repo vorliegen.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproduzieren Sie den beschriebenen Fehler, finden Sie die Ursache und beheben Sie ihn mit einem Regressionstest.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'Anfrage fehlgeschlagen mit http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Anfrage fehlgeschlagen mit HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Berechtigungen anfordern';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Anfrage an $arg1 ist fehlgeschlagen, bevor das Backend geantwortet hat.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Angefragt $arg1';
  }

  @override
  String get requireStarttls => 'STARTTLS verlangen';

  @override
  String get requiredBehindHttpsOrATls =>
      'Erforderlich hinter HTTPS oder einem TLS-Proxy. Gilt nach einem Server ';

  @override
  String get requiredExampleBerlinDe => 'Erforderlich. Beispiel: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Erforderlich. Format: owner/repo';

  @override
  String get reserveAssistantHotkey => 'Assistenten-Tastenkürzel reservieren';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get resetPassword => 'Passwort zurücksetzen';

  @override
  String get resetView => 'Ansicht zurücksetzen';

  @override
  String resetsArg1(Object? arg1) {
    return 'Zurücksetzen am $arg1';
  }

  @override
  String get responsibilities => 'Zuständigkeiten';

  @override
  String get restart => 'Neu starten';

  @override
  String get restartToFinishTheUpdate =>
      ' Neu starten, um die Aktualisierung abzuschließen.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Vorherige NeoAgent-Laufzeit wird wiederhergestellt';

  @override
  String get restrictDelegationTargets => 'Delegierungsziele einschränken';

  @override
  String get result => 'Ergebnis';

  @override
  String get resultDelivery => 'Ergebniszustellung';

  @override
  String get resultOneClickAddsOneYou =>
      'Ergebnis. Ein Klick fügt eine hinzu; Sie können sie später bearbeiten.';

  @override
  String get results => 'Ergebnisse';

  @override
  String get retrievalInspector => 'Retrieval-Inspektor';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Wiederverwendbar · $arg1× genutzt';
  }

  @override
  String get reviewMyWeekWhatGotDone =>
      'Schau meine Woche durch: was erledigt wurde, was liegengeblieben ist und was noch offen ist. ';

  @override
  String get reviewUncommittedChanges => 'Nicht committete Änderungen prüfen';

  @override
  String get revoke => 'Widerrufen';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Zuerst Admin-Rechte mit `neoagent admin revoke $arg1` entziehen';
  }

  @override
  String get revokeThisLink => 'Diesen Link widerrufen?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Raumbatch-Fenster: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Drehen zum Fortfahren';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'Zeilen werden angezeigt. Fügen Sie ein LIMIT oder eine engere WHERE-Klausel hinzu, um ';

  @override
  String get rule => 'Regel';

  @override
  String get run => 'Lauf';

  @override
  String get run2 => 'LAUF';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Führen Sie beliebige Befehle auf Ihrem Rechner oder Ihrer VM aus.';

  @override
  String get runAt => 'Ausführen um';

  @override
  String get runCompleted => 'Lauf abgeschlossen';

  @override
  String get runFailed => 'Lauf fehlgeschlagen';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Führen Sie git diff aus, prüfen Sie die nicht committeten Änderungen auf Fehler und Stilprobleme und fassen Sie die Ergebnisse zusammen.';

  @override
  String get runLink => 'LAUF-LINK';

  @override
  String get runLinked => 'Lauf verknüpft';

  @override
  String get runNotFound => 'Ausführung nicht gefunden';

  @override
  String get runNow => 'Jetzt ausführen';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Bei eingehenden persönlichen WhatsApp-Nachrichten ausführen.';

  @override
  String get runQuery => 'Abfrage ausführen';

  @override
  String get runShellCommandsOrInstallApps =>
      'Shell-Befehle ausführen oder Apps auf Ihrem Android-Gerät installieren.';

  @override
  String get runStarted => 'Lauf gestartet';

  @override
  String get runStatus => 'Laufstatus';

  @override
  String get runStopped => 'Lauf gestoppt';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Terminalbefehle ausführen und Apps oder Webseiten öffnen.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Diesen Server betreiben: Konten, Updates, Anbieter, Konfiguration ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Ausführen, wenn eine passende Gmail-Nachricht eintrifft.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Ausführen, wenn eine passende Outlook-E-Mail eintrifft.';

  @override
  String get runWhenANewIssueMatching =>
      'Ausführen, wenn in einem Repository ein neues Issue eröffnet wird, das Ihren Filtern entspricht.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Ausführen, wenn eine neue NeoRecall-Erinnerung erstellt wird, die Ihren Filtern entspricht.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Ausführen, wenn eine Benachrichtigung auf Ihrem Gerät eintrifft.';

  @override
  String get runWhenASlackMessageMatches =>
      'Ausführen, wenn eine Slack-Nachricht dem gewählten Bereich entspricht.';

  @override
  String get runWhenATeamsChatMessage =>
      'Ausführen, wenn eine Teams-Chatnachricht dem gewählten Bereich entspricht.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Ausführen, wenn konfigurierte Wetterereignisse für einen Ort vorhergesagt werden.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'ausführen darf. Solange ein Modell deaktiviert ist, starten später von Anbietern ';

  @override
  String get running => 'Läuft';

  @override
  String runningArg1(Object? arg1) {
    return 'Führt $arg1 aus';
  }

  @override
  String get runningTask => 'Aufgabe wird ausgeführt';

  @override
  String get runningTool => 'Tool wird ausgeführt';

  @override
  String get runs => 'Läufe';

  @override
  String get runsCommandsBrowsesTheWebAnd =>
      'Führt Befehle aus, durchsucht das Web und bearbeitet Dateien auf einem echten Linux-';

  @override
  String get runsEveryDayAtTheSelected =>
      'Läuft jeden Tag zur gewählten Uhrzeit.';

  @override
  String get runsFourTimesPerHour => 'Läuft viermal pro Stunde.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— Läufe, Nachrichten, Erinnerungen, Integrationen, Dateien und ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'Läufe, Nachrichten, Erinnerungen, Integrationen, Dateien und Sitzungen. ';

  @override
  String get runsMondayThroughFriday => 'Läuft von Montag bis Freitag.';

  @override
  String get runsOnSelectedWeekdays => 'Läuft an den ausgewählten Wochentagen.';

  @override
  String get runsOncePerHour => 'Läuft einmal pro Stunde.';

  @override
  String get runsOncePerMonthOnThe =>
      'Läuft einmal im Monat am ausgewählten Tag.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Läuft nur, wenn Sie auf Jetzt ausführen tippen.';

  @override
  String get runsPerDay => 'Läufe pro Tag';

  @override
  String get runsPerDay30Days => 'Läufe pro Tag (30 Tage)';

  @override
  String get runsThatCompleted => 'Abgeschlossene Läufe';

  @override
  String get runsThisWeek => 'Läufe diese Woche';

  @override
  String get runsToday => 'Läufe heute';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Läufe, Werkzeuge, Gedächtnis, Planung, Skills und MCP sind hier alle verfügbar.';

  @override
  String get runsTwicePerHour => 'Läuft zweimal pro Stunde.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Läufe greifen dann auf den gemeinsamen Serverschlüssel für $arg1 zurück, falls einer konfiguriert ist. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Runtime $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Laufzeit: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Runtime-Einstellungen, mit denen dieser Server gestartet wurde. Bearbeiten Sie sie unter ';

  @override
  String get runtimeSetupRequired =>
      'Laufzeitumgebung muss eingerichtet werden';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Der öffentliche Schlüssel zur Laufzeitsignierung muss 32 Bytes lang sein.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Speichern';

  @override
  String get saveATrelloApiKeyFor =>
      'Speichern Sie einen Trello-API-Schlüssel für diesen Agenten und verbinden Sie anschließend sicher ein Trello-Konto. Das Kontotoken wird auf dem Server gespeichert und nur für diesen Agenten verwendet.';

  @override
  String get saveAccount => 'Konto speichern';

  @override
  String get saveBillingSetup => 'Abrechnungseinrichtung speichern';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get saveCloudComputerSettings =>
      'Cloud-Computer-Einstellungen speichern';

  @override
  String get saveConnect => 'Speichern & Verbinden';

  @override
  String get saveDefaults => 'Standards speichern';

  @override
  String get saveDiagnosticReport => 'Diagnosebericht speichern';

  @override
  String get saveEmail => 'E-Mail speichern';

  @override
  String get saveEmailSettings => 'E-Mail-Einstellungen speichern';

  @override
  String get saveGeneralSettings => 'Allgemeine Einstellungen speichern';

  @override
  String get saveName => 'Name speichern';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'NeoAgent-Einrichtungsdiagnose speichern';

  @override
  String get saveOnly => 'Nur speichern';

  @override
  String get savePlan => 'Tarif speichern';

  @override
  String get saveSetup => 'Einrichtung speichern';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Speichern Sie diese Wiederherstellungscodes jetzt. Sie werden nicht erneut angezeigt.';

  @override
  String saveUpToArg1Yearly(Object? arg1) {
    return 'Bis zu $arg1 % jährlich sparen';
  }

  @override
  String get savedDeliveryDestination => 'Gespeichertes Zustellziel';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Ratenlimits für @$arg1 gespeichert.';
  }

  @override
  String get scanANeoagentLoginQr => 'NeoAgent-Anmelde-QR scannen';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scannen Sie einen NeoAgent-Pairing-QR von einem anderen Gerät und geben Sie ihn in dieser Launcher-Sitzung frei.';

  @override
  String get scanLoginQr => 'Anmelde-QR scannen';

  @override
  String get scanPairingQr => 'Pairing-QR scannen';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scannen Sie QR-Anmeldeanfragen von abgemeldeten Geräten und genehmigen Sie sie aus dieser authentifizierten mobilen Sitzung.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scannen, um $arg1 abzuschließen';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Mit NeoAgent auf Ihrem Telefon scannen';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Prüft neue E-Mails und benachrichtigt Sie nur, wenn etwas wichtig ist.';

  @override
  String get schedule => 'Zeitplan';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'geplanten Zeit. Sobald Läufe gemessen wurden, startet sie früher.';

  @override
  String scoreArg1(Object? arg1) {
    return 'Score: $arg1';
  }

  @override
  String get screen => 'Bildschirm';

  @override
  String get screenAction => 'Bildschirmaktion';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scroll wird auf dieser Plattform nicht unterstützt.';

  @override
  String get scrollToBottom => 'Nach unten scrollen';

  @override
  String get search => 'Suchen';

  @override
  String get search2 => 'Suchen…';

  @override
  String get searchAdminSettingsEGStripe =>
      'Admin-Einstellungen suchen (z. B. Stripe, SMTP, Ollama, Logs)';

  @override
  String get searchAgain => 'Erneut suchen';

  @override
  String get searchByUsernameOrEmail => 'Nach Benutzername oder E-Mail suchen';

  @override
  String get searchChannels => 'Kanäle suchen';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Durchsuchen Sie erkannte Messaging-Kanäle, Kontakte, Gruppen und aktuelle Unterhaltungen.';

  @override
  String get searchGroups => 'Gruppen suchen';

  @override
  String get searchMemory => 'Gedächtnis durchsuchen';

  @override
  String get searchModels => 'Modelle suchen';

  @override
  String get searchModelsOrProviders => 'Modelle oder Anbieter suchen';

  @override
  String get searchModelsOrProviders2 => 'Modelle oder Anbieter suchen…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Letzte Personen und Gruppen suchen';

  @override
  String get searchSessions => 'Sitzungen suchen';

  @override
  String get searchSettings => 'Einstellungen suchen';

  @override
  String get searchTheWebForTodayS =>
      'Suche im Web nach den wichtigsten heutigen Nachrichten zu den Themen, die mich ';

  @override
  String get searchTitleModelTriggerRunId =>
      'Titel, Modell, Auslöser, Ausführungs-ID suchen';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Tools, Integrationen und Skills suchen';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Code nach \"$arg1\" durchsucht';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Dateien nach \"$arg1\" durchsucht';
  }

  @override
  String get secretField => 'Geheimfeld';

  @override
  String get secretKey => 'Geheimschlüssel';

  @override
  String get secureCookies => 'Sichere Cookies';

  @override
  String get security => 'Sicherheit';

  @override
  String get securityKey => 'Sicherheitsschlüssel';

  @override
  String get securityKeyPromptWasDismissed =>
      'Die Aufforderung zum Sicherheitsschlüssel wurde abgebrochen.';

  @override
  String get securityKeySignInCompletedBut =>
      'Anmeldung mit Sicherheitsschlüssel abgeschlossen, aber NeoAgent konnte die Browser-Sitzung nicht behalten. Bitte melden Sie sich erneut an.';

  @override
  String get securityKeySignInCouldNot =>
      'Anmeldung mit Sicherheitsschlüssel konnte nicht gestartet werden.';

  @override
  String get securityKeys => 'Sicherheitsschlüssel';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Sicherheitsschlüssel sind nur in der NeoAgent-Web-App verfügbar.';

  @override
  String get seeAll => 'Alle anzeigen';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Sehen Sie, welchen NeoAgent-Server dieses Fenster nutzt, und führen Sie das Backend auf diesem Computer aus.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'Ihren Benutzernamen und diese Einstellungen, nie Ihre Chats, Erinnerungen ';

  @override
  String get selectARun => 'Ausführung auswählen';

  @override
  String get selectASessionToSeeIts =>
      'Wählen Sie eine Sitzung, um Computer, Dateien und Änderungen zu sehen.';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get selectAll2 => 'Alle auswählen';

  @override
  String get selectAnEventFromTheFeed =>
      'Wählen Sie ein Ereignis aus dem Feed.';

  @override
  String selectArg1(Object? arg1) {
    return '$arg1 auswählen';
  }

  @override
  String get selectTrigger => 'Auslöser wählen';

  @override
  String semanticArg1(Object? arg1) {
    return 'Semantisch: $arg1';
  }

  @override
  String get send => 'Senden (⌘↵)';

  @override
  String get send2 => 'Senden';

  @override
  String get sendATaskFromChatAnd =>
      'Senden Sie eine Aufgabe aus dem Chat – der Ausführungsverlauf erscheint hier.';

  @override
  String get sendItAsAShortScannable =>
      'Sende es als kurze, gut überblickbare Nachricht.';

  @override
  String get sendItToATeammateWith =>
      'senden Sie ihn an ein Teammitglied mit einem Konto auf diesem Server.';

  @override
  String get sendLink => 'Link senden';

  @override
  String get sendPath => 'Sendepfad';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'POST-/PUT-/DELETE-Anfragen an externe APIs senden.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Senden Sie diesen Link nur an die Person, für die er gedacht ist. Er wird einmal angezeigt; ';

  @override
  String get senderAddress => 'Absenderadresse';

  @override
  String get senderFilterOptional => 'Absenderfilter (optional)';

  @override
  String get sentSharedAttachments => 'Geteilte Anhänge gesendet.';

  @override
  String get separateAccount => 'Separates Konto';

  @override
  String get server => 'Server';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Serverstandard ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Servervorgaben für Sprachgespräche in der App. Anrufe laufen über ein Live-';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'Server selbst: Konten, Anbieter und Konfiguration.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Server, Nick, Kanal und optional TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'server ausgabe konsole warnungen fehler kopieren';

  @override
  String get serverProviderCredentials => 'Server-Anbieter-Zugangsdaten';

  @override
  String get serverToStopIt => 'Server neu, um sie zu beenden.';

  @override
  String get serverUrl => 'Server-URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Servernutzungslimits gelten nicht für Modelle mit Ihrem eigenen Schlüssel.';

  @override
  String get serverWithNoAccountsYetAlways =>
      'Server ohne Konten lässt die erste ';

  @override
  String get serviceEmail => 'Service-E-Mail';

  @override
  String get serviceEmailIsNotConfigured =>
      'Service-E-Mail ist nicht konfiguriert';

  @override
  String get serviceEmailSmtp => 'Service-E-Mail (SMTP)';

  @override
  String get sessionActions => 'Sitzungsaktionen';

  @override
  String get sessionToThisDeviceWhenYou =>
      'Sitzung auf Dieses Gerät um, wenn lokal gearbeitet werden soll.';

  @override
  String get sessions => 'Sitzungen';

  @override
  String get sessions2 => 'SITZUNGEN';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sitzungen sind an einen Ordner und einen Computer gebunden. Starten Sie eine, um von hier aus zu planen, zu bauen, zu testen und auszuliefern.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'Sitzungen (DSGVO Art. 17). Admin-Konten können nicht gelöscht werden ';

  @override
  String get sessionsLogoutRevokeForce =>
      'sitzungen abmelden widerrufen erzwingen';

  @override
  String get setBlockAskAllowPerTool =>
      'Blockieren / Fragen / Erlauben pro Tool-Kategorie festlegen oder einen globalen Modus wählen.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'NeoAgent auf diesem Computer einrichten';

  @override
  String get setUpOrConnectNeoagent => 'NeoAgent einrichten oder verbinden';

  @override
  String get setUpYourWorkspaceInA =>
      'Richten Sie Ihren Workspace in wenigen Schritten ein und nutzen Sie NeoAgent sofort.';

  @override
  String get setUrl => 'URL festlegen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get settingsAndCannotBeUndone =>
      'Einstellungen und kann nicht rückgängig gemacht werden.';

  @override
  String get settingsArea => 'Einstellungsbereich';

  @override
  String get settingsAreas => 'Einstellungsbereiche';

  @override
  String get setup => 'Einrichtung';

  @override
  String get setupDetails => 'Einrichtungsdetails';

  @override
  String get setupRequired => 'Einrichtung erforderlich';

  @override
  String get setupWasCancelled => 'Einrichtung wurde abgebrochen.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Geteilte Anhänge vom NeoAgent-Client:';

  @override
  String get sharedFromAnotherApp => 'Aus einer anderen App geteilt';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Geteilte Anbieterschlüssel sind auf dem Server konfiguriert. Um stattdessen Ihren eigenen API-Schlüssel oder einen benutzerdefinierten Endpunkt zu nutzen, gehen Sie zu Erweitert → Eigenen Schlüssel mitbringen.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Mit dem NeoAgent-Chat und seinem Speicher geteilt.';

  @override
  String get shellCommands => 'Shell-Befehle';

  @override
  String showAllArg1(Object? arg1) {
    return 'Alle $arg1 anzeigen';
  }

  @override
  String get showEarlier => 'Frühere anzeigen';

  @override
  String get showEveryStep => 'Jeden Schritt anzeigen';

  @override
  String get showTools => 'Tools anzeigen';

  @override
  String get showWorkbenchJ => 'Workbench anzeigen (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Die ersten $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Wird in der Seitenleiste angezeigt. Leer lassen, um Ihren Benutzernamen zu verwenden.';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signInCompletedButNeoagentCould =>
      'Anmeldung abgeschlossen, aber NeoAgent konnte die Browser-Sitzung nicht behalten. Bitte melden Sie sich erneut an. Wenn das weiterhin passiert, prüfen Sie die Backend-Sitzungs-Cookie-Einstellungen.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Anmeldung abgeschlossen, aber NeoAgent konnte die Browser-Sitzung nicht behalten. Bitte melden Sie sich erneut an. Wenn das weiterhin passiert, wird das Backend-Sitzungs-Cookie vermutlich nicht gespeichert.';

  @override
  String get signInToThisNeoagentServer =>
      'Melden Sie sich bei diesem NeoAgent-Server an, bevor Sie einen Pairing-QR-Code scannen.';

  @override
  String get signInWithAHardwareKey =>
      'Melden Sie sich mit einem Hardware-Schlüssel oder Passkey statt mit Ihrem Passwort an. ';

  @override
  String get signInWithASecurityKey => 'Mit Sicherheitsschlüssel anmelden';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Mit $arg1 anmelden';
  }

  @override
  String get signInWithTheSameEmail =>
      'Melden Sie sich mit derselben E-Mail-Adresse und demselben Master-Passwort an, die Sie in Bitwarden verwenden. Master-Passwort und Zwei-Schritt-Code werden nur zur Anmeldung verwendet und nie gespeichert oder an die KI gesendet.';

  @override
  String get signOut => 'Abmelden';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return '@$arg1 überall abmelden?';
  }

  @override
  String get signOutEverywhere => 'Überall abmelden';

  @override
  String get signUpIsClosed => 'Registrierung ist geschlossen.';

  @override
  String get signalCliRestApiBridge => 'signal-cli-REST-API-Brücke';

  @override
  String get signalCliServerUrl => 'signal-cli-Server-URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return '@$arg1 wurde aus allen Sitzungen abgemeldet.';
  }

  @override
  String get signedInDevices => 'Angemeldete Geräte';

  @override
  String get signedInWithin24Hours => 'Angemeldet innerhalb von 24 Stunden';

  @override
  String get signingSecret => 'Signaturgeheimnis';

  @override
  String sinceArg1(Object? arg1) {
    return 'Seit $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'seit $arg1';
  }

  @override
  String get singleMessage => 'Einzelne Nachricht';

  @override
  String get singleUse => 'Einmalig';

  @override
  String get skill => 'Fähigkeit';

  @override
  String get skillChanges => 'Skill-Änderungen';

  @override
  String get skillContent => 'Skill-Inhalt';

  @override
  String get skills => 'Fähigkeiten';

  @override
  String get skip => 'Überspringen';

  @override
  String get skipForNow => 'Vorerst überspringen';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Diese Aufgabe überspringen, bevor sie das Modell aufruft.';

  @override
  String get skipsStripeCheckout => 'überspringt den Stripe-Checkout.';

  @override
  String get slackMessageReceived => 'Slack-Nachricht empfangen';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Schlaf $arg1 Sitzungen';
  }

  @override
  String get smallestCurrencyUnit1900Is19 =>
      'Kleinste Währungseinheit: 1900 entspricht 19,00.';

  @override
  String get smartModelSelection => 'Intelligente Modellauswahl';

  @override
  String get smartSelector => 'Smart Selector';

  @override
  String get smartSelector2 => 'Smart Selector';

  @override
  String get smartSelectorPool => 'Smart-Selector-Pool';

  @override
  String get smtpHost => 'SMTP-Host';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail absender passwort tls bestätigung benachrichtigungen zurücksetzen';

  @override
  String get smtpPassword => 'SMTP-Passwort';

  @override
  String get smtpPort => 'SMTP-Port';

  @override
  String get smtpPortMustBeAWhole =>
      'Der SMTP-Port muss eine ganze Zahl von 1 bis 65535 sein.';

  @override
  String get smtpUsername => 'SMTP-Benutzername';

  @override
  String get soTheRunStartsThatMuch =>
      'daher startet der Lauf entsprechend früher.';

  @override
  String get socialBehaviorOff => 'Soziales Verhalten aus';

  @override
  String get socialIntelligence => 'soziale Intelligenz';

  @override
  String get socialIntelligence2 => 'Soziale Intelligenz';

  @override
  String get socialObservability => 'Soziale Beobachtbarkeit';

  @override
  String get socialReach => 'soziale Reichweite';

  @override
  String get socialReach2 => 'Soziale Reichweite';

  @override
  String get socialReach3 => 'Social Reach';

  @override
  String get socialReachUpdated => 'Social Reach aktualisiert.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Soziale Quellen, die Agenten direkt lesen können, einschließlich Feeds, Repositories, Reddit, X, Videos und cookiegestützter Marktdaten.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut.';

  @override
  String get sortOrder => 'Sortierreihenfolge';

  @override
  String get sortOrderMustBeAWhole =>
      'Die Sortierreihenfolge muss eine ganze Zahl sein.';

  @override
  String get source => 'Quelle';

  @override
  String get source2 => 'QUELLE';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Space- oder Chat-ID, die verwendet wird, wenn dieser Agent eine Unterhaltung startet.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space-Webhook und App-Callback-Unterstützung';

  @override
  String get speaking => 'Spricht';

  @override
  String get speechToSpeechModelUsingThe =>
      'Speech-to-Speech-Modell mit dem OpenAI- oder Google-Schlüssel unter ';

  @override
  String get speechToText => 'Sprache zu Text';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Spracherkennung transkribiert Sprachnachrichten und Diktate. Auto verwendet OpenAI, Gemini oder Deepgram – je nachdem, welcher API-Schlüssel hinterlegt ist. Das Sprachantwort-Modell ist das Chat-Modell, das Sprachnachrichten beantwortet.';

  @override
  String get sqlConsole => 'SQL-Konsole';

  @override
  String get stable => 'Stabil';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stabil installiert die neueste veröffentlichte Backend-Version.';

  @override
  String get stackTrace => 'Stacktrace';

  @override
  String get standard => 'Standard';

  @override
  String get standardView => 'Standardansicht';

  @override
  String get start => 'Starten';

  @override
  String get startASessionToPlanOr =>
      'Starten Sie eine Sitzung, um mit NeoAgent zu planen oder zu bauen.';

  @override
  String get startAndroid => 'Android starten';

  @override
  String get startComputer => 'Computer starten';

  @override
  String get startFullSetup => 'Vollständige Einrichtung starten';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Einrichtung starten';

  @override
  String get startTalking => 'Sprechen starten';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Starten Sie zuerst das Android-Telefon und legen Sie dann eine .apk- oder .apks-Datei hier ab.';

  @override
  String get startTheServerLaterFromThe =>
      'Starten Sie den Server später aus der Liste, sobald die Konfiguration gespeichert ist.';

  @override
  String get startWithARecommendedTask =>
      'Mit einer empfohlenen Aufgabe starten';

  @override
  String get startingAndroid => 'Android wird gestartet';

  @override
  String get startingYourComputer => 'Ihr Computer wird gestartet';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Beginnt mit xoxb-. Aus den Zugangsdaten Ihrer Slack-App.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting-Fehler: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistik läufe tokens benutzer diagramme erfolgsrate';

  @override
  String get status => 'Status';

  @override
  String get status2 => 'STATUS';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'status datenbank laufzeit vm anbieter';

  @override
  String get statusIsNotLoadedYet => 'Status ist noch nicht geladen.';

  @override
  String get stayManagedByYou => 'bleiben von Ihnen verwaltet.';

  @override
  String get stayOnTheCall => 'Im Gespräch bleiben';

  @override
  String get stayedQuiet => 'Still geblieben';

  @override
  String get steering => 'STEUERUNG';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'SCHRITT $arg1 VON $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Schritte $arg1';
  }

  @override
  String get stop => 'Stoppen';

  @override
  String get stop2 => 'Stopp (⌘.)';

  @override
  String get stopManaging => 'Verwaltung beenden';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Verwaltung von $arg1 beenden?';
  }

  @override
  String get stopRun => 'Ausführung stoppen';

  @override
  String get stopSpeaking => 'Sprechen beenden';

  @override
  String get stoppedBeforeCompletion => 'Vor Abschluss gestoppt';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting-Fehler: $arg1';
  }

  @override
  String get storage => 'Speicher';

  @override
  String get storeSkill => 'Store-Skill';

  @override
  String storedArg1(Object? arg1) {
    return 'Gespeichert: $arg1';
  }

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'verschlüsselt gespeichert und nur für Ihre eigenen Läufe verwendet.';

  @override
  String get storedMetrics => 'Gespeicherte Metriken';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Speichert nur den Bitwarden-Sitzungsschlüssel verschlüsselt auf diesem Server, damit Verbindungen Neustarts überstehen. Sie können ihn jederzeit sperren.';

  @override
  String get stripeBilling => 'Stripe-Abrechnung';

  @override
  String get stripeKeysForPaidPlansPoint =>
      'Stripe-Schlüssel für kostenpflichtige Tarife. Richten Sie einen Stripe-Webhook auf ';

  @override
  String get stripePriceId => 'Stripe-Preis-ID';

  @override
  String get stripeSetup => 'Stripe-Einrichtung';

  @override
  String get strong => 'Stark';

  @override
  String get strongPassword => 'Starkes Passwort.';

  @override
  String get subAgent => 'Subagent';

  @override
  String get subagentUpdate => 'Subagent-Update';

  @override
  String get subagentUpdate2 => 'Subagent-Update.';

  @override
  String get subscription => 'Abonnement';

  @override
  String get subscriptionBillingOverrideComp =>
      'abo abrechnung überschreibung gratis';

  @override
  String get subscriptionCanceled => 'Abonnement gekündigt.';

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get successRate => 'Erfolgsrate';

  @override
  String get suggestTheThreeMostImportantThings =>
      'Schlage die drei wichtigsten Dinge vor, auf die ich mich nächste Woche konzentrieren sollte.';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Vorschläge: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Meinen letzten Lauf zusammenfassen';

  @override
  String get summary => 'ZUSAMMENFASSUNG';

  @override
  String get supportUrl => 'Support-URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Unterstützt: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Agent wechseln';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Symbolische Links sind in NeoAgent-Workspace-Pfaden nicht erlaubt.';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'System-Datenschutzeinstellungen';

  @override
  String get tableInfoUsers => 'Tabelleninfo (users)';

  @override
  String get tagsOnly => 'Nur Markierungen';

  @override
  String get tapAnEntityToFilterMemories =>
      'Tippen Sie auf eine Entität, um Erinnerungen danach zu filtern.';

  @override
  String get task => 'AUFGABE';

  @override
  String get tasks => 'Aufgaben';

  @override
  String get tasksRunOnAScheduleOr =>
      'Aufgaben laufen nach Zeitplan oder bei Ereignissen und ';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Aufgaben laufen selbstständig und senden Ihnen das ';

  @override
  String get tcpBridgeToALocalDevice =>
      'TCP-Brücke zu einem lokalen Gerätekanal';

  @override
  String get teach => 'Beibringen';

  @override
  String get teachingInProgress => 'Einlernen läuft';

  @override
  String get team => 'Team';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Team-Links machen niemanden zum Server-Admin. Admins betreiben den ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Team-Spaces, Räume, Kanäle und Live-Communities.';

  @override
  String get teamsMessageReceived => 'Teams-Nachricht empfangen';

  @override
  String get templates => 'Vorlagen';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Temporäre Einrichtungsdateien werden später bereinigt.';

  @override
  String get tenantId => 'Mandanten-ID';

  @override
  String get testConnection => 'Verbindung testen';

  @override
  String get testConnection2 => 'Verbindung testen';

  @override
  String get textChat => 'Text & Chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'die einen eigenen Schlüssel hinzugefügt haben, behalten ihn.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Diese E-Mail gehört bereits zu einem bestehenden Konto. Melden Sie sich zuerst an und verknüpfen Sie Google dann in den Kontoeinstellungen.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Diese E-Mail ist bereits mit einem anderen Konto verknüpft.';

  @override
  String get thatGoogleAccountIsAlreadyLinked =>
      'Dieses Google-Konto ist bereits mit einem anderen NeoAgent-Konto verknüpft.';

  @override
  String get thatQrCodeIsNotA =>
      'Dieser QR-Code ist keine NeoAgent-Anmeldeanfrage.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Dieser QR-Code ist keine NeoAgent-Pairing-Anfrage.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Dieser Sicherheitsschlüssel ist bereits für dieses Konto registriert.';

  @override
  String get theAddress => 'Die Adresse';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Die Adresse Ihres BlueBubbles-Servers.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Die Adresse, über die Personen und OAuth-Anbieter ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Der Agent liest von Ihnen genannte Zeiten und führt geplante Aufgaben in dieser Zeitzone aus.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Der Agent fragt vor jedem sensiblen Tool nach, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Der Agent ignoriert diesen Skill.';

  @override
  String get theAppCouldNotReachThis =>
      'Die App konnte dieses NeoAgent-Deployment nicht erreichen. Prüfen Sie Ihre Netzwerkverbindung oder ob die Service-URL korrekt ist.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Der Browser hat eine Anfrage an $arg1 wegen der Content Security Policy blockiert.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Der Browser hat eine erforderliche Anfrage wegen der Content Security Policy blockiert.';

  @override
  String get theCloudComputerIsSandboxedFrom =>
      'Der Cloud-Computer ist von Ihren Geräten abgeschirmt. Stellen Sie eine ';

  @override
  String get theCloudWorkspace => 'den Cloud-Arbeitsbereich';

  @override
  String get theComputerCouldNotStart =>
      'Der Computer konnte nicht gestartet werden';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Der Computer braucht mehr freien Speicherplatz auf dem NeoAgent-Host. Geben Sie Speicherplatz frei und versuchen Sie es erneut.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Die Computer-Runtime muss repariert werden. Führen Sie NeoAgent Doctor aus und versuchen Sie es erneut.';

  @override
  String get theConnectionTestFailed =>
      'Der Verbindungstest ist fehlgeschlagen.';

  @override
  String get theDesktopDidNotStart => 'Der Desktop ist nicht gestartet';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Das gefundene NeoAgent hat unvollständige Identitätsdaten zurückgegeben.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Das gefundene NeoAgent verwendet ein nicht unterstütztes Einrichtungsprotokoll.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Der gefundene Dienst ist nicht NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Die heruntergeladene NeoAgent-Laufzeit hat die Prüfung nicht bestanden.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Der Google-Chat-Space-Webhook, an den dieser Agent posten soll.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Der Installer ist nicht mehr verfügbar.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Der interaktive Linux-Desktop ist in der NeoAgent-Web-App verfügbar.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Die Einführung ist auf diesem Gerät nicht verfügbar.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Die neuesten Läufe über alle Konten.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Das letzte Synchronisationsfenster endete $arg1 und fand keine neuen Health-Connect-Datensätze. Die unten gespeicherten Metriken stammen aus früheren Synchronisationen.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Die grafische Linux-Sitzung läuft nicht.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Das Live-Sprachmodell hat nicht geantwortet. Versuchen Sie es erneut.';

  @override
  String get theLocalIpOfTheMeshtastic =>
      'Die lokale IP des Meshtastic-Geräts.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Der lokale NeoAgent-Befehl wurde mit Code $arg1 beendet.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Der lokale NeoAgent-Befehl ist abgelaufen.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Die lokale NeoAgent-Laufzeitumgebung muss repariert werden.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Die lokale Runtime muss repariert werden ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Das lokale Benutzer-Home-Verzeichnis ist nicht verfügbar.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Das Mailkonto, von dem NeoAgent Registrierungsbestätigungen, Anmelde-';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Der Hauptagent wird bei Bedarf automatisch erstellt.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Die passende NeoAgent-Laufzeit fehlt in diesem Release.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Der eingehende Mattermost-Webhook, an den dieser Agent posten soll.';

  @override
  String get theModelListCouldNotBe =>
      'Die Modellliste konnte nicht geladen werden. Geben Sie Modell-IDs durch ';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Die Modelle, zwischen denen der Smart Selector automatisch routet.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Der NeoAgent-Backend-Download stimmt nicht mit dem Manifest überein.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Der NeoAgent-Backend-Download war unvollständig.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Das NeoAgent-Backend auf diesem Computer antwortet nicht auf Port ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Die NeoAgent-Backend-Laufzeit konnte nicht heruntergeladen werden.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Das NeoAgent-Backend hat für $arg1 zu lange zum Antworten gebraucht.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Das NeoAgent-Deployment hat mit HTTP 402 statt dem üblichen 401 für ungültige Anmeldedaten geantwortet. Prüfen Sie Reverse-Proxy-, Auth-Gateway- oder zahlungsbezogene Regeln auf diesem Server.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Das NeoAgent-Deployment hat mit HTTP 402 geantwortet.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Das NeoAgent-Deployment hat mit HTTP 402 geantwortet. Prüfen Sie Reverse-Proxy-, Auth-Gateway- oder zahlungsbezogene Regeln auf diesem Server.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Die NeoAgent-Instanz, mit der diese App verbunden ist.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Der NeoAgent-Release-Dienst hat ungültige Daten zurückgegeben.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Die Metadaten des NeoAgent-Laufzeitartefakts sind ungültig.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Das NeoAgent-Laufzeitmanifest hat die Signaturprüfung nicht bestanden.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Das NeoAgent-Laufzeitmanifest enthält keine Artefakte.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Die Signatur des NeoAgent-Laufzeitmanifests ist ungültig.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Das Passwort, das Sie in BlueBubbles festgelegt haben.';

  @override
  String get thePeopleYouManageStayWith =>
      'Die Personen, die Sie verwalten, bleiben bei Ihnen.';

  @override
  String get thePlanStopsBeingOfferedIt =>
      'Der Tarif wird nicht mehr angeboten. Er bleibt erhalten, wird nicht gelöscht, und ';

  @override
  String get theProviderAnswers => 'der Anbieter antwortet.';

  @override
  String get theQueryReturnedNoRows =>
      'Die Abfrage hat keine Zeilen zurückgegeben.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Die angeforderte Desktop-Anzeige ist nicht verfügbar.';

  @override
  String get theRest => 'den Rest zu sehen.';

  @override
  String get theRestEndpointForYourSignal =>
      'Der REST-Endpunkt Ihrer signal-cli-Instanz.';

  @override
  String get theRunIsPausedUntilYou =>
      'Der Lauf ist pausiert, bis Sie antworten.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Der Lauf startet zur geplanten Zeit.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Die Runtime ist ein schlanker Debian-Linux-Desktop mit Chromium, PCManFM, Mousepad, LXTerminal, Python, Git und gängigen Kommandozeilen-Tools. Die Kapazität verwaltet der NeoAgent-Host.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Die Sicherheitsschlüssel-Registrierung konnte nicht gestartet werden.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'der Server speichert nur einen Fingerabdruck davon.';

  @override
  String get theServerOnThisComputerIs =>
      'Der Server auf diesem Computer läuft nicht';

  @override
  String get theServerReportedNoHealthChecks =>
      'Der Server hat keine Gesundheitsprüfungen gemeldet.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Die Signal-Telefonnummer, die dieser Bot verwendet.';

  @override
  String get theSubscriptionPlansPeopleCanChoose =>
      'Die Abonnementtarife, aus denen Personen wählen können.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Der eingehende Teams-Webhook, an den dieser Agent posten soll.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Die Zwei-Faktor-Herausforderung ist abgelaufen. Melden Sie sich erneut an.';

  @override
  String get theTwoFactorCodeIsNot => 'Der Zwei-Faktor-Code ist ungültig.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Das verifizierte Laufzeitpaket konnte nicht als ausführbar markiert werden.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Dem verifizierten Laufzeitpaket fehlen erforderliche Dateien.';

  @override
  String get theWebAppCouldNotReach =>
      'Die Web-App konnte das NeoAgent-Backend nicht erreichen.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Die Web-App konnte das NeoAgent-Backend unter $arg1 nicht erreichen. Prüfen Sie die Browserkonsole und die Reverse-Proxy-/Netzwerkkonfiguration.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'selbst löschen; der Serverbetreiber entfernt zuerst die Admin-Rechte mit ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Diese Kanäle bleiben stumm. Um wieder von ihnen zu hören, fügen Sie sie unter Wer darf schreiben für diese Plattform hinzu.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Diese Listen sind optional, es sei denn, ein Abschnitt oben ist auf Nur Freigegebene gestellt.';

  @override
  String get thesePeopleAnywhere => 'Diese Personen, überall';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Diese Personen können $arg1 in privaten Chats und in jeder gemeinsamen Gruppe schreiben.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Diese Personen können $arg1 Eins-zu-eins schreiben. Das erlaubt ihnen nicht, in Gruppen zu sprechen.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Diese Personen können $arg1 nur in der von Ihnen gewählten Gruppe schreiben.';
  }

  @override
  String get thesePeopleInOneGroup => 'Diese Personen, in einer Gruppe';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'diese Schalter, nie Ihre Chats, Erinnerungen oder Dateien.';

  @override
  String get thisAccountIsIgnored => 'diesem Konto werden ignoriert.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Dieses Konto entsperrt NeoAgent auf diesem Gerät.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Dieser Agent kann an jeden geeigneten empfangenden Agenten delegieren.';

  @override
  String get thisAgentIsUsingAServer =>
      'Dieser Agent verwendet einen serverseitig verwalteten Trello-API-Schlüssel. Sie müssen unten nur ein Kontotoken autorisieren.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Dieser Build darf nicht mit diesem NeoAgent-Deployment kommunizieren.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Dieser Code gehört zu einem anderen NeoAgent-Server: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Dieser Desktop ist verbunden';

  @override
  String get thisDevice => 'Dieses Gerät';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Dieses Gerät: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Dieses Gerät kann keine Sicherheitsschlüssel registrieren. Öffnen Sie NeoAgent in einem Browser über HTTPS, um einen hinzuzufügen.';

  @override
  String get thisDeviceUnavailable => 'Dieses Gerät — nicht verfügbar';

  @override
  String get thisFileHasNoContent => 'Diese Datei hat keinen Inhalt.';

  @override
  String get thisGoogleAccountIsNotLinked =>
      'Dieses Google-Konto ist noch nicht verknüpft. Nutzen Sie zuerst die Anbieterregistrierung, oder melden Sie sich normal an und verknüpfen Sie es in den Kontoeinstellungen.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Dadurch wird „$arg1“ aus Routing und Auswahl ausgeblendet.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Diese Integration unterstützt derzeit ein verbundenes Konto pro Agent. Öffnen Sie die Einrichtung erneut, um es zu ersetzen.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Diese Integration ist nicht mehr verfügbar.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Diese Einführung ist für die Vollbildwiedergabe im Querformat gedacht.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Dies ist ein verwaltetes Deployment. Der Betreiber rollt ';

  @override
  String get thisMayTakeAMoment => 'Das kann einen Moment dauern.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Dieser MCP-Server ist nicht mehr konfiguriert.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Diese Erinnerung wird dauerhaft entfernt.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Dieser NeoAgent-Build ist nicht für die Verifizierung von Backend-Laufzeiten konfiguriert.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Dadurch werden alle Ihre Daten dauerhaft gelöscht und können nicht ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Dadurch werden das Konto und alles, was dazu gehört, dauerhaft gelöscht: ';

  @override
  String get thisPersonAnywhere => 'Diese Person, überall';

  @override
  String get thisPersonInOneGroup => 'Diese Person, in einer Gruppe';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Diese QR-Anmeldeanfrage ist abgelaufen. Erzeugen Sie einen neuen Code und versuchen Sie es erneut.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'diese QR-Anmeldeanfrage ist abgelaufen';

  @override
  String get thisQrLoginRequestIsStill =>
      'Diese QR-Anmeldeanfrage wartet noch auf Freigabe.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Diese QR-Anmeldeanfrage wurde bereits verwendet.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Dadurch werden die Home-Assistant-Einrichtung und die verbundene Instanz für diesen Agenten entfernt.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Dadurch werden die NeoRecall-Backend-URL und alle verbundenen NeoRecall-Konten für diesen Agenten entfernt.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Dadurch werden die Nextcloud-URL und alle verbundenen Nextcloud-Konten für diesen Agenten entfernt.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Dadurch werden die Trello-Einrichtung und verbundene Konten für diesen Agenten entfernt.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Erfordert eine authentifizierte Sitzung auf demselben NeoAgent-Server.';

  @override
  String get thisRunDidNotProduceA =>
      'Dieser Lauf hat keine für den Nutzer sichtbare Antwort erzeugt.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Diese Ausführung hat keine aufgezeichneten Schrittdaten.';

  @override
  String get thisServer => 'diesen Server erreichen.';

  @override
  String get thisServerIsAlreadySetUp =>
      'Dieser Server ist bereits eingerichtet. Melden Sie sich mit einem bestehenden Konto an.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Dieser Server meldet keine Anbietereinstellungen.';

  @override
  String get thisSkillIsNoLongerIn => 'Dieser Skill ist nicht mehr im Store.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Dieser Skill ist nicht mehr installiert.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Diese Aufgabe hat noch keinen abgeschlossenen Lauf, startet also weiterhin zur ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Diese Aufgabe läuft nur, wenn Sie auf Jetzt ausführen tippen.';

  @override
  String get thisWeek => 'Diese Woche';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Damit wird die Antwort in $arg1 importiert.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Dadurch wird \"$arg1\" entfernt.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Dadurch wird „$arg1“ aus der Serverliste entfernt.';
  }

  @override
  String get tickTheModelsThisPlanMay =>
      'Haken Sie die Modelle an, die dieser Tarif nutzen darf. Alle unangehakt lassen, um ';

  @override
  String get time => 'Zeit';

  @override
  String get time2 => 'ZEIT';

  @override
  String get timeZone => 'Zeitzone';

  @override
  String get timeZone2 => 'Zeitzone';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Zeitüberschreitung$arg1';
  }

  @override
  String get timeline => 'Zeitleiste';

  @override
  String get timelineFeed => 'Zeitachsen-Feed';

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Zeitzonen konnten nicht geladen werden: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Gerätezeitzone konnte nicht gelesen werden: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Gerätezeitzone konnte nicht gespeichert werden: $arg1';
  }

  @override
  String get title => 'TITEL';

  @override
  String toArg1(Object? arg1) {
    return 'nach $arg1 verschoben';
  }

  @override
  String get toUseTheServerDefault => 'um den Server-Standard zu verwenden.';

  @override
  String get today => 'Heute';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Token-Kontingent für @$arg1. Lassen Sie ein Feld leer, ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Token-Kontingent für jedes Konto ohne eigene Überschreibung. Lassen Sie ein ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'token budget limit 4 stunde wöchentlich kontingent benutzer';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token budget limit 4 stunde wöchentlich kontingent global';

  @override
  String get tokenLimitsMustBeWholeNumbers =>
      'Token-Limits müssen ganze Zahlen sein oder leer für den Standard.';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Token-Nutzung auf dieser Serverversion nicht verfügbar.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokens, die jedes Konto in 4 Stunden nutzen darf.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens, die jedes Konto in 7 Tagen nutzen darf.';

  @override
  String get tokensPerDay => 'Tokens pro Tag';

  @override
  String get tokensPerRun => 'Tokens pro Lauf';

  @override
  String get tokensToday => 'Tokens heute';

  @override
  String get tokensUsed => ' Tokens verbraucht';

  @override
  String get tomorrowKeepItShortAndSend =>
      'morgen nachverfolgen sollte. Halte es kurz und sende es mir.';

  @override
  String get tomorrowPrep => 'Vorbereitung für morgen';

  @override
  String get tooManyAttempts => 'zu viele Versuche';

  @override
  String get tooManySignInAttemptsPlease =>
      'Zu viele Anmeldeversuche. Bitte warten Sie und versuchen Sie es erneut.';

  @override
  String get tool => 'Werkzeug';

  @override
  String get toolApproval => 'Tool-Freigabe';

  @override
  String get toolApprovalRequired => 'Tool-Freigabe erforderlich';

  @override
  String get toolCompleted => 'Werkzeug abgeschlossen';

  @override
  String get toolFailed => 'Werkzeug fehlgeschlagen';

  @override
  String get toolPermissions => 'Tool-Berechtigungen';

  @override
  String get toolStarted => 'Werkzeug gestartet';

  @override
  String get tools => 'Werkzeuge';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Tools, die nicht in NeoAgent integriert sind, einschließlich verbundener MCP-Server und eigener Tool-Anbieter.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Angebotene Tools ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Tools, die das verwaltete Konto nutzen darf';

  @override
  String get topUsers => 'Top-Nutzer';

  @override
  String get topUsersAndRecentRuns => 'Top-Nutzer und aktuelle Läufe';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Gesamt: $arg1 Tokens in $arg2 Läufen';
  }

  @override
  String get totalRuns => 'Läufe insgesamt';

  @override
  String get totalTokens => 'Tokens insgesamt';

  @override
  String get totalUsers => 'Nutzer insgesamt';

  @override
  String get transcript => 'Transkript';

  @override
  String get transcript2 => 'TRANSKRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkription fehlgeschlagen: $arg1';
  }

  @override
  String get transfer => 'Übertragen';

  @override
  String get trelloApiKey => 'Trello-API-Schlüssel';

  @override
  String get trelloApiKeyIsRequired => 'Trello-API-Schlüssel ist erforderlich.';

  @override
  String get trelloSetup => 'Trello-Einrichtung';

  @override
  String get triggerType => 'Auslösertyp';

  @override
  String get tryABroaderSearchLikeModels =>
      'Versuchen Sie eine breitere Suche wie Modelle, Browser oder Stimme.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Versuchen Sie einen Anbieternamen, „E-Mail“, „Limits“, „Update“ oder „Logs“.';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Versuchen Sie es erneut. Wenn das weiterhin passiert, führen Sie NeoAgent Doctor aus, um die Computer-Runtime zu prüfen.';

  @override
  String get tryAgainInAMoment => 'Versuchen Sie es in einem Moment erneut.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Versuchen Sie es erneut oder führen Sie NeoAgent Doctor aus.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Versuchen Sie eine andere Suche, verbinden Sie eine Messaging-Plattform oder geben Sie eine Ziel-ID manuell ein.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Aktivieren Sie eine Gruppe, wenn $arg1 auch Nachrichten ohne Markierung lesen soll.';
  }

  @override
  String get turnOffComputer => 'Computer ausschalten';

  @override
  String get turnOffOnlyForAMail =>
      'Nur für einen Mailserver mit selbstsigniertem Zertifikat ausschalten.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Aktivieren, wenn Signal weiterhin nach eingehenden Chats suchen soll.';

  @override
  String get turnTaking => 'Rederecht';

  @override
  String get turnTakingModel => 'Rederecht-Modell';

  @override
  String get turnTakingOff => 'Gesprächswechsel aus';

  @override
  String get turnThisOffToKeepThis =>
      'Ausschalten, um diesen Agenten vollständig von anderen Agenten zu trennen.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Ausgeschaltet von $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Deaktiviert von $arg1, der dieses Konto verwaltet. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Für Sie von $arg1 ausgeschaltet — nur diese Person kann das ändern';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Für Sie ausgeschaltet, daher können Sie es nicht weitergeben';

  @override
  String get twitchChatOverIrc => 'Twitch-Chat über IRC';

  @override
  String get twoFactorAuthentication => 'Zwei-Faktor-Authentifizierung';

  @override
  String get twoFactorChallengeExpired =>
      'Zwei-Faktor-Herausforderung abgelaufen';

  @override
  String get twoFactorCode => 'Zwei-Faktor-Code';

  @override
  String get twoFactorSignInCompletedBut =>
      'Zwei-Faktor-Anmeldung abgeschlossen, aber NeoAgent konnte die Browser-Sitzung nicht behalten. Bitte melden Sie sich erneut an.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Zwei-Schritt-Anmeldung (nur wenn aktiviert)';

  @override
  String get type => 'Typ';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Geben Sie zur Bestätigung $arg1 ein';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'type text wird auf dieser Plattform nicht unterstützt.';

  @override
  String get typedInTheBrowser => 'Im Browser getippt';

  @override
  String get typedText => 'Text eingegeben';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'Java-Runtime konnte nicht gefunden werden';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Zeiteinstellungen können in diesem Build nicht geöffnet werden.';

  @override
  String get unableToOpenWiFiSettings =>
      'Wi-Fi-Einstellungen können in diesem Build nicht geöffnet werden.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Die ausgewählte Desktop-Anzeige konnte nicht gespeichert werden.';

  @override
  String get unclearWhoItWasFor => 'Unklar, für wen es war';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'rückgängig gemacht werden. Geben Sie zur Bestätigung Ihren Benutzernamen ein.';

  @override
  String get unknownAccount => 'Unbekanntes Konto';

  @override
  String get unknownAgent => 'Unbekannter Agent';

  @override
  String get unknownBrowser => 'Unbekannter Browser';

  @override
  String get unknownDevice => 'Unbekanntes Gerät';

  @override
  String get unknownError => 'unbekannter Fehler';

  @override
  String get unknownLocalComputerPermission =>
      'Unbekannte lokale Computerberechtigung.';

  @override
  String get unknownLocation => 'Unbekannter Standort';

  @override
  String get unknownPlan => 'Unbekannter Tarif';

  @override
  String get unknownPublishTime => 'Unbekannter Veröffentlichungszeitpunkt';

  @override
  String get unknownSize => 'Unbekannte Größe';

  @override
  String get unlink => 'Trennen';

  @override
  String get unreadOnly => 'Nur Ungelesene';

  @override
  String get unsavedChanges => 'Ungespeicherte Änderungen';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nicht unterstützter Desktop-Begleiter-Befehl: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nicht unterstützte Methode: $arg1';
  }

  @override
  String get untitledRunEvent => 'Unbenanntes Laufereignis';

  @override
  String get unusualSignInAlerts => 'Hinweise zu ungewöhnlichen Anmeldungen';

  @override
  String get update => 'Aktualisieren';

  @override
  String updateArg1(Object? arg1) {
    return 'Update $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Kernspeicher-Einträge aus dem Import aktualisieren.';

  @override
  String get updateNow => 'Jetzt aktualisieren';

  @override
  String get updateReady => 'Update bereit';

  @override
  String get updateSetup => 'Einrichtung aktualisieren';

  @override
  String get updateTheAccessListToAllow =>
      'Aktualisieren Sie die Zugriffsliste, um Antworten zu erlauben.';

  @override
  String get updateTheServer => 'Server aktualisieren?';

  @override
  String get updateTheServer2 => 'Server aktualisieren';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Zeitzone automatisch vom verwendeten Gerät übernehmen.';

  @override
  String updatedArg1(Object? arg1) {
    return 'aktualisiert $arg1';
  }

  @override
  String get updates => 'Aktualisierungen';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Updates sind für diesen Build nicht konfiguriert.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'Updates aus, daher sind Selbstaktualisierung und Kanalwechsel hier deaktiviert.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'upgrade update jetzt release kanal stable beta';

  @override
  String get usageAnalytics => 'Nutzungsanalysen';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Nutzungs- und Gesundheitssignale, die das aktuelle Laufzeitverhalten erklären, ohne zuerst die Logs durchsuchen zu müssen.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Nutzung wird vollständig zurückgesetzt in $arg1';
  }

  @override
  String get usageLeaderboard => 'nutzung rangliste';

  @override
  String get usageLimits => 'Nutzung & Limits';

  @override
  String get usageLimits2 => 'Nutzung & Limits';

  @override
  String get usageThisPeriod => 'Nutzung in dieser Periode';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Verwenden Sie mindestens 8 Zeichen. Längere Passphrasen eignen sich gut.';

  @override
  String get useADateAndTimeFor =>
      'Datum und Uhrzeit angeben, zum Beispiel 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Nutzen Sie einen Namen, eine Telefonnummer oder eine Chat-ID.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Verwenden Sie eine NeoRecall-URL, die der NeoAgent-Server erreichen kann. Die PUBLIC_URL von NeoAgent muss für den OAuth-Callback auch von diesem Browser aus erreichbar sein.';

  @override
  String get useANewPasswordWithAt =>
      'Verwenden Sie ein neues Passwort mit mindestens 8 Zeichen.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Verwenden Sie eine Nextcloud-URL, die der NeoAgent-Server erreichen kann, zum Beispiel https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Verwenden Sie ein Passwort mit mindestens 8 Zeichen.';

  @override
  String get useASecureConnectionTls => 'Sichere Verbindung verwenden (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Verwenden Sie eine Authenticator-App wie Authy, 1Password oder Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Mindestens 1 vCPU verwenden.';

  @override
  String get useAtLeast8Characters => 'Verwenden Sie mindestens 8 Zeichen.';

  @override
  String get useDefault => 'Standard verwenden';

  @override
  String get useDefaultChannel => 'Standardkanal verwenden';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Standard verwenden (NeoAgent Workspace)';

  @override
  String get useFor => 'Verwenden für';

  @override
  String get useManualDestination => 'Manuelles Ziel verwenden';

  @override
  String get useOrDoTheSameFor =>
      'nutzen darf, oder tun Sie dasselbe für Ihre Teammitglieder.';

  @override
  String get usePerCategorySettingsBelow =>
      'Kategorieeinstellungen unten verwenden.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Einstellungsstandard verwenden ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Server auf diesem Computer verwenden';

  @override
  String get useTheseForContextIfA =>
      'Nutzen Sie diese als Kontext. Wenn eine lokale URI vom Server aus nicht direkt erreichbar ist, bitten Sie mich, die Datei über einen zugänglichen Workspace bereitzustellen.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Für Orchestrierungs-Agenten verwenden. Für isolierte Arbeitsbots, die Direktnachrichten selbst erledigen sollen, ausgeschaltet lassen.';

  @override
  String get useTlsFromTheStartOf =>
      'TLS vom Verbindungsbeginn an nutzen, meist auf Port 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Verwenden Sie Ihren eigenen API-Schlüssel für einen Anbieter oder verbinden Sie einen eigenen ';

  @override
  String get usedByEveryAccountOnThis =>
      'Wird von jedem Konto auf diesem Server genutzt, das keinen eigenen Schlüssel ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Dient zur Überprüfung, dass eingehende Slack-Ereignisse echt sind.';

  @override
  String get userSummary => 'Nutzerübersicht';

  @override
  String get username => 'Benutzername';

  @override
  String get usernameOrEmail => 'Benutzername oder E-Mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'benutzer personen suchen e-mail benutzername admin abzeichen verwaltet team';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Verwendet das unter Einstellungen konfigurierte Chat-Modell';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Installierte NeoAgent-Laufzeit wird verwendet';

  @override
  String get usually0ForThePrimaryChannel =>
      'Üblicherweise 0 für den Hauptkanal.';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Sieht üblicherweise aus wie @bot:matrix.org';

  @override
  String get validEmail => 'gültige E-Mail';

  @override
  String get value => 'Wert';

  @override
  String get vaultLocked => 'Tresor gesperrt';

  @override
  String get vaultOperationFailed => 'Tresoroperation fehlgeschlagen.';

  @override
  String vectorRankArg1(Object? arg1) {
    return 'Vektorrang: $arg1';
  }

  @override
  String get verification => 'Überprüfung';

  @override
  String verificationArg1(Object? arg1) {
    return 'Prüfung: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'Prüfung: $arg1';
  }

  @override
  String get verificationCompleted => 'Prüfung abgeschlossen.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Prüfstatus: $arg1';
  }

  @override
  String get verifiedTheResult => 'Ergebnis überprüft';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Heruntergeladene Laufzeit wird geprüft';

  @override
  String get versionAndUptime => 'Version und Betriebszeit';

  @override
  String versionArg1(Object? arg1) {
    return 'Version $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Version $arg1 ist installiert, aber $arg2 läuft noch.';
  }

  @override
  String get videoLinks => 'Video-Links';

  @override
  String get viewDesktop => 'Desktop anzeigen';

  @override
  String get viewLastRun => 'Letzten Lauf anzeigen';

  @override
  String get viewLogs => 'Protokolle anzeigen';

  @override
  String get viewPlans => 'Tarife anzeigen';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm image speicher cpu qemu laufzeit';

  @override
  String get voice => 'Stimme';

  @override
  String get voiceAssistant => 'Sprachassistent';

  @override
  String get voiceCall => 'SPRACHANRUF';

  @override
  String get voiceCall2 => 'Sprachanruf';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'anruf sprache gpt-live gemini live modell speech realtime';

  @override
  String get voiceCallsRunOnALive =>
      'Sprachanrufe laufen über ein Live-Speech-to-Speech-Modell mit derselben Persona, demselben Speicher und derselben Chat-Historie wie NeoAgent. Es antwortet sofort und übergibt echte Arbeit an den normalen Agenten, der im Hintergrund weiterläuft.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'sprachnachricht sprache transkription api key';

  @override
  String get voiceNotesAndDictation => 'Sprachnotizen und Diktat';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Sprachwiedergabe ist auf diesem Gerät nicht verfügbar.';

  @override
  String get voiceReplyModel => 'Antwortmodell für Stimme';

  @override
  String get waitingForApproval => 'Warte auf Freigabe: ';

  @override
  String get waitingForCode => 'Warte auf Code';

  @override
  String get waitingForInput => 'Wartet auf Eingabe';

  @override
  String get waitingForServerOrFlutterLog =>
      'Warte auf Server- oder Flutter-Logausgabe…';

  @override
  String get waitingForTaskEvents => 'Warte auf Aufgabenereignisse...';

  @override
  String get waitingForYou => 'wartet auf Sie';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Wollte eine Antwort von $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Möchte mit Ihnen sprechen · ${arg1}s';
  }

  @override
  String get watchItLive => 'Live zusehen';

  @override
  String get weak => 'Schwach';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Wetter, Kalender und Prioritäten, bevor Ihr Tag beginnt.';

  @override
  String get weatherEvent => 'Wetterereignis';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Webbrowser';

  @override
  String get webSearchApiKey => 'websuche api key';

  @override
  String get webhookOrRestChannelPosting => 'Webhook- oder REST-Kanal-Posting';

  @override
  String get webhookSecret => 'Webhook-Geheimnis';

  @override
  String get webhookSigningSecret => 'Webhook-Signiergeheimnis';

  @override
  String get webhookUrlCopied => 'Webhook-URL kopiert';

  @override
  String get weekdays => 'Wochentage';

  @override
  String get weekdays0730 => 'Wochentags · 07:30';

  @override
  String get weekdays1800 => 'Wochentags · 18:00';

  @override
  String get weekly => 'Wöchentlich';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Wochenlimit $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Wochenlimit (Tokens)';

  @override
  String get weeklyReview => 'Wochenrückblick';

  @override
  String get weeklyTokenLimit => 'Wöchentliches Token-Limit';

  @override
  String get weeklyTokens => 'Wöchentliche Tokens';

  @override
  String get weeklyUsage => 'Wöchentliche Nutzung';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Gewicht $arg1 Einträge';
  }

  @override
  String get welcomeToNeoagent => 'WILLKOMMEN BEI NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Willkommen bei\nNeoAgent';

  @override
  String get whatAreYouAdding => 'Was möchten Sie hinzufügen?';

  @override
  String get whatIsOnTomorrow => 'Was steht morgen an?';

  @override
  String get whatShouldNeoagentLearn => 'Was soll NeoAgent lernen?';

  @override
  String get whatShouldWeBuild => 'Was sollen wir bauen?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Was Sie und NeoAgent sagen, erscheint hier und im Chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Persönliche WhatsApp-Nachricht empfangen';

  @override
  String get whenOffOnlyExistingAccountsCan =>
      'Wenn aus, können sich nur bestehende Konten anmelden. Ein ';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Wenn Sie „Nur freigegeben“ wählen, fügen Sie unten Personen oder Gruppen hinzu.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Wohin dieser Agent Antworten senden soll.';

  @override
  String get whileItWorks => 'während der Arbeit zu sehen.';

  @override
  String get whoCanMessage => 'Wer darf schreiben';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Wer darf auf $arg1 schreiben';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Wer $arg1 eine Eins-zu-eins-Nachricht senden darf.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Wer in einer Gruppe, einem Kanal oder Raum mit $arg1 sprechen darf.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'die dieses Konto verwaltet, deaktiviert hat: ';

  @override
  String get whoManagesWhom => 'Wer wen verwaltet';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Wer einen Link annimmt, tritt Ihrem Team nur mit den Tools bei, die er ';

  @override
  String get wholeGroup => 'Ganze Gruppe';

  @override
  String get wholeGroups => 'Ganze Gruppen';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Warum $arg1 in $arg2-Gruppen geantwortet oder geschwiegen hat.';
  }

  @override
  String get windowsApp => 'Windows-App';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Arbeitskonto';

  @override
  String get workOnAProjectWithNeoagent =>
      'An einem Projekt mit NeoAgent arbeiten';

  @override
  String workflowArg1(Object? arg1) {
    return 'Workflow: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Arbeitet in $arg1 auf dem Cloud-Computer. NeoAgent liest und bearbeitet dort Dateien und kann Befehle sowie einen Browser ausführen.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Arbeitet im Hintergrund: $arg1';
  }

  @override
  String get worksLikeYouWould => 'Arbeitet, wie Sie es würden';

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Arbeitsbereichskonfiguration und Kontosicherheit an einem Ort.';

  @override
  String get workspaceFiles => 'Workspace-Dateien';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Steuerung für Arbeitsbereich, Modelle und Diagnose.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Die Workspace-Überschreibung muss ein absoluter Pfad sein.';

  @override
  String wroteArg1(Object? arg1) {
    return '$arg1 geschrieben';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'XMLHttpRequest-Fehler';

  @override
  String get yearly => 'Jährlich';

  @override
  String get yesterday => 'Gestern';

  @override
  String get youAreInControl => 'Sie haben die Kontrolle';

  @override
  String get youCanFollowAlongOnThe =>
      'Sie können auf dem Desktop mitverfolgen.';

  @override
  String get youCanLeaveATeamAt =>
      'Sie können ein Team jederzeit verlassen; dann gelten wieder Ihre eigenen Einstellungen.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Sie können jederzeit auf der Team-Seite austreten.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Sie entscheiden, welche Tools Ihr Agent nutzen darf, unter Einstellungen › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Sie verwalten noch niemanden. Erstellen Sie unten einen Einladungslink und ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Sie haben ungespeicherte Einstellungen. Was möchten Sie tun?';

  @override
  String get youReOnYourOwnYou =>
      'Sie sind auf sich gestellt: Sie entscheiden, welche Tools Ihr Agent nutzen darf. Wenn ';

  @override
  String get yourAccountAndUsageOnA =>
      'Ihr Konto nutzbar -- und die Nutzung eines Modells mit Ihrem eigenen Schlüssel ';

  @override
  String get yourAccountHasBeenDeleted => 'Ihr Konto wurde gelöscht.';

  @override
  String get yourAgentWillBeAllowed => 'Ihr Agent darf:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Ihre Apps und Dateien sind gespeichert.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Ihre Apps und Dateien bleiben gespeichert.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Ihr $arg1-Schlüssel';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Ihre Assistentenschicht für Erfassen, Kontext und Handeln.';

  @override
  String get yourComputerIsAsleep => 'Ihr Computer ist im Ruhezustand';

  @override
  String get yourComputerIsOff => 'Ihr Computer ist ausgeschaltet';

  @override
  String get yourComputerIsReady => 'Ihr Computer ist bereit';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Ihr aktuelles Passwort ist falsch.';

  @override
  String get yourData => 'Ihre Daten';

  @override
  String get yourDataExportWasCopiedTo =>
      'Ihr Datenexport wurde in die Zwischenablage kopiert.';

  @override
  String get yourDesktopIsReady => 'Ihr Desktop ist bereit';

  @override
  String get yourLinuxComputer => 'Ihr Linux-Computer';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Ihr Standort wird niemals durchgehend verfolgt oder auf unseren Servern gespeichert. Wir nutzen ihn nur lokal zum Abgleich mit Ihren aktiven Aufgaben.';

  @override
  String get yourManager => 'Ihr Verwalter';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Ihre Mattermost-Site-URL, falls Sie die REST API verwenden.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Ihre Sitzung ist abgelaufen oder wurde vom Browser nicht behalten. Bitte melden Sie sich erneut an.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.';

  @override
  String get yourSubscriptionWillRemainActiveUntil =>
      'Ihr Abonnement bleibt bis zum Ende der Abrechnungsperiode aktiv.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Ihr Benutzername oder Passwort ist falsch.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Überblick';

  @override
  String get sectionDiagnostics => 'Diagnose';

  @override
  String get sectionVolume => 'Lautstärke';

  @override
  String get sectionSession => 'Sitzung';

  @override
  String get sectionDeliverable => 'Ergebnis';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Die lokale Laufzeitumgebung hat noch keine Protokolldatei geschrieben.';

  @override
  String get thisComputer => 'Dieser Computer';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta installiert das neueste Vorab-Backend. Rechnen Sie mit Ecken und Kanten.';

  @override
  String get copiedFinalResponse => 'Abschließende Antwort kopiert';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Die abschließende Antwort erscheint hier, wenn der Lauf beendet ist.';

  @override
  String get waitingForTheFirstStep => 'Warten auf den ersten Schritt…';

  @override
  String get loadingPrompt => 'Prompt wird geladen…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Für diesen Lauf wurde keine abschließende Antwort erfasst.';

  @override
  String get readyToSignIn => 'Bereit zur Anmeldung';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Wechseln Sie zu „Standard“ oder „Immer nachfragen“, um die Freigabeprüfungen wieder zu aktivieren.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Senden Sie eine Steuerung oder eine Notiz für den aktuellen Lauf…';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Keine Netzwerkverbindung. NeoAgent verbindet sich wieder, sobald das Gerät online ist.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Die letzte Steuerung wurde auf den aktuellen Lauf angewendet.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Die private Sprachsitzung wird vorbereitet…';

  @override
  String get preparingYourComputer => 'Ihr Computer wird vorbereitet';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent lädt das sichere Linux-System herunter und bereitet es vor. Das geschieht nur beim ersten Mal.';

  @override
  String get moreFreeSpaceIsNeeded => 'Mehr freier Speicherplatz wird benötigt';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Geben Sie Speicherplatz auf dem NeoAgent-Host frei und versuchen Sie es erneut. Ihre vorhandenen Computerdaten bleiben erhalten.';

  @override
  String get androidReady => 'Android bereit';

  @override
  String get startingAndroid2 => 'Android wird gestartet…';

  @override
  String get androidStopped => 'Android angehalten';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Der erste Start lädt das Android-SDK und das Systemabbild herunter. Das kann einige Minuten dauern.';

  @override
  String get androidIsStopped => 'Android ist angehalten';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Starten Sie die verwaltete Android-Umgebung, wenn Sie sie benötigen.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'NeoAgent auf diesem Computer arbeiten lassen';

  @override
  String get firstTimeSetupIsInProgress => 'Die Ersteinrichtung läuft.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent kann den Zugriff nutzen, den Sie erlauben.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Geben Sie Speicherplatz auf dem Host frei und versuchen Sie es erneut.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Starten Sie, wenn NeoAgent hier helfen soll.';

  @override
  String get systemPermissionMissing => 'Systemberechtigung fehlt';

  @override
  String get connectingThisDevice => 'Dieses Gerät wird verbunden';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Die sichere lokale Verbindung wird aufgebaut.';

  @override
  String get recordingYourDemonstration => 'Ihre Vorführung wird aufgezeichnet';

  @override
  String get noErrorsInTheRecentLog => 'Keine Fehler im letzten Protokoll.';

  @override
  String get loadingAccounts => 'Konten werden geladen…';

  @override
  String get neverSignedIn => 'Noch nie angemeldet';

  @override
  String get emptyUsesTheServerDefault => 'Leer verwendet den Serverstandard.';

  @override
  String get followTheSelectedSession => 'Der ausgewählten Sitzung folgen';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Der Planmodus prüft nur. Wechseln Sie in den Agentenmodus, damit NeoAgent Dateien bearbeiten kann.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Erforderlich, um die E-Mail-Adresse Ihres Kontos hinzuzufügen oder zu ändern.';

  @override
  String get confirmNewPassword => 'Neues Passwort bestätigen';

  @override
  String get passwordChanged => 'Passwort geändert.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Diese Anfrage wurde bereits verwendet.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Diese Anfrage ist abgelaufen. Bitten Sie das andere Gerät, einen neuen Code zu erzeugen.';

  @override
  String get startQuickstart => 'Schnellstart beginnen';

  @override
  String get createYourAccount => 'Konto erstellen';

  @override
  String get showWorkAsSummaries => 'Arbeit als Zusammenfassungen anzeigen';

  @override
  String get tokensUsedByTheLatestRun => 'Tokens des letzten Laufs';

  @override
  String get listedTheWorkspaceRoot => 'Wurzel des Arbeitsbereichs aufgelistet';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Noch keine offiziellen Integrationen verfügbar.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Noch keine MCP-Server konfiguriert. Fügen Sie einen hinzu, um seine Werkzeuge bereitzustellen.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Fügen Sie einen MCP-Server hinzu oder installieren Sie eine Fähigkeit, um zu beginnen.';

  @override
  String get setUp => 'Einrichten';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Leer lassen, um den gespeicherten Wert zu behalten';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Dadurch wird die Adresse für jedes Konto auf diesem Server entfernt.';

  @override
  String get allModels => 'Alle Modelle';

  @override
  String get optionalAndPermanentBlankGeneratesOne =>
      'Optional und dauerhaft. Leer erzeugt einen.';

  @override
  String get noSubscriptionsYet => 'Noch keine Abonnements.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Sprechen Sie einfach. Sie können jederzeit unterbrechen. Tippen Sie zum Stummschalten.';

  @override
  String get tapAgainWhenYouAreDone =>
      'Tippen Sie erneut, wenn Sie fertig sind.';

  @override
  String get workingOnATaskInTheBackground =>
      'Eine Aufgabe wird im Hintergrund bearbeitet.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Sprache zu Sprache mit demselben Gedächtnis, denselben Werkzeugen und demselben Chatverlauf wie NeoAgent.';

  @override
  String get checkLink => 'Link prüfen';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Ihr Agent erhält keines der gesteuerten Werkzeuge.';

  @override
  String get notYoursToChange => 'Nicht von Ihnen änderbar';

  @override
  String get setByYou => 'Von Ihnen festgelegt';

  @override
  String get noTools => 'Keine Werkzeuge';

  @override
  String get untitledLink => 'Unbenannter Link';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Verliert die Gültigkeit, sobald eine Person den Link einlöst.';

  @override
  String get theOperator => 'Die Bedienperson';

  @override
  String get getStarted => 'Loslegen';

  @override
  String get smartSelectorOn => 'Smart Selector an';

  @override
  String get startASessionToBegin => 'Starten Sie eine Sitzung, um zu beginnen';

  @override
  String get steerTheActiveRun => 'Aktiven Lauf steuern…';

  @override
  String get describeWhatToPlan => 'Beschreiben Sie, was geplant werden soll…';

  @override
  String get stopDictation => 'Diktat beenden';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Nachrichten steuern den aktuellen Lauf · ⌘↵ senden · ⌘. anhalten';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Der Planmodus prüft nur; es ändert sich nichts, bis Sie umsetzen · ⌘↵ senden';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Der Agent bearbeitet den Arbeitsbereich. Der Plan prüft nur.';

  @override
  String get defaultModel => 'Standardmodell';

  @override
  String get openingScanner => 'Scanner wird geöffnet…';

  @override
  String get theAgentCanUseThisSkill =>
      'Der Agent kann diese Fähigkeit verwenden.';

  @override
  String get allSelected => 'Alle ausgewählt';

  @override
  String get addCoreMemoryEntry => 'Gedächtniseintrag hinzufügen';

  @override
  String get channelId => 'Kanal-ID';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Von der KI erstellte und nicht festgelegte Aufgaben verwenden den aktuellen Standard.';

  @override
  String get waitingForRunEvents => 'Warten auf Laufereignisse…';

  @override
  String get hideSteps => 'Schritte ausblenden';

  @override
  String get commitTheActiveLiveCapture => 'Aktive Live-Aufnahme übernehmen';

  @override
  String get stopCaptureAndSubmit => 'Aufnahme beenden und senden';

  @override
  String get clickTheMicToStartSpeaking =>
      'Klicken Sie auf das Mikrofon, um zu sprechen';

  @override
  String get connectACustomEndpoint => 'Eigenen Endpunkt verbinden';

  @override
  String get hostedProvider => 'gehosteten Anbieter.';

  @override
  String get serverToStartIt => 'Server neu, um sie zu starten.';

  @override
  String get muted => ' • stumm';

  @override
  String get addWhoCanMessage => 'Festlegen, wer schreiben darf';

  @override
  String get joinsGroupConversations => 'Nimmt an Gruppengesprächen teil';

  @override
  String get label1PersonOrGroupAdded => '1 Person oder Gruppe hinzugefügt';

  @override
  String get inProgress => 'In Bearbeitung';

  @override
  String get waitingForUpdateJobOutput =>
      'Warten auf die Ausgabe des Update-Auftrags…';

  @override
  String get taskTrigger => 'Aufgabenauslöser';

  @override
  String get bearerToken => 'Bearer-Token';

  @override
  String get bearerToken2 => 'Bearer-Token';

  @override
  String get notRecorded => 'Nicht erfasst';

  @override
  String get sessionCookie => 'Sitzungscookie';

  @override
  String get neverUsed => 'Noch nie verwendet';

  @override
  String get linkedRecently => 'Kürzlich verknüpft';

  @override
  String get notUsedYet => 'Noch nicht verwendet';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Ein oder mehrere Konten sind abgelaufen. Verbinden Sie sie erneut, um den Zugriff wiederherzustellen. Wenn das weiterhin geschieht, befindet sich Ihre Google-Cloud-OAuth-App möglicherweise im Testmodus — veröffentlichen Sie sie in der Google Cloud Console für die Produktion, um langlebige Tokens zu erhalten.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Tresor verbunden und nach einem Neustart verfügbar';

  @override
  String get vaultConnectedForThisSession =>
      'Tresor für diese Sitzung verbunden';

  @override
  String get connectAnotherAccount => 'Weiteres Konto verbinden';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Ersatz für das langlebige Zugriffstoken einfügen';

  @override
  String get updateInstance => 'Instanz aktualisieren';

  @override
  String get pasteAReplacementToken => 'Ersatz-Token einfügen';

  @override
  String get replaceAccount => 'Konto ersetzen';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Kann an jeden empfangenden Agenten delegieren';

  @override
  String get canReceiveDelegatedTasks2 => 'kann delegierte Aufgaben empfangen';

  @override
  String get noSyncYet => 'Noch keine Synchronisierung';

  @override
  String get noNewData => 'Keine neuen Daten';

  @override
  String get syncOnceToSeedYourBackend =>
      'Synchronisieren Sie einmal, um Ihr Backend zu befüllen.';

  @override
  String get lastWindowEndIsUnknown =>
      'Das Ende des letzten Fensters ist unbekannt.';

  @override
  String get lastNonEmptySync => 'Letzte nicht leere Synchronisierung';

  @override
  String get stopTranscribe => 'Stoppen und transkribieren';

  @override
  String get steeringMode => 'Steuerungsmodus';

  @override
  String get noMessageText => 'Kein Nachrichtentext';

  @override
  String get reconnectingToServer =>
      'Verbindung zum Server wird wiederhergestellt…';

  @override
  String get signingIn => 'Anmeldung läuft…';

  @override
  String get noGroupsFoundYet => 'Noch keine Gruppen gefunden';

  @override
  String get onForNewGroupsOnly => 'Nur für neue Gruppen aktiv';

  @override
  String get noGroupsInThisCategory => 'Keine Gruppen in dieser Kategorie';

  @override
  String get groupOrChannel => 'Gruppe oder Kanal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Notizen, die Sie an sich selbst schreiben, starten einen Lauf, und Antworten landen im selben Chat. Die Freigabeliste gilt hier nicht.';

  @override
  String get needToReply => 'Antwort erforderlich';

  @override
  String get enter2faCode => '2FA-Code eingeben';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Öffnen Sie Ihre Authenticator-App und geben Sie den aktuellen NeoAgent-Code ein.';

  @override
  String get alreadyHaveAnAccountSignIn =>
      'Sie haben bereits ein Konto? Anmelden';

  @override
  String get serverOnThisComputer => 'Server auf diesem Computer';

  @override
  String get showQrCode => 'QR-Code anzeigen';

  @override
  String get createAnotherNeoagentAccount =>
      'Weiteres NeoAgent-Konto erstellen.';

  @override
  String get canCoordinateDelegatedWork =>
      'Kann delegierte Arbeit koordinieren';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Das NeoAgent-Laufzeitarchiv konnte nicht entpackt werden.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Das NeoAgent-Laufzeitarchiv konnte nicht gelesen werden.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Das NeoAgent-Laufzeitarchiv enthält einen unsicheren Pfad.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Das NeoAgent-Laufzeitarchiv enthält einen unsicheren Verweis.';

  @override
  String get installingAppPackageOnThePhone =>
      'App-Paket wird auf dem Telefon installiert…';

  @override
  String get dragAndDropAApkOrApks =>
      'Ziehen Sie eine .apk- oder .apks-Datei hierher oder klicken Sie zum Auswählen.';

  @override
  String get releaseToInstallThisPackage =>
      'Loslassen, um dieses Paket zu installieren';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Der Sicherheitsschlüssel konnte nicht verwendet werden.';

  @override
  String get connecting => 'Verbindung wird hergestellt…';

  @override
  String get changes => 'Änderungen';

  @override
  String get runtimeReady => 'Laufzeit bereit';

  @override
  String get saving => 'Wird gespeichert…';

  @override
  String get earlier => 'Früher';

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mär';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Okt';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dez';

  @override
  String get steeringWord => 'Steuerung';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Dadurch wechselt das Backend vom Kanal $arg1 zum Kanal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1 Cookies importiert';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'vor $arg1 Sek.';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Steuerung in der Warteschlange: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Die Web-App konnte das NeoAgent-Backend nicht erreichen.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Der Browser hat eine erforderliche Anfrage wegen der Content Security Policy blockiert.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 von 4 erlaubt';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Arbeiten Sie die Aufgabe so ab, wie Sie es sonst tun.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Änderungen · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Dieses Gerät · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limit erreicht$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Es sind noch $arg1 Wiederherstellungscodes verfügbar.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Sicherheitsschlüssel $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Aktuelle Sitzung';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nZuletzt verwendet: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Arbeitet in $arg1 auf diesem Gerät. NeoAgent liest und bearbeitet den Ordner direkt und kann Befehle ausführen, Apps öffnen und den Bildschirm nutzen.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Gearbeitet für $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Erlaubt von $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 Einladungslinks von $arg2 wurden widerrufen';
  }

  @override
  String trialEndsArg1(Object? arg1) {
    return 'Testphase endet $arg1';
  }

  @override
  String cancelsAtEndOfPeriodArg1(Object? arg1) {
    return 'Endet zum Periodenende · $arg1';
  }

  @override
  String renewsArg1(Object? arg1) {
    return 'Verlängert sich $arg1';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Fügen Sie die Personen und Gruppen hinzu, mit denen $arg1 sprechen soll';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Fügen Sie die Personen und Gruppen hinzu, mit denen $arg1 sprechen darf.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Wo $arg1 zuhört';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 beobachtet diese Orte auf Erwähnungen. Hier kann jeder schreiben, deshalb brauchen Personen darunter weiterhin eine eigene Freigabe.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Diese Personen können $arg1 überall fragen, wo sie es erwähnen. Rollen zählen nur an den oben aufgeführten Orten.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Nur wenn $arg1 erwähnt wird';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Aktiv für alle $arg1 Gruppen';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 hört weiterhin nur Personen und Gruppen, die Sie bereits freigegeben haben. Dadurch nimmt $arg1 dort auch am gewöhnlichen Chat teil, nicht nur an Erwähnungen und Antworten.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 hört weiterhin nur Personen und Gruppen, die Sie bereits freigegeben haben. Hier wählen Sie nur, welchen dieser Gruppen es beitritt.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Wenn jemand $arg1 erwähnt oder antwortet, antwortet $arg1 immer. Schalten Sie dies ein, wenn $arg1 auch im gewöhnlichen Gruppenchat mitreden soll.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Neue Gruppen lassen $arg1 am gewöhnlichen Chat mit freigegebenen Personen teilnehmen, bis Sie sie ausschalten.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Neue Gruppen lassen $arg1 am gewöhnlichen Chat teilnehmen, bis Sie sie ausschalten.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Neue Gruppen bleiben still, bis eine freigegebene Person $arg1 erwähnt oder Sie sie einschalten.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Nur wenn eine freigegebene Person $arg1 erwähnt, außer Sie schalten eine Gruppe ein';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Nur wenn $arg1 erwähnt wird, außer Sie schalten eine Gruppe ein';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 von $arg2 Gruppen nehmen am gewöhnlichen Chat mit freigegebenen Personen teil';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Dadurch werden keine neuen Personen freigegeben. Erwähnungen und Antworten freigegebener Personen erhalten immer eine Antwort. Schalten Sie eine Gruppe ein, wenn $arg1 dort auch am gewöhnlichen Chat teilnehmen soll.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Dadurch werden keine neuen Personen freigegeben. Schalten Sie eine Gruppe ein, wenn $arg1 am gewöhnlichen Chat mit bereits freigegebenen Personen teilnehmen soll.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Erwähnungen und Antworten erhalten immer eine Antwort. Schalten Sie eine Gruppe ein, wenn $arg1 dort auch am gewöhnlichen Chat teilnehmen soll.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 nimmt am gewöhnlichen Chat mit freigegebenen Personen teil';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 kann am gewöhnlichen Chat teilnehmen';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 antwortet nur, wenn eine freigegebene Person es erwähnt';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Es ist nichts Weiteres nötig. Verbinden Sie sich, um $arg1 zu verwenden.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Aktualisiert sich in $arg1 s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Mit $arg1 registrieren';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Keine Erinnerungen mit „$arg1“ verknüpft.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (Standard)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Zweig: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 tritt nur den Gruppen und Kanälen bei, die Sie unten hinzufügen.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 wird benötigt, um die NeoAgent-Laufzeitdaten zu finden.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[gekürzte Vorschau, insgesamt $arg1 Bytes]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[Artefakt begrenzt, insgesamt $arg1 Bytes]...\n';
  }

  @override
  String userArg1(Object? arg1) {
    return 'Benutzer #$arg1';
  }

  @override
  String inArg1(Object? arg1) {
    return ' in $arg1';
  }

  @override
  String get worldNews => 'Weltnachrichten';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Ausführen, wenn neue Weltnachrichten erscheinen. Dein Prompt entscheidet, ob du benachrichtigt wirst.';

  @override
  String get newsKeywordsOptional => 'Stichwörter (optional)';

  @override
  String get worldNewsSetup => 'Weltnachrichten-Einrichtung';

  @override
  String get connectWorldNewsWithGnews =>
      'Füge einen GNews-API-Schlüssel hinzu (kostenloser Tarif auf gnews.io). Er wird verschlüsselt gespeichert und für Weltnachrichten-Trigger zum Abrufen der Top-Schlagzeilen verwendet.';

  @override
  String get gnewsApiKey => 'GNews-API-Schlüssel';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Neuen GNews-API-Schlüssel einfügen';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Leer lassen, um den gespeicherten Schlüssel zu behalten.';

  @override
  String get gnewsApiKeyIsRequired =>
      'Ein GNews-API-Schlüssel ist erforderlich.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Weltnachrichten-Einrichtung konnte nicht gespeichert werden.';

  @override
  String get disconnectWorldNews => 'Weltnachrichten trennen';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Dadurch wird der gespeicherte GNews-API-Schlüssel entfernt. Weltnachrichten-Trigger werden nicht mehr ausgelöst, bis du wieder einen Schlüssel hinzufügst.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Weltnachrichten konnten nicht getrennt werden.';

  @override
  String get systemOneModels => 'SystemOne-Modelle';

  @override
  String get systemOneAuto => 'Automatisch';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Wählt das beste verfügbare SystemOne-Modell';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Das Chat-Modell trifft diese Entscheidungen';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Entscheidungsmodelle, die die Hintergrundaufrufe in einem Bruchteil einer Sekunde erledigen: wann in Gruppenchats geantwortet wird und Browserschritte. Ihr Chat-Modell schreibt weiterhin jede Antwort.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Das SystemOne-Modell entscheidet, wann gesprochen wird, solange es aktiv ist; dieses Modell ist die Ausweichlösung.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 von SystemOne bewertet';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne hat diese Nachricht direkt bewertet. Es wurde kein Sprachmodell ausgeführt.';

  @override
  String get systemOneUnavailable => 'SystemOne nicht verfügbar';

  @override
  String get systemOneAdminAvailability =>
      'Entscheidungsmodelle, die Agenten unter Einstellungen › Modelle auswählen können. Ein hier deaktiviertes Modell verschwindet aus dieser Auswahl, und Agenten, die es gewählt hatten, nutzen Automatisch. Solange ein Modell deaktiviert ist, starten später von Anbietern hinzugefügte SystemOne-Modelle ebenfalls deaktiviert.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Noch keine SystemOne-Modelle. Fügen Sie unter Anbieter einen TypeSafe- oder OpenRouter-Schlüssel hinzu oder laden Sie in Ollama 0.35 oder neuer ein Entscheidungsmodell wie nimble.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Noch ist kein SystemOne-Modell verfügbar. Fügen Sie unter Einstellungen › Modelle › Eigenen Schlüssel verwenden einen TypeSafe- oder OpenRouter-Schlüssel hinzu oder laden Sie in Ollama ein Entscheidungsmodell wie nimble.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one entscheidung modelle jev typesafe openrouter ollama verfügbarkeit aktivieren deaktivieren';

  @override
  String get chatModels => 'Chat-Modelle';

  @override
  String get disabled => 'Deaktiviert';

  @override
  String get enableShown => 'Angezeigte aktivieren';

  @override
  String get disableShown => 'Angezeigte deaktivieren';

  @override
  String get expandAll => 'Alle ausklappen';

  @override
  String get collapseAll => 'Alle einklappen';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 ungespeicherte Änderungen';
  }

  @override
  String get settingsScopeAllAgents => 'Alle Agenten';

  @override
  String get settingsScopeAgent => 'Dieser Agent';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint =>
      'Überall gleich, wo Sie angemeldet sind';

  @override
  String get settingsScopeAllAgentsHint => 'Gilt für alle Ihre Agenten';

  @override
  String get settingsAppliesTo => 'Gilt für';

  @override
  String get settingsSaving => 'Wird gespeichert …';

  @override
  String get settingsSavedAutomatically =>
      'Änderungen werden automatisch gespeichert';

  @override
  String get settingsSearchHint => 'Alle Einstellungen durchsuchen';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Anmeldung & Sicherheit';

  @override
  String get settingsPageUsage => 'Tarif & Nutzung';

  @override
  String get settingsPagePermissions => 'Berechtigungen';

  @override
  String get settingsPageComputer => 'Computer & Web';

  @override
  String get settingsPageBehavior => 'Verhalten';

  @override
  String get settingsPageSystem => 'System';

  @override
  String get settingsPageProfileDescription =>
      'Ihr Name und Ihre E-Mail, eine Kopie Ihrer Daten und das Abmelden.';

  @override
  String get settingsPageSecurityDescription =>
      'Passwort, Zwei-Faktor-Authentifizierung, Sicherheitsschlüssel und wo Sie angemeldet sind.';

  @override
  String get settingsPageUsageDescription =>
      'Ihre Limits, Ihr Token-Verbrauch und Ihr Tarif an einem Ort.';

  @override
  String get settingsPageAgentsDescription =>
      'Agenten anlegen und festlegen, welcher standardmäßig antwortet.';

  @override
  String get settingsPagePermissionsDescription =>
      'Was Ihre Agenten tun dürfen, ohne vorher zu fragen.';

  @override
  String get settingsPageComputerDescription =>
      'Der Computer, auf dem Ihre Agenten arbeiten, und die Seiten, die sie in Ihrem Namen lesen können.';

  @override
  String get settingsPageModelsDescription =>
      'Welche Modelle dieser Agent nutzt und mit welchen API-Schlüsseln sie bezahlt werden.';

  @override
  String get settingsPageBehaviorDescription =>
      'Wie dieser Agent spricht und wie er einen Gruppenchat liest.';

  @override
  String get settingsPageVoiceDescription =>
      'Live-Anrufe, Diktat und gesprochene Antworten für diesen Agenten.';

  @override
  String get settingsPageMessagingDescription =>
      'Wo dieser Agent erreichbar ist und wie er sich in Chats verhält.';

  @override
  String get settingsPageGeneralDescription =>
      'Darstellung, Sprache, Zeitzone und was diese App im Hintergrund tut.';

  @override
  String get settingsPageSystemDescription =>
      'Der Server dieses Fensters, der Server auf diesem Computer und App-Updates.';

  @override
  String get settingsYourAgents => 'Ihre Agenten';

  @override
  String get settingsChatModel => 'Chat-Modell';

  @override
  String get settingsChatModelDescription => 'Beantwortet Ihre Nachrichten.';

  @override
  String get settingsSubAgentModel => 'Sub-Agent-Modell';

  @override
  String get settingsSubAgentModelDescription =>
      'Erledigt Arbeit, die während einer Aufgabe abgegeben wird.';

  @override
  String get settingsDefaultModels => 'Standardmodelle';

  @override
  String get settingsDefaultModelsDescription =>
      'Werden verwendet, wenn ein Chat oder eine Aufgabe kein eigenes Modell wählt.';

  @override
  String get settingsSmartSelection => 'Intelligente Auswahl';

  @override
  String get settingsModelPool => 'Modell-Pool';

  @override
  String get settingsApiKeysDescription =>
      'Eigene Schlüssel oder einen eigenen Endpunkt für diesen Agenten nutzen. Schlüssel werden verschlüsselt und nie wieder angezeigt.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Feinabstimmung';

  @override
  String get settingsFineTuningDescription =>
      'Selten nötig. Die Standardwerte passen für die meisten Chats.';

  @override
  String get settingsShow => 'Anzeigen';

  @override
  String get settingsHide => 'Ausblenden';

  @override
  String get settingsMinimumContribution => 'Mindestwert für Beiträge';

  @override
  String get settingsBatchWindow => 'Bündelungsfenster';

  @override
  String get settingsBatchWindowDescription =>
      'Wartet so lange, um schnell aufeinanderfolgende Nachrichten als einen Beitrag zu behandeln.';

  @override
  String get settingsHandsFree => 'Freihändig';

  @override
  String get settingsHandsFreeDescription =>
      'Frei sprechen und jederzeit unterbrechen.';

  @override
  String get settingsPushToTalkDescription =>
      'Zum Sprechen gedrückt halten, zum Senden loslassen.';

  @override
  String get settingsLiveVoice => 'Live-Stimme';

  @override
  String get settingsChannels => 'Kanäle';

  @override
  String get settingsGroupChats => 'In Gruppenchats';

  @override
  String get settingsGroupChatsDescription =>
      'Wie sich dieser Agent in Gruppen auf allen Kanälen verhält.';

  @override
  String get settingsGroupChatsDisabled =>
      'Aktivieren Sie die Verhaltensmodule unter Verhalten, um diese Einstellungen zu ändern.';

  @override
  String get settingsParticipationAutomatic => 'Automatisch';

  @override
  String get settingsParticipationMentionOnly => 'Nur bei Erwähnung';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Liest die Stimmung und meldet sich, wenn es etwas Nützliches beizutragen gibt.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Antwortet nur, wenn er erwähnt oder direkt angesprochen wird.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Antwortet auf jede Nachricht.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Teilt längere Antworten in kurze Nachrichten auf, wie es ein Mensch tun würde.';

  @override
  String get settingsDeliverySingleDescription =>
      'Sendet jede Antwort als eine Nachricht.';

  @override
  String get settingsComputerStatus => 'Status';

  @override
  String get settingsTest => 'Testen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Hell';

  @override
  String get settingsThemeDark => 'Dunkel';

  @override
  String get settingsCloseWindow => 'Beim Schließen des Fensters';

  @override
  String get settingsCloseAsk => 'Fragen';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent läuft im Hintergrund weiter und bleibt erreichbar.';

  @override
  String get settingsCloseQuitDescription =>
      'NeoAgent wird vollständig beendet.';

  @override
  String get settingsPhoneTriggers => 'Auslöser auf dem Telefon';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signale, die dieses Telefon an Ihre Agenten sendet, damit Aufgaben darauf reagieren können.';

  @override
  String get settingsLocationTriggers => 'Standort-Auslöser';

  @override
  String get settingsLocationTriggersDescription =>
      'Prüft alle paar Minuten Ihren ungefähren Standort gegen die Orte, die Ihre Aufgaben beobachten.';

  @override
  String get settingsNotificationTriggers => 'Benachrichtigungs-Auslöser';

  @override
  String get settingsNotificationTriggersDescription =>
      'Leitet Benachrichtigungen anderer Apps auf diesem Telefon an Ihre Agenten weiter.';

  @override
  String get settingsSetup => 'Einrichtung';

  @override
  String get settingsOnboarding => 'Einführung';

  @override
  String get settingsOnboardingDescription =>
      'Die Ersteinrichtung erneut durchlaufen. Nichts von dem, was Sie eingerichtet haben, geht verloren.';

  @override
  String get settingsUsernameDescription =>
      'Wird zur Anmeldung verwendet und kann nicht geändert werden.';

  @override
  String get settingsExport => 'Exportieren';

  @override
  String get settingsLeave => 'Abmelden und löschen';

  @override
  String get settingsSignOutDescription =>
      'Meldet Sie nur auf diesem Gerät ab.';

  @override
  String get settingsDeleteAccountDescription =>
      'Löscht Ihr Konto, Ihre Agenten, Erinnerungen und Einstellungen. Das lässt sich nicht rückgängig machen.';

  @override
  String get settingsTokenUsage => 'Token-Verbrauch';

  @override
  String get settingsAvailablePlans => 'Verfügbare Tarife';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Keine Einstellung passt zu „$query“.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Treffer',
      one: '1 Treffer',
    );
    return '$_temp0';
  }
}
