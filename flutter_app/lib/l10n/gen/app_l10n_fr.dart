// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppL10nFr extends AppL10n {
  AppL10nFr([String locale = 'fr']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Bienvenue';

  @override
  String get onboardingEyebrowCommunication => 'Communication';

  @override
  String get onboardingEyebrowIntelligence => 'Intelligence';

  @override
  String get onboardingEyebrowComputer => 'Ordinateur';

  @override
  String get onboardingEyebrowAutomation => 'Automatisation';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingIntroCouldNotLoad =>
      'L\'intro n\'a pas pu être chargée.';

  @override
  String get onboardingModelDescription =>
      'Choisissez le modèle que NeoAgent doit utiliser par défaut ou laissez-le choisir automatiquement.';

  @override
  String get onboardingLoadingModels => 'Chargement des modèles…';

  @override
  String get noAiModelTitle => 'Aucun modèle d\'IA n\'est encore configuré';

  @override
  String get noAiModelBody =>
      'Ajoutez une clé API d\'un fournisseur tel que OpenAI, Anthropic ou Google. NeoAgent affiche ensuite les modèles que vous pouvez utiliser.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent a besoin d\'un modèle d\'IA pour répondre. Ajoutez une clé API d\'un fournisseur tel que OpenAI, Anthropic ou Google.';

  @override
  String get noAiModelAdminHint =>
      'En tant qu\'administrateur, vous pouvez également configurer des fournisseurs pour tout le monde sous Admin → Fournisseurs.';

  @override
  String get addApiKey => 'Ajouter une clé API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform est connecté.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'En attente de connexion de $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'La configuration n\'a pas pu être enregistrée : $error';
  }

  @override
  String get onboardingEyebrowReady => 'Prêt';

  @override
  String get onboardingStepRequired => 'Obligatoire';

  @override
  String get onboardingStepOptional => 'Facultatif';

  @override
  String get onboardingStepCloudOrLocal => 'Cloud ou local';

  @override
  String get onboardingStepComputer => 'Ordinateur';

  @override
  String get onboardingStepRoutines => 'Routines';

  @override
  String get onboardingComputerChoiceTitle => 'Où doit-il\ntravailler ?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Vous pouvez changer d’ordinateur à chaque session.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Bac à sable privé · toujours actif';

  @override
  String get onboardingThisComputer => 'Cet ordinateur';

  @override
  String get onboardingThisComputerSubtitle =>
      'Vos fichiers, applications et navigateur';

  @override
  String get onboardingSearchApps => 'Rechercher des applications…';

  @override
  String get onboardingRoutinesDescription =>
      'Les résultats arrivent dans vos discussions.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Les résultats arrivent sous forme de notifications.';

  @override
  String get onboardingNotifications => 'Notifications';

  @override
  String get onboardingReadyTitle => 'Tout est\nprêt.';

  @override
  String get onboardingReadyDescription => 'Envoyez votre premier message.';

  @override
  String get onboardingMessageNeoagent => 'Écrire à NeoAgent';

  @override
  String get onboardingAskAnything => 'Demandez n\'importe quoi…';

  @override
  String get onboardingOpenNeoagent => 'Ouvrir NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planifiez un week-end';

  @override
  String get onboardingStarterLanding => 'Créer une page de destination';

  @override
  String onboardingQuickSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes rapides',
      one: '$count étape rapide',
    );
    return '$_temp0';
  }

  @override
  String get taskNeedsEmail => 'Connectez d\'abord l\'e-mail';

  @override
  String get taskNeedsCalendar => 'Connectez d\'abord un calendrier';

  @override
  String get taskNeedsModel => 'Configurez d\'abord un modèle d\'IA';

  @override
  String get taskPromptDailyRecap =>
      'Récapitulez ma journée : résumez les conversations, le travail terminé et les décisions d\'aujourd\'hui, puis énumérez tout ce sur quoi je devrais donner suite demain. Soyez bref et envoyez-le-moi.';

  @override
  String get taskPromptInboxCheck =>
      'Vérifiez ma boîte de réception pour les messages arrivés depuis la dernière vérification. Envoyez-moi uniquement des messages concernant les e-mails urgents ou nécessitant une réponse, avec un résumé d\'une ligne chacun. Si rien ne requiert mon attention, n’envoyez rien.';

  @override
  String get taskPromptMorningBriefing =>
      'Préparez mon briefing du matin : la météo du jour là où je me trouve, les événements de mon calendrier et les points ouverts les plus importants que je connais. Envoyez-le sous forme de message court et numérisable.';

  @override
  String get taskPromptTomorrowPrep =>
      'Regarde mon calendrier pour demain. Pour chaque réunion, dites-moi de quoi il s\'agit, qui est impliqué et tout ce que je dois préparer. Si demain est vide, n’envoyez rien.';

  @override
  String get taskPromptNewsDigest =>
      'Recherchez sur le Web les actualités les plus importantes du jour sur les sujets qui me tiennent à cœur (utilisez ce dont vous vous souvenez concernant mes intérêts). Envoyez-moi un résumé contenant jusqu\'à cinq éléments contenant chacun une phrase et un lien.';

  @override
  String get taskPromptWeeklyReview =>
      'Revoyez ma semaine : ce qui a été fait, ce qui a glissé et ce qui est encore ouvert. Suggérez les trois choses les plus importantes sur lesquelles vous concentrer la semaine prochaine.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Associez un numéro de téléphone appartenant à l\'agent. Toute personne que vous autorisez peut discuter avec lui, dans des discussions directes et des groupes.';

  @override
  String get whatsappSelfChatDescription =>
      'Associez votre propre numéro et parlez à l\'agent dans votre chat « Envoyez-vous un message ». Tous les autres chats et groupes de ce compte sont ignorés.';

  @override
  String get chatSendHintMac => '⌘↵ pour envoyer';

  @override
  String get chatSendHintOther => 'Ctrl+Entrée pour envoyer';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Une URL de base est requise pour ce point de terminaison.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Une adresse e-mail modifiée est confirmée avant d\'être utilisée.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Une décision située plus haut dans la chaîne l’emporte.';

  @override
  String get aDeletedAccount => 'un compte supprimé';

  @override
  String get aFridayLookBackAtThe =>
      'Un vendredi, retour sur la semaine et plan pour la suivante.';

  @override
  String get aKeyThatAsksForA =>
      'Une clé qui demande un code PIN ou une empreinte digitale remplace également votre code à deux facteurs.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Un modèle de langage a jugé ce message car SystemOne est désactivé.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Un fichier de métadonnées d\'installation de NeoAgent a dépassé sa taille limite de sécurité.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Une version Web plus récente est disponible sur le serveur. Rechargez pour récupérer le dernier bundle.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Un bureau privé avec Chromium, des fichiers, un éditeur de texte, un terminal et Python. Votre travail reste enregistré entre les sessions.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Un ordinateur Linux privé ou un appareil Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Un fichier d\'installation NeoAgent requis n\'a pas pu être téléchargé.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Un coéquipier vous envoie un lien d\'invitation. Une fois que vous l\'acceptez, ils ';

  @override
  String get aTeammateSentYouAnInvite =>
      'un coéquipier vous a envoyé un lien d\'invitation, saisissez-le ici pour rejoindre son équipe.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Un téléchargement temporaire sera nettoyé plus tard.';

  @override
  String get aValueIsStored => 'Une valeur est stockée.';

  @override
  String get access => 'Accès';

  @override
  String get accessActivity => 'Activité d\'accès';

  @override
  String accessArg1(Object? arg1) {
    return 'Accès : $arg1';
  }

  @override
  String get accessMode => 'Mode d\'accès';

  @override
  String get accessPermissions => 'Autorisations d\'accès';

  @override
  String get accessToken => 'jeton d\'accès';

  @override
  String get accessToken2 => 'Jeton d\'accès';

  @override
  String get account => 'Compte';

  @override
  String accountArg1(Object? arg1) {
    return 'Compte #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Alertes de changement de compte';

  @override
  String get accountEmail => 'E-mail du compte';

  @override
  String get accountEmailIsOffUntilThese =>
      'L\'e-mail du compte est désactivé jusqu\'à ce que ceux-ci soient définis : ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent utilise cette langue dans toute l’application. Lors de votre première connexion, la langue de cet appareil est utilisée. Votre choix est ensuite enregistré dans votre compte et utilisé sur tous vos appareils.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Impossible de changer la langue : $error';
  }

  @override
  String get accountLanguageTitle => 'Langue';

  @override
  String get accountNumber => 'Numéro de compte';

  @override
  String get accountSettings => 'Paramètres du compte';

  @override
  String get accounts => 'Comptes';

  @override
  String get accountsByTokensUsedAllTime =>
      'Comptes par jetons utilisés, à tout moment.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'ordinateurs cloud des comptes. Les modifications s\'appliquent après un serveur ';

  @override
  String get accountsOnThisServer => 'Comptes sur ce serveur';

  @override
  String get active => 'Actif';

  @override
  String get activeSessions => 'Séances actives';

  @override
  String get activeToday => 'Actif aujourd\'hui';

  @override
  String get add => 'Ajouter';

  @override
  String get addAProviderCredentialFirstIts =>
      'Ajoutez d’abord les informations d’identification du fournisseur. Ses modèles apparaissent ici une fois ';

  @override
  String get addAgent => 'Ajouter un agent';

  @override
  String get addAnotherSignInMethodBefore =>
      'Ajoutez une autre méthode de connexion avant de supprimer celle-ci.';

  @override
  String get addBinding => 'Ajouter une liaison';

  @override
  String get addByNameOrId => 'Ajouter par nom ou identifiant';

  @override
  String get addByNameOrIdInstead => 'Ajoutez plutôt par nom ou ID';

  @override
  String get addCredentialBinding =>
      'Ajouter une liaison d\'informations d\'identification';

  @override
  String get addEntry => 'Ajouter une entrée';

  @override
  String get addKey => 'Ajouter une clé';

  @override
  String get addMcpServer => 'Ajouter un serveur MCP';

  @override
  String get addMemory => 'Ajouter de la mémoire';

  @override
  String get memoryReview => 'Réviser';

  @override
  String get memoryReviewPrompt =>
      'Passe en revue tous mes souvenirs et fais le ménage : archive les doublons, les faits obsolètes et tout ce qui n\'a pas de valeur durable. Dis-moi ensuite brièvement ce que tu as modifié.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Ajoutez plus de longueur ou un autre type de caractère.';

  @override
  String get addPeopleOrGroups => 'Ajouter des personnes ou des groupes';

  @override
  String get addSecurityKey => 'Ajouter une clé de sécurité';

  @override
  String get addSomeoneOrAGroup => 'Ajouter quelqu\'un ou un groupe';

  @override
  String get addTask => 'Ajouter une tâche';

  @override
  String get addTests => 'Ajouter des tests';

  @override
  String get addTestsForThePartsOf =>
      'Ajoutez des tests pour les parties de ce projet qui ont le moins de couverture, puis exécutez-les.';

  @override
  String get addTheirOwnKeysInSettings =>
      'ajouter leurs propres clés dans Paramètres.';

  @override
  String get addToPrompt => 'Ajouter à l\'invite';

  @override
  String get added => 'Ajouté';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Ajouté $arg1 · Dernière utilisation $arg2';
  }

  @override
  String get addressWithTheProvider => 'adresse chez le fournisseur.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Ajustez le volume du haut-parleur, vérifiez les paramètres par défaut des boutons matériels et gérez cette session de lancement.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Ajustez le filtre de recherche ou d\'état pour voir plus de canaux de messagerie.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Réglez ici le volume du haut-parleur.';

  @override
  String get admin => 'Administrateur';

  @override
  String adminArg1(Object? arg1) {
    return 'Administrateur › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Les subventions d\'administrateur, les liens d\'invitation et les changements de gestion s\'affichent ici.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Planification manuelle avancée pour les cas particuliers.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avancé : minute heure jour mois jour de la semaine.';

  @override
  String get againRightAway => 'encore une fois tout de suite.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent : $arg1';
  }

  @override
  String get agentCalls => 'Appels d\'agent';

  @override
  String get agentCommunication => 'Communication des agents';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Communication des agents : $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Le mode Agent édite l\'espace de travail · ⌘↵ envoyer · ⌘N nouvelle session';

  @override
  String get agentPausesAndAsksYouBefore =>
      'L’agent s’arrête et vous demande votre accord avant de lancer l’exécution.';

  @override
  String get agentProfile => 'Profil d\'agent';

  @override
  String get agentVisibleName => 'Nom visible par l\'agent';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'L\'agent souhaite utiliser $arg1. Appuyez pour décider.';
  }

  @override
  String get agents => 'Agents';

  @override
  String get aiAnswerUnreadable => 'Réponse de l\'IA illisible';

  @override
  String get aiProviderKeys => 'Clés du fournisseur d\'IA';

  @override
  String get aiUnavailable => 'IA indisponible';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'alertes et autres e-mails de compte provenant de.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Alertes lorsqu\'une connexion de messagerie nécessite l\'attention de l\'utilisateur';

  @override
  String get all => 'Tout';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Tous les agents ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Tous les $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Tous les emplacements pour ordinateurs cloud sont actuellement utilisés. Réessayez dans un instant.';

  @override
  String get allComputerSlotsAreBusy =>
      'Tous les emplacements d\'ordinateur sont occupés';

  @override
  String get allTables => 'Tous les tableaux';

  @override
  String get allTime => 'Tout le temps';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Tous les outils sont autorisés : l’agent peut utiliser n’importe quelle fonctionnalité sans le demander. ';

  @override
  String get allow => 'Autoriser';

  @override
  String get allowedRunsWithoutAsking => 'Autorisé. Fonctionne sans demander.';

  @override
  String get allowAll => 'Autoriser tout';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Autorisez « Installer des applications inconnues » pour NeoAgent, puis réessayez la mise à jour.';

  @override
  String get allowOnce => 'Autoriser une fois';

  @override
  String get allowSender => 'Autoriser l\'expéditeur';

  @override
  String get allowSession => 'Autoriser la session';

  @override
  String get allowTheAgentToStartAn =>
      'Autorisez l\'agent à démarrer un appel vocal dans l\'application avec vous.';

  @override
  String get allowedOrigins => 'Origines autorisées';

  @override
  String get allowedPathPrefix => 'Préfixe de chemin autorisé';

  @override
  String get allowsYouCanChangeThatPer =>
      'permet. Vous pourrez modifier cela par personne plus tard. Les liens ne s\'accordent jamais ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'appartient déjà à un compte existant';

  @override
  String get alreadyLinkedToAnotherAccount => 'déjà lié à un autre compte';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'déjà lié à un autre compte neoagent';

  @override
  String get alreadyUsed => 'déjà utilisé';

  @override
  String get always => 'Toujours';

  @override
  String get alwaysAllow => 'Toujours autoriser';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '« Toujours autoriser » enregistre la stratégie de manière permanente : vous pouvez la modifier dans les paramètres.';

  @override
  String get alwaysAsk => 'Demandez toujours';

  @override
  String get alwaysEngage => 'Toujours s\'engager';

  @override
  String get alwaysJoins => 'Rejoint toujours';

  @override
  String get anApiKeyIsRequired => 'Une clé API est requise.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Un résumé en soirée de ce qui s\'est passé et des suites à donner.';

  @override
  String get anHttpOrHttpsUrlIs => 'Une URL http ou https est requise.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'et analyses. Liens d\'équipe en direct sur la page Équipe.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'L’installation de l’APK Android n’est pas disponible sur cette plateforme.';

  @override
  String get androidApp => 'Application Android';

  @override
  String get androidControl => 'Contrôle Android';

  @override
  String get androidCouldNotStart => 'Android n\'a pas pu démarrer';

  @override
  String get androidNotificationReceived => 'Notification Android reçue';

  @override
  String get androidOnly => 'Android uniquement';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Le programme d\'installation du package Android n\'a pas pu être ouvert.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Écran Android : appuyez pour toucher, faites glisser pour faire glisser';

  @override
  String get androidSdk => 'SDK Android';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Répond aux @mentions sur les problèmes et les demandes d\'extraction';

  @override
  String get anyone => 'N\'importe qui';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'N\'importe qui sur cette plateforme peut envoyer un message à $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'N\'importe qui sur cette plateforme peut envoyer un message à $arg1 dans $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Toute personne pouvant accéder à ce compte peut parler à $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Toute personne disposant du lien peut s\'inscrire jusqu\'à son expiration ou jusqu\'à ce que vous le révoquiez.';

  @override
  String get apiHttpsOrigin => 'Origine HTTPS de l\'API';

  @override
  String get apiKey => 'Clé API';

  @override
  String get apiKey2 => 'clé API';

  @override
  String get apiKey3 => 'Clé API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'clé api anthropique claude openai gpt xai grok google gemini minimax nvidia nim informations d\'identification openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Clés API et points de terminaison pour les fournisseurs d\'IA, de recherche et de voix. Ils ';

  @override
  String get apiRequest => 'Requête API';

  @override
  String get apiYourOwnServerASelf =>
      'API : votre propre serveur, un modèle auto-hébergé ou un autre ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Le téléchargement de l\'APK a échoué avec HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Le nom de l\'application est requis.';

  @override
  String get appUpdates => 'Mises à jour de l\'application';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Les mises à jour des applications ne sont pas configurées pour cette version.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Application des mises à jour de pilotage en file d\'attente $arg1 à l\'exécution en cours.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Mise à jour(s) de la direction $arg1 appliquée(s).';
  }

  @override
  String get apply => 'Postuler';

  @override
  String get applyBehaviorNotes => 'Appliquer des notes de comportement';

  @override
  String get applyCoreMemory => 'Appliquer la mémoire principale';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Demandes d\'approbation pour les outils d\'agent sensibles';

  @override
  String get approvalRequired => 'Approbation requise';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'L\'approbation reste dans votre session mobile authentifiée et chaque code expire automatiquement après une courte fenêtre.';

  @override
  String get approveLogin => 'Approuver la connexion';

  @override
  String get approveQrLogin => 'Approuver la connexion QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Approuvez ceci uniquement si vous venez de démarrer la connexion sur cet appareil.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Connexion approuvée pour $arg1.';
  }

  @override
  String get approvedOnly => 'Approuvé uniquement';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Appairage approuvé pour $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Personnes et groupes approuvés';

  @override
  String get approvedPeopleOnly => 'Personnes autorisées uniquement';

  @override
  String get archive => 'Archiver';

  @override
  String get archiveAgent => 'Agent d\'archives ?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archiver ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archiver $arg1 $arg2 ?';
  }

  @override
  String get archiveSelectedMemories => 'Archiver les souvenirs sélectionnés ?';

  @override
  String get areSharedByEveryAccountOn =>
      'sont partagés par tous les comptes de ce serveur ; les comptes peuvent toujours ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1 M d\'entrée';
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
    return 'Accès $arg1 requis';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Comptes $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 actif';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 ajouté. Modifiez-le à tout moment pour changer le ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '« $arg1 » et son historique d\'exécution seront définitivement supprimés. Toute exécution active sera arrêtée. Les fichiers de l\'espace de travail ne sont pas touchés.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Approbation $arg1 requise';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Applications $arg1 actives';
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
    return '$arg1 : $arg2';
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
    return '$arg1 (outils actifs $arg2)';
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
    return '$arg1 $arg2 et $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 modifié';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · Caractères $arg2';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Créé $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [uri local : $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 correspondant à « $arg3 »';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}Espace de travail NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\nNouveaux comptes $arg2';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 fonctionne · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · Échantillons $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · Direction $arg2 en file d\'attente';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nJetons $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Jetons $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 à $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 est devenu administrateur ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 octets';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Canal $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return 'Caractères $arg1';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 effacé.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 configuré';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 connecté. Choisissez les référentiels et les personnes sous Qui peut envoyer des messages.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Entrées principales $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 a créé un lien d\'invitation';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Bureau $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Événements $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · Échec du $arg1';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return 'Échec du $arg1';
  }

  @override
  String arg1Failing(Object? arg1) {
    return 'Échec de $arg1';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 pour $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 FR';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Groupes $arg1 balisés uniquement';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'Il y a ${arg1}h';
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
    return 'Aides $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(taux de réussite $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 est un administrateur, le compte ne peut donc pas être supprimé ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 est bloqué sur $arg2. Mettez à jour la liste d\'accès pour autoriser les réponses.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 est connecté et répond.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 n\'est plus un administrateur ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 n\'est pas disponible sur $arg2 (autorisation d\'exécution ou dépendance manquante).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 rejoint sous $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 jugé par LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 Ko';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Clé $arg1$arg2 configurée';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Clé $arg1 supprimée.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 gauche';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 gauche $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 lié';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Il y a ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Assurez-vous qu\'il est en cours d\'exécution, puis réessayez.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 gère ce compte';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 min.';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 min $arg2 sec';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Modèles $arg1 prêts';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 plus';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 étapes supplémentaires dans l\'historique des exécutions';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 déplacé de $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 doit être un nombre fini.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 doit être une adresse http:// ou https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 a besoin d\'attention';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Espace de travail $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return 'Nouveaux comptes $arg1 dans le dernier $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · de nouveaux messages guident cette course';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nouvelles courses';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 gère désormais ce compte.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 sur 4 autorisations autorisées. Les fichiers sont limités à votre dossier NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 ou $arg2 activé';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return 'Les groupes $arg1 des groupes $arg2 rejoignent le chat ordinaire';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return 'Modèles $arg1 ou $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return 'Modèles $arg1 ou $arg2 prêts';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return 'Ensemble $arg1 de $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Outils $arg1 ou $arg2 autorisés';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1 : OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 le jour $arg2 à $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 répond uniquement aux personnes que vous ajoutez ci-dessous.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 ne répond que lorsqu\'il est tagué';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 ne parle qu\'aux personnes et aux groupes que vous approuvez';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Personnes ou groupes $arg1 ajoutés';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Planification $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Fournisseurs $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 prêt';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Enregistrements $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI de redirection $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 enregistré';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 a répondu';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 a révoqué un lien d\'invitation';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 fonctionne';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 fonctionne · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 s\'exécute dans le dernier $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 enregistré.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sec';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 sélectionné';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 illustré';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 est resté silencieux';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return 'Direction $arg1 $arg2 en file d\'attente';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · appuyez sur un nœud pour inspecter';
  }

  @override
  String arg1Steps(Object? arg1) {
    return 'Étapes $arg1';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 a arrêté de gérer $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Jetons $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Jetons $arg1 dans le dernier $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Outils $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (remplacement enregistré indisponible)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% utilisé · $arg2 restant';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 veut parler avec vous.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'Web $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" sera supprimé définitivement.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 gérera ce compte';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 ne répondra pas sur cette plateforme';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 ne répondra pas à $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Stockage des artefacts par utilisateur';

  @override
  String get askAQuestionOrStartA =>
      'Posez une question ou démarrez une tâche...';

  @override
  String get askBeforeClosingToBackground =>
      'Demander avant de passer à l\'arrière-plan';

  @override
  String get askMe => 'Demandez-moi';

  @override
  String get assignedAgent => 'Agent assigné';

  @override
  String get assignedAgent2 => 'Agent assigné';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Agent désigné : $arg1';
  }

  @override
  String get assigneeOptional => 'Destinataire (facultatif)';

  @override
  String get assistant => 'Assistante';

  @override
  String get assistantKey131 => 'Clé assistante 131';

  @override
  String get atLeast1 => 'Au moins 1.';

  @override
  String get attachFiles => 'Joindre des fichiers';

  @override
  String attentionArg1(Object? arg1) {
    return 'Attention $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'journal d\'audit administrateur accorder révoquer l\'invitation historique de l\'équipe';

  @override
  String get authMethod => 'Méthode d\'authentification';

  @override
  String get authServerUrl => 'URL du serveur d\'authentification';

  @override
  String get authentication => 'Authentification';

  @override
  String get authenticationFailed => 'L\'authentification a échoué.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'L’authentification est toujours en attente. Terminez la procédure dans le navigateur, puis réessayez.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'L’authentification est toujours en attente. Terminez la procédure dans le navigateur, puis actualisez.';

  @override
  String get authenticationTimedOut => 'L\'authentification a expiré.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'L\'authentification a été annulée avant la fin.';

  @override
  String get authenticatorApp => 'Application d\'authentification';

  @override
  String get authenticatorCode => 'Code d\'authentification';

  @override
  String get authorOptional => 'Auteur (facultatif)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (premier fournisseur avec une clé API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Itinéraires automatiques vers le meilleur modèle disponible';

  @override
  String get automaticFast => 'Automatique (rapide)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatique lit la pièce et retient normalement. La mention uniquement ne prend aucune décision jusqu\'à ce qu\'elle soit directement adressée.';

  @override
  String get automaticReserved => 'Automatique, réservé';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'La restauration automatique nécessite une nouvelle tentative à partir de l\'écran de configuration.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatique sélectionne un modèle rapide via le catalogue de modèles normal.';

  @override
  String get automation => 'Automatisation';

  @override
  String get available => 'Disponible';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'De nouveau disponible en $arg1';
  }

  @override
  String get availableAgainShortly => 'De nouveau disponible sous peu';

  @override
  String get availableInTheDesktopAppFor =>
      'Disponible dans l\'application de bureau pour macOS, Windows et Linux';

  @override
  String get availableToTheAgent => 'Disponible pour l\'agent';

  @override
  String get averageAllTime => 'Moyenne, tout le temps';

  @override
  String get avgImp => 'Diablotin moyen.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Moyenne/exécution : jetons $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Évitez les caractères répétés et les séquences évidentes.';

  @override
  String get awaitingScan => 'En attente d\'analyse';

  @override
  String get back => 'Retour';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count en arrière-plan';
  }

  @override
  String get backgroundTasks => 'Tâches en arrière-plan';

  @override
  String get backOn => 'de retour.';

  @override
  String get backToChat => 'Retour au chat';

  @override
  String get backToFolder => 'Retour au dossier';

  @override
  String get backToSignIn => 'Retour pour vous connecter';

  @override
  String get backendChannel => 'Canal back-end';

  @override
  String get backendOnThisComputer => 'Backend sur cet ordinateur';

  @override
  String get backendSync => 'Synchronisation back-end';

  @override
  String get backgroundLocationNeeded => 'Emplacement d\'arrière-plan requis';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'La synchronisation en arrière-plan reste programmée sur Android';

  @override
  String get badState => 'Mauvais état : ';

  @override
  String get baseImageAndSizeOfThe =>
      'Image de base et taille des machines virtuelles QEMU qui s\'exécutent ';

  @override
  String get baseUrlOptional => 'URL de base (facultatif)';

  @override
  String get baseUrlTokenLocal => 'jeton d\'URL de base local';

  @override
  String get basicAuthentication => 'Authentification de base';

  @override
  String get behaviorModules => 'Modules de comportement';

  @override
  String get behaviorNotes => 'notes de comportement';

  @override
  String get beta => 'Bêta';

  @override
  String get bitwardenCredentialBroker => 'Courtier d\'accréditation Bitwarden';

  @override
  String get bitwardenItem => 'Article Bitwarden';

  @override
  String get bitwardenServer => 'Serveur Bitwarden';

  @override
  String get blankUsesCommon => 'Le blanc utilise \"commun\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank utilise le rappel par défaut';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Les valeurs vides utilisent les valeurs par défaut du fournisseur.';

  @override
  String get block => 'Bloquer';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Message entrant bloqué de $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Pont compatible BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL du serveur BlueBubbles';

  @override
  String get botToken => 'Jeton de robot';

  @override
  String get botTokenAndApprovedChats =>
      'Jeton de bot et discussions approuvées';

  @override
  String get botTokenAndServerChannelAccess =>
      'Jeton de bot et accès au serveur/canal';

  @override
  String get botTokenEventsApiAndChannel =>
      'Jeton de bot, API d\'événements et accès aux canaux';

  @override
  String get botUserId => 'ID utilisateur du robot';

  @override
  String get botUsername => 'Nom d\'utilisateur du robot';

  @override
  String get brandName => 'Nom de la marque';

  @override
  String get braveSearch => 'Recherche courageuse';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Reliez tout fournisseur capable de publier et de recevoir des charges utiles de webhook.';

  @override
  String get bringYourOwnKey => 'apportez votre propre clé';

  @override
  String get bringYourOwnKey2 => 'Apportez votre propre clé';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Le navigateur, le bureau Linux, les fichiers, le terminal et Python partagent un ordinateur cloud persistant.';

  @override
  String get browserLogin => 'Connexion au navigateur';

  @override
  String get browserScripting => 'Script de navigateur';

  @override
  String get call => 'Appeler';

  @override
  String get callAgent => 'Agent d\'appel';

  @override
  String get callUser => 'Appeler l\'utilisateur';

  @override
  String get calledByName => 'Appelé par son nom';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Peut déléguer des tâches à d\'autres agents';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Peut déléguer à $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Peut recevoir des tâches déléguées';

  @override
  String get cancel => 'Annuler';

  @override
  String get cancelTask => 'Annuler la tâche';

  @override
  String get cannotPreview => 'Impossible de prévisualiser';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ne peut pas recevoir de tâches déléguées';

  @override
  String get cannotRunYet => 'Je ne peux pas encore courir.';

  @override
  String get capturedThePage => 'J\'ai capturé la page';

  @override
  String get category => 'Catégorie';

  @override
  String chainArg1(Object? arg1) {
    return 'Chaîne : $arg1. ';
  }

  @override
  String get changeSetupMode => 'Changer le mode de configuration';

  @override
  String get channel => 'Chaîne';

  @override
  String get channelAccessToken => 'Jeton d\'accès au canal';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Chaîne : $arg1$arg2 | Version mise à jour : $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory =>
      'Mémoire sociale à l\'échelle du canal';

  @override
  String get channels => 'Canaux';

  @override
  String get chat => 'Discussion';

  @override
  String get chatId => 'Identifiant de discussion';

  @override
  String get chatMode => 'Mode discussion';

  @override
  String get chatModel => 'Modèle de discussion';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Vérifier automatiquement au lancement';

  @override
  String get checkForMessagesEveryMs => 'Vérifier les messages toutes les (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Rechercher automatiquement les nouveaux messages';

  @override
  String get checkNow => 'Vérifiez maintenant';

  @override
  String get checkYourEmailToConfirmYour =>
      'Vérifiez votre courrier électronique pour confirmer votre compte NeoAgent avant de vous connecter.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Vérifié $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Choisissez une catégorie ou effectuez une recherche dans tous les paramètres.';

  @override
  String get chooseAPerson => 'Choisissez une personne';

  @override
  String get chooseAProjectFolder => 'Choisissez un dossier de projet';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Choisissez les valeurs par défaut pour le chat, les agents, le comportement de secours et le routage intelligent.';

  @override
  String get chooseGroups => 'Choisissez des groupes';

  @override
  String get chooseHowMuchYouWantTo =>
      'Choisissez combien vous souhaitez configurer maintenant. Les deux options peuvent être modifiées ultérieurement.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Choisissez comment cette tâche doit démarrer. Le manuel s\'exécute uniquement sur Exécuter maintenant. Le calendrier est basé sur le temps. L\'intégration déclenche le feu des applications officielles connectées.';

  @override
  String get chooseOneToGetStartedNow =>
      'Choisissez-en un pour commencer maintenant. Vous pourrez en ajouter d’autres plus tard.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Choisissez le modèle vivant et la voix dans Paramètres.';

  @override
  String get chooseTheirGroup => 'Choisissez leur groupe';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Choisissez où cette personne doit être autorisée à parler à $arg1. Vous pourrez modifier cela ultérieurement sous Qui peut envoyer un message.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Choisissez les groupes que $arg1 doit rejoindre même lorsque personne ne le marque. Cette plate-forme peut ne pas distinguer les balises des messages normaux.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Choisissez quels modèles chaque compte sur ce serveur peut choisir et ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Choisissez à qui $arg1 parle et quand il rejoint les discussions de groupe.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Choisissez qui peut joindre $arg1, puis enregistrez vos modifications.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Choisissez qui peut envoyer un message à l\'agent avec « Qui peut envoyer un message » sur la carte WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Choisissez votre\nmodèle par défaut.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, les fichiers, l\'éditeur de texte et le terminal sont tous disponibles depuis le bureau Linux.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Effacer';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String clearArg1(Object? arg1) {
    return 'Effacer $arg1 ?';
  }

  @override
  String get clearFilter => 'Effacer le filtre';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get clearView => 'Vue dégagée';

  @override
  String get cliSession => 'Session CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'Le clic n\'est pas pris en charge sur cette plateforme.';

  @override
  String get clickOnceToBeginCapturing =>
      'Cliquez une fois pour commencer la capture';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Cliquez, tapez et interagissez avec les applications de bureau.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Cliqué sur ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Cliqué dans le navigateur';

  @override
  String get clientId => 'Identifiant client';

  @override
  String get clientSecret => 'Secret client';

  @override
  String get close => 'Fermer';

  @override
  String get closeJ => 'Fermer (⌘J)';

  @override
  String get closeTeachMode => 'Fermer le mode d\'apprentissage';

  @override
  String get closingTheWindowCanEitherKeep =>
      'La fermeture de la fenêtre peut soit laisser NeoAgent fonctionner en arrière-plan avec accès à la barre d\'état, soit quitter complètement le runtime du bureau.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Les instances cloud et auto-hébergées sont prises en charge. Les URL de réseaux locaux et privés fonctionnent lorsque NeoAgent peut les atteindre.';

  @override
  String get cloudComputer => 'Ordinateur dans le cloud';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Ordinateur en nuage · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Paramètres de l\'ordinateur cloud enregistrés. Redémarrez le serveur pour les appliquer.';

  @override
  String get cloudComputerVm => 'Ordinateur cloud (VM)';

  @override
  String get cloudComputers => 'Ordinateurs cloud';

  @override
  String get codeHosting => 'Hébergement de codes';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Noms de chaînes séparés par des virgules, sans le #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Séparés par des virgules, par exemple #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Virgule séparée. Le problème doit les avoir tous.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Échec de la commande ($arg1) : $arg2';
  }

  @override
  String get commandIsRequired => 'Le commandement est requis.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'L’accumulateur de sortie de commande n’est pas actif.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Échec du téléchargement de la sortie de commande ($arg1) : $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Le téléchargement du résultat de la commande a omis les métadonnées de l\'artefact.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Le résultat de la commande était déjà finalisé.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Commandes et applications';

  @override
  String get commandsRunInTheSamePersistent =>
      'Les commandes s\'exécutent sur le même ordinateur persistant que celui utilisé par le bureau visible.';

  @override
  String get communityChatops => 'Communauté et ChatOps';

  @override
  String get completeSetup => 'Configuration complète';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Terminez le flux de travail sur le bureau.';

  @override
  String get completed => 'Terminé';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Complètement bloqué — l\'agent ne peut pas utiliser cette catégorie.';

  @override
  String get computerShell => 'Coque d\'ordinateur';

  @override
  String get computerUsedByThisSession =>
      'Ordinateur utilisé par cette session';

  @override
  String get computerWorkspace => 'Espace de travail informatique';

  @override
  String get configurablePersonalWebhookBridge =>
      'Pont webhook personnel configurable';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Pont relais ou webhook configurable';

  @override
  String get configurableTalkWebhookBridge => 'Pont webhook Talk configurable';

  @override
  String get configurableWebInboxBridge =>
      'Pont de boîte de réception Web configurable';

  @override
  String get configurableWebhookBridge => 'Pont de webhook configurable';

  @override
  String get configurableWebhooks => 'Webhooks configurables';

  @override
  String get configurationOrInTheEnvFile =>
      'Configuration ou dans le fichier .env.';

  @override
  String get configure => 'Configurer';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configurez le comportement de l\'espace de travail et les valeurs par défaut du modèle.';

  @override
  String configuredArg1(Object? arg1) {
    return '$arg1 configuré';
  }

  @override
  String get confirmEmailChanges =>
      'Confirmer les modifications apportées à l\'e-mail';

  @override
  String get confirmNewSignUps => 'Confirmer les nouvelles inscriptions';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get confirmPassword2 => 'Confirmer le mot de passe';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Confirmez votre e-mail avant de vous connecter. Vérifiez le message e-mail de service de NeoAgent.';

  @override
  String get connect => 'Se connecter';

  @override
  String get connectAMessagingPlatform =>
      'Connectez une plateforme\nde messagerie.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Connectez un point de terminaison HTTPS Home Assistant public avec un jeton d’accès longue durée. Les adresses de réseau local, de bouclage et privé sont bloquées par le serveur.';

  @override
  String get connectAccount => 'Connecter le compte';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Connectez les comptes d\'application individuellement afin que l\'IA puisse utiliser le bon compte pour chaque intégration officielle.';

  @override
  String connectArg1(Object? arg1) {
    return 'Connectez $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Connectez autant de comptes que vous le souhaitez. Chaque application peut utiliser un compte différent.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Connectez les chaînes, choisissez à qui $arg1 parle et regardez l\'activité récente.';
  }

  @override
  String get connectInstance => 'Connecter l\'instance';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Connectez d\'abord cette intégration pour choisir un compte.';

  @override
  String get connectToThisServer => 'Connectez-vous à ce serveur';

  @override
  String get connectWhatsapp => 'Connectez WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Connectez votre instance Nextcloud, y compris les serveurs auto-hébergés. NeoAgent ouvre la propre page de connexion de Nextcloud afin que vous puissiez vous connecter avec un mot de passe, SSO ou 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Connectez votre serveur NeoRecall auto-hébergé. NeoAgent reçoit un accès en lecture seule à la recherche locale, aux souvenirs et aux preuves de transcription après avoir approuvé l\'écran OAuth.';

  @override
  String get connected => 'Connecté';

  @override
  String get connectedAccount => 'Compte connecté';

  @override
  String connectedArg1(Object? arg1) {
    return 'Connecté $arg1';
  }

  @override
  String get connectedInstance => 'Instance connectée';

  @override
  String get connectedNeorecallUser => 'Utilisateur NeoRecall connecté';

  @override
  String get connectedNextcloudUser => 'Utilisateur Nextcloud connecté';

  @override
  String get connectedServer => 'Serveur connecté';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Connexion au modèle vocal en direct...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Connexion #$arg1';
  }

  @override
  String get connectionId => 'ID de connexion';

  @override
  String get connectionLooksGood => 'La connexion semble bonne.';

  @override
  String get connectionMethod => 'Méthode de connexion';

  @override
  String get containsTextOptional => 'Contient du texte (facultatif)';

  @override
  String get content => 'Contenu';

  @override
  String get contentSecurityPolicy => 'politique de sécurité du contenu';

  @override
  String get continue2 => 'Continuer';

  @override
  String get continueFullSetup => 'Continuer la configuration complète';

  @override
  String get continueRun => 'Continuer à courir';

  @override
  String get continueToSetup => 'Continuer la configuration';

  @override
  String get controlSurface => 'SURFACE DE CONTRÔLE';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Contrôle l\'accès aux outils $arg1.';
  }

  @override
  String get conversation => 'Conversation';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID de conversation utilisé lorsque cet agent démarre une conversation.';

  @override
  String get cookieSetup => 'Configuration des cookies';

  @override
  String get cookiesNotConfigured => 'Cookies non configurés';

  @override
  String get copiedAsCsv => 'Copié au format CSV';

  @override
  String get copiedDebugInfo => 'Informations de débogage copiées';

  @override
  String get copiedExportForTheLast5 =>
      'Export copié pour les 5 derniers messages';

  @override
  String get copiedFullPrompt => 'Invite complète copiée';

  @override
  String get copiedLogs => 'Journaux copiés';

  @override
  String get copiedRunId => 'ID d\'exécution copié';

  @override
  String get copy => 'Copier';

  @override
  String get copyAll => 'Copier tout';

  @override
  String get copyCodes => 'Copier les codes';

  @override
  String get copyCsv => 'Copier le fichier CSV';

  @override
  String get copyDebugInfo => 'Copier les informations de débogage';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get copyLogs => 'Copier les journaux';

  @override
  String get copyPrompt => 'Copier l\'invite';

  @override
  String get copyResponse => 'Copier la réponse';

  @override
  String get copyRunId => 'Copier l\'ID d\'exécution';

  @override
  String get copyWebhookUrl => 'Copier l\'URL du webhook';

  @override
  String get core => 'Noyau';

  @override
  String get coreMemory => 'mémoire centrale';

  @override
  String get coreServicesThisServerDependsOn =>
      'Services de base dont dépend ce serveur.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'domaine cors https url publique origines';

  @override
  String get couldHelp => 'Pourrait aider';

  @override
  String get couldNotApproveQrLogin =>
      'Impossible d\'approuver la connexion QR.';

  @override
  String get couldNotApproveQrPairing =>
      'Impossible d\'approuver l\'association QR.';

  @override
  String get couldNotConnect => 'Impossible de se connecter.';

  @override
  String get couldNotCreateBinding => 'Impossible de créer la liaison.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Impossible de supprimer votre compte : $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Impossible de déconnecter Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Impossible de déconnecter Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Impossible de déconnecter NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Impossible de déconnecter Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Impossible de déconnecter Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Impossible d\'exporter vos données : $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Impossible de charger les décisions';

  @override
  String get couldNotLoadUsageData =>
      'Impossible de charger les données d\'utilisation.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Impossible d\'ouvrir automatiquement les paramètres Linux.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Impossible d\'ouvrir la page de liaison du fournisseur.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Impossible d\'ouvrir la page de connexion du fournisseur.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Impossible d\'ouvrir l\'élément de version.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Impossible d\'ouvrir Trello dans votre navigateur.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Impossible d\'ouvrir le téléchargement du fichier de l\'espace de travail.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Impossible de lire le package de l\'application Android.';

  @override
  String get couldNotReadTheApk => 'Impossible de lire l\'APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Impossible de supprimer la clé : $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Impossible d\'enregistrer l\'agent.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Impossible d\'enregistrer la configuration de Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Impossible d\'enregistrer la configuration de Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Impossible d\'enregistrer la configuration de NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Impossible d\'enregistrer la configuration de Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Impossible d\'enregistrer la configuration de Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'impossible d\'envoyer l\'e-mail de confirmation';

  @override
  String get couldNotStart => 'Impossible de démarrer';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Créer';

  @override
  String get createAPasswordFirstToChange =>
      'Créez d\'abord un mot de passe pour modifier l\'e-mail de votre compte.';

  @override
  String get createAPasswordOrLinkAnother =>
      'créez un mot de passe ou associez un autre fournisseur avant de supprimer cette méthode de connexion';

  @override
  String get createATaskWhileThisAgent =>
      'Créez une tâche pendant que cet agent est sélectionné.';

  @override
  String get createLink => 'Créer un lien';

  @override
  String get createOrModifyFilesInYour =>
      'Créez ou modifiez des fichiers dans votre espace de travail.';

  @override
  String get createPassword => 'Créer un mot de passe';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Créez des robots spécialisés avec une mémoire, des paramètres, des outils et des attributions de compte séparés.';

  @override
  String get createTheFirstAccount => 'Créez le premier compte';

  @override
  String get createUpdateOrDeleteSkills =>
      'Créez, mettez à jour ou supprimez des compétences.';

  @override
  String get creatingYourSkill => 'Créer votre compétence…';

  @override
  String get credentialBindings => 'Liaisons d’informations d’identification';

  @override
  String get credentialUse => 'Utilisation des informations d\'identification';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Exécutions récurrentes basées sur Cron et exécution ponctuelle.';

  @override
  String get cronExpression => 'Expression Cron';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Entrée exécute la requête.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Maj + Espace';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Courriel actuel : $arg1';
  }

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get currentPasswordIsIncorrect =>
      'le mot de passe actuel est incorrect';

  @override
  String get currentTwoStepLoginCode =>
      'Code de connexion actuel en deux étapes';

  @override
  String get customAccess => 'Accès personnalisé';

  @override
  String get customCron => 'Cron personnalisé';

  @override
  String get customCronMustHave5Fields =>
      'Le Cron personnalisé doit avoir 5 champs.';

  @override
  String get customEndpoint => 'point de terminaison personnalisé';

  @override
  String get customField => 'Champ personnalisé';

  @override
  String get customHeader => 'En-tête personnalisé';

  @override
  String get customHeadersJson => 'En-têtes personnalisés (JSON)';

  @override
  String get customOpenaiCompatible => 'Compatible OpenAI personnalisé';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Point de terminaison personnalisé compatible OpenAI';

  @override
  String get customOutgoingUrl => 'URL sortante personnalisée';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Quotidiennement';

  @override
  String get dailyRecap => 'Récapitulatif quotidien';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'requête de base de données sélectionner des modèles CSV';

  @override
  String dayArg1(Object? arg1) {
    return 'Jour $arg1';
  }

  @override
  String get dayOfMonth => 'Jour du mois';

  @override
  String get decideWhichToolsYourAgentMay =>
      'décidez quels outils votre agent peut utiliser. Ils voient ton nom et ';

  @override
  String get decisionHigherUpTheChainWins =>
      'décision plus haut dans la chaîne gagne et montre un verrou avec le ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Les décisions apparaissent ici lorsque $arg1 lit les groupes $arg2 approuvés. Seules les 30 dernières sont conservées et elles se réinitialisent au redémarrage du serveur.';
  }

  @override
  String get decline => 'Refuser';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'analyse approfondie · étape $arg1';
  }

  @override
  String get deepgramKey => 'Clé Deepgram';

  @override
  String get default2 => 'Par défaut';

  @override
  String get default3 => 'PAR DÉFAUT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Par défaut ($arg1)';
  }

  @override
  String get defaultConversation => 'Conversation par défaut';

  @override
  String get defaultForNewGroups => 'Par défaut pour les nouveaux groupes';

  @override
  String get defaultGroupParticipation => 'Participation de groupe par défaut';

  @override
  String get defaultNeoagentWorkspace =>
      'Espace de travail NeoAgent par défaut';

  @override
  String get defaultOpenai => 'Par défaut (OpenAI)';

  @override
  String get defaultRateLimits => 'Limites de taux par défaut';

  @override
  String get defaultRateLimitsSaved =>
      'Limites de taux par défaut enregistrées.';

  @override
  String get defaultRecommended => 'Par défaut (recommandé)';

  @override
  String get defaultRouting => 'Routage par défaut';

  @override
  String get defaultSpace => 'Espace par défaut';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountPermanently => 'Supprimer définitivement le compte ?';

  @override
  String get deleteAnAccount => 'Supprimer un compte';

  @override
  String deleteArg1(Object? arg1) {
    return 'Supprimer @$arg1 ?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Supprimer ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Supprimer définitivement $arg1 $arg2 ?';
  }

  @override
  String get deleteBinding => 'Supprimer la liaison';

  @override
  String get deleteCoreMemoryEntry =>
      'Supprimer l\'entrée de la mémoire principale ?';

  @override
  String get deleteForever => 'Supprimer pour toujours';

  @override
  String get deleteMcpServer => 'Supprimer le serveur MCP ?';

  @override
  String get deleteMemory => 'Supprimer la mémoire ?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Supprimer efface définitivement un compte et toutes ses données ';

  @override
  String get deleteRun => 'Supprimer l\'exécution ?';

  @override
  String get deleteRun2 => 'Supprimer l\'exécution';

  @override
  String get deleteSelectedMemories => 'Supprimer les souvenirs sélectionnés ?';

  @override
  String get deleteSession => 'Supprimer la séance ?';

  @override
  String get deleteSkill => 'Supprimer la compétence ?';

  @override
  String get deleteTask => 'Supprimer la tâche ?';

  @override
  String deletedArg1(Object? arg1) {
    return '\"$arg1\" supprimé.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Supprimé @$arg1 et toutes ses données.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'La suppression supprime toutes vos conversations, souvenirs, fichiers, tâches et ';

  @override
  String get deliverableArtifactProduced => 'Artefact livrable produit';

  @override
  String get deliverableCompleted => 'Livrable terminé';

  @override
  String get deliverableExecutionStarted =>
      'L\'exécution du livrable a commencé';

  @override
  String get deliverableSelected => 'Livrable sélectionné';

  @override
  String get deliverableValidationFailed =>
      'Échec de la validation du livrable';

  @override
  String get deliverableValidationStarted => 'Validation du livrable commencée';

  @override
  String get deny => 'Refuser';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Décrivez le résultat, puis démontrez-le sur le bureau';

  @override
  String get describeWhatToBuildOrChange =>
      'Décrivez ce qu’il faut construire ou modifier…';

  @override
  String get description => 'Descriptif';

  @override
  String get desktopApp => 'Application de bureau';

  @override
  String get desktopAppControlsAvailable =>
      'Commandes d\'application de bureau disponibles';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'La capture de bureau n\'est pas disponible sur cette plateforme.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Téléchargement de la sortie de la commande de bureau annulé.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'La commande compagnon de bureau a été annulée.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'La connexion du compagnon de bureau a expiré.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'La négociation avec le compagnon de bureau a expiré.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Le compagnon de bureau n\'est pas disponible ici.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Le compagnon de bureau est mis en pause localement.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Échec de la gestion des messages du compagnon de bureau : $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Les paramètres d\'autorisation du compagnon de bureau ne sont pas disponibles sur le Web.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Les paramètres d\'autorisation du compagnon de bureau ne sont pas disponibles sur cette plate-forme.';

  @override
  String get desktopCompanionRejected => 'Compagnon de bureau rejeté.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Échec de la réponse du compagnon de bureau : $arg1';
  }

  @override
  String get desktopControl => 'Contrôle de bureau';

  @override
  String get desktopFailedToStart => 'Le bureau n\'a pas pu démarrer';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Échec de la capture du flux de bureau : $arg1';
  }

  @override
  String get destinationId => 'ID de destination';

  @override
  String get deviceAccess => 'Accès aux appareils';

  @override
  String get deviceSettings => 'Paramètres de l\'appareil';

  @override
  String get devices => 'Appareils';

  @override
  String get diagnosticsSaved => 'Diagnostic enregistré.';

  @override
  String get directBluebubblesImessageBridge =>
      'Pont iMessage direct BlueBubbles';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Les messages directs restent réactifs. Les groupes sur liste autorisée utilisent le mode de participation ci-dessous.';

  @override
  String get directoryDoesNotExist => 'Le répertoire n\'existe pas.';

  @override
  String get disable2fa => 'Désactiver 2FA';

  @override
  String get disableAll => 'Désactiver tout';

  @override
  String get discard => 'Jeter';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get disconnectHomeAssistant => 'Déconnecter Home Assistant ?';

  @override
  String get disconnectNeorecall => 'Déconnecter NeoRecall ?';

  @override
  String get disconnectNextcloud => 'Déconnecter Nextcloud ?';

  @override
  String get disconnectPlatform => 'Déconnecter la plateforme';

  @override
  String get disconnectTrello => 'Déconnecter Trello ?';

  @override
  String get discoveryFailed => 'Échec de la découverte';

  @override
  String get dismiss => 'Rejeter';

  @override
  String get displayIdIsRequired => 'L’ID d’affichage est requis.';

  @override
  String get displayName => 'Nom d\'affichage';

  @override
  String get displayNameMustBe64Characters =>
      'Le nom d’affichage doit comporter 64 caractères maximum.';

  @override
  String get displayNameSaved => 'Nom d’affichage enregistré.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'N\'incluez pas votre nom d\'utilisateur ou votre adresse e-mail.';

  @override
  String get done => 'Terminé';

  @override
  String get downloadACopyOfYourData =>
      'Téléchargez une copie de vos données. Les comptes administrateur ne peuvent pas être supprimés ';

  @override
  String get downloadACopyOfYourData2 =>
      'Téléchargez une copie de vos données ou supprimez définitivement votre compte. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Télécharger $arg1';
  }

  @override
  String get downloadUpdate => 'Télécharger la mise à jour';

  @override
  String get downloadingTheNeoagentBackend =>
      'Téléchargement du backend NeoAgent';

  @override
  String get draft => 'Brouillon';

  @override
  String get dragIsNotSupportedOnThis =>
      'le glisser n\'est pas pris en charge sur cette plate-forme.';

  @override
  String get draggedOnTheScreen => 'Glissé sur l\'écran';

  @override
  String get dropAnApkOrApkBundle =>
      'Déposez un APK ou un bundle APK ici pour l\'installer';

  @override
  String get dropApkOrApksHere => 'Déposez l’APK ou .apks ici';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Instructions durables pour le style de voix et d\'interaction. Les règles de sécurité et d’exécution restent prioritaires.';

  @override
  String get eGAlexSLaptop => 'par ex. L\'ordinateur portable d\'Alex';

  @override
  String get eGMyLocalServer => 'par ex. Mon serveur local';

  @override
  String get edit => 'Modifier';

  @override
  String get editAgent => 'Modifier l\'agent';

  @override
  String get editCoreMemoryEntry =>
      'Modifier l\'entrée de la mémoire principale';

  @override
  String get editInstructions => 'Modifier les instructions';

  @override
  String get editMcpServer => 'Modifier le serveur MCP';

  @override
  String get editTask => 'Modifier la tâche';

  @override
  String editedArg1(Object? arg1) {
    return 'Modifié $arg1';
  }

  @override
  String get email => 'Courriel';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Envoyez un e-mail aux propriétaires de comptes concernant les connexions qui semblent inhabituelles.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Envoyez un e-mail aux propriétaires de comptes lorsque les détails de leur compte changent.';

  @override
  String get emailCode => 'Code de courrier électronique';

  @override
  String get emailConfirmationRequired => 'confirmation par e-mail requise';

  @override
  String get emailIsAlreadyInUse => 'l\'e-mail est déjà utilisé';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail enregistré. Si une confirmation est requise, vérifiez la nouvelle adresse pour un lien de confirmation NeoAgent.';

  @override
  String get emailSettingsSaved => 'Paramètres de messagerie enregistrés.';

  @override
  String get emailUnverified => 'E-mail non vérifié';

  @override
  String get empty => 'Vide';

  @override
  String get emptyFile => 'Fichier vide';

  @override
  String get emptyFolder => 'Dossier vide';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty utilise la valeur par défaut du serveur ($arg1).';
  }

  @override
  String get enable2fa => 'Activer 2FA';

  @override
  String get enableAll => 'Activer tout';

  @override
  String get enableBehaviorModules => 'Activer les modules de comportement';

  @override
  String get enableOrDisableModels => 'Activer ou désactiver des modèles';

  @override
  String get enabled => 'Activé';

  @override
  String get encryptedPrivateToYourAccount => 'Crypté, privé sur votre compte';

  @override
  String get end => 'Fin';

  @override
  String get endCall => 'Terminer l\'appel';

  @override
  String get endVoiceCall => 'Mettre fin à l\'appel vocal ?';

  @override
  String get endpoint => 'Point de terminaison';

  @override
  String get enterAPassword => 'Entrez un mot de passe.';

  @override
  String get enterAUsername => 'Entrez un nom d\'utilisateur.';

  @override
  String get enterAValidEmailAddress => 'Entrez une adresse e-mail valide.';

  @override
  String get enterAnAddressManually => 'Saisir une adresse manuellement';

  @override
  String get enterAnApiKeyFirst => 'Entrez d\'abord une clé API.';

  @override
  String get enterInviteLink => 'Entrez le lien d\'invitation';

  @override
  String get enterTheAddressOfANeoagent =>
      'Saisissez l\'adresse d\'un serveur NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Entrez les détails que $arg1 vous a fournis pour que $arg2 puisse envoyer et recevoir des messages.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Entrez votre 2FA ou votre code de récupération.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Entrez votre mot de passe actuel pour le modifier.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Entrez votre mot de passe actuel pour enregistrer les modifications apportées aux e-mails.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Entrez les détails de votre compte NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Entrez votre nom d\'utilisateur ou l\'e-mail de votre compte. NeoAgent enverra un lien de réinitialisation s\'il peut correspondre au compte.';

  @override
  String get enterYourUsernameOrEmail =>
      'Entrez votre nom d\'utilisateur ou votre email.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entité : $arg1';
  }

  @override
  String get environment => 'Environnement';

  @override
  String get error => 'Erreur';

  @override
  String errorArg1(Object? arg1) {
    return '\nerreur : $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Erreurs du journal récent, regroupées par message.';

  @override
  String get errorsProblemsFailures => 'erreurs problèmes échecs';

  @override
  String get eventTypesCommaSeparated =>
      'Types d\'événements (séparés par des virgules)';

  @override
  String get every15Minutes => 'Toutes les 15 minutes';

  @override
  String get every30Minutes => 'Toutes les 30 minutes';

  @override
  String get everyAccountOnThisServerLoses =>
      'Chaque compte sur ce serveur perd cette clé partagée. Comptes ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'chaque compte sur ce serveur. Les secrets sont en écriture seule : quittez ';

  @override
  String get everyAccountOnThisServerUses =>
      'Chaque compte sur ce serveur utilise cette adresse pour ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Chaque session active pour ce compte se termine. Ils peuvent se connecter ';

  @override
  String get everyDay0800 => 'Tous les jours · 08h00';

  @override
  String get everyDay2000 => 'Tous les jours · 20h00';

  @override
  String get everyHour => 'Toutes les heures';

  @override
  String get everyRunOnThisServerAll =>
      'Chaque exécution sur ce serveur, à tout moment.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Chaque outil sensible nécessite une approbation à chaque fois.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Tous les outils fonctionnent sans rien demander, sauf ceux que la personne ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Tous les membres de ces groupes, canaux ou salles peuvent parler à $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Tout le monde dans ce groupe';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Tout ce que $arg1 a désactivé pour votre agent vient ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Tout le reste est éteint.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Tout est disponible depuis le bureau.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Tout ce que l\'agent peut utiliser : intégrations officielles, serveurs MCP et compétences.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Tout ce que vous avez désactivé pour $arg1 revient ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Origines Web exactes autorisées à effectuer des requêtes cross-origin, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Exécutez JavaScript dans la session de votre navigateur.';

  @override
  String get execution => 'Exécution';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Les détails d\'exécution ne sont pas disponibles pour cette exécution.';

  @override
  String get executionPlanCreated => 'Plan d\'exécution créé.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Exercices séances $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[sortie $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Expire $arg1';
  }

  @override
  String get explainThisProject => 'Expliquez ce projet';

  @override
  String exploredArg1(Object? arg1) {
    return 'Exploré $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Exploré $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'J\'ai exploré l\'espace de travail';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Échec de l\'exportation : $arg1';
  }

  @override
  String get exportLast5Messages => 'Exporter les 5 derniers messages';

  @override
  String get exportMyData => 'Exporter mes données';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Le lancement du navigateur externe a échoué avec le code de sortie $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Le lancement d\'un navigateur externe n\'est pas pris en charge sur cette plateforme.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Le délai de lancement du navigateur externe a expiré.';

  @override
  String get externalMcpTools => 'Outils externes et MCP';

  @override
  String get extraButtons => 'Boutons supplémentaires';

  @override
  String get extractingTheNeoagentRuntime => 'Extraction du runtime NeoAgent';

  @override
  String get failed => 'Échec';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Échec de la connexion : $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Échec de la connexion à $arg1 : $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Échec de la suppression de \"$arg1\" : $arg2';
  }

  @override
  String get failedToFetch => 'échec de récupération';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Échec de la génération de l\'invite : $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Échec du lancement du navigateur externe via url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Échec du lancement du flux OAuth.';

  @override
  String get failedToLoadPolicies => 'Échec du chargement des règles';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Échec de l\'enregistrement : $arg1';
  }

  @override
  String get failedToSaveMcpServer =>
      'Échec de l\'enregistrement du serveur MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Échec de l\'enregistrement de la sélection : $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Échec de l\'envoi de la notification au backend : $arg1';
  }

  @override
  String get fair => 'Foire';

  @override
  String get fasterReplies => 'Des réponses plus rapides';

  @override
  String get fewerModelCalls => 'Moins d\'appels de modèles';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'champ vide pour restaurer la valeur par défaut intégrée.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Le fichier dépasse la limite de 1 Mio de l\'éditeur.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Le fichier dépasse la limite de taille prise en charge.';

  @override
  String get fileWrites => 'Écritures de fichiers';

  @override
  String get filename => 'Nom du fichier';

  @override
  String get files => 'Fichiers';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Les fichiers que NeoAgent écrit ou modifie au cours de cette session s\'affichent ici.';

  @override
  String get filesSavedByAllUsers =>
      'Fichiers enregistrés par tous les utilisateurs';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Remplissez les connexions approuvées ou authentifiez les demandes sans montrer de secrets à l\'IA.';

  @override
  String get finalResponse => 'Réponse finale';

  @override
  String get findAPlatform => 'Trouver une plateforme';

  @override
  String get findAndFixABug => 'Rechercher et corriger un bug';

  @override
  String get findRecentChats => 'Rechercher des discussions récentes';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Trouver le bon runtime NeoAgent';

  @override
  String get finish => 'Terminer';

  @override
  String get finishAtTheScheduledTime => 'Terminer à l\'heure prévue';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Terminez de vous connecter à $arg1 dans votre navigateur, puis reconnectez-vous.';
  }

  @override
  String get flowGraph => 'Graphique de flux';

  @override
  String get flutterApp => 'Application Flutter';

  @override
  String get focusedExecutionProfile => 'Profil d\'exécution ciblé';

  @override
  String get folderIdOptional => 'ID du dossier (facultatif)';

  @override
  String get folderUnavailable => 'Dossier indisponible';

  @override
  String get forExampleHttpsMatrixOrg => 'Par exemple https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Pour les configurations réseau hébergées ou avancées';

  @override
  String get forLinksInEmailsBlankUses =>
      'Pour les liens dans les e-mails. Blank utilise l\'URL publique du serveur.';

  @override
  String get forgotPassword => 'Mot de passe oublié ?';

  @override
  String get frameUnavailable => 'Cadre indisponible';

  @override
  String freshnessArg1(Object? arg1) {
    return 'fraîcheur : $arg1';
  }

  @override
  String get fridays1700 => 'Vendredi · 17h00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Depuis BotFather après avoir créé le bot.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Désormais, $arg1 décide quels outils votre agent peut utiliser. Ils ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Depuis le portail des développeurs Discord, sous votre bot.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Depuis la console des développeurs LINE.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Depuis le client Matrix ou le compte bot.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Depuis twitchapps.com/tmi ou votre application de développement Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Invite complète';

  @override
  String get fullSetup => 'Configuration complète';

  @override
  String get general => 'Général';

  @override
  String get generalSettings => 'Paramètres généraux';

  @override
  String get generalSettingsSaved => 'Paramètres généraux enregistrés.';

  @override
  String get generateAPromptForAnotherAi =>
      'Générez une invite pour une autre IA, collez la réponse ici pour importer des souvenirs.';

  @override
  String get generatePrompt => 'Générer une invite';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Erreur de suivi de clôture géographique : $arg1';
  }

  @override
  String get getInspired => 'Inspirez-vous';

  @override
  String get githubCopilot => 'Copilote GitHub';

  @override
  String get githubCopilotAndOpenaiCodex => 'Copilote GitHub et OpenAI Codex';

  @override
  String get githubIssueOpened => 'Problème GitHub ouvert';

  @override
  String get neorecallMemoryCreated => 'Mémoire NeoRecall créée';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'La vérification de la version GitHub a échoué avec HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'La charge utile de la version GitHub n’était pas une liste de versions.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Nom d\'utilisateur GitHub qui a ouvert le problème';

  @override
  String get globalSecurityMode => 'Mode de sécurité globale';

  @override
  String get gmailMessageReceived => 'Message Gmail reçu';

  @override
  String get good => 'Bien';

  @override
  String get goodAfternoon => 'Bonjour';

  @override
  String get goodEvening => 'Bonsoir';

  @override
  String get goodMorning => 'Bonjour';

  @override
  String get goodPasswordALittleMoreLength =>
      'Bon mot de passe. Un peu plus de longueur le rend plus fort.';

  @override
  String get googleChat => 'Chat Google';

  @override
  String get googleWorkspace => 'Espace de travail Google';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live utilise votre clé API OpenAI, Gemini Live votre clé Google AI. Les modifications s\'appliquent au prochain appel.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Accordez les autorisations Health Connect avant la synchronisation.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Groupe, chaîne ou salle';

  @override
  String get groupType => 'Type de groupe';

  @override
  String get groupsAndChannels => 'Groupes et chaînes';

  @override
  String groupsArg1(Object? arg1) {
    return 'Groupes : $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Les groupes que $arg1 n\'a pas encore vu suivront.';
  }

  @override
  String get handlesDirectTasksItself => 'Gère lui-même les tâches directes';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Mains libres (parlez librement, interrompez à tout moment)';

  @override
  String get headerName => 'Nom de l\'en-tête';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titres sur les sujets qui vous intéressent, filtrés pour le signal.';

  @override
  String get health => 'Santé';

  @override
  String get healthChecks => 'Bilans de santé';

  @override
  String get healthConnect => 'connexion santé';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect n\'est pas disponible sur cet appareil.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'État de synchronisation de Health Connect et métriques backend stockées.';

  @override
  String get healthStatusIsUnavailable =>
      'L\'état de santé n\'est pas disponible.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'La synchronisation de la santé est disponible sur Android uniquement.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Enregistrements cardiaques $arg1';
  }

  @override
  String get heldBack => 'Retenu';

  @override
  String get helper => 'Aide';

  @override
  String helperArg1(Object? arg1) {
    return 'Assistant : $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'ici. Révoquer l\'administrateur avec « neoagent admin revoke $arg1 » en premier.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Des valeurs plus élevées rendent NeoAgent plus sélectif dans les groupes.';

  @override
  String get highlyRecommended => 'Fortement recommandé';

  @override
  String get holdButton131ForTheAssistant =>
      'Maintenez le bouton 131 pour l\'assistant.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Maintenez Ctrl+Shift+Espace pour parler';

  @override
  String get holdToTalk => 'Attendez pour parler.';

  @override
  String get holdToTalk2 => 'Attends pour parler';

  @override
  String get home => 'Accueil';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Le jeton d’accès de longue durée de Home Assistant est requis.';

  @override
  String get homeAssistantSetup => 'Configuration de l\'assistant à domicile';

  @override
  String get homeAssistantUrl => 'URL de l\'assistant à domicile';

  @override
  String get homeAssistantUrlIsRequired =>
      'L’URL de Home Assistant est requise.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Jeton de serveur domestique avec interrogation de salle';

  @override
  String get homeserverUrl => 'URL du serveur domestique';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'service hébergé). Vos clés sont cryptées et utilisables uniquement par ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Nom d\'hôte du réseau IRC, par exemple irc.libera.chat';

  @override
  String get hourly => 'Horaire';

  @override
  String get hourlyInboxCheck =>
      'Vérification horaire de la boîte de réception';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Combien de temps les liens de confirmation restent valides.';

  @override
  String get howOftenThisAgentLooksFor =>
      'À quelle fréquence cet agent recherche les nouveaux messages de salle.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'À quelle fréquence cet agent recherche de nouveaux messages Signal.';

  @override
  String get howTeamsWork => 'Comment fonctionnent les équipes';

  @override
  String get howThisServerIsReachedPlus =>
      'Comment ce serveur est atteint, ainsi que les commutateurs à l\'échelle du serveur.';

  @override
  String get httpsSessionCookie => 'cookie de session https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Je n\'ai pas pu finaliser cette demande pour le moment. Veuillez réessayer dans un instant.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inactif';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Si $arg1 demande une URL de webhook, collez-la afin que les messages puissent atteindre $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Si ce compte dispose d\'un e-mail confirmé, NeoAgent enverra un lien de réinitialisation du mot de passe.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Si le service nécessite un jeton sur les requêtes sortantes.';

  @override
  String get ignoreGroups => 'Ignorer les groupes';

  @override
  String get ignoreThisChat => 'Ignorer cette discussion';

  @override
  String get ignoredChannels => 'Canaux ignorés';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Message compagnon de bureau mal formé ignoré : $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Diablotin $arg1';
  }

  @override
  String get implementThePlanAbove => 'Mettez en œuvre le plan ci-dessus.';

  @override
  String get implementThisPlan => 'Mettre en œuvre ce plan';

  @override
  String get implicitTls => 'TLS implicite';

  @override
  String get import => 'Importer';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Échec de l\'importation : $arg1';
  }

  @override
  String get importFromComputer => 'Importer depuis un ordinateur';

  @override
  String get importMemoryTransfer => 'Importer un transfert de mémoire ?';

  @override
  String get importance => 'Importance';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Mémoires $arg1 importées, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'Dans l\'équipe de @$arg1';
  }

  @override
  String get inBackground => 'fond';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Les messages de canal entrants et sortants apparaîtront ici.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Appels vocaux entrants dans l\'application depuis NeoAgent';

  @override
  String get incomingMessages => 'Messages entrants';

  @override
  String get incomingNeoagentCall => 'Appel NeoAgent entrant';

  @override
  String get incomingNeoagentCall2 => 'APPEL NEOAGENT ENTRANT';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Prise en charge du webhook entrant et des rappels sortants';

  @override
  String get incorporatingSteering => 'Intégration de la direction';

  @override
  String get input => 'Entrée';

  @override
  String get inputMode => 'Mode de saisie';

  @override
  String get insertATemplate => 'Insérer un modèle';

  @override
  String get install => 'Installer';

  @override
  String get installASignedSelfContainedRuntime =>
      'Installez un runtime signé et autonome. Les commandes Node.js, npm, Git et terminal ne sont pas requises.';

  @override
  String get installApk => 'Installer l\'APK';

  @override
  String get installApkBundle => 'Installer l\'APK/Bundle';

  @override
  String get installApkClickOrDropA =>
      'Installer l\'APK - cliquez ou déposez un fichier .apk';

  @override
  String get installNeoagent => 'Installer NéoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Installez NeoAgent sur cet ordinateur sans terminal, ou connectez-vous à un terminal déjà en cours d\'exécution.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Installez les nouvelles versions et choisissez le canal que suit ce serveur.';

  @override
  String get installTheBackend => 'Installer le back-end';

  @override
  String get installTheCoreWithExtraOptional =>
      'Installez le noyau avec une configuration facultative supplémentaire. Les clés du fournisseur d’IA sont ajoutées ultérieurement, comme pour Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Installez le noyau sécurisé, puis créez votre compte. Ajoutez ensuite les clés du fournisseur d’IA.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Installé : $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Installé : $arg1 • Dernière vérification : $arg2';
  }

  @override
  String get instructions => 'Instructions';

  @override
  String get integration => 'Intégration';

  @override
  String get integrationApps => 'Applications d\'intégration';

  @override
  String get integrationConnections => 'Connexions d\'intégration';

  @override
  String get integrationSettingsSaved =>
      'Paramètres d\'intégration enregistrés.';

  @override
  String get integrations => 'Intégrations';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'Integrations/oauth/callback, et enregistrez-le de même ';

  @override
  String get interruptAi => 'Interrompre l\'IA';

  @override
  String get invalid2fa => '2fa invalide';

  @override
  String get invalidArgumentS => 'Arguments invalides : ';

  @override
  String get invalidCredentials => 'informations d\'identification invalides';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Manifeste d’exécution NeoAgent non valide.';

  @override
  String get inviteLink => 'Lien d\'invitation';

  @override
  String get inviteLinkReady => 'Lien d\'invitation prêt';

  @override
  String get inviteLinks => 'Inviter des liens';

  @override
  String get iphoneApp => 'Application iPhone';

  @override
  String get issues => 'Problèmes';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Les problèmes apparaissent une fois le journal chargé.';

  @override
  String get itCanTBeUndone => 'Cela ne peut pas être annulé.';

  @override
  String get itMayHaveBeenDeleted => 'Il a peut-être été supprimé.';

  @override
  String get javaRuntime => 'environnement d\'exécution Java';

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
    return 'A rejoint $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Inscrit au cours des 7 derniers jours';

  @override
  String get joiningATeam => 'Rejoindre une équipe';

  @override
  String get joiningIsOffHere => 'L\'adhésion est désactivée ici';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Champ JSON qui contient le texte du message. Généralement du texte.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Champ JSON qui identifie à qui le message est destiné.';

  @override
  String get jumpToLatest => 'Aller au dernier';

  @override
  String get justNow => 'juste maintenant';

  @override
  String get keepNeoagentRunning => 'Continuer à faire fonctionner NeoAgent ?';

  @override
  String get keepRunning => 'Continuez à courir';

  @override
  String get keepTaskRunning => 'Maintenir la tâche en cours';

  @override
  String get keepTheVaultAvailable => 'Gardez le coffre-fort disponible';

  @override
  String get keepThisLauncherUpToDate => 'Gardez ce lanceur à jour.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Gardez ce panneau ouvert jusqu\'à ce que la plateforme confirme la connexion.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Garder l\'ordinateur de cette session visible';

  @override
  String get keepTrackOfYourAiUsage =>
      'Gardez une trace de votre utilisation de l\'IA. Des limites sont appliquées pour garantir une utilisation équitable sur l’ensemble de la plateforme.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Continuez à utiliser vos applications normalement. NeoAgent fonctionne sur le même écran et demande chaque fois qu\'il a besoin d\'un nouvel accès.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Garder cet appareil connecté';

  @override
  String get key => 'Clé';

  @override
  String get keyIsRequired => 'La clé est requise.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Paires clé-valeur qui persistent dans les conversations.';

  @override
  String get knowledgeGraph => 'Graphique des connaissances';

  @override
  String get knowledgeView => 'Vue Connaissance';

  @override
  String get labelOnlyYouSeeIt => 'Étiquette (vous seul la voyez)';

  @override
  String get labelsOptional => 'Étiquettes (facultatif)';

  @override
  String get last24Hours => 'Dernières 24 heures';

  @override
  String get last7Days => '7 derniers jours';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return '7 derniers jours : jetons $arg1 dans les exécutions $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Dernier $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Dernier : $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Dernière synchronisation non vide · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Dernière exécution : $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Vu pour la dernière fois $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Dernière connexion $arg1';
  }

  @override
  String get lastSyncSummary => 'Résumé de la dernière synchronisation';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Dernière utilisation : $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Dernière fenêtre terminée $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'plus tard, le démarrage est également désactivé.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Dernière exécution · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Le lancement d\'applications de bureau n\'est pas pris en charge sur cette plateforme.';

  @override
  String get learnRoomNorms => 'Apprendre les normes de la chambre';

  @override
  String get leave => 'Partir';

  @override
  String get leaveARedirectUriBlankTo =>
      'Laissez un URI de redirection vide pour utiliser <public URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Quitter l’équipe de $arg1 ?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Conservez la valeur par défaut, sauf si vous avez personnalisé BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Laissez le jeton vide pour conserver le jeton actuellement stocké.';

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
    return 'Laissez $arg1 me gérer';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Laissez tous les membres de ce groupe parler à $arg1.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Laissez-le fonctionner pendant\nque vous ne le faites pas.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Laissez NeoAgent cliquer, taper et vous déplacer dans vos applications.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Laissez NeoAgent comprendre ce qui est visible sur votre écran.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Laissez quelqu\'un avec qui vous travaillez décider quels outils votre agent peut ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Laissez cette personne envoyer à $arg1 un message individuel.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Laissez cette personne parler à $arg1 ici, mais pas dans des discussions privées ou d\'autres groupes.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Laissez cette personne parler à $arg1 dans des discussions privées et dans n\'importe quel groupe qu\'elle partage.';
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
    return 'Lien $arg1';
  }

  @override
  String get linkCopied => 'Lien copié';

  @override
  String get linkExpiresAfter => 'Le lien expire après';

  @override
  String get linkLifetimeHours => 'Durée de vie du lien (heures)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'La durée de vie du lien doit être comprise entre 1 et 8 760 heures.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Lien valable jusqu\'à $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Fournisseurs de connexion liés';

  @override
  String get linuxApp => 'Application Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Répertorié $arg1/';
  }

  @override
  String get listening => 'Écoute';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Historique d\'exécution en direct, étapes de l\'outil et réponses.';

  @override
  String get liveModel => 'Modèle vivant';

  @override
  String get liveModelProvider => 'Fournisseur de modèles vivants';

  @override
  String get liveRun => 'Course en direct';

  @override
  String get liveVoice => 'Voix en direct';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'La connexion vocale en direct n\'est pas disponible.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'La connexion vocale en direct a été fermée.';

  @override
  String get liveVoiceDefaults => 'Paramètres vocaux en direct par défaut';

  @override
  String get liveVoiceFailed => 'La voix en direct a échoué.';

  @override
  String get llmMemoryExportResponse => 'Réponse d\'exportation de mémoire LLM';

  @override
  String get loadFailed => 'échec du chargement';

  @override
  String get loadingExecutionDetails =>
      'Chargement des détails d\'exécution...';

  @override
  String get loadingNeoagent => 'Chargement de NeoAgent';

  @override
  String get loadingRunFlow => 'Chargement du flux d\'exécution…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Les URL de réseaux locaux et privés sont prises en charge lorsque le serveur NeoAgent peut les atteindre. L\'audio n\'est jamais exposé à NeoAgent.';

  @override
  String get localApp => 'application locale';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'L\'installation backend locale n\'est pas disponible sur cette plateforme.';

  @override
  String get localBaseImagePath => 'Chemin de l\'image de base locale';

  @override
  String get localComputerControlIsAvailableIn =>
      'Le contrôle de l\'ordinateur local est disponible dans l\'application de bureau NeoAgent sur macOS, Windows et Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Le contrôle informatique local n’est pas disponible ici.';

  @override
  String get localModelsUrl => 'URL des modèles locaux';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'La découverte NeoAgent locale est temporairement indisponible.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Préférences locales pour l\'application NeoAgent. Le contrôle informatique s\'effectue toujours via l\'ordinateur cloud unifié.';

  @override
  String get localSetup => 'CONFIGURATION LOCALE';

  @override
  String get locationCityOrPlace => 'Localisation (ville ou lieu)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'L\'emplacement est requis pour les déclencheurs d\'événements météorologiques';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Échec de l\'initialisation de LocationService : $arg1';
  }

  @override
  String get logCopied => 'Journal copié';

  @override
  String get loginPassword => 'Mot de passe de connexion';

  @override
  String get logout => 'Déconnexion';

  @override
  String get logs => 'Journaux';

  @override
  String get logsCopied => 'Journaux copiés.';

  @override
  String get logsOnThisComputer => 'Journaux sur cet ordinateur';

  @override
  String get longLivedAccessToken => 'Jeton d\'accès de longue durée';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Rappel à long terme, faits structurés et graphique de connaissances.';

  @override
  String get lookedAtTheScreen => 'J\'ai regardé l\'écran';

  @override
  String get lookingOnThisComputerAndYour =>
      'En regardant sur cet ordinateur et votre réseau local…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Anticipe les réunions de demain pour que rien ne vous surprenne.';

  @override
  String get loopExecution => 'Exécution de boucle';

  @override
  String get loopPaused => 'Boucle en pause';

  @override
  String get macOsX => 'Mac OS X';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'L\'accessibilité macOS n\'est pas accordée à NeoAgent. Autorisez-le dans Paramètres système › Confidentialité et sécurité › Accessibilité.';

  @override
  String get macosApp => 'Application macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'L\'enregistrement d\'écran macOS n\'est pas accordé à NeoAgent. Autorisez-le dans Paramètres système > Confidentialité et sécurité > Enregistrement d\'écran, puis rouvrez NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Les serveurs de messagerie qui ont besoin d\'un mot de passe refuseront d\'envoyer jusqu\'à un nouveau ';

  @override
  String get main => 'Principal';

  @override
  String get makeDefault => 'Par défaut';

  @override
  String get manage => 'Gérer';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Gérez la messagerie de votre compte, l\'authentification à deux facteurs et les sessions actives.';

  @override
  String get managedBy => 'Géré par';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Les managers peuvent avoir leurs propres managers (jusqu\'à quatre niveaux). Un ';

  @override
  String get managing => 'Gérer';

  @override
  String get manualDestination => 'Destination manuelle';

  @override
  String get manualTrigger => 'Déclenchement manuel';

  @override
  String get masterPassword => 'Mot de passe principal';

  @override
  String get matchThisDevice => 'Correspond à cet appareil';

  @override
  String get matchedAgainstTitleAndBody => 'Comparé au titre et au corps';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Correspond à l\'ancien flux NeoAgent MCP : URL plus méthode d\'authentification.';

  @override
  String get mcp => 'PCM';

  @override
  String get mcpServer => 'Serveur MCP';

  @override
  String get mcpServer2 => 'Serveur MCP';

  @override
  String get mcpServerUrl => 'URL du serveur MCP';

  @override
  String get mcpServers => 'Serveurs MCP';

  @override
  String get meantForSomeoneElse => 'Destiné à quelqu\'un d\'autre';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Coût du modèle mesuré : $arg1';
  }

  @override
  String get memories => 'Souvenirs';

  @override
  String get memory => 'Mémoire';

  @override
  String memoryArg1(Object? arg1) {
    return 'Mémoire : $arg1';
  }

  @override
  String get memoryInjected => 'Mémoire injectée';

  @override
  String get mentionOrReplyOnly => 'Mentionner ou répondre uniquement';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Journaux d\'exécution du serveur et de Flutter fusionnés pour cette session d\'application.';

  @override
  String get messageBodyTemplateJson => 'Modèle de corps de message (JSON)';

  @override
  String get messageNeedsAccess => 'Le message nécessite un accès';

  @override
  String get messageTextField => 'Champ de texte du message';

  @override
  String get messaging => 'Messagerie';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Événements push et webhook de l\'API de messagerie';

  @override
  String get messagingConnectionNeedsAttention =>
      'La connexion de messagerie nécessite une attention particulière';

  @override
  String get messagingConnections => 'Connexions de messagerie';

  @override
  String get messagingDelivery => 'Livraison de messages';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Erreur de messagerie. Veuillez réessayer.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'La capture du microphone s\'est arrêtée de manière inattendue. Essayer à nouveau.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Erreur de microphone : $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Micro coupé. Appuyez pour réactiver le son.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'L\'autorisation du microphone est requise pour la voix en direct.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack et les autres intégrations. Ils s\'appliquent à ';

  @override
  String get microsoftTeams => 'Équipes Microsoft';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Valeur minimale de cotisation : $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'La configuration mobile a échoué.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'La configuration mobile a échoué car Java n\'est pas disponible sur la machine exécutant NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'La configuration mobile a échoué car Java n\'est pas disponible sur la machine exécutant NeoAgent. Installez un JDK et réessayez.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'La configuration mobile a échoué. Vérifiez que les outils Android sont correctement installés et réessayez.';

  @override
  String modeArg1(Object? arg1) {
    return 'mode : $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Le mode se verrouille lorsqu\'une analyse est active.';

  @override
  String get model => 'Modèle';

  @override
  String modelArg1(Object? arg1) {
    return 'Modèle : $arg1';
  }

  @override
  String get modelAvailability => 'Disponibilité du modèle';

  @override
  String get modelAvailabilitySaved => 'Disponibilité du modèle enregistrée.';

  @override
  String get modelForThisSession => 'Modèle pour cette séance';

  @override
  String get modelOverride => 'Remplacement du modèle';

  @override
  String get modelPending => 'Modèle en attente';

  @override
  String get modelTurn => 'Tour de modèle';

  @override
  String get modelTurnCompleted => 'Tour de modèle terminé';

  @override
  String get modelTurnStarted => 'Le tour du modèle a commencé';

  @override
  String get modelVisibilityHideShowList =>
      'visibilité du modèle masquer afficher la liste';

  @override
  String get models => 'Modèles';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modèles, comportement, voix et espace de travail';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modèles, navigateur, voix, diagnostics...';

  @override
  String get modelsRouting => 'Modèles & routage';

  @override
  String get monthly => 'Mensuel';

  @override
  String get moreActions => 'Plus de propositions';

  @override
  String get morningBriefing => 'Briefing du matin';

  @override
  String get mostUsedAgents => 'Agents les plus utilisés';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Modèles les plus utilisés dans le dernier $arg1.';
  }

  @override
  String get mouseKeyboard => 'Souris et clavier';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove n\'est pas pris en charge sur cette plate-forme.';

  @override
  String get mustBeReachableOnThePublic =>
      'Doit être accessible sur l\'Internet public - local et ';

  @override
  String get n24Hours => '24 heures';

  @override
  String get n2faOrRecoveryCode => '2FA ou code de récupération';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA nécessite que SESSION_SECRET soit configuré sur ce déploiement NeoAgent.';

  @override
  String get n30Days => '30 jours';

  @override
  String get n365Days => '365 jours';

  @override
  String get n4HourLimitTokens => 'Limite de 4 heures (jetons)';

  @override
  String get n4HourUsage => 'Utilisation de 4 heures';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Limite 4h $arg1';
  }

  @override
  String get n7DayUsage => 'Utilisation sur 7 jours';

  @override
  String get n7Days => '7 jours';

  @override
  String get n90Days => '90 jours';

  @override
  String get name => 'Nom';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnom : Nouvelle compétence\ndescription : Décrivez ce que fait cette compétence\n---\nÉcrivez ici les instructions pour cette compétence.\n';

  @override
  String get nameOfWhoeverMadeIt => 'nom de celui qui l\'a fait.';

  @override
  String get nameOptional => 'Nom (facultatif)';

  @override
  String get nativeAndWebhookChannels => 'Canaux natifs et webhook';

  @override
  String get naturalBubbles => 'Bulles naturelles';

  @override
  String get nearbyNeoagentServers => 'Serveurs NeoAgent à proximité';

  @override
  String get needANewAccountRegister =>
      'Besoin d\'un nouveau compte ? S\'inscrire';

  @override
  String get needAnIdea => 'Besoin d\'une idée ?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Besoin de répondre · $arg1% pour parler';
  }

  @override
  String get needsAttention => 'A besoin d\'attention';

  @override
  String get needsInput => 'Nécessite une contribution';

  @override
  String get neoagentApp => 'Application NéoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NéoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Assistant NéoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent n\'a pas pu vérifier le runtime backend disponible.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent n\'a pas pu terminer la configuration locale.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent n\'a pas pu terminer la configuration locale. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informations de débogage NeoAgent';

  @override
  String get neoagentDesktopInstaller =>
      'Programme d\'installation du bureau NeoAgent';

  @override
  String get neoagentFlutterUpdater =>
      'Programme de mise à jour NeoAgent Flutter';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent installe le dernier $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent est installé et en cours d\'exécution.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent n\'est pas installé sur cet ordinateur.';

  @override
  String get neoagentIsReady => 'NeoAgent est prêt';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent travaille toujours sur une tâche. Mettez fin à l\'appel et obtenez le résultat dans le chat, ou annulez également la tâche.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent transforme votre démonstration en un flux de travail adaptable.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent attend pendant que vous utilisez le bureau.';

  @override
  String get neoagentIsWorking => 'NeoAgent fonctionne';

  @override
  String get neoagentLinuxComputer => 'Ordinateur NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT A BESOIN D’UNE DÉCISION';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Les téléchargements du runtime NeoAgent nécessitent une adresse sécurisée.';

  @override
  String get neoagentServerAddress => 'Adresse du serveur NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'L\'e-mail du service NeoAgent n\'est pas prêt. Demandez à l\'opérateur du serveur de vérifier les paramètres de l\'environnement de messagerie.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'La configuration de NeoAgent n\'a pas pu se terminer.';

  @override
  String get neoagentUser => 'Utilisateur NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent utilise cet ordinateur automatiquement et vous demande avant d\'utiliser votre écran, votre souris, votre clavier, vos fichiers ou votre ligne de commande.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent utilise votre emplacement approximatif en arrière-plan pour déclencher des rappels de géolocalisation (par exemple « Rappelez-moi d\'acheter du lait lorsque je passe devant le supermarché »).\n\n';

  @override
  String get neoagentWorkspace => 'Espace de travail NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NéoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][pile] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'URL du back-end NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'L’URL du backend NeoRecall est requise.';

  @override
  String get neorecallSetup => 'Configuration de NeoRecall';

  @override
  String get networkRequestFailed => 'la requête réseau a échoué';

  @override
  String get networkWriteRequests => 'Demandes d\'écriture réseau';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'ne compte jamais dans les limites d’utilisation partagée.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Les nouveaux comptes confirment leur adresse e-mail avant de se connecter.';

  @override
  String get newAccountsPerDay => 'Nouveaux comptes par jour';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Les nouveaux groupes restent silencieux à moins que quelqu\'un ne marque $arg1, jusqu\'à ce que vous les activiez.';
  }

  @override
  String get newLink => 'Nouveau lien';

  @override
  String get newPasswordsDoNotMatch =>
      'Les nouveaux mots de passe ne correspondent pas.';

  @override
  String get newRecoveryCodes => 'Nouveaux codes de récupération';

  @override
  String get newSession => 'Nouvelle séance';

  @override
  String get newSessionN => 'Nouvelle séance (⌘N)';

  @override
  String get newSessionWithSameSetup =>
      'Nouvelle session avec la même configuration';

  @override
  String get newSkill => 'Nouvelle compétence';

  @override
  String get newSkill2 => 'Nouvelle compétence';

  @override
  String get newThisWeek => 'Nouveau cette semaine';

  @override
  String get newsDigest => 'Résumé de l\'actualité';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Nouvelle tentative : $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Flux de connexion Nextcloud';

  @override
  String get nextcloudSetup => 'Configuration Nextcloud';

  @override
  String get nextcloudTalk => 'Discussion Nextcloud';

  @override
  String get nextcloudUrl => 'URL du prochain cloud';

  @override
  String get nextcloudUrlIsRequired => 'L\'URL Nextcloud est requise.';

  @override
  String get nickname => 'Surnom';

  @override
  String get noAccountsConnectedYet => 'Aucun compte connecté pour l\'instant.';

  @override
  String get noAccountsFound => 'Aucun compte trouvé.';

  @override
  String get noActiveSessionsFound => 'Aucune session active trouvée.';

  @override
  String get noAgentsYet => 'Aucun agent pour l\'instant';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Aucun fournisseur d\'IA n\'est configuré, donc le chat et la messagerie ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Aucune invite d\'approbation : l\'agent s\'exécute sans interruption.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Aucun actif de version $arg1 ne correspond à cette plate-forme.';
  }

  @override
  String get noArguments => '(pas d\'arguments)';

  @override
  String get noAuth => 'Pas d\'authentification';

  @override
  String get noBindingsYet => 'Pas encore de liaisons.';

  @override
  String get noChangesYet => 'Aucun changement pour l\'instant';

  @override
  String get noChannelsFound => 'Aucune chaîne trouvée';

  @override
  String get noCloudComputerSlotIsFree =>
      'Aucun emplacement d’ordinateur cloud n’est gratuit pour le moment. Réessayez dans un instant.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Aucune entrée de mémoire principale pour l\'instant.';

  @override
  String get noDescription => 'Pas de description';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Aucun écran de bureau n\'est actuellement disponible.';

  @override
  String get noDetailAvailable => 'Aucun détail disponible';

  @override
  String get noDetailedSyncSummaryYet =>
      'Pas encore de résumé détaillé de la synchronisation.';

  @override
  String get noDetailsCaptured => 'Aucun détail capturé.';

  @override
  String get noEmailLinked => 'Aucun e-mail lié';

  @override
  String get noExternalSignInProvidersLinked =>
      'Aucun fournisseur de connexion externe lié.';

  @override
  String get noGroupMessagesYet => 'Pas encore de messages de groupe';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Aucune personne spécifique au groupe n\'a encore été ajoutée.';

  @override
  String get noGroupsAddedYet => 'Aucun groupe n\'a encore été ajouté.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Aucun groupe trouvé pour l\'instant. Une fois que $arg1 a vu un message de groupe, utilisez Rechercher des discussions récentes et elles apparaîtront ici.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Aucun groupe trouvé pour l\'instant. Une fois que $arg1 a vu un message de groupe, utilisez Rechercher des discussions récentes.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Aucune charge utile de données de santé renvoyée.';

  @override
  String get noHealthSamplesStoredYet =>
      'Aucun échantillon de santé n\'est encore stocké.';

  @override
  String get noHttpClientImplementationForThis =>
      'Aucune implémentation de client HTTP pour cette plateforme.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Aucune entrée ou sortie n\'a été enregistrée pour cette étape.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Aucune intégration ne correspond à cette recherche.';

  @override
  String get noLimit => 'Aucune limite';

  @override
  String get noLocalPasswordIsSetYet =>
      'Aucun mot de passe local n\'est encore défini. Créez-en un pour activer la connexion par nom d\'utilisateur/mot de passe.';

  @override
  String get noLogEntries => 'Aucune entrée de journal.';

  @override
  String get noMatchingSettings => 'Aucun paramètre correspondant';

  @override
  String get noMcpServersMatchThisSearch =>
      'Aucun serveur MCP ne correspond à cette recherche.';

  @override
  String get noMemoryEntriesFound => 'Aucune entrée de mémoire trouvée.';

  @override
  String get noMemorySync => 'Pas de synchronisation de la mémoire';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Lit une seule fois les e-mails importants et envoyés des 12 derniers mois pour que l\'agent connaisse vos contacts et vos projets.';

  @override
  String get emailMemory => 'Mémoire des e-mails';

  @override
  String get importNow => 'Importer maintenant';

  @override
  String get importOnConnect =>
      'Importer les anciens e-mails à la connexion d\'un compte';

  @override
  String get sweepStarting => 'Préparation…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Lecture des e-mails · $done sur $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Lecture des e-mails · $count trouvés';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Apprentissage à partir des e-mails · $done sur $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Dernier import : $emails e-mails · $memories nouveaux souvenirs';
  }

  @override
  String get sweepNothingNew => 'Aucun nouvel e-mail à importer';

  @override
  String sweepFailed(String error) {
    return 'Échec de l\'import : $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Aucun modèle ne correspond à \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Aucune demande de modèle n\'a été enregistrée pour cette exécution.';

  @override
  String get noModelsDiscoveredYet => 'Aucun modèle découvert pour l\'instant';

  @override
  String get noModelsSelected => 'Aucun modèle sélectionné';

  @override
  String get noModelsYet => 'Aucun modèle pour l\'instant';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'aucun compte neoagent n\'est lié à ce prestataire';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Aucun moteur d\'exécution backend NeoAgent n\'est disponible pour cet ordinateur.';

  @override
  String get noNetworkConnection => 'Aucune connexion réseau';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Aucune connexion réseau. Connectez-vous pour continuer à utiliser NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Aucune connexion réseau. Reconnectez-vous pour vérifier les mises à jour.';

  @override
  String get noOne => 'Personne';

  @override
  String get noOneAddedYet => 'Personne n\'a encore été ajouté.';

  @override
  String get noOneCanMessage => 'Personne ne peut envoyer un message';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Aucun autre serveur NeoAgent n\'a été trouvé. Vous pouvez effectuer une nouvelle recherche ou saisir une adresse manuellement.';

  @override
  String get noPeopleAddedYet => 'Aucune personne ajoutée pour l\'instant.';

  @override
  String get noPlatformsMatch => 'Aucune plateforme ne correspond';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Aucun fournisseur n\'est encore disponible à configurer.';

  @override
  String get noRecentChannelActivity => 'Aucune activité récente sur la chaîne';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Aucun résultat pour \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Aucune course dans cette plage.';

  @override
  String get noRunsMatchTheseFilters =>
      'Aucune exécution ne correspond à ces filtres';

  @override
  String get noRunsYet => 'Aucune course pour l\'instant';

  @override
  String get noRunsYet2 => 'Aucune course pour l\'instant.';

  @override
  String get noSecurityKeyWasProvided =>
      'Aucune clé de sécurité n\'a été fournie.';

  @override
  String get noServerUrlSet => 'Aucune URL de serveur définie';

  @override
  String get noSessionMatchesThatSearch =>
      'Aucune session ne correspond à cette recherche.';

  @override
  String get noSessionsYet => 'Aucune séance pour l\'instant';

  @override
  String get noSkillsMatchTheseFilters =>
      'Aucune compétence ne correspond à ces filtres.';

  @override
  String get noStepsWereRecordedForThis =>
      'Aucune étape n\'a été enregistrée pour cette exécution.';

  @override
  String get noSummaryAvailable => 'Aucun résumé disponible.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Aucune tâche pour $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Aucun outil ne correspond à \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Aucune mise à jour en cours';

  @override
  String get noUsageYet => 'Aucune utilisation pour l\'instant.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Aucun moteur d’exécution backend NeoAgent vérifié n’est encore disponible.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Personne ne peut plus l\'utiliser. Les personnes qui ont déjà rejoint ';

  @override
  String get none => 'Aucun';

  @override
  String get notApprovedYet => 'pas encore approuvé';

  @override
  String get notAuthenticated => 'non authentifié';

  @override
  String get notCheckedYet => 'Pas encore vérifié';

  @override
  String get notConfigured => 'Non configuré';

  @override
  String get notConnected => 'Non connecté';

  @override
  String get notConnected2 => 'Non connecté';

  @override
  String get notInstalled => 'Non installé';

  @override
  String get notNeeded => 'Pas nécessaire';

  @override
  String get notNeededEnough => 'Pas assez nécessaire';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get notNow2 => 'Pas maintenant';

  @override
  String get notSet => 'Non défini';

  @override
  String get notSetUp => 'Non configuré';

  @override
  String get notTheSameAsAdmin => 'Pas la même chose qu\'un administrateur';

  @override
  String get nothingFound => 'Rien trouvé';

  @override
  String get nothingHereYet => 'Rien ici encore.';

  @override
  String get nothingHereYet2 => 'Rien ici encore';

  @override
  String get nothingMatches => 'Rien ne correspond';

  @override
  String get nothingStoredYet => 'Rien de stocké pour l\'instant.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NIM NVIDIA';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'Informations d\'identification de l\'application OAuth qui permettent aux comptes de connecter Google, ';

  @override
  String get oauthClientId => 'ID client OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'Clé API de redirection secrète de l\'identifiant client oauth';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth client id redirection secrète lecteur de calendrier gmail';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Le lancement OAuth n\'est pas pris en charge sur cette plateforme.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'secret d\'identification du client du locataire oauth Outlook';

  @override
  String get oauthToken => 'Jeton OAuth';

  @override
  String get oauthWithPkce => 'OAuth avec PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'de $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'de sa propre. Il n\'est plus jamais affiché après l\'enregistrement.';

  @override
  String get off => 'Désactivé';

  @override
  String get officialIntegration => 'Intégration officielle';

  @override
  String get officialIntegrationDidNotReturnA =>
      'L\'intégration officielle n\'a pas renvoyé d\'URL de connexion.';

  @override
  String get on => 'Activé';

  @override
  String get onASignedInAndroidDevice =>
      'Sur un appareil Android connecté, ouvrez Paramètres > Connexion et sécurité, scannez ce code et approuvez la connexion.';

  @override
  String get onByDefaultForNewGroups =>
      'Activé par défaut pour les nouveaux groupes';

  @override
  String get onDemand => 'Sur demande';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Allumé pour les groupes $arg1 des $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'sur. Ils ne peuvent se joindre à nouveau qu\'avec un nouveau lien d\'invitation.';

  @override
  String get onYourOwnTheDefault => 'Seul (par défaut)';

  @override
  String get once => 'Une fois';

  @override
  String get oneBlankToKeepWhatIs =>
      'un blanc pour conserver ce qui est stocké.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'on est sauvé. Les autres modifications apportées à ce formulaire sont également enregistrées.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Un ou plusieurs comptes ont expiré. Reconnectez le compte concerné pour restaurer l\'accès à l\'outil.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Un environnement d\'exécution contrôle le personnage, le tour de rôle du groupe, la mémoire de la salle, les normes, la théorie de l\'esprit et la livraison.';

  @override
  String get oneTimeRun => 'Exécution unique';

  @override
  String get onlyApkOrApksFilesCan =>
      'Seuls les fichiers .apk ou .apks peuvent être installés.';

  @override
  String get onlyInThisGroup => 'Uniquement dans ce groupe';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Nécessaire uniquement si le service demande des en-têtes HTTP supplémentaires.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Nécessaire uniquement si vous souhaitez remodeler la charge utile sortante.';

  @override
  String get onlyTheyCanChangeIt => 'Eux seuls peuvent le changer.';

  @override
  String get open => 'Ouvrir';

  @override
  String get openAccountSettingsOnASigned =>
      'Ouvrez Paramètres › Connexion et sécurité sur un appareil Android connecté, scannez ce code et approuvez la connexion.';

  @override
  String get openComputer => 'Ordinateur ouvert';

  @override
  String get openDashboard => 'Ouvrir le tableau de bord';

  @override
  String get openFolder => 'Ouvrir le dossier…';

  @override
  String get openInWorkbench => 'Ouvrir dans l\'établi';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Ouvrez NeoAgent et reconnectez $arg1 pour restaurer la messagerie.';
  }

  @override
  String get openTimeSettings => 'Paramètres de temps d\'ouverture';

  @override
  String get openToAnyone => 'Ouvert à tous';

  @override
  String get openTrello => 'Ouvrir Trello';

  @override
  String get openVoiceAssistant => 'Assistant vocal ouvert';

  @override
  String get openWiFiSettings => 'Ouvrir les paramètres Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Ouvrir avec l\'application par défaut';

  @override
  String get openaiCodex => 'Codex OpenAI';

  @override
  String get openaiCompatible => 'compatible openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Point de terminaison compatible OpenAI (votre propre serveur ou un autre ';

  @override
  String openedArg1(Object? arg1) {
    return 'Ouvert $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'L\'ouverture d\'URL de bureau n\'est pas prise en charge sur cette plate-forme.';

  @override
  String get openingYourSavedDesktop => 'Ouverture de votre bureau enregistré.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Ouverture de votre bureau enregistré. Les démarrages normaux prennent moins de 10 secondes.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Secret supplémentaire facultatif si vous protégez le webhook entrant.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Remplacement facultatif si l’URL du webhook n’est pas suffisante.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Secret facultatif pour vérifier les événements de chat entrants.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Secret facultatif pour vérifier les événements entrants.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Secret facultatif pour vérifier les événements iMessage entrants.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Secret facultatif pour vérifier les événements LINE entrants.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Secret facultatif pour vérifier les événements Mattermost entrants.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Secret facultatif pour vérifier les événements Teams entrants.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Facultatif. L\'agent a déjà sa propre personnalité. Tout ce que vous ajoutez sur le ton est superposé, vous n\'avez donc jamais besoin d\'en définir un.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Facultatif. Lorsqu\'il est défini, il est utilisé à la place de l\'URL.';

  @override
  String get orAnswerInYourOwnWords => 'Ou répondez avec vos propres mots';

  @override
  String get orBuildYourOwnTask => 'Ou créez votre propre tâche';

  @override
  String get orContinueWith => 'ou continuez avec';

  @override
  String get orFiles => 'ou des fichiers.';

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
  String get originNotAllowed => 'origine non autorisée';

  @override
  String get outgoingMessage => 'Message sortant';

  @override
  String get outgoingWebhookUrl => 'URL du webhook sortant';

  @override
  String get outlookEmailReceived => 'E-mail Outlook reçu';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Remplacez les notes de comportement de l’importation.';

  @override
  String get ownModel => 'propre modèle';

  @override
  String get packageName => 'Nom du package';

  @override
  String get pairWithQrCode => 'Associer avec le code QR';

  @override
  String get password => 'Mot de passe';

  @override
  String get password2faAndActiveSessions =>
      'Mot de passe, 2FA et sessions actives';

  @override
  String get passwordCreated => 'Mot de passe créé.';

  @override
  String get passwordIsTooWeak => 'le mot de passe est trop faible';

  @override
  String get passwordMin8 => 'mot de passe minimum 8';

  @override
  String get passwordOrApiKey => 'Mot de passe ou clé API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Force du mot de passe : $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get pasteAKey => 'Collez une clé.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Collez une nouvelle clé pour remplacer $arg1';
  }

  @override
  String get pasteTheKey => 'Collez la clé';

  @override
  String get pasteYourAccountToken => 'Collez votre jeton de compte';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Collez votre clé API $arg1 ci-dessous. C\'est ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Le chemin doit rester dans NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Le chemin doit rester dans le dossier de l’espace de travail.';

  @override
  String get pauseLiveUpdates => 'Suspendre les mises à jour en direct';

  @override
  String get pauseTaskLoop => 'Suspendre la boucle de tâches';

  @override
  String get paused => 'En pause';

  @override
  String peakArg1(Object? arg1) {
    return 'pic $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Personnes dans des discussions privées';

  @override
  String get perAccountRateLimits => 'Limites de taux par compte';

  @override
  String get perCategoryPermissions => 'Autorisations par catégorie';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Politiques d\'autorisation par outil, portes d\'approbation et isolation des processus pour l\'exécution du shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Autorisation requise : $arg1';
  }

  @override
  String get permissionsNeeded => 'Autorisations nécessaires';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Autorisations. Personne d’autre ne peut changer cela.';

  @override
  String get personOrChat => 'Personne ou chat';

  @override
  String get personaBehaviorNotes => 'Notes de comportement du personnage';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Jeton d\'accès personnel pour le bot Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Canaux personnels et surfaces d\'assistance directes.';

  @override
  String get personalSelfChat => 'Chat personnel';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get pickARunFromTheList =>
      'Choisissez une course dans la liste pour voir ses étapes.';

  @override
  String get pickARunFromTheList2 =>
      'Choisissez une course dans la liste de gauche pour explorer son déroulement.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Choisissez parmi les discussions $arg1 récentes ou ajoutez vous-même une personne ou un groupe.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Choisissez comment $arg1 utilise ce compte.';
  }

  @override
  String get pickOneToFillInThe =>
      'Choisissez-en un pour remplir la tâche. Vous pourrez tout modifier par la suite.';

  @override
  String get picksUpWhereYouLeftOff => 'Reprenant là où tu t\'étais arrêté';

  @override
  String get plan => 'Planifier';

  @override
  String get planning => 'Planification';

  @override
  String get platform => 'Plateforme';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Plateforme $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Veuillez choisir un horaire.';

  @override
  String get pleaseEnterAFilename => 'Veuillez entrer un nom de fichier.';

  @override
  String get pleaseEnterAKey => 'Veuillez entrer une clé.';

  @override
  String get pleaseEnterAPrompt => 'Veuillez saisir une invite.';

  @override
  String get pleaseEnterATaskName => 'Veuillez saisir un nom de tâche.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Veuillez saisir le contenu de la mémoire.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Veuillez entrer quand la tâche doit être exécutée.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Veuillez sélectionner un compte ou saisir un identifiant de connexion valide.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Pointez NeoAgent vers n\'importe quelle fin de chat compatible OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Pointez la caméra vers le code affiché sur l\'appareil déconnecté. L\'approbation reste sur ce téléphone.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env url publique proxy de confiance déploiement de cookies sécurisés';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Automatisation premium avec déclencheurs de planification et d’intégration.';

  @override
  String get prepareQrCode => 'Préparer le code QR';

  @override
  String get preparingNeoagent => 'Préparation de NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Préparation de NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Appuyez et maintenez pour une capture rapide';

  @override
  String get pressKeysIsNotSupportedOn =>
      'appuyer sur les touches n\'est pas pris en charge sur cette plate-forme.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Pressé $arg1';
  }

  @override
  String get priceUnknown => 'Prix inconnu';

  @override
  String get primaryDisplay => 'Affichage principal';

  @override
  String get privateChat => 'Chat privé';

  @override
  String get privateChats => 'Discussions privées';

  @override
  String get privateChats2 => 'discussions privées';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Chats privés : $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Chats privés $arg1 · groupes $arg2';
  }

  @override
  String get privateChatsOnly => 'Chats privés uniquement';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'les adresses de réseau privé ne sont pas autorisées.';

  @override
  String get profileEmailAndPersonalData =>
      'Profil, e-mail et données personnelles';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Invite avant que NeoAgent ne reste résident dans la barre d\'état système.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Cache d\'invite : jetons mis en cache $arg1 ';
  }

  @override
  String get promptCopied => 'Invite copiée.';

  @override
  String get promptOrSchedule => 'invite ou calendrier.';

  @override
  String get promptToPasteIntoAnotherAi => 'Invite à coller dans une autre IA';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'L\'association du fournisseur n\'a pas pu être démarrée.';

  @override
  String get providerSignInCouldNotBe =>
      'La connexion au fournisseur n\'a pas pu démarrer.';

  @override
  String get providers => 'Fournisseurs';

  @override
  String get providersEachAccountCanStillPick =>
      'Fournisseurs ; chaque compte peut toujours choisir son propre modèle dans les paramètres. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Les fournisseurs, les intégrations, la voix et les fonctionnalités facultatives peuvent être complétés à tout moment à partir des paramètres.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Fils de discussion sur les problèmes publics et les demandes de tirage, répondus uniquement aux personnes approuvées.';

  @override
  String get publicUrl => 'URL publique';

  @override
  String get publicUrlAndAllowedOrigins =>
      'URL publique et origines autorisées';

  @override
  String get publicUrlOverride => 'Remplacement de l\'URL publique';

  @override
  String get pullsTogetherTheDayAhead => 'Rassemble la journée à venir';

  @override
  String get pushToTalk => 'Appuyer pour parler';

  @override
  String get qrBasedPhoneLinking => 'Liaison téléphonique basée sur QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Connexion QR terminée, mais NeoAgent n\'a pas pu conserver la session. Veuillez réessayer.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'La connexion QR n\'a pas pu être démarrée.';

  @override
  String get qrLoginRequestHasExpired => 'la demande de connexion qr a expiré';

  @override
  String get qrLoginRequestWasNotFound =>
      'La demande de connexion QR n\'a pas été trouvée';

  @override
  String get qrPairing => 'Couplage QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'les requêtes sont exécutées ; tout ce qui écrit est rejeté.';

  @override
  String get queryFilter => 'Requête/Filtre';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'En file d\'attente comme direction pour l\'exécution en cours : $arg1';
  }

  @override
  String get quickstart => 'Démarrage rapide';

  @override
  String get quit => 'Quitter';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, vent_alerte';

  @override
  String get ranAScriptInThePage => 'Exécuté un script dans la page';

  @override
  String ranArg1(Object? arg1) {
    return 'Ran $arg1';
  }

  @override
  String get rateLimits => 'Limites de taux';

  @override
  String get readAnArtifact => 'Lire un artefact';

  @override
  String get readAndEditFilesInsideYour =>
      'Lisez et modifiez les fichiers dans votre dossier NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Lire $arg1';
  }

  @override
  String get readError => 'Erreur de lecture';

  @override
  String get readFiles => 'Lire des fichiers';

  @override
  String get readOnly => 'Lecture seule';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Lisez le dossier et résumez la pile, les points d\'entrée et comment l\'exécuter.';

  @override
  String get readThePage => 'Lire la page';

  @override
  String get readTheUiTree =>
      'Lire l\'arborescence de l\'interface utilisateur';

  @override
  String get readWrite => 'Lire / Écrire';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Lit les pas, la fréquence cardiaque, le sommeil, l\'exercice et le poids.';

  @override
  String get ready => 'Prêt';

  @override
  String get readyForFirstTimeSetup => 'Prêt pour la première configuration';

  @override
  String get readyToConnect => 'Prêt à vous connecter';

  @override
  String get recentChannelActivity => 'Activité récente de la chaîne';

  @override
  String get recentChats => 'Discussions récentes';

  @override
  String get recentDecisions => 'Décisions récentes';

  @override
  String get recentFailedRuns => 'Échecs récents des exécutions';

  @override
  String get recentGroupDecisions => 'Décisions de groupe récentes';

  @override
  String get recentRuns => 'Courses récentes';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Les courses récentes durent environ $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Sortie récente du serveur, la plus récente en premier.';

  @override
  String get recentUsage4Hours => 'Utilisation récente (4 heures)';

  @override
  String get recents => 'Récents';

  @override
  String get recipientField => 'Champ Destinataire';

  @override
  String get reconnectOrFinishSetup =>
      'Reconnectez-vous ou terminez la configuration';

  @override
  String get reconnectingThisDevice => 'Reconnexion de cet appareil…';

  @override
  String get recurring => 'Récurrent';

  @override
  String get redirectUri => 'URI de redirection';

  @override
  String get redoOnboarding => 'Refaire l\'intégration';

  @override
  String get refresh => 'Actualiser';

  @override
  String get refreshCode => 'Actualiser le code';

  @override
  String get refreshNow => 'Actualiser maintenant';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Actualisez l\'écran Android pour réessayer.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Refusez d\'envoyer à moins que la connexion ne soit mise à niveau vers TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'quels que soient les paramètres par catégorie ci-dessous.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Enregistrez $arg1 pour le flux d\'invocation d\'assistant.';
  }

  @override
  String get registrationIsClosed => 'les inscriptions sont closes';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'inscription enregistrer de nouveaux comptes permettre l\'inscription';

  @override
  String get rejectInvalidTlsCertificates =>
      'Rejeter les certificats TLS invalides';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'libération et redémarrages. Les applications connectées se reconnectent une fois de retour.';

  @override
  String get releaseChannel => 'Canal de sortie';

  @override
  String get releaseCommitBranchNode =>
      'libérer le nœud de branche de validation';

  @override
  String get releaseWhenYouAreDone => 'Relâchez lorsque vous avez terminé.';

  @override
  String get reloadNow => 'Recharger maintenant';

  @override
  String get rememberThisChoice => 'Rappelez-vous ce choix';

  @override
  String get remove => 'Supprimer';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Supprimer « $arg1 » et ses étapes enregistrées de l\'historique d\'exécution ?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Supprimez \"$arg1\" de la mémoire principale.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Supprimer la clé $arg1 ?';
  }

  @override
  String get removeEraseGdprUser => 'supprimer effacer l\'utilisateur RGPD';

  @override
  String get removeSmtpPassword => 'Supprimer le mot de passe SMTP';

  @override
  String get removeTheSmtpPassword => 'Supprimer le mot de passe SMTP ?';

  @override
  String get rename => 'Renommer';

  @override
  String get renameSecurityKey => 'Renommer la clé de sécurité';

  @override
  String get renameSession => 'Renommer la session';

  @override
  String get repairAndRetry => 'Réparer et réessayer';

  @override
  String get repairDesktop => 'Réparer le bureau';

  @override
  String get repeat => 'Répéter';

  @override
  String get repliesWhenTagged => 'Répond lorsqu\'il est tagué';

  @override
  String get replyToAddress => 'Adresse de réponse';

  @override
  String replyToArg1(Object? arg1) {
    return 'Répondre à $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Le référentiel doit être au format propriétaire/dépôt.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproduisez le bug que je décris, trouvez la cause première et corrigez-le avec un test de régression.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'la requête a échoué avec http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'La requête a échoué avec HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Demander des autorisations';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'La requête adressée à $arg1 a échoué avant que le backend ne réponde.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Demandé $arg1';
  }

  @override
  String get requireStarttls => 'Exiger STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Requis derrière HTTPS ou un proxy TLS. S\'applique après un serveur ';

  @override
  String get requiredExampleBerlinDe => 'Obligatoire. Exemple : Berlin, DE';

  @override
  String get requiredFormatOwnerRepo =>
      'Obligatoire. Format : propriétaire/dépôt';

  @override
  String get reserveAssistantHotkey =>
      'Touche de raccourci pour l\'assistant de réservation';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get resetView => 'Réinitialiser la vue';

  @override
  String get responsibilities => 'Responsabilités';

  @override
  String get restart => 'Redémarrer';

  @override
  String get restartToFinishTheUpdate =>
      ' Redémarrez pour terminer la mise à jour.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Restauration du runtime NeoAgent précédent';

  @override
  String get restrictDelegationTargets =>
      'Restreindre les cibles de délégation';

  @override
  String get result => 'Résultat';

  @override
  String get resultDelivery => 'Livraison des résultats';

  @override
  String get resultOneClickAddsOneYou =>
      'résultat. Un clic en ajoute un ; vous pourrez le modifier plus tard.';

  @override
  String get results => 'Résultats';

  @override
  String get retry => 'Réessayer';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Réutilisable · utilisé $arg1×';
  }

  @override
  String get reviewUncommittedChanges =>
      'Examiner les modifications non validées';

  @override
  String get revoke => 'Révoquer';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Révoquer l\'administrateur avec « neoagent admin revoke $arg1 » en premier';
  }

  @override
  String get revokeThisLink => 'Révoquer ce lien ?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Fenêtre de lot de salle : $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Faites pivoter pour continuer';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rangées. Ajoutez une clause LIMIT ou une clause WHERE plus étroite pour voir ';

  @override
  String get rule => 'Règle';

  @override
  String get run => 'Exécution';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Exécutez des commandes arbitraires sur votre machine ou VM.';

  @override
  String get runAt => 'Courir à';

  @override
  String get runCompleted => 'Exécution terminée';

  @override
  String get runFailed => 'Échec de l\'exécution';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Exécutez git diff, examinez les modifications non validées pour détecter les bogues et les problèmes de style, et résumez ce que vous trouvez.';

  @override
  String get runNotFound => 'Exécution introuvable';

  @override
  String get runNow => 'Exécuter maintenant';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Exécutez les messages WhatsApp personnels entrants.';

  @override
  String get runQuery => 'Exécuter une requête';

  @override
  String get runShellCommandsOrInstallApps =>
      'Exécutez des commandes shell ou installez des applications sur votre appareil Android.';

  @override
  String get runStarted => 'L\'exécution a commencé';

  @override
  String get runStatus => 'Statut d\'exécution';

  @override
  String get runStopped => 'Exécution arrêtée';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Exécutez les commandes du terminal et ouvrez des applications ou des pages Web.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Exécuter ce serveur : comptes, mises à jour, fournisseurs, configuration ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Exécuté lorsqu\'un message Gmail correspondant arrive.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Exécuté lorsqu\'un e-mail Outlook correspondant arrive.';

  @override
  String get runWhenANewIssueMatching =>
      'Exécuté lorsqu\'un nouveau numéro correspondant à vos filtres est ouvert dans un référentiel.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Exécuté lorsqu\'une nouvelle mémoire NeoRecall correspondant à vos filtres est créée.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Exécuté lorsqu\'une notification arrive sur votre appareil.';

  @override
  String get runWhenASlackMessageMatches =>
      'Exécuté lorsqu\'un message Slack correspond à la portée sélectionnée.';

  @override
  String get runWhenATeamsChatMessage =>
      'Exécuté lorsqu’un message de discussion Teams correspond à la portée sélectionnée.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Exécuté lorsque des événements météorologiques configurés sont prévus pour un emplacement.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'courir. Lorsqu\'un modèle est désactivé, les modèles ajoutés par les fournisseurs ';

  @override
  String get running => 'En cours';

  @override
  String runningArg1(Object? arg1) {
    return 'Exécution de $arg1';
  }

  @override
  String get runningTask => 'Tâche en cours d\'exécution';

  @override
  String get runningTool => 'Outil de course';

  @override
  String get runs => 'Exécutions';

  @override
  String get runsEveryDayAtTheSelected =>
      'S\'exécute tous les jours à l\'heure sélectionnée.';

  @override
  String get runsFourTimesPerHour => 'Fonctionne quatre fois par heure.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '- exécutions, messages, mémoires, intégrations, fichiers et ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'exécutions, messages, mémoires, intégrations, fichiers et sessions. ';

  @override
  String get runsMondayThroughFriday => 'Fonctionne du lundi au vendredi.';

  @override
  String get runsOnSelectedWeekdays =>
      'Fonctionne certains jours de la semaine.';

  @override
  String get runsOncePerHour => 'Fonctionne une fois par heure.';

  @override
  String get runsOncePerMonthOnThe =>
      'S\'exécute une fois par mois le jour sélectionné.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'S\'exécute uniquement lorsque vous appuyez sur Exécuter maintenant.';

  @override
  String get runsPerDay => 'Courses par jour';

  @override
  String get runsPerDay30Days => 'Courses par jour (30 jours)';

  @override
  String get runsThatCompleted => 'Exécutions terminées';

  @override
  String get runsThisWeek => 'Fonctionne cette semaine';

  @override
  String get runsToday => 'Fonctionne aujourd\'hui';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Les exécutions, les outils, la mémoire, la planification, les compétences et le MCP sont tous disponibles ici.';

  @override
  String get runsTwicePerHour => 'Fonctionne deux fois par heure.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Les exécutions reviendront à la clé de serveur partagée pour $arg1, si celle-ci est configurée. Cela ne peut pas être annulé.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Exécution $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Durée d\'exécution : $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Paramètres d\'exécution avec lesquels ce serveur a démarré. Modifiez-les sous ';

  @override
  String get runtimeSetupRequired => 'Configuration d\'exécution requise';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'La clé publique de signature d’exécution doit être de 32 octets.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveATrelloApiKeyFor =>
      'Enregistrez une clé API Trello pour cet agent, puis connectez un compte Trello en toute sécurité. Le jeton de compte est stocké sur le serveur et utilisé uniquement pour cet agent.';

  @override
  String get saveAccount => 'Enregistrer le compte';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get saveCloudComputerSettings =>
      'Enregistrer les paramètres de l\'ordinateur cloud';

  @override
  String get saveConnect => 'Enregistrer et se connecter';

  @override
  String get saveDefaults => 'Enregistrer les valeurs par défaut';

  @override
  String get saveDiagnosticReport => 'Enregistrer le rapport de diagnostic';

  @override
  String get saveEmail => 'Enregistrer l\'e-mail';

  @override
  String get saveEmailSettings => 'Enregistrer les paramètres de messagerie';

  @override
  String get saveGeneralSettings => 'Enregistrer les paramètres généraux';

  @override
  String get saveName => 'Enregistrer le nom';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Enregistrer les diagnostics de configuration de NeoAgent';

  @override
  String get saveOnly => 'Enregistrer uniquement';

  @override
  String get saveSetup => 'Enregistrer la configuration';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Enregistrez ces codes de récupération maintenant. Ils ne seront plus montrés.';

  @override
  String get savedDeliveryDestination => 'Destination de livraison enregistrée';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Limites de débit enregistrées pour @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Scanner un QR de connexion NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scannez un QR de couplage NeoAgent depuis un autre appareil et approuvez-le à partir de cette session de lancement.';

  @override
  String get scanLoginQr => 'Scanner le QR de connexion';

  @override
  String get scanPairingQr => 'Scanner le QR d\'appariement';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scannez les demandes de connexion QR à partir d\'appareils déconnectés et approuvez-les à partir de cette session mobile authentifiée.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scannez pour terminer $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Scannez avec NeoAgent sur votre téléphone';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Analyse les nouveaux e-mails et vous envoie un ping uniquement lorsque quelque chose est important.';

  @override
  String get schedule => 'Calendrier';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'heure prévue. Une fois les courses mesurées, elles commenceront plus tôt.';

  @override
  String get screen => 'Écran';

  @override
  String get screenAction => 'action à l\'écran';

  @override
  String get scrollIsNotSupportedOnThis =>
      'le défilement n\'est pas pris en charge sur cette plate-forme.';

  @override
  String get scrollToBottom => 'Faire défiler vers le bas';

  @override
  String get search => 'Rechercher';

  @override
  String get search2 => 'Rechercher…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Rechercher les paramètres d\'administration (par exemple SMTP, Ollama, journaux)';

  @override
  String get searchAgain => 'Rechercher à nouveau';

  @override
  String get searchByUsernameOrEmail =>
      'Rechercher par nom d\'utilisateur ou email';

  @override
  String get searchChannels => 'Rechercher des chaînes';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Recherchez les canaux de messagerie, les contacts, les groupes et les conversations récentes découverts.';

  @override
  String get searchGroups => 'Rechercher des groupes';

  @override
  String get searchMemory => 'Rechercher dans la mémoire';

  @override
  String get searchModelsOrProviders =>
      'Rechercher des modèles ou des fournisseurs';

  @override
  String get searchModelsOrProviders2 =>
      'Rechercher des modèles ou des fournisseurs…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Rechercher des personnes et des groupes récents';

  @override
  String get searchSessions => 'Sessions de recherche';

  @override
  String get searchSettings => 'Paramètres de recherche';

  @override
  String get searchTitleModelTriggerRunId =>
      'Rechercher un titre, un modèle, un déclencheur, un ID d\'exécution';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Outils de recherche, intégrations et compétences';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Code recherché pour \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Fichiers recherchés pour \"$arg1\"';
  }

  @override
  String get secretField => 'Champ secret';

  @override
  String get secureCookies => 'Cookies sécurisés';

  @override
  String get security => 'Sécurité';

  @override
  String get securityKey => 'Clé de sécurité';

  @override
  String get securityKeyPromptWasDismissed =>
      'L\'invite de clé de sécurité a été ignorée.';

  @override
  String get securityKeySignInCompletedBut =>
      'Connexion par clé de sécurité terminée, mais NeoAgent n\'a pas pu conserver la session du navigateur. Veuillez vous reconnecter.';

  @override
  String get securityKeySignInCouldNot =>
      'La connexion par clé de sécurité n\'a pas pu démarrer.';

  @override
  String get securityKeys => 'Clés de sécurité';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Les clés de sécurité ne sont disponibles que dans l\'application Web NeoAgent.';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Vérifiez quel serveur NeoAgent cette fenêtre utilise et exécutez le backend sur cet ordinateur.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'voir votre nom d\'utilisateur et ces paramètres, jamais vos discussions, souvenirs ';

  @override
  String get selectARun => 'Sélectionnez une course';

  @override
  String get selectASessionToSeeIts =>
      'Sélectionnez une session pour voir son ordinateur, ses fichiers et ses modifications.';

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get selectAll2 => 'Sélectionner tout';

  @override
  String selectArg1(Object? arg1) {
    return 'Sélectionnez $arg1';
  }

  @override
  String get selectTrigger => 'Sélectionnez le déclencheur';

  @override
  String get send => 'Envoyer (⌘↵)';

  @override
  String get send2 => 'Envoyer';

  @override
  String get sendATaskFromChatAnd =>
      'Envoyez une tâche depuis le chat et son historique d\'exécution s\'affichera ici.';

  @override
  String get sendItToATeammateWith =>
      'envoyez-le à un coéquipier possédant un compte sur ce serveur.';

  @override
  String get sendLink => 'Envoyer le lien';

  @override
  String get sendPath => 'Envoyer le chemin';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Envoyez des requêtes POST / PUT / DELETE à des API externes.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Envoyez ce lien uniquement à la personne à laquelle il est destiné. Il est affiché une fois ; ';

  @override
  String get senderAddress => 'Adresse de l\'expéditeur';

  @override
  String get senderFilterOptional => 'Filtre d\'expéditeur (facultatif)';

  @override
  String get sentSharedAttachments => 'Envoyé des pièces jointes partagées.';

  @override
  String get separateAccount => 'Compte séparé';

  @override
  String get server => 'Serveur';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Serveur par défaut ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Paramètres par défaut du serveur pour les appels vocaux dans l\'application. Les appels se déroulent en direct ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'serveur lui-même : comptes, fournisseurs et configuration.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Serveur, pseudo, canal et TLS en option';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'copie des erreurs d\'avertissements de la console de sortie du serveur';

  @override
  String get serverProviderCredentials =>
      'Identifiants du fournisseur de serveur';

  @override
  String get serverUrl => 'URL du serveur';

  @override
  String get serverUsageLimitsDonTApply =>
      'Les limites d\'utilisation du serveur ne s\'appliquent pas aux modèles exécutés sur votre propre clé.';

  @override
  String get serviceEmail => 'E-mail de service';

  @override
  String get serviceEmailIsNotConfigured =>
      'l\'e-mail de service n\'est pas configuré';

  @override
  String get serviceEmailSmtp => 'E-mail de service (SMTP)';

  @override
  String get sessionActions => 'Actions de session';

  @override
  String get sessions => 'Séances';

  @override
  String get sessions2 => 'SÉANCES';

  @override
  String get sessionsArePinnedToAFolder =>
      'Les sessions sont épinglées sur un dossier et un ordinateur. Commencez-en un pour planifier, construire, tester et expédier à partir d’ici.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'séances (RGPD art. 17). Les comptes administrateur ne peuvent pas être supprimés ';

  @override
  String get sessionsLogoutRevokeForce =>
      'sessions déconnexion révoquer forcer';

  @override
  String get setBlockAskAllowPerTool =>
      'Définissez bloquer/demander/autoriser par catégorie d\'outils, ou choisissez un mode global.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Configurer NeoAgent sur cet ordinateur';

  @override
  String get setUpOrConnectNeoagent => 'Configurer ou connecter NeoAgent';

  @override
  String get setUrl => 'Définir l\'URL';

  @override
  String get settings => 'Paramètres';

  @override
  String get settingsAndCannotBeUndone =>
      'paramètres et ne peut pas être annulé.';

  @override
  String get settingsArea => 'Zone de paramètres';

  @override
  String get settingsAreas => 'Zones de paramètres';

  @override
  String get setup => 'Configuration';

  @override
  String get setupDetails => 'Détails de configuration';

  @override
  String get setupRequired => 'Configuration requise';

  @override
  String get setupWasCancelled => 'L\'installation a été annulée.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Pièces jointes partagées depuis le client NeoAgent :';

  @override
  String get sharedFromAnotherApp => 'Partagé depuis une autre application';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Les clés de fournisseur partagées sont configurées sur le serveur. Pour utiliser votre propre clé API ou un point de terminaison personnalisé, accédez à Avancé → Apportez votre propre clé.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Partagé avec le chat NeoAgent et sa mémoire.';

  @override
  String get shellCommands => 'Commandes Shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Afficher tout $arg1';
  }

  @override
  String get showEarlier => 'Afficher plus tôt';

  @override
  String get showEveryStep => 'Montrer chaque étape';

  @override
  String get showTools => 'Afficher les outils';

  @override
  String get showWorkbenchJ => 'Afficher l\'établi (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Présentation du premier $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Affiché dans la barre latérale. Laissez vide pour utiliser votre nom d\'utilisateur.';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signInCompletedButNeoagentCould =>
      'Connexion terminée, mais NeoAgent n\'a pas pu conserver la session du navigateur. Veuillez vous reconnecter. Si cela continue, vérifiez les paramètres des cookies de session backend.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Connexion terminée, mais NeoAgent n\'a pas pu conserver la session du navigateur. Veuillez vous reconnecter. Si cela continue, le cookie de session backend n\'est probablement pas conservé.';

  @override
  String get signInToThisNeoagentServer =>
      'Connectez-vous à ce serveur NeoAgent avant de scanner un code QR de couplage.';

  @override
  String get signInWithAHardwareKey =>
      'Connectez-vous avec une clé matérielle ou un mot de passe au lieu de votre mot de passe. ';

  @override
  String get signInWithASecurityKey => 'Sign in with a security key';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Connectez-vous avec $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Approve NeoAgent in your $arg1 account. Aucune clé à copier.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'En attente de $arg1. Terminez dans votre navigateur.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Collez le code $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Après avoir approuvé NeoAgent, $arg1 a affiché un code à usage unique. Collez-le ici.';
  }

  @override
  String get signInCode => 'Code de connexion';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Connectez-vous avec $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Échec de la connexion : $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Connectez-vous avec le même e-mail et le même mot de passe principal que vous utilisez dans Bitwarden. Le mot de passe principal et le code en deux étapes sont utilisés uniquement pour la connexion et ne sont jamais stockés ni envoyés à l\'IA.';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Sign out @$arg1 everywhere?';
  }

  @override
  String get signOutEverywhere => 'Déconnectez-vous partout';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API bridge';

  @override
  String get signalCliServerUrl => 'URL du serveur signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Signed @$arg1 out of every session.';
  }

  @override
  String get signedInDevices => 'Appareils connectés';

  @override
  String get signedInWithin24Hours => 'Signed in within 24 hours';

  @override
  String get signingSecret => 'Secret de signature';

  @override
  String sinceArg1(Object? arg1) {
    return 'Depuis $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'depuis $arg1';
  }

  @override
  String get singleMessage => 'Message unique';

  @override
  String get singleUse => 'Usage unique';

  @override
  String get skill => 'Compétence';

  @override
  String get skillChanges => 'Changements de compétences';

  @override
  String get skillContent => 'Contenu de compétence';

  @override
  String get skills => 'Compétences';

  @override
  String get skip => 'Sauter';

  @override
  String get skipForNow => 'Passer pour l\'instant';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Ignorez cette tâche avant qu\'elle appelle le modèle.';

  @override
  String get slackMessageReceived => 'Message Slack reçu';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Séances de sommeil $arg1';
  }

  @override
  String get smartSelector => 'sélecteur intelligent';

  @override
  String get smartSelector2 => 'Sélecteur intelligent';

  @override
  String get smartSelectorPool => 'Pool de sélecteurs intelligents';

  @override
  String get smtpHost => 'Hôte SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp mail expéditeur mot de passe tls confirmation notifications réinitialiser';

  @override
  String get smtpPassword => 'Mot de passe SMTP';

  @override
  String get smtpPort => 'Port SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Le port SMTP doit être un nombre entier compris entre 1 et 65535.';

  @override
  String get smtpUsername => 'Nom d\'utilisateur SMTP';

  @override
  String get soTheRunStartsThatMuch =>
      'donc la course commence beaucoup plus tôt.';

  @override
  String get socialBehaviorOff => 'Comportement social désactivé';

  @override
  String get socialIntelligence => 'intelligence sociale';

  @override
  String get socialIntelligence2 => 'Intelligence sociale';

  @override
  String get socialObservability => 'Observabilité sociale';

  @override
  String get socialReach => 'portée sociale';

  @override
  String get socialReach2 => 'Portée sociale';

  @override
  String get socialReach3 => 'Portée sociale';

  @override
  String get socialReachUpdated => 'Portée sociale mise à jour.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Les agents des sources sociales peuvent lire directement, notamment les flux, les référentiels, Reddit, X, les vidéos et les données de marché sauvegardées par des cookies.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Quelque chose s\'est mal passé. Veuillez réessayer.';

  @override
  String get source => 'Source';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Espace ou ID de chat utilisé lorsque cet agent démarre une conversation.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Prise en charge du webhook spatial et des rappels d\'applications';

  @override
  String get speaking => 'Parler';

  @override
  String get speechToSpeechModelUsingThe =>
      'modèle de synthèse vocale utilisant la clé OpenAI ou Google sous ';

  @override
  String get speechToText => 'Parole en texte';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'La synthèse vocale transcrit les notes vocales et les dictées. Auto utilise OpenAI, Gemini ou Deepgram, selon celui qui possède une clé API. Le modèle de réponse vocale est le modèle de chat qui répond aux notes vocales.';

  @override
  String get sqlConsole => 'Console SQL';

  @override
  String get stable => 'Stable';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable installe la dernière version backend publiée.';

  @override
  String get stackTrace => 'trace de pile';

  @override
  String get standard => 'Norme';

  @override
  String get standardView => 'Vue standard';

  @override
  String get start => 'Commencer';

  @override
  String get startASessionToPlanOr =>
      'Start a session to plan or build with NeoAgent.';

  @override
  String get startAndroid => 'Démarrer Android';

  @override
  String get startComputer => 'Démarrer l\'ordinateur';

  @override
  String get startFullSetup => 'Démarrer la configuration complète';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Démarrer la configuration';

  @override
  String get startTalking => 'Commencez à parler';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Démarrez d’abord le téléphone Android, puis déposez un fichier .apk ou .apks ici.';

  @override
  String get startTheServerLaterFromThe =>
      'Démarrez le serveur plus tard à partir de la liste une fois la configuration enregistrée.';

  @override
  String get startWithARecommendedTask => 'Start with a recommended task';

  @override
  String get startingAndroid => 'Démarrer Android';

  @override
  String get startingYourComputer => 'Démarrage de votre ordinateur';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Commence par xoxb-. From your Slack app credentials.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Error: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'stats runs tokens users charts success rate';

  @override
  String get status => 'Statut';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'fournisseurs de machines virtuelles d\'exécution de la base de données d\'état';

  @override
  String get statusIsNotLoadedYet => 'Le statut n\'est pas encore chargé.';

  @override
  String get stayManagedByYou => 'restez géré par vous.';

  @override
  String get stayOnTheCall => 'Restez à l\'appel';

  @override
  String get stayedQuiet => 'Je suis resté silencieux';

  @override
  String get steering => 'DIRECTION';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'ÉTAPE $arg1 DE $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Étapes $arg1';
  }

  @override
  String get stop => 'Arrêter';

  @override
  String get stop2 => 'Arrêtez (⌘.)';

  @override
  String get stopManaging => 'Arrêtez de gérer';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Arrêter de gérer $arg1 ?';
  }

  @override
  String get stopRun => 'Arrêter de courir';

  @override
  String get stopSpeaking => 'Arrête de parler';

  @override
  String get stoppedBeforeCompletion => 'Arrêté avant la fin';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'Erreur stopTelecomCallRouting : $arg1';
  }

  @override
  String get storage => 'Stockage';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'stocké crypté et utilisé uniquement pour vos propres courses.';

  @override
  String get storedMetrics => 'Métriques stockées';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Stocke uniquement la clé de session Bitwarden chiffrée sur ce serveur, afin que les connexions survivent aux redémarrages. Vous pouvez le verrouiller à tout moment.';

  @override
  String get strong => 'Fort';

  @override
  String get strongPassword => 'Mot de passe fort.';

  @override
  String get subAgent => 'Sous-agent';

  @override
  String get subagentUpdate => 'Mise à jour du sous-agent';

  @override
  String get subagentUpdate2 => 'Mise à jour du sous-agent.';

  @override
  String get successRate => 'Taux de réussite';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Suggestions : $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Résumer ma dernière course';

  @override
  String get supportUrl => 'URL d\'assistance';

  @override
  String get supportedRainStartSnowStartWind =>
      'Pris en charge : rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Agent de commutation';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Les liens symboliques ne sont pas autorisés dans les chemins NeoAgent Workspace.';

  @override
  String get syncNow => 'Synchronisez maintenant';

  @override
  String get synologyChat => 'Discussion Synologie';

  @override
  String get systemPrivacySettings =>
      'Paramètres de confidentialité du système';

  @override
  String get tableInfoUsers => 'Informations sur la table (utilisateurs)';

  @override
  String get tagsOnly => 'Balises uniquement';

  @override
  String get tasks => 'Tâches';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Les tâches s\'exécutent d\'elles-mêmes et vous envoient un message avec le ';

  @override
  String get teach => 'Enseigner';

  @override
  String get teachingInProgress => 'Enseignement en cours';

  @override
  String get team => 'Équipe';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Les liens d’équipe ne font jamais de quelqu’un un administrateur de serveur. Les administrateurs exécutent le ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Espaces d\'équipe, salles, chaînes et communautés en direct.';

  @override
  String get teamsMessageReceived => 'Message des équipes reçu';

  @override
  String get templates => 'Modèles';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Les fichiers d\'installation temporaires seront nettoyés ultérieurement.';

  @override
  String get tenantId => 'ID du locataire';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get testConnection2 => 'Tester la connexion';

  @override
  String get textChat => 'Envoyer des SMS et discuter';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'qui a ajouté sa propre clé, continuez à l\'utiliser.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Cet e-mail appartient déjà à un compte existant. Connectez-vous d\'abord, puis associez Google à partir des paramètres du compte.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Cet e-mail est déjà lié à un autre compte.';

  @override
  String get thatQrCodeIsNotA =>
      'Ce code QR n\'est pas une demande de connexion NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Ce code QR n\'est pas une demande de couplage NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Cette clé de sécurité est déjà enregistrée sur ce compte.';

  @override
  String get theAddress => 'L\'adresse';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'L\'adresse de votre serveur BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'L\'adresse que les personnes et les fournisseurs OAuth utilisent pour atteindre ';

  @override
  String get theAgentReadsTimesYouMention =>
      'L\'agent lit les heures que vous mentionnez et exécute les tâches planifiées dans ce fuseau horaire.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'L\'agent demandera avant chaque outil sensible, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'L\'agent ignorera cette compétence.';

  @override
  String get theAppCouldNotReachThis =>
      'L\'application n\'a pas pu atteindre ce déploiement NeoAgent. Vérifiez votre connexion réseau ou confirmez que l\'URL du service est correcte.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Le navigateur a bloqué une demande adressée à $arg1 en raison de la politique de sécurité du contenu.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Le navigateur a bloqué une requête requise en raison de la politique de sécurité du contenu.';

  @override
  String get theCloudWorkspace => 'l\'espace de travail cloud';

  @override
  String get theComputerCouldNotStart => 'L\'ordinateur n\'a pas pu démarrer';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'L\'ordinateur a besoin de plus d\'espace disque libre sur l\'hôte NeoAgent. Libérez de l\'espace, puis réessayez.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Le moteur d\'exécution de l\'ordinateur doit être réparé. Exécutez NeoAgent Doctor, puis réessayez.';

  @override
  String get theConnectionTestFailed => 'Le test de connexion a échoué.';

  @override
  String get theDesktopDidNotStart => 'Le bureau n\'a pas démarré';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Le NeoAgent découvert a renvoyé des données d\'identité incomplètes.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Le NeoAgent découvert utilise un protocole d\'installation non pris en charge.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Le service découvert n\'est pas NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Le runtime NeoAgent téléchargé n’a pas réussi la vérification.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook de l\'espace Google Chat sur lequel cet agent doit publier.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Le programme d\'installation n\'est plus disponible.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Le bureau Linux interactif est disponible dans l\'application Web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'L\'intro n\'est pas disponible sur cet appareil.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'La dernière version s\'applique à tous les comptes.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'La dernière fenêtre de synchronisation a terminé $arg1 et n\'a trouvé aucun nouvel enregistrement Health Connect. Les métriques stockées ci-dessous proviennent de synchronisations antérieures.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'La session graphique Linux ne fonctionne pas.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Le modèle vocal en direct n\'a pas répondu. Essayer à nouveau.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'La commande NeoAgent locale s\'est terminée avec le code $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'La commande NeoAgent locale a expiré.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Le runtime NeoAgent local doit être réparé.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Le runtime local doit être réparé ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Le répertoire de base de l\'utilisateur local n\'est pas disponible.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Le compte de messagerie NeoAgent envoie des confirmations d\'inscription, de connexion ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'L\'agent principal est créé automatiquement en cas de besoin.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Le runtime NeoAgent correspondant est absent de cette version.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Le webhook entrant Mattermost sur lequel cet agent doit publier.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Les modèles entre lesquels le Smart Selector achemine automatiquement.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Le téléchargement du backend NeoAgent ne correspondait pas à son manifeste.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Le téléchargement du backend de NeoAgent était incomplet.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Le backend NeoAgent sur cet ordinateur ne répond pas sur le port ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Le runtime backend NeoAgent n’a pas pu être téléchargé.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Le backend NeoAgent a mis trop de temps à répondre pour $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Le déploiement de NeoAgent a répondu avec HTTP 402 au lieu du 401 normal pour les informations d\'identification non valides. Vérifiez le proxy inverse, la passerelle d\'authentification ou les règles liées au paiement sur ce serveur.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Le déploiement de NeoAgent a répondu avec HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Le déploiement de NeoAgent a répondu avec HTTP 402. Vérifiez le proxy inverse, la passerelle d\'authentification ou les règles liées au paiement sur ce serveur.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'L\'instance NeoAgent à laquelle cette application est connectée.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Le service de publication de NeoAgent a renvoyé des données non valides.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Les métadonnées de l\'artefact d\'exécution de NeoAgent ne sont pas valides.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Le manifeste d\'exécution de NeoAgent n\'a pas réussi la vérification de la signature.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Le manifeste d\'exécution de NeoAgent ne contient aucun artefact.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'La signature du manifeste d\'exécution de NeoAgent n\'est pas valide.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Le mot de passe que vous avez défini dans BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Les personnes que vous dirigez restent avec vous.';

  @override
  String get theProviderAnswers => 'le fournisseur répond.';

  @override
  String get theQueryReturnedNoRows => 'La requête n\'a renvoyé aucune ligne.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'L\'affichage du bureau demandé n\'est pas disponible.';

  @override
  String get theRest => 'le reste.';

  @override
  String get theRestEndpointForYourSignal =>
      'Le point de terminaison REST pour votre instance signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'L\'exécution est interrompue jusqu\'à ce que vous répondiez.';

  @override
  String get theRunStartsAtTheScheduled =>
      'La course commence à l\'heure prévue.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Le moteur d\'exécution est un bureau Debian Linux léger avec Chromium, PCManFM, Mousepad, LXTerminal, Python, Git et des outils de ligne de commande standard. Sa capacité est gérée par l\'hôte NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'L\'enregistrement de la clé de sécurité n\'a pas pu démarrer.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'le serveur n\'en conserve qu\'une empreinte digitale.';

  @override
  String get theServerOnThisComputerIs =>
      'Le serveur sur cet ordinateur ne fonctionne pas';

  @override
  String get theServerReportedNoHealthChecks =>
      'Le serveur n\'a signalé aucune vérification de l\'état.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Le numéro de téléphone Signal utilisé par ce bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Webhook entrant Teams sur lequel cet agent doit publier.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Le défi à deux facteurs a expiré. Connectez-vous à nouveau.';

  @override
  String get theTwoFactorCodeIsNot =>
      'Le code à deux facteurs n\'est pas valide.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Le package d\'exécution vérifié n\'a pas pu être marqué comme exécutable.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Le package d\'exécution vérifié ne contient pas les fichiers requis.';

  @override
  String get theWebAppCouldNotReach =>
      'L\'application Web n\'a pas pu atteindre le backend NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'L\'application Web n\'a pas pu atteindre le backend NeoAgent à $arg1. Vérifiez la console du navigateur et la configuration du proxy inverse/réseau.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'eux-mêmes; l\'opérateur du serveur supprime d\'abord l\'administrateur avec ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Ces chaînes restent silencieuses. Pour les entendre à nouveau, ajoutez-les sous Qui peut envoyer un message pour cette plateforme.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Ces listes sont facultatives, sauf si une section ci-dessus est définie comme approuvée uniquement.';

  @override
  String get thesePeopleAnywhere => 'Ces gens, n\'importe où';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Ces personnes peuvent envoyer des messages à $arg1 dans des discussions privées et dans n\'importe quel groupe qu\'elles partagent.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Ces personnes peuvent envoyer un message individuel à $arg1. Cela ne leur permet pas de parler en groupe.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Ces personnes ne peuvent envoyer des messages à $arg1 que dans le groupe que vous avez choisi.';
  }

  @override
  String get thesePeopleInOneGroup => 'Ces gens, dans un groupe';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'ces commutateurs, jamais vos discussions, souvenirs ou fichiers.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Ce compte débloquera NeoAgent sur cette machine.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Cet agent peut déléguer à tout agent réceptionnaire éligible.';

  @override
  String get thisAgentIsUsingAServer =>
      'Cet agent utilise une clé API Trello gérée par le serveur. Il vous suffit d\'autoriser un jeton de compte ci-dessous.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Cette version n\'est pas autorisée à communiquer avec ce déploiement NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Ce code appartient à un autre serveur NeoAgent : $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Ce bureau est connecté';

  @override
  String get thisDevice => 'Cet appareil';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Cet appareil : $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Cet appareil ne peut pas enregistrer les clés de sécurité. Ouvrez NeoAgent dans un navigateur via HTTPS pour en ajouter un.';

  @override
  String get thisDeviceUnavailable => 'Cet appareil — indisponible';

  @override
  String get thisFileHasNoContent => 'Ce fichier n\'a aucun contenu.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Cela masque \"$arg1\" du routage et de la sélection.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Cette intégration prend actuellement en charge un compte connecté par agent. Rouvrez la configuration pour la remplacer.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Cette intégration n\'est plus disponible.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Cette introduction est conçue pour une lecture paysage en plein écran.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Il s\'agit d\'un déploiement géré. Son opérateur déploie ';

  @override
  String get thisMayTakeAMoment => 'Cela peut prendre un moment.';

  @override
  String get thisMcpServerIsNoLonger => 'Ce serveur MCP n\'est plus configuré.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Cette mémoire sera supprimée définitivement.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Cette version de NeoAgent n\'est pas configurée pour vérifier les environnements d\'exécution du backend.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Cela efface définitivement toutes vos données et ne peut pas être ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Cela efface définitivement le compte et tout ce qu\'il possède : ';

  @override
  String get thisPersonAnywhere => 'Cette personne, n\'importe où';

  @override
  String get thisPersonInOneGroup => 'Cette personne, dans un groupe';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Cette demande de connexion QR a expiré. Générez un nouveau code et réessayez.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'cette demande de connexion QR a expiré';

  @override
  String get thisQrLoginRequestIsStill =>
      'Cette demande de connexion QR est toujours en attente d\'approbation.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Cette demande de connexion QR a déjà été utilisée.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Cela supprime la configuration de Home Assistant et l’instance connectée pour cet agent.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Cela supprime l\'URL du backend NeoRecall et tous les comptes NeoRecall connectés pour cet agent.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Cela supprime l\'URL Nextcloud et tous les comptes Nextcloud connectés pour cet agent.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Cela supprime la configuration Trello et les comptes connectés pour cet agent.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Cela nécessite une session authentifiée sur le même serveur NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Cette exécution n’a pas produit de réponse destinée à l’utilisateur.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Cette exécution ne contient aucune donnée de pas enregistrée.';

  @override
  String get thisServer => 'ce serveur.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Ce serveur ne signale aucun paramètre de fournisseur.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Cette compétence n\'est plus installée.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Cette tâche n\'a pas encore été exécutée, elle démarre donc toujours au ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Cette tâche ne s\'exécutera que lorsque vous appuierez sur Exécuter maintenant.';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Cela importera la réponse dans $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Cela supprimera \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Cela supprimera \"$arg1\" de la liste des serveurs.';
  }

  @override
  String get time => 'Temps';

  @override
  String get timeZone => 'fuseau horaire';

  @override
  String get timeZone2 => 'Fuseau horaire';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Délai expiré$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Impossible de répertorier les fuseaux horaires : $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Impossible de lire le fuseau horaire de l\'appareil : $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Impossible d\'enregistrer le fuseau horaire de l\'appareil : $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'à $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'pour utiliser la valeur par défaut du serveur.';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Budget symbolique pour @$arg1. Laisser un champ vide ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Budget de jetons pour chaque compte sans son propre remplacement. Laisser un ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'Limite de budget symbolique Utilisateur du quota hebdomadaire de 4 heures';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'Limite de budget symbolique Quota hebdomadaire de 4 heures global';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Utilisation du jeton indisponible sur cette version du serveur.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Jetons que tout compte peut utiliser en 4 heures.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Jetons que tout compte peut utiliser dans 7 jours.';

  @override
  String get tokensPerDay => 'Jetons par jour';

  @override
  String get tokensPerRun => 'Jetons par course';

  @override
  String get tokensToday => 'Les jetons aujourd\'hui';

  @override
  String get tokensUsed => ' jetons utilisés';

  @override
  String get tomorrowPrep => 'Préparation de demain';

  @override
  String get tooManyAttempts => 'trop de tentatives';

  @override
  String get tooManySignInAttemptsPlease =>
      'Trop de tentatives de connexion. Veuillez patienter et réessayer.';

  @override
  String get tool => 'Outil';

  @override
  String get toolApproval => 'Approbation des outils';

  @override
  String get toolApprovalRequired => 'Approbation de l\'outil requise';

  @override
  String get toolCompleted => 'Outil terminé';

  @override
  String get toolFailed => 'L\'outil a échoué';

  @override
  String get toolPermissions => 'Autorisations des outils';

  @override
  String get toolStarted => 'Outil démarré';

  @override
  String get tools => 'Outils';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Outils non intégrés à NeoAgent, y compris les serveurs MCP connectés et les fournisseurs d\'outils personnalisés.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Outils offerts ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Outils que le compte géré peut utiliser';

  @override
  String get topUsers => 'Principaux utilisateurs';

  @override
  String get topUsersAndRecentRuns =>
      'Principaux utilisateurs et exécutions récentes';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Total : jetons $arg1 sur les exécutions $arg2';
  }

  @override
  String get totalRuns => 'Nombre total de courses';

  @override
  String get totalTokens => 'Total des jetons';

  @override
  String get totalUsers => 'Nombre total d\'utilisateurs';

  @override
  String get transcript => 'Transcription';

  @override
  String get transcript2 => 'TRANSCRIPTION';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Échec de la transcription : $arg1';
  }

  @override
  String get transfer => 'Transfert';

  @override
  String get trelloApiKey => 'Clé API Trello';

  @override
  String get trelloApiKeyIsRequired => 'La clé API Trello est requise.';

  @override
  String get trelloSetup => 'Configuration de Trello';

  @override
  String get triggerType => 'Type de déclencheur';

  @override
  String get tryABroaderSearchLikeModels =>
      'Essayez une recherche plus large comme modèles, navigateur ou voix.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Essayez un nom de fournisseur, « e-mail », « limites », « mise à jour » ou « journaux ».';

  @override
  String get tryAgain => 'Réessayez';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Réessayez. Si cela continue, exécutez NeoAgent Doctor pour vérifier le temps d\'exécution de l\'ordinateur.';

  @override
  String get tryAgainInAMoment => 'Réessayez dans un instant.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Réessayez ou exécutez NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Essayez une autre recherche, connectez une plateforme de messagerie ou saisissez manuellement un identifiant de destination.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Activez un groupe si $arg1 doit également lire les messages qui ne le balisent pas.';
  }

  @override
  String get turnOffComputer => 'Éteignez l\'ordinateur';

  @override
  String get turnOffOnlyForAMail =>
      'Désactivez cette option uniquement pour un serveur de messagerie doté d\'un certificat auto-signé.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Activez si Signal doit continuer à rechercher les discussions entrantes.';

  @override
  String get turnTaking => 'prendre son tour';

  @override
  String get turnTakingModel => 'Modèle à tour de rôle';

  @override
  String get turnTakingOff => 'Décollage';

  @override
  String get turnThisOffToKeepThis =>
      'Désactivez cette option pour que cet agent soit complètement séparé des autres agents.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Désactivé par $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Désactivé par $arg1, qui gère ce compte. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Désactivé pour vous par $arg1 — eux seuls peuvent le modifier';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Éteint pour toi, donc tu ne peux pas le distribuer';

  @override
  String get twitchChatOverIrc => 'Chat Twitch sur IRC';

  @override
  String get twoFactorAuthentication => 'Authentification à deux facteurs';

  @override
  String get twoFactorChallengeExpired => 'défi à deux facteurs expiré';

  @override
  String get twoFactorCode => 'code à deux facteurs';

  @override
  String get twoFactorSignInCompletedBut =>
      'Connexion à deux facteurs terminée, mais NeoAgent n\'a pas pu conserver la session du navigateur. Veuillez vous reconnecter.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Connexion en deux étapes (uniquement si activée)';

  @override
  String get type => 'Tapez';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Tapez $arg1 pour confirmer';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'la saisie de texte n\'est pas prise en charge sur cette plate-forme.';

  @override
  String get typedInTheBrowser => 'Tapé dans le navigateur';

  @override
  String get typedText => 'Texte tapé';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'impossible de localiser un runtime Java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Impossible d\'ouvrir les paramètres d\'heure sur cette version.';

  @override
  String get unableToOpenWiFiSettings =>
      'Impossible d\'ouvrir les paramètres Wi-Fi sur cette version.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Impossible de conserver l\'affichage du bureau sélectionné.';

  @override
  String get unclearWhoItWasFor => 'On ne sait pas à qui c\'était';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'défait. Tapez votre nom d\'utilisateur pour confirmer.';

  @override
  String get unknownAccount => 'Compte inconnu';

  @override
  String get unknownAgent => 'Agent inconnu';

  @override
  String get unknownBrowser => 'Navigateur inconnu';

  @override
  String get unknownDevice => 'Appareil inconnu';

  @override
  String get unknownError => 'erreur inconnue';

  @override
  String get unknownLocalComputerPermission =>
      'Autorisation inconnue de l\'ordinateur local.';

  @override
  String get unknownLocation => 'Lieu inconnu';

  @override
  String get unknownPublishTime => 'Heure de publication inconnue';

  @override
  String get unknownSize => 'Taille inconnue';

  @override
  String get unlink => 'Dissocier';

  @override
  String get unreadOnly => 'Non lu uniquement';

  @override
  String get unsavedChanges => 'Modifications non enregistrées';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Commande compagnon de bureau non prise en charge : $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Méthode non prise en charge : $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Alertes de connexion inhabituelles';

  @override
  String updateArg1(Object? arg1) {
    return 'Mettre à jour $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Mettez à jour les entrées de mémoire principale à partir de l’importation.';

  @override
  String get updateNow => 'Mettre à jour maintenant';

  @override
  String get updateReady => 'Mise à jour prête';

  @override
  String get updateSetup => 'Configuration de la mise à jour';

  @override
  String get updateTheAccessListToAllow =>
      'Mettez à jour la liste d\'accès pour autoriser les réponses.';

  @override
  String get updateTheServer => 'Mettre à jour le serveur ?';

  @override
  String get updateTheServer2 => 'Mettre à jour le serveur';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Mettez à jour automatiquement le fuseau horaire depuis l\'appareil que vous utilisez.';

  @override
  String updatedArg1(Object? arg1) {
    return 'mise à jour $arg1';
  }

  @override
  String get updates => 'Mises à jour';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Les mises à jour ne sont pas configurées pour cette version.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'mises à jour, donc la mise à jour automatique et les changements de chaîne sont désactivés ici.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'mettre à jour la mise à jour publie maintenant la version bêta stable du canal';

  @override
  String get usageAnalytics => 'Analyse d\'utilisation';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Signaux d’utilisation et d’état qui aident à expliquer le comportement d’exécution actuel sans fouiller au préalable dans les journaux.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'L\'utilisation est entièrement réinitialisée dans $arg1';
  }

  @override
  String get usageLeaderboard => 'classement d\'utilisation';

  @override
  String get usageLimits => 'Utilisation et limites';

  @override
  String get usageLimits2 => 'Utilisation et limites';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Utilisez plus de 8 caractères. Les phrases secrètes plus longues fonctionnent bien.';

  @override
  String get useADateAndTimeFor =>
      'Utilisez une date et une heure, par exemple 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Utilisez un nom, un numéro de téléphone ou un identifiant de chat.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Utilisez une URL NeoRecall que le serveur NeoAgent peut atteindre. La PUBLIC_URL de NeoAgent doit également être accessible depuis ce navigateur pour le rappel OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Utilisez un nouveau mot de passe comportant au moins 8 caractères.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Utilisez une URL Nextcloud que le serveur NeoAgent peut atteindre, par exemple https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Utilisez un mot de passe d\'au moins 8 caractères.';

  @override
  String get useASecureConnectionTls =>
      'Utiliser une connexion sécurisée (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Utilisez une application d\'authentification telle que Authy, 1Password ou Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Utilisez au moins 1 processeur virtuel.';

  @override
  String get maxMemoryPerComputerMb => 'Mémoire maximale par ordinateur (Mo)';

  @override
  String get maxVcpusPerComputer =>
      'Nombre maximal de processeurs virtuels par ordinateur';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Au moins $arg1. Les ordinateurs obtiennent moins lorsque l\'hôte est occupé.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'La mémoire maximale doit être d\'au moins $arg1 Mo.';
  }

  @override
  String get useAtLeast8Characters => 'Utilisez au moins 8 caractères.';

  @override
  String get useDefault => 'Utiliser par défaut';

  @override
  String get useDefaultChannel => 'Utiliser le canal par défaut';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Utiliser la valeur par défaut (NeoAgent Workspace)';

  @override
  String get useFor => 'Utiliser pour';

  @override
  String get useManualDestination => 'Utiliser la destination manuelle';

  @override
  String get useOrDoTheSameFor =>
      'utilisez-le, ou faites de même pour vos coéquipiers.';

  @override
  String get usePerCategorySettingsBelow =>
      'Utilisez les paramètres par catégorie ci-dessous.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Utiliser les paramètres par défaut ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Utiliser le serveur sur cet ordinateur';

  @override
  String get useTheseForContextIfA =>
      'Utilisez-les pour le contexte. Si un URI local n\'est pas directement accessible depuis le serveur, demandez-moi de fournir le fichier via un espace de travail accessible.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Utilisez-le pour les agents orchestrateurs. Laissez de côté les robots de travail isolés qui devraient terminer eux-mêmes les messages directs.';

  @override
  String get useTlsFromTheStartOf =>
      'Utilisez TLS dès le début de la connexion, généralement sur le port 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Utilisez votre propre clé API pour un fournisseur ou connectez une clé personnalisée ';

  @override
  String get usedByEveryAccountOnThis =>
      'Utilisé par tous les comptes de ce serveur qui n\'ont pas de clé ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Utilisé pour vérifier que les événements Slack entrants sont authentiques.';

  @override
  String get userSummary => 'Résumé de l\'utilisateur';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get usernameOrEmail => 'Nom d\'utilisateur ou email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'utilisateurs personnes recherche email nom d\'utilisateur administrateur badge équipe gérée';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Utilise le modèle de chat configuré dans Paramètres';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Utilisation du runtime NeoAgent installé';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Ressemble généralement à @bot:matrix.org';

  @override
  String get validEmail => 'email valide';

  @override
  String get value => 'Valeur';

  @override
  String get vaultLocked => 'Coffre verrouillé';

  @override
  String get vaultOperationFailed => 'L\'opération du coffre-fort a échoué.';

  @override
  String get verification => 'Vérification';

  @override
  String verificationArg1(Object? arg1) {
    return 'Vérification : $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'vérification : $arg1';
  }

  @override
  String get verificationCompleted => 'Vérification terminée.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Statut de vérification : $arg1';
  }

  @override
  String get verifiedTheResult => 'Vérifié le résultat';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Vérification du runtime téléchargé';

  @override
  String get versionAndUptime => 'Version et disponibilité';

  @override
  String versionArg1(Object? arg1) {
    return 'Version $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'La version $arg1 est installée, mais $arg2 est toujours en cours d\'exécution.';
  }

  @override
  String get videoLinks => 'Liens vidéo';

  @override
  String get viewDesktop => 'Afficher le bureau';

  @override
  String get viewLastRun => 'Afficher la dernière exécution';

  @override
  String get viewLogs => 'Afficher les journaux';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'mémoire d\'image vm processeur qemu runtime';

  @override
  String get voice => 'Voix';

  @override
  String get voiceAssistant => 'Assistant vocal';

  @override
  String get voiceCall => 'APPEL VOCAL';

  @override
  String get voiceCall2 => 'Appel vocal';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'appel vocal gpt-live gemini live model discours en temps réel';

  @override
  String get voiceCallsRunOnALive =>
      'Les appels vocaux s\'exécutent sur un modèle de synthèse vocale en direct avec le même personnage, la même mémoire et le même historique de discussion que NeoAgent. Il répond immédiatement et confie un véritable travail à l\'agent normal, qui continue de fonctionner en arrière-plan.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'Clé API de transcription vocale de notes vocales';

  @override
  String get voiceNotesAndDictation => 'Notes vocales et dictée';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'La lecture vocale n\'est pas disponible sur cet appareil.';

  @override
  String get voiceReplyModel => 'Modèle de réponse vocale';

  @override
  String get waitingForApproval => 'En attente d\'approbation : ';

  @override
  String get waitingForCode => 'En attente de code';

  @override
  String get waitingForInput => 'En attente de contribution';

  @override
  String get waitingForServerOrFlutterLog =>
      'En attente de la sortie du serveur ou du journal Flutter…';

  @override
  String get waitingForTaskEvents => 'En attente des événements de tâche...';

  @override
  String get waitingForYou => 'je t\'attends';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Je voulais une réponse de $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Veut vous parler · ${arg1}s';
  }

  @override
  String get weak => 'Faible';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Météo, calendrier et priorités avant le début de votre journée.';

  @override
  String get weatherEvent => 'Événement météorologique';

  @override
  String get web => 'Internet';

  @override
  String get webBrowser => 'Navigateur Internet';

  @override
  String get webSearchApiKey => 'clé API de recherche sur le Web';

  @override
  String get webhookOrRestChannelPosting =>
      'Publication de webhook ou de canal REST';

  @override
  String get webhookSecret => 'Secret du webhook';

  @override
  String get webhookUrlCopied => 'URL du webhook copiée';

  @override
  String get weekdays => 'En semaine';

  @override
  String get weekdays0730 => 'En semaine · 07h30';

  @override
  String get weekdays1800 => 'En semaine · 18h00';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Limite hebdomadaire $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Limite hebdomadaire (jetons)';

  @override
  String get weeklyReview => 'Revue hebdomadaire';

  @override
  String get weeklyUsage => 'Utilisation hebdomadaire';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Poids des enregistrements $arg1';
  }

  @override
  String get welcomeToNeoagent => 'BIENVENUE CHEZ NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Bienvenue\nsur NeoAgent';

  @override
  String get whatAreYouAdding => 'Qu\'est-ce que tu ajoutes ?';

  @override
  String get whatIsOnTomorrow => 'Qu\'est-ce qu\'il y a demain ?';

  @override
  String get whatShouldNeoagentLearn => 'Que doit apprendre NeoAgent ?';

  @override
  String get whatShouldWeBuild => 'Que devons-nous construire ?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Ce que vous et NeoAgent dites apparaît ici et dans le chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Message personnel WhatsApp reçu';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Lorsque vous choisissez Approuvé uniquement, ajoutez des personnes ou des groupes ci-dessous.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Où cet agent doit envoyer les réponses.';

  @override
  String get whoCanMessage => 'Qui peut envoyer un message';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Qui peut envoyer des messages sur $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Qui peut envoyer à $arg1 un message individuel.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Qui peut parler à $arg1 dans un groupe, une chaîne ou une salle.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'qui gère ce compte désactivé : ';

  @override
  String get whoManagesWhom => 'Qui gère qui';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Celui qui accepte un lien rejoint votre équipe avec uniquement les outils dont il dispose ';

  @override
  String get wholeGroup => 'Groupe entier';

  @override
  String get wholeGroups => 'Des groupes entiers';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Pourquoi $arg1 a répondu ou est resté silencieux dans les groupes $arg2.';
  }

  @override
  String get windowsApp => 'Application Windows';

  @override
  String get windowsNt => 'Windows NT';

  @override
  String get workAccount => 'Compte professionnel';

  @override
  String get workOnAProjectWithNeoagent =>
      'Travailler sur un projet avec NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Flux de travail : $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Travailler dans $arg1 sur l\'ordinateur cloud. NeoAgent y lit et édite des fichiers et peut exécuter des commandes et un navigateur.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Travailler en arrière-plan : $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Configuration de l\'espace de travail et sécurité des comptes en un seul endroit.';

  @override
  String get workspaceFiles => 'Fichiers de l\'espace de travail';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Espace de travail, modèles et contrôles de diagnostic.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Le remplacement de l\'espace de travail doit être un chemin absolu.';

  @override
  String wroteArg1(Object? arg1) {
    return 'A écrit $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'erreur xmlhttprequest';

  @override
  String get yesterday => 'Hier';

  @override
  String get youAreInControl => 'Vous êtes en contrôle';

  @override
  String get youCanFollowAlongOnThe => 'Vous pouvez suivre sur le bureau.';

  @override
  String get youCanLeaveATeamAt =>
      'Vous pouvez quitter une équipe à tout moment ; vos propres paramètres s\'appliquent à nouveau.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Vous pouvez partir à tout moment depuis la page Equipe.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Vous décidez quels outils votre agent peut utiliser, sous Paramètres › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Vous ne dirigez encore personne. Créez un lien d\'invitation ci-dessous et ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Vous avez des paramètres non enregistrés. Qu\'aimeriez-vous faire ?';

  @override
  String get youReOnYourOwnYou =>
      'Vous êtes seul : vous décidez quels outils votre agent peut utiliser. Si ';

  @override
  String get yourAccountAndUsageOnA =>
      'votre compte - et utilisation sur un modèle soutenu par votre propre clé ';

  @override
  String get yourAccountHasBeenDeleted => 'Votre compte a été supprimé.';

  @override
  String get yourAgentWillBeAllowed => 'Votre agent sera autorisé :';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Vos applications et fichiers sont enregistrés.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Vos applications et fichiers restent enregistrés.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Votre clé $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Votre couche assistante pour la capture, le contexte et l\'action.';

  @override
  String get yourComputerIsAsleep => 'Votre ordinateur est en veille';

  @override
  String get yourComputerIsOff => 'Votre ordinateur est éteint';

  @override
  String get yourComputerIsReady => 'Votre ordinateur est prêt';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Votre mot de passe actuel est incorrect.';

  @override
  String get yourData => 'Vos données';

  @override
  String get yourDataExportWasCopiedTo =>
      'Votre exportation de données a été copiée dans le presse-papiers.';

  @override
  String get yourDesktopIsReady => 'Votre bureau est prêt';

  @override
  String get yourLinuxComputer => 'Votre ordinateur Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Votre localisation n\'est jamais suivie en continu ni stockée sur nos serveurs. Nous l\'utilisons uniquement localement pour vérifier vos tâches actives.';

  @override
  String get yourManager => 'votre manager';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'L\'URL de votre site Mattermost, si vous utilisez l\'API REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Votre session a expiré ou n\'a pas été conservée par le navigateur. Veuillez vous reconnecter.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Votre nom d\'utilisateur ou votre mot de passe est incorrect.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personnel';

  @override
  String get sectionOverview => 'Aperçu';

  @override
  String get sectionDiagnostics => 'Diagnostic';

  @override
  String get sectionVolume => 'Volume';

  @override
  String get sectionSession => 'Séance';

  @override
  String get sectionDeliverable => 'Livrable';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Le moteur d\'exécution local n\'a pas encore écrit de fichier journal.';

  @override
  String get thisComputer => 'Cet ordinateur';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'La version bêta installe le dernier backend préliminaire. Attendez-vous à des aspérités.';

  @override
  String get copiedFinalResponse => 'Réponse finale copiée';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'La réponse finale apparaît ici une fois l\'exécution terminée.';

  @override
  String get waitingForTheFirstStep => 'En attendant la première étape…';

  @override
  String get loadingPrompt => 'Invite de chargement…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Aucune réponse finale n\'a été capturée pour cette exécution.';

  @override
  String get readyToSignIn => 'Prêt à vous connecter';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Passez à « Par défaut » ou « Toujours demander » pour réactiver les contrôles d\'approbation.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Envoyer une mise à jour du pilotage ou une note suivante pour l\'exécution en cours...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Aucune connexion réseau. NeoAgent se reconnectera lorsque l\'appareil sera de nouveau en ligne.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Application de la dernière mise à jour du pilotage à l\'exécution en cours.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Préparation de la séance vocale privée…';

  @override
  String get preparingYourComputer => 'Préparation de votre ordinateur';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent télécharge et prépare le système Linux sécurisé. Cela n\'arrive que la première fois.';

  @override
  String get moreFreeSpaceIsNeeded => 'Plus d\'espace libre est nécessaire';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Libérez de l\'espace disque sur l\'hôte NeoAgent, puis réessayez. Vos données informatiques existantes sont en sécurité.';

  @override
  String get androidReady => 'Prêt pour Android';

  @override
  String get startingAndroid2 => 'Démarrage d’Android…';

  @override
  String get androidStopped => 'Android s\'est arrêté';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Le premier démarrage télécharge le SDK Android et l\'image système, ce qui peut prendre plusieurs minutes.';

  @override
  String get androidIsStopped => 'Android est arrêté';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Démarrez l\'environnement Android géré lorsque vous en avez besoin.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Laisser NeoAgent travailler sur cet ordinateur';

  @override
  String get firstTimeSetupIsInProgress =>
      'La première configuration est en cours.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent peut utiliser l\'accès que vous autorisez.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Libérez de l\'espace de stockage sur l\'hôte et réessayez.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Commencez lorsque vous souhaitez que NeoAgent vous aide ici.';

  @override
  String get systemPermissionMissing => 'Autorisation système manquante';

  @override
  String get connectingThisDevice => 'Connexion de cet appareil';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'La connexion locale sécurisée est en cours d\'établissement.';

  @override
  String get recordingYourDemonstration => 'Enregistrer votre démonstration';

  @override
  String get noErrorsInTheRecentLog => 'Aucune erreur dans le journal récent.';

  @override
  String get loadingAccounts => 'Chargement des comptes…';

  @override
  String get neverSignedIn => 'Jamais connecté';

  @override
  String get emptyUsesTheServerDefault =>
      'Empty utilise la valeur par défaut du serveur.';

  @override
  String get followTheSelectedSession => 'Suivre la séance sélectionnée';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Le mode Plan inspecte uniquement. Passez en mode Agent pour laisser NeoAgent éditer les fichiers.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Obligatoire pour ajouter ou modifier l\'adresse e-mail de votre compte.';

  @override
  String get confirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get passwordChanged => 'Mot de passe modifié.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Cette demande a déjà été utilisée.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Cette demande a expiré. Demandez à l\'autre appareil de générer un nouveau code.';

  @override
  String get startQuickstart => 'Démarrer le démarrage rapide';

  @override
  String get createYourAccount => 'Créez votre compte';

  @override
  String get showWorkAsSummaries => 'Afficher le travail sous forme de résumés';

  @override
  String get tokensUsedByTheLatestRun =>
      'Jetons utilisés par la dernière exécution';

  @override
  String get listedTheWorkspaceRoot =>
      'Répertorié la racine de l\'espace de travail';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Aucune intégration officielle n\'est encore disponible.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Aucun serveur MCP configuré pour le moment. Ajoutez-en un pour exposer ses outils.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Ajoutez un serveur MCP ou installez une compétence pour commencer.';

  @override
  String get setUp => 'Configurer';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Laisser vide pour conserver la valeur stockée';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Cela supprime l\'adresse de chaque compte sur ce serveur.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Parlez simplement. Vous pouvez interrompre à tout moment. Appuyez pour désactiver le son.';

  @override
  String get tapAgainWhenYouAreDone =>
      'Appuyez à nouveau lorsque vous avez terminé.';

  @override
  String get workingOnATaskInTheBackground =>
      'Travailler sur une tâche en arrière-plan.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Synthèse vocale avec la même mémoire, les mêmes outils et le même historique de discussion que NeoAgent.';

  @override
  String get checkLink => 'Vérifier le lien';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Votre agent ne sera autorisé à aucun des outils contrôlés.';

  @override
  String get notYoursToChange => 'Ce n\'est pas à toi de changer';

  @override
  String get setByYou => 'Fixé par vous';

  @override
  String get noTools => 'Aucun outil';

  @override
  String get untitledLink => 'Lien sans titre';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Arrête de fonctionner après qu\'une personne l\'ait racheté.';

  @override
  String get theOperator => 'L\'opérateur';

  @override
  String get smartSelectorOn => 'Sélecteur intelligent activé';

  @override
  String get startASessionToBegin => 'Démarrer une session pour commencer';

  @override
  String get steerTheActiveRun => 'Pilotez la course active…';

  @override
  String get describeWhatToPlan => 'Décrivez ce qu’il faut planifier…';

  @override
  String get stopDictation => 'Arrêter la dictée';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Les messages guident l\'exécution en cours · ⌘↵ envoyer · ⌘. arrêter';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Le mode Plan inspecte uniquement ; rien n\'est changé jusqu\'à ce que vous implémentiez · ⌘↵ envoyer';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'L\'agent modifie l\'espace de travail. Plan inspecte uniquement.';

  @override
  String get defaultModel => 'Modèle par défaut';

  @override
  String get openingScanner => 'Ouverture du scanner...';

  @override
  String get theAgentCanUseThisSkill =>
      'L\'agent peut utiliser cette compétence.';

  @override
  String get allSelected => 'Tous sélectionnés';

  @override
  String get addCoreMemoryEntry => 'Ajouter une entrée de mémoire principale';

  @override
  String get channelId => 'ID de chaîne';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Les tâches créées par l\'IA et non spécifiées utilisent la valeur par défaut actuelle.';

  @override
  String get waitingForRunEvents => 'En attente des événements d\'exécution...';

  @override
  String get hideSteps => 'Masquer les étapes';

  @override
  String get commitTheActiveLiveCapture =>
      'Valider la capture active en direct';

  @override
  String get stopCaptureAndSubmit => 'Arrêtez la capture et soumettez';

  @override
  String get clickTheMicToStartSpeaking =>
      'Cliquez sur le micro pour commencer à parler';

  @override
  String get connectACustomEndpoint =>
      'Connecter un point de terminaison personnalisé';

  @override
  String get hostedProvider => 'fournisseur hébergé.';

  @override
  String get muted => ' • en sourdine';

  @override
  String get addWhoCanMessage => 'Ajouter qui peut envoyer un message';

  @override
  String get joinsGroupConversations => 'Rejoint les conversations de groupe';

  @override
  String get label1PersonOrGroupAdded => '1 personne ou groupe ajouté';

  @override
  String get inProgress => 'En cours';

  @override
  String get waitingForUpdateJobOutput =>
      'En attente de la sortie de la tâche de mise à jour…';

  @override
  String get taskTrigger => 'Déclencheur de tâche';

  @override
  String get bearerToken => 'Jeton du porteur';

  @override
  String get bearerToken2 => 'Jeton du porteur';

  @override
  String get notRecorded => 'Non enregistré';

  @override
  String get sessionCookie => 'Cookie de session';

  @override
  String get neverUsed => 'Jamais utilisé';

  @override
  String get linkedRecently => 'Lié récemment';

  @override
  String get notUsedYet => 'Pas encore utilisé';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Un ou plusieurs comptes ont expiré. Reconnectez-vous pour restaurer l’accès. Si cela continue, votre application Google Cloud OAuth est peut-être en mode Test : publiez-la en production dans Google Cloud Console pour obtenir des jetons à longue durée de vie.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault connecté et disponible après le redémarrage';

  @override
  String get vaultConnectedForThisSession =>
      'Vault connecté pour cette session';

  @override
  String get connectAnotherAccount => 'Connecter un autre compte';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Coller le jeton d\'accès longue durée de remplacement';

  @override
  String get updateInstance => 'Mettre à jour l\'instance';

  @override
  String get pasteAReplacementToken => 'Collez un jeton de remplacement';

  @override
  String get replaceAccount => 'Remplacer le compte';

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Peut déléguer à n’importe quel agent réceptionnaire';

  @override
  String get canReceiveDelegatedTasks2 => 'peut recevoir des tâches déléguées';

  @override
  String get noSyncYet => 'Pas encore de synchronisation';

  @override
  String get noNewData => 'Aucune nouvelle donnée';

  @override
  String get syncOnceToSeedYourBackend =>
      'Synchronisez une fois pour amorcer votre backend.';

  @override
  String get lastWindowEndIsUnknown =>
      'La fin de la dernière fenêtre est inconnue.';

  @override
  String get lastNonEmptySync => 'Dernière synchronisation non vide';

  @override
  String get stopTranscribe => 'Arrêter et transcrire';

  @override
  String get steeringMode => 'Mode de pilotage';

  @override
  String get noMessageText => 'Aucun texte de message';

  @override
  String get reconnectingToServer => 'Reconnexion au serveur…';

  @override
  String get signingIn => 'Connexion...';

  @override
  String get noGroupsFoundYet => 'Aucun groupe trouvé pour l\'instant';

  @override
  String get onForNewGroupsOnly =>
      'Activé uniquement pour les nouveaux groupes';

  @override
  String get noGroupsInThisCategory => 'Aucun groupe dans cette catégorie';

  @override
  String get groupOrChannel => 'Groupe ou canal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Les notes que vous vous écrivez démarrent une course et les réponses atterrissent dans le même chat. La liste blanche ne s\'applique pas ici.';

  @override
  String get needToReply => 'Besoin de répondre';

  @override
  String get enter2faCode => 'Entrez le code 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Ouvrez votre application d\'authentification et entrez le code NeoAgent actuel.';

  @override
  String get alreadyHaveAnAccountSignIn =>
      'Vous avez déjà un compte ? Connectez-vous';

  @override
  String get serverOnThisComputer => 'Serveur sur cet ordinateur';

  @override
  String get showQrCode => 'Afficher le code QR';

  @override
  String get createAnotherNeoagentAccount => 'Créez un autre compte NeoAgent.';

  @override
  String get canCoordinateDelegatedWork => 'Peut coordonner le travail délégué';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'L\'archive d\'exécution de NeoAgent n\'a pas pu être extraite.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'L\'archive d\'exécution de NeoAgent n\'a pas pu être lue.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'L\'archive d\'exécution de NeoAgent contient un chemin non sécurisé.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'L\'archive d\'exécution de NeoAgent contient un lien dangereux.';

  @override
  String get installingAppPackageOnThePhone =>
      'Installation du package d\'application sur le téléphone...';

  @override
  String get dragAndDropAApkOrApks =>
      'Faites glisser et déposez un fichier .apk ou .apks ici, ou cliquez pour parcourir.';

  @override
  String get releaseToInstallThisPackage => 'Release pour installer ce package';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'La clé de sécurité n\'a pas pu être utilisée.';

  @override
  String get connecting => 'Connexion…';

  @override
  String get changes => 'Changements';

  @override
  String get runtimeReady => 'Prêt pour l\'exécution';

  @override
  String get saving => 'Sauvegarde...';

  @override
  String get earlier => 'Plus tôt';

  @override
  String get monthJan => 'janvier';

  @override
  String get monthFeb => 'Février';

  @override
  String get monthMar => 'mars';

  @override
  String get monthApr => 'avril';

  @override
  String get monthMay => 'mai';

  @override
  String get monthJun => 'juin';

  @override
  String get monthJul => 'juillet';

  @override
  String get monthAug => 'Août';

  @override
  String get monthSep => 'septembre';

  @override
  String get monthOct => 'octobre';

  @override
  String get monthNov => 'novembre';

  @override
  String get monthDec => 'décembre';

  @override
  String get steeringWord => 'Direction';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Cela fait passer le backend du canal $arg1 au canal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Cookies $arg1 importés';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Il y a $arg1';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Direction en file d\'attente : $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'L\'application Web n\'a pas pu atteindre le backend NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Le navigateur a bloqué une requête requise en raison de la politique de sécurité du contenu.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 sur 4 autorisé';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Accomplissez la tâche comme vous le feriez normalement.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Modifications · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Cet appareil · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limite atteinte$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Les codes de récupération $arg1 sont toujours disponibles.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Clé de sécurité $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Session en cours';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nDernière utilisation : $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Travailler dans $arg1 sur cet appareil. NeoAgent lit et modifie le dossier directement et peut exécuter des commandes, ouvrir des applications et utiliser l\'écran.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'A travaillé pour $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Autorisé par $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Les liens d\'invitation $arg1 de $arg2 ont été révoqués';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Ajouter les personnes et les groupes avec lesquels $arg1 doit parler';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Ajoutez les personnes et les groupes avec lesquels $arg1 est autorisé à parler.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Où $arg1 écoute';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 surveille ces lieux à la recherche de mentions. Tout le monde peut publier ici, les gens ont donc toujours besoin de leur propre approbation ci-dessous.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Ces personnes peuvent demander à $arg1 partout où elles le marquent. Les rôles comptent uniquement dans les endroits indiqués ci-dessus.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Uniquement lorsque $arg1 est étiqueté';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Activé pour tous les groupes $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 n\'entend toujours que les personnes et les groupes que vous avez déjà approuvés. Cela permet simplement à $arg1 de rejoindre le chat ordinaire, pas seulement les balises et les réponses.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 n\'entend toujours que les personnes et les groupes que vous avez déjà approuvés. Cela choisit simplement lequel de ces groupes il doit rejoindre.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Si quelqu\'un tague $arg1 ou répond, $arg1 répond toujours. Activez cette option si $arg1 doit également intervenir dans une discussion de groupe ordinaire.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Les nouveaux groupes permettront à $arg1 de rejoindre une discussion ordinaire avec des personnes approuvées, jusqu\'à ce que vous les désactiviez.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Les nouveaux groupes permettront à $arg1 de rejoindre le chat ordinaire jusqu\'à ce que vous les désactiviez.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Les nouveaux groupes restent silencieux à moins qu\'une personne approuvée n\'identifie $arg1, jusqu\'à ce que vous les activiez.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Uniquement lorsqu\'une personne approuvée identifie $arg1, sauf si vous activez un groupe';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Uniquement lorsque $arg1 est étiqueté, sauf si vous activez un groupe';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return 'Les groupes $arg1 des groupes $arg2 rejoignent le chat ordinaire avec des personnes approuvées';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Cela n\'approuve pas les nouvelles personnes. Les balises et les réponses des personnes approuvées reçoivent toujours une réponse. Activez un groupe si $arg1 doit également y rejoindre le chat ordinaire.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Cela n\'approuve pas les nouvelles personnes. Activez un groupe si $arg1 doit rejoindre une discussion ordinaire avec des personnes que vous avez déjà approuvées.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Les balises et les réponses reçoivent toujours une réponse. Activez un groupe si $arg1 doit également y rejoindre le chat ordinaire.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 rejoint le chat ordinaire avec des personnes approuvées';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 peut rejoindre un chat ordinaire';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 ne répond que lorsqu\'une personne autorisée l\'identifie';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Rien de plus n\'est nécessaire. Connectez-vous pour commencer à utiliser $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Actualisation dans les $arg1';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Inscrivez-vous sur $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Aucun souvenir lié à \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (par défaut)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Branche : $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 rejoint uniquement les groupes et chaînes que vous ajoutez ci-dessous.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 est requis pour localiser les données d’exécution de NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[aperçu tronqué, total d\'octets $arg1]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefact délimité, total d\'octets $arg1]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' dans $arg1';
  }

  @override
  String get worldNews => 'Nouvelles du monde';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Courez lorsque de nouveaux titres mondiaux apparaissent. Votre invite décide s\'il convient de vous avertir.';

  @override
  String get newsKeywordsOptional => 'Mots-clés (facultatif)';

  @override
  String get worldNewsSetup => 'Configuration des actualités mondiales';

  @override
  String get connectWorldNewsWithGnews =>
      'Ajoutez une clé API GNews (plan gratuit disponible sur gnews.io). Il est stocké crypté et utilisé pour interroger les principaux titres des déclencheurs de World News.';

  @override
  String get gnewsApiKey => 'Clé API GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Coller la clé API GNews de remplacement';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Laissez la clé vide pour conserver la clé actuellement stockée.';

  @override
  String get gnewsApiKeyIsRequired => 'Une clé API GNews est requise.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Impossible d\'enregistrer la configuration de World News.';

  @override
  String get disconnectWorldNews => 'Déconnecter l\'actualité mondiale';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Cela supprime la clé API GNews stockée. Les déclencheurs de World News cesseront de se déclencher jusqu\'à ce que vous ajoutiez à nouveau une clé.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Impossible de déconnecter World News.';

  @override
  String get systemOneModels => 'Modèles SystemOne';

  @override
  String get systemOneAuto => 'Automatique';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Sélectionne le meilleur modèle SystemOne disponible';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Le modèle de chat prend ces décisions';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Des modèles de décision qui effectuent des appels en coulisses en une fraction de seconde : tour de discussion en groupe et étapes du navigateur. Votre modèle de chat écrit toujours chaque réponse.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Le modèle SystemOne décide quand parler lorsqu\'il est allumé ; ce modèle est la solution de repli.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 noté par SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne a noté ce message directement. Aucun modèle de langage n\'a été exécuté.';

  @override
  String get systemOneUnavailable => 'SystemOne indisponible';

  @override
  String get systemOneAdminAvailability =>
      'Les agents peuvent choisir des modèles de décision sous Paramètres > Modèles. Un modèle désactivé ici quitte ce sélecteur et les agents qui l\'ont choisi reviennent à Auto. Lorsqu\'un modèle est désactivé, les modèles SystemOne que les fournisseurs ajoutent plus tard démarrent également.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Aucun modèle SystemOne pour l’instant. Ajoutez une clé TypeSafe ou OpenRouter sous Fournisseurs, ou extrayez un modèle de décision tel que agile dans Ollama 0.35 ou version ultérieure.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Aucun modèle SystemOne n’est encore disponible. Ajoutez une clé TypeSafe ou OpenRouter sous Paramètres › Modèles › Apportez votre propre clé ou extrayez un modèle de décision tel que agile dans Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one décision modèles jev typesafe openrouter ollama disponibilité activer désactiver';

  @override
  String get chatModels => 'Modèles de discussion';

  @override
  String get disabled => 'Désactivé';

  @override
  String get enableShown => 'Activer affiché';

  @override
  String get disableShown => 'Désactiver affiché';

  @override
  String get expandAll => 'Tout développer';

  @override
  String get collapseAll => 'Tout réduire';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return 'Modifications non enregistrées $arg1';
  }

  @override
  String get settingsScopeAllAgents => 'Tous les agents';

  @override
  String get settingsScopeAgent => 'Cet agent';

  @override
  String get settingsScopeApp => 'Application';

  @override
  String get settingsScopeAccountHint => 'Idem partout où vous vous connectez';

  @override
  String get settingsScopeAllAgentsHint => 'Partagé par tous vos agents';

  @override
  String get settingsAppliesTo => 'S\'applique à';

  @override
  String get settingsSaving => 'Sauvegarde…';

  @override
  String get settingsSavedAutomatically =>
      'Les modifications sont enregistrées automatiquement';

  @override
  String get settingsSearchHint => 'Rechercher tous les paramètres';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Connexion et sécurité';

  @override
  String get settingsPageUsage => 'Utilisation';

  @override
  String get settingsPagePermissions => 'Autorisations';

  @override
  String get settingsPageComputer => 'Informatique et Internet';

  @override
  String get settingsPageBehavior => 'Comportement';

  @override
  String get settingsPageSystem => 'Système';

  @override
  String get settingsPagePlatforms => 'Plateformes';

  @override
  String get settingsPageProfileDescription =>
      'Votre nom et votre e-mail, une copie de vos données et votre déconnexion.';

  @override
  String get settingsPageSecurityDescription =>
      'Mot de passe, authentification à deux facteurs, clés de sécurité et où vous êtes connecté.';

  @override
  String get settingsPageUsageDescription =>
      'Vos limites et vos dépenses symboliques, le tout au même endroit.';

  @override
  String get settingsPageAgentsDescription =>
      'Créez des agents et choisissez celui qui répond par défaut.';

  @override
  String get settingsPagePermissionsDescription =>
      'Ce que vos agents peuvent faire sans vous le demander au préalable.';

  @override
  String get settingsPageComputerDescription =>
      'L\'ordinateur sur lequel vos agents travaillent et les sites qu\'ils peuvent lire en même temps que vous.';

  @override
  String get settingsPageModelsDescription =>
      'Quels modèles cet agent utilise-t-il et quelles clés API les financent.';

  @override
  String get settingsPageBehaviorDescription =>
      'Comment cet agent parle et comment il lit une discussion de groupe.';

  @override
  String get settingsPageVoiceDescription =>
      'Appels en direct, dictée et réponses vocales pour cet agent.';

  @override
  String get settingsPageMessagingDescription =>
      'Où les gens peuvent joindre cet agent et comment il se comporte dans les discussions.';

  @override
  String get settingsPageGeneralDescription =>
      'Apparence, langue, fuseau horaire et ce que fait cette application en arrière-plan.';

  @override
  String get settingsPageSystemDescription =>
      'Le serveur utilisé par cette fenêtre, celui de cet ordinateur et les mises à jour de l\'application.';

  @override
  String get settingsYourAgents => 'Vos agents';

  @override
  String get settingsChatModel => 'Modèle de discussion';

  @override
  String get settingsChatModelDescription => 'Répond à vos messages.';

  @override
  String get settingsSubAgentModel => 'Modèle de sous-agent';

  @override
  String get settingsSubAgentModelDescription =>
      'Exécute le travail transféré au cours d’une tâche.';

  @override
  String get settingsDefaultModels => 'Modèles par défaut';

  @override
  String get settingsDefaultModelsDescription =>
      'Utilisé chaque fois qu\'une discussion ou une tâche ne choisit pas son propre modèle.';

  @override
  String get settingsModelPool => 'Piscine modèle';

  @override
  String get settingsApiKeysDescription =>
      'Utilisez vos propres clés ou point de terminaison pour cet agent. Les clés sont cryptées et ne sont plus jamais affichées.';

  @override
  String get settingsPersona => 'Personnalité';

  @override
  String get settingsFineTuning => 'Mise au point';

  @override
  String get settingsFineTuningDescription =>
      'Rarement nécessaire. Les valeurs par défaut conviennent à la plupart des discussions.';

  @override
  String get settingsShow => 'Afficher';

  @override
  String get settingsHide => 'Masquer';

  @override
  String get settingsMinimumContribution => 'Valeur minimale de cotisation';

  @override
  String get settingsBatchWindow => 'Fenêtre de lot de pièces';

  @override
  String get settingsBatchWindowDescription =>
      'Attend aussi longtemps pour traiter les messages rapides comme un seul tour.';

  @override
  String get settingsHandsFree => 'Mains libres';

  @override
  String get settingsHandsFreeDescription =>
      'Parlez librement et interrompez à tout moment.';

  @override
  String get settingsPushToTalkDescription =>
      'Tenez pour parler, relâchez pour envoyer.';

  @override
  String get settingsLiveVoice => 'Voix en direct';

  @override
  String get settingsChannels => 'Canaux';

  @override
  String get settingsGroupChats => 'Dans les discussions de groupe';

  @override
  String get settingsGroupChatsDescription =>
      'Comment cet agent se comporte en groupes sur chaque canal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Activez les modules de comportement dans Behaviour pour les modifier.';

  @override
  String get settingsParticipationAutomatic => 'Automatique';

  @override
  String get settingsParticipationMentionOnly => 'Mentionner seulement';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Lit la pièce et la rejoint lorsqu\'elle a quelque chose d\'utile à ajouter.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Répond uniquement lorsqu\'il est mentionné ou répondu.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Répond à chaque message.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Divise les réponses plus longues en messages courts, comme le ferait une personne.';

  @override
  String get settingsDeliverySingleDescription =>
      'Envoie chaque réponse sous forme d\'un seul message.';

  @override
  String get settingsComputerStatus => 'Statut';

  @override
  String get settingsTest => 'Tester';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsCloseWindow => 'Quand tu fermes la fenêtre';

  @override
  String get settingsCloseAsk => 'Demander';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent continue de fonctionner en arrière-plan et reste joignable.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent se ferme complètement.';

  @override
  String get settingsPhoneTriggers => 'Déclencheurs téléphoniques';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signaux que ce téléphone envoie à vos agents afin que les tâches puissent y réagir.';

  @override
  String get settingsLocationTriggers => 'Déclencheurs de localisation';

  @override
  String get settingsLocationTriggersDescription =>
      'Vérifie votre position approximative toutes les quelques minutes par rapport aux endroits surveillés par vos tâches.';

  @override
  String get settingsNotificationTriggers => 'Déclencheurs de notifications';

  @override
  String get settingsNotificationTriggersDescription =>
      'Transfère les notifications d\'autres applications sur ce téléphone à vos agents.';

  @override
  String get settingsSetup => 'Configuration';

  @override
  String get settingsOnboarding => 'Intégration';

  @override
  String get settingsOnboardingDescription =>
      'Parcourez à nouveau la configuration de première exécution. Rien de ce que vous avez configuré n\'est perdu.';

  @override
  String get settingsUsernameDescription =>
      'Utilisé pour se connecter. Il ne peut pas être modifié.';

  @override
  String get settingsExport => 'Exporter';

  @override
  String get settingsLeave => 'Déconnectez-vous et supprimez';

  @override
  String get settingsSignOutDescription =>
      'Vous déconnecte uniquement sur cet appareil.';

  @override
  String get settingsDeleteAccountDescription =>
      'Efface votre compte, vos agents, votre mémoire et vos paramètres. Cela ne peut pas être annulé.';

  @override
  String get settingsTokenUsage => 'Utilisation des jetons';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Aucun paramètre ne correspond à « $query ».';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '$count résultat',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Paramètres avancés du modèle';

  @override
  String get settingsAdvancedModelsDescription =>
      'Facultatif. Épinglez un modèle à un type de travail ; il prend le relais chaque fois que l\'agent utilise ces outils. Tout ce qui reste par défaut suit le modèle de chat.';

  @override
  String get settingsTaskModelDefault => 'Par défaut';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Suit le modèle de chat';

  @override
  String get settingsTaskModelCoding => 'Codage';

  @override
  String get settingsTaskModelCodingDescription =>
      'Écriture, édition et débogage de code.';

  @override
  String get settingsTaskModelComputerUse => 'Utilisation de l\'ordinateur';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Piloter le navigateur et le bureau.';

  @override
  String get settingsTaskModelAndroidUse => 'Utilisation d\'Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Utiliser des applications sur un appareil ou un émulateur Android.';

  @override
  String get settingsTaskModelResearch => 'Recherche';

  @override
  String get settingsTaskModelResearchDescription =>
      'Rechercher, lire et résumer des sources.';

  @override
  String get knowledgeGraphHint =>
      'Vos entités les plus mentionnées, colorées par cluster. Les lignes relient des entités qui apparaissent dans les mêmes mémoires. Appuyez sur l\'un d\'entre eux pour voir ses liens et ses souvenirs ; faites glisser pour effectuer un panoramique, pincer ou Ctrl/⌘-faire défiler pour zoomer.';

  @override
  String get linkedEntities => 'Entités liées';

  @override
  String get noLinkedEntities => 'Pas encore lié à d\'autres entités.';

  @override
  String mentionsArg1(int arg1) {
    return '${arg1}mentionne';
  }

  @override
  String get entityKindConcept => 'Concept';

  @override
  String get entityKindDomain => 'Domaine';

  @override
  String get entityKindEmail => 'Courriel';

  @override
  String get entityKindLink => 'Lien';

  @override
  String get entityKindFile => 'Fichier';

  @override
  String get entityKindAcronym => 'Acronyme';

  @override
  String get entityKindIdentifier => 'Identifiant';

  @override
  String get entityKindVersion => 'Version';

  @override
  String get openFullscreen => 'Ouvrir en plein écran';

  @override
  String get zoomIn => 'Zoomer';

  @override
  String get zoomOut => 'Zoom arrière';

  @override
  String get searchEntities => 'Trouver une entité';

  @override
  String get incomingCall => 'Appel entrant';

  @override
  String get answerCall => 'Réponse';

  @override
  String get callMeLater => 'Appelle-moi plus tard';

  @override
  String get callingEllipsis => 'Appel…';

  @override
  String get reconnectingCall => 'Reconnexion';

  @override
  String get agentWorking => 'Travailler';

  @override
  String get micMuted => 'En sourdine';

  @override
  String get speakerphone => 'Haut-parleur';

  @override
  String get muteMic => 'Muet';

  @override
  String get unmuteMic => 'Activer le son';

  @override
  String get releaseToSend => 'Libérer pour envoyer';

  @override
  String get callEnded => 'Appel terminé';

  @override
  String get openConversation => 'Conversation ouverte';

  @override
  String get callBack => 'Rappeler';

  @override
  String get letCallsReachYou => 'Laissez les appels vous parvenir';

  @override
  String get callPermissionsIntro =>
      'Vos agents peuvent vous appeler. Pour sonner comme un appel téléphonique lorsque NeoAgent est en arrière-plan ou que votre téléphone est verrouillé, il en a besoin.';

  @override
  String get showOverOtherApps => 'Afficher sur d\'autres applications';

  @override
  String get showOverOtherAppsDetail =>
      'Affiche l\'écran d\'appel où que vous soyez.';

  @override
  String get fullScreenCalls => 'Appels en plein écran';

  @override
  String get fullScreenCallsDetail => 'Sonne sur l\'écran de verrouillage.';

  @override
  String get unrestrictedBattery => 'Batterie sans restriction';

  @override
  String get unrestrictedBatteryDetail =>
      'Maintient NeoAgent connecté pour que les appels arrivent.';

  @override
  String get permissionAllowed => 'Autorisé';

  @override
  String get triggerSectionCalendar => 'Calendrier';

  @override
  String get triggerSectionFiles => 'Fichiers et documents';

  @override
  String get triggerSectionHome => 'Maison et médias';

  @override
  String get triggerSectionDevices => 'Appareils et lieux';

  @override
  String get triggerSectionTasks => 'Tâches';

  @override
  String get messagingMemberJoined => 'Membre rejoint';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'S\'exécute lorsque quelqu\'un rejoint un serveur Discord, un groupe Telegram ou WhatsApp, une chaîne Slack ou une salle Matrix.';

  @override
  String get messagingMemberLeft => 'Membre parti';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Exécuté lorsque quelqu\'un quitte un serveur Discord, un groupe Telegram ou WhatsApp, une chaîne Slack ou une salle Matrix.';

  @override
  String get messagingReactionAdded => 'Réaction ajoutée';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Exécuté lorsqu\'une personne autorisée réagit à un message dans une discussion privée.';

  @override
  String get messagingPlatformDisconnected => 'Messagerie déconnectée';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'S\'exécute lorsqu\'une connexion de messagerie s\'arrête et a besoin de vous, par exemple après une déconnexion.';

  @override
  String get googleCalendarEventStarting =>
      'Début de l\'événement Google Agenda';

  @override
  String get googleCalendarEventCreated => 'Événement Google Agenda créé';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Exécuté lorsqu\'un nouvel événement ou une nouvelle invitation apparaît.';

  @override
  String get outlookCalendarEventStarting =>
      'Démarrage de l\'événement du calendrier Outlook';

  @override
  String get nextcloudCalendarEventStarting =>
      'Début de l\'événement du calendrier Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Exécutez un nombre défini de minutes avant chaque événement.';

  @override
  String get googleDriveFileAdded => 'Fichier Google Drive ajouté';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Exécuté lorsqu\'un fichier est ajouté à Drive ou à un dossier qu\'il contient.';

  @override
  String get googleSheetsRowAdded => 'Ligne Google Sheets ajoutée';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Exécuté lorsque de nouvelles lignes apparaissent dans une feuille.';

  @override
  String get onedriveFileAdded => 'Fichier OneDrive ajouté';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Exécuté lorsqu\'un fichier est ajouté à un dossier OneDrive.';

  @override
  String get nextcloudFileAdded => 'Fichier Nextcloud ajouté';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Exécuté lorsqu\'un fichier est ajouté à un dossier Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Fichier Nextcloud partagé avec vous';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Exécuté lorsque quelqu\'un partage un fichier ou un dossier avec vous.';

  @override
  String get notionItemAdded => 'Élément de base de données Notion ajouté';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Exécuté lorsqu\'un élément est ajouté à une base de données Notion.';

  @override
  String get notionItemUpdated =>
      'Élément de base de données Notion mis à jour';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Exécuté lorsqu\'un élément d\'une base de données Notion change.';

  @override
  String get trelloCardEnteredList => 'Carte Trello ajoutée à la liste';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Exécuté lorsqu\'une carte est créée ou déplacée dans une liste.';

  @override
  String get figmaCommentAdded => 'Commentaire Figma ajouté';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Exécuté lorsque quelqu\'un commente un fichier Figma.';

  @override
  String get githubPrOpened => 'Demande d\'extraction GitHub ouverte';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Exécuté lorsqu\'une nouvelle pull request est ouverte dans un référentiel.';

  @override
  String get githubWorkflowRunFailed =>
      'L\'exécution du workflow GitHub a échoué';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Exécuté lorsqu\'une exécution d\'actions GitHub échoue.';

  @override
  String get githubCommitPushed => 'Validation GitHub poussée';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Exécuté lorsque de nouveaux commits atteignent une branche.';

  @override
  String get mcpServerFailed => 'Le serveur MCP a échoué';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Exécuté lorsqu\'un serveur MCP qui fonctionnait échoue ou nécessite une connexion.';

  @override
  String get homeAssistantStateChanged => 'L’état de Home Assistant a changé';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Exécuté lorsqu\'une entité change, atteint un état ou dépasse une valeur.';

  @override
  String get spotifyTrackChanged => 'La piste Spotify a changé';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Exécuté lorsqu\'une autre piste commence à jouer.';

  @override
  String get neorecallDailySummaryReady =>
      'Le résumé quotidien NeoRecall est prêt';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Exécuté lorsque le résumé d\'une journée est définitif.';

  @override
  String get neorecallConversationRecorded =>
      'Conversation NeoRecall enregistrée';

  @override
  String get runWhenARecordedConversationEnds =>
      'Exécuté à la fin d\'une conversation enregistrée.';

  @override
  String get geofenceTrigger => 'Clôture géographique de localisation';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Courez lorsque votre téléphone arrive ou quitte un endroit. Nécessite un suivi de localisation sur le téléphone.';

  @override
  String get healthMetricRecorded => 'Mesure de santé enregistrée';

  @override
  String get runWhenAHealthReadingArrives =>
      'Exécuté lorsqu\'une lecture de santé synchronisée arrive, éventuellement au-dessus ou en dessous d\'une valeur.';

  @override
  String get wearableConnectionChanged => 'Wearable connecté ou déconnecté';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Exécutez lorsque votre portable se connecte ou se déconnecte.';

  @override
  String get taskRunFinished => 'Une autre tâche terminée';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Exécuté après la fin, la réussite ou l\'échec d\'une autre tâche.';

  @override
  String get appPackageOptional => 'Package d\'application (facultatif)';

  @override
  String get appPackageHelper => 'Par exemple com.whatsapp';

  @override
  String get anyPlatform => 'N\'importe quelle plateforme';

  @override
  String get spaceIdOptional =>
      'ID de serveur, de groupe, de canal ou de salle (facultatif)';

  @override
  String get spaceIdHelper =>
      'Vide surveille tous ceux dans lesquels se trouve le bot.';

  @override
  String get emojiOptional => 'Émoji (facultatif)';

  @override
  String get chatIdOptional => 'Identifiant de discussion (facultatif)';

  @override
  String get platformOptional => 'Plateforme (facultatif)';

  @override
  String get platformOptionalHelper =>
      'Par exemple WhatsApp. Les montres sont toutes vides.';

  @override
  String get minutesBefore => 'Quelques minutes avant';

  @override
  String get calendarIdOptional => 'ID d\'agenda (facultatif)';

  @override
  String get calendarIdHelper => 'Vide utilise votre calendrier principal.';

  @override
  String get invitesOnly => 'Uniquement les invitations des autres';

  @override
  String get nextcloudCalendarPath => 'Calendrier';

  @override
  String get nextcloudCalendarPathHelper =>
      'Son nom dans la liste du calendrier Nextcloud, par exemple personnel';

  @override
  String get folderIdOptionalHelperDrive => 'Vide surveille tout Drive.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Vide surveille le dossier racine.';

  @override
  String get driveFolderIdOptional => 'ID du dossier (facultatif)';

  @override
  String get spreadsheetId => 'ID de feuille de calcul';

  @override
  String get sheetRange => 'Gamme';

  @override
  String get sheetRangeHelper =>
      'Les colonnes du tableau, par exemple Sheet1!A:E';

  @override
  String get folderPathOptional => 'Chemin du dossier (facultatif)';

  @override
  String get folderPathHelper => 'Par exemple Documents';

  @override
  String get notionDatabaseId => 'ID de base de données';

  @override
  String get trelloListId => 'Identifiant de la liste';

  @override
  String get figmaFileKey => 'Clé de fichier';

  @override
  String get figmaFileKeyHelper =>
      'À partir du lien du fichier : figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Référentiel';

  @override
  String get workflowOptional => 'Flux de travail (facultatif)';

  @override
  String get workflowHelper => 'Nom de fichier tel que ci.yml';

  @override
  String get branchOptional => 'Branche (facultatif)';

  @override
  String get branchHelper => 'Empty utilise la branche par défaut.';

  @override
  String get mcpServerIdOptional => 'ID du serveur MCP (facultatif)';

  @override
  String get entityId => 'ID d\'entité';

  @override
  String get entityIdHelper => 'Par exemple binaire_sensor.front_door';

  @override
  String get targetStateOptional => 'État cible (facultatif)';

  @override
  String get targetStateHelper => 'Par exemple sur';

  @override
  String get aboveOptional => 'Ci-dessus (facultatif)';

  @override
  String get belowOptional => 'Ci-dessous (facultatif)';

  @override
  String get placeName => 'Nom du lieu';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get radiusMeters => 'Rayon en mètres';

  @override
  String get geofenceTransition => 'Quand';

  @override
  String get arriving => 'Arrivée';

  @override
  String get leaving => 'Partir';

  @override
  String get healthMetric => 'Mesure de santé';

  @override
  String get healthMetricHelper =>
      'Par exemple fréquence cardiaque, pas, poids';

  @override
  String get wearableTransition => 'Quand le portable';

  @override
  String get wearableConnects => 'Se connecte';

  @override
  String get wearableDisconnects => 'Déconnexions';

  @override
  String get sourceTask => 'Après la tâche';

  @override
  String get taskOutcome => 'Résultat';

  @override
  String get anyOutcome => 'N\'importe quel résultat';

  @override
  String get succeeded => 'Réussi';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 est manquant ou non valide.';
  }

  @override
  String get triggerSectionMessaging => 'Messagerie';

  @override
  String get triggerSectionDeveloper => 'Développeur';

  @override
  String get triggerSectionMemory => 'Mémoire';

  @override
  String get triggerSectionNews => 'Actualités';

  @override
  String get triggerSectionSystem => 'Système';

  @override
  String get searchTriggersHint =>
      'Rechercher des déclencheurs, des applications ou des événements';

  @override
  String get noTriggersMatch =>
      'Aucun déclencheur ne correspond à votre recherche.';

  @override
  String get triggerAccountMissing => 'Pas encore de compte';

  @override
  String get pickTriggerKeyboardHint => 'Enter sélectionne le premier résultat';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return 'Déclencheurs $arg1';
  }

  @override
  String get addFromSkillsSh => 'Ajouter à partir de skills.sh';

  @override
  String get skillsShHint =>
      'Recherchez ci-dessus pour trouver des compétences sur skills.sh, ou collez un lien skills.sh ou une commande « npx skills add ».';

  @override
  String get noSkillsShMatches =>
      'Aucune compétence skills.sh ne correspond à cette recherche.';

  @override
  String get installingSkill => 'Installation…';

  @override
  String installedSkillArg1(Object? arg1) {
    return '$arg1 installé';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Installations de $arg1';
  }

  @override
  String get authVerify => 'Vérifier';

  @override
  String get authCreateAccount => 'Créer un compte';

  @override
  String get authNewInviteLink => 'Nouveau lien d\'invitation';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get authPasswordWillBeRejected => 'trop faible, sera rejeté';

  @override
  String get authUsernameTooShort =>
      'Les noms d\'utilisateur doivent comporter au moins 3 caractères.';

  @override
  String get authUsernameTaken => 'Ce nom d\'utilisateur est déjà pris.';

  @override
  String get authSignupsClosed =>
      'Les inscriptions sont fermées sur ce serveur. Demandez à l\'administrateur un compte.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Ce serveur n\'accepte que les connexions via HTTPS. Ouvrez plutôt $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Ce serveur n\'accepte que les connexions via HTTPS. Connectez-vous-y avec une adresse https://.';

  @override
  String get authAccountNotFound => 'Ce compte n\'existe plus.';

  @override
  String get authQrRateLimited =>
      'Trop de demandes de connexion QR. Attendez un instant, puis actualisez le code.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Vous avez oublié votre mot de passe ? Demandez à l\'administrateur de votre serveur de le réinitialiser dans Admin → Utilisateurs.';

  @override
  String get authChangeServer => 'Changer de serveur';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Connexion à $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Cette adresse ne répond pas comme un serveur NeoAgent. Vérifiez l\'URL et réessayez.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Impossible d\'ouvrir une connexion sécurisée (HTTPS) à $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Impossible d\'atteindre $arg1 via HTTPS, et HTTP simple n\'a pas non plus répondu. Vérifiez l\'adresse et le port.';
  }

  @override
  String get adminResetPassword => 'Réinitialiser le mot de passe';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Réinitialiser le mot de passe pour $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Choisissez un nouveau mot de passe pour $arg1. Ils seront déconnectés sur chaque appareil et se reconnecteront avec ce mot de passe.';
  }

  @override
  String get adminNewPassword => 'Nouveau mot de passe';

  @override
  String get adminSetPassword => 'Définir le mot de passe';

  @override
  String get authMissingFields => 'Remplissez tous les champs obligatoires.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 réinitialise le mot de passe de $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Mot de passe mis à jour ; l\'utilisateur était déconnecté partout.';

  @override
  String get authSignInTitle => 'Connectez-vous à NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Scannez avec votre téléphone ou utilisez votre mot de passe.';

  @override
  String get authOrUsePassword => 'ou utilisez votre mot de passe';

  @override
  String get qrLoginWaitingTitle => 'Approuvez sur votre téléphone';

  @override
  String get qrLoginWaitingBody =>
      'Votre téléphone a scanné le code. Confirmez la connexion ici pour terminer la connexion.';

  @override
  String get qrLoginSigningInOn => 'Connexion sur';

  @override
  String get qrLoginLocation => 'Emplacement';

  @override
  String get qrLoginWaitingForApproval => 'En attente d\'approbation';

  @override
  String get qrLoginCancelAndUsePassword =>
      'Annuler et utiliser un mot de passe';

  @override
  String get qrLoginDeclinedOnPhone =>
      'La connexion a été refusée sur votre téléphone. Scannez le nouveau code pour réessayer.';

  @override
  String get signupKey => 'Clé d’inscription';

  @override
  String get signupKeyStepSubtitle =>
      'Les nouveaux comptes sur ce serveur nécessitent une clé d’inscription. Saisissez celle qu’un administrateur vous a remise.';

  @override
  String get signupKeyChange => 'Modifier';

  @override
  String get signupKeyRequiredError => 'Saisissez votre clé d’inscription.';

  @override
  String get signupKeyInvalidError =>
      'Cette clé d’inscription n’est pas valide. Vérifiez-la et réessayez.';

  @override
  String get signupKeyUsedError =>
      'Cette clé d’inscription a déjà été utilisée. Demandez-en une nouvelle à un administrateur.';

  @override
  String get adminRequireSignupKey => 'Exiger une clé d’inscription';

  @override
  String get adminRequireSignupKeyHint =>
      'Les nouveaux comptes nécessitent une clé à usage unique fournie par un administrateur. Désactivé, toute personne pouvant accéder à ce serveur peut s’inscrire. Le premier compte n’a jamais besoin de clé.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Les nouveaux comptes nécessitent désormais une clé d’inscription.';

  @override
  String get adminSignupOpenNotice =>
      'Tout le monde peut désormais s’inscrire.';

  @override
  String get signupKeys => 'Clés d’inscription';

  @override
  String get signupKeysDescription =>
      'Clés à usage unique pour s’inscrire lorsqu’une clé est exigée. Chaque clé crée exactement un compte.';

  @override
  String get signupKeysNew => 'Nouvelles clés';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Inutilisées · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Utilisées · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Révoquées · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Toutes · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Inutilisée';

  @override
  String get signupKeyStatusUsed => 'Utilisée';

  @override
  String get signupKeyStatusRevoked => 'Révoquée';

  @override
  String get signupKeysExport => 'Exporter en .txt';

  @override
  String get signupKeysCopied => 'Clés copiées';

  @override
  String get signupKeyCopied => 'Clé copiée';

  @override
  String get signupKeysEmpty => 'Aucune clé dans cette liste.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Créée le $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Utilisée par $arg1 le $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Utilisée le $arg1 par un compte supprimé depuis';
  }

  @override
  String get signupKeyRevokeTitle => 'Révoquer cette clé ?';

  @override
  String get signupKeyRevokeMessage =>
      'Personne ne pourra plus s’inscrire avec. Cette action est irréversible.';

  @override
  String get signupKeyRevoked => 'Clé révoquée.';

  @override
  String signupKeysShowMore(int count) {
    return 'Afficher $count de plus';
  }

  @override
  String get signupKeysCreateTitle => 'Créer des clés d’inscription';

  @override
  String get signupKeysCount => 'Nombre de clés';

  @override
  String get signupKeysCountHelper => 'De 1 à 500';

  @override
  String get signupKeysCountInvalid => 'Saisissez un nombre entre 1 et 500.';

  @override
  String get signupKeysLabel => 'Libellé (facultatif)';

  @override
  String get signupKeysLabelHint => 'p. ex. Testeurs bêta du printemps';

  @override
  String signupKeysCreateAction(int count) {
    return 'Créer ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Clés prêtes : $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Remettez chaque clé à une seule personne. Les clés inutilisées restent dans la liste : vous pourrez les copier ou les exporter plus tard.';

  @override
  String get signupKeysSaveDialogTitle => 'Enregistrer les clés d’inscription';

  @override
  String get signupKeysExported => 'Clés exportées.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor a créé des clés d’inscription ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor a révoqué une clé d’inscription';
  }

  @override
  String get providerChooseUsername => 'Choisissez votre nom d\'utilisateur';

  @override
  String get providerChooseUsernameBody =>
      'Choisissez un nom d\'utilisateur disponible pour finir de créer votre compte.';

  @override
  String get dataSharingTitle => 'Partager les données d\'utilisation';

  @override
  String get dataSharingDescription =>
      'Aidez les responsables de ce serveur à l\'améliorer. Partage la façon dont vous utilisez NeoAgent, jamais ce que vous écrivez ou stockez.';

  @override
  String dataSharingSince(String date) {
    return 'Partagé depuis le $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Ce qui est partagé';

  @override
  String get dataSharingIncluded => 'Partagé';

  @override
  String get dataSharingExcluded => 'Jamais partagé';

  @override
  String get dataSharingIncludedDevice =>
      'Type d\'appareil et version de l\'application';

  @override
  String get dataSharingIncludedLocale =>
      'Langue de l\'application et région du fuseau horaire, par exemple Europe';

  @override
  String get dataSharingIncludedFeatures =>
      'Les fonctionnalités que vous avez configurées, comme les tâches, les skills et les intégrations';

  @override
  String get dataSharingIncludedRuns =>
      'Les outils et modèles utilisés par vos exécutions, avec durées et nombre de tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Quand vous utilisez NeoAgent, par jour de la semaine et par heure';

  @override
  String get dataSharingExcludedContent => 'Messages, prompts et réponses';

  @override
  String get dataSharingExcludedRuns =>
      'Titres des exécutions, entrées et résultats des outils';

  @override
  String get dataSharingExcludedFiles =>
      'Fichiers, souvenirs et tout ce que vous stockez';

  @override
  String get dataSharingExcludedIdentity =>
      'Votre nom, e-mail, adresse IP et localisation';

  @override
  String get dataSharingExcludedAccounts =>
      'Les comptes avec lesquels vous connectez des intégrations';

  @override
  String get dataSharingPooledNote =>
      'Les administrateurs ne voient que des totaux sur l\'ensemble des personnes qui partagent, jamais vous seul. Désactivez-le à tout moment et vous sortez immédiatement des totaux.';

  @override
  String get dataSharingConfirmTitle => 'Partager les données d\'utilisation ?';

  @override
  String get dataSharingConfirmAction => 'Partager';

  @override
  String get sharedUsageTitle => 'Utilisation partagée';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Comptes qui partagent leurs données d\'utilisation : $sharing sur $total. Totaux uniquement, aucun contenu.';
  }

  @override
  String get sharedUsageEmpty =>
      'Personne ne partage encore ses données d\'utilisation. Chacun peut l\'activer dans Paramètres, Profil, Vos données.';

  @override
  String get sharedUsageRuns => 'Exécutions partagées';

  @override
  String get sharedUsageAvgDuration => 'Durée moy.';

  @override
  String get sharedUsageCompletedRuns => 'Exécutions terminées';

  @override
  String get sharedUsageStepsPerRun => 'Étapes par exécution';

  @override
  String get sharedUsageDevices => 'Appareils';

  @override
  String get sharedUsageAppVersions => 'Versions de l\'application';

  @override
  String get sharedUsageLanguages => 'Langues';

  @override
  String get sharedUsageRegions => 'Régions';

  @override
  String get sharedUsageFeatures => 'Adoption des fonctionnalités';

  @override
  String get sharedUsageFeaturesDescription =>
      'Part des comptes qui partagent et l\'ont configurée.';

  @override
  String get sharedUsageTools => 'Outils';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Outils les plus appelés ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Appels : $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Échecs : $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Intégrations';

  @override
  String get sharedUsageMessaging => 'Canaux de messagerie';

  @override
  String get sharedUsageTriggers => 'Comment les exécutions démarrent';

  @override
  String get sharedUsageActivity => 'Quand c\'est utilisé';

  @override
  String get sharedUsageActivityDescription =>
      'Exécutions par jour de la semaine et par heure, UTC.';

  @override
  String get sharedUsageModels => 'Performance des modèles';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'moy. $latency · $cached % en cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Comptes : $count';
  }

  @override
  String get sharedUsageNoData => 'Rien sur cette période.';

  @override
  String get sharedUsageNotReported => 'Pas encore signalé';

  @override
  String get sharedUsageFeatureAgents => 'Plus d\'un agent';

  @override
  String get sharedUsageFeatureTasks => 'Tâches planifiées';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'Serveurs MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Intégrations';

  @override
  String get sharedUsageFeatureMessaging => 'Canaux de messagerie';

  @override
  String get sharedUsageFeatureMemory => 'Mémoire';

  @override
  String get sharedUsageSearchKeywords =>
      'partage de données opt-in télémétrie appareils fonctionnalités outils modèles activité';
}
