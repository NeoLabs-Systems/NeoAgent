// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppL10nEl extends AppL10n {
  AppL10nEl([String locale = 'el']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Καλώς ήρθατε';

  @override
  String get onboardingEyebrowCommunication => 'Επικοινωνία';

  @override
  String get onboardingEyebrowIntelligence => 'Ευφυΐα';

  @override
  String get onboardingEyebrowComputer => 'Υπολογιστής';

  @override
  String get onboardingEyebrowAutomation => 'Αυτοματοποίηση';

  @override
  String get onboardingNext => 'Επόμενο';

  @override
  String get onboardingIntroCouldNotLoad =>
      'Δεν ήταν δυνατή η φόρτωση της εισαγωγής.';

  @override
  String get onboardingModelDescription =>
      'Επιλέξτε το μοντέλο που πρέπει να χρησιμοποιεί το NeoAgent από προεπιλογή ή αφήστε το να επιλέξει αυτόματα.';

  @override
  String get onboardingLoadingModels => 'Φόρτωση μοντέλων…';

  @override
  String get noAiModelTitle => 'Κανένα μοντέλο AI δεν έχει ρυθμιστεί ακόμα';

  @override
  String get noAiModelBody =>
      'Προσθέστε ένα κλειδί API από έναν πάροχο όπως το OpenAI, το Anthropic ή το Google. Στη συνέχεια, το NeoAgent εμφανίζει τα μοντέλα που μπορείτε να χρησιμοποιήσετε.';

  @override
  String get noAiModelChatBody =>
      'Το NeoAgent χρειάζεται ένα μοντέλο AI για να απαντήσει. Προσθέστε ένα κλειδί API από έναν πάροχο όπως το OpenAI, το Anthropic ή το Google.';

  @override
  String get noAiModelAdminHint =>
      'Ως διαχειριστής, μπορείτε επίσης να ρυθμίσετε παρόχους για όλους στην ενότητα Διαχειριστής → Πάροχοι.';

  @override
  String get addApiKey => 'Προσθήκη κλειδιού API';

  @override
  String onboardingMessagingConnected(String platform) {
    return 'Το $platform είναι συνδεδεμένο.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Αναμονή για σύνδεση του $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Έτοιμοι';

  @override
  String get onboardingStepRequired => 'Απαιτείται';

  @override
  String get onboardingStepOptional => 'Προαιρετικό';

  @override
  String get onboardingStepCloudOrLocal => 'Σύννεφο ή τοπικό';

  @override
  String get onboardingStepComputer => 'Υπολογιστής';

  @override
  String get onboardingStepRoutines => 'Ρουτίνες';

  @override
  String get onboardingComputerChoiceTitle => 'Πού πρέπει να\nλειτουργεί;';

  @override
  String get onboardingComputerChoiceDescription =>
      'Μπορείτε να κάνετε εναλλαγή ανά περίοδο σύνδεσης.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Ιδιωτικό sandbox · πάντα ενεργοποιημένο';

  @override
  String get onboardingThisComputer => 'Αυτός ο υπολογιστής';

  @override
  String get onboardingThisComputerSubtitle =>
      'Τα αρχεία, οι εφαρμογές και το πρόγραμμα περιήγησής σας';

  @override
  String get onboardingSearchApps => 'Αναζήτηση εφαρμογών…';

  @override
  String get onboardingRoutinesDescription =>
      'Τα αποτελέσματα φτάνουν στις συνομιλίες σας.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Τα αποτελέσματα φτάνουν ως ειδοποιήσεις.';

  @override
  String get onboardingNotifications => 'Ειδοποιήσεις';

  @override
  String get onboardingReadyTitle => 'Όλα είναι\nέτοιμα.';

  @override
  String get onboardingReadyDescription => 'Στείλτε το πρώτο σας μήνυμα.';

  @override
  String get onboardingMessageNeoagent => 'Μήνυμα NeoAgent';

  @override
  String get onboardingAskAnything => 'Ρωτήστε οτιδήποτε…';

  @override
  String get onboardingOpenNeoagent => 'Ανοίξτε το NeoAgent';

  @override
  String get onboardingStarterTrip =>
      'Προγραμματίστε ένα ταξίδι το Σαββατοκύριακο';

  @override
  String get onboardingStarterLanding => 'Δημιουργήστε μια σελίδα προορισμού';

  @override
  String onboardingQuickSteps(int count) {
    return '$count γρήγορα βήματα';
  }

  @override
  String get taskNeedsEmail => 'Συνδέστε πρώτα το email';

  @override
  String get taskNeedsCalendar => 'Συνδέστε πρώτα ένα ημερολόγιο';

  @override
  String get taskNeedsModel => 'Ρυθμίστε πρώτα ένα μοντέλο AI';

  @override
  String get taskPromptDailyRecap =>
      'Ανακεφαλαιώστε την ημέρα μου: συνοψίστε τις συζητήσεις, τις τελειωμένες εργασίες και τις αποφάσεις από σήμερα και, στη συνέχεια, αναφέρετε οτιδήποτε πρέπει να συνεχίσω αύριο. Κράτα το σύντομο και στείλε το σε μένα.';

  @override
  String get taskPromptInboxCheck =>
      'Ελέγξτε τα εισερχόμενα του email μου για μηνύματα που έφτασαν από τον τελευταίο έλεγχο. Στείλτε μου μόνο μηνύματα ηλεκτρονικού ταχυδρομείου που είναι επείγοντα ή χρειάζονται απάντηση, με περίληψη μίας γραμμής το καθένα. Εάν τίποτα δεν χρειάζεται την προσοχή μου, μην στείλετε τίποτα.';

  @override
  String get taskPromptMorningBriefing =>
      'Προετοιμάστε την πρωινή μου ενημέρωση: ο καιρός που βρίσκομαι σήμερα, τα συμβάντα στο ημερολόγιό μου και τα πιο σημαντικά ανοιχτά στοιχεία που γνωρίζω. Στείλτε το ως σύντομο μήνυμα με δυνατότητα σάρωσης.';

  @override
  String get taskPromptTomorrowPrep =>
      'Δείτε το ημερολόγιό μου για αύριο. Για κάθε συνάντηση, πείτε μου περί τίνος πρόκειται, ποιος συμμετέχει και οτιδήποτε πρέπει να προετοιμάσω. Αν αύριο είναι άδειο, μην στείλετε τίποτα.';

  @override
  String get taskPromptNewsDigest =>
      'Αναζητήστε στον ιστό τις πιο σημαντικές ειδήσεις της ημέρας σχετικά με τα θέματα που με ενδιαφέρουν (χρησιμοποιήστε όσα θυμάστε για τα ενδιαφέροντά μου). Στείλτε μου μια σύνοψη έως και πέντε στοιχείων με μία πρόταση το καθένα και έναν σύνδεσμο.';

  @override
  String get taskPromptWeeklyReview =>
      'Αναθεωρήστε την εβδομάδα μου: τι έγινε, τι γλίστρησε και τι είναι ακόμα ανοιχτό. Προτείνετε τα τρία πιο σημαντικά πράγματα στα οποία πρέπει να εστιάσετε την επόμενη εβδομάδα.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Συνδέστε έναν αριθμό τηλεφώνου που ανήκει στον αντιπρόσωπο. Οποιοσδήποτε επιτρέπετε μπορεί να συνομιλήσει μαζί του, σε απευθείας συνομιλίες και ομάδες.';

  @override
  String get whatsappSelfChatDescription =>
      'Συνδέστε τον δικό σας αριθμό και μιλήστε με τον πράκτορα στη συνομιλία \"Μήνυμα στον εαυτό σας\". Κάθε άλλη συζήτηση και ομάδα σε αυτόν τον λογαριασμό αγνοείται.';

  @override
  String get chatSendHintMac => '⌘↵ για αποστολή';

  @override
  String get chatSendHintOther => 'Ctrl+Enter για αποστολή';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Απαιτείται μια βασική διεύθυνση URL για αυτό το τελικό σημείο.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Μια αλλαγμένη διεύθυνση email επιβεβαιώνεται πριν χρησιμοποιηθεί.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Μια απόφαση ψηλότερα στην αλυσίδα κερδίζει.';

  @override
  String get aDeletedAccount => 'έναν διαγραμμένο λογαριασμό';

  @override
  String get aFridayLookBackAtThe =>
      'Μια Παρασκευή αναδρομή στην εβδομάδα και ένα σχέδιο για την επόμενη.';

  @override
  String get aKeyThatAsksForA =>
      'Ένα κλειδί που ζητά PIN ή δακτυλικό αποτύπωμα αντικαθιστά επίσης τον κωδικό δύο παραγόντων.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Ένα μοντέλο γλώσσας έκρινε αυτό το μήνυμα επειδή το SystemOne είναι απενεργοποιημένο.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Ένα αρχείο μεταδεδομένων ρύθμισης NeoAgent υπερέβη το όριο ασφαλούς μεγέθους του.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Μια νεότερη έκδοση ιστού είναι διαθέσιμη στον διακομιστή. Επαναλάβετε τη φόρτωση για να λάβετε το πιο πρόσφατο πακέτο.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Μια ιδιωτική επιφάνεια εργασίας με Chromium, αρχεία, πρόγραμμα επεξεργασίας κειμένου, τερματικό και Python. Η εργασία σας παραμένει αποθηκευμένη μεταξύ των περιόδων σύνδεσης.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Ένας ιδιωτικός υπολογιστής Linux ή μια συσκευή Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Δεν ήταν δυνατή η λήψη ενός απαιτούμενου αρχείου εγκατάστασης NeoAgent.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Ένας συμπαίκτης σας στέλνει έναν σύνδεσμο πρόσκλησης. Μόλις το αποδεχτείς, εκείνοι ';

  @override
  String get aTeammateSentYouAnInvite =>
      'ένας συμπαίκτης σας έστειλε έναν σύνδεσμο πρόσκλησης, εισάγετέ τον εδώ για να γίνετε μέλος της ομάδας του.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Μια προσωρινή λήψη θα καθαριστεί αργότερα.';

  @override
  String get aValueIsStored => 'Αποθηκεύεται μια τιμή.';

  @override
  String get access => 'Πρόσβαση';

  @override
  String get accessActivity => 'Πρόσβαση στη δραστηριότητα';

  @override
  String accessArg1(Object? arg1) {
    return 'Πρόσβαση: $arg1';
  }

  @override
  String get accessMode => 'Λειτουργία πρόσβασης';

  @override
  String get accessPermissions => 'Δικαιώματα πρόσβασης';

  @override
  String get accessToken => 'διακριτικό πρόσβασης';

  @override
  String get accessToken2 => 'Διακριτικό πρόσβασης';

  @override
  String get account => 'Λογαριασμός';

  @override
  String accountArg1(Object? arg1) {
    return 'Λογαριασμός #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Ειδοποιήσεις αλλαγής λογαριασμού';

  @override
  String get accountEmail => 'Email λογαριασμού';

  @override
  String get accountEmailIsOffUntilThese =>
      'Η διεύθυνση ηλεκτρονικού ταχυδρομείου του λογαριασμού είναι απενεργοποιημένη έως ότου οριστούν: ';

  @override
  String get accountLanguageDescription =>
      'Το NeoAgent χρησιμοποιεί αυτή τη γλώσσα παντού στην εφαρμογή. Την πρώτη φορά που συνδέεστε, ακολουθεί αυτή τη συσκευή. Μετά από αυτό, η επιλογή αποθηκεύεται στον λογαριασμό σας και χρησιμοποιείται σε κάθε συσκευή.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Δεν ήταν δυνατή η αλλαγή της γλώσσας: $error';
  }

  @override
  String get accountLanguageTitle => 'Γλώσσα';

  @override
  String get accountNumber => 'Αριθμός λογαριασμού';

  @override
  String get accountSettings => 'Ρυθμίσεις λογαριασμού';

  @override
  String get accounts => 'Λογαριασμοί';

  @override
  String get accountsByTokensUsedAllTime =>
      'Λογαριασμοί ανά διακριτικά που χρησιμοποιούνται, πάντα.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'υπολογιστές cloud των λογαριασμών. Οι αλλαγές ισχύουν μετά από διακομιστή ';

  @override
  String get accountsOnThisServer => 'Λογαριασμοί σε αυτόν τον διακομιστή';

  @override
  String get active => 'Ενεργός';

  @override
  String get activeSessions => 'Ενεργές συνεδρίες';

  @override
  String get activeToday => 'Ενεργός σήμερα';

  @override
  String get add => 'Προσθήκη';

  @override
  String get addAProviderCredentialFirstIts =>
      'Προσθέστε πρώτα ένα διαπιστευτήριο παρόχου. Τα μοντέλα του εμφανίζονται εδώ μία φορά ';

  @override
  String get addAgent => 'Προσθήκη πράκτορα';

  @override
  String get addAnotherSignInMethodBefore =>
      'Προσθέστε μια άλλη μέθοδο σύνδεσης πριν την καταργήσετε.';

  @override
  String get addBinding => 'Προσθέστε δέσιμο';

  @override
  String get addByNameOrId => 'Προσθήκη με όνομα ή αναγνωριστικό';

  @override
  String get addByNameOrIdInstead =>
      'Αντ\' αυτού, προσθέστε με όνομα ή αναγνωριστικό';

  @override
  String get addCredentialBinding => 'Προσθήκη δέσμευσης διαπιστευτηρίων';

  @override
  String get addEntry => 'Προσθήκη Καταχώρισης';

  @override
  String get addKey => 'Προσθήκη κλειδιού';

  @override
  String get addMcpServer => 'Προσθήκη διακομιστή MCP';

  @override
  String get addMemory => 'Προσθήκη μνήμης';

  @override
  String get memoryReview => 'Έλεγχος';

  @override
  String get memoryReviewPrompt =>
      'Έλεγξε όλες τις αναμνήσεις μου και τακτοποίησέ τες: αρχειοθέτησε διπλότυπα, παρωχημένα στοιχεία και ό,τι δεν έχει μόνιμη αξία. Μετά πες μου σύντομα τι άλλαξες.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Προσθέστε περισσότερο μήκος ή άλλο τύπο χαρακτήρα.';

  @override
  String get addPeopleOrGroups => 'Προσθέστε άτομα ή ομάδες';

  @override
  String get addSecurityKey => 'Προσθήκη κλειδιού ασφαλείας';

  @override
  String get addSomeoneOrAGroup => 'Προσθέστε κάποιον ή μια ομάδα';

  @override
  String get addTask => 'Προσθήκη Εργασίας';

  @override
  String get addTests => 'Προσθέστε τεστ';

  @override
  String get addTestsForThePartsOf =>
      'Προσθέστε δοκιμές για τα μέρη αυτού του έργου που έχουν τη μικρότερη κάλυψη και, στη συνέχεια, εκτελέστε τα.';

  @override
  String get addTheirOwnKeysInSettings =>
      'προσθέτουν τα δικά τους κλειδιά στις Ρυθμίσεις.';

  @override
  String get addToPrompt => 'Προσθήκη στο ερώτημα';

  @override
  String get added => 'Προστέθηκε';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Προστέθηκε $arg1 · Τελευταία χρήση $arg2';
  }

  @override
  String get addressWithTheProvider => 'διεύθυνση με τον πάροχο.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Προσαρμόστε την ένταση του ηχείου, ελέγξτε τις προεπιλογές κουμπιών υλικού και διαχειριστείτε αυτήν την περίοδο λειτουργίας εκκίνησης.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Προσαρμόστε το φίλτρο αναζήτησης ή κατάστασης για να δείτε περισσότερα κανάλια ανταλλαγής μηνυμάτων.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Ρυθμίστε την ένταση του ηχείου εδώ.';

  @override
  String get admin => 'Διαχειρ';

  @override
  String adminArg1(Object? arg1) {
    return 'Διαχειριστής › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Οι επιχορηγήσεις διαχειριστή, οι σύνδεσμοι προσκλήσεων και οι αλλαγές διαχείρισης εμφανίζονται εδώ.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Προηγμένο χειροκίνητο πρόγραμμα για ειδικές περιπτώσεις.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Για προχωρημένους: λεπτή ώρα ημέρας μήνας καθημερινής ημέρας.';

  @override
  String get againRightAway => 'πάλι αμέσως.';

  @override
  String get agent => 'Πράκτορας';

  @override
  String agentArg1(Object? arg1) {
    return 'Αντιπρόσωπος: $arg1';
  }

  @override
  String get agentCalls => 'Κλήσεις πράκτορα';

  @override
  String get agentCommunication => 'Επικοινωνία αντιπροσώπου';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Επικοινωνία αντιπροσώπου: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Η λειτουργία Agent επεξεργάζεται τον χώρο εργασίας · ⌘↵ αποστολή · ⌘N νέα περίοδος λειτουργίας';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Ο πράκτορας σταματά και ζητά την άδειά σας πριν από την εκτέλεση.';

  @override
  String get agentProfile => 'Προφίλ πράκτορα';

  @override
  String get agentVisibleName => 'Ορατό όνομα αντιπροσώπου';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Ο πράκτορας θέλει να χρησιμοποιήσει το $arg1. Πατήστε για να αποφασίσετε.';
  }

  @override
  String get agents => 'Πράκτορες';

  @override
  String get aiAnswerUnreadable => 'Η απάντηση AI δεν είναι αναγνώσιμη';

  @override
  String get aiProviderKeys => 'Κλειδιά παρόχου AI';

  @override
  String get aiUnavailable => 'Το AI δεν είναι διαθέσιμο';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'ειδοποιήσεις και άλλα email λογαριασμού από.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Ειδοποιήσεις όταν μια σύνδεση ανταλλαγής μηνυμάτων χρειάζεται την προσοχή του χρήστη';

  @override
  String get all => 'Όλα';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Όλοι οι αντιπρόσωποι ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Όλα $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Όλες οι υποδοχές υπολογιστών cloud χρησιμοποιούνται αυτήν τη στιγμή. Δοκιμάστε ξανά σε λίγο.';

  @override
  String get allComputerSlotsAreBusy =>
      'Όλες οι υποδοχές υπολογιστή είναι απασχολημένες';

  @override
  String get allTables => 'Όλα τα τραπέζια';

  @override
  String get allTime => 'Όλο το χρόνο';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Επιτρέπονται όλα τα εργαλεία — ο πράκτορας μπορεί να χρησιμοποιήσει οποιαδήποτε δυνατότητα χωρίς να ρωτήσει. ';

  @override
  String get allow => 'Να επιτρέπεται';

  @override
  String get allowedRunsWithoutAsking =>
      'Επιτρέπεται. Τρέχει χωρίς να ρωτήσει.';

  @override
  String get allowAll => 'Επιτρέψτε όλα';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Επιτρέψτε την \"Εγκατάσταση άγνωστων εφαρμογών\" για το NeoAgent και, στη συνέχεια, δοκιμάστε ξανά την ενημέρωση.';

  @override
  String get allowOnce => 'Επιτρέψτε μια φορά';

  @override
  String get allowSender => 'Να επιτρέπεται στον αποστολέα';

  @override
  String get allowSession => 'Να επιτρέπεται η συνεδρία';

  @override
  String get allowTheAgentToStartAn =>
      'Επιτρέψτε στον πράκτορα να ξεκινήσει μια φωνητική κλήση εντός εφαρμογής μαζί σας.';

  @override
  String get allowedOrigins => 'Επιτρεπόμενες προελεύσεις';

  @override
  String get allowedPathPrefix => 'Επιτρεπόμενο πρόθεμα διαδρομής';

  @override
  String get allowsYouCanChangeThatPer =>
      'επιτρέπει. Μπορείτε να το αλλάξετε ανά άτομο αργότερα. Οι σύνδεσμοι δεν χορηγούνται ποτέ ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'ανήκει ήδη σε έναν υπάρχοντα λογαριασμό';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'έχει ήδη συνδεθεί με άλλο λογαριασμό';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'έχει ήδη συνδεθεί με άλλο λογαριασμό neoagent';

  @override
  String get alreadyUsed => 'ήδη χρησιμοποιείται';

  @override
  String get always => 'Πάντα';

  @override
  String get alwaysAllow => 'Πάντα να επιτρέπεται';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Το \"Να επιτρέπεται πάντα\" αποθηκεύει μόνιμα την πολιτική — μπορείτε να την αλλάξετε στις Ρυθμίσεις.';

  @override
  String get alwaysAsk => 'Ρωτάτε πάντα';

  @override
  String get alwaysEngage => 'Πάντα να ασχολείσαι';

  @override
  String get alwaysJoins => 'Πάντα συμμετέχει';

  @override
  String get anApiKeyIsRequired => 'Απαιτείται ένα κλειδί API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Μια απογευματινή σύνοψη του τι συνέβη και τι πρέπει να ακολουθήσει.';

  @override
  String get anHttpOrHttpsUrlIs => 'Απαιτείται διεύθυνση URL http ή https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'και αναλυτικά στοιχεία. Οι σύνδεσμοι ομάδας ζωντανά στη σελίδα της ομάδας.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Η εγκατάσταση Android APK δεν είναι διαθέσιμη σε αυτήν την πλατφόρμα.';

  @override
  String get androidApp => 'Εφαρμογή Android';

  @override
  String get androidControl => 'Έλεγχος Android';

  @override
  String get androidCouldNotStart => 'Το Android δεν μπόρεσε να ξεκινήσει';

  @override
  String get androidNotificationReceived => 'Λήψη ειδοποίησης Android';

  @override
  String get androidOnly => 'Μόνο Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Δεν ήταν δυνατό το άνοιγμα του προγράμματος εγκατάστασης πακέτου Android.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Οθόνη Android — πατήστε για να αγγίξετε, σύρετε για σάρωση';

  @override
  String get androidSdk => 'android SDK';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Απαντάει σε @αναφορές για ζητήματα και αιτήματα έλξης';

  @override
  String get anyone => 'Οποιοσδήποτε';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Οποιοσδήποτε σε αυτήν την πλατφόρμα μπορεί να στείλει μήνυμα στο $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Οποιοσδήποτε σε αυτήν την πλατφόρμα μπορεί να στείλει μήνυμα $arg1 στο $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Όποιος μπορεί να αποκτήσει πρόσβαση σε αυτόν τον λογαριασμό μπορεί να μιλήσει στο $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Οποιοσδήποτε διαθέτει τον σύνδεσμο μπορεί να εγγραφεί μέχρι να λήξει ή να τον ανακαλέσετε.';

  @override
  String get apiHttpsOrigin => 'Προέλευση HTTPS API';

  @override
  String get apiKey => 'Κλειδί API';

  @override
  String get apiKey2 => 'κλειδί api';

  @override
  String get apiKey3 => 'Κλειδί API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api key anthropic claude openai gpt xai grok google gemini minimax διαπιστευτήρια nvidia nim openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Κλειδιά API και τελικά σημεία για παρόχους τεχνητής νοημοσύνης, αναζήτησης και φωνής. Αυτοί ';

  @override
  String get apiRequest => 'Αίτημα API';

  @override
  String get apiYourOwnServerASelf =>
      'API -- ο δικός σας διακομιστής, ένα αυτο-φιλοξενούμενο μοντέλο ή άλλο ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Η λήψη του APK απέτυχε με το HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Απαιτείται όνομα εφαρμογής.';

  @override
  String get appUpdates => 'Ενημερώσεις εφαρμογών';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Οι ενημερώσεις εφαρμογών δεν έχουν διαμορφωθεί για αυτήν την έκδοση.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Εφαρμόστηκαν ενημερώσεις του τιμονιού $arg1 στην ουρά στην τρέχουσα διαδρομή.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Εφαρμόστηκε ενημέρωση(εις) του τιμονιού $arg1.';
  }

  @override
  String get apply => 'Εφαρμόστε';

  @override
  String get applyBehaviorNotes => 'Εφαρμόστε σημειώσεις συμπεριφοράς';

  @override
  String get applyCoreMemory => 'Εφαρμογή μνήμης πυρήνα';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Αιτήματα έγκρισης για ευαίσθητα εργαλεία αντιπροσώπων';

  @override
  String get approvalRequired => 'Απαιτείται έγκριση';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Η έγκριση παραμένει εντός της επαληθευμένης περιόδου σύνδεσης για κινητά και κάθε κωδικός λήγει αυτόματα μετά από ένα σύντομο παράθυρο.';

  @override
  String get approveLogin => 'Έγκριση σύνδεσης';

  @override
  String get approveQrLogin => 'Έγκριση σύνδεσης QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Εγκρίνετε αυτό μόνο εάν ξεκινήσατε τη σύνδεση σε αυτήν τη συσκευή μόλις τώρα.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Εγκεκριμένη σύνδεση για $arg1.';
  }

  @override
  String get approvedOnly => 'Μόνο εγκεκριμένο';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Εγκεκριμένη σύζευξη για $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Εγκεκριμένα άτομα και ομάδες';

  @override
  String get approvedPeopleOnly => 'Μόνο εγκεκριμένα άτομα';

  @override
  String get archive => 'Αρχείο';

  @override
  String get archiveAgent => 'Αρχειακός πράκτορας;';

  @override
  String archiveArg1(Object? arg1) {
    return 'Αρχείο ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Αρχειοθέτηση $arg1 $arg2;';
  }

  @override
  String get archiveSelectedMemories => 'Αρχειοθέτηση επιλεγμένων αναμνήσεων;';

  @override
  String get areSharedByEveryAccountOn =>
      'κοινοποιούνται από κάθε λογαριασμό σε αυτόν τον διακομιστή. οι λογαριασμοί μπορούν ακόμα ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1 εκατ. είσοδος';
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
    return 'Απαιτείται πρόσβαση $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Λογαριασμοί $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 ενεργό';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Προστέθηκε $arg1. Επεξεργαστείτε το ανά πάσα στιγμή για να αλλάξετε το ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return 'Το \"$arg1\" και το ιστορικό εκτέλεσής του θα διαγραφούν οριστικά. Οποιαδήποτε ενεργή εκτέλεση θα διακοπεί. Τα αρχεία στο χώρο εργασίας δεν αγγίζονται.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Απαιτείται έγκριση $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Οι εφαρμογές $arg1 είναι ενεργές';
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
    return '$arg1 (ενεργά εργαλεία $arg2)';
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
    return '$arg1 $arg2 στο $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 άλλαξε';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 χαρακτήρες';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Δημιουργήθηκε το $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [τοπική διεύθυνση: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 που ταιριάζει με \"$arg3\"';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1$arg2Χώρος εργασίας NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 νέοι λογαριασμοί';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 τρέχει · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · Δείγματα $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 τιμόνι σε ουρά';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nμάρκες $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'μάρκες $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 στο $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 Β';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return 'Ο $arg1 έγινε διαχειριστής ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 byte';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Κανάλι $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 χαρακτήρες';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return 'Το $arg1 διαγράφηκε.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return 'Το $arg1 έχει ρυθμιστεί';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return 'Συνδέθηκε το $arg1. Επιλέξτε αποθετήρια και άτομα στην ενότητα Ποιος μπορεί να στείλει μήνυμα.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 εγγραφές πυρήνα.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return 'Το $arg1 δημιούργησε έναν σύνδεσμο πρόσκλησης';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 επιφάνεια εργασίας';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 συμβάντα';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · Το $arg1 απέτυχε';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return 'Το $arg1 απέτυχε';
  }

  @override
  String arg1Failing(Object? arg1) {
    return 'Αποτυχία $arg1';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 για $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Ομάδες $arg1 μόνο με ετικέτα';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h πριν';
  }

  @override
  String arg1HArg2M(Object? arg1, Object? arg2) {
    return '${arg1}h ${arg2}m';
  }

  @override
  String arg1HArg2Min(Object? arg1, Object? arg2) {
    return '$arg1 h $arg2 ελάχ';
  }

  @override
  String arg1Helpers(Object? arg1) {
    return 'Βοηθοί $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 αναλογία επιτυχίας)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return 'Ο @$arg1 είναι διαχειριστής, επομένως ο λογαριασμός δεν μπορεί να διαγραφεί ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return 'Το $arg1 είναι αποκλεισμένο στο $arg2. Ενημερώστε τη λίστα πρόσβασης για να επιτρέψετε τις απαντήσεις.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return 'Το $arg1 είναι συνδεδεμένο και αποκρίνεται.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return 'Ο $arg1 δεν είναι πλέον διαχειριστής ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return 'Το $arg1 δεν είναι διαθέσιμο στο $arg2 (λείπει άδεια χρόνου εκτέλεσης ή εξάρτηση).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return 'Το $arg1 εντάχθηκε κάτω από το $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 κρίνεται από την LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Το κλειδί $arg1$arg2 έχει ρυθμιστεί';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Το κλειδί $arg1 αφαιρέθηκε.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 αριστερά';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 αριστερά $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return 'Το $arg1 συνδέεται';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m πριν';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Βεβαιωθείτε ότι λειτουργεί και, στη συνέχεια, δοκιμάστε ξανά.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return 'Ο $arg1 διαχειρίζεται αυτόν τον λογαριασμό';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 ελάχ';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 min $arg2 δευτ';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Τα μοντέλα $arg1 είναι έτοιμα';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 περισσότερα';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 περισσότερα βήματα στο ιστορικό εκτέλεσης';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return 'Το $arg1 μετακινήθηκε από το $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return 'Το $arg1 πρέπει να είναι πεπερασμένος αριθμός.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return 'Το $arg1 πρέπει να είναι διεύθυνση http:// ή https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return 'Το $arg1 χρειάζεται προσοχή';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Χώρος εργασίας $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 νέοι λογαριασμοί στο τελευταίο $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · νέα μηνύματα καθοδηγούν αυτή τη διαδρομή';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 νέες εκδόσεις';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return 'Το $arg1 διαχειρίζεται τώρα αυτόν τον λογαριασμό.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 4 αδειών επιτρέπονται. Τα αρχεία περιορίζονται στο φάκελο NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 από $arg2 ενεργοποιημένο';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return 'Οι $arg1 των ομάδων $arg2 συμμετέχουν στη συνηθισμένη συνομιλία';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 των μοντέλων $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return 'Έτοιμο το $arg1 των μοντέλων $arg2';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return 'Σετ $arg1 του $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Επιτρέπονται τα $arg1 των εργαλείων $arg2';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Εντάξει';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 την ημέρα $arg2 στο $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return 'Το $arg1 απαντά μόνο στα άτομα που προσθέτετε παρακάτω.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return 'Το $arg1 απαντά μόνο όταν έχει επισημανθεί';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return 'Το $arg1 μιλά μόνο με άτομα και ομάδες που εγκρίνετε';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Προστέθηκαν άτομα ή ομάδες $arg1';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 προγραμματισμός';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Πάροχοι $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 έτοιμο';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Εγγραφές $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI ανακατεύθυνσης $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return 'Το $arg1 έχει εγγραφεί';
  }

  @override
  String arg1Replied(Object? arg1) {
    return 'Ο $arg1 απάντησε';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return 'Το $arg1 ανακάλεσε έναν σύνδεσμο πρόσκλησης';
  }

  @override
  String arg1Runs(Object? arg1) {
    return 'Το $arg1 εκτελείται';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return 'Εκτελείται το $arg1 · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Το $arg1 εκτελείται στο τελευταίο $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return 'Το $arg1 αποθηκεύτηκε.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 δευτ';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Επιλέχθηκε το $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Εμφανίζεται το $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return 'Ο $arg1 έμεινε ήσυχος';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 τιμόνι $arg2 σε ουρά';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 βήμα$arg2 · πατήστε έναν κόμβο για επιθεώρηση';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 βήματα';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return 'Ο $arg1 σταμάτησε να διαχειρίζεται το $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'μάρκες $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 διακριτικά στο τελευταίο $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Εργαλεία $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (μη διαθέσιμη αποθηκευμένη παράκαμψη)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% χρησιμοποιημένο · Απομένει $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return 'Ο $arg1 θέλει να μιλήσει μαζί σας.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'Ιστός $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return 'Το \"$arg1\" θα καταργηθεί οριστικά.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return 'Ο $arg1 θα διαχειρίζεται αυτόν τον λογαριασμό';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return 'Το $arg1 δεν θα απαντήσει σε αυτήν την πλατφόρμα';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return 'Ο $arg1 δεν θα απαντήσει στο $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Αποθήκευση τεχνουργημάτων ανά χρήστη';

  @override
  String get askAQuestionOrStartA =>
      'Κάντε μια ερώτηση ή ξεκινήστε μια εργασία...';

  @override
  String get askBeforeClosingToBackground => 'Ρωτήστε πριν κλείσετε στο φόντο';

  @override
  String get askMe => 'Ρώτα με';

  @override
  String get assignedAgent => 'Ορισμένος πράκτορας';

  @override
  String get assignedAgent2 => 'Εντεταλμένος πράκτορας';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Εκτεθειμένος αντιπρόσωπος: $arg1';
  }

  @override
  String get assigneeOptional => 'Ανάδοχος (προαιρετικό)';

  @override
  String get assistant => 'Βοηθός';

  @override
  String get assistantKey131 => 'Βοηθητικό κλειδί 131';

  @override
  String get atLeast1 => 'Τουλάχιστον 1.';

  @override
  String get attachFiles => 'Επισύναψη αρχείων';

  @override
  String attentionArg1(Object? arg1) {
    return 'Προσοχή $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'αρχείο καταγραφής ελέγχου Ιστορικό ομάδας ανάκλησης επιχορήγησης διαχειριστή';

  @override
  String get authMethod => 'Μέθοδος Auth';

  @override
  String get authServerUrl => 'Διεύθυνση URL διακομιστή ελέγχου ταυτότητας';

  @override
  String get authentication => 'Έλεγχος ταυτότητας';

  @override
  String get authenticationFailed => 'Ο έλεγχος ταυτότητας απέτυχε.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Ο έλεγχος ταυτότητας είναι ακόμη σε εκκρεμότητα. Ολοκληρώστε τη ροή του προγράμματος περιήγησης και δοκιμάστε ξανά.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Ο έλεγχος ταυτότητας είναι ακόμη σε εκκρεμότητα. Ολοκληρώστε τη ροή του προγράμματος περιήγησης και ανανεώστε.';

  @override
  String get authenticationTimedOut => 'Ο χρόνος ελέγχου ταυτότητας έληξε.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Ο έλεγχος ταυτότητας ακυρώθηκε πριν από την ολοκλήρωση.';

  @override
  String get authenticatorApp => 'Εφαρμογή ελέγχου ταυτότητας';

  @override
  String get authenticatorCode => 'Κωδικός ελέγχου ταυτότητας';

  @override
  String get authorOptional => 'Συγγραφέας (προαιρετικό)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Αυτόματο (πρώτος πάροχος με κλειδί API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Αυτόματη διαδρομή προς το καλύτερο διαθέσιμο μοντέλο';

  @override
  String get automaticFast => 'Αυτόματο (γρήγορο)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Αυτόματο διαβάζει το δωμάτιο και συνήθως συγκρατεί. Η αναφορά-μόνο δεν λαμβάνει καμία κλήση απόφασης μέχρι να απευθυνθεί απευθείας.';

  @override
  String get automaticReserved => 'Αυτόματο, δεσμευμένο';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Η αυτόματη επαναφορά χρειάζεται επανάληψη από την οθόνη εγκατάστασης.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Το Automatic επιλέγει ένα γρήγορο μοντέλο μέσω του κανονικού καταλόγου μοντέλων.';

  @override
  String get automation => 'Αυτοματοποίηση';

  @override
  String get available => 'Διαθέσιμο';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Διαθέσιμο ξανά σε $arg1';
  }

  @override
  String get availableAgainShortly => 'Διαθέσιμο ξανά σύντομα';

  @override
  String get availableInTheDesktopAppFor =>
      'Διατίθεται στην εφαρμογή για υπολογιστές για macOS, Windows και Linux';

  @override
  String get availableToTheAgent => 'Διαθέσιμο στον πράκτορα';

  @override
  String get averageAllTime => 'Μέσος όρος, όλων των εποχών';

  @override
  String get avgImp => 'Μέσος απρ.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Μέσος όρος/τρέξιμο: $arg1 διακριτικά';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Αποφύγετε επαναλαμβανόμενους χαρακτήρες και εμφανείς ακολουθίες.';

  @override
  String get awaitingScan => 'Αναμονή σάρωσης';

  @override
  String get back => 'Πίσω';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count στο παρασκήνιο';
  }

  @override
  String get backgroundTasks => 'Εργασίες παρασκηνίου';

  @override
  String get backOn => 'πίσω.';

  @override
  String get backToChat => 'Επιστροφή στη συνομιλία';

  @override
  String get backToFolder => 'Επιστροφή στο φάκελο';

  @override
  String get backToSignIn => 'Επιστροφή για είσοδο';

  @override
  String get backendChannel => 'Backend κανάλι';

  @override
  String get backendOnThisComputer => 'Backend σε αυτόν τον υπολογιστή';

  @override
  String get backendSync => 'Συγχρονισμός backend';

  @override
  String get backgroundLocationNeeded => 'Απαιτείται τοποθεσία στο παρασκήνιο';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Ο συγχρονισμός στο παρασκήνιο παραμένει προγραμματισμένος στο Android';

  @override
  String get badState => 'Κακή κατάσταση: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Βασική εικόνα και μέγεθος των εικονικών μηχανών QEMU που εκτελούνται ';

  @override
  String get baseUrlOptional => 'URL βάσης (προαιρετικό)';

  @override
  String get baseUrlTokenLocal => 'τοπικό διακριτικό διεύθυνσης URL βάσης';

  @override
  String get basicAuthentication => 'Βασικός έλεγχος ταυτότητας';

  @override
  String get behaviorModules => 'Ενότητες Συμπεριφοράς';

  @override
  String get behaviorNotes => 'σημειώσεις συμπεριφοράς';

  @override
  String get beta => 'Βήτα';

  @override
  String get bitwardenCredentialBroker => 'Μεσίτης διαπιστευτηρίων Bitwarden';

  @override
  String get bitwardenItem => 'Αντικείμενο Bitwarden';

  @override
  String get bitwardenServer => 'Διακομιστής Bitwarden';

  @override
  String get blankUsesCommon => 'Το κενό χρησιμοποιεί \"κοινό\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Το Blank χρησιμοποιεί την προεπιλεγμένη επανάκληση';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Οι κενές τιμές χρησιμοποιούν τις προεπιλογές του παρόχου.';

  @override
  String get block => 'Αποκλεισμός';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Αποκλείστηκε το εισερχόμενο μήνυμα από το $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Γέφυρα συμβατή με BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL διακομιστή BlueBubbles';

  @override
  String get botToken => 'Διακριτικό bot';

  @override
  String get botTokenAndApprovedChats =>
      'Token bot και εγκεκριμένες συνομιλίες';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token bot και πρόσβαση διακομιστή/κανάλι';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token bot, API συμβάντων και πρόσβαση καναλιού';

  @override
  String get botUserId => 'Αναγνωριστικό χρήστη bot';

  @override
  String get botUsername => 'Όνομα χρήστη bot';

  @override
  String get brandName => 'Επωνυμία';

  @override
  String get braveSearch => 'Γενναία αναζήτηση';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Γεφυρώστε κάθε πάροχο που μπορεί να δημοσιεύει και να λαμβάνει ωφέλιμα φορτία webhook.';

  @override
  String get bringYourOwnKey => 'φέρτε το δικό σας κλειδί';

  @override
  String get bringYourOwnKey2 => 'Φέρτε το δικό σας κλειδί';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Το πρόγραμμα περιήγησης, η επιφάνεια εργασίας Linux, τα αρχεία, το τερματικό και η Python μοιράζονται έναν μόνιμο υπολογιστή cloud.';

  @override
  String get browserLogin => 'Είσοδος στο πρόγραμμα περιήγησης';

  @override
  String get browserScripting => 'Scripting προγράμματος περιήγησης';

  @override
  String get call => 'Καλέστε';

  @override
  String get callAgent => 'Κλήση πράκτορα';

  @override
  String get callUser => 'Κλήση χρήστη';

  @override
  String get calledByName => 'Καλούμενος με το όνομα';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Μπορεί να αναθέσει εργασίες σε άλλους πράκτορες';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Μπορεί να αναθέσει σε $arg1';
  }

  @override
  String get canReceiveDelegatedTasks =>
      'Μπορεί να λαμβάνει εργασίες που έχουν ανατεθεί';

  @override
  String get cancel => 'Ακύρωση';

  @override
  String get cancelTask => 'Ακύρωση εργασίας';

  @override
  String get cannotPreview => 'Δεν είναι δυνατή η προεπισκόπηση';

  @override
  String get cannotReceiveDelegatedTasks =>
      'δεν μπορεί να λάβει ανατεθείσες εργασίες';

  @override
  String get cannotRunYet => 'δεν μπορεί να τρέξει ακόμα.';

  @override
  String get capturedThePage => 'Κατέλαβε τη σελίδα';

  @override
  String get category => 'Κατηγορία';

  @override
  String chainArg1(Object? arg1) {
    return 'Αλυσίδα: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Αλλαγή λειτουργίας ρύθμισης';

  @override
  String get channel => 'Κανάλι';

  @override
  String get channelAccessToken => 'Διακριτικό πρόσβασης καναλιού';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Κανάλι: $arg1$arg2 | Έκδοση ενημέρωσης: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Κοινωνική μνήμη εύρους καναλιού';

  @override
  String get channels => 'Κανάλια';

  @override
  String get chat => 'Συνομιλία';

  @override
  String get chatId => 'Αναγνωριστικό συνομιλίας';

  @override
  String get chatMode => 'Λειτουργία συνομιλίας';

  @override
  String get chatModel => 'Μοντέλο συνομιλίας';

  @override
  String get checkAutomaticallyOnLaunch => 'Ελέγξτε αυτόματα κατά την εκκίνηση';

  @override
  String get checkForMessagesEveryMs => 'Έλεγχος για μηνύματα κάθε (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Ελέγξτε για νέα μηνύματα αυτόματα';

  @override
  String get checkNow => 'Ελέγξτε τώρα';

  @override
  String get checkYourEmailToConfirmYour =>
      'Ελέγξτε το email σας για να επιβεβαιώσετε τον λογαριασμό σας στο NeoAgent πριν συνδεθείτε.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Έλεγξε το $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Επιλέξτε μια κατηγορία ή πραγματοποιήστε αναζήτηση σε όλες τις ρυθμίσεις.';

  @override
  String get chooseAPerson => 'Επιλέξτε ένα άτομο';

  @override
  String get chooseAProjectFolder => 'Επιλέξτε ένα φάκελο έργου';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Επιλέξτε προεπιλογές για συνομιλία, πράκτορες, εναλλακτική συμπεριφορά και έξυπνη δρομολόγηση.';

  @override
  String get chooseGroups => 'Επιλέξτε ομάδες';

  @override
  String get chooseHowMuchYouWantTo =>
      'Επιλέξτε πόσο θέλετε να διαμορφώσετε τώρα. Και οι δύο επιλογές μπορούν να αλλάξουν αργότερα.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Επιλέξτε πώς θα ξεκινήσει αυτή η εργασία. Το Manual εκτελείται μόνο στο Run Now. Το χρονοδιάγραμμα βασίζεται στον χρόνο. Η ενσωμάτωση ενεργοποιεί πυρκαγιά από συνδεδεμένες επίσημες εφαρμογές.';

  @override
  String get chooseOneToGetStartedNow =>
      'Επιλέξτε ένα για να ξεκινήσετε τώρα. Μπορείτε να προσθέσετε περισσότερα αργότερα.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Επιλέξτε το ζωντανό μοντέλο και τη φωνή στις Ρυθμίσεις.';

  @override
  String get chooseTheirGroup => 'Επιλέξτε την ομάδα τους';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Επιλέξτε πού θα επιτρέπεται σε αυτό το άτομο να μιλήσει με τον $arg1. Μπορείτε να το αλλάξετε αργότερα στην ενότητα Ποιος μπορεί να στείλει μήνυμα.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Επιλέξτε σε ποιες ομάδες θα συμμετέχει το $arg1 ακόμα και όταν κανείς δεν του προσθέτει ετικέτα. Αυτή η πλατφόρμα ενδέχεται να μην ξεχωρίζει τις ετικέτες από τα κανονικά μηνύματα.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Επιλέξτε ποια μοντέλα μπορεί να επιλέξει κάθε λογαριασμός σε αυτόν τον διακομιστή και ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Επιλέξτε με ποιον συνομιλεί το $arg1 και πότε συμμετέχει σε ομαδικές συνομιλίες.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Επιλέξτε ποιος μπορεί να φτάσει στο $arg1 και, στη συνέχεια, αποθηκεύστε τις αλλαγές σας.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Επιλέξτε ποιος μπορεί να στείλει μήνυμα στον πράκτορα με το \"Who can message\" στην κάρτα WhatsApp.';

  @override
  String get chooseYourDefaultModel =>
      'Επιλέξτε το προεπιλεγμένο\nμοντέλο σας.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Το Chromium, τα αρχεία, το πρόγραμμα επεξεργασίας κειμένου και το τερματικό είναι όλα διαθέσιμα από την επιφάνεια εργασίας Linux.';

  @override
  String get claudeCode => 'Κώδικας Κλοντ';

  @override
  String get clear => 'Εκκαθάριση';

  @override
  String get clearAll => 'Καθαρίστε όλα';

  @override
  String clearArg1(Object? arg1) {
    return 'Διαγραφή $arg1;';
  }

  @override
  String get clearFilter => 'Καθαρίστε το φίλτρο';

  @override
  String get clearFilters => 'Καθαρίστε τα φίλτρα';

  @override
  String get clearSearch => 'Εκκαθάριση αναζήτησης';

  @override
  String get clearView => 'Καθαρή όψη';

  @override
  String get cliSession => 'Συνεδρία CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'το κλικ δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get clickOnceToBeginCapturing =>
      'Κάντε κλικ μία φορά για να ξεκινήσετε τη λήψη';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Κάντε κλικ, πληκτρολογήστε και αλληλεπιδράστε με εφαρμογές επιφάνειας εργασίας.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Κάντε κλικ στο ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Κάντε κλικ στο πρόγραμμα περιήγησης';

  @override
  String get clientId => 'Αναγνωριστικό πελάτη';

  @override
  String get clientSecret => 'Μυστικό πελάτη';

  @override
  String get close => 'Κλείσιμο';

  @override
  String get closeJ => 'Κλείσιμο (⌘J)';

  @override
  String get closeTeachMode => 'Κλείστε τη λειτουργία διδασκαλίας';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Το κλείσιμο του παραθύρου μπορεί είτε να διατηρήσει το NeoAgent σε λειτουργία στο παρασκήνιο με πρόσβαση στο δίσκο είτε να τερματίσει πλήρως τον χρόνο εκτέλεσης στην επιφάνεια εργασίας.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Υποστηρίζονται περιπτώσεις cloud και self-hosted. Οι διευθύνσεις URL τοπικού και ιδιωτικού δικτύου λειτουργούν όταν το NeoAgent μπορεί να τις προσεγγίσει.';

  @override
  String get cloudComputer => 'Υπολογιστής cloud';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Υπολογιστής cloud · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Οι ρυθμίσεις του υπολογιστή Cloud αποθηκεύτηκαν. Κάντε επανεκκίνηση του διακομιστή για να τα εφαρμόσετε.';

  @override
  String get cloudComputerVm => 'Υπολογιστής cloud (VM)';

  @override
  String get cloudComputers => 'υπολογιστές cloud';

  @override
  String get codeHosting => 'Φιλοξενία κώδικα';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Ονόματα καναλιών διαχωρισμένα με κόμματα, χωρίς το #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Διαχωρίζονται με κόμματα, για παράδειγμα #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Διαχωρίστηκε με κόμμα. Το θέμα πρέπει να τα έχει όλα.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Η εντολή απέτυχε ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Απαιτείται εντολή.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Ο συσσωρευτής εξόδου εντολών δεν είναι ενεργός.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Η μεταφόρτωση εξόδου εντολής απέτυχε ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Εξόδου εντολής μεταφόρτωση παραλειφθέντων μεταδεδομένων τεχνουργήματος.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Η έξοδος εντολών είχε ήδη οριστικοποιηθεί.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Εντολές και εφαρμογές';

  @override
  String get commandsRunInTheSamePersistent =>
      'Οι εντολές εκτελούνται στον ίδιο μόνιμο υπολογιστή που χρησιμοποιείται από την ορατή επιφάνεια εργασίας.';

  @override
  String get communityChatops => 'Κοινότητα & ChatOps';

  @override
  String get completeSetup => 'Ολοκληρώστε την εγκατάσταση';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Ολοκληρώστε τη ροή εργασίας στην επιφάνεια εργασίας.';

  @override
  String get completed => 'Ολοκληρώθηκε';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Πλήρως αποκλεισμένος — ο πράκτορας δεν μπορεί να χρησιμοποιήσει αυτήν την κατηγορία.';

  @override
  String get computerShell => 'Κέλυφος υπολογιστή';

  @override
  String get computerUsedByThisSession =>
      'Υπολογιστής που χρησιμοποιείται από αυτήν την περίοδο λειτουργίας';

  @override
  String get computerWorkspace => 'Χώρος εργασίας υπολογιστή';

  @override
  String get configurablePersonalWebhookBridge =>
      'Ρυθμιζόμενη προσωπική γέφυρα webhook';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Ρελέ ή γέφυρα webhook με δυνατότητα διαμόρφωσης';

  @override
  String get configurableTalkWebhookBridge => 'Ρυθμιζόμενη γέφυρα Talk webhook';

  @override
  String get configurableWebInboxBridge =>
      'Γέφυρα εισερχομένων ιστού με δυνατότητα διαμόρφωσης';

  @override
  String get configurableWebhookBridge =>
      'Γέφυρα webhook με δυνατότητα διαμόρφωσης';

  @override
  String get configurableWebhooks => 'Διαμορφώσιμα Webhooks';

  @override
  String get configurationOrInTheEnvFile => 'Διαμόρφωση ή στο αρχείο .env.';

  @override
  String get configure => 'Διαμόρφωση';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Διαμόρφωση συμπεριφοράς χώρου εργασίας και προεπιλογών μοντέλου.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Διαμορφώθηκε το $arg1';
  }

  @override
  String get confirmEmailChanges => 'Επιβεβαιώστε τις αλλαγές email';

  @override
  String get confirmNewSignUps => 'Επιβεβαιώστε νέες εγγραφές';

  @override
  String get confirmPassword => 'Επιβεβαίωση κωδικού πρόσβασης';

  @override
  String get confirmPassword2 => 'Επιβεβαίωση κωδικού πρόσβασης';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Επιβεβαιώστε το email σας πριν συνδεθείτε. Ελέγξτε το μήνυμα email υπηρεσίας από το NeoAgent.';

  @override
  String get connect => 'Συνδεθείτε';

  @override
  String get connectAMessagingPlatform =>
      'Συνδέστε μια πλατφόρμα\nανταλλαγής μηνυμάτων.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Συνδέστε ένα δημόσιο τελικό σημείο του HTTPS Home Assistant με ένα διακριτικό πρόσβασης μακράς διαρκείας. Οι τοπικές διευθύνσεις, οι διευθύνσεις loopback και οι ιδιωτικές διευθύνσεις δικτύου αποκλείονται από τον διακομιστή.';

  @override
  String get connectAccount => 'Σύνδεση λογαριασμού';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Συνδέστε τους λογαριασμούς εφαρμογών μεμονωμένα, ώστε το AI να μπορεί να χρησιμοποιεί τον σωστό λογαριασμό για κάθε επίσημη ενσωμάτωση.';

  @override
  String connectArg1(Object? arg1) {
    return 'Συνδέστε το $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Συνδέστε όσους λογαριασμούς θέλετε. Κάθε εφαρμογή μπορεί να χρησιμοποιεί διαφορετικό λογαριασμό.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Συνδέστε κανάλια, επιλέξτε με ποιον συνομιλεί ο $arg1 και παρακολουθήστε την πρόσφατη δραστηριότητα.';
  }

  @override
  String get connectInstance => 'Σύνδεση παρουσίας';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Συνδέστε πρώτα αυτήν την ενοποίηση για να επιλέξετε έναν λογαριασμό.';

  @override
  String get connectToThisServer => 'Συνδεθείτε σε αυτόν τον διακομιστή';

  @override
  String get connectWhatsapp => 'Συνδέστε το WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Συνδέστε το στιγμιότυπο του Nextcloud, συμπεριλαμβανομένων των αυτο-φιλοξενούμενων διακομιστών. Το NeoAgent ανοίγει τη σελίδα σύνδεσης του Nextcloud, ώστε να μπορείτε να συνδεθείτε με κωδικό πρόσβασης, SSO ή 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Συνδέστε τον αυτο-φιλοξενούμενο διακομιστή NeoRecall. Το NeoAgent λαμβάνει πρόσβαση μόνο για ανάγνωση στην τοπική αναζήτηση, τις μνήμες και τα στοιχεία μεταγραφής αφού εγκρίνετε την οθόνη OAuth.';

  @override
  String get connected => 'Συνδεδεμένος';

  @override
  String get connectedAccount => 'Συνδεδεμένος λογαριασμός';

  @override
  String connectedArg1(Object? arg1) {
    return 'Συνδεδεμένο $arg1';
  }

  @override
  String get connectedInstance => 'Συνδεδεμένη περίπτωση';

  @override
  String get connectedNeorecallUser => 'Συνδεδεμένος χρήστης NeoRecall';

  @override
  String get connectedNextcloudUser => 'Συνδεδεμένος χρήστης Nextcloud';

  @override
  String get connectedServer => 'Συνδεδεμένος διακομιστής';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Σύνδεση με το μοντέλο ζωντανής φωνής...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Σύνδεση #$arg1';
  }

  @override
  String get connectionId => 'Αναγνωριστικό σύνδεσης';

  @override
  String get connectionLooksGood => 'Η σύνδεση φαίνεται καλή.';

  @override
  String get connectionMethod => 'Μέθοδος Σύνδεσης';

  @override
  String get containsTextOptional => 'Περιέχει κείμενο (προαιρετικό)';

  @override
  String get content => 'περιεχόμενο';

  @override
  String get contentSecurityPolicy => 'πολιτική ασφάλειας περιεχομένου';

  @override
  String get continue2 => 'Συνέχεια';

  @override
  String get continueFullSetup => 'Συνεχίστε την πλήρη εγκατάσταση';

  @override
  String get continueRun => 'Συνέχισε το τρέξιμο';

  @override
  String get continueToSetup => 'Συνεχίστε τη ρύθμιση';

  @override
  String get controlSurface => 'ΕΠΙΦΑΝΕΙΑ ΕΛΕΓΧΟΥ';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Ελέγχει την πρόσβαση στα εργαλεία $arg1.';
  }

  @override
  String get conversation => 'Συνομιλία';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Το αναγνωριστικό συνομιλίας χρησιμοποιείται όταν αυτός ο πράκτορας ξεκινά μια συνομιλία.';

  @override
  String get cookieSetup => 'Ρύθμιση cookie';

  @override
  String get cookiesNotConfigured => 'Τα cookie δεν έχουν διαμορφωθεί';

  @override
  String get copiedAsCsv => 'Αντιγράφηκε ως CSV';

  @override
  String get copiedDebugInfo => 'Αντιγράφηκαν πληροφορίες εντοπισμού σφαλμάτων';

  @override
  String get copiedExportForTheLast5 =>
      'Αντιγράφηκε η εξαγωγή για τα τελευταία 5 μηνύματα';

  @override
  String get copiedFullPrompt => 'Αντιγράφηκε η πλήρης προτροπή';

  @override
  String get copiedLogs => 'Αντιγραμμένα αρχεία καταγραφής';

  @override
  String get copiedRunId => 'Αντιγράφηκε το αναγνωριστικό εκτέλεσης';

  @override
  String get copy => 'Αντιγραφή';

  @override
  String get copyAll => 'Αντιγράψτε όλα';

  @override
  String get copyCodes => 'Αντιγραφή κωδικών';

  @override
  String get copyCsv => 'Αντιγραφή CSV';

  @override
  String get copyDebugInfo => 'Αντιγραφή πληροφοριών εντοπισμού σφαλμάτων';

  @override
  String get copyLink => 'Αντιγραφή συνδέσμου';

  @override
  String get copyLogs => 'Αντιγραφή αρχείων καταγραφής';

  @override
  String get copyPrompt => 'Προτροπή αντιγραφής';

  @override
  String get copyResponse => 'Αντιγραφή απάντησης';

  @override
  String get copyRunId => 'Αντιγράψτε το αναγνωριστικό εκτέλεσης';

  @override
  String get copyWebhookUrl => 'Αντιγραφή διεύθυνσης URL webhook';

  @override
  String get core => 'Πυρήνας';

  @override
  String get coreMemory => 'πυρήνα μνήμης';

  @override
  String get coreServicesThisServerDependsOn =>
      'Βασικές υπηρεσίες από τις οποίες εξαρτάται αυτός ο διακομιστής.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'Cors domain https προέλευση δημόσιας διεύθυνσης URL';

  @override
  String get couldHelp => 'Θα μπορούσε να βοηθήσει';

  @override
  String get couldNotApproveQrLogin => 'Δεν ήταν δυνατή η έγκριση σύνδεσης QR.';

  @override
  String get couldNotApproveQrPairing =>
      'Δεν ήταν δυνατή η έγκριση της σύζευξης QR.';

  @override
  String get couldNotConnect => 'Δεν ήταν δυνατή η σύνδεση.';

  @override
  String get couldNotCreateBinding => 'Δεν ήταν δυνατή η δημιουργία δέσμευσης.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Δεν ήταν δυνατή η διαγραφή του λογαριασμού σας: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Δεν ήταν δυνατή η αποσύνδεση του Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Δεν ήταν δυνατή η αποσύνδεση του Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Δεν ήταν δυνατή η αποσύνδεση του NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Δεν ήταν δυνατή η αποσύνδεση του Nextcloud.';

  @override
  String get couldNotDisconnectTrello =>
      'Δεν ήταν δυνατή η αποσύνδεση του Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Δεν ήταν δυνατή η εξαγωγή των δεδομένων σας: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Δεν ήταν δυνατή η φόρτωση των αποφάσεων';

  @override
  String get couldNotLoadUsageData =>
      'Δεν ήταν δυνατή η φόρτωση δεδομένων χρήσης.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Δεν ήταν δυνατό το αυτόματα άνοιγμα των ρυθμίσεων Linux.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Δεν ήταν δυνατό το άνοιγμα της σελίδας σύνδεσης παρόχου.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Δεν ήταν δυνατό το άνοιγμα της σελίδας σύνδεσης παρόχου.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Δεν ήταν δυνατό το άνοιγμα του στοιχείου κυκλοφορίας.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Δεν ήταν δυνατό το άνοιγμα του Trello στο πρόγραμμα περιήγησής σας.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Δεν ήταν δυνατό το άνοιγμα της λήψης αρχείου χώρου εργασίας.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Δεν ήταν δυνατή η ανάγνωση του πακέτου της εφαρμογής Android.';

  @override
  String get couldNotReadTheApk => 'Δεν ήταν δυνατή η ανάγνωση του APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Δεν ήταν δυνατή η αφαίρεση του κλειδιού: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Δεν ήταν δυνατή η αποθήκευση του πράκτορα.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης του Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης του Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης του Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'δεν ήταν δυνατή η αποστολή email επιβεβαίωσης';

  @override
  String get couldNotStart => 'Δεν ήταν δυνατή η έναρξη';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Δημιουργία';

  @override
  String get createAPasswordFirstToChange =>
      'Δημιουργήστε πρώτα έναν κωδικό πρόσβασης για να αλλάξετε το email του λογαριασμού σας.';

  @override
  String get createAPasswordOrLinkAnother =>
      'δημιουργήστε έναν κωδικό πρόσβασης ή συνδέστε έναν άλλο πάροχο προτού καταργήσετε αυτήν τη μέθοδο σύνδεσης';

  @override
  String get createATaskWhileThisAgent =>
      'Δημιουργήστε μια εργασία ενώ είναι επιλεγμένος αυτός ο πράκτορας.';

  @override
  String get createLink => 'Δημιουργία συνδέσμου';

  @override
  String get createOrModifyFilesInYour =>
      'Δημιουργήστε ή τροποποιήστε αρχεία στον χώρο εργασίας σας.';

  @override
  String get createPassword => 'Δημιουργία κωδικού πρόσβασης';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Δημιουργήστε εξειδικευμένα bots με ξεχωριστή μνήμη, ρυθμίσεις, εργαλεία και αναθέσεις λογαριασμού.';

  @override
  String get createTheFirstAccount => 'Δημιουργήστε τον πρώτο λογαριασμό';

  @override
  String get createUpdateOrDeleteSkills =>
      'Δημιουργία, ενημέρωση ή διαγραφή δεξιοτήτων.';

  @override
  String get creatingYourSkill => 'Δημιουργώντας τις δεξιότητές σας…';

  @override
  String get credentialBindings => 'Δεσμεύσεις διαπιστευτηρίων';

  @override
  String get credentialUse => 'Χρήση διαπιστευτηρίων';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Επαναλαμβανόμενες εκτελέσεις με βάση το Cron και εκτέλεση με χρονική διάρκεια μιας φοράς.';

  @override
  String get cronExpression => 'Cron έκφραση';

  @override
  String get ctrlEnterRunsTheQuery => 'Το Ctrl/⌘ + Enter εκτελεί το ερώτημα.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Space';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Τρέχον email: $arg1';
  }

  @override
  String get currentPassword => 'Τρέχων κωδικός πρόσβασης';

  @override
  String get currentPasswordIsIncorrect =>
      'ο τρέχων κωδικός πρόσβασης είναι λανθασμένος';

  @override
  String get currentTwoStepLoginCode => 'Τρέχων κωδικός σύνδεσης δύο βημάτων';

  @override
  String get customAccess => 'Προσαρμοσμένη πρόσβαση';

  @override
  String get customCron => 'Προσαρμοσμένο Cron';

  @override
  String get customCronMustHave5Fields =>
      'Το προσαρμοσμένο Cron πρέπει να έχει 5 πεδία.';

  @override
  String get customEndpoint => 'προσαρμοσμένο τελικό σημείο';

  @override
  String get customField => 'Προσαρμοσμένο πεδίο';

  @override
  String get customHeader => 'Προσαρμοσμένη κεφαλίδα';

  @override
  String get customHeadersJson => 'Προσαρμοσμένες κεφαλίδες (JSON)';

  @override
  String get customOpenaiCompatible => 'Προσαρμοσμένο OpenAI-συμβατό';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Προσαρμοσμένο τελικό σημείο συμβατό με OpenAI';

  @override
  String get customOutgoingUrl => 'Προσαρμοσμένη εξερχόμενη διεύθυνση URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Καθημερινά';

  @override
  String get dailyRecap => 'Ημερήσια ανακεφαλαίωση';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'ερώτημα βάσης δεδομένων επιλέξτε πρότυπα csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Ημέρα $arg1';
  }

  @override
  String get dayOfMonth => 'Ημέρα του μήνα';

  @override
  String get decideWhichToolsYourAgentMay =>
      'αποφασίστε ποια εργαλεία μπορεί να χρησιμοποιήσει ο αντιπρόσωπός σας. Βλέπουν το όνομά σου και ';

  @override
  String get decisionHigherUpTheChainWins =>
      'απόφαση ψηλότερα η αλυσίδα κερδίζει και δείχνει ένα λουκέτο με το ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Οι αποφάσεις εμφανίζονται εδώ καθώς το $arg1 διαβάζει εγκεκριμένες ομάδες $arg2. Διατηρούνται μόνο τα τελευταία 30 και επαναφέρονται κατά την επανεκκίνηση του διακομιστή.';
  }

  @override
  String get decline => 'Απόρριψη';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'βαθύ τρέξιμο · βήμα $arg1';
  }

  @override
  String get deepgramKey => 'Κλειδί Deepgram';

  @override
  String get default2 => 'Προεπιλογή';

  @override
  String get default3 => 'ΠΡΟΕΠΙΛΟΓΗ';

  @override
  String defaultArg1(Object? arg1) {
    return 'Προεπιλογή ($arg1)';
  }

  @override
  String get defaultConversation => 'Προεπιλεγμένη συνομιλία';

  @override
  String get defaultForNewGroups => 'Προεπιλογή για νέες ομάδες';

  @override
  String get defaultGroupParticipation => 'Προεπιλεγμένη ομαδική συμμετοχή';

  @override
  String get defaultNeoagentWorkspace =>
      'Προεπιλεγμένος χώρος εργασίας NeoAgent';

  @override
  String get defaultOpenai => 'Προεπιλογή (OpenAI)';

  @override
  String get defaultRateLimits => 'Προεπιλεγμένα όρια ποσοστών';

  @override
  String get defaultRateLimitsSaved =>
      'Τα προεπιλεγμένα όρια τιμών αποθηκεύτηκαν.';

  @override
  String get defaultRecommended => 'Προεπιλογή (συνιστάται)';

  @override
  String get defaultRouting => 'Προεπιλεγμένη δρομολόγηση';

  @override
  String get defaultSpace => 'Προεπιλεγμένος χώρος';

  @override
  String get delete => 'Διαγραφή';

  @override
  String get deleteAccount => 'Διαγραφή λογαριασμού';

  @override
  String get deleteAccountPermanently => 'Μόνιμη διαγραφή λογαριασμού;';

  @override
  String get deleteAnAccount => 'Διαγραφή λογαριασμού';

  @override
  String deleteArg1(Object? arg1) {
    return 'Διαγραφή @$arg1;';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Διαγραφή ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Μόνιμη διαγραφή $arg1 $arg2;';
  }

  @override
  String get deleteBinding => 'Διαγραφή δέσμευσης';

  @override
  String get deleteCoreMemoryEntry => 'Διαγραφή καταχώρισης βασικής μνήμης;';

  @override
  String get deleteForever => 'Διαγραφή για πάντα';

  @override
  String get deleteMcpServer => 'Διαγραφή διακομιστή MCP;';

  @override
  String get deleteMemory => 'Διαγραφή μνήμης;';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Η διαγραφή διαγράφει οριστικά έναν λογαριασμό και όλα τα δεδομένα του ';

  @override
  String get deleteRun => 'Διαγραφή εκτέλεσης;';

  @override
  String get deleteRun2 => 'Διαγραφή εκτέλεσης';

  @override
  String get deleteSelectedMemories => 'Διαγραφή επιλεγμένων αναμνήσεων;';

  @override
  String get deleteSession => 'Διαγραφή συνεδρίας;';

  @override
  String get deleteSkill => 'Διαγραφή δεξιότητας;';

  @override
  String get deleteTask => 'Διαγραφή εργασίας;';

  @override
  String deletedArg1(Object? arg1) {
    return 'Διαγράφηκε το \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Διαγράφηκε το @$arg1 και όλα τα δεδομένα του.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Η διαγραφή αφαιρεί όλες τις συνομιλίες, τις αναμνήσεις, τα αρχεία, τις εργασίες και ';

  @override
  String get deliverableArtifactProduced => 'Παράγεται παραδοτέο τεχνούργημα';

  @override
  String get deliverableCompleted => 'Ολοκληρώθηκε η παράδοση';

  @override
  String get deliverableExecutionStarted => 'Ξεκίνησε η παραδοτέα εκτέλεση';

  @override
  String get deliverableSelected => 'Επιλέχθηκε το παραδοτέο';

  @override
  String get deliverableValidationFailed =>
      'Η επικύρωση με δυνατότητα παράδοσης απέτυχε';

  @override
  String get deliverableValidationStarted =>
      'Η επικύρωση της παράδοσης ξεκίνησε';

  @override
  String get deny => 'Αρνηθείτε';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Περιγράψτε το αποτέλεσμα και, στη συνέχεια, δείξτε το στην επιφάνεια εργασίας';

  @override
  String get describeWhatToBuildOrChange =>
      'Περιγράψτε τι να χτίσετε ή να αλλάξετε…';

  @override
  String get description => 'Περιγραφή';

  @override
  String get desktopApp => 'Εφαρμογή επιφάνειας εργασίας';

  @override
  String get desktopAppControlsAvailable =>
      'Διαθέσιμα στοιχεία ελέγχου εφαρμογών επιφάνειας εργασίας';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Η λήψη από επιτραπέζιους υπολογιστές δεν είναι διαθέσιμη σε αυτήν την πλατφόρμα.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Η μεταφόρτωση εξόδου εντολής επιφάνειας εργασίας ακυρώθηκε.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Η συνοδευτική εντολή επιφάνειας εργασίας ακυρώθηκε.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Το χρονικό όριο της συνοδευτικής σύνδεσης στην επιφάνεια εργασίας έληξε.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Το χρονικό όριο της χειραψίας συνοδευτικού επιτραπέζιου υπολογιστή έληξε.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Το Desktop Companion δεν είναι διαθέσιμο εδώ.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Το συνοδευτικό Desktop έχει τεθεί σε παύση τοπικά.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Ο χειρισμός του συνοδευτικού μηνύματος στην επιφάνεια εργασίας απέτυχε: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Οι ρυθμίσεις αδειών συνοδευτικών επιτραπέζιων υπολογιστών δεν είναι διαθέσιμες στον ιστό.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Οι ρυθμίσεις αδειών συνοδευτικών επιτραπέζιων υπολογιστών δεν είναι διαθέσιμες σε αυτήν την πλατφόρμα.';

  @override
  String get desktopCompanionRejected =>
      'Το συνοδευτικό επιτραπέζιου υπολογιστή απορρίφθηκε.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Η απόκριση συνοδευτικού επιτραπέζιου υπολογιστή απέτυχε: $arg1';
  }

  @override
  String get desktopControl => 'Έλεγχος επιφάνειας εργασίας';

  @override
  String get desktopFailedToStart =>
      'Η επιφάνεια εργασίας απέτυχε να ξεκινήσει';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Η λήψη ροής από επιφάνεια εργασίας απέτυχε: $arg1';
  }

  @override
  String get destinationId => 'Ταυτότητα προορισμού';

  @override
  String get deviceAccess => 'Πρόσβαση στη συσκευή';

  @override
  String get deviceSettings => 'Ρυθμίσεις συσκευής';

  @override
  String get devices => 'Συσκευές';

  @override
  String get diagnosticsSaved => 'Τα διαγνωστικά αποθηκεύτηκαν.';

  @override
  String get directBluebubblesImessageBridge =>
      'Άμεση γέφυρα BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Τα άμεσα μηνύματα παραμένουν αποκριτικά. Οι επιτρεπόμενες ομάδες χρησιμοποιούν τον παρακάτω τρόπο συμμετοχής.';

  @override
  String get directoryDoesNotExist => 'Ο κατάλογος δεν υπάρχει.';

  @override
  String get disable2fa => 'Απενεργοποιήστε το 2FA';

  @override
  String get disableAll => 'Απενεργοποίηση όλων';

  @override
  String get discard => 'Απορρίψτε';

  @override
  String get disconnect => 'Αποσύνδεση';

  @override
  String get disconnectHomeAssistant => 'Αποσύνδεση του Home Assistant;';

  @override
  String get disconnectNeorecall => 'Αποσύνδεση του NeoRecall;';

  @override
  String get disconnectNextcloud => 'Αποσύνδεση του Nextcloud;';

  @override
  String get disconnectPlatform => 'Αποσυνδέστε την πλατφόρμα';

  @override
  String get disconnectTrello => 'Αποσύνδεση Trello;';

  @override
  String get discoveryFailed => 'Η ανακάλυψη απέτυχε';

  @override
  String get dismiss => 'Απόρριψη';

  @override
  String get displayIdIsRequired => 'Απαιτείται αναγνωριστικό εμφάνισης.';

  @override
  String get displayName => 'Εμφανιζόμενο όνομα';

  @override
  String get displayNameMustBe64Characters =>
      'Το εμφανιζόμενο όνομα πρέπει να αποτελείται από 64 χαρακτήρες ή λιγότερους.';

  @override
  String get displayNameSaved => 'Το εμφανιζόμενο όνομα αποθηκεύτηκε.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Μην συμπεριλάβετε το όνομα χρήστη ή το email σας.';

  @override
  String get done => 'Έγινε';

  @override
  String get downloadACopyOfYourData =>
      'Κατεβάστε ένα αντίγραφο των δεδομένων σας. Δεν είναι δυνατή η διαγραφή λογαριασμών διαχειριστή ';

  @override
  String get downloadACopyOfYourData2 =>
      'Κατεβάστε ένα αντίγραφο των δεδομένων σας ή διαγράψτε οριστικά τον λογαριασμό σας. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Κατεβάστε το $arg1';
  }

  @override
  String get downloadUpdate => 'Λήψη ενημέρωσης';

  @override
  String get downloadingTheNeoagentBackend =>
      'Λήψη του συστήματος υποστήριξης NeoAgent';

  @override
  String get draft => 'Σχέδιο';

  @override
  String get dragIsNotSupportedOnThis =>
      'Το drag δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get draggedOnTheScreen => 'Σύρετε στην οθόνη';

  @override
  String get dropAnApkOrApkBundle =>
      'Ρίξτε ένα πακέτο APK ή APK εδώ για να το εγκαταστήσετε';

  @override
  String get dropApkOrApksHere => 'Απόθεση APK ή .apks Εδώ';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Ανθεκτικές οδηγίες για στυλ φωνής και αλληλεπίδρασης. Οι κανόνες ασφάλειας και εκτέλεσης εξακολουθούν να έχουν προτεραιότητα.';

  @override
  String get eGAlexSLaptop => 'π.χ. Το laptop του Alex';

  @override
  String get eGMyLocalServer => 'π.χ. Ο τοπικός μου διακομιστής';

  @override
  String get edit => 'Επεξεργασία';

  @override
  String get editAgent => 'Επεξεργασία πράκτορα';

  @override
  String get editCoreMemoryEntry => 'Επεξεργασία καταχώρισης μνήμης πυρήνα';

  @override
  String get editInstructions => 'Επεξεργασία οδηγιών';

  @override
  String get editMcpServer => 'Επεξεργασία διακομιστή MCP';

  @override
  String get editTask => 'Επεξεργασία εργασίας';

  @override
  String editedArg1(Object? arg1) {
    return 'Επεξεργάστηκε $arg1';
  }

  @override
  String get email => 'Email';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Στείλτε στους κατόχους λογαριασμών ηλεκτρονικού ταχυδρομείου σχετικά με τις συνδέσεις που φαίνονται ασυνήθιστες.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Στείλτε email στους κατόχους λογαριασμών όταν αλλάξουν τα στοιχεία του λογαριασμού τους.';

  @override
  String get emailCode => 'Κωδικός email';

  @override
  String get emailConfirmationRequired => 'απαιτείται επιβεβαίωση μέσω email';

  @override
  String get emailIsAlreadyInUse => 'Το email χρησιμοποιείται ήδη';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Το email αποθηκεύτηκε. Εάν απαιτείται επιβεβαίωση, ελέγξτε τη νέα διεύθυνση για έναν σύνδεσμο επιβεβαίωσης NeoAgent.';

  @override
  String get emailSettingsSaved => 'Οι ρυθμίσεις email αποθηκεύτηκαν.';

  @override
  String get emailUnverified => 'Το email δεν επαληθεύτηκε';

  @override
  String get empty => 'Άδειο';

  @override
  String get emptyFile => 'Κενό αρχείο';

  @override
  String get emptyFolder => 'Κενός φάκελος';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Το Empty χρησιμοποιεί την προεπιλογή διακομιστή ($arg1).';
  }

  @override
  String get enable2fa => 'Ενεργοποίηση 2FA';

  @override
  String get enableAll => 'Ενεργοποίηση όλων';

  @override
  String get enableBehaviorModules =>
      'Ενεργοποίηση λειτουργικών μονάδων συμπεριφοράς';

  @override
  String get enableOrDisableModels => 'Ενεργοποίηση ή απενεργοποίηση μοντέλων';

  @override
  String get enabled => 'Ενεργοποιημένο';

  @override
  String get encryptedPrivateToYourAccount =>
      'Κρυπτογραφημένο, ιδιωτικό στον λογαριασμό σας';

  @override
  String get end => 'Τέλος';

  @override
  String get endCall => 'Τερματισμός κλήσης';

  @override
  String get endVoiceCall => 'Τερματισμός φωνητικής κλήσης;';

  @override
  String get endpoint => 'Τελικό σημείο';

  @override
  String get enterAPassword => 'Εισαγάγετε έναν κωδικό πρόσβασης.';

  @override
  String get enterAUsername => 'Εισαγάγετε ένα όνομα χρήστη.';

  @override
  String get enterAValidEmailAddress =>
      'Εισαγάγετε μια έγκυρη διεύθυνση email.';

  @override
  String get enterAnAddressManually =>
      'Εισαγάγετε μια διεύθυνση με μη αυτόματο τρόπο';

  @override
  String get enterAnApiKeyFirst => 'Εισαγάγετε πρώτα ένα κλειδί API.';

  @override
  String get enterInviteLink => 'Εισαγάγετε τον σύνδεσμο πρόσκλησης';

  @override
  String get enterTheAddressOfANeoagent =>
      'Εισαγάγετε τη διεύθυνση ενός διακομιστή NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Εισαγάγετε τα στοιχεία που σας έδωσε το $arg1, ώστε το $arg2 να μπορεί να στέλνει και να λαμβάνει μηνύματα.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Εισαγάγετε το 2FA ή τον κωδικό ανάκτησης.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Εισαγάγετε τον τρέχοντα κωδικό πρόσβασης για να τον αλλάξετε.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Εισαγάγετε τον τρέχοντα κωδικό πρόσβασής σας για να αποθηκεύσετε τις αλλαγές email.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Εισαγάγετε τα στοιχεία του λογαριασμού σας στο NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Εισαγάγετε το όνομα χρήστη ή το email του λογαριασμού σας. Το NeoAgent θα στείλει έναν σύνδεσμο επαναφοράς εάν μπορεί να ταιριάζει με τον λογαριασμό.';

  @override
  String get enterYourUsernameOrEmail =>
      'Εισαγάγετε το όνομα χρήστη ή το email σας.';

  @override
  String entityArg1(Object? arg1) {
    return 'Οντότητα: $arg1';
  }

  @override
  String get environment => 'Περιβάλλον';

  @override
  String get error => 'Σφάλμα';

  @override
  String errorArg1(Object? arg1) {
    return '\nσφάλμα: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Σφάλματα από το πρόσφατο αρχείο καταγραφής, ομαδοποιημένα κατά μήνυμα.';

  @override
  String get errorsProblemsFailures => 'λάθη προβλήματα αποτυχίες';

  @override
  String get eventTypesCommaSeparated =>
      'Τύποι συμβάντων (χωρισμένοι με κόμματα)';

  @override
  String get every15Minutes => 'Κάθε 15 λεπτά';

  @override
  String get every30Minutes => 'Κάθε 30 λεπτά';

  @override
  String get everyAccountOnThisServerLoses =>
      'Κάθε λογαριασμός σε αυτόν τον διακομιστή χάνει αυτό το κοινόχρηστο κλειδί. Λογαριασμοί ';

  @override
  String get everyAccountOnThisServerUses =>
      'Κάθε λογαριασμός σε αυτόν τον διακομιστή χρησιμοποιεί αυτήν τη διεύθυνση ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Κάθε ενεργή περίοδος σύνδεσης για αυτόν τον λογαριασμό τελειώνει. Μπορούν να συνδεθούν ';

  @override
  String get everyDay0800 => 'Καθημερινά · 08:00';

  @override
  String get everyDay2000 => 'Καθημερινά · 20:00';

  @override
  String get everyHour => 'Κάθε ώρα';

  @override
  String get everyRunOnThisServerAll =>
      'Κάθε εκτέλεση σε αυτόν τον διακομιστή, πάντα.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Κάθε ευαίσθητο εργαλείο απαιτεί έγκριση, κάθε φορά.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Κάθε εργαλείο τρέχει χωρίς να ρωτήσει, εκτός από αυτά του ατόμου ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Όλοι σε αυτές τις ομάδες, κανάλια ή δωμάτια μπορούν να μιλήσουν στον $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Όλοι σε αυτήν την ομάδα';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Ό,τι είναι απενεργοποιημένο το $arg1 για τον αντιπρόσωπό σας έρχεται ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Όλα τα άλλα είναι απενεργοποιημένα.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Όλα είναι διαθέσιμα από την επιφάνεια εργασίας.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Όλα όσα μπορεί να χρησιμοποιήσει ο πράκτορας: επίσημες ενσωματώσεις, διακομιστές MCP και δεξιότητες.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Όλα όσα απενεργοποιήσατε για το $arg1 επιστρέφουν ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Οι ακριβείς προελεύσεις ιστού επιτρέπεται να υποβάλλουν αιτήματα διασταυρούμενης προέλευσης, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Εκτελέστε JavaScript μέσα στην περίοδο λειτουργίας του προγράμματος περιήγησής σας.';

  @override
  String get execution => 'Εκτέλεση';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Οι λεπτομέρειες εκτέλεσης δεν είναι διαθέσιμες για αυτήν την εκτέλεση.';

  @override
  String get executionPlanCreated => 'Δημιουργήθηκε σχέδιο εκτέλεσης.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Άσκηση συνεδρίες $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[έξοδος $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Λήγει $arg1';
  }

  @override
  String get explainThisProject => 'Εξηγήστε αυτό το έργο';

  @override
  String exploredArg1(Object? arg1) {
    return 'Εξερευνημένο $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Εξερεύνηση $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Εξερευνήστε τον χώρο εργασίας';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Η εξαγωγή απέτυχε: $arg1';
  }

  @override
  String get exportLast5Messages => 'Εξαγωγή των τελευταίων 5 μηνυμάτων';

  @override
  String get exportMyData => 'Εξαγωγή των δεδομένων μου';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Η εκκίνηση του εξωτερικού προγράμματος περιήγησης απέτυχε με τον κωδικό εξόδου $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Η εκκίνηση του εξωτερικού προγράμματος περιήγησης δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Το χρονικό όριο εκκίνησης του εξωτερικού προγράμματος περιήγησης έληξε.';

  @override
  String get externalMcpTools => 'Εξωτερικά & MCP Εργαλεία';

  @override
  String get extraButtons => 'Επιπλέον κουμπιά';

  @override
  String get extractingTheNeoagentRuntime =>
      'Εξαγωγή του χρόνου εκτέλεσης NeoAgent';

  @override
  String get failed => 'Απέτυχε';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Αποτυχία σύνδεσης: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Αποτυχία σύνδεσης $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Αποτυχία διαγραφής \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'απέτυχε η ανάκτηση';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Αποτυχία δημιουργίας προτροπής: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Αποτυχία εκκίνησης εξωτερικού προγράμματος περιήγησης μέσω url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Απέτυχε η εκκίνηση της ροής OAuth.';

  @override
  String get failedToLoadPolicies => 'Αποτυχία φόρτωσης πολιτικών';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Αποτυχία αποθήκευσης: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Αποτυχία αποθήκευσης διακομιστή MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Αποτυχία αποθήκευσης της επιλογής: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Αποτυχία αποστολής ειδοποίησης στο backend: $arg1';
  }

  @override
  String get fair => 'Δίκαιο';

  @override
  String get fasterReplies => 'Γρήγορες απαντήσεις';

  @override
  String get fewerModelCalls => 'Λιγότερες κλήσεις μοντέλου';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'κενό πεδίο για επαναφορά της ενσωματωμένης προεπιλογής.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Το αρχείο υπερβαίνει το όριο επεξεργασίας 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Το αρχείο υπερβαίνει το υποστηριζόμενο όριο μεγέθους.';

  @override
  String get fileWrites => 'Το αρχείο γράφει';

  @override
  String get filename => 'Όνομα αρχείου';

  @override
  String get files => 'Αρχεία';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Τα αρχεία που γράφει ή επεξεργάζεται το NeoAgent σε αυτήν την περίοδο λειτουργίας εμφανίζονται εδώ.';

  @override
  String get filesSavedByAllUsers =>
      'Αρχεία που αποθηκεύονται από όλους τους χρήστες';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Συμπληρώστε εγκεκριμένα στοιχεία σύνδεσης ή επαληθεύστε αιτήματα χωρίς να δείξετε μυστικά στο AI.';

  @override
  String get finalResponse => 'Τελική απάντηση';

  @override
  String get findAPlatform => 'Βρείτε μια πλατφόρμα';

  @override
  String get findAndFixABug => 'Βρείτε και διορθώστε ένα σφάλμα';

  @override
  String get findRecentChats => 'Βρείτε πρόσφατες συνομιλίες';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Εύρεση του σωστού χρόνου εκτέλεσης NeoAgent';

  @override
  String get finish => 'Τελειώστε';

  @override
  String get finishAtTheScheduledTime => 'Τερματίστε την προγραμματισμένη ώρα';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Ολοκληρώστε τη σύνδεση στο $arg1 στο πρόγραμμα περιήγησής σας και, στη συνέχεια, συνδεθείτε ξανά.';
  }

  @override
  String get flowGraph => 'Γράφημα ροής';

  @override
  String get flutterApp => 'Εφαρμογή Flutter';

  @override
  String get focusedExecutionProfile => 'Εστιασμένο προφίλ εκτέλεσης';

  @override
  String get folderIdOptional => 'Αναγνωριστικό φακέλου (προαιρετικό)';

  @override
  String get folderUnavailable => 'Ο φάκελος δεν είναι διαθέσιμος';

  @override
  String get forExampleHttpsMatrixOrg => 'Για παράδειγμα https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Για φιλοξενούμενες ή προηγμένες ρυθμίσεις δικτύου';

  @override
  String get forLinksInEmailsBlankUses =>
      'Για συνδέσμους σε email. Το Blank χρησιμοποιεί τη δημόσια διεύθυνση URL του διακομιστή.';

  @override
  String get forgotPassword => 'Ξεχάσατε τον κωδικό πρόσβασης;';

  @override
  String get frameUnavailable => 'Το πλαίσιο δεν είναι διαθέσιμο';

  @override
  String freshnessArg1(Object? arg1) {
    return 'φρεσκάδα: $arg1';
  }

  @override
  String get fridays1700 => 'Παρασκευή · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Από το BotFather αφού δημιουργήσετε το bot.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Από εδώ και στο εξής, το $arg1 αποφασίζει ποια εργαλεία μπορεί να χρησιμοποιήσει ο αντιπρόσωπός σας. Αυτοί ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Από το Discord Developer Portal, κάτω από το bot σας.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Από την Κονσόλα προγραμματιστών LINE.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Από τον λογαριασμό πελάτη Matrix ή bot.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Από το twitchapps.com/tmi ή την εφαρμογή προγραμματιστή Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Πλήρης προτροπή';

  @override
  String get fullSetup => 'Πλήρης ρύθμιση';

  @override
  String get general => 'Στρατηγός';

  @override
  String get generalSettings => 'Γενικές ρυθμίσεις';

  @override
  String get generalSettingsSaved => 'Οι γενικές ρυθμίσεις αποθηκεύτηκαν.';

  @override
  String get generateAPromptForAnotherAi =>
      'Δημιουργήστε ένα μήνυμα προτροπής για άλλο AI, επικολλήστε την απόκριση εδώ για να εισαγάγετε μνήμες.';

  @override
  String get generatePrompt => 'Δημιουργία προτροπής';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Σφάλμα παρακολούθησης Geofence: $arg1';
  }

  @override
  String get getInspired => 'Εμπνευστείτε';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot και OpenAI Codex';

  @override
  String get githubIssueOpened => 'Το ζήτημα του GitHub άνοιξε';

  @override
  String get neorecallMemoryCreated => 'Δημιουργήθηκε η μνήμη NeoRecall';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Ο έλεγχος έκδοσης του GitHub απέτυχε με το HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Το ωφέλιμο φορτίο κυκλοφορίας του GitHub δεν ήταν λίστα εκδόσεων.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Όνομα χρήστη GitHub που άνοιξε το ζήτημα';

  @override
  String get globalSecurityMode => 'Λειτουργία παγκόσμιας ασφάλειας';

  @override
  String get gmailMessageReceived => 'Το μήνυμα Gmail ελήφθη';

  @override
  String get good => 'Καλό';

  @override
  String get goodAfternoon => 'Καλησπέρα';

  @override
  String get goodEvening => 'καλησπέρα';

  @override
  String get goodMorning => 'Καλημέρα';

  @override
  String get goodPasswordALittleMoreLength =>
      'Καλός κωδικός πρόσβασης. Λίγο περισσότερο μήκος το κάνει πιο δυνατό.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'Το GPT-Live χρησιμοποιεί το κλειδί σας OpenAI API, το Gemini Live το κλειδί σας Google AI. Οι αλλαγές ισχύουν για την επόμενη κλήση.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Παραχωρήστε δικαιώματα Health Connect πριν από το συγχρονισμό.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Ομάδα, κανάλι ή δωμάτιο';

  @override
  String get groupType => 'Τύπος ομάδας';

  @override
  String get groupsAndChannels => 'Ομάδες και κανάλια';

  @override
  String groupsArg1(Object? arg1) {
    return 'Ομάδες: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Ομάδες που δεν έχει δει ακόμα το $arg1 θα το ακολουθήσουν.';
  }

  @override
  String get handlesDirectTasksItself => 'Χειρίζεται άμεσες εργασίες';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Hands-free (μιλήστε ελεύθερα, διακόψτε οποιαδήποτε στιγμή)';

  @override
  String get headerName => 'Όνομα κεφαλίδας';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Επικεφαλίδες για τα θέματα που σας ενδιαφέρουν, φιλτραρισμένα για σήμα.';

  @override
  String get health => 'Υγεία';

  @override
  String get healthChecks => 'Έλεγχοι υγείας';

  @override
  String get healthConnect => 'υγεία σύνδεση';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Το Health Connect δεν είναι διαθέσιμο σε αυτήν τη συσκευή.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Κατάσταση συγχρονισμού Health Connect και αποθηκευμένες μετρήσεις υποστήριξης.';

  @override
  String get healthStatusIsUnavailable =>
      'Η κατάσταση της υγείας δεν είναι διαθέσιμη.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Ο συγχρονισμός υγείας είναι διαθέσιμος μόνο σε Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Εγγραφές Heart $arg1';
  }

  @override
  String get heldBack => 'Συγκρατήθηκε';

  @override
  String get helper => 'Βοηθός';

  @override
  String helperArg1(Object? arg1) {
    return 'Βοηθός: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'εδώ. Ανάκληση διαχειριστή με το \"neoagent admin revoke $arg1\" πρώτα.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Οι υψηλότερες τιμές κάνουν το NeoAgent πιο επιλεκτικό στις ομάδες.';

  @override
  String get highlyRecommended => 'Συνιστάται ανεπιφύλακτα';

  @override
  String get holdButton131ForTheAssistant =>
      'Κρατήστε πατημένο το κουμπί 131 για τον βοηθό.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Κρατήστε πατημένο το συνδυασμό πλήκτρων Ctrl+Shift+Space για να μιλήσετε';

  @override
  String get holdToTalk => 'Κράτα για να μιλήσεις.';

  @override
  String get holdToTalk2 => 'Κράτα για να μιλήσεις';

  @override
  String get home => 'Σπίτι';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Απαιτείται το διακριτικό πρόσβασης μακράς διαρκείας του Βοηθού σπιτιού.';

  @override
  String get homeAssistantSetup => 'Ρύθμιση Home Assistant';

  @override
  String get homeAssistantUrl => 'URL Βοηθού σπιτιού';

  @override
  String get homeAssistantUrlIsRequired =>
      'Απαιτείται η διεύθυνση URL του Home Assistant.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Κουπόνι Homeserver με ψηφοφορία δωματίου';

  @override
  String get homeserverUrl => 'URL διακομιστή οικίας';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'φιλοξενούμενη υπηρεσία). Τα κλειδιά σας είναι κρυπτογραφημένα και μπορούν να χρησιμοποιηθούν μόνο από ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Όνομα κεντρικού υπολογιστή του δικτύου IRC, για παράδειγμα irc.libera.chat';

  @override
  String get hourly => 'Ωριαία';

  @override
  String get hourlyInboxCheck => 'Ωριαίος έλεγχος εισερχομένων';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Πόσο καιρό οι σύνδεσμοι επιβεβαίωσης παραμένουν έγκυροι.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Πόσο συχνά αυτός ο αντιπρόσωπος αναζητά μηνύματα για νέα δωμάτια.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Πόσο συχνά αυτός ο πράκτορας αναζητά νέα μηνύματα σήματος.';

  @override
  String get howTeamsWork => 'Πώς λειτουργούν οι ομάδες';

  @override
  String get howThisServerIsReachedPlus =>
      'Πώς προσεγγίζεται αυτός ο διακομιστής, καθώς και διακόπτες σε όλο τον διακομιστή.';

  @override
  String get httpsSessionCookie => 'https cookie συνεδρίας';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Δεν μπορούσα να ολοκληρώσω αυτό το αίτημα αυτήν τη στιγμή. Δοκιμάστε ξανά σε λίγο.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Σε αδράνεια';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Εάν το $arg1 ζητήσει μια διεύθυνση URL webhook, επικολλήστε την έτσι ώστε τα μηνύματα να φτάσουν στο $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Εάν αυτός ο λογαριασμός έχει επιβεβαιωμένο email, το NeoAgent θα στείλει έναν σύνδεσμο επαναφοράς κωδικού πρόσβασης.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Εάν η υπηρεσία απαιτεί ένα διακριτικό για τα εξερχόμενα αιτήματα.';

  @override
  String get ignoreGroups => 'Παράβλεψη ομάδων';

  @override
  String get ignoreThisChat => 'Αγνοήστε αυτήν τη συνομιλία';

  @override
  String get ignoredChannels => 'Κανάλια που αγνοήθηκαν';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Παράβλεψη λανθασμένης μορφής συνοδευτικού μηνύματος επιφάνειας εργασίας: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Εφαρμόστε το παραπάνω σχέδιο.';

  @override
  String get implementThisPlan => 'Εφαρμόστε αυτό το σχέδιο';

  @override
  String get implicitTls => 'Σιωπηρό TLS';

  @override
  String get import => 'Εισαγωγή';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Η εισαγωγή απέτυχε: $arg1';
  }

  @override
  String get importFromComputer => 'Εισαγωγή από υπολογιστή';

  @override
  String get importMemoryTransfer => 'Εισαγωγή μεταφοράς μνήμης;';

  @override
  String get importance => 'Σημασία';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Εισαγόμενες μνήμες $arg1, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'Στην ομάδα του @$arg1';
  }

  @override
  String get inBackground => 'φόντο';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Τα εισερχόμενα και τα εξερχόμενα μηνύματα καναλιού θα εμφανίζονται εδώ.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Εισερχόμενες φωνητικές κλήσεις εντός εφαρμογής από το NeoAgent';

  @override
  String get incomingMessages => 'Εισερχόμενα μηνύματα';

  @override
  String get incomingNeoagentCall => 'Εισερχόμενη κλήση NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'ΕΙΣΕΡΧΟΜΕΝΗ ΚΛΗΣΗ ΝΕΟΠΑΡΑΓΟΝΤΗ';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Υποστήριξη εισερχόμενου webhook και εξερχόμενης επανάκλησης';

  @override
  String get incorporatingSteering => 'Ενσωματώνει σύστημα διεύθυνσης';

  @override
  String get input => 'Εισαγωγή';

  @override
  String get inputMode => 'Λειτουργία εισαγωγής';

  @override
  String get insertATemplate => 'Εισαγάγετε ένα πρότυπο';

  @override
  String get install => 'Εγκατάσταση';

  @override
  String get installASignedSelfContainedRuntime =>
      'Εγκαταστήστε έναν υπογεγραμμένο, αυτόνομο χρόνο εκτέλεσης. Δεν απαιτούνται εντολές Node.js, npm, Git και τερματικού.';

  @override
  String get installApk => 'Εγκαταστήστε το APK';

  @override
  String get installApkBundle => 'Εγκαταστήστε το APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Εγκαταστήστε το APK — κάντε κλικ ή αποθέστε ένα αρχείο .apk';

  @override
  String get installNeoagent => 'Εγκαταστήστε το NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Εγκαταστήστε το NeoAgent σε αυτόν τον υπολογιστή χωρίς τερματικό ή συνδεθείτε σε ένα που εκτελείται ήδη.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Εγκαταστήστε νέες εκδόσεις και επιλέξτε ποιο κανάλι ακολουθεί αυτός ο διακομιστής.';

  @override
  String get installTheBackend => 'Εγκαταστήστε το backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Εγκαταστήστε τον πυρήνα με επιπλέον προαιρετική ρύθμιση. Στη συνέχεια προστίθενται κλειδιά παρόχου AI, όπως και το Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Εγκαταστήστε τον ασφαλή πυρήνα και, στη συνέχεια, δημιουργήστε τον λογαριασμό σας. Προσθέστε κλειδιά παρόχου AI στη συνέχεια.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Εγκατεστημένο: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Εγκατεστημένο: $arg1 • Τελευταίο έλεγχο: $arg2';
  }

  @override
  String get instructions => 'Οδηγίες';

  @override
  String get integration => 'Ένταξη';

  @override
  String get integrationConnections => 'Συνδέσεις ολοκλήρωσης';

  @override
  String get integrationSettingsSaved =>
      'Οι ρυθμίσεις ενσωμάτωσης αποθηκεύτηκαν.';

  @override
  String get integrations => 'Ενσωματώσεις';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback και καταχωρήστε το ίδιο ';

  @override
  String get interruptAi => 'Διακοπή AI';

  @override
  String get invalid2fa => 'μη έγκυρο 2fa';

  @override
  String get invalidArgumentS => 'Μη έγκυρα ορίσματα: ';

  @override
  String get invalidCredentials => 'μη έγκυρα διαπιστευτήρια';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Μη έγκυρη δήλωση χρόνου εκτέλεσης NeoAgent.';

  @override
  String get inviteLink => 'Σύνδεσμος πρόσκλησης';

  @override
  String get inviteLinkReady => 'Έτοιμος ο σύνδεσμος πρόσκλησης';

  @override
  String get inviteLinks => 'Σύνδεσμοι πρόσκλησης';

  @override
  String get iphoneApp => 'Εφαρμογή iPhone';

  @override
  String get issues => 'Θέματα';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Τα ζητήματα εμφανίζονται μόλις φορτωθεί το αρχείο καταγραφής.';

  @override
  String get itCanTBeUndone => 'Δεν μπορεί να αναιρεθεί.';

  @override
  String get itMayHaveBeenDeleted => 'Μπορεί να έχει διαγραφεί.';

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
    return 'Έγινε μέλος του $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Εγγράφηκε τις τελευταίες 7 ημέρες';

  @override
  String get joiningATeam => 'Συμμετοχή σε ομάδα';

  @override
  String get joiningIsOffHere => 'Η συμμετοχή ολοκληρώθηκε εδώ';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Πεδίο JSON που περιέχει το κείμενο του μηνύματος. Συνήθως κείμενο.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Πεδίο JSON που προσδιορίζει σε ποιον απευθύνεται το μήνυμα.';

  @override
  String get jumpToLatest => 'Μετάβαση στο πιο πρόσφατο';

  @override
  String get justNow => 'μόλις τώρα';

  @override
  String get keepNeoagentRunning => 'Να συνεχίσει να λειτουργεί το NeoAgent;';

  @override
  String get keepRunning => 'Συνέχισε να τρέχεις';

  @override
  String get keepTaskRunning => 'Συνεχίστε την εκτέλεση της εργασίας';

  @override
  String get keepTheVaultAvailable => 'Κρατήστε το θησαυροφυλάκιο διαθέσιμο';

  @override
  String get keepThisLauncherUpToDate =>
      'Διατηρήστε αυτό το πρόγραμμα εκκίνησης ενημερωμένο.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Διατηρήστε αυτό το πλαίσιο ανοιχτό έως ότου η πλατφόρμα επιβεβαιώσει τη σύνδεση.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Διατηρήστε ορατό τον υπολογιστή αυτής της συνεδρίας';

  @override
  String get keepTrackOfYourAiUsage =>
      'Παρακολουθήστε τη χρήση του AI σας. Τα όρια επιβάλλονται για να διασφαλιστεί η δίκαιη χρήση σε όλη την πλατφόρμα.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Συνεχίστε να χρησιμοποιείτε τις εφαρμογές σας κανονικά. Το NeoAgent λειτουργεί στην ίδια οθόνη και ρωτά όποτε χρειάζεται νέα πρόσβαση.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Διατήρηση αυτής της συσκευής συνδεδεμένη';

  @override
  String get key => 'Κλειδί';

  @override
  String get keyIsRequired => 'Απαιτείται κλειδί.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Ζεύγη κλειδιών-τιμών που παραμένουν σε όλες τις συνομιλίες.';

  @override
  String get knowledgeGraph => 'Γράφημα Γνώσης';

  @override
  String get knowledgeView => 'Άποψη γνώσης';

  @override
  String get labelOnlyYouSeeIt => 'Ετικέτα (μόνο εσείς τη βλέπετε)';

  @override
  String get labelsOptional => 'Ετικέτες (προαιρετικά)';

  @override
  String get last24Hours => 'Τελευταίες 24 ώρες';

  @override
  String get last7Days => 'Τελευταίες 7 μέρες';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Τελευταίες 7 ημέρες: Τα διακριτικά $arg1 σε εκτελέσεις $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Τελευταίο $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Τελευταίο: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Τελευταίος μη κενός συγχρονισμός · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Τελευταία εκτέλεση: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Τελευταία εμφάνιση $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Τελευταία σύνδεση $arg1';
  }

  @override
  String get lastSyncSummary => 'Σύνοψη του τελευταίου συγχρονισμού';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Τελευταία χρήση: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Τελευταίο παράθυρο που έληξε $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'αργότερα απενεργοποιήθηκε και η εκκίνηση.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Τελευταία εκτέλεση · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Η εκκίνηση εφαρμογών για υπολογιστές δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get learnRoomNorms => 'Μάθετε τους κανόνες του δωματίου';

  @override
  String get leave => 'Φύγε';

  @override
  String get leaveARedirectUriBlankTo =>
      'Αφήστε ένα URI ανακατεύθυνσης κενό για να χρησιμοποιήσετε το <public URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Αποχωρήστε από την ομάδα του $arg1;';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Αφήστε ως προεπιλογή, εκτός εάν προσαρμόσατε το BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Αφήστε το διακριτικό κενό για να διατηρήσετε το τρέχον αποθηκευμένο διακριτικό.';

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
    return 'Αφήστε το $arg1 να με διαχειριστεί';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Αφήστε όλους σε αυτήν την ομάδα να μιλήσουν στον $arg1.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Αφήστε το να λειτουργήσει\nενώ εσείς όχι.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Αφήστε το NeoAgent να κάνει κλικ, να πληκτρολογήσει και να μετακινηθεί στις εφαρμογές σας.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Αφήστε το NeoAgent να καταλάβει τι είναι ορατό στην οθόνη σας.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Αφήστε κάποιον με τον οποίο συνεργάζεστε να αποφασίσει ποια εργαλεία μπορεί ο αντιπρόσωπός σας ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Αφήστε αυτό το άτομο να στείλει στον $arg1 ένα μήνυμα ένας προς έναν.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Αφήστε αυτό το άτομο να μιλήσει με τον $arg1 εδώ, αλλά όχι σε ιδιωτικές συνομιλίες ή άλλες ομάδες.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Αφήστε αυτό το άτομο να μιλήσει με τον $arg1 σε ιδιωτικές συνομιλίες και σε οποιαδήποτε ομάδα μοιράζεται.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Επίπεδο $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Σύνδεσμος $arg1';
  }

  @override
  String get linkCopied => 'Ο σύνδεσμος αντιγράφηκε';

  @override
  String get linkExpiresAfter => 'Ο σύνδεσμος λήγει μετά';

  @override
  String get linkLifetimeHours => 'Διάρκεια ζωής συνδέσμου (ώρες)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Η διάρκεια ζωής του συνδέσμου πρέπει να είναι από 1 έως 8760 ώρες.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Ο σύνδεσμος ισχύει μέχρι $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Συνδεδεμένοι πάροχοι σύνδεσης';

  @override
  String get linuxApp => 'Εφαρμογή Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Καταχωρήθηκε $arg1/';
  }

  @override
  String get listening => 'Ακούγοντας';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Ζωντανό ιστορικό εκτέλεσης, βήματα εργαλείου και απαντήσεις.';

  @override
  String get liveModel => 'Ζωντανό μοντέλο';

  @override
  String get liveModelProvider => 'Πάροχος ζωντανών μοντέλων';

  @override
  String get liveRun => 'Ζωντανό τρέξιμο';

  @override
  String get liveVoice => 'Ζωντανή φωνή';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Η ζωντανή φωνητική σύνδεση δεν είναι διαθέσιμη.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Η ζωντανή φωνητική σύνδεση έκλεισε.';

  @override
  String get liveVoiceDefaults => 'Προεπιλογές ζωντανής φωνής';

  @override
  String get liveVoiceFailed => 'Η ζωντανή φωνή απέτυχε.';

  @override
  String get llmMemoryExportResponse => 'Απόκριση εξαγωγής μνήμης LLM';

  @override
  String get loadFailed => 'το φορτίο απέτυχε';

  @override
  String get loadingExecutionDetails => 'Φόρτωση λεπτομερειών εκτέλεσης...';

  @override
  String get loadingNeoagent => 'Φόρτωση NeoAgent';

  @override
  String get loadingRunFlow => 'Φόρτωση ροής εκτέλεσης…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Οι διευθύνσεις URL τοπικού και ιδιωτικού δικτύου υποστηρίζονται όταν ο διακομιστής NeoAgent μπορεί να τις προσεγγίσει. Ο ήχος δεν εκτίθεται ποτέ στο NeoAgent.';

  @override
  String get localApp => 'τοπική εφαρμογή';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Η τοπική εγκατάσταση υποστήριξης δεν είναι διαθέσιμη σε αυτήν την πλατφόρμα.';

  @override
  String get localBaseImagePath => 'Τοπική διαδρομή εικόνας βάσης';

  @override
  String get localComputerControlIsAvailableIn =>
      'Ο τοπικός έλεγχος υπολογιστή είναι διαθέσιμος στην εφαρμογή NeoAgent για υπολογιστές σε macOS, Windows και Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Ο τοπικός έλεγχος υπολογιστή δεν είναι διαθέσιμος εδώ.';

  @override
  String get localModelsUrl => 'URL τοπικών μοντέλων';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Η τοπική ανακάλυψη NeoAgent δεν είναι προσωρινά διαθέσιμη.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Τοπικές προτιμήσεις για την εφαρμογή NeoAgent. Ο έλεγχος υπολογιστή εκτελείται πάντα μέσω του ενοποιημένου υπολογιστή cloud.';

  @override
  String get localSetup => 'ΤΟΠΙΚΗ ΡΥΘΜΙΣΗ';

  @override
  String get locationCityOrPlace => 'Τοποθεσία (πόλη ή μέρος)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Η τοποθεσία απαιτείται για ενεργοποιήσεις καιρικών γεγονότων';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Η προετοιμασία LocationService απέτυχε: $arg1';
  }

  @override
  String get logCopied => 'Το αρχείο καταγραφής αντιγράφηκε';

  @override
  String get loginPassword => 'Κωδικός πρόσβασης σύνδεσης';

  @override
  String get logout => 'Αποσύνδεση';

  @override
  String get logs => 'κούτσουρα';

  @override
  String get logsCopied => 'Τα αρχεία καταγραφής αντιγράφηκαν.';

  @override
  String get logsOnThisComputer => 'Αρχεία καταγραφής σε αυτόν τον υπολογιστή';

  @override
  String get longLivedAccessToken => 'Διακριτικό πρόσβασης μακράς διαρκείας';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Μακροπρόθεσμη ανάκληση, δομημένα γεγονότα και γράφημα γνώσης.';

  @override
  String get lookedAtTheScreen => 'Κοίταξε την οθόνη';

  @override
  String get lookingOnThisComputerAndYour =>
      'Ψάχνετε σε αυτόν τον υπολογιστή και το τοπικό σας δίκτυο…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Κοιτάζει μπροστά στις αυριανές συναντήσεις, οπότε τίποτα δεν σας εκπλήσσει.';

  @override
  String get loopExecution => 'Εκτέλεση βρόχου';

  @override
  String get loopPaused => 'Ο βρόχος σταμάτησε';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Η προσβασιμότητα macOS δεν παραχωρείται στο NeoAgent. Επιτρέψτε το στις Ρυθμίσεις συστήματος › Απόρρητο και ασφάλεια › Προσβασιμότητα.';

  @override
  String get macosApp => 'εφαρμογή macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Η εγγραφή οθόνης macOS δεν εκχωρείται στο NeoAgent. Επιτρέψτε το στις Ρυθμίσεις συστήματος › Απόρρητο και ασφάλεια › Εγγραφή οθόνης και, στη συνέχεια, ανοίξτε ξανά το NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Οι διακομιστές αλληλογραφίας που χρειάζονται κωδικό πρόσβασης θα αρνηθούν να στείλουν μέχρι να γίνει νέος ';

  @override
  String get main => 'Κύρια';

  @override
  String get makeDefault => 'Ορίστε την προεπιλογή';

  @override
  String get manage => 'Διαχείριση';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Διαχειριστείτε το email του λογαριασμού σας, τον έλεγχο ταυτότητας δύο παραγόντων και τις ενεργές περιόδους σύνδεσης.';

  @override
  String get managedBy => 'Διαχειρίζεται από';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Οι διευθυντές μπορούν να έχουν δικούς τους διευθυντές (έως τέσσερα επίπεδα). Α ';

  @override
  String get managing => 'Διαχείριση';

  @override
  String get manualDestination => 'Χειροκίνητος προορισμός';

  @override
  String get manualTrigger => 'Χειροκίνητη σκανδάλη';

  @override
  String get masterPassword => 'Κύριος κωδικός πρόσβασης';

  @override
  String get matchThisDevice => 'Ταιριάξτε αυτήν τη συσκευή';

  @override
  String get matchedAgainstTitleAndBody => 'Ταίριαξε με τίτλο και σώμα';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Ταιριάζει με την παλιά ροή NeoAgent MCP: URL συν τη μέθοδο εξουσιοδότησης.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'Διακομιστής MCP';

  @override
  String get mcpServer2 => 'Διακομιστής MCP';

  @override
  String get mcpServerUrl => 'Διεύθυνση URL διακομιστή MCP';

  @override
  String get mcpServers => 'Διακομιστές MCP';

  @override
  String get meantForSomeoneElse => 'Προορίζεται για κάποιον άλλον';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Μετρημένο κόστος μοντέλου: $arg1';
  }

  @override
  String get memories => 'Αναμνήσεις';

  @override
  String get memory => 'Μνήμη';

  @override
  String memoryArg1(Object? arg1) {
    return 'Μνήμη: $arg1';
  }

  @override
  String get memoryInjected => 'Έγινε ένεση μνήμης';

  @override
  String get mentionOrReplyOnly => 'Μόνο αναφορά ή απάντηση';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Συγχωνευμένα αρχεία καταγραφής χρόνου εκτέλεσης διακομιστή και Flutter για αυτήν την περίοδο λειτουργίας εφαρμογής.';

  @override
  String get messageBodyTemplateJson => 'Πρότυπο σώματος μηνύματος (JSON)';

  @override
  String get messageNeedsAccess => 'Το μήνυμα χρειάζεται πρόσβαση';

  @override
  String get messageTextField => 'Πεδίο κειμένου μηνύματος';

  @override
  String get messaging => 'Μηνύματα';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Συμβάντα push και webhook API μηνυμάτων';

  @override
  String get messagingConnectionNeedsAttention =>
      'Η σύνδεση μηνυμάτων χρειάζεται προσοχή';

  @override
  String get messagingConnections => 'Συνδέσεις μηνυμάτων';

  @override
  String get messagingDelivery => 'Παράδοση μηνυμάτων';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Σφάλμα μηνυμάτων. Δοκιμάστε ξανά.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Η λήψη μικροφώνου σταμάτησε απροσδόκητα. Προσπαθήστε ξανά.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Σφάλμα μικροφώνου: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Σίγαση του μικροφώνου. Πατήστε για κατάργηση σίγασης.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Απαιτείται άδεια μικροφώνου για ζωντανή φωνή.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Ομάδες της Microsoft';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Ελάχιστη αξία συνεισφοράς: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Η ρύθμιση του κινητού απέτυχε.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Η ρύθμιση του κινητού απέτυχε επειδή η Java δεν είναι διαθέσιμη στο μηχάνημα που εκτελεί το NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Η ρύθμιση του κινητού απέτυχε επειδή η Java δεν είναι διαθέσιμη στο μηχάνημα που εκτελεί το NeoAgent. Εγκαταστήστε ένα JDK και δοκιμάστε ξανά.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Η ρύθμιση του κινητού απέτυχε. Ελέγξτε ότι το Android tooling έχει εγκατασταθεί σωστά και δοκιμάστε ξανά.';

  @override
  String modeArg1(Object? arg1) {
    return 'λειτουργία: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Η λειτουργία κλειδώνει ενώ μια εκτέλεση είναι ενεργή.';

  @override
  String get model => 'Μοντέλο';

  @override
  String modelArg1(Object? arg1) {
    return 'Μοντέλο: $arg1';
  }

  @override
  String get modelAvailability => 'Διαθεσιμότητα μοντέλου';

  @override
  String get modelAvailabilitySaved =>
      'Η διαθεσιμότητα του μοντέλου αποθηκεύτηκε.';

  @override
  String get modelForThisSession => 'Μοντέλο για αυτήν τη συνεδρία';

  @override
  String get modelOverride => 'Παράκαμψη μοντέλου';

  @override
  String get modelPending => 'Μοντέλο σε εκκρεμότητα';

  @override
  String get modelTurn => 'Στροφή μοντέλου';

  @override
  String get modelTurnCompleted => 'Η σειρά του μοντέλου ολοκληρώθηκε';

  @override
  String get modelTurnStarted => 'Ξεκίνησε η στροφή του μοντέλου';

  @override
  String get modelVisibilityHideShowList =>
      'ορατότητα μοντέλου απόκρυψη λίστας εμφάνισης';

  @override
  String get models => 'Μοντέλα';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Μοντέλα, συμπεριφορά, φωνή και χώρος εργασίας';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Μοντέλα, πρόγραμμα περιήγησης, φωνή, διαγνωστικά...';

  @override
  String get modelsRouting => 'Μοντέλα και δρομολόγηση';

  @override
  String get monthly => 'Μηνιαία';

  @override
  String get moreActions => 'Περισσότερες ενέργειες';

  @override
  String get morningBriefing => 'Πρωινή ενημέρωση';

  @override
  String get mostUsedAgents => 'Οι πιο χρησιμοποιημένοι παράγοντες';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Τα πιο χρησιμοποιημένα μοντέλα στο τελευταίο $arg1.';
  }

  @override
  String get mouseKeyboard => 'Ποντίκι & πληκτρολόγιο';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'Το mouseMove δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get mustBeReachableOnThePublic =>
      'Πρέπει να είναι προσβάσιμο στο δημόσιο διαδίκτυο -- τοπικό και ';

  @override
  String get n24Hours => '24 ώρες';

  @override
  String get n2faOrRecoveryCode => '2FA ή κωδικός ανάκτησης';

  @override
  String get n2faRequiresSessionSecretToBe =>
      'Το 2FA απαιτεί τη διαμόρφωση του SESSION_SECRET σε αυτήν την ανάπτυξη του NeoAgent.';

  @override
  String get n30Days => '30 ημέρες';

  @override
  String get n365Days => '365 ημέρες';

  @override
  String get n4HourLimitTokens => 'Όριο 4 ωρών (κουπόνια)';

  @override
  String get n4HourUsage => '4ωρη χρήση';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Όριο 4 ωρών $arg1';
  }

  @override
  String get n7DayUsage => '7ήμερη χρήση';

  @override
  String get n7Days => '7 ημέρες';

  @override
  String get n90Days => '90 ημέρες';

  @override
  String get name => 'Όνομα';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nόνομα: New Skill\nπεριγραφή: Περιγράψτε τι κάνει αυτή η δεξιότητα\n---\nΓράψτε τις οδηγίες για αυτήν την ικανότητα εδώ.\n';

  @override
  String get nameOfWhoeverMadeIt => 'το όνομα αυτού που το έφτιαξε.';

  @override
  String get nameOptional => 'Όνομα (προαιρετικό)';

  @override
  String get nativeAndWebhookChannels => 'Εγγενή και webhook κανάλια';

  @override
  String get naturalBubbles => 'Φυσικές φυσαλίδες';

  @override
  String get nearbyNeoagentServers => 'Κοντινοί διακομιστές NeoAgent';

  @override
  String get needANewAccountRegister => 'Χρειάζεστε νέο λογαριασμό; Εγγραφή';

  @override
  String get needAnIdea => 'Χρειάζεστε μια ιδέα;';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Πρέπει να απαντήσετε · $arg1% για να μιλήσετε';
  }

  @override
  String get needsAttention => 'Χρειάζεται προσοχή';

  @override
  String get needsInput => 'Χρειάζεται εισαγωγή';

  @override
  String get neoagentApp => 'Εφαρμογή NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Βοηθός NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'Το NeoAgent δεν μπόρεσε να ελέγξει τον διαθέσιμο χρόνο εκτέλεσης backend.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'Το NeoAgent δεν μπόρεσε να ολοκληρώσει την τοπική εγκατάσταση.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'Το NeoAgent δεν μπόρεσε να ολοκληρώσει την τοπική εγκατάσταση. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Πληροφορίες εντοπισμού σφαλμάτων NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'Το NeoAgent εγκαθιστά το πιο πρόσφατο $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'Το NeoAgent είναι εγκατεστημένο και εκτελείται.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'Το NeoAgent δεν είναι εγκατεστημένο σε αυτόν τον υπολογιστή.';

  @override
  String get neoagentIsReady => 'Το NeoAgent είναι έτοιμο';

  @override
  String get neoagentIsStillWorkingOnA =>
      'Το NeoAgent εξακολουθεί να εργάζεται σε μια εργασία. Τερματίστε την κλήση και λάβετε το αποτέλεσμα στη συνομιλία ή ακυρώστε επίσης την εργασία.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'Το NeoAgent μετατρέπει την επίδειξη σας σε μια προσαρμόσιμη ροή εργασίας.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'Το NeoAgent περιμένει ενώ χρησιμοποιείτε την επιφάνεια εργασίας.';

  @override
  String get neoagentIsWorking => 'Το NeoAgent λειτουργεί';

  @override
  String get neoagentLinuxComputer => 'Υπολογιστής NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'Το NEOAGENT ΧΡΕΙΑΖΕΤΑΙ ΑΠΟΦΑΣΗ';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Οι λήψεις χρόνου εκτέλεσης NeoAgent απαιτούν μια ασφαλή διεύθυνση.';

  @override
  String get neoagentServerAddress => 'Διεύθυνση διακομιστή NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'Το email υπηρεσίας NeoAgent δεν είναι έτοιμο. Ζητήστε από τον χειριστή του διακομιστή να ελέγξει τις ρυθμίσεις περιβάλλοντος ηλεκτρονικού ταχυδρομείου.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Δεν ήταν δυνατή η ολοκλήρωση της ρύθμισης του NeoAgent.';

  @override
  String get neoagentUser => 'Χρήστης NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'Το NeoAgent χρησιμοποιεί αυτόν τον υπολογιστή αυτόματα και ρωτά πριν χρησιμοποιήσει την οθόνη, το ποντίκι, το πληκτρολόγιο, τα αρχεία ή τη γραμμή εντολών.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'Το NeoAgent χρησιμοποιεί την κατά προσέγγιση τοποθεσία σας στο παρασκήνιο για να ενεργοποιήσει υπενθυμίσεις γεωγραφικής προστασίας (π.χ. \"Υπενθύμισέ μου να αγοράσω γάλα όταν περνάω από το σούπερ μάρκετ\").\n\n';

  @override
  String get neoagentWorkspace => 'Χώρος εργασίας NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][στοίβα] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'Διεύθυνση URL υποστήριξης NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Απαιτείται διεύθυνση URL υποστήριξης NeoRecall.';

  @override
  String get neorecallSetup => 'Ρύθμιση NeoRecall';

  @override
  String get networkRequestFailed => 'Το αίτημα δικτύου απέτυχε';

  @override
  String get networkWriteRequests => 'Αιτήματα εγγραφής δικτύου';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'δεν μετράει ποτέ στα κοινόχρηστα όρια χρήσης.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Οι νέοι λογαριασμοί επιβεβαιώνουν τη διεύθυνση ηλεκτρονικού ταχυδρομείου τους πριν από τη σύνδεση.';

  @override
  String get newAccountsPerDay => 'Νέοι λογαριασμοί ανά ημέρα';

  @override
  String get newChat => 'Νέα συνομιλία';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Οι νέες ομάδες παραμένουν αθόρυβες εκτός εάν κάποιος προσθέσει ετικέτα στο $arg1, μέχρι να τις ενεργοποιήσετε.';
  }

  @override
  String get newLink => 'Νέος σύνδεσμος';

  @override
  String get newPasswordsDoNotMatch =>
      'Οι νέοι κωδικοί πρόσβασης δεν ταιριάζουν.';

  @override
  String get newRecoveryCodes => 'Νέοι κωδικοί ανάκτησης';

  @override
  String get newSession => 'Νέα συνεδρία';

  @override
  String get newSessionN => 'Νέα περίοδος σύνδεσης (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Νέα συνεδρία με την ίδια ρύθμιση';

  @override
  String get newSkill => 'Νέα δεξιότητα';

  @override
  String get newSkill2 => 'Νέα Δεξιότητα';

  @override
  String get newThisWeek => 'Νέα αυτή την εβδομάδα';

  @override
  String get newsDigest => 'Ανασκόπηση ειδήσεων';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Επόμενη επανάληψη: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Ροή σύνδεσης Nextcloud';

  @override
  String get nextcloudSetup => 'Nextcloud Setup';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'URL Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'Απαιτείται η διεύθυνση URL Nextcloud.';

  @override
  String get nickname => 'Ψευδώνυμο';

  @override
  String get noAccountsConnectedYet =>
      'Δεν υπάρχουν ακόμα συνδεδεμένοι λογαριασμοί.';

  @override
  String get noAccountsFound => 'Δεν βρέθηκαν λογαριασμοί.';

  @override
  String get noActiveSessionsFound => 'Δεν βρέθηκαν ενεργές περίοδοι σύνδεσης.';

  @override
  String get noAgentsYet => 'Δεν υπάρχουν ακόμη πράκτορες';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Κανένας πάροχος τεχνητής νοημοσύνης δεν έχει ρυθμιστεί, επομένως συνομιλία και ανταλλαγή μηνυμάτων ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Δεν ζητείται έγκριση — ο πράκτορας εκτελείται χωρίς διακοπή.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Κανένα στοιχείο έκδοσης $arg1 δεν ταιριάζει με αυτήν την πλατφόρμα.';
  }

  @override
  String get noArguments => '(χωρίς επιχειρήματα)';

  @override
  String get noAuth => 'Όχι auth';

  @override
  String get noBindingsYet => 'Δεν υπάρχουν δεσμεύσεις ακόμα.';

  @override
  String get noChangesYet => 'Καμία αλλαγή ακόμα';

  @override
  String get noChannelsFound => 'Δεν βρέθηκαν κανάλια';

  @override
  String get noCloudComputerSlotIsFree =>
      'Καμία υποδοχή υπολογιστή cloud δεν είναι δωρεάν αυτή τη στιγμή. Δοκιμάστε ξανά σε λίγο.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Δεν υπάρχουν ακόμη καταχωρήσεις βασικής μνήμης.';

  @override
  String get noDescription => 'Καμία περιγραφή';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Δεν υπάρχουν διαθέσιμες οθόνες επιφάνειας εργασίας αυτήν τη στιγμή.';

  @override
  String get noDetailAvailable => 'Δεν υπάρχουν διαθέσιμες λεπτομέρειες';

  @override
  String get noDetailedSyncSummaryYet =>
      'Δεν υπάρχει ακόμη λεπτομερής σύνοψη συγχρονισμού.';

  @override
  String get noDetailsCaptured => 'Δεν καταγράφηκαν λεπτομέρειες.';

  @override
  String get noEmailLinked => 'Δεν υπάρχει συνδεδεμένο email';

  @override
  String get noExternalSignInProvidersLinked =>
      'Δεν έχουν συνδεθεί εξωτερικοί πάροχοι σύνδεσης.';

  @override
  String get noGroupMessagesYet => 'Δεν υπάρχουν ακόμη ομαδικά μηνύματα';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Δεν έχουν προστεθεί ακόμη άτομα ειδικά για την ομάδα.';

  @override
  String get noGroupsAddedYet => 'Δεν έχουν προστεθεί ακόμη ομάδες.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Δεν βρέθηκαν ακόμη ομάδες. Αφού το $arg1 δει ένα ομαδικό μήνυμα, χρησιμοποιήστε την Εύρεση πρόσφατων συνομιλιών και θα εμφανιστούν εδώ.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Δεν βρέθηκαν ακόμη ομάδες. Αφού το $arg1 δει ένα ομαδικό μήνυμα, χρησιμοποιήστε την Εύρεση πρόσφατων συνομιλιών.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Δεν επιστράφηκε ωφέλιμο φορτίο δεδομένων υγείας.';

  @override
  String get noHealthSamplesStoredYet =>
      'Δεν έχουν αποθηκευτεί ακόμη δείγματα υγείας.';

  @override
  String get noHttpClientImplementationForThis =>
      'Δεν υπάρχει εφαρμογή πελάτη HTTP για αυτήν την πλατφόρμα.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Δεν καταγράφηκε είσοδος ή έξοδος για αυτό το βήμα.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Δεν υπάρχουν ενσωματώσεις που να αντιστοιχούν σε αυτήν την αναζήτηση.';

  @override
  String get noLimit => 'Κανένα όριο';

  @override
  String get noLocalPasswordIsSetYet =>
      'Δεν έχει οριστεί ακόμη τοπικός κωδικός πρόσβασης. Δημιουργήστε ένα για να ενεργοποιήσετε τη σύνδεση με όνομα χρήστη/κωδικό πρόσβασης.';

  @override
  String get noLogEntries => 'Δεν υπάρχουν καταχωρήσεις ημερολογίου.';

  @override
  String get noMatchingSettings => 'Δεν υπάρχουν ρυθμίσεις που να ταιριάζουν';

  @override
  String get noMcpServersMatchThisSearch =>
      'Κανένας διακομιστής MCP δεν αντιστοιχεί σε αυτήν την αναζήτηση.';

  @override
  String get noMemoryEntriesFound => 'Δεν βρέθηκαν καταχωρήσεις μνήμης.';

  @override
  String get noMemorySync => 'Δεν υπάρχει συγχρονισμός μνήμης';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Διαβάζει μία φορά τα σημαντικά και τα απεσταλμένα email των τελευταίων 12 μηνών, ώστε ο πράκτορας να γνωρίζει τις επαφές και τα έργα σας.';

  @override
  String get emailMemory => 'Μνήμη email';

  @override
  String get importNow => 'Εισαγωγή τώρα';

  @override
  String get importOnConnect =>
      'Εισαγωγή παλαιότερων μηνυμάτων κατά τη σύνδεση λογαριασμού';

  @override
  String get sweepStarting => 'Προετοιμασία…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Ανάγνωση email · $done από $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Ανάγνωση email · βρέθηκαν $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Μάθηση από τα email · $done από $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Τελευταία εισαγωγή: $emails email · $memories νέες αναμνήσεις';
  }

  @override
  String get sweepNothingNew => 'Δεν υπάρχουν νέα email για εισαγωγή';

  @override
  String sweepFailed(String error) {
    return 'Η εισαγωγή απέτυχε: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Κανένα μοντέλο δεν ταιριάζει με το \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Δεν καταγράφηκε αίτημα μοντέλου για αυτήν την εκτέλεση.';

  @override
  String get noModelsDiscoveredYet => 'Δεν έχουν ανακαλυφθεί ακόμη μοντέλα';

  @override
  String get noModelsSelected => 'Δεν επιλέχθηκαν μοντέλα';

  @override
  String get noModelsYet => 'Δεν υπάρχουν ακόμη μοντέλα';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'κανένας λογαριασμός neoagent δεν είναι συνδεδεμένος με αυτόν τον πάροχο';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Δεν υπάρχει διαθέσιμος χρόνος εκτέλεσης υποστήριξης NeoAgent για αυτόν τον υπολογιστή.';

  @override
  String get noNetworkConnection => 'Δεν υπάρχει σύνδεση δικτύου';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Δεν υπάρχει σύνδεση δικτύου. Συνδεθείτε για να συνεχίσετε να χρησιμοποιείτε το NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Δεν υπάρχει σύνδεση δικτύου. Επανασυνδεθείτε για να ελέγξετε για ενημερώσεις.';

  @override
  String get noOne => 'Κανένας';

  @override
  String get noOneAddedYet => 'Δεν έχει προστεθεί κανείς ακόμα.';

  @override
  String get noOneCanMessage => 'Κανείς δεν μπορεί να στείλει μήνυμα';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Δεν βρέθηκε άλλος διακομιστής NeoAgent. Μπορείτε να αναζητήσετε ξανά ή να εισαγάγετε μια διεύθυνση με μη αυτόματο τρόπο.';

  @override
  String get noPeopleAddedYet => 'Δεν έχουν προστεθεί ακόμη άτομα.';

  @override
  String get noPlatformsMatch => 'Δεν ταιριάζουν πλατφόρμες';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Δεν υπάρχουν ακόμη διαθέσιμοι πάροχοι για διαμόρφωση.';

  @override
  String get noRecentChannelActivity =>
      'Δεν υπάρχει πρόσφατη δραστηριότητα καναλιού';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Δεν υπάρχουν αποτελέσματα για \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Δεν υπάρχουν τρεξίματα σε αυτό το εύρος.';

  @override
  String get noRunsMatchTheseFilters =>
      'Καμία εκτέλεση δεν αντιστοιχεί σε αυτά τα φίλτρα';

  @override
  String get noRunsYet => 'Δεν υπάρχουν ακόμα τρεξίματα';

  @override
  String get noRunsYet2 => 'Δεν υπάρχουν ακόμα τρεξίματα.';

  @override
  String get noSecurityKeyWasProvided => 'Δεν δόθηκε κλειδί ασφαλείας.';

  @override
  String get noServerUrlSet => 'Δεν έχει οριστεί διεύθυνση URL διακομιστή';

  @override
  String get noSessionMatchesThatSearch =>
      'Καμία περίοδος σύνδεσης δεν αντιστοιχεί σε αυτήν την αναζήτηση.';

  @override
  String get noSessionsYet => 'Δεν υπάρχουν ακόμη συνεδρίες';

  @override
  String get noSkillsMatchTheseFilters =>
      'Δεν υπάρχουν δεξιότητες που να ταιριάζουν με αυτά τα φίλτρα.';

  @override
  String get noStepsWereRecordedForThis =>
      'Δεν καταγράφηκαν βήματα για αυτήν την εκτέλεση.';

  @override
  String get noSummaryAvailable => 'Δεν υπάρχει διαθέσιμη περίληψη.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Δεν υπάρχουν εργασίες για το $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Κανένα εργαλείο δεν ταιριάζει με το \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Δεν εκτελείται ενημέρωση';

  @override
  String get noUsageYet => 'Καμία χρήση ακόμα.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Δεν υπάρχει ακόμη διαθέσιμος επαληθευμένος χρόνος εκτέλεσης του NeoAgent.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Κανείς δεν μπορεί πλέον να το χρησιμοποιήσει. Άτομα που έχουν ήδη εγγραφεί ';

  @override
  String get none => 'Κανένα';

  @override
  String get notApprovedYet => 'δεν έχει εγκριθεί ακόμη';

  @override
  String get notAuthenticated => 'δεν έχει επικυρωθεί';

  @override
  String get notCheckedYet => 'Δεν έχει ελεγχθεί ακόμα';

  @override
  String get notConfigured => 'Δεν έχει ρυθμιστεί';

  @override
  String get notConnected => 'Δεν είναι συνδεδεμένο';

  @override
  String get notConnected2 => 'Δεν έχει συνδεθεί';

  @override
  String get notInstalled => 'Δεν έχει εγκατασταθεί';

  @override
  String get notNeeded => 'Δεν χρειάζεται';

  @override
  String get notNeededEnough => 'Δεν χρειάζεται αρκετά';

  @override
  String get notNow => 'Όχι τώρα';

  @override
  String get notNow2 => 'Όχι τώρα';

  @override
  String get notSet => 'Δεν έχει οριστεί';

  @override
  String get notSetUp => 'Δεν έχει ρυθμιστεί';

  @override
  String get notTheSameAsAdmin => 'Δεν είναι το ίδιο με τον διαχειριστή';

  @override
  String get nothingFound => 'Δεν βρέθηκε τίποτα';

  @override
  String get nothingHereYet => 'Τίποτα εδώ ακόμα.';

  @override
  String get nothingHereYet2 => 'Τίποτα εδώ ακόμα';

  @override
  String get nothingMatches => 'Τίποτα δεν ταιριάζει';

  @override
  String get nothingStoredYet => 'Δεν έχει αποθηκευτεί τίποτα ακόμα.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'Αναγνωριστικό πελάτη OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth κλειδί api μυστικής ανακατεύθυνσης αναγνωριστικού πελάτη';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth αναγνωριστικό πελάτη μυστική ανακατεύθυνση μονάδας ημερολογίου gmail';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Η εκκίνηση του OAuth δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook ενοικιαστής πελάτη μυστικό id';

  @override
  String get oauthToken => 'Token OAuth';

  @override
  String get oauthWithPkce => 'OAuth με PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'του $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'δικό της. Δεν εμφανίζεται ποτέ ξανά μετά την αποθήκευση.';

  @override
  String get off => 'Ανενεργό';

  @override
  String get officialIntegration => 'Επίσημη ένταξη';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Η επίσημη ενσωμάτωση δεν επέστρεψε διεύθυνση URL σύνδεσης.';

  @override
  String get on => 'Ενεργό';

  @override
  String get onASignedInAndroidDevice =>
      'Σε μια συνδεδεμένη συσκευή Android, ανοίξτε τις Ρυθμίσεις › Είσοδος και ασφάλεια, σαρώστε αυτόν τον κωδικό και εγκρίνετε τη σύνδεση.';

  @override
  String get onByDefaultForNewGroups => 'Ενεργό από προεπιλογή για νέες ομάδες';

  @override
  String get onDemand => 'Κατ\' απαίτηση';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Ενεργό για $arg1 των ομάδων $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'επάνω. Μπορούν να εγγραφούν ξανά μόνο με έναν νέο σύνδεσμο πρόσκλησης.';

  @override
  String get onYourOwnTheDefault => 'Μόνοι σας (η προεπιλογή)';

  @override
  String get once => 'Μια φορά';

  @override
  String get oneIsSavedOtherChangesIn =>
      'ένας σώζεται. Άλλες αλλαγές σε αυτήν τη φόρμα αποθηκεύονται επίσης.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Ένας ή περισσότεροι λογαριασμοί έληξαν. Επανασυνδέστε τον επηρεαζόμενο λογαριασμό για να επαναφέρετε την πρόσβαση στο εργαλείο.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Ένας χρόνος εκτέλεσης ελέγχει την προσωπικότητα, την ομαδική στροφή, τη μνήμη δωματίου, τους κανόνες, τη Θεωρία του Νου και την παράδοση.';

  @override
  String get oneTimeRun => 'Ένα τρέξιμο';

  @override
  String get onlyApkOrApksFilesCan =>
      'Μπορούν να εγκατασταθούν μόνο αρχεία .apk ή .apks.';

  @override
  String get onlyInThisGroup => 'Μόνο σε αυτή την ομάδα';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Χρειάζεται μόνο εάν η υπηρεσία ζητά επιπλέον κεφαλίδες HTTP.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Χρειάζεται μόνο εάν θέλετε να αναδιαμορφώσετε το εξερχόμενο ωφέλιμο φορτίο.';

  @override
  String get onlyTheyCanChangeIt => 'Μόνο αυτοί μπορούν να το αλλάξουν.';

  @override
  String get open => 'Ανοίξτε';

  @override
  String get openAccountSettingsOnASigned =>
      'Ανοίξτε τις Ρυθμίσεις › Είσοδος και ασφάλεια σε μια συνδεδεμένη συσκευή Android, σαρώστε αυτόν τον κωδικό και εγκρίνετε τη σύνδεση.';

  @override
  String get openComputer => 'Ανοίξτε τον υπολογιστή';

  @override
  String get openDashboard => 'Ανοίξτε τον πίνακα ελέγχου';

  @override
  String get openFolder => 'Άνοιγμα φακέλου…';

  @override
  String get openInWorkbench => 'Ανοίξτε στον πάγκο εργασίας';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Ανοίξτε το NeoAgent και επανασυνδέστε το $arg1 για να επαναφέρετε τα μηνύματα.';
  }

  @override
  String get openTimeSettings => 'Ανοίξτε τις ρυθμίσεις ώρας';

  @override
  String get openToAnyone => 'Ανοιχτό σε οποιονδήποτε';

  @override
  String get openTrello => 'Ανοίξτε το Trello';

  @override
  String get openVoiceAssistant => 'Ανοίξτε τον φωνητικό βοηθό';

  @override
  String get openWiFiSettings => 'Ανοίξτε τις ρυθμίσεις Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Ανοίξτε με την προεπιλεγμένη εφαρμογή';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'συμβατό με openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Συμβατό με OpenAI τελικό σημείο (ο δικός σας διακομιστής ή άλλος ';

  @override
  String openedArg1(Object? arg1) {
    return 'Άνοιξε το $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Το άνοιγμα διευθύνσεων URL επιφάνειας εργασίας δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get openingYourSavedDesktop =>
      'Άνοιγμα της αποθηκευμένης επιφάνειας εργασίας σας.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Άνοιγμα της αποθηκευμένης επιφάνειας εργασίας σας. Οι κανονικές εκκινήσεις διαρκούν λιγότερο από 10 δευτερόλεπτα.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Προαιρετικό επιπλέον μυστικό εάν προστατεύετε το εισερχόμενο webhook.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Προαιρετική παράκαμψη εάν η διεύθυνση URL του webhook δεν είναι αρκετή.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Προαιρετικό μυστικό για την επαλήθευση εισερχόμενων συμβάντων συνομιλίας.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Προαιρετικό μυστικό για την επαλήθευση εισερχόμενων συμβάντων.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Προαιρετικό μυστικό για την επαλήθευση εισερχόμενων συμβάντων iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Προαιρετικό μυστικό για την επαλήθευση εισερχόμενων συμβάντων LINE.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Προαιρετικό μυστικό για την επαλήθευση εισερχόμενων συμβάντων Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Προαιρετικό μυστικό για την επαλήθευση εισερχόμενων συμβάντων Ομάδων.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Προαιρετικό. Ο πράκτορας έχει ήδη τη δική του προσωπικότητα. Οτιδήποτε προσθέτετε σχετικά με τον τόνο είναι τοποθετημένο πάνω του, επομένως δεν χρειάζεται ποτέ να ορίσετε ένα.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Προαιρετικό. Όταν οριστεί, χρησιμοποιείται αντί για τη διεύθυνση URL.';

  @override
  String get orAnswerInYourOwnWords => 'Ή απαντήστε με δικά σας λόγια';

  @override
  String get orBuildYourOwnTask => 'Ή φτιάξτε τη δική σας εργασία';

  @override
  String get orContinueWith => 'ή συνεχίστε με';

  @override
  String get orFiles => 'ή αρχεία.';

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
  String get originNotAllowed => 'δεν επιτρέπεται η προέλευση';

  @override
  String get outgoingMessage => 'Εξερχόμενο μήνυμα';

  @override
  String get outgoingWebhookUrl => 'Εξερχόμενη διεύθυνση URL webhook';

  @override
  String get outlookEmailReceived => 'Λήφθηκε το email του Outlook';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Αντικαταστήστε τις σημειώσεις συμπεριφοράς από την εισαγωγή.';

  @override
  String get ownModel => 'δικό του μοντέλο';

  @override
  String get packageName => 'Όνομα πακέτου';

  @override
  String get pairWithQrCode => 'Σύζευξη με κωδικό QR';

  @override
  String get password => 'Κωδικός πρόσβασης';

  @override
  String get password2faAndActiveSessions =>
      'Κωδικός πρόσβασης, 2FA και ενεργές συνεδρίες';

  @override
  String get passwordCreated => 'Δημιουργήθηκε κωδικός πρόσβασης.';

  @override
  String get passwordIsTooWeak => 'ο κωδικός πρόσβασης είναι πολύ αδύναμος';

  @override
  String get passwordMin8 => 'κωδικός min 8';

  @override
  String get passwordOrApiKey => 'Κωδικός πρόσβασης ή κλειδί API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Ισχύς κωδικού πρόσβασης: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Οι κωδικοί πρόσβασης δεν ταιριάζουν.';

  @override
  String get pasteAKey => 'Επικολλήστε ένα κλειδί.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Επικολλήστε ένα νέο κλειδί για να αντικαταστήσετε το $arg1';
  }

  @override
  String get pasteTheKey => 'Επικολλήστε το κλειδί';

  @override
  String get pasteYourAccountToken =>
      'Επικολλήστε το διακριτικό του λογαριασμού σας';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Επικολλήστε το κλειδί API $arg1 παρακάτω. Είναι ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Η διαδρομή πρέπει να παραμείνει εντός του χώρου εργασίας NeoAgent.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Η διαδρομή πρέπει να παραμείνει μέσα στο φάκελο του χώρου εργασίας.';

  @override
  String get pauseLiveUpdates => 'Παύση ζωντανών ενημερώσεων';

  @override
  String get pauseTaskLoop => 'Παύση βρόχου εργασιών';

  @override
  String get paused => 'Σε παύση';

  @override
  String peakArg1(Object? arg1) {
    return 'κορυφή $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Άτομα σε ιδιωτικές συνομιλίες';

  @override
  String get perAccountRateLimits => 'Όρια επιτοκίων ανά λογαριασμό';

  @override
  String get perCategoryPermissions => 'Δικαιώματα ανά κατηγορία';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Πολιτικές αδειών ανά εργαλείο, πύλες έγκρισης και απομόνωση διεργασιών για την εκτέλεση φλοιού.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Απαιτείται άδεια: $arg1';
  }

  @override
  String get permissionsNeeded => 'Απαιτούνται άδειες';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Άδειες. Κανείς άλλος δεν μπορεί να το αλλάξει αυτό.';

  @override
  String get personOrChat => 'Πρόσωπο ή συνομιλία';

  @override
  String get personaBehaviorNotes => 'Σημειώσεις συμπεριφοράς προσωπικού';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Προσωπικό διακριτικό πρόσβασης για το ρομπότ Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Προσωπικά κανάλια και επιφάνειες άμεσης στήριξης.';

  @override
  String get personalSelfChat => 'Προσωπική αυτοσυζήτηση';

  @override
  String get phoneNumber => 'Αριθμός τηλεφώνου';

  @override
  String get pickARunFromTheList =>
      'Επιλέξτε μια σειρά από τη λίστα για να δείτε τα βήματά της.';

  @override
  String get pickARunFromTheList2 =>
      'Επιλέξτε μια σειρά από τη λίστα στα αριστερά για να εξερευνήσετε τη ροή της.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Επιλέξτε από τις πρόσφατες συνομιλίες $arg1 ή προσθέστε μόνοι σας ένα άτομο ή μια ομάδα.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Επιλέξτε πώς το $arg1 χρησιμοποιεί αυτόν τον λογαριασμό.';
  }

  @override
  String get pickOneToFillInThe =>
      'Επιλέξτε ένα για να συμπληρώσετε την εργασία. Μπορείτε να τροποποιήσετε τα πάντα μετά.';

  @override
  String get picksUpWhereYouLeftOff => 'Συνεχίζει από εκεί που σταματήσατε';

  @override
  String get plan => 'Σχέδιο';

  @override
  String get planning => 'Προγραμματισμός';

  @override
  String get platform => 'Πλατφόρμα';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Πλατφόρμα $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Επιλέξτε ένα πρόγραμμα.';

  @override
  String get pleaseEnterAFilename => 'Εισαγάγετε ένα όνομα αρχείου.';

  @override
  String get pleaseEnterAKey => 'Εισαγάγετε ένα κλειδί.';

  @override
  String get pleaseEnterAPrompt => 'Εισαγάγετε μια προτροπή.';

  @override
  String get pleaseEnterATaskName => 'Εισαγάγετε ένα όνομα εργασίας.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Εισαγάγετε το περιεχόμενο της μνήμης.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Εισαγάγετε πότε πρέπει να εκτελεστεί η εργασία.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Επιλέξτε έναν λογαριασμό ή εισαγάγετε ένα έγκυρο αναγνωριστικό σύνδεσης.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Σημειώστε το NeoAgent σε οποιεσδήποτε Ολοκληρώσεις συνομιλίας συμβατές με OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Στρέψτε την κάμερα στον κωδικό που εμφανίζεται στην αποσυνδεδεμένη συσκευή. Η έγκριση παραμένει σε αυτό το τηλέφωνο.';

  @override
  String get port => 'Λιμάνι';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env δημόσια url αξιόπιστη ανάπτυξη cookie μεσολάβησης';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Αυτοματισμός Premium με χρονοδιαγράμματα και ενσωμάτωση.';

  @override
  String get prepareQrCode => 'Προετοιμάστε τον κωδικό QR';

  @override
  String get preparingNeoagent => 'Προετοιμασία NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Προετοιμασία NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Πατήστε παρατεταμένα για γρήγορη λήψη';

  @override
  String get pressKeysIsNotSupportedOn =>
      'το πάτημα πλήκτρων δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Πατημένο $arg1';
  }

  @override
  String get priceUnknown => 'Τιμή άγνωστη';

  @override
  String get primaryDisplay => 'Κύρια οθόνη';

  @override
  String get privateChat => 'Ιδιωτική συνομιλία';

  @override
  String get privateChats => 'Ιδιωτικές συνομιλίες';

  @override
  String get privateChats2 => 'ιδιωτικές συνομιλίες';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Ιδιωτικές συνομιλίες: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Ιδιωτικές συνομιλίες $arg1 · ομάδες $arg2';
  }

  @override
  String get privateChatsOnly => 'Μόνο ιδιωτικές συνομιλίες';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'Δεν επιτρέπονται οι ιδιωτικές διευθύνσεις δικτύου.';

  @override
  String get profileEmailAndPersonalData =>
      'Προφίλ, email και προσωπικά δεδομένα';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Ερώτηση προτού το NeoAgent παραμείνει στο δίσκο συστήματος.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Προσωρινή προσωρινή μνήμη: $arg1 αποθηκευμένα διακριτικά ';
  }

  @override
  String get promptCopied => 'Το μήνυμα αντιγράφηκε.';

  @override
  String get promptOrSchedule => 'προτροπή ή χρονοδιάγραμμα.';

  @override
  String get promptToPasteIntoAnotherAi => 'Προτροπή για επικόλληση σε άλλο AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Δεν ήταν δυνατή η έναρξη της σύνδεσης παρόχου.';

  @override
  String get providerSignInCouldNotBe =>
      'Δεν ήταν δυνατή η έναρξη της σύνδεσης παρόχου.';

  @override
  String get providers => 'Παρόχους';

  @override
  String get providersEachAccountCanStillPick =>
      'Πάροχοι? κάθε λογαριασμός μπορεί ακόμα να επιλέξει το δικό του μοντέλο στις Ρυθμίσεις. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Οι πάροχοι, οι ενσωματώσεις, η φωνή και οι προαιρετικές δυνατότητες μπορούν να ολοκληρωθούν από τις Ρυθμίσεις ανά πάσα στιγμή.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Δημόσια ζητήματα και νήματα αιτημάτων έλξης, απαντώνται μόνο για εγκεκριμένα άτομα.';

  @override
  String get publicUrl => 'Δημόσια διεύθυνση URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Δημόσιο URL και επιτρεπόμενες προελεύσεις';

  @override
  String get publicUrlOverride => 'Παράκαμψη δημόσιας διεύθυνσης URL';

  @override
  String get pullsTogetherTheDayAhead => 'Μαζεύει την επόμενη μέρα';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Σύνδεση τηλεφώνου που βασίζεται σε QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Η σύνδεση QR ολοκληρώθηκε, αλλά το NeoAgent δεν μπόρεσε να διατηρήσει τη συνεδρία. Δοκιμάστε ξανά.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'Δεν ήταν δυνατή η έναρξη της σύνδεσης QR.';

  @override
  String get qrLoginRequestHasExpired => 'Το αίτημα σύνδεσης qr έχει λήξει';

  @override
  String get qrLoginRequestWasNotFound => 'Το αίτημα σύνδεσης qr δεν βρέθηκε';

  @override
  String get qrPairing => 'Σύζευξη QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'εκτελούνται ερωτήματα. οτιδήποτε γράφει απορρίπτεται.';

  @override
  String get queryFilter => 'Ερώτημα / Φίλτρο';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Σε ουρά ως σύστημα διεύθυνσης για την τρέχουσα διαδρομή: $arg1';
  }

  @override
  String get quickstart => 'Γρήγορη εκκίνηση';

  @override
  String get quit => 'Κλείσε';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Έτρεξε ένα σενάριο στη σελίδα';

  @override
  String ranArg1(Object? arg1) {
    return 'Έτρεξε το $arg1';
  }

  @override
  String get rateLimits => 'Όρια ποσοστών';

  @override
  String get readAnArtifact => 'Διαβάστε ένα τεχνούργημα';

  @override
  String get readAndEditFilesInsideYour =>
      'Διαβάστε και επεξεργαστείτε αρχεία μέσα στο φάκελο NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Διαβάστε το $arg1';
  }

  @override
  String get readError => 'Σφάλμα ανάγνωσης';

  @override
  String get readFiles => 'Διαβάστε αρχεία';

  @override
  String get readOnly => 'Μόνο για ανάγνωση';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Διαβάστε το φάκελο και συνοψίστε τη στοίβα, τα σημεία εισόδου και τον τρόπο εκτέλεσης του.';

  @override
  String get readThePage => 'Διαβάστε τη σελίδα';

  @override
  String get readTheUiTree => 'Διαβάστε το δέντρο διεπαφής χρήστη';

  @override
  String get readWrite => 'Διαβάστε / Γράψτε';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Διαβάζει βήματα, καρδιακούς παλμούς, ύπνο, άσκηση και βάρος.';

  @override
  String get ready => 'Έτοιμοι';

  @override
  String get readyForFirstTimeSetup => 'Έτοιμο για εγκατάσταση για πρώτη φορά';

  @override
  String get readyToConnect => 'Έτοιμοι για σύνδεση';

  @override
  String get recentChannelActivity => 'Πρόσφατη δραστηριότητα καναλιού';

  @override
  String get recentChats => 'Πρόσφατες συνομιλίες';

  @override
  String get recentDecisions => 'Πρόσφατες αποφάσεις';

  @override
  String get recentFailedRuns => 'Πρόσφατες αποτυχημένες εκτελέσεις';

  @override
  String get recentGroupDecisions => 'Πρόσφατες ομαδικές αποφάσεις';

  @override
  String get recentRuns => 'Πρόσφατες διαδρομές';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Οι πρόσφατες εκτελέσεις διαρκούν περίπου το $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Πρόσφατη έξοδος διακομιστή, πρώτα το νεότερο.';

  @override
  String get recentUsage4Hours => 'Πρόσφατη χρήση (4 ώρες)';

  @override
  String get recents => 'Πρόσφατα';

  @override
  String get recipientField => 'Πεδίο παραλήπτη';

  @override
  String get reconnectOrFinishSetup => 'Επανασυνδέστε ή ολοκληρώστε τη ρύθμιση';

  @override
  String get reconnectingThisDevice => 'Επανασύνδεση αυτής της συσκευής…';

  @override
  String get recurring => 'Επαναλαμβανόμενο';

  @override
  String get redirectUri => 'Ανακατεύθυνση URI';

  @override
  String get redoOnboarding => 'Επανάληψη της ενσωμάτωσης';

  @override
  String get refresh => 'Ανανέωση';

  @override
  String get refreshCode => 'Ανανέωση κωδικού';

  @override
  String get refreshNow => 'Ανανέωση τώρα';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Ανανεώστε την οθόνη Android για να προσπαθήσετε ξανά.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Αρνηθείτε την αποστολή εκτός εάν η σύνδεση αναβαθμιστεί σε TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'ανεξάρτητα από τις παρακάτω ρυθμίσεις ανά κατηγορία.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Καταχωρίστε το $arg1 για τη ροή κλήσης βοηθού.';
  }

  @override
  String get registrationIsClosed => 'η εγγραφή έχει κλείσει';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'εγγραφή εγγραφή νέου λογαριασμούς επιτρέπουν την εγγραφή';

  @override
  String get rejectInvalidTlsCertificates =>
      'Απόρριψη μη έγκυρων πιστοποιητικών TLS';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'απελευθέρωση και επανεκκίνηση. Οι συνδεδεμένες εφαρμογές επανασυνδέονται μόλις επιστρέψει.';

  @override
  String get releaseChannel => 'Έκδοση καναλιού';

  @override
  String get releaseCommitBranchNode =>
      'κόμβος διακλάδωσης δέσμευσης απελευθέρωσης';

  @override
  String get releaseWhenYouAreDone => 'Αφήστε όταν τελειώσετε.';

  @override
  String get reloadNow => 'Επαναφόρτωση τώρα';

  @override
  String get rememberThisChoice => 'Θυμηθείτε αυτή την επιλογή';

  @override
  String get remove => 'Αφαίρεση';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Κατάργηση του \"$arg1\" και των καταγεγραμμένων βημάτων του από το ιστορικό εκτέλεσης;';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Αφαιρέστε το \"$arg1\" από τη μνήμη πυρήνα.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Κατάργηση του κλειδιού $arg1;';
  }

  @override
  String get removeEraseGdprUser => 'κατάργηση διαγραφής χρήστη gdpr';

  @override
  String get removeSmtpPassword => 'Καταργήστε τον κωδικό πρόσβασης SMTP';

  @override
  String get removeTheSmtpPassword => 'Κατάργηση του κωδικού πρόσβασης SMTP;';

  @override
  String get rename => 'Μετονομασία';

  @override
  String get renameSecurityKey => 'Μετονομασία κλειδιού ασφαλείας';

  @override
  String get renameSession => 'Μετονομασία συνεδρίας';

  @override
  String get repairAndRetry => 'Επισκευάστε και δοκιμάστε ξανά';

  @override
  String get repairDesktop => 'Επισκευή επιφάνειας εργασίας';

  @override
  String get repeat => 'Επαναλάβετε';

  @override
  String get repliesWhenTagged => 'Απαντήσεις όταν έχουν επισημανθεί';

  @override
  String get replyToAddress => 'Απάντηση-Στη διεύθυνση';

  @override
  String replyToArg1(Object? arg1) {
    return 'Απάντηση στο $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Το αποθετήριο πρέπει να έχει τη μορφή κάτοχος/αποθήκη.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Αναπαράγετε το σφάλμα που περιγράφω, βρείτε τη βασική αιτία και διορθώστε το με μια δοκιμή παλινδρόμησης.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'το αίτημα απέτυχε με το http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Το αίτημα απέτυχε με το HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Ζητήστε άδειες';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Το αίτημα για το $arg1 απέτυχε πριν ανταποκριθεί το backend.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Ζητήθηκε $arg1';
  }

  @override
  String get requireStarttls => 'Απαιτείται STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Απαιτείται πίσω από HTTPS ή διακομιστή μεσολάβησης TLS. Ισχύει μετά από διακομιστή ';

  @override
  String get requiredExampleBerlinDe => 'Απαιτείται. Παράδειγμα: Βερολίνο, DE';

  @override
  String get requiredFormatOwnerRepo => 'Απαιτείται. Μορφή: ιδιοκτήτης/repo';

  @override
  String get reserveAssistantHotkey => 'Κρατήστε το πλήκτρο πρόσβασης βοηθού';

  @override
  String get reset => 'Επαναφορά';

  @override
  String get resetPassword => 'Επαναφορά κωδικού πρόσβασης';

  @override
  String get resetView => 'Επαναφορά προβολής';

  @override
  String get responsibilities => 'Ευθύνες';

  @override
  String get restart => 'Επανεκκίνηση';

  @override
  String get restartToFinishTheUpdate =>
      ' Κάντε επανεκκίνηση για να ολοκληρώσετε την ενημέρωση.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Επαναφορά του προηγούμενου χρόνου εκτέλεσης NeoAgent';

  @override
  String get restrictDelegationTargets => 'Περιορίστε τους στόχους ανάθεσης';

  @override
  String get result => 'Αποτέλεσμα';

  @override
  String get resultDelivery => 'Παράδοση αποτελεσμάτων';

  @override
  String get resultOneClickAddsOneYou =>
      'αποτέλεσμα. Ένα κλικ προσθέτει ένα? μπορείτε να το επεξεργαστείτε αργότερα.';

  @override
  String get results => 'Αποτελέσματα';

  @override
  String get retry => 'Επανάληψη';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Επαναχρησιμοποιήσιμο · μεταχειρισμένο $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Ελέγξτε τις μη δεσμευμένες αλλαγές';

  @override
  String get revoke => 'Ανάκληση';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Ανάκληση διαχειριστή με το \"neoagent admin revoke $arg1\" πρώτα';
  }

  @override
  String get revokeThisLink => 'Ανάκληση αυτού του συνδέσμου;';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Παράθυρο παρτίδας δωματίου: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Περιστρέψτε για να συνεχίσετε';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'σειρές. Προσθέστε ένα LIMIT ή μια στενότερη ρήτρα WHERE για να δείτε ';

  @override
  String get rule => 'Κανόνας';

  @override
  String get run => 'Εκτέλεση';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Εκτελέστε αυθαίρετες εντολές στο μηχάνημά σας ή στο VM.';

  @override
  String get runAt => 'Τρέξτε στο';

  @override
  String get runCompleted => 'Η εκτέλεση ολοκληρώθηκε';

  @override
  String get runFailed => 'Η εκτέλεση απέτυχε';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Εκτελέστε το git diff, ελέγξτε τις μη δεσμευμένες αλλαγές για σφάλματα και ζητήματα στυλ και συνοψίστε τι βρίσκετε.';

  @override
  String get runNotFound => 'Η εκτέλεση δεν βρέθηκε';

  @override
  String get runNow => 'Εκτέλεση τώρα';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Εκτελέστε τα εισερχόμενα προσωπικά μηνύματα WhatsApp.';

  @override
  String get runQuery => 'Εκτέλεση ερωτήματος';

  @override
  String get runShellCommandsOrInstallApps =>
      'Εκτελέστε εντολές φλοιού ή εγκαταστήστε εφαρμογές στη συσκευή σας Android.';

  @override
  String get runStarted => 'Το τρέξιμο ξεκίνησε';

  @override
  String get runStatus => 'Κατάσταση εκτέλεσης';

  @override
  String get runStopped => 'Το τρέξιμο σταμάτησε';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Εκτελέστε εντολές τερματικού και ανοίξτε εφαρμογές ή ιστοσελίδες.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Εκτελέστε αυτόν τον διακομιστή: λογαριασμοί, ενημερώσεις, πάροχοι, διαμόρφωση ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Εκτέλεση όταν φτάσει ένα αντίστοιχο μήνυμα στο Gmail.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Εκτελείται όταν φτάσει ένα αντίστοιχο μήνυμα ηλεκτρονικού ταχυδρομείου του Outlook.';

  @override
  String get runWhenANewIssueMatching =>
      'Εκτελείται όταν ανοίγει ένα νέο ζήτημα που ταιριάζει με τα φίλτρα σας σε ένα αποθετήριο.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Εκτελείται όταν δημιουργείται μια νέα μνήμη NeoRecall που ταιριάζει με τα φίλτρα σας.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Εκτελέστε όταν φτάσει μια ειδοποίηση στη συσκευή σας.';

  @override
  String get runWhenASlackMessageMatches =>
      'Εκτελείται όταν ένα μήνυμα Slack ταιριάζει με το επιλεγμένο εύρος.';

  @override
  String get runWhenATeamsChatMessage =>
      'Εκτελείται όταν ένα μήνυμα συνομιλίας Teams ταιριάζει με το επιλεγμένο εύρος.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Εκτέλεση όταν προβλέπονται διαμορφωμένα καιρικά συμβάντα για μια τοποθεσία.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'τρέξιμο. Ενώ οποιοδήποτε μοντέλο είναι απενεργοποιημένο, τα μοντέλα που προσθέτουν οι πάροχοι ';

  @override
  String get running => 'Σε εξέλιξη';

  @override
  String runningArg1(Object? arg1) {
    return 'Εκτέλεση $arg1';
  }

  @override
  String get runningTask => 'Εκτέλεση εργασίας';

  @override
  String get runningTool => 'Εργαλείο τρεξίματος';

  @override
  String get runs => 'Εκτελέσεις';

  @override
  String get runsEveryDayAtTheSelected =>
      'Τρέχει κάθε μέρα την επιλεγμένη ώρα.';

  @override
  String get runsFourTimesPerHour => 'Τρέχει τέσσερις φορές την ώρα.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— εκτελέσεις, μηνύματα, μνήμες, ενσωματώσεις, αρχεία και ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'εκτελέσεις, μηνύματα, μνήμες, ενσωματώσεις, αρχεία και συνεδρίες. ';

  @override
  String get runsMondayThroughFriday => 'Εκτελείται από Δευτέρα έως Παρασκευή.';

  @override
  String get runsOnSelectedWeekdays => 'Εκτελείται σε επιλεγμένες καθημερινές.';

  @override
  String get runsOncePerHour => 'Τρέχει μία φορά την ώρα.';

  @override
  String get runsOncePerMonthOnThe =>
      'Εκτελείται μία φορά το μήνα την επιλεγμένη ημέρα.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Εκτελείται μόνο όταν πατάτε Εκτέλεση τώρα.';

  @override
  String get runsPerDay => 'Τρεξίματα ανά ημέρα';

  @override
  String get runsPerDay30Days => 'Τρεξίματα ανά ημέρα (30 ημέρες)';

  @override
  String get runsThatCompleted => 'Τρεξίματα που ολοκληρώθηκαν';

  @override
  String get runsThisWeek => 'Τρέχει αυτή την εβδομάδα';

  @override
  String get runsToday => 'Τρέχει σήμερα';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Εκτελέσεις, εργαλεία, μνήμη, προγραμματισμός, δεξιότητες και MCP είναι όλα διαθέσιμα εδώ.';

  @override
  String get runsTwicePerHour => 'Τρέχει δύο φορές την ώρα.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Οι εκτελέσεις θα επιστρέψουν στο κοινόχρηστο κλειδί διακομιστή για το $arg1, εάν έχει ρυθμιστεί κάποιο. Αυτό δεν μπορεί να αναιρεθεί.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Χρόνος εκτέλεσης $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Χρόνος εκτέλεσης: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Ρυθμίσεις χρόνου εκτέλεσης με τις οποίες ξεκίνησε αυτός ο διακομιστής. Επεξεργαστείτε τα κάτω από ';

  @override
  String get runtimeSetupRequired => 'Απαιτείται ρύθμιση χρόνου εκτέλεσης';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Το δημόσιο κλειδί υπογραφής χρόνου εκτέλεσης πρέπει να είναι 32 byte.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Αποθήκευση';

  @override
  String get saveATrelloApiKeyFor =>
      'Αποθηκεύστε ένα κλειδί API Trello για αυτόν τον πράκτορα και, στη συνέχεια, συνδέστε έναν λογαριασμό Trello με ασφάλεια. Το διακριτικό λογαριασμού αποθηκεύεται στον διακομιστή και χρησιμοποιείται μόνο για αυτόν τον πράκτορα.';

  @override
  String get saveAccount => 'Αποθήκευση λογαριασμού';

  @override
  String get saveChanges => 'Αποθήκευση αλλαγών';

  @override
  String get saveCloudComputerSettings =>
      'Αποθηκεύστε τις ρυθμίσεις υπολογιστή cloud';

  @override
  String get saveConnect => 'Αποθήκευση & Σύνδεση';

  @override
  String get saveDefaults => 'Αποθήκευση προεπιλογών';

  @override
  String get saveDiagnosticReport => 'Αποθήκευση διαγνωστικής αναφοράς';

  @override
  String get saveEmail => 'Αποθήκευση email';

  @override
  String get saveEmailSettings => 'Αποθηκεύστε τις ρυθμίσεις email';

  @override
  String get saveGeneralSettings => 'Αποθήκευση γενικών ρυθμίσεων';

  @override
  String get saveName => 'Αποθήκευση ονόματος';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Αποθηκεύστε τα διαγνωστικά ρύθμισης NeoAgent';

  @override
  String get saveOnly => 'Αποθήκευση μόνο';

  @override
  String get saveSetup => 'Αποθήκευση εγκατάστασης';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Αποθηκεύστε αυτούς τους κωδικούς ανάκτησης τώρα. Δεν θα προβληθούν ξανά.';

  @override
  String get savedDeliveryDestination => 'Αποθηκευμένος προορισμός παράδοσης';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Αποθηκευμένα όρια τιμών για @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Σαρώστε ένα QR σύνδεσης NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Σαρώστε ένα QR σύζευξης NeoAgent από άλλη συσκευή και εγκρίνετέ το από αυτήν την περίοδο λειτουργίας εκκίνησης.';

  @override
  String get scanLoginQr => 'Σάρωση QR σύνδεσης';

  @override
  String get scanPairingQr => 'Σάρωση σύζευξης QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Σαρώστε τα αιτήματα σύνδεσης QR από αποσυνδεδεμένες συσκευές και εγκρίνετέ τα από αυτήν την επαληθευμένη περίοδο λειτουργίας για κινητά.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Σάρωση για να ολοκληρώσετε το $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Σάρωση με το NeoAgent στο τηλέφωνό σας';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Σαρώνει νέα email και σας κάνει ping μόνο όταν κάτι έχει σημασία.';

  @override
  String get schedule => 'Πρόγραμμα';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'προγραμματισμένη ώρα. Μόλις μετρηθούν οι διαδρομές, θα ξεκινήσει νωρίτερα.';

  @override
  String get screen => 'Οθόνη';

  @override
  String get screenAction => 'δράση οθόνης';

  @override
  String get scrollIsNotSupportedOnThis =>
      'Η κύλιση δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get scrollToBottom => 'Κάντε κύλιση προς τα κάτω';

  @override
  String get search => 'Αναζήτηση';

  @override
  String get search2 => 'Αναζήτηση…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Ρυθμίσεις διαχειριστή αναζήτησης (π.χ. SMTP, Ollama, αρχεία καταγραφής)';

  @override
  String get searchAgain => 'Αναζήτηση ξανά';

  @override
  String get searchByUsernameOrEmail => 'Αναζήτηση με όνομα χρήστη ή email';

  @override
  String get searchChannels => 'Αναζήτηση καναλιών';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Αναζήτηση ανακαλυφθέντων καναλιών ανταλλαγής μηνυμάτων, επαφών, ομάδων και πρόσφατων συνομιλιών.';

  @override
  String get searchGroups => 'Αναζήτηση ομάδων';

  @override
  String get searchMemory => 'Μνήμη αναζήτησης';

  @override
  String get searchModelsOrProviders => 'Αναζήτηση μοντέλων ή παρόχων';

  @override
  String get searchModelsOrProviders2 => 'Αναζήτηση μοντέλων ή παρόχων…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Αναζήτηση πρόσφατων ατόμων και ομάδων';

  @override
  String get searchSessions => 'Αναζήτηση συνεδριών';

  @override
  String get searchSettings => 'Ρυθμίσεις αναζήτησης';

  @override
  String get searchTitleModelTriggerRunId =>
      'Αναζήτηση τίτλου, μοντέλου, ενεργοποίησης, αναγνωριστικού εκτέλεσης';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Εργαλεία αναζήτησης, ενσωματώσεις και δεξιότητες';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Αναζήτηση κωδικού για \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Αναζήτηση αρχείων για \"$arg1\"';
  }

  @override
  String get secretField => 'Μυστικό πεδίο';

  @override
  String get secureCookies => 'Ασφαλή cookies';

  @override
  String get security => 'Ασφάλεια';

  @override
  String get securityKey => 'Κλειδί ασφαλείας';

  @override
  String get securityKeyPromptWasDismissed =>
      'Η προτροπή κλειδιού ασφαλείας παραβλέφθηκε.';

  @override
  String get securityKeySignInCompletedBut =>
      'Η είσοδος με κλειδί ασφαλείας ολοκληρώθηκε, αλλά το NeoAgent δεν μπόρεσε να διατηρήσει την περίοδο λειτουργίας του προγράμματος περιήγησης. Παρακαλούμε συνδεθείτε ξανά.';

  @override
  String get securityKeySignInCouldNot =>
      'Δεν ήταν δυνατή η έναρξη της σύνδεσης με κλειδί ασφαλείας.';

  @override
  String get securityKeys => 'Κλειδιά ασφαλείας';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Τα κλειδιά ασφαλείας είναι διαθέσιμα μόνο στην εφαρμογή web NeoAgent.';

  @override
  String get seeAll => 'Δείτε όλα';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Δείτε ποιον διακομιστή NeoAgent χρησιμοποιεί αυτό το παράθυρο και εκτελέστε το backend σε αυτόν τον υπολογιστή.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'δείτε το όνομα χρήστη σας και αυτές τις ρυθμίσεις, ποτέ τις συνομιλίες, τις αναμνήσεις σας ';

  @override
  String get selectARun => 'Επιλέξτε ένα τρέξιμο';

  @override
  String get selectASessionToSeeIts =>
      'Επιλέξτε μια περίοδο λειτουργίας για να δείτε τον υπολογιστή, τα αρχεία και τις αλλαγές της.';

  @override
  String get selectAll => 'Επιλέξτε όλα';

  @override
  String get selectAll2 => 'Επιλέξτε Όλα';

  @override
  String selectArg1(Object? arg1) {
    return 'Επιλέξτε $arg1';
  }

  @override
  String get selectTrigger => 'Επιλέξτε Trigger';

  @override
  String get send => 'Αποστολή (⌘↵)';

  @override
  String get send2 => 'Αποστολή';

  @override
  String get sendATaskFromChatAnd =>
      'Στείλτε μια εργασία από τη συνομιλία και το ιστορικό εκτέλεσής της θα εμφανιστεί εδώ.';

  @override
  String get sendItToATeammateWith =>
      'στείλτε το σε έναν συμπαίκτη με λογαριασμό σε αυτόν τον διακομιστή.';

  @override
  String get sendLink => 'Αποστολή συνδέσμου';

  @override
  String get sendPath => 'Διαδρομή αποστολής';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Αποστολή αιτημάτων POST / PUT / DELETE σε εξωτερικά API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Στείλτε αυτόν τον σύνδεσμο μόνο στο άτομο για το οποίο προορίζεται. Εμφανίζεται μία φορά. ';

  @override
  String get senderAddress => 'Διεύθυνση αποστολέα';

  @override
  String get senderFilterOptional => 'Φίλτρο αποστολέα (προαιρετικό)';

  @override
  String get sentSharedAttachments => 'Εστάλη κοινόχρηστα συνημμένα.';

  @override
  String get separateAccount => 'Ξεχωριστός λογαριασμός';

  @override
  String get server => 'Διακομιστής';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Προεπιλογή διακομιστή ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Προεπιλογές διακομιστή για φωνητικές κλήσεις εντός εφαρμογής. Οι κλήσεις εκτελούνται ζωντανά ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'ο ίδιος ο διακομιστής: λογαριασμοί, πάροχοι και διαμόρφωση.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Διακομιστής, ψευδώνυμο, κανάλι και προαιρετικό TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'Αντιγραφή σφαλμάτων προειδοποιήσεων κονσόλας εξόδου διακομιστή';

  @override
  String get serverProviderCredentials => 'Διαπιστευτήρια παρόχου διακομιστή';

  @override
  String get serverUrl => 'URL διακομιστή';

  @override
  String get serverUsageLimitsDonTApply =>
      'Τα όρια χρήσης διακομιστή δεν ισχύουν για μοντέλα που εκτελούνται με δικό σας κλειδί.';

  @override
  String get serviceEmail => 'email υπηρεσίας';

  @override
  String get serviceEmailIsNotConfigured =>
      'Το email υπηρεσίας δεν έχει ρυθμιστεί';

  @override
  String get serviceEmailSmtp => 'Υπηρεσία email (SMTP)';

  @override
  String get sessionActions => 'Ενέργειες συνεδρίας';

  @override
  String get sessions => 'Συνεδρίες';

  @override
  String get sessions2 => 'ΣΥΝΕΔΡΙΕΣ';

  @override
  String get sessionsArePinnedToAFolder =>
      'Οι περίοδοι λειτουργίας είναι καρφιτσωμένες σε ένα φάκελο και έναν υπολογιστή. Ξεκινήστε ένα για να σχεδιάσετε, να κατασκευάσετε, να δοκιμάσετε και να στείλετε από εδώ.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'συνεδρίες (άρθρο 17 του GDPR). Οι λογαριασμοί διαχειριστή δεν μπορούν να διαγραφούν ';

  @override
  String get sessionsLogoutRevokeForce =>
      'ισχύς ανάκλησης αποσύνδεσης περιόδων σύνδεσης';

  @override
  String get setBlockAskAllowPerTool =>
      'Ορίστε μπλοκ / ερώτηση / άδεια ανά κατηγορία εργαλείου ή επιλέξτε μια καθολική λειτουργία.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Ρυθμίστε το NeoAgent σε αυτόν τον υπολογιστή';

  @override
  String get setUpOrConnectNeoagent => 'Ρυθμίστε ή συνδέστε το NeoAgent';

  @override
  String get setUrl => 'Ορισμός διεύθυνσης URL';

  @override
  String get settings => 'Ρυθμίσεις';

  @override
  String get settingsAndCannotBeUndone =>
      'ρυθμίσεις και δεν μπορεί να αναιρεθεί.';

  @override
  String get settingsArea => 'Περιοχή ρυθμίσεων';

  @override
  String get settingsAreas => 'Περιοχές ρυθμίσεων';

  @override
  String get setup => 'Ρύθμιση';

  @override
  String get setupDetails => 'Λεπτομέρειες ρύθμισης';

  @override
  String get setupRequired => 'Απαιτείται ρύθμιση';

  @override
  String get setupWasCancelled => 'Η ρύθμιση ακυρώθηκε.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Κοινόχρηστα συνημμένα από τον πελάτη NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Κοινή χρήση από άλλη εφαρμογή';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Τα κοινόχρηστα κλειδιά παρόχου έχουν ρυθμιστεί στον διακομιστή. Για να χρησιμοποιήσετε το δικό σας κλειδί API ή ένα προσαρμοσμένο τελικό σημείο, μεταβείτε στην ενότητα Για προχωρημένους → Φέρτε το δικό σας κλειδί.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Κοινή χρήση με τη συνομιλία NeoAgent και τη μνήμη της.';

  @override
  String get shellCommands => 'Εντολές Shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Εμφάνιση όλων των $arg1';
  }

  @override
  String get showEarlier => 'Εμφάνιση νωρίτερα';

  @override
  String get showEveryStep => 'Δείξτε κάθε βήμα';

  @override
  String get showTools => 'Εμφάνιση εργαλείων';

  @override
  String get showWorkbenchJ => 'Εμφάνιση πάγκου εργασίας (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Εμφάνιση του πρώτου $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Εμφανίζεται στην πλαϊνή γραμμή. Αφήστε το κενό για να χρησιμοποιήσετε το όνομα χρήστη σας.';

  @override
  String get signIn => 'Συνδεθείτε';

  @override
  String get signInCompletedButNeoagentCould =>
      'Η σύνδεση ολοκληρώθηκε, αλλά το NeoAgent δεν μπόρεσε να διατηρήσει την περίοδο λειτουργίας του προγράμματος περιήγησης. Παρακαλούμε συνδεθείτε ξανά. Εάν αυτό συνεχίζει να συμβαίνει, ελέγξτε τις ρυθμίσεις cookie περιόδου λειτουργίας υποστήριξης.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Η σύνδεση ολοκληρώθηκε, αλλά το NeoAgent δεν μπόρεσε να διατηρήσει την περίοδο λειτουργίας του προγράμματος περιήγησης. Παρακαλούμε συνδεθείτε ξανά. Εάν αυτό συνεχίσει να συμβαίνει, το cookie περιόδου λειτουργίας υποστήριξης είναι πιθανό να μην διατηρηθεί.';

  @override
  String get signInToThisNeoagentServer =>
      'Συνδεθείτε σε αυτόν τον διακομιστή NeoAgent πριν σαρώσετε έναν κωδικό QR σύζευξης.';

  @override
  String get signInWithAHardwareKey =>
      'Συνδεθείτε με κλειδί υλικού ή κωδικό πρόσβασης αντί για τον κωδικό πρόσβασής σας. ';

  @override
  String get signInWithASecurityKey => 'Συνδεθείτε με ένα κλειδί ασφαλείας';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Συνδεθείτε με το $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Εγκρίνετε το NeoAgent στον λογαριασμό σας $arg1. Δεν υπάρχει κλειδί για αντιγραφή.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Αναμονή για $arg1. Ολοκληρώστε στο πρόγραμμα περιήγησής σας.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Επικολλήστε τον κωδικό $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Αφού εγκρίνατε το NeoAgent, το $arg1 έδειξε έναν κωδικό μιας χρήσης. Επικολλήστε το εδώ.';
  }

  @override
  String get signInCode => 'Κωδικός σύνδεσης';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Συνδεθήκατε με $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Η σύνδεση απέτυχε: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Συνδεθείτε με το ίδιο email και τον ίδιο κύριο κωδικό πρόσβασης που χρησιμοποιείτε στο Bitwarden. Ο κύριος κωδικός πρόσβασης και ο κωδικός δύο βημάτων χρησιμοποιούνται μόνο για είσοδο και δεν αποθηκεύονται ούτε αποστέλλονται ποτέ στο AI.';

  @override
  String get signOut => 'Αποσυνδεθείτε';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Αποσύνδεση @$arg1 παντού;';
  }

  @override
  String get signOutEverywhere => 'Αποσυνδεθείτε παντού';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API bridge';

  @override
  String get signalCliServerUrl => 'URL διακομιστή signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Έγινε υπογραφή @$arg1 από κάθε συνεδρία.';
  }

  @override
  String get signedInDevices => 'συνδεδεμένες συσκευές';

  @override
  String get signedInWithin24Hours => 'Σύνδεση εντός 24 ωρών';

  @override
  String get signingSecret => 'Μυστικό υπογραφής';

  @override
  String sinceArg1(Object? arg1) {
    return 'Από $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'από το $arg1';
  }

  @override
  String get singleMessage => 'Ενιαίο μήνυμα';

  @override
  String get singleUse => 'Μίας χρήσης';

  @override
  String get skill => 'Επιδεξιότητα';

  @override
  String get skillChanges => 'Αλλαγές δεξιοτήτων';

  @override
  String get skillContent => 'Περιεχόμενο δεξιοτήτων';

  @override
  String get skills => 'Δεξιότητες';

  @override
  String get skip => 'Παράλειψη';

  @override
  String get skipForNow => 'Παράλειψη προς το παρόν';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Παραλείψτε αυτήν την εργασία πριν καλέσετε το μοντέλο.';

  @override
  String get slackMessageReceived => 'Λήφθηκε χαλαρό μήνυμα';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Sleep $arg1 συνεδρίες';
  }

  @override
  String get smartSelector => 'έξυπνος επιλογέας';

  @override
  String get smartSelector2 => 'Έξυπνος επιλογέας';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP host';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'Επαναφορά του κωδικού πρόσβασης αποστολέα αλληλογραφίας smtp tls των ειδοποιήσεων επιβεβαίωσης';

  @override
  String get smtpPassword => 'Κωδικός πρόσβασης SMTP';

  @override
  String get smtpPort => 'Θύρα SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Η θύρα SMTP πρέπει να είναι ακέραιος αριθμός από το 1 έως το 65535.';

  @override
  String get smtpUsername => 'Όνομα χρήστη SMTP';

  @override
  String get soTheRunStartsThatMuch => 'οπότε το τρέξιμο ξεκινά πολύ νωρίτερα.';

  @override
  String get socialBehaviorOff => 'Απενεργοποίηση κοινωνικής συμπεριφοράς';

  @override
  String get socialIntelligence => 'κοινωνική νοημοσύνη';

  @override
  String get socialIntelligence2 => 'Κοινωνική νοημοσύνη';

  @override
  String get socialObservability => 'Κοινωνική παρατηρησιμότητα';

  @override
  String get socialReach => 'κοινωνική εμβέλεια';

  @override
  String get socialReach2 => 'Κοινωνική εμβέλεια';

  @override
  String get socialReach3 => 'Κοινωνική Απήχηση';

  @override
  String get socialReachUpdated => 'Το Social Reach ενημερώθηκε.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Οι πράκτορες πηγών κοινωνικής δικτύωσης μπορούν να διαβάζουν απευθείας, συμπεριλαμβανομένων ροών δεδομένων, αποθετηρίων, Reddit, X, βίντεο και δεδομένων αγοράς που υποστηρίζονται από cookie.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Κάτι πήγε στραβά. Δοκιμάστε ξανά.';

  @override
  String get source => 'Πηγή';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Το αναγνωριστικό χώρου ή συνομιλίας χρησιμοποιείται όταν αυτός ο πράκτορας ξεκινά μια συνομιλία.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Υποστήριξη επανάκλησης για το Space webhook και app';

  @override
  String get speaking => 'Μιλώντας';

  @override
  String get speechToSpeechModelUsingThe =>
      'μοντέλο ομιλίας σε ομιλία χρησιμοποιώντας το πλήκτρο OpenAI ή Google κάτω από ';

  @override
  String get speechToText => 'Ομιλία σε κείμενο';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Ομιλία σε κείμενο μεταγράφει φωνητικές σημειώσεις και υπαγόρευση. Το Auto χρησιμοποιεί OpenAI, Gemini ή Deepgram, όποιο έχει κλειδί API. Το μοντέλο φωνητικής απάντησης είναι το μοντέλο συνομιλίας που απαντά στις φωνητικές σημειώσεις.';

  @override
  String get sqlConsole => 'Κονσόλα SQL';

  @override
  String get stable => 'Σταθερό';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Το Stable εγκαθιστά την πιο πρόσφατη δημοσιευμένη έκδοση backend.';

  @override
  String get stackTrace => 'ίχνος στοίβας';

  @override
  String get standard => 'Τυπικό';

  @override
  String get standardView => 'Τυπική όψη';

  @override
  String get start => 'Έναρξη';

  @override
  String get startASessionToPlanOr =>
      'Ξεκινήστε μια συνεδρία για να σχεδιάσετε ή να δημιουργήσετε με το NeoAgent.';

  @override
  String get startAndroid => 'Ξεκινήστε το Android';

  @override
  String get startComputer => 'Εκκινήστε τον υπολογιστή';

  @override
  String get startFullSetup => 'Ξεκινήστε την πλήρη εγκατάσταση';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Ξεκινήστε τη ρύθμιση';

  @override
  String get startTalking => 'Άρχισε να μιλάς';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Ξεκινήστε πρώτα το τηλέφωνο Android και, στη συνέχεια, αποθέστε ένα αρχείο .apk ή .apks εδώ.';

  @override
  String get startTheServerLaterFromThe =>
      'Ξεκινήστε τον διακομιστή αργότερα από τη λίστα μόλις αποθηκευτεί η διαμόρφωση.';

  @override
  String get startWithARecommendedTask =>
      'Ξεκινήστε με μια προτεινόμενη εργασία';

  @override
  String get startingAndroid => 'Εκκίνηση Android';

  @override
  String get startingYourComputer => 'Εκκίνηση του υπολογιστή σας';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Ξεκινά με xoxb-. Από τα διαπιστευτήρια της εφαρμογής Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Σφάλμα: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'stats runs tokens ποσοστό επιτυχίας γραφημάτων χρηστών';

  @override
  String get status => 'Κατάσταση';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'πάροχοι vm χρόνου εκτέλεσης βάσης δεδομένων κατάστασης';

  @override
  String get statusIsNotLoadedYet => 'Η κατάσταση δεν έχει φορτωθεί ακόμα.';

  @override
  String get stayManagedByYou => 'παραμένετε υπό τη διαχείριση σας.';

  @override
  String get stayOnTheCall => 'Μείνετε στο τηλεφώνημα';

  @override
  String get stayedQuiet => 'Έμεινε ήσυχος';

  @override
  String get steering => 'ΤΙΜΟΝΙ';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'ΒΗΜΑ $arg1 OF $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Βήματα $arg1';
  }

  @override
  String get stop => 'Διακοπή';

  @override
  String get stop2 => 'Διακοπή (⌘.)';

  @override
  String get stopManaging => 'Σταματήστε να διαχειρίζεστε';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Διακοπή διαχείρισης $arg1;';
  }

  @override
  String get stopRun => 'Σταμάτα να τρέχεις';

  @override
  String get stopSpeaking => 'Σταμάτα να μιλάς';

  @override
  String get stoppedBeforeCompletion => 'Σταμάτησε πριν από την ολοκλήρωση';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Σφάλμα: $arg1';
  }

  @override
  String get storage => 'Αποθήκευση';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'αποθηκευμένο κρυπτογραφημένο και χρησιμοποιείται μόνο για τις δικές σας εκτελέσεις.';

  @override
  String get storedMetrics => 'Αποθηκευμένες μετρήσεις';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Αποθηκεύει μόνο το κλειδί περιόδου λειτουργίας Bitwarden κρυπτογραφημένο σε αυτόν τον διακομιστή, έτσι ώστε οι συνδέσεις να επιβιώνουν από την επανεκκίνηση. Μπορείτε να το κλειδώσετε ανά πάσα στιγμή.';

  @override
  String get strong => 'Δυνατός';

  @override
  String get strongPassword => 'Ισχυρός κωδικός πρόσβασης.';

  @override
  String get subAgent => 'Υποπράκτορας';

  @override
  String get subagentUpdate => 'Ενημέρωση Subagent';

  @override
  String get subagentUpdate2 => 'Ενημέρωση Subagent.';

  @override
  String get successRate => 'Ποσοστό επιτυχίας';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Προτάσεις: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Συνοψίστε την τελευταία μου διαδρομή';

  @override
  String get supportUrl => 'URL υποστήριξης';

  @override
  String get supportedRainStartSnowStartWind =>
      'Υποστηρίζεται: rain_start, snow_start, wind_alert, temperature_pove, temperature_polow';

  @override
  String get switchAgent => 'Αντικαταστάτης';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Οι συμβολικοί σύνδεσμοι δεν επιτρέπονται στις διαδρομές του NeoAgent Workspace.';

  @override
  String get syncNow => 'Συγχρονισμός τώρα';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Ρυθμίσεις απορρήτου συστήματος';

  @override
  String get tableInfoUsers => 'Πληροφορίες πίνακα (χρήστες)';

  @override
  String get tagsOnly => 'Μόνο ετικέτες';

  @override
  String get tasks => 'Καθήκοντα';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Οι εργασίες εκτελούνται μόνες τους και σας στέλνουν μήνυμα με το ';

  @override
  String get teach => 'Διδάξτε';

  @override
  String get teachingInProgress => 'Διδασκαλία σε εξέλιξη';

  @override
  String get team => 'Ομάδα';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Οι σύνδεσμοι ομάδας δεν κάνουν ποτέ κανέναν διαχειριστή διακομιστή. Οι διαχειριστές τρέχουν το ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Χώροι ομάδας, δωμάτια, κανάλια και ζωντανές κοινότητες.';

  @override
  String get teamsMessageReceived => 'Λήφθηκε το μήνυμα της ομάδας';

  @override
  String get templates => 'Πρότυπα';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Τα προσωρινά αρχεία εγκατάστασης θα καθαριστούν αργότερα.';

  @override
  String get tenantId => 'Ταυτότητα μισθωτή';

  @override
  String get testConnection => 'Δοκιμή σύνδεσης';

  @override
  String get testConnection2 => 'Δοκιμή σύνδεσης';

  @override
  String get textChat => 'Κείμενο & συνομιλία';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'που πρόσθεσαν το δικό τους κλειδί συνεχίστε να το χρησιμοποιείτε.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Αυτό το email ανήκει ήδη σε έναν υπάρχοντα λογαριασμό. Συνδεθείτε πρώτα και, στη συνέχεια, συνδέστε το Google από τις ρυθμίσεις λογαριασμού.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Αυτό το email είναι ήδη συνδεδεμένο με άλλο λογαριασμό.';

  @override
  String get thatQrCodeIsNotA =>
      'Αυτός ο κωδικός QR δεν είναι αίτημα σύνδεσης NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Αυτός ο κωδικός QR δεν είναι αίτημα σύζευξης NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Αυτό το κλειδί ασφαλείας είναι ήδη εγγεγραμμένο σε αυτόν τον λογαριασμό.';

  @override
  String get theAddress => 'Η διεύθυνση';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Η διεύθυνση του διακομιστή σας BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Η διεύθυνση που χρησιμοποιούν τα άτομα και οι πάροχοι OAuth για να προσεγγίσουν ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Ο πράκτορας διαβάζει τις ώρες που αναφέρετε και εκτελεί προγραμματισμένες εργασίες σε αυτήν τη ζώνη ώρας.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Ο πράκτορας θα ρωτήσει πριν από κάθε ευαίσθητο εργαλείο, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Ο πράκτορας θα αγνοήσει αυτήν την ικανότητα.';

  @override
  String get theAppCouldNotReachThis =>
      'Η εφαρμογή δεν μπόρεσε να φτάσει σε αυτήν την ανάπτυξη του NeoAgent. Ελέγξτε τη σύνδεση δικτύου σας ή επιβεβαιώστε ότι η διεύθυνση URL της υπηρεσίας είναι σωστή.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Το πρόγραμμα περιήγησης απέκλεισε ένα αίτημα προς το $arg1 λόγω της Πολιτικής ασφάλειας περιεχομένου.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Το πρόγραμμα περιήγησης απέκλεισε ένα απαιτούμενο αίτημα λόγω της Πολιτικής ασφάλειας περιεχομένου.';

  @override
  String get theCloudWorkspace => 'τον χώρο εργασίας του cloud';

  @override
  String get theComputerCouldNotStart =>
      'Ο υπολογιστής δεν μπορούσε να ξεκινήσει';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Ο υπολογιστής χρειάζεται περισσότερο ελεύθερο χώρο στον κεντρικό υπολογιστή NeoAgent. Ελευθερώστε λίγο χώρο και δοκιμάστε ξανά.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Ο χρόνος εκτέλεσης του υπολογιστή χρειάζεται επισκευή. Εκτελέστε το NeoAgent Doctor και δοκιμάστε ξανά.';

  @override
  String get theConnectionTestFailed => 'Η δοκιμή σύνδεσης απέτυχε.';

  @override
  String get theDesktopDidNotStart => 'Η επιφάνεια εργασίας δεν ξεκίνησε';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Το ανακαλυφθέν NeoAgent επέστρεψε ελλιπή δεδομένα ταυτότητας.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Το ανακαλυφθέν NeoAgent χρησιμοποιεί ένα μη υποστηριζόμενο πρωτόκολλο εγκατάστασης.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Η υπηρεσία που ανακαλύφθηκε δεν είναι NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Ο χρόνος εκτέλεσης του NeoAgent που λήφθηκε δεν πέρασε από την επαλήθευση.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Το webhook του Google Chat space στο οποίο θα πρέπει να δημοσιεύσει αυτός ο αντιπρόσωπος.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Το πρόγραμμα εγκατάστασης δεν είναι πλέον διαθέσιμο.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Η διαδραστική επιφάνεια εργασίας Linux είναι διαθέσιμη στην εφαρμογή web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Η εισαγωγή δεν είναι διαθέσιμη σε αυτήν τη συσκευή.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Το πιο πρόσφατο τρέχει σε κάθε λογαριασμό.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Το πιο πρόσφατο παράθυρο συγχρονισμού έληξε με το $arg1 και δεν βρέθηκε καμία νέα εγγραφή του Health Connect. Οι παρακάτω αποθηκευμένες μετρήσεις προήλθαν από προηγούμενους συγχρονισμούς.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Η γραφική περίοδος λειτουργίας Linux δεν εκτελείται.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Το μοντέλο ζωντανής φωνής δεν απάντησε. Προσπαθήστε ξανά.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Η τοπική εντολή NeoAgent εξήλθε με κωδικό $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Η τοπική εντολή NeoAgent έληξε.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Ο τοπικός χρόνος εκτέλεσης NeoAgent χρειάζεται επισκευή.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Ο τοπικός χρόνος εκτέλεσης χρειάζεται επισκευή ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Ο αρχικός κατάλογος τοπικών χρηστών δεν είναι διαθέσιμος.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Ο λογαριασμός αλληλογραφίας NeoAgent στέλνει επιβεβαιώσεις εγγραφής, είσοδο ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Ο κύριος πράκτορας δημιουργείται αυτόματα όταν χρειάζεται.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Ο αντίστοιχος χρόνος εκτέλεσης NeoAgent λείπει από αυτήν την έκδοση.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Το Mattermost εισερχόμενο webhook στο οποίο πρέπει να δημοσιεύσει αυτός ο πράκτορας.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Τα μοντέλα που ο Έξυπνος Επιλογέας δρομολογεί αυτόματα μεταξύ τους.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Η λήψη του backend του NeoAgent δεν ταιριάζει με το μανιφέστο του.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Η λήψη του backend του NeoAgent δεν ολοκληρώθηκε.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Το σύστημα υποστήριξης NeoAgent σε αυτόν τον υπολογιστή δεν απαντά στη θύρα ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Δεν ήταν δυνατή η λήψη του χρόνου εκτέλεσης υποστήριξης NeoAgent.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Το backend του NeoAgent άργησε να ανταποκριθεί για το $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Η ανάπτυξη του NeoAgent απάντησε με HTTP 402 αντί για το κανονικό 401 για μη έγκυρα διαπιστευτήρια. Ελέγξτε τον αντίστροφο διακομιστή μεσολάβησης, την πύλη ελέγχου ταυτότητας ή τους κανόνες που σχετίζονται με πληρωμές σε αυτόν τον διακομιστή.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Η ανάπτυξη του NeoAgent απάντησε με HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Η ανάπτυξη του NeoAgent ανταποκρίθηκε με το HTTP 402. Ελέγξτε τους κανόνες αντιστροφής διακομιστή μεσολάβησης, πύλης ελέγχου ή πληρωμών σε αυτόν τον διακομιστή.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Η περίπτωση NeoAgent στην οποία είναι συνδεδεμένη αυτή η εφαρμογή.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Η υπηρεσία έκδοσης NeoAgent επέστρεψε μη έγκυρα δεδομένα.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Τα μεταδεδομένα τεχνουργήματος χρόνου εκτέλεσης NeoAgent δεν είναι έγκυρα.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Η δήλωση χρόνου εκτέλεσης NeoAgent δεν πέρασε την επαλήθευση υπογραφής.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Η δήλωση χρόνου εκτέλεσης NeoAgent δεν έχει τεχνουργήματα.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Η υπογραφή δήλωσης χρόνου εκτέλεσης NeoAgent δεν είναι έγκυρη.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Ο κωδικός πρόσβασης που ορίζετε στο BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Τα άτομα που διαχειρίζεσαι μένουν μαζί σου.';

  @override
  String get theProviderAnswers => 'απαντά ο πάροχος.';

  @override
  String get theQueryReturnedNoRows => 'Το ερώτημα δεν επέστρεψε καμία σειρά.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Η ζητούμενη οθόνη επιφάνειας εργασίας δεν είναι διαθέσιμη.';

  @override
  String get theRest => 'τα υπόλοιπα.';

  @override
  String get theRestEndpointForYourSignal =>
      'Το τελικό σημείο REST για την παρουσία σήματος-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Το τρέξιμο διακόπτεται μέχρι να απαντήσετε.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Το τρέξιμο ξεκινά την προγραμματισμένη ώρα.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Ο χρόνος εκτέλεσης είναι μια ελαφριά επιφάνεια εργασίας Debian Linux με Chromium, PCManFM, Mousepad, LXTerminal, Python, Git και τυπικά εργαλεία γραμμής εντολών. Η χωρητικότητά του διαχειρίζεται ο κεντρικός υπολογιστής NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Δεν ήταν δυνατή η εκκίνηση της εγγραφής του κλειδιού ασφαλείας.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'ο διακομιστής διατηρεί μόνο ένα δακτυλικό αποτύπωμά του.';

  @override
  String get theServerOnThisComputerIs =>
      'Ο διακομιστής σε αυτόν τον υπολογιστή δεν εκτελείται';

  @override
  String get theServerReportedNoHealthChecks =>
      'Ο διακομιστής δεν ανέφερε κανέναν έλεγχο υγείας.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Ο αριθμός τηλεφώνου Signal που χρησιμοποιεί αυτό το bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Το εισερχόμενο webhook των ομάδων θα πρέπει να δημοσιεύσει αυτός ο πράκτορας.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Η πρόκληση δύο παραγόντων έληξε. Συνδεθείτε ξανά.';

  @override
  String get theTwoFactorCodeIsNot =>
      'Ο κωδικός δύο παραγόντων δεν είναι έγκυρος.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Το πακέτο επαληθευμένου χρόνου εκτέλεσης δεν ήταν δυνατό να επισημανθεί ως εκτελέσιμο.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Από το πακέτο επαληθευμένου χρόνου εκτέλεσης λείπουν τα απαιτούμενα αρχεία.';

  @override
  String get theWebAppCouldNotReach =>
      'Η εφαρμογή Ιστού δεν μπόρεσε να φτάσει στο σύστημα υποστήριξης NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Η εφαρμογή ιστού δεν μπόρεσε να φτάσει στο backend του NeoAgent στο $arg1. Ελέγξτε την κονσόλα του προγράμματος περιήγησης και τη διαμόρφωση αντίστροφου διακομιστή μεσολάβησης/δικτύου.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'εαυτούς; ο χειριστής του διακομιστή αφαιρεί πρώτα τον διαχειριστή με ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Αυτά τα κανάλια παραμένουν αθόρυβα. Για να ακούσετε ξανά νέα, προσθέστε τους στην ενότητα Ποιος μπορεί να στείλει μήνυμα για αυτήν την πλατφόρμα.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Αυτές οι λίστες είναι προαιρετικές, εκτός εάν μια ενότητα παραπάνω έχει οριστεί ως μόνο εγκεκριμένη.';

  @override
  String get thesePeopleAnywhere => 'Αυτοί οι άνθρωποι, οπουδήποτε';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Αυτά τα άτομα μπορούν να στείλουν μήνυμα στο $arg1 σε ιδιωτικές συνομιλίες και σε οποιαδήποτε ομάδα μοιράζονται.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Αυτά τα άτομα μπορούν να στείλουν μήνυμα στο $arg1 ένας προς έναν. Αυτό δεν τους αφήνει να μιλήσουν σε ομάδες.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Αυτά τα άτομα μπορούν να στείλουν μήνυμα σε $arg1 μόνο στην ομάδα που επιλέξατε.';
  }

  @override
  String get thesePeopleInOneGroup => 'Αυτοί οι άνθρωποι, σε μια ομάδα';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'αυτοί οι διακόπτες, ποτέ οι συνομιλίες, οι αναμνήσεις ή τα αρχεία σας.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Αυτός ο λογαριασμός θα ξεκλειδώσει το NeoAgent σε αυτό το μηχάνημα.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Αυτός ο αντιπρόσωπος μπορεί να αναθέσει σε οποιονδήποτε κατάλληλο πράκτορα παραλήπτη.';

  @override
  String get thisAgentIsUsingAServer =>
      'Αυτός ο πράκτορας χρησιμοποιεί ένα κλειδί API Trello που διαχειρίζεται διακομιστής. Χρειάζεται μόνο να εξουσιοδοτήσετε ένα διακριτικό λογαριασμού παρακάτω.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Αυτή η έκδοση δεν επιτρέπεται να συνομιλεί με αυτήν την ανάπτυξη του NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Αυτός ο κωδικός ανήκει σε διαφορετικό διακομιστή NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected =>
      'Αυτή η επιφάνεια εργασίας είναι συνδεδεμένη';

  @override
  String get thisDevice => 'Αυτή η συσκευή';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Αυτή η συσκευή: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Αυτή η συσκευή δεν μπορεί να καταχωρήσει κλειδιά ασφαλείας. Ανοίξτε το NeoAgent σε ένα πρόγραμμα περιήγησης μέσω HTTPS για να προσθέσετε ένα.';

  @override
  String get thisDeviceUnavailable => 'Αυτή η συσκευή — δεν είναι διαθέσιμη';

  @override
  String get thisFileHasNoContent => 'Αυτό το αρχείο δεν έχει περιεχόμενο.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Αυτό αποκρύπτει το \"$arg1\" από τη δρομολόγηση και την επιλογή.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Αυτή η ενσωμάτωση υποστηρίζει επί του παρόντος έναν συνδεδεμένο λογαριασμό ανά παράγοντα. Ανοίξτε ξανά τη ρύθμιση για να την αντικαταστήσετε.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Αυτή η ενσωμάτωση δεν είναι πλέον διαθέσιμη.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Αυτή η εισαγωγή έχει σχεδιαστεί για οριζόντια αναπαραγωγή σε πλήρη οθόνη.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Αυτή είναι μια διαχειριζόμενη ανάπτυξη. Ο χειριστής του ανοίγει ';

  @override
  String get thisMayTakeAMoment => 'Αυτό μπορεί να διαρκέσει λίγο.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Αυτός ο διακομιστής MCP δεν είναι πλέον διαμορφωμένος.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Αυτή η μνήμη θα αφαιρεθεί οριστικά.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Αυτή η έκδοση NeoAgent δεν έχει ρυθμιστεί για επαλήθευση χρόνου εκτέλεσης backend.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Αυτό διαγράφει οριστικά όλα τα δεδομένα σας και δεν μπορεί να γίνει ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Αυτό διαγράφει οριστικά τον λογαριασμό και όλα όσα κατέχει: ';

  @override
  String get thisPersonAnywhere => 'Αυτό το άτομο, οπουδήποτε';

  @override
  String get thisPersonInOneGroup => 'Αυτό το άτομο, σε μια ομάδα';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Αυτό το αίτημα σύνδεσης QR έληξε. Δημιουργήστε έναν νέο κωδικό και δοκιμάστε ξανά.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'αυτό το αίτημα σύνδεσης qr έχει λήξει';

  @override
  String get thisQrLoginRequestIsStill =>
      'Αυτό το αίτημα σύνδεσης QR εξακολουθεί να περιμένει έγκριση.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Αυτό το αίτημα σύνδεσης QR χρησιμοποιήθηκε ήδη.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Αυτό καταργεί τη ρύθμιση του Home Assistant και τη συνδεδεμένη παρουσία για αυτόν τον παράγοντα.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Αυτό καταργεί τη διεύθυνση URL υποστήριξης NeoRecall και όλους τους συνδεδεμένους λογαριασμούς NeoRecall για αυτόν τον παράγοντα.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Αυτό καταργεί τη διεύθυνση URL του Nextcloud και όλους τους συνδεδεμένους λογαριασμούς Nextcloud για αυτόν τον παράγοντα.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Αυτό καταργεί τη ρύθμιση Trello και τους συνδεδεμένους λογαριασμούς για αυτόν τον πράκτορα.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Αυτό απαιτεί έλεγχο ταυτότητας στον ίδιο διακομιστή NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Αυτή η εκτέλεση δεν παρήγαγε απόκριση προς το χρήστη.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Αυτή η εκτέλεση δεν έχει καταγεγραμμένα δεδομένα βημάτων.';

  @override
  String get thisServer => 'αυτόν τον διακομιστή.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Αυτός ο διακομιστής δεν αναφέρει ρυθμίσεις παρόχου.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Αυτή η ικανότητα δεν είναι πλέον εγκατεστημένη.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Αυτή η εργασία δεν έχει ολοκληρωθεί ακόμα, επομένως ξεκινά ακόμα στο ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Αυτή η εργασία θα εκτελεστεί μόνο όταν πατήσετε Εκτέλεση τώρα.';

  @override
  String get thisWeek => 'Αυτή την εβδομάδα';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Αυτό θα εισάγει την απόκριση στο $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Αυτό θα αφαιρέσει το \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Αυτό θα αφαιρέσει το \"$arg1\" από τη λίστα διακομιστών.';
  }

  @override
  String get time => 'Χρόνος';

  @override
  String get timeZone => 'ζώνη ώρας';

  @override
  String get timeZone2 => 'Ζώνη ώρας';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Λήξη χρόνου$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Δεν ήταν δυνατή η λίστα ζωνών ώρας: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Δεν ήταν δυνατή η ανάγνωση της ζώνης ώρας της συσκευής: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Δεν ήταν δυνατή η αποθήκευση της ζώνης ώρας της συσκευής: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'σε $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'για να χρησιμοποιήσετε την προεπιλογή του διακομιστή.';

  @override
  String get today => 'Σήμερα';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Προϋπολογισμός διακριτικού για @$arg1. Αφήστε ένα πεδίο κενό ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Προϋπολογισμός διακριτικού για κάθε λογαριασμό χωρίς τη δική του παράκαμψη. Αφήστε α ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'όριο προϋπολογισμού διακριτικού χρήστη εβδομαδιαίου ορίου 4 ωρών';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'όριο προϋπολογισμού συμβολικού 4 ώρες εβδομαδιαία συνολική ποσόστωση';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Η χρήση διακριτικού δεν είναι διαθέσιμη σε αυτήν την έκδοση διακομιστή.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Διακριτικά που μπορεί να χρησιμοποιήσει οποιοσδήποτε λογαριασμός σε 4 ώρες.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Διακριτικά που μπορεί να χρησιμοποιήσει οποιοσδήποτε λογαριασμός σε 7 ημέρες.';

  @override
  String get tokensPerDay => 'Μαρτυρίες ανά ημέρα';

  @override
  String get tokensPerRun => 'Tokens ανά τρέξιμο';

  @override
  String get tokensToday => 'Tokens σήμερα';

  @override
  String get tokensUsed => ' μάρκες που χρησιμοποιούνται';

  @override
  String get tomorrowPrep => 'Αύριο προετοιμασία';

  @override
  String get tooManyAttempts => 'πάρα πολλές προσπάθειες';

  @override
  String get tooManySignInAttemptsPlease =>
      'Πάρα πολλές προσπάθειες σύνδεσης. Περιμένετε και δοκιμάστε ξανά.';

  @override
  String get tool => 'Εργαλείο';

  @override
  String get toolApproval => 'Έγκριση εργαλείου';

  @override
  String get toolApprovalRequired => 'Απαιτείται έγκριση εργαλείου';

  @override
  String get toolCompleted => 'Το εργαλείο ολοκληρώθηκε';

  @override
  String get toolFailed => 'Το εργαλείο απέτυχε';

  @override
  String get toolPermissions => 'Δικαιώματα εργαλείου';

  @override
  String get toolStarted => 'Το εργαλείο ξεκίνησε';

  @override
  String get tools => 'Εργαλεία';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Εργαλεία που δεν είναι ενσωματωμένα στο NeoAgent, συμπεριλαμβανομένων των συνδεδεμένων διακομιστών MCP και των παρόχων προσαρμοσμένων εργαλείων.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Προσφερόμενα εργαλεία ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Εργαλεία που μπορεί να χρησιμοποιεί ο διαχειριζόμενος λογαριασμός';

  @override
  String get topUsers => 'Κορυφαίοι χρήστες';

  @override
  String get topUsersAndRecentRuns =>
      'Κορυφαίοι χρήστες και πρόσφατες εκτελέσεις';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Σύνολο: $arg1 διακριτικά σε όλες τις εκτελέσεις $arg2';
  }

  @override
  String get totalRuns => 'Συνολικές διαδρομές';

  @override
  String get totalTokens => 'Σύνολο μάρκες';

  @override
  String get totalUsers => 'Σύνολο χρηστών';

  @override
  String get transcript => 'Μεταγραφή';

  @override
  String get transcript2 => 'ΜΕΤΑΓΡΑΦΗ';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Η μεταγραφή απέτυχε: $arg1';
  }

  @override
  String get transfer => 'Μεταφορά';

  @override
  String get trelloApiKey => 'Κλειδί API Trello';

  @override
  String get trelloApiKeyIsRequired => 'Απαιτείται το κλειδί API Trello.';

  @override
  String get trelloSetup => 'Ρύθμιση Trello';

  @override
  String get triggerType => 'Τύπος σκανδάλης';

  @override
  String get tryABroaderSearchLikeModels =>
      'Δοκιμάστε μια ευρύτερη αναζήτηση όπως μοντέλα, πρόγραμμα περιήγησης ή φωνή.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Δοκιμάστε ένα όνομα παρόχου, \"email\", \"limits\", \"update\" ή \"logs\".';

  @override
  String get tryAgain => 'Προσπαθήστε ξανά';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Προσπαθήστε ξανά. Εάν αυτό συνεχίζει να συμβαίνει, εκτελέστε το NeoAgent Doctor για να ελέγξετε το χρόνο εκτέλεσης του υπολογιστή.';

  @override
  String get tryAgainInAMoment => 'Δοκιμάστε ξανά σε λίγο.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Δοκιμάστε ξανά ή εκτελέστε το NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Δοκιμάστε μια άλλη αναζήτηση, συνδέστε μια πλατφόρμα ανταλλαγής μηνυμάτων ή εισαγάγετε ένα αναγνωριστικό προορισμού με μη αυτόματο τρόπο.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Ενεργοποιήστε μια ομάδα εάν το $arg1 θα πρέπει επίσης να διαβάζει μηνύματα που δεν του προσθέτουν ετικέτα.';
  }

  @override
  String get turnOffComputer => 'Απενεργοποιήστε τον υπολογιστή';

  @override
  String get turnOffOnlyForAMail =>
      'Απενεργοποίηση μόνο για διακομιστή αλληλογραφίας με αυτο-υπογεγραμμένο πιστοποιητικό.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Ενεργοποιήστε εάν το Signal συνεχίσει να αναζητά εισερχόμενες συνομιλίες.';

  @override
  String get turnTaking => 'στροφή παίρνοντας';

  @override
  String get turnTakingModel => 'Μοντέλο στροφής';

  @override
  String get turnTakingOff => 'Απενεργοποίηση';

  @override
  String get turnThisOffToKeepThis =>
      'Απενεργοποιήστε αυτήν την επιλογή για να διατηρήσετε αυτόν τον παράγοντα εντελώς ξεχωριστό από άλλους πράκτορες.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Απενεργοποιήθηκε από το $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Απενεργοποιήθηκε από τον $arg1, ο οποίος διαχειρίζεται αυτόν τον λογαριασμό. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Απενεργοποιήθηκε για εσάς από το $arg1 — μόνο αυτοί μπορούν να το αλλάξουν';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Απενεργοποιήθηκε για εσάς, οπότε δεν μπορείτε να το παραδώσετε';

  @override
  String get twitchChatOverIrc => 'Twitch chat μέσω IRC';

  @override
  String get twoFactorAuthentication => 'Έλεγχος ταυτότητας δύο παραγόντων';

  @override
  String get twoFactorChallengeExpired => 'Η πρόκληση δύο παραγόντων έληξε';

  @override
  String get twoFactorCode => 'κωδικός δύο παραγόντων';

  @override
  String get twoFactorSignInCompletedBut =>
      'Η σύνδεση δύο παραγόντων ολοκληρώθηκε, αλλά το NeoAgent δεν μπόρεσε να διατηρήσει την περίοδο λειτουργίας του προγράμματος περιήγησης. Παρακαλούμε συνδεθείτε ξανά.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Σύνδεση σε δύο βήματα (μόνο εάν είναι ενεργοποιημένη)';

  @override
  String get type => 'Τύπος';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Πληκτρολογήστε $arg1 για επιβεβαίωση';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'κείμενο τύπου δεν υποστηρίζεται σε αυτήν την πλατφόρμα.';

  @override
  String get typedInTheBrowser => 'Πληκτρολογήθηκε στο πρόγραμμα περιήγησης';

  @override
  String get typedText => 'Δακτυλογραφημένο κείμενο';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'δεν είναι δυνατός ο εντοπισμός ενός χρόνου εκτέλεσης java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Δεν είναι δυνατό το άνοιγμα των ρυθμίσεων ώρας σε αυτήν την έκδοση.';

  @override
  String get unableToOpenWiFiSettings =>
      'Δεν είναι δυνατό το άνοιγμα των ρυθμίσεων Wi-Fi σε αυτήν την έκδοση.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Δεν είναι δυνατή η διατήρηση της επιλεγμένης οθόνης επιφάνειας εργασίας.';

  @override
  String get unclearWhoItWasFor => 'Δεν είναι σαφές για ποιον ήταν';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'αναίρεση. Πληκτρολογήστε το όνομα χρήστη σας για επιβεβαίωση.';

  @override
  String get unknownAccount => 'Άγνωστος λογαριασμός';

  @override
  String get unknownAgent => 'Άγνωστος πράκτορας';

  @override
  String get unknownBrowser => 'Άγνωστο πρόγραμμα περιήγησης';

  @override
  String get unknownDevice => 'Άγνωστη συσκευή';

  @override
  String get unknownError => 'άγνωστο σφάλμα';

  @override
  String get unknownLocalComputerPermission =>
      'Άγνωστη άδεια τοπικού υπολογιστή.';

  @override
  String get unknownLocation => 'Άγνωστη τοποθεσία';

  @override
  String get unknownPublishTime => 'Άγνωστος χρόνος δημοσίευσης';

  @override
  String get unknownSize => 'Άγνωστο μέγεθος';

  @override
  String get unlink => 'Αποσύνδεση';

  @override
  String get unreadOnly => 'Μόνο μη αναγνωσμένα';

  @override
  String get unsavedChanges => 'Μη αποθηκευμένες αλλαγές';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Μη υποστηριζόμενη συνοδευτική εντολή επιφάνειας εργασίας: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Μη υποστηριζόμενη μέθοδος: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Ασυνήθιστες ειδοποιήσεις σύνδεσης';

  @override
  String updateArg1(Object? arg1) {
    return 'Ενημέρωση $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Ενημερώστε τις καταχωρήσεις βασικής μνήμης από την εισαγωγή.';

  @override
  String get updateNow => 'Ενημέρωση τώρα';

  @override
  String get updateReady => 'Έτοιμη η ενημέρωση';

  @override
  String get updateSetup => 'Ενημέρωση εγκατάστασης';

  @override
  String get updateTheAccessListToAllow =>
      'Ενημερώστε τη λίστα πρόσβασης για να επιτρέψετε τις απαντήσεις.';

  @override
  String get updateTheServer => 'Ενημέρωση του διακομιστή;';

  @override
  String get updateTheServer2 => 'Ενημερώστε τον διακομιστή';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Ενημερώστε τη ζώνη ώρας αυτόματα από τη συσκευή που χρησιμοποιείτε.';

  @override
  String updatedArg1(Object? arg1) {
    return 'ενημερώθηκε το $arg1';
  }

  @override
  String get updates => 'Ενημερώσεις';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Οι ενημερώσεις δεν έχουν ρυθμιστεί για αυτήν την έκδοση.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'ενημερώσεις, επομένως η αυτόματη ενημέρωση και οι αλλαγές καναλιών είναι απενεργοποιημένες εδώ.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'αναβάθμιση ενημέρωση τώρα κυκλοφορήσει το κανάλι σταθερή beta';

  @override
  String get usageAnalytics => 'Αναλυτικά στοιχεία χρήσης';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Σήματα χρήσης και υγείας που βοηθούν στην εξήγηση της τρέχουσας συμπεριφοράς χρόνου εκτέλεσης χωρίς να ψάξετε πρώτα τα αρχεία καταγραφής.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Επαναφέρεται πλήρως η χρήση στο $arg1';
  }

  @override
  String get usageLeaderboard => 'leaderboard χρήσης';

  @override
  String get usageLimits => 'Χρήση & Όρια';

  @override
  String get usageLimits2 => 'Χρήση και όρια';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Χρησιμοποιήστε 8+ χαρακτήρες. Οι μεγαλύτερες φράσεις πρόσβασης λειτουργούν καλά.';

  @override
  String get useADateAndTimeFor =>
      'Χρησιμοποιήστε μια ημερομηνία και ώρα, για παράδειγμα 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Χρησιμοποιήστε όνομα, αριθμό τηλεφώνου ή αναγνωριστικό συνομιλίας.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Χρησιμοποιήστε μια διεύθυνση URL NeoRecall στην οποία μπορεί να προσεγγίσει ο διακομιστής NeoAgent. Το PUBLIC_URL του NeoAgent πρέπει επίσης να είναι προσβάσιμο από αυτό το πρόγραμμα περιήγησης για την επιστροφή κλήσης του OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Χρησιμοποιήστε έναν νέο κωδικό πρόσβασης με τουλάχιστον 8 χαρακτήρες.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Χρησιμοποιήστε μια διεύθυνση URL Nextcloud στην οποία μπορεί να φτάσει ο διακομιστής NeoAgent, για παράδειγμα https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Χρησιμοποιήστε έναν κωδικό πρόσβασης με τουλάχιστον 8 χαρακτήρες.';

  @override
  String get useASecureConnectionTls => 'Χρήση ασφαλούς σύνδεσης (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Χρησιμοποιήστε μια εφαρμογή ελέγχου ταυτότητας όπως Authy, 1Password ή Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Χρησιμοποιήστε τουλάχιστον 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Μέγιστη μνήμη ανά υπολογιστή (MB)';

  @override
  String get maxVcpusPerComputer => 'Μέγιστη vCPU ανά υπολογιστή';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Τουλάχιστον $arg1. Οι υπολογιστές γίνονται λιγότεροι όταν ο κεντρικός υπολογιστής είναι απασχολημένος.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Η μέγιστη μνήμη πρέπει να είναι τουλάχιστον $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters =>
      'Χρησιμοποιήστε τουλάχιστον 8 χαρακτήρες.';

  @override
  String get useDefault => 'Χρήση προεπιλογής';

  @override
  String get useDefaultChannel => 'Χρησιμοποιήστε το προεπιλεγμένο κανάλι';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Χρήση προεπιλογής (NeoAgent Workspace)';

  @override
  String get useFor => 'Χρήση για';

  @override
  String get useManualDestination => 'Χρησιμοποιήστε μη αυτόματο προορισμό';

  @override
  String get useOrDoTheSameFor =>
      'χρησιμοποιήστε ή κάντε το ίδιο για τους συμπαίκτες σας.';

  @override
  String get usePerCategorySettingsBelow =>
      'Χρησιμοποιήστε τις παρακάτω ρυθμίσεις ανά κατηγορία.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Χρήση προεπιλεγμένων ρυθμίσεων ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Χρησιμοποιήστε το διακομιστή σε αυτόν τον υπολογιστή';

  @override
  String get useTheseForContextIfA =>
      'Χρησιμοποιήστε αυτά για το πλαίσιο. Εάν ένα τοπικό URI δεν είναι άμεσα προσβάσιμο από τον διακομιστή, ζητήστε μου να παράσχω το αρχείο μέσω ενός προσβάσιμου χώρου εργασίας.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Χρησιμοποιήστε το για πράκτορες ενορχηστρωτών. Αφήστε μακριά για μεμονωμένα ρομπότ εργασίας που θα πρέπει να ολοκληρώσουν τα ίδια τα άμεσα μηνύματα.';

  @override
  String get useTlsFromTheStartOf =>
      'Χρησιμοποιήστε το TLS από την αρχή της σύνδεσης, συνήθως στη θύρα 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Χρησιμοποιήστε το δικό σας κλειδί API για έναν πάροχο ή συνδέστε ένα προσαρμοσμένο ';

  @override
  String get usedByEveryAccountOnThis =>
      'Χρησιμοποιείται από κάθε λογαριασμό σε αυτόν τον διακομιστή που δεν έχει κλειδί ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Χρησιμοποιείται για την επαλήθευση ότι τα εισερχόμενα συμβάντα Slack είναι γνήσια.';

  @override
  String get userSummary => 'Περίληψη χρήστη';

  @override
  String get username => 'Όνομα χρήστη';

  @override
  String get usernameOrEmail => 'Όνομα χρήστη ή email';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'χρήστες άτομα αναζήτηση email όνομα χρήστη σήμα διαχειριστή διαχειριζόμενη ομάδα';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Χρησιμοποιεί το μοντέλο συνομιλίας που έχει διαμορφωθεί στις Ρυθμίσεις';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Χρήση του εγκατεστημένου χρόνου εκτέλεσης NeoAgent';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Συνήθως μοιάζει με το @bot:matrix.org';

  @override
  String get validEmail => 'έγκυρο email';

  @override
  String get value => 'Αξία';

  @override
  String get vaultLocked => 'Θόλος κλειδωμένος';

  @override
  String get vaultOperationFailed =>
      'Η λειτουργία του θησαυροφυλάκιου απέτυχε.';

  @override
  String get verification => 'Επαλήθευση';

  @override
  String verificationArg1(Object? arg1) {
    return 'Επαλήθευση: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'επαλήθευση: $arg1';
  }

  @override
  String get verificationCompleted => 'Ολοκληρώθηκε η επαλήθευση.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Κατάσταση επαλήθευσης: $arg1';
  }

  @override
  String get verifiedTheResult => 'Επαληθεύτηκε το αποτέλεσμα';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Επαλήθευση του χρόνου εκτέλεσης λήψης';

  @override
  String get versionAndUptime => 'Έκδοση και χρόνος λειτουργίας';

  @override
  String versionArg1(Object? arg1) {
    return 'Έκδοση $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Η έκδοση $arg1 είναι εγκατεστημένη, αλλά το $arg2 εξακολουθεί να εκτελείται.';
  }

  @override
  String get videoLinks => 'Σύνδεσμοι βίντεο';

  @override
  String get viewDesktop => 'Προβολή επιφάνειας εργασίας';

  @override
  String get viewLastRun => 'Προβολή τελευταίας εκτέλεσης';

  @override
  String get viewLogs => 'Προβολή αρχείων καταγραφής';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'vm μνήμη εικόνων cpu qemu runtime';

  @override
  String get voice => 'Φωνή';

  @override
  String get voiceAssistant => 'Βοηθός φωνής';

  @override
  String get voiceCall => 'ΦΩΝΗΤΙΚΗ ΚΛΗΣΗ';

  @override
  String get voiceCall2 => 'Φωνητική κλήση';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'φωνητική κλήση gpt-live gemini ζωντανό μοντέλο ομιλίας σε πραγματικό χρόνο';

  @override
  String get voiceCallsRunOnALive =>
      'Οι φωνητικές κλήσεις εκτελούνται σε ένα ζωντανό μοντέλο ομιλίας σε ομιλία με την ίδια προσωπικότητα, μνήμη και ιστορικό συνομιλίας με το NeoAgent. Απαντά αμέσως και δίνει πραγματική δουλειά στον κανονικό πράκτορα, ο οποίος συνεχίζει να τρέχει στο παρασκήνιο.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'Πλήκτρο api μεταγραφής ομιλίας φωνητικής νότας';

  @override
  String get voiceNotesAndDictation => 'Φωνητικές νότες και υπαγόρευση';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Η αναπαραγωγή φωνής δεν είναι διαθέσιμη σε αυτήν τη συσκευή.';

  @override
  String get voiceReplyModel => 'Μοντέλο φωνητικής απάντησης';

  @override
  String get waitingForApproval => 'Αναμονή για έγκριση: ';

  @override
  String get waitingForCode => 'Αναμονή για κωδικό';

  @override
  String get waitingForInput => 'Αναμονή για εισαγωγή';

  @override
  String get waitingForServerOrFlutterLog =>
      'Αναμονή για έξοδο καταγραφής διακομιστή ή Flutter…';

  @override
  String get waitingForTaskEvents => 'Αναμονή για συμβάντα εργασιών...';

  @override
  String get waitingForYou => 'σε περιμένει';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Ήθελα μια απάντηση από τον $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Θέλει να μιλήσει μαζί σας · ${arg1}s';
  }

  @override
  String get weak => 'Αδύναμος';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Καιρός, ημερολόγιο και προτεραιότητες πριν ξεκινήσει η μέρα σας.';

  @override
  String get weatherEvent => 'Καιρική εκδήλωση';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'πρόγραμμα περιήγησης στο Web';

  @override
  String get webSearchApiKey => 'κλειδί api αναζήτησης ιστού';

  @override
  String get webhookOrRestChannelPosting => 'Ανάρτηση καναλιού Webhook ή REST';

  @override
  String get webhookSecret => 'Webhook μυστικό';

  @override
  String get webhookUrlCopied => 'Η διεύθυνση URL του Webhook αντιγράφηκε';

  @override
  String get weekdays => 'Καθημερινές';

  @override
  String get weekdays0730 => 'Καθημερινές · 07:30';

  @override
  String get weekdays1800 => 'Καθημερινές · 18:00';

  @override
  String get weekly => 'Εβδομαδιαία';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Εβδομαδιαίο όριο $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Εβδομαδιαίο όριο (κουπόνια)';

  @override
  String get weeklyReview => 'Εβδομαδιαία ανασκόπηση';

  @override
  String get weeklyUsage => 'Εβδομαδιαία χρήση';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Ρεκόρ βάρους $arg1';
  }

  @override
  String get welcomeToNeoagent => 'ΚΑΛΩΣΟΡΙΣΑΤΕ ΣΤΟ NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Καλώς ήρθατε\nστο NeoAgent';

  @override
  String get whatAreYouAdding => 'Τι προσθέτεις;';

  @override
  String get whatIsOnTomorrow => 'Τι γίνεται αύριο;';

  @override
  String get whatShouldNeoagentLearn => 'Τι πρέπει να μάθει το NeoAgent;';

  @override
  String get whatShouldWeBuild => 'Τι να φτιάξουμε;';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Αυτό που λέτε εσείς και η NeoAgent εμφανίζεται εδώ και στη συνομιλία.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Το προσωπικό μήνυμα WhatsApp ελήφθη';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Όταν επιλέγετε μόνο εγκεκριμένα, προσθέστε άτομα ή ομάδες παρακάτω.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Όπου αυτός ο αντιπρόσωπος πρέπει να στείλει απαντήσεις.';

  @override
  String get whoCanMessage => 'Ποιος μπορεί να στείλει μήνυμα';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Ποιος μπορεί να στείλει μήνυμα στο $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Ποιος μπορεί να στείλει στον $arg1 ένα μήνυμα ένας προς έναν.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Ποιος μπορεί να μιλήσει με τον $arg1 σε μια ομάδα, κανάλι ή δωμάτιο.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'ποιος διαχειρίζεται αυτόν τον λογαριασμό απενεργοποιήθηκε: ';

  @override
  String get whoManagesWhom => 'Ποιος διαχειρίζεται ποιον';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Όποιος αποδέχεται έναν σύνδεσμο γίνεται μέλος της ομάδας σας μόνο με τα εργαλεία του ';

  @override
  String get wholeGroup => 'Ολόκληρη η ομάδα';

  @override
  String get wholeGroups => 'Ολόκληρες ομάδες';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Γιατί ο $arg1 απάντησε ή έμεινε ήσυχος στις ομάδες $arg2.';
  }

  @override
  String get windowsApp => 'εφαρμογή Windows';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Λογαριασμός εργασίας';

  @override
  String get workOnAProjectWithNeoagent =>
      'Εργαστείτε σε ένα έργο με τη NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Ροή εργασίας: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Εργασία στο $arg1 στον υπολογιστή cloud. Το NeoAgent διαβάζει και επεξεργάζεται αρχεία εκεί και μπορεί να εκτελέσει εντολές και ένα πρόγραμμα περιήγησης.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Εργασία στο παρασκήνιο: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Διαμόρφωση χώρου εργασίας και ασφάλεια λογαριασμού σε ένα μέρος.';

  @override
  String get workspaceFiles => 'Αρχεία χώρου εργασίας';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Χώρος εργασίας, μοντέλα και στοιχεία ελέγχου διαγνωστικών.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Η παράκαμψη χώρου εργασίας πρέπει να είναι μια απόλυτη διαδρομή.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Έγραψε το $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'Σφάλμα αιτήματος xmlhttp';

  @override
  String get yesterday => 'Χθες';

  @override
  String get youAreInControl => 'Έχετε τον έλεγχο';

  @override
  String get youCanFollowAlongOnThe =>
      'Μπορείτε να ακολουθήσετε στην επιφάνεια εργασίας.';

  @override
  String get youCanLeaveATeamAt =>
      'Μπορείτε να φύγετε από μια ομάδα ανά πάσα στιγμή. ισχύουν ξανά οι δικές σας ρυθμίσεις.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Μπορείτε να φύγετε ανά πάσα στιγμή από τη σελίδα της ομάδας.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Εσείς αποφασίζετε ποια εργαλεία μπορεί να χρησιμοποιήσει ο αντιπρόσωπός σας, στις Ρυθμίσεις › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Δεν διαχειρίζεσαι κανέναν ακόμα. Δημιουργήστε έναν σύνδεσμο πρόσκλησης παρακάτω και ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Έχετε μη αποθηκευμένες ρυθμίσεις. Τι θα ήθελες να κάνεις;';

  @override
  String get youReOnYourOwnYou =>
      'Είστε μόνοι σας: εσείς αποφασίζετε ποια εργαλεία μπορεί να χρησιμοποιήσει ο αντιπρόσωπός σας. Αν ';

  @override
  String get yourAccountAndUsageOnA =>
      'τον λογαριασμό σας -- και τη χρήση σε ένα μοντέλο που υποστηρίζεται από το δικό σας κλειδί ';

  @override
  String get yourAccountHasBeenDeleted => 'Ο λογαριασμός σας έχει διαγραφεί.';

  @override
  String get yourAgentWillBeAllowed => 'Ο αντιπρόσωπός σας θα επιτρέπεται:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Οι εφαρμογές και τα αρχεία σας αποθηκεύονται.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Οι εφαρμογές και τα αρχεία σας παραμένουν αποθηκευμένα.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Το κλειδί σας $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Επίπεδο βοηθού σας για λήψη, πλαίσιο και δράση.';

  @override
  String get yourComputerIsAsleep => 'Ο υπολογιστής σας κοιμάται';

  @override
  String get yourComputerIsOff => 'Ο υπολογιστής σας είναι απενεργοποιημένος';

  @override
  String get yourComputerIsReady => 'Ο υπολογιστής σας είναι έτοιμος';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Ο τρέχων κωδικός πρόσβασής σας είναι λανθασμένος.';

  @override
  String get yourData => 'Τα δεδομένα σας';

  @override
  String get yourDataExportWasCopiedTo =>
      'Η εξαγωγή των δεδομένων σας αντιγράφηκε στο πρόχειρο.';

  @override
  String get yourDesktopIsReady => 'Η επιφάνεια εργασίας σας είναι έτοιμη';

  @override
  String get yourLinuxComputer => 'Ο υπολογιστής σας Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Η τοποθεσία σας δεν παρακολουθείται ποτέ συνεχώς ούτε αποθηκεύεται στους διακομιστές μας. Το χρησιμοποιούμε μόνο τοπικά για να ελέγξουμε τις ενεργές εργασίες σας.';

  @override
  String get yourManager => 'ο διευθυντής σας';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Η διεύθυνση URL του ιστότοπού σας Mattermost, εάν χρησιμοποιείτε το REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Η συνεδρία σας έληξε ή δεν διατηρήθηκε από το πρόγραμμα περιήγησης. Παρακαλούμε συνδεθείτε ξανά.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Η συνεδρία σας έληξε. Παρακαλούμε συνδεθείτε ξανά.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Το όνομα χρήστη ή ο κωδικός πρόσβασής σας είναι λανθασμένο.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Επισκόπηση';

  @override
  String get sectionDiagnostics => 'Διαγνωστικά';

  @override
  String get sectionVolume => 'Όγκος';

  @override
  String get sectionSession => 'συνεδρία';

  @override
  String get sectionDeliverable => 'Παραδοτέο';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Ο τοπικός χρόνος εκτέλεσης δεν έχει γράψει ακόμα αρχείο καταγραφής.';

  @override
  String get thisComputer => 'Αυτός ο υπολογιστής';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Η Beta εγκαθιστά το νεότερο backend προέκδοσης. Αναμένετε τραχιές άκρες.';

  @override
  String get copiedFinalResponse => 'Αντιγράφηκε η τελική απάντηση';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Η τελική απόκριση εμφανίζεται εδώ όταν τελειώσει η εκτέλεση.';

  @override
  String get waitingForTheFirstStep => 'Αναμονή για το πρώτο βήμα…';

  @override
  String get loadingPrompt => 'Φόρτωση προτροπής…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Δεν καταγράφηκε τελική απάντηση για αυτήν την εκτέλεση.';

  @override
  String get readyToSignIn => 'Έτοιμοι για είσοδο';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Μεταβείτε σε \"Προεπιλογή\" ή \"Να ζητείται πάντα\" για να ενεργοποιήσετε ξανά τους ελέγχους έγκρισης.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Στείλτε μια ενημέρωση του συστήματος διεύθυνσης ή μια επόμενη σημείωση για την τρέχουσα εκτέλεση...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Δεν υπάρχει σύνδεση δικτύου. Το NeoAgent θα επανασυνδεθεί όταν η συσκευή συνδεθεί ξανά.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Εφαρμόστηκε η πιο πρόσφατη ενημέρωση συστήματος διεύθυνσης στην τρέχουσα διαδρομή.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Προετοιμασία της ιδιωτικής φωνητικής συνεδρίας…';

  @override
  String get preparingYourComputer => 'Προετοιμασία του υπολογιστή σας';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'Το NeoAgent κατεβάζει και προετοιμάζει το ασφαλές σύστημα Linux. Αυτό συμβαίνει μόνο την πρώτη φορά.';

  @override
  String get moreFreeSpaceIsNeeded => 'Απαιτείται περισσότερος ελεύθερος χώρος';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Ελευθερώστε λίγο χώρο στο δίσκο στον κεντρικό υπολογιστή NeoAgent και δοκιμάστε ξανά. Τα υπάρχοντα δεδομένα υπολογιστή σας είναι ασφαλή.';

  @override
  String get androidReady => 'Android έτοιμο';

  @override
  String get startingAndroid2 => 'Έναρξη Android…';

  @override
  String get androidStopped => 'Το Android σταμάτησε';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Η πρώτη εκκίνηση κατεβάζει το Android SDK και την εικόνα συστήματος, κάτι που μπορεί να διαρκέσει αρκετά λεπτά.';

  @override
  String get androidIsStopped => 'Το Android έχει σταματήσει';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Ξεκινήστε το διαχειριζόμενο περιβάλλον Android όταν το χρειάζεστε.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Αφήστε το NeoAgent να λειτουργήσει σε αυτόν τον υπολογιστή';

  @override
  String get firstTimeSetupIsInProgress =>
      'Η εγκατάσταση για πρώτη φορά βρίσκεται σε εξέλιξη.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'Το NeoAgent μπορεί να χρησιμοποιήσει την πρόσβαση που επιτρέπετε.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Ελευθερώστε λίγο χώρο αποθήκευσης κεντρικού υπολογιστή και δοκιμάστε ξανά.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Ξεκινήστε όταν θέλετε το NeoAgent να σας βοηθήσει εδώ.';

  @override
  String get systemPermissionMissing => 'Λείπει η άδεια συστήματος';

  @override
  String get connectingThisDevice => 'Σύνδεση αυτής της συσκευής';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Η ασφαλής τοπική σύνδεση δημιουργείται.';

  @override
  String get recordingYourDemonstration => 'Καταγραφή της επίδειξής σας';

  @override
  String get noErrorsInTheRecentLog =>
      'Δεν υπάρχουν σφάλματα στο πρόσφατο αρχείο καταγραφής.';

  @override
  String get loadingAccounts => 'Φόρτωση λογαριασμών…';

  @override
  String get neverSignedIn => 'Δεν συνδέθηκε ποτέ';

  @override
  String get emptyUsesTheServerDefault =>
      'Το Empty χρησιμοποιεί την προεπιλογή του διακομιστή.';

  @override
  String get followTheSelectedSession => 'Ακολουθήστε την επιλεγμένη συνεδρία';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Επιθεωρεί μόνο η λειτουργία σχεδίου. Μεταβείτε στη λειτουργία Agent για να επιτρέψετε στο NeoAgent να επεξεργάζεται αρχεία.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Απαιτείται για να προσθέσετε ή να αλλάξετε τη διεύθυνση ηλεκτρονικού ταχυδρομείου του λογαριασμού σας.';

  @override
  String get confirmNewPassword => 'Επιβεβαίωση νέου κωδικού πρόσβασης';

  @override
  String get passwordChanged => 'Ο κωδικός άλλαξε.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Αυτό το αίτημα έχει ήδη χρησιμοποιηθεί.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Αυτό το αίτημα έχει λήξει. Ζητήστε από την άλλη συσκευή να δημιουργήσει έναν νέο κωδικό.';

  @override
  String get startQuickstart => 'Ξεκινήστε τη γρήγορη εκκίνηση';

  @override
  String get createYourAccount => 'Δημιουργήστε τον λογαριασμό σας';

  @override
  String get showWorkAsSummaries => 'Εμφάνιση εργασίας ως περιλήψεις';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokens που χρησιμοποιούνται από την τελευταία εκτέλεση';

  @override
  String get listedTheWorkspaceRoot => 'Αναφέρθηκε η ρίζα του χώρου εργασίας';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Δεν υπάρχουν ακόμη διαθέσιμες επίσημες ενσωματώσεις.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Δεν έχουν διαμορφωθεί ακόμη διακομιστές MCP. Προσθέστε ένα για να αποκαλύψετε τα εργαλεία του.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Προσθέστε έναν διακομιστή MCP ή εγκαταστήστε μια δεξιότητα για να ξεκινήσετε.';

  @override
  String get setUp => 'Ρύθμιση';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Αφήστε το κενό για να διατηρήσετε την αποθηκευμένη τιμή';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Αυτό καταργεί τη διεύθυνση για κάθε λογαριασμό σε αυτόν τον διακομιστή.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Απλά μιλήστε. Μπορείτε να διακόψετε οποιαδήποτε στιγμή. Πατήστε για σίγαση.';

  @override
  String get tapAgainWhenYouAreDone => 'Πατήστε ξανά όταν τελειώσετε.';

  @override
  String get workingOnATaskInTheBackground =>
      'Εργασία σε μια εργασία στο παρασκήνιο.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Ομιλία σε ομιλία με την ίδια μνήμη, εργαλεία και ιστορικό συνομιλιών με το NeoAgent.';

  @override
  String get checkLink => 'Ελέγξτε τον σύνδεσμο';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Δεν θα επιτραπεί στον αντιπρόσωπό σας κανένα από τα ελεγχόμενα εργαλεία.';

  @override
  String get notYoursToChange => 'Δεν είναι δικό σου για να αλλάξεις';

  @override
  String get setByYou => 'Ορίστηκε από εσάς';

  @override
  String get noTools => 'Χωρίς εργαλεία';

  @override
  String get untitledLink => 'Σύνδεσμος χωρίς τίτλο';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Σταματά να λειτουργεί αφού το εξαργυρώσει ένα άτομο.';

  @override
  String get theOperator => 'Ο χειριστής';

  @override
  String get smartSelectorOn => 'Έξυπνος επιλογέας ενεργοποιημένος';

  @override
  String get startASessionToBegin => 'Ξεκινήστε μια συνεδρία για να ξεκινήσετε';

  @override
  String get steerTheActiveRun => 'Κατευθύνετε το ενεργό τρέξιμο…';

  @override
  String get describeWhatToPlan => 'Περιγράψτε τι να σχεδιάσετε…';

  @override
  String get stopDictation => 'Σταματήστε την υπαγόρευση';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Τα μηνύματα κατευθύνουν την τρέχουσα εκτέλεση · ⌘↵ αποστολή · ⌘. σταματήστε';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Επιθεωρεί μόνο η λειτουργία σχεδίου. τίποτα δεν αλλάζει μέχρι να εφαρμόσετε · ⌘↵ αποστολή';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Ο παράγοντας επεξεργάζεται τον χώρο εργασίας. Σχεδιάστε μόνο επιθεωρήσεις.';

  @override
  String get defaultModel => 'Προεπιλεγμένο μοντέλο';

  @override
  String get openingScanner => 'Άνοιγμα σαρωτή...';

  @override
  String get theAgentCanUseThisSkill =>
      'Ο πράκτορας μπορεί να χρησιμοποιήσει αυτήν την ικανότητα.';

  @override
  String get allSelected => 'Όλα Επιλεγμένα';

  @override
  String get addCoreMemoryEntry => 'Προσθήκη καταχώρησης βασικής μνήμης';

  @override
  String get channelId => 'Αναγνωριστικό καναλιού';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Οι εργασίες που έχουν δημιουργηθεί με AI και οι απροσδιόριστες εργασίες χρησιμοποιούν την τρέχουσα προεπιλογή.';

  @override
  String get waitingForRunEvents => 'Αναμονή για τρέχοντα συμβάντα...';

  @override
  String get hideSteps => 'Απόκρυψη βημάτων';

  @override
  String get commitTheActiveLiveCapture => 'Κάντε την ενεργή ζωντανή λήψη';

  @override
  String get stopCaptureAndSubmit => 'Διακοπή λήψης και υποβολή';

  @override
  String get clickTheMicToStartSpeaking =>
      'Κάντε κλικ στο μικρόφωνο για να αρχίσετε να μιλάτε';

  @override
  String get connectACustomEndpoint =>
      'Συνδέστε ένα προσαρμοσμένο τελικό σημείο';

  @override
  String get hostedProvider => 'φιλοξενούμενος πάροχος.';

  @override
  String get muted => ' • σίγαση';

  @override
  String get addWhoCanMessage => 'Προσθέστε ποιος μπορεί να στείλει μήνυμα';

  @override
  String get joinsGroupConversations => 'Συμμετέχει σε ομαδικές συνομιλίες';

  @override
  String get label1PersonOrGroupAdded => 'Προστέθηκε 1 άτομο ή ομάδα';

  @override
  String get inProgress => 'Σε εξέλιξη';

  @override
  String get waitingForUpdateJobOutput =>
      'Αναμονή για την έξοδο εργασίας ενημέρωσης…';

  @override
  String get taskTrigger => 'Έναρξη εργασίας';

  @override
  String get bearerToken => 'Κουπόνι φορέα';

  @override
  String get bearerToken2 => 'Διακριτικό Φορέα';

  @override
  String get notRecorded => 'Δεν έχει καταγραφεί';

  @override
  String get sessionCookie => 'Cookie συνεδρίας';

  @override
  String get neverUsed => 'Δεν χρησιμοποιήθηκε ποτέ';

  @override
  String get linkedRecently => 'Συνδέθηκε πρόσφατα';

  @override
  String get notUsedYet => 'Δεν έχει χρησιμοποιηθεί ακόμα';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Ένας ή περισσότεροι λογαριασμοί έληξαν. Επανασυνδεθείτε για να επαναφέρετε την πρόσβαση. Εάν αυτό συνεχίσει να συμβαίνει, η εφαρμογή σας Google Cloud OAuth μπορεί να βρίσκεται σε λειτουργία δοκιμής — δημοσιεύστε την στο Production στο Google Cloud Console για να λάβετε μάρκες μεγάλης διάρκειας.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Το Vault είναι συνδεδεμένο και διαθέσιμο μετά την επανεκκίνηση';

  @override
  String get vaultConnectedForThisSession =>
      'Το Vault συνδέθηκε για αυτήν την περίοδο σύνδεσης';

  @override
  String get connectAnotherAccount => 'Σύνδεση άλλου λογαριασμού';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Αντικατάσταση επικόλλησης Long-Lived Access Token';

  @override
  String get updateInstance => 'Ενημέρωση παρουσίας';

  @override
  String get pasteAReplacementToken =>
      'Επικολλήστε ένα διακριτικό αντικατάστασης';

  @override
  String get replaceAccount => 'Αντικατάσταση λογαριασμού';

  @override
  String get addAccount => 'Προσθήκη λογαριασμού';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Μπορεί να αναθέσει σε οποιονδήποτε πράκτορα παραλήπτη';

  @override
  String get canReceiveDelegatedTasks2 =>
      'μπορεί να λαμβάνει εργασίες που έχουν ανατεθεί';

  @override
  String get noSyncYet => 'Δεν υπάρχει συγχρονισμός ακόμα';

  @override
  String get noNewData => 'Δεν υπάρχουν νέα δεδομένα';

  @override
  String get syncOnceToSeedYourBackend =>
      'Συγχρονίστε μία φορά για να εμφανίσετε το backend σας.';

  @override
  String get lastWindowEndIsUnknown =>
      'Το τελευταίο τέλος παραθύρου είναι άγνωστο.';

  @override
  String get lastNonEmptySync => 'Τελευταίος μη κενός συγχρονισμός';

  @override
  String get stopTranscribe => 'Διακοπή & μεταγραφή';

  @override
  String get steeringMode => 'Λειτουργία διεύθυνσης';

  @override
  String get noMessageText => 'Χωρίς κείμενο μηνύματος';

  @override
  String get reconnectingToServer => 'Επανασύνδεση στον διακομιστή…';

  @override
  String get signingIn => 'Σύνδεση...';

  @override
  String get noGroupsFoundYet => 'Δεν βρέθηκαν ακόμη ομάδες';

  @override
  String get onForNewGroupsOnly => 'Ενεργό μόνο για νέες ομάδες';

  @override
  String get noGroupsInThisCategory =>
      'Δεν υπάρχουν ομάδες σε αυτήν την κατηγορία';

  @override
  String get groupOrChannel => 'Ομάδα ή κανάλι';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Οι σημειώσεις που γράφετε στον εαυτό σας ξεκινούν ένα τρέξιμο και οι απαντήσεις καταλήγουν στην ίδια συνομιλία. Η λίστα επιτρεπόμενων δεν ισχύει εδώ.';

  @override
  String get needToReply => 'Χρειάζεται απάντηση';

  @override
  String get enter2faCode => 'Εισαγάγετε τον κωδικό 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Ανοίξτε την εφαρμογή ελέγχου ταυτότητας και εισαγάγετε τον τρέχοντα κωδικό NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Έχετε ήδη λογαριασμό; Συνδεθείτε';

  @override
  String get serverOnThisComputer => 'Διακομιστής σε αυτόν τον υπολογιστή';

  @override
  String get showQrCode => 'Εμφάνιση κωδικού QR';

  @override
  String get createAnotherNeoagentAccount =>
      'Δημιουργήστε έναν άλλο λογαριασμό NeoAgent.';

  @override
  String get canCoordinateDelegatedWork =>
      'Μπορεί να συντονίσει τις εργασίες που έχουν ανατεθεί';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Δεν ήταν δυνατή η εξαγωγή του αρχείου χρόνου εκτέλεσης NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Δεν ήταν δυνατή η ανάγνωση του αρχείου χρόνου εκτέλεσης του NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Το αρχείο χρόνου εκτέλεσης NeoAgent περιέχει μια μη ασφαλή διαδρομή.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Το αρχείο χρόνου εκτέλεσης του NeoAgent περιέχει έναν μη ασφαλή σύνδεσμο.';

  @override
  String get installingAppPackageOnThePhone =>
      'Εγκατάσταση πακέτου εφαρμογών στο τηλέφωνο...';

  @override
  String get dragAndDropAApkOrApks =>
      'Σύρετε και αποθέστε ένα αρχείο .apk ή .apks εδώ ή κάντε κλικ για περιήγηση.';

  @override
  String get releaseToInstallThisPackage =>
      'Απελευθερώστε για να εγκαταστήσετε αυτό το πακέτο';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Δεν ήταν δυνατή η χρήση του κλειδιού ασφαλείας.';

  @override
  String get connecting => 'Σύνδεση…';

  @override
  String get changes => 'Αλλαγές';

  @override
  String get runtimeReady => 'Έτοιμος ο χρόνος εκτέλεσης';

  @override
  String get saving => 'Αποθήκευση...';

  @override
  String get earlier => 'Νωρίτερα';

  @override
  String get monthJan => 'Ιαν';

  @override
  String get monthFeb => 'Φεβ';

  @override
  String get monthMar => 'Μαρ';

  @override
  String get monthApr => 'Απρ';

  @override
  String get monthMay => 'Μάιος';

  @override
  String get monthJun => 'Ιούν';

  @override
  String get monthJul => 'Ιούλ';

  @override
  String get monthAug => 'Αύγ';

  @override
  String get monthSep => 'Σεπτ';

  @override
  String get monthOct => 'Οκτ';

  @override
  String get monthNov => 'Νοε';

  @override
  String get monthDec => 'Δεκ';

  @override
  String get steeringWord => 'τιμόνι';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Αυτό αλλάζει το backend από το κανάλι $arg1 στο κανάλι $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Εισήχθησαν cookies $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s πριν';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Τιμόνι σε σειρά: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Η εφαρμογή Ιστού δεν μπόρεσε να φτάσει στο σύστημα υποστήριξης NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Το πρόγραμμα περιήγησης απέκλεισε ένα απαιτούμενο αίτημα λόγω της Πολιτικής ασφάλειας περιεχομένου.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 από 4 επιτρέπονται';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Εκτελέστε την εργασία όπως θα κάνατε συνήθως.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Αλλαγές · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Αυτή η συσκευή · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Το όριο έφτασε $arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Οι κωδικοί ανάκτησης $arg1 εξακολουθούν να είναι διαθέσιμοι.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Κλειδί ασφαλείας $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Τρέχουσα συνεδρία';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nΤελευταία χρήση: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Εργασία σε $arg1 σε αυτήν τη συσκευή. Το NeoAgent διαβάζει και επεξεργάζεται απευθείας το φάκελο και μπορεί να εκτελεί εντολές, να ανοίγει εφαρμογές και να χρησιμοποιεί την οθόνη.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Δούλεψε για το $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Επιτρέπεται από $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Οι σύνδεσμοι πρόσκλησης $arg1 από το $arg2 ανακλήθηκαν';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Προσθέστε τα άτομα και τις ομάδες με τις οποίες πρέπει να μιλήσει ο $arg1';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Προσθέστε τα άτομα και τις ομάδες με τις οποίες επιτρέπεται να μιλήσει ο $arg1.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Όπου ακούει το $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return 'Το $arg1 παρακολουθεί αυτά τα μέρη για αναφορές. Οποιοσδήποτε μπορεί να δημοσιεύσει εδώ, επομένως οι χρήστες εξακολουθούν να χρειάζονται τη δική τους έγκριση παρακάτω.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Αυτά τα άτομα μπορούν να ρωτήσουν το $arg1 όπου κι αν του επισημάνουν. Οι ρόλοι μετρούν μόνο στις θέσεις που αναφέρονται παραπάνω.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Μόνο όταν έχει επισημανθεί το $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Ενεργό για όλες τις ομάδες $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return 'Το $arg1 εξακολουθεί να ακούει μόνο άτομα και ομάδες που έχετε ήδη εγκρίνει. Αυτό απλώς επιτρέπει στον $arg1 να συμμετέχει σε μια συνηθισμένη συνομιλία εκεί, όχι μόνο σε ετικέτες και απαντήσεις.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return 'Το $arg1 εξακολουθεί να ακούει μόνο άτομα και ομάδες που έχετε ήδη εγκρίνει. Αυτό απλώς επιλέγει σε ποια από αυτές τις ομάδες πρέπει να ενταχθεί.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Εάν κάποιος προσθέσει ετικέτα στο $arg1 ή απαντήσει, το $arg1 απαντά πάντα. Ενεργοποιήστε το εάν το $arg1 πρέπει επίσης να χτυπήσει σε μια συνηθισμένη ομαδική συνομιλία.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Οι νέες ομάδες θα επιτρέπουν στον $arg1 να συμμετέχει σε συνηθισμένη συνομιλία με εγκεκριμένα άτομα, μέχρι να τα απενεργοποιήσετε.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Οι νέες ομάδες θα επιτρέψουν στον $arg1 να συμμετέχει στη συνηθισμένη συνομιλία μέχρι να τις απενεργοποιήσετε.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Οι νέες ομάδες παραμένουν αθόρυβες εκτός εάν κάποιο εγκεκριμένο άτομο προσθέσει ετικέτα στο $arg1, μέχρι να τις ενεργοποιήσετε.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Μόνο όταν ένα εγκεκριμένο άτομο προσθέσει ετικέτα στο $arg1, εκτός εάν ενεργοποιήσετε μια ομάδα';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Μόνο όταν επισημανθεί το $arg1, εκτός εάν ενεργοποιήσετε μια ομάδα';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return 'Οι $arg1 των ομάδων $arg2 συμμετέχουν σε μια συνηθισμένη συνομιλία με εγκεκριμένα άτομα';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Αυτό δεν εγκρίνει νέα άτομα. Οι ετικέτες και οι απαντήσεις από εγκεκριμένα άτομα λαμβάνουν πάντα απάντηση. Ενεργοποιήστε μια ομάδα εάν ο $arg1 πρέπει επίσης να συμμετάσχει σε μια συνηθισμένη συνομιλία εκεί.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Αυτό δεν εγκρίνει νέα άτομα. Ενεργοποιήστε μια ομάδα εάν ο $arg1 συμμετέχει σε συνηθισμένη συνομιλία με άτομα που έχετε ήδη εγκρίνει.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Οι ετικέτες και οι απαντήσεις λαμβάνουν πάντα απάντηση. Ενεργοποιήστε μια ομάδα εάν ο $arg1 πρέπει επίσης να συμμετάσχει σε μια συνηθισμένη συνομιλία εκεί.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return 'Ο $arg1 συμμετέχει σε συνηθισμένη συνομιλία με εγκεκριμένα άτομα';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return 'Το $arg1 μπορεί να συμμετάσχει σε συνηθισμένη συνομιλία';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return 'Το $arg1 απαντά μόνο όταν ένα εγκεκριμένο άτομο του προσθέτει ετικέτα';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Δεν χρειάζεται τίποτα επιπλέον. Συνδεθείτε για να ξεκινήσετε να χρησιμοποιείτε το $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Ανανεώνεται σε $arg1';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Εγγραφείτε στο $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Δεν υπάρχουν μνήμες συνδεδεμένες με το \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (προεπιλογή)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Υποκατάστημα: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return 'Το $arg1 συμμετέχει μόνο στις ομάδες και τα κανάλια που προσθέτετε παρακάτω.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return 'Το $arg1 απαιτείται για τον εντοπισμό δεδομένων χρόνου εκτέλεσης NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[περικομμένη προεπισκόπηση, $arg1 byte συνολικά]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[περιορισμένο αντικείμενο, $arg1 byte συνολικά]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' σε $arg1';
  }

  @override
  String get worldNews => 'Παγκόσμια Νέα';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Εκτελέστε όταν εμφανίζονται νέοι παγκόσμιοι τίτλοι. Η προτροπή σας αποφασίζει εάν θα σας ειδοποιήσει.';

  @override
  String get newsKeywordsOptional => 'Λέξεις-κλειδιά (προαιρετικά)';

  @override
  String get worldNewsSetup => 'Ρύθμιση παγκόσμιων ειδήσεων';

  @override
  String get connectWorldNewsWithGnews =>
      'Προσθέστε ένα κλειδί API GNews (δωρεάν σχέδιο διαθέσιμο στο gnews.io). Αποθηκεύεται κρυπτογραφημένο και χρησιμοποιείται για τη δημοσκόπηση των κορυφαίων πρωτοσέλιδων για ενεργοποιητές World News.';

  @override
  String get gnewsApiKey => 'Κλειδί API GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Επικόλληση αντικατάσταση κλειδιού GNews API';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Αφήστε το κλειδί κενό για να διατηρήσετε το τρέχον αποθηκευμένο κλειδί.';

  @override
  String get gnewsApiKeyIsRequired => 'Απαιτείται ένα κλειδί API GNews.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Δεν ήταν δυνατή η αποθήκευση της ρύθμισης World News.';

  @override
  String get disconnectWorldNews => 'Αποσύνδεση World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Αυτό καταργεί το αποθηκευμένο κλειδί API GNews. Οι κανόνες ετικέτας World News θα σταματήσουν να ενεργοποιούνται μέχρι να προσθέσετε ξανά ένα κλειδί.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Δεν ήταν δυνατή η αποσύνδεση του World News.';

  @override
  String get systemOneModels => 'Μοντέλα SystemOne';

  @override
  String get systemOneAuto => 'Αυτόματο';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Επιλέγει το καλύτερο διαθέσιμο μοντέλο SystemOne';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Το μοντέλο συνομιλίας λαμβάνει αυτές τις αποφάσεις';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Μοντέλα αποφάσεων που πραγματοποιούν τις κλήσεις στα παρασκήνια σε κλάσματα δευτερολέπτου: ομαδική συνομιλία και βήματα του προγράμματος περιήγησης. Το μοντέλο συνομιλίας σας εξακολουθεί να γράφει κάθε απάντηση.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Το μοντέλο SystemOne αποφασίζει πότε θα μιλήσει ενώ είναι ενεργοποιημένο. αυτό το μοντέλο είναι το εναλλακτικό.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return 'Το $arg1 σημειώθηκε από το SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'Το SystemOne σημείωσε απευθείας αυτό το μήνυμα. Κανένα γλωσσικό μοντέλο δεν έτρεξε.';

  @override
  String get systemOneUnavailable => 'Το SystemOne δεν είναι διαθέσιμο';

  @override
  String get systemOneAdminAvailability =>
      'Οι πράκτορες μοντέλων αποφάσεων μπορούν να επιλέξουν από τις Ρυθμίσεις › Μοντέλα. Ένα μοντέλο που απενεργοποιήθηκε εδώ αφήνει αυτόν τον επιλογέα και οι πράκτορες που το επέλεξαν πέφτουν στο Auto. Ενώ οποιοδήποτε μοντέλο είναι απενεργοποιημένο, τα μοντέλα SystemOne που προσθέτουν αργότερα οι πάροχοι ξεκινούν επίσης απενεργοποιημένα.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Δεν υπάρχουν ακόμη μοντέλα SystemOne. Προσθέστε ένα κλειδί TypeSafe ή OpenRouter στην περιοχή Providers ή τραβήξτε ένα μοντέλο απόφασης, όπως το ευκίνητο στο Ollama 0.35 ή μεταγενέστερο.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Κανένα μοντέλο SystemOne δεν είναι ακόμη διαθέσιμο. Προσθέστε ένα κλειδί TypeSafe ή OpenRouter στις Ρυθμίσεις › Μοντέλα › Φέρτε το δικό σας κλειδί ή τραβήξτε ένα μοντέλο απόφασης, όπως το ευκίνητο στο Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone σύστημα μίας απόφασης μοντέλα jev typeafe openrouter olama διαθεσιμότητα ενεργοποίηση απενεργοποίηση';

  @override
  String get chatModels => 'Μοντέλα συνομιλίας';

  @override
  String get disabled => 'Απενεργοποιημένο';

  @override
  String get enableShown => 'Ενεργοποίηση εμφανίζεται';

  @override
  String get disableShown => 'Απενεργοποίηση εμφανίζεται';

  @override
  String get expandAll => 'Αναπτύξτε όλα';

  @override
  String get collapseAll => 'Σύμπτυξη όλων';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 μη αποθηκευμένες αλλαγές';
  }

  @override
  String get settingsScopeAllAgents => 'Όλοι οι πράκτορες';

  @override
  String get settingsScopeAgent => 'Αυτός ο πράκτορας';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint => 'Το ίδιο παντού και όπου συνδέεστε';

  @override
  String get settingsScopeAllAgentsHint =>
      'Κοινή χρήση όλων των αντιπροσώπων σας';

  @override
  String get settingsAppliesTo => 'Ισχύει για';

  @override
  String get settingsSaving => 'Αποθήκευση…';

  @override
  String get settingsSavedAutomatically => 'Οι αλλαγές αποθηκεύονται αυτόματα';

  @override
  String get settingsSearchHint => 'Αναζήτηση όλων των ρυθμίσεων';

  @override
  String get settingsPageProfile => 'Προφίλ';

  @override
  String get settingsPageSecurity => 'Είσοδος και ασφάλεια';

  @override
  String get settingsPageUsage => 'Χρήση';

  @override
  String get settingsPagePermissions => 'Άδειες';

  @override
  String get settingsPageComputer => 'Υπολογιστής & web';

  @override
  String get settingsPageBehavior => 'Συμπεριφορά';

  @override
  String get settingsPageSystem => 'Σύστημα';

  @override
  String get settingsPagePlatforms => 'Πλατφόρμες';

  @override
  String get settingsPageProfileDescription =>
      'Το όνομα και το email σας, ένα αντίγραφο των δεδομένων σας και η αποσύνδεση.';

  @override
  String get settingsPageSecurityDescription =>
      'Κωδικός πρόσβασης, έλεγχος ταυτότητας δύο παραγόντων, κλειδιά ασφαλείας και πού είστε συνδεδεμένοι.';

  @override
  String get settingsPageUsageDescription =>
      'Τα όρια και οι συμβολικές δαπάνες σας, όλα σε ένα μέρος.';

  @override
  String get settingsPageAgentsDescription =>
      'Δημιουργήστε πράκτορες και επιλέξτε ποιος θα απαντήσει από προεπιλογή.';

  @override
  String get settingsPagePermissionsDescription =>
      'Τι μπορούν να κάνουν οι πράκτορές σας χωρίς να σας ρωτήσουν πρώτα.';

  @override
  String get settingsPageComputerDescription =>
      'Ο υπολογιστής στον οποίο εργάζονται οι πράκτορες σας και οι ιστότοποι που μπορούν να διαβάσουν ως εσάς.';

  @override
  String get settingsPageModelsDescription =>
      'Ποια μοντέλα χρησιμοποιεί αυτός ο πράκτορας και τα κλειδιά API που πληρώνουν για αυτά.';

  @override
  String get settingsPageBehaviorDescription =>
      'Πώς μιλάει αυτός ο πράκτορας και πώς διαβάζει μια ομαδική συνομιλία.';

  @override
  String get settingsPageVoiceDescription =>
      'Ζωντανές κλήσεις, υπαγόρευση και προφορικές απαντήσεις για αυτόν τον πράκτορα.';

  @override
  String get settingsPageMessagingDescription =>
      'Πού μπορούν να προσεγγίσουν οι άνθρωποι αυτόν τον πράκτορα και πώς συμπεριφέρεται στις συνομιλίες.';

  @override
  String get settingsPageGeneralDescription =>
      'Εμφάνιση, γλώσσα, ζώνη ώρας και τι κάνει αυτή η εφαρμογή στο παρασκήνιο.';

  @override
  String get settingsPageSystemDescription =>
      'Ο διακομιστής που χρησιμοποιεί αυτό το παράθυρο, αυτός σε αυτόν τον υπολογιστή και ενημερώσεις εφαρμογών.';

  @override
  String get settingsYourAgents => 'Οι πράκτορες σου';

  @override
  String get settingsChatModel => 'Μοντέλο συνομιλίας';

  @override
  String get settingsChatModelDescription => 'Απαντάει στα μηνύματά σας.';

  @override
  String get settingsSubAgentModel => 'Μοντέλο υπο-πράκτορα';

  @override
  String get settingsSubAgentModelDescription =>
      'Εκτελεί την εργασία που παραδίδεται κατά τη διάρκεια μιας εργασίας.';

  @override
  String get settingsDefaultModels => 'Προεπιλεγμένα μοντέλα';

  @override
  String get settingsDefaultModelsDescription =>
      'Χρησιμοποιείται κάθε φορά που μια συνομιλία ή μια εργασία δεν επιλέγει το δικό της μοντέλο.';

  @override
  String get settingsModelPool => 'Μοντέλο πισίνας';

  @override
  String get settingsApiKeysDescription =>
      'Χρησιμοποιήστε τα δικά σας κλειδιά ή τελικό σημείο για αυτόν τον παράγοντα. Τα κλειδιά είναι κρυπτογραφημένα και δεν εμφανίζονται ποτέ ξανά.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'μικρορύθμιση';

  @override
  String get settingsFineTuningDescription =>
      'Σπάνια χρειάζεται. Οι προεπιλογές ταιριάζουν στις περισσότερες συνομιλίες.';

  @override
  String get settingsShow => 'Εμφάνιση';

  @override
  String get settingsHide => 'Απόκρυψη';

  @override
  String get settingsMinimumContribution => 'Ελάχιστη αξία συνεισφοράς';

  @override
  String get settingsBatchWindow => 'Παράθυρο παρτίδας δωματίου';

  @override
  String get settingsBatchWindowDescription =>
      'Περιμένει τόσο πολύ για να αντιμετωπίσει τα γρήγορα μηνύματα ως μια στροφή.';

  @override
  String get settingsHandsFree => 'Hands-free';

  @override
  String get settingsHandsFreeDescription =>
      'Μιλήστε ελεύθερα και διακόψτε ανά πάσα στιγμή.';

  @override
  String get settingsPushToTalkDescription =>
      'Κρατήστε για να μιλήσετε, αφήστε το για αποστολή.';

  @override
  String get settingsLiveVoice => 'Ζωντανή φωνή';

  @override
  String get settingsChannels => 'Κανάλια';

  @override
  String get settingsGroupChats => 'Σε ομαδικές συνομιλίες';

  @override
  String get settingsGroupChatsDescription =>
      'Πώς συμπεριφέρεται αυτός ο πράκτορας σε ομάδες σε κάθε κανάλι.';

  @override
  String get settingsGroupChatsDisabled =>
      'Ενεργοποιήστε τις μονάδες συμπεριφοράς στο Behavior για να τις αλλάξετε.';

  @override
  String get settingsParticipationAutomatic => 'Αυτόματο';

  @override
  String get settingsParticipationMentionOnly => 'Αναφορά μόνο';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Διαβάζει το δωμάτιο και συμμετέχει όταν έχει κάτι χρήσιμο να προσθέσει.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Απαντήσεις μόνο όταν αναφέρεται ή απαντηθεί.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Απαντήσεις σε κάθε μήνυμα.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Χωρίζει τις μεγαλύτερες απαντήσεις σε σύντομα μηνύματα, όπως θα έκανε ένα άτομο.';

  @override
  String get settingsDeliverySingleDescription =>
      'Στέλνει κάθε απάντηση ως ένα μήνυμα.';

  @override
  String get settingsComputerStatus => 'Κατάσταση';

  @override
  String get settingsTest => 'Δοκιμή';

  @override
  String get settingsAppearance => 'Εμφάνιση';

  @override
  String get settingsTheme => 'Θέμα';

  @override
  String get settingsThemeSystem => 'Σύστημα';

  @override
  String get settingsThemeLight => 'Φωτεινό';

  @override
  String get settingsThemeDark => 'Σκοτεινό';

  @override
  String get settingsCloseWindow => 'Όταν κλείνεις το παράθυρο';

  @override
  String get settingsCloseAsk => 'Ρωτήστε';

  @override
  String get settingsCloseKeepRunningDescription =>
      'Το NeoAgent συνεχίζει να εκτελείται στο παρασκήνιο και παραμένει προσβάσιμο.';

  @override
  String get settingsCloseQuitDescription => 'Το NeoAgent σταματά εντελώς.';

  @override
  String get settingsPhoneTriggers => 'Ενεργοποιήσεις τηλεφώνου';

  @override
  String get settingsPhoneTriggersDescription =>
      'Σήματα στέλνει αυτό το τηλέφωνο στους αντιπροσώπους σας, ώστε οι εργασίες να μπορούν να αντιδράσουν σε αυτούς.';

  @override
  String get settingsLocationTriggers => 'Ενεργοποιητές τοποθεσίας';

  @override
  String get settingsLocationTriggersDescription =>
      'Ελέγχει την κατά προσέγγιση τοποθεσία σας κάθε λίγα λεπτά σε σχέση με τα μέρη που παρακολουθούν οι εργασίες σας.';

  @override
  String get settingsNotificationTriggers => 'Ενεργοποιήσεις ειδοποιήσεων';

  @override
  String get settingsNotificationTriggersDescription =>
      'Προωθεί ειδοποιήσεις από άλλες εφαρμογές σε αυτό το τηλέφωνο στους αντιπροσώπους σας.';

  @override
  String get settingsSetup => 'Ρύθμιση';

  @override
  String get settingsOnboarding => 'Ενσωμάτωση';

  @override
  String get settingsOnboardingDescription =>
      'Περάστε ξανά στη ρύθμιση πρώτης εκτέλεσης. Τίποτα που ρυθμίσατε δεν πάει χαμένο.';

  @override
  String get settingsUsernameDescription =>
      'Χρησιμοποιείται για τη σύνδεση. Δεν μπορεί να αλλάξει.';

  @override
  String get settingsExport => 'Εξαγωγή';

  @override
  String get settingsLeave => 'Αποσυνδεθείτε και διαγράψτε';

  @override
  String get settingsSignOutDescription =>
      'Σας αποσυνδέει μόνο σε αυτήν τη συσκευή.';

  @override
  String get settingsDeleteAccountDescription =>
      'Διαγράφει τον λογαριασμό, τους πράκτορες, τη μνήμη και τις ρυθμίσεις σας. Αυτό δεν μπορεί να αναιρεθεί.';

  @override
  String get settingsTokenUsage => 'Χρήση διακριτικών';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Καμία ρύθμιση δεν ταιριάζει με το \"$query\".';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count αποτελέσματα',
      one: '$count αποτέλεσμα',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Προηγμένες ρυθμίσεις μοντέλου';

  @override
  String get settingsAdvancedModelsDescription =>
      'Προαιρετικό. Καρφιτσώστε ένα μοντέλο σε ένα είδος εργασίας. αναλαμβάνει κάθε φορά που ο πράκτορας χρησιμοποιεί αυτά τα εργαλεία. Οτιδήποτε παραμένει στην προεπιλογή ακολουθεί το μοντέλο συνομιλίας.';

  @override
  String get settingsTaskModelDefault => 'Προεπιλογή';

  @override
  String get settingsTaskModelDefaultSubtitle =>
      'Ακολουθεί το μοντέλο συνομιλίας';

  @override
  String get settingsTaskModelCoding => 'Κωδικοποίηση';

  @override
  String get settingsTaskModelCodingDescription =>
      'Σύνταξη, επεξεργασία και διόρθωση κώδικα.';

  @override
  String get settingsTaskModelComputerUse => 'Χρήση υπολογιστή';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Οδήγηση του προγράμματος περιήγησης και της επιφάνειας εργασίας.';

  @override
  String get settingsTaskModelAndroidUse => 'Χρήση Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Λειτουργία εφαρμογών σε συσκευή Android ή εξομοιωτή.';

  @override
  String get settingsTaskModelResearch => 'Έρευνα';

  @override
  String get settingsTaskModelResearchDescription =>
      'Αναζήτηση, ανάγνωση και σύνοψη πηγών.';

  @override
  String get knowledgeGraphHint =>
      'Οι οντότητες που αναφέρατε περισσότερο, χρωματισμένες ανά σύμπλεγμα. Οι γραμμές συνδέουν οντότητες που εμφανίζονται στις ίδιες μνήμες. Πατήστε ένα για να δείτε τους συνδέσμους και τις αναμνήσεις του. σύρετε για μετατόπιση, τσιμπήστε ή Ctrl/⌘-κύλιση για μεγέθυνση.';

  @override
  String get linkedEntities => 'Συνδεδεμένες οντότητες';

  @override
  String get noLinkedEntities => 'Δεν έχει συνδεθεί ακόμα με άλλες οντότητες.';

  @override
  String mentionsArg1(int arg1) {
    return 'Το $arg1 αναφέρει';
  }

  @override
  String get entityKindConcept => 'Έννοια';

  @override
  String get entityKindDomain => 'Τομέας';

  @override
  String get entityKindEmail => 'Email';

  @override
  String get entityKindLink => 'Σύνδεσμος';

  @override
  String get entityKindFile => 'Αρχείο';

  @override
  String get entityKindAcronym => 'Ακρωνύμιο';

  @override
  String get entityKindIdentifier => 'Αναγνωριστικό';

  @override
  String get entityKindVersion => 'Έκδοση';

  @override
  String get openFullscreen => 'Άνοιγμα πλήρους οθόνης';

  @override
  String get zoomIn => 'Μεγέθυνση';

  @override
  String get zoomOut => 'Σμίκρυνση';

  @override
  String get searchEntities => 'Βρείτε μια οντότητα';

  @override
  String get incomingCall => 'Εισερχόμενη κλήση';

  @override
  String get answerCall => 'Απάντηση';

  @override
  String get callMeLater => 'Τηλεφώνησέ με αργότερα';

  @override
  String get callingEllipsis => 'Κλήση…';

  @override
  String get reconnectingCall => 'Επανασύνδεση';

  @override
  String get agentWorking => 'Εργασία';

  @override
  String get micMuted => 'Σίγαση';

  @override
  String get speakerphone => 'Ομιλητής';

  @override
  String get muteMic => 'Σίγαση';

  @override
  String get unmuteMic => 'Κατάργηση σίγασης';

  @override
  String get releaseToSend => 'Αφήστε για αποστολή';

  @override
  String get callEnded => 'Η κλήση έληξε';

  @override
  String get openConversation => 'Ανοιχτή συνομιλία';

  @override
  String get callBack => 'Καλέστε πίσω';

  @override
  String get letCallsReachYou => 'Αφήστε τις κλήσεις να σας φτάσουν';

  @override
  String get callPermissionsIntro =>
      'Οι πράκτορές σας μπορούν να σας καλέσουν. Για να χτυπήσει σαν ένα τηλεφώνημα ενώ το NeoAgent βρίσκεται στο παρασκήνιο ή το τηλέφωνό σας είναι κλειδωμένο, χρειάζεται αυτά.';

  @override
  String get showOverOtherApps => 'Εμφάνιση πάνω από άλλες εφαρμογές';

  @override
  String get showOverOtherAppsDetail =>
      'Φέρνει την οθόνη κλήσης όπου κι αν βρίσκεστε.';

  @override
  String get fullScreenCalls => 'Κλήσεις πλήρους οθόνης';

  @override
  String get fullScreenCallsDetail =>
      'Κουδουνίζει πάνω από την οθόνη κλειδώματος.';

  @override
  String get unrestrictedBattery => 'Απεριόριστη μπαταρία';

  @override
  String get unrestrictedBatteryDetail =>
      'Διατηρεί το NeoAgent συνδεδεμένο έτσι ώστε να φτάνουν οι κλήσεις.';

  @override
  String get permissionAllowed => 'Επιτρέπεται';

  @override
  String get triggerSectionCalendar => 'Ημερολόγιο';

  @override
  String get triggerSectionFiles => 'Αρχεία και έγγραφα';

  @override
  String get triggerSectionHome => 'Σπίτι και μέσα ενημέρωσης';

  @override
  String get triggerSectionDevices => 'Συσκευές και μέρη';

  @override
  String get triggerSectionTasks => 'Καθήκοντα';

  @override
  String get messagingMemberJoined => 'Έγινε μέλος';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Εκτελέστε όταν κάποιος εγγραφεί σε διακομιστή Discord, ομάδα Telegram ή WhatsApp, κανάλι Slack ή δωμάτιο Matrix.';

  @override
  String get messagingMemberLeft => 'Το μέλος αποχώρησε';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Εκτελέστε όταν κάποιος φεύγει από διακομιστή Discord, ομάδα Telegram ή WhatsApp, κανάλι Slack ή δωμάτιο Matrix.';

  @override
  String get messagingReactionAdded => 'Προστέθηκε η αντίδραση';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Εκτελείται όταν ένα επιτρεπόμενο άτομο αντιδρά σε ένα μήνυμα σε μια ιδιωτική συνομιλία.';

  @override
  String get messagingPlatformDisconnected =>
      'Η αποστολή μηνυμάτων αποσυνδέθηκε';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Εκτελέστε όταν μια σύνδεση ανταλλαγής μηνυμάτων σταματά και σας χρειάζεται, όπως μετά από αποσύνδεση.';

  @override
  String get googleCalendarEventStarting =>
      'Έναρξη εκδήλωσης Ημερολογίου Google';

  @override
  String get googleCalendarEventCreated =>
      'Δημιουργήθηκε το συμβάν του Ημερολογίου Google';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Εκτέλεση όταν εμφανίζεται μια νέα εκδήλωση ή πρόσκληση.';

  @override
  String get outlookCalendarEventStarting =>
      'Έναρξη συμβάντος ημερολογίου του Outlook';

  @override
  String get nextcloudCalendarEventStarting =>
      'Έναρξη εκδήλωσης Nextcloud Calendar';

  @override
  String get runMinutesBeforeEachEvent =>
      'Εκτελέστε έναν καθορισμένο αριθμό λεπτών πριν από κάθε συμβάν.';

  @override
  String get googleDriveFileAdded => 'Προστέθηκε αρχείο Google Drive';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Εκτελείται όταν προστίθεται ένα αρχείο στο Drive ή ένας φάκελος σε αυτό.';

  @override
  String get googleSheetsRowAdded => 'Προστέθηκε σειρά Φύλλων Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Εκτελείται όταν εμφανίζονται νέες σειρές σε ένα φύλλο.';

  @override
  String get onedriveFileAdded => 'Προστέθηκε αρχείο OneDrive';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Εκτελείται όταν προστίθεται ένα αρχείο σε έναν φάκελο OneDrive.';

  @override
  String get nextcloudFileAdded => 'Προστέθηκε το αρχείο Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Εκτελείται όταν προστίθεται ένα αρχείο σε έναν φάκελο Nextcloud.';

  @override
  String get nextcloudShareReceived =>
      'Το αρχείο Nextcloud είναι κοινόχρηστο μαζί σας';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Εκτελέστε όταν κάποιος μοιράζεται ένα αρχείο ή φάκελο μαζί σας.';

  @override
  String get notionItemAdded => 'Προστέθηκε στοιχείο βάσης δεδομένων έννοιας';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Εκτελείται όταν προστίθεται ένα στοιχείο σε μια βάση δεδομένων Notion.';

  @override
  String get notionItemUpdated =>
      'Ενημερώθηκε το στοιχείο βάσης δεδομένων Notion';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Εκτελείται όταν αλλάζει ένα στοιχείο σε μια βάση δεδομένων Notion.';

  @override
  String get trelloCardEnteredList => 'Η κάρτα Trello προστέθηκε στη λίστα';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Εκτελείται όταν μια κάρτα δημιουργείται ή μετακινείται σε μια λίστα.';

  @override
  String get figmaCommentAdded => 'Προστέθηκε σχόλιο Figma';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Εκτελείται όταν κάποιος σχολιάζει ένα αρχείο Figma.';

  @override
  String get githubPrOpened => 'Άνοιξε το αίτημα έλξης GitHub';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Εκτελείται όταν ανοίγει ένα νέο αίτημα έλξης σε ένα αποθετήριο.';

  @override
  String get githubWorkflowRunFailed =>
      'Η εκτέλεση ροής εργασίας GitHub απέτυχε';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Εκτελείται όταν αποτυγχάνει η εκτέλεση του GitHub Actions.';

  @override
  String get githubCommitPushed => 'Η δέσμευση GitHub ώθησε';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Εκτελέστε όταν οι νέες δεσμεύσεις φτάσουν σε έναν κλάδο.';

  @override
  String get mcpServerFailed => 'Ο διακομιστής MCP απέτυχε';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Εκτελείται όταν ένας διακομιστής MCP που λειτουργούσε αποτυγχάνει ή χρειάζεται σύνδεση.';

  @override
  String get homeAssistantStateChanged =>
      'Η κατάσταση του Home Assistant άλλαξε';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Εκτελείται όταν μια οντότητα αλλάζει, φτάνει σε κατάσταση ή διασχίζει μια τιμή.';

  @override
  String get spotifyTrackChanged => 'Το κομμάτι Spotify άλλαξε';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Εκτελέστε όταν αρχίσει να παίζει διαφορετικό κομμάτι.';

  @override
  String get neorecallDailySummaryReady =>
      'Έτοιμη η καθημερινή περίληψη του NeoRecall';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Εκτελέστε όταν η σύνοψη μιας ημέρας είναι οριστική.';

  @override
  String get neorecallConversationRecorded =>
      'Η συνομιλία NeoRecall καταγράφηκε';

  @override
  String get runWhenARecordedConversationEnds =>
      'Εκτελέστε όταν τελειώσει μια ηχογραφημένη συνομιλία.';

  @override
  String get geofenceTrigger => 'Τοποθεσία geofence';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Εκτελέστε όταν το τηλέφωνό σας φτάσει ή φεύγει από ένα μέρος. Απαιτείται παρακολούθηση τοποθεσίας στο τηλέφωνο.';

  @override
  String get healthMetricRecorded => 'Η μέτρηση υγείας καταγράφηκε';

  @override
  String get runWhenAHealthReadingArrives =>
      'Εκτελείται όταν φτάσει μια συγχρονισμένη ένδειξη υγείας, προαιρετικά πάνω ή κάτω από μια τιμή.';

  @override
  String get wearableConnectionChanged => 'Φορητό συνδεδεμένο ή αποσυνδεδεμένο';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Εκτελέστε όταν το wearable σας συνδεθεί ή αποσυνδεθεί.';

  @override
  String get taskRunFinished => 'Μια άλλη εργασία ολοκληρώθηκε';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Εκτέλεση μετά την ολοκλήρωση, την επιτυχία ή την αποτυχία μιας άλλης εργασίας.';

  @override
  String get appPackageOptional => 'Πακέτο εφαρμογής (προαιρετικό)';

  @override
  String get appPackageHelper => 'Για παράδειγμα com.whatsapp';

  @override
  String get anyPlatform => 'Οποιαδήποτε πλατφόρμα';

  @override
  String get spaceIdOptional =>
      'Αναγνωριστικό διακομιστή, ομάδας, καναλιού ή δωματίου (προαιρετικό)';

  @override
  String get spaceIdHelper =>
      'Άδειο ρολόι σε κάθε ένα στο οποίο βρίσκεται το bot.';

  @override
  String get emojiOptional => 'Emoji (προαιρετικό)';

  @override
  String get chatIdOptional => 'Αναγνωριστικό συνομιλίας (προαιρετικό)';

  @override
  String get platformOptional => 'Πλατφόρμα (προαιρετικό)';

  @override
  String get platformOptionalHelper =>
      'Για παράδειγμα το whatsapp. Άδεια ρολόγια όλα.';

  @override
  String get minutesBefore => 'Λεπτά πριν';

  @override
  String get calendarIdOptional => 'Αναγνωριστικό ημερολογίου (προαιρετικό)';

  @override
  String get calendarIdHelper =>
      'Το Empty χρησιμοποιεί το κύριο ημερολόγιό σας.';

  @override
  String get invitesOnly => 'Μόνο προσκλήσεις από άλλους';

  @override
  String get nextcloudCalendarPath => 'Ημερολόγιο';

  @override
  String get nextcloudCalendarPathHelper =>
      'Το όνομά του στη λίστα ημερολογίου Nextcloud, για παράδειγμα προσωπικό';

  @override
  String get folderIdOptionalHelperDrive => 'Άδειο ρολόγια σε όλο το Drive.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Το Empty παρακολουθεί τον ριζικό φάκελο.';

  @override
  String get driveFolderIdOptional => 'Αναγνωριστικό φακέλου (προαιρετικό)';

  @override
  String get spreadsheetId => 'Αναγνωριστικό υπολογιστικού φύλλου';

  @override
  String get sheetRange => 'Εύρος';

  @override
  String get sheetRangeHelper =>
      'Οι στήλες του πίνακα, για παράδειγμα Sheet1!A:E';

  @override
  String get folderPathOptional => 'Διαδρομή φακέλου (προαιρετικό)';

  @override
  String get folderPathHelper => 'Για παράδειγμα Έγγραφα';

  @override
  String get notionDatabaseId => 'Αναγνωριστικό βάσης δεδομένων';

  @override
  String get trelloListId => 'Αναγνωριστικό λίστας';

  @override
  String get figmaFileKey => 'Κλειδί αρχείου';

  @override
  String get figmaFileKeyHelper =>
      'Από τον σύνδεσμο αρχείου: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Αποθετήριο';

  @override
  String get workflowOptional => 'Ροή εργασιών (προαιρετικό)';

  @override
  String get workflowHelper => 'Όνομα αρχείου όπως ci.yml';

  @override
  String get branchOptional => 'Υποκατάστημα (προαιρετικό)';

  @override
  String get branchHelper => 'Το Empty χρησιμοποιεί τον προεπιλεγμένο κλάδο.';

  @override
  String get mcpServerIdOptional =>
      'Αναγνωριστικό διακομιστή MCP (προαιρετικό)';

  @override
  String get entityId => 'Αναγνωριστικό οντότητας';

  @override
  String get entityIdHelper => 'Για παράδειγμα binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Κατάσταση στόχου (προαιρετικό)';

  @override
  String get targetStateHelper => 'Για παράδειγμα στο';

  @override
  String get aboveOptional => 'Πάνω (προαιρετικό)';

  @override
  String get belowOptional => 'Παρακάτω (προαιρετικό)';

  @override
  String get placeName => 'Τοπωνύμιο';

  @override
  String get latitude => 'Γεωγραφικό πλάτος';

  @override
  String get longitude => 'γεωγραφικό μήκος';

  @override
  String get radiusMeters => 'Ακτίνα σε μέτρα';

  @override
  String get geofenceTransition => 'Πότε';

  @override
  String get arriving => 'Φτάνοντας';

  @override
  String get leaving => 'Φεύγοντας';

  @override
  String get healthMetric => 'Μέτρηση υγείας';

  @override
  String get healthMetricHelper =>
      'Για παράδειγμα καρδιακός_παλμός, βήματα, βάρος';

  @override
  String get wearableTransition => 'Όταν το φορετό';

  @override
  String get wearableConnects => 'Συνδέεται';

  @override
  String get wearableDisconnects => 'Αποσυνδέεται';

  @override
  String get sourceTask => 'Μετά την εργασία';

  @override
  String get taskOutcome => 'Αποτέλεσμα';

  @override
  String get anyOutcome => 'Οποιοδήποτε αποτέλεσμα';

  @override
  String get succeeded => 'Πέτυχε';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return 'Το $arg1 λείπει ή δεν είναι έγκυρο.';
  }

  @override
  String get triggerSectionMessaging => 'Μηνύματα';

  @override
  String get triggerSectionDeveloper => 'Προγραμματιστής';

  @override
  String get triggerSectionMemory => 'Μνήμη';

  @override
  String get triggerSectionNews => 'Νέα';

  @override
  String get triggerSectionSystem => 'Σύστημα';

  @override
  String get searchTriggersHint => 'Αναζήτηση κανόνων, εφαρμογών ή συμβάντων';

  @override
  String get noTriggersMatch =>
      'Κανένας κανόνας ετικέτας δεν αντιστοιχεί στην αναζήτησή σας.';

  @override
  String get triggerAccountMissing => 'Δεν υπάρχει λογαριασμός ακόμα';

  @override
  String get pickTriggerKeyboardHint => 'Το Enter επιλέγει το πρώτο αποτέλεσμα';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 σκανδάλες';
  }

  @override
  String get addFromSkillsSh => 'Προσθήκη από skills.sh';

  @override
  String get skillsShHint =>
      'Αναζητήστε παραπάνω για να βρείτε skills στο skills.sh ή επικολλήστε έναν σύνδεσμο skills.sh ή μια εντολή \"npx skills add\".';

  @override
  String get noSkillsShMatches =>
      'Δεν υπάρχουν δεξιότητες skills.sh που να αντιστοιχούν σε αυτήν την αναζήτηση.';

  @override
  String get installingSkill => 'Εγκατάσταση…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Εγκατεστημένο το $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Το $arg1 εγκαθιστά';
  }

  @override
  String get authVerify => 'Επαλήθευση';

  @override
  String get authCreateAccount => 'Δημιουργία λογαριασμού';

  @override
  String get authNewInviteLink => 'Νέος σύνδεσμος πρόσκλησης';

  @override
  String get authShowPassword => 'Εμφάνιση κωδικού πρόσβασης';

  @override
  String get authHidePassword => 'Απόκρυψη κωδικού πρόσβασης';

  @override
  String get authPasswordWillBeRejected => 'πολύ αδύναμο, θα απορριφθεί';

  @override
  String get authUsernameTooShort =>
      'Τα ονόματα χρήστη χρειάζονται τουλάχιστον 3 χαρακτήρες.';

  @override
  String get authUsernameTaken => 'Αυτό το όνομα χρήστη έχει ήδη ληφθεί.';

  @override
  String get authSignupsClosed =>
      'Οι εγγραφές έχουν κλείσει σε αυτόν τον διακομιστή. Ζητήστε από τον διαχειριστή έναν λογαριασμό.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Αυτός ο διακομιστής δέχεται συνδέσεις μόνο μέσω HTTPS. Ανοίξτε το $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Αυτός ο διακομιστής δέχεται συνδέσεις μόνο μέσω HTTPS. Συνδεθείτε σε αυτό με μια διεύθυνση https://.';

  @override
  String get authAccountNotFound => 'Αυτός ο λογαριασμός δεν υπάρχει πλέον.';

  @override
  String get authQrRateLimited =>
      'Πάρα πολλά αιτήματα σύνδεσης QR. Περιμένετε λίγο και μετά ανανεώστε τον κωδικό.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Ξεχάσατε τον κωδικό σας; Ζητήστε από τον διαχειριστή του διακομιστή σας να το επαναφέρει στο Διαχειριστής → Χρήστες.';

  @override
  String get authChangeServer => 'Αλλαγή διακομιστή';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Σύνδεση στο $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Αυτή η διεύθυνση δεν απαντά σαν διακομιστής NeoAgent. Ελέγξτε τη διεύθυνση URL και δοκιμάστε ξανά.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Δεν ήταν δυνατό το άνοιγμα μιας ασφαλούς σύνδεσης (HTTPS) στο $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Δεν ήταν δυνατή η επικοινωνία με το $arg1 μέσω HTTPS και ούτε το απλό HTTP απάντησε. Ελέγξτε τη διεύθυνση και τη θύρα.';
  }

  @override
  String get adminResetPassword => 'Επαναφορά κωδικού πρόσβασης';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Επαναφορά κωδικού πρόσβασης για $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Επιλέξτε έναν νέο κωδικό πρόσβασης για το $arg1. Θα αποσυνδεθούν σε κάθε συσκευή και θα συνδεθούν ξανά με αυτόν τον κωδικό πρόσβασης.';
  }

  @override
  String get adminNewPassword => 'Νέος κωδικός πρόσβασης';

  @override
  String get adminSetPassword => 'Ορίστε κωδικό πρόσβασης';

  @override
  String get authMissingFields => 'Συμπληρώστε κάθε απαιτούμενο πεδίο.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return 'Το $arg1 επαναφέρει τον κωδικό πρόσβασης του $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Ο κωδικός ενημερώθηκε. ο χρήστης ήταν αποσυνδεδεμένος παντού.';

  @override
  String get authSignInTitle => 'Συνδεθείτε στο NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Σαρώστε με το τηλέφωνό σας ή χρησιμοποιήστε τον κωδικό πρόσβασής σας.';

  @override
  String get authOrUsePassword => 'ή χρησιμοποιήστε τον κωδικό πρόσβασής σας';

  @override
  String get qrLoginWaitingTitle => 'Έγκριση στο τηλέφωνό σας';

  @override
  String get qrLoginWaitingBody =>
      'Το τηλέφωνό σας σάρωση του κωδικού. Επιβεβαιώστε τη σύνδεση εκεί για να ολοκληρώσετε τη σύνδεση.';

  @override
  String get qrLoginSigningInOn => 'Σύνδεση';

  @override
  String get qrLoginLocation => 'Τοποθεσία';

  @override
  String get qrLoginWaitingForApproval => 'Αναμονή για έγκριση';

  @override
  String get qrLoginCancelAndUsePassword =>
      'Ακύρωση και χρήση κωδικού πρόσβασης';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Η σύνδεση απορρίφθηκε στο τηλέφωνό σας. Σαρώστε τον νέο κωδικό για να προσπαθήσετε ξανά.';

  @override
  String get signupKey => 'Κλειδί εγγραφής';

  @override
  String get signupKeyStepSubtitle =>
      'Οι νέοι λογαριασμοί σε αυτόν τον διακομιστή χρειάζονται κλειδί εγγραφής. Εισαγάγετε το κλειδί που λάβατε από έναν διαχειριστή.';

  @override
  String get signupKeyChange => 'Αλλαγή';

  @override
  String get signupKeyRequiredError => 'Εισαγάγετε το κλειδί εγγραφής σας.';

  @override
  String get signupKeyInvalidError =>
      'Αυτό το κλειδί εγγραφής δεν είναι έγκυρο. Ελέγξτε το και δοκιμάστε ξανά.';

  @override
  String get signupKeyUsedError =>
      'Αυτό το κλειδί εγγραφής έχει ήδη χρησιμοποιηθεί. Ζητήστε νέο από έναν διαχειριστή.';

  @override
  String get adminRequireSignupKey => 'Απαίτηση κλειδιού εγγραφής';

  @override
  String get adminRequireSignupKeyHint =>
      'Οι νέοι λογαριασμοί χρειάζονται κλειδί μίας χρήσης από διαχειριστή. Όταν είναι απενεργοποιημένο, μπορεί να εγγραφεί οποιοσδήποτε έχει πρόσβαση σε αυτόν τον διακομιστή. Ο πρώτος λογαριασμός δεν χρειάζεται ποτέ κλειδί.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Οι νέοι λογαριασμοί χρειάζονται πλέον κλειδί εγγραφής.';

  @override
  String get adminSignupOpenNotice => 'Πλέον μπορεί να εγγραφεί οποιοσδήποτε.';

  @override
  String get signupKeys => 'Κλειδιά εγγραφής';

  @override
  String get signupKeysDescription =>
      'Κλειδιά μίας χρήσης για εγγραφή όσο απαιτείται κλειδί. Κάθε κλειδί δημιουργεί ακριβώς έναν λογαριασμό.';

  @override
  String get signupKeysNew => 'Νέα κλειδιά';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Αχρησιμοποίητα · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Χρησιμοποιημένα · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Ανακλημένα · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Όλα · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Αχρησιμοποίητο';

  @override
  String get signupKeyStatusUsed => 'Χρησιμοποιημένο';

  @override
  String get signupKeyStatusRevoked => 'Ανακλημένο';

  @override
  String get signupKeysExport => 'Εξαγωγή .txt';

  @override
  String get signupKeysCopied => 'Τα κλειδιά αντιγράφηκαν';

  @override
  String get signupKeyCopied => 'Το κλειδί αντιγράφηκε';

  @override
  String get signupKeysEmpty => 'Δεν υπάρχουν κλειδιά σε αυτή τη λίστα.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Δημιουργήθηκε $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Χρησιμοποιήθηκε από $arg1 στις $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Χρησιμοποιήθηκε στις $arg1 από λογαριασμό που έχει πλέον διαγραφεί';
  }

  @override
  String get signupKeyRevokeTitle => 'Ανάκληση αυτού του κλειδιού;';

  @override
  String get signupKeyRevokeMessage =>
      'Κανείς δεν θα μπορεί να εγγραφεί με αυτό. Η ενέργεια δεν αναιρείται.';

  @override
  String get signupKeyRevoked => 'Το κλειδί ανακλήθηκε.';

  @override
  String signupKeysShowMore(int count) {
    return 'Εμφάνιση $count ακόμη';
  }

  @override
  String get signupKeysCreateTitle => 'Δημιουργία κλειδιών εγγραφής';

  @override
  String get signupKeysCount => 'Αριθμός κλειδιών';

  @override
  String get signupKeysCountHelper => 'Από 1 έως 500';

  @override
  String get signupKeysCountInvalid => 'Εισαγάγετε αριθμό από 1 έως 500.';

  @override
  String get signupKeysLabel => 'Ετικέτα (προαιρετικά)';

  @override
  String get signupKeysLabelHint => 'π.χ. Ανοιξιάτικοι beta testers';

  @override
  String signupKeysCreateAction(int count) {
    return 'Δημιουργία ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Έτοιμα κλειδιά: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Δώστε κάθε κλειδί σε ένα μόνο άτομο. Τα αχρησιμοποίητα κλειδιά παραμένουν στη λίστα, ώστε να μπορείτε να τα αντιγράψετε ή να τα εξαγάγετε ξανά αργότερα.';

  @override
  String get signupKeysSaveDialogTitle => 'Αποθήκευση κλειδιών εγγραφής';

  @override
  String get signupKeysExported => 'Τα κλειδιά εξήχθησαν.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor δημιούργησε κλειδιά εγγραφής ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor ανακάλεσε ένα κλειδί εγγραφής';
  }

  @override
  String get providerChooseUsername => 'Επιλέξτε όνομα χρήστη';

  @override
  String get providerChooseUsernameBody =>
      'Επιλέξτε ένα διαθέσιμο όνομα χρήστη για να ολοκληρώσετε τη δημιουργία του λογαριασμού σας.';

  @override
  String get dataSharingTitle => 'Κοινοποίηση δεδομένων χρήσης';

  @override
  String get dataSharingDescription =>
      'Βοηθήστε όσους διαχειρίζονται αυτόν τον διακομιστή να τον βελτιώσουν. Κοινοποιεί πώς χρησιμοποιείτε το NeoAgent, ποτέ τι γράφετε ή αποθηκεύετε.';

  @override
  String dataSharingSince(String date) {
    return 'Κοινοποίηση από $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Τι κοινοποιείται';

  @override
  String get dataSharingIncluded => 'Κοινοποιείται';

  @override
  String get dataSharingExcluded => 'Δεν κοινοποιείται ποτέ';

  @override
  String get dataSharingIncludedDevice => 'Τύπος συσκευής και έκδοση εφαρμογής';

  @override
  String get dataSharingIncludedLocale =>
      'Γλώσσα εφαρμογής και περιοχή ζώνης ώρας, π.χ. Ευρώπη';

  @override
  String get dataSharingIncludedFeatures =>
      'Ποιες λειτουργίες έχετε ρυθμίσει, όπως εργασίες, skills και ενσωματώσεις';

  @override
  String get dataSharingIncludedRuns =>
      'Ποια εργαλεία και μοντέλα χρησιμοποιούν οι εκτελέσεις σας, με χρόνους και αριθμό tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Πότε χρησιμοποιείτε το NeoAgent, ανά ημέρα της εβδομάδας και ώρα';

  @override
  String get dataSharingExcludedContent => 'Μηνύματα, prompts και απαντήσεις';

  @override
  String get dataSharingExcludedRuns =>
      'Τίτλοι εκτελέσεων, είσοδοι και αποτελέσματα εργαλείων';

  @override
  String get dataSharingExcludedFiles =>
      'Αρχεία, αναμνήσεις και ό,τι άλλο αποθηκεύετε';

  @override
  String get dataSharingExcludedIdentity =>
      'Το όνομα, το email, η διεύθυνση IP και η τοποθεσία σας';

  @override
  String get dataSharingExcludedAccounts =>
      'Οι λογαριασμοί με τους οποίους συνδέετε ενσωματώσεις';

  @override
  String get dataSharingPooledNote =>
      'Οι διαχειριστές βλέπουν μόνο σύνολα για όλους όσους κοινοποιούν, ποτέ εσάς μεμονωμένα. Απενεργοποιήστε το οποτεδήποτε και βγαίνετε αμέσως από τα σύνολα.';

  @override
  String get dataSharingConfirmTitle => 'Κοινοποίηση δεδομένων χρήσης;';

  @override
  String get dataSharingConfirmAction => 'Κοινοποίηση';

  @override
  String get sharedUsageTitle => 'Κοινόχρηστη χρήση';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Λογαριασμοί που κοινοποιούν δεδομένα χρήσης: $sharing από $total. Μόνο σύνολα, χωρίς περιεχόμενο.';
  }

  @override
  String get sharedUsageEmpty =>
      'Κανείς δεν κοινοποιεί ακόμη δεδομένα χρήσης. Ενεργοποιείται από Ρυθμίσεις, Προφίλ, Τα δεδομένα σας.';

  @override
  String get sharedUsageRuns => 'Κοινοποιημένες εκτελέσεις';

  @override
  String get sharedUsageAvgDuration => 'Μέση διάρκεια';

  @override
  String get sharedUsageCompletedRuns => 'Ολοκληρωμένες εκτελέσεις';

  @override
  String get sharedUsageStepsPerRun => 'Βήματα ανά εκτέλεση';

  @override
  String get sharedUsageDevices => 'Συσκευές';

  @override
  String get sharedUsageAppVersions => 'Εκδόσεις εφαρμογής';

  @override
  String get sharedUsageLanguages => 'Γλώσσες';

  @override
  String get sharedUsageRegions => 'Περιοχές';

  @override
  String get sharedUsageFeatures => 'Υιοθέτηση λειτουργιών';

  @override
  String get sharedUsageFeaturesDescription =>
      'Ποσοστό των λογαριασμών που κοινοποιούν και την έχουν ρυθμίσει.';

  @override
  String get sharedUsageTools => 'Εργαλεία';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Τα πιο συχνά καλούμενα εργαλεία ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Κλήσεις: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Αποτυχίες: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Ενσωματώσεις';

  @override
  String get sharedUsageMessaging => 'Κανάλια μηνυμάτων';

  @override
  String get sharedUsageTriggers => 'Πώς ξεκινούν οι εκτελέσεις';

  @override
  String get sharedUsageActivity => 'Πότε χρησιμοποιείται';

  @override
  String get sharedUsageActivityDescription =>
      'Εκτελέσεις ανά ημέρα της εβδομάδας και ώρα, UTC.';

  @override
  String get sharedUsageModels => 'Απόδοση μοντέλων';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'μέσος όρος $latency · $cached% από cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Λογαριασμοί: $count';
  }

  @override
  String get sharedUsageNoData => 'Τίποτα σε αυτό το διάστημα.';

  @override
  String get sharedUsageNotReported => 'Δεν έχει αναφερθεί ακόμη';

  @override
  String get sharedUsageFeatureAgents => 'Περισσότεροι από ένας πράκτορες';

  @override
  String get sharedUsageFeatureTasks => 'Προγραμματισμένες εργασίες';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'Διακομιστές MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Ενσωματώσεις';

  @override
  String get sharedUsageFeatureMessaging => 'Κανάλια μηνυμάτων';

  @override
  String get sharedUsageFeatureMemory => 'Μνήμη';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in κοινοποίηση δεδομένων τηλεμετρία συσκευές λειτουργίες εργαλεία μοντέλα δραστηριότητα';

  @override
  String get yourOAuthApp => 'Η εφαρμογή OAuth σας';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Η εφαρμογή OAuth σας για $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Αυτός ο διακομιστής δεν έχει καθολική εφαρμογή $provider, οπότε συνδέεστε με μια εφαρμογή OAuth που καταχωρίζετε εσείς. Το μυστικό πελάτη αποθηκεύεται κρυπτογραφημένο και δεν εμφανίζεται ποτέ ξανά.';
  }

  @override
  String get oauthAppStepCreate => '1. Δημιουργήστε την εφαρμογή';

  @override
  String get openDeveloperConsole => 'Άνοιγμα κονσόλας προγραμματιστή';

  @override
  String get oauthAppStepCallback => '2. Καταχωρίστε αυτό το URL επιστροφής';

  @override
  String get callbackUrlCopied => 'Το URL επιστροφής αντιγράφηκε';

  @override
  String get oauthAppScopes => 'Εύρη πρόσβασης προς έγκριση';

  @override
  String get scopesCopied => 'Τα εύρη πρόσβασης αντιγράφηκαν';

  @override
  String get oauthAppStepCredentials =>
      '3. Επικολλήστε τα διαπιστευτήρια της εφαρμογής';

  @override
  String get couldNotSaveOAuthApp =>
      'Δεν ήταν δυνατή η αποθήκευση της εφαρμογής OAuth.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Κατάργηση της εφαρμογής σας για $provider;';
  }

  @override
  String get removeOAuthAppBody =>
      'Οι συνδεδεμένοι λογαριασμοί παραμένουν στη λίστα, αλλά σταματούν να λειτουργούν μέχρι να προσθέσετε ξανά εφαρμογή.';

  @override
  String get globalIntegrationConfiguration =>
      'Καθολική διαμόρφωση ενοποιήσεων';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Προαιρετικές εφαρμογές OAuth για όλο τον διακομιστή. Όταν μια ενοποίηση έχει μία, κάθε λογαριασμός τη χρησιμοποιεί και δεν μπορεί να προσθέσει δική του. Αφήστε μια ενοποίηση κενή και κάθε χρήστης ρυθμίζει τη δική του εφαρμογή. Τα μυστικά είναι μόνο για εγγραφή: αφήστε κενό για να διατηρηθεί η αποθηκευμένη τιμή.';

  @override
  String get globalStatus => 'Καθολικά';

  @override
  String get perUserStatus => 'Ανά χρήστη';

  @override
  String get phoneSyncGuidance =>
      'Μοιραστείτε τα ημερολόγια και τις επαφές αυτού του τηλεφώνου με τον πράκτορά σας. Λειτουργεί με κάθε λογαριασμό που υπάρχει ήδη στο τηλέφωνο.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Ανοίξτε το NeoAgent στο τηλέφωνο και ενεργοποιήστε εκεί την κοινή χρήση. Ο πράκτορας θα βλέπει τα ημερολόγια και τις επαφές όλων των λογαριασμών του τηλεφώνου.';

  @override
  String get manageOnThisPhone => 'Διαχείριση σε αυτό το τηλέφωνο';

  @override
  String get setUpOnThisPhone => 'Ρύθμιση σε αυτό το τηλέφωνο';

  @override
  String get setUpOnPhone => 'Ρύθμιση στο τηλέφωνό σας';

  @override
  String emailConnectedArg1(String email) {
    return 'Συνδέθηκε το $email';
  }

  @override
  String get couldNotConnectEmail =>
      'Δεν ήταν δυνατή η σύνδεση του λογαριασμού.';

  @override
  String get emailSetupTitle => 'Σύνδεση email και ημερολογίου';

  @override
  String get emailChecking => 'Έλεγχος γραμματοκιβωτίου…';

  @override
  String get emailSetupIntro =>
      'Χρησιμοποιήστε κωδικό εφαρμογής από τον πάροχο email. Χωρίς κονσόλα προγραμματιστή, έτοιμο σε λίγα λεπτά.';

  @override
  String emailOpenArg1(String provider) {
    return 'Άνοιγμα $provider';
  }

  @override
  String get emailStepServers => '1. Εισαγάγετε τους διακομιστές';

  @override
  String get emailStepPassword => '1. Δημιουργήστε κωδικό εφαρμογής';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Άνοιγμα κωδικών εφαρμογών $provider';
  }

  @override
  String get emailStepSignIn => '2. Σύνδεση';

  @override
  String get appPassword => 'Κωδικός εφαρμογής';

  @override
  String get appPasswordHelper =>
      'Τα κενά δεν μετράνε. Το NeoAgent τον αποθηκεύει κρυπτογραφημένο.';

  @override
  String get emailUsernameOptional => 'Όνομα χρήστη, αν δεν είναι το email σας';

  @override
  String get emailIncludeCalendar => 'Συμπερίληψη ημερολογίου';

  @override
  String get emailIncludeContacts => 'Συμπερίληψη επαφών';

  @override
  String get imapServer => 'Διακομιστής IMAP';

  @override
  String get smtpServer => 'Διακομιστής SMTP';

  @override
  String get caldavUrlOptional => 'URL CalDAV (προαιρετικό)';

  @override
  String get carddavUrlOptional => 'URL CardDAV (προαιρετικό)';

  @override
  String get alternativeEmail =>
      'Συνδέστε το γραμματοκιβώτιο με κωδικό εφαρμογής ή το ημερολόγιο με τον σύνδεσμο iCal του. Έτοιμο σε λίγα λεπτά.';

  @override
  String get alternativePhone =>
      'Μοιραστείτε το ημερολόγιο και τις επαφές του τηλεφώνου μέσω της εφαρμογής NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Μοιραστείτε το ημερολόγιο και τις επαφές του τηλεφώνου. Ρυθμίστε το στην εφαρμογή NeoAgent του τηλεφώνου.';

  @override
  String get skipTheDeveloperConsole => 'Χωρίς κονσόλα προγραμματιστή';

  @override
  String get phoneSyncPromptTitle => 'Να βλέπει ο πράκτορας το ημερολόγιό σας;';

  @override
  String get phoneSyncPromptBody =>
      'Μοιραστείτε τα ημερολόγια και τις επαφές του τηλεφώνου ώστε ο πράκτορας να οργανώνει τη μέρα σας. Μπορείτε να το αλλάξετε ανά πάσα στιγμή στα Εργαλεία › Ενοποιήσεις.';

  @override
  String get phoneSyncTitle =>
      'Κοινή χρήση ημερολογίου και επαφών του τηλεφώνου';

  @override
  String get phoneSyncIntro =>
      'Ο πράκτορας βλέπει τα ημερολόγια και τις επαφές όλων των λογαριασμών του τηλεφώνου. Χωρίς κονσόλα προγραμματιστή, χωρίς επιπλέον σύνδεση.';

  @override
  String get phoneSyncPointAccounts =>
      'Λειτουργεί με τους λογαριασμούς Google, Outlook, iCloud και Exchange του τηλεφώνου.';

  @override
  String get phoneSyncPointPrivate =>
      'Κοινοποιείται μόνο στον διακομιστή NeoAgent σας, που τα αποθηκεύει κρυπτογραφημένα.';

  @override
  String get phoneSyncPointWrites =>
      'Τα συμβάντα που προσθέτει ο πράκτορας δημιουργούνται από αυτό το τηλέφωνο και συγχρονίζονται κανονικά.';

  @override
  String get phoneSyncCalendarHint =>
      'Συμβάντα από 30 ημέρες πριν έως 90 ημέρες μετά';

  @override
  String get phoneSyncContacts => 'Επαφές';

  @override
  String get phoneSyncContactsHint =>
      'Ονόματα, διευθύνσεις email και αριθμοί τηλεφώνου';

  @override
  String get phoneSyncOtherAgent =>
      'Αυτό το τηλέφωνο μοιράζεται με άλλον πράκτορα. Η κοινή χρήση εδώ το μεταφέρει σε αυτόν.';

  @override
  String get phoneSyncDenied =>
      'Το NeoAgent δεν έχει ακόμη πρόσβαση. Επιτρέψτε την στις Ρυθμίσεις και επιστρέψτε.';

  @override
  String get openPhoneSettings => 'Άνοιγμα Ρυθμίσεων';

  @override
  String get phoneSyncShare => 'Κοινή χρήση με το NeoAgent';

  @override
  String get phoneSyncStop => 'Διακοπή κοινής χρήσης';

  @override
  String get phoneSyncWaiting => 'Αναμονή για τον πρώτο συγχρονισμό…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Τελευταίος συγχρονισμός $time';
  }

  @override
  String get calendarLink => 'Σύνδεσμος ημερολογίου';

  @override
  String get calendarLinkHelper =>
      'Η διεύθυνση iCal του ημερολογίου. Όποιος την έχει μπορεί να διαβάσει το ημερολόγιο, οπότε κρατήστε την ιδιωτική.';

  @override
  String get calendarLinkName => 'Όνομα (προαιρετικό)';

  @override
  String get calendarLinkAdded => 'Το ημερολόγιο προστέθηκε';

  @override
  String get toolsApps => 'Εφαρμογές';

  @override
  String get reconnect => 'Επανασύνδεση';

  @override
  String get reconnectNeeded => 'Απαιτείται επανασύνδεση';

  @override
  String get mixedAccess => 'Μικτή πρόσβαση';

  @override
  String disconnectAccountTitle(String account) {
    return 'Αποσύνδεση του $account;';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Ο πράκτορας χάνει την πρόσβαση στα $apps μέσω αυτού του λογαριασμού.';
  }

  @override
  String get neoRouterServerDescription =>
      'Συνδέστε το NeoRouter σας μία φορά και κάθε λογαριασμός εδώ θα το χρησιμοποιεί για τις εργασίες που είναι ενεργές παρακάτω.';

  @override
  String get neoRouterUserDescription =>
      'Χρησιμοποιήστε τον δικό σας λογαριασμό NeoRouter για τις εργασίες που είναι ενεργές παρακάτω αντί για τους παρόχους αυτού του διακομιστή.';

  @override
  String get neoRouterAddress => 'Διεύθυνση NeoRouter';

  @override
  String get neoRouterConnect => 'Σύνδεση NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Εγκρίνετε το NeoAgent στο NeoRouter. Εμφανίζει τον κωδικό $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Άνοιγμα ξανά';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Συνδέθηκε με $arg1';
  }

  @override
  String get neoRouterUnreachable =>
      'Το NeoRouter δεν είναι προσβάσιμο αυτή τη στιγμή.';

  @override
  String get neoRouterDisconnect => 'Αποσύνδεση';

  @override
  String get neoRouterDisconnectBody =>
      'Το NeoAgent σταματά να χρησιμοποιεί αυτό το NeoRouter. Για να ανακαλέσετε και το κλειδί, κάντε το στο NeoRouter στα Κλειδιά API.';

  @override
  String get neoRouterServerInUse =>
      'Αυτός ο διακομιστής χρησιμοποιεί ήδη NeoRouter για όλους. Συνδέστε τον δικό σας λογαριασμό NeoRouter για δικά σας μοντέλα και προϋπολογισμό.';

  @override
  String get neoRouterConnected => 'Το NeoRouter συνδέθηκε.';

  @override
  String get neoRouterRoleChat => 'Συνομιλία και αναγνώριση εικόνας';

  @override
  String get neoRouterRoleSystemOne => 'Αποφάσεις System One';

  @override
  String get neoRouterRoleTranscription => 'Ομιλία σε κείμενο';

  @override
  String get neoRouterRoleLive => 'Ζωντανή φωνή';

  @override
  String get neoRouterRoleEmbeddings => 'Αναζήτηση στη μνήμη';

  @override
  String get neoRouterRoleImages => 'Δημιουργία εικόνων';

  @override
  String get neoRouterRoleSearch => 'Αναζήτηση στο web';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Διαθέσιμα στο NeoRouter σας: $arg1';
  }

  @override
  String get neoRouterNoModels => 'Δεν υπάρχει ακόμη τίποτα στο NeoRouter σας.';

  @override
  String get neoRouterPicksModels =>
      'Το NeoRouter επιλέγει το μοντέλο για κάθε αίτημα, οπότε αυτή η επιλογή δεν χρησιμοποιείται.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return 'Στο NeoRouter σας: $arg1, αλλά το κλειδί του NeoAgent δεν μπορεί ακόμη να τα χρησιμοποιήσει (π.χ. τα επί πληρωμή). Επιτρέψτε τα για το NeoAgent στα Κλειδιά API του NeoRouter.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Χρειάζονται μοντέλα αποφάσεων όπως το Jev. Οι ταξινομητές ασφάλειας δεν απαντούν σε αυτές τις ερωτήσεις.';
}
