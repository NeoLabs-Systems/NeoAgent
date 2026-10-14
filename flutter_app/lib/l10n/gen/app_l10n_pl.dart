// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppL10nPl extends AppL10n {
  AppL10nPl([String locale = 'pl']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Witamy';

  @override
  String get onboardingEyebrowCommunication => 'Komunikacja';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligencja';

  @override
  String get onboardingEyebrowComputer => 'Komputer';

  @override
  String get onboardingEyebrowAutomation => 'Automatyzacja';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingIntroCouldNotLoad => 'Nie udało się wczytać wstępu.';

  @override
  String get onboardingModelDescription =>
      'Wybierz model, którego NeoAgent powinien używać domyślnie, lub pozwól mu wybrać automatycznie.';

  @override
  String get onboardingLoadingModels => 'Ładowanie modeli…';

  @override
  String get noAiModelTitle => 'Nie skonfigurowano jeszcze żadnego modelu AI';

  @override
  String get noAiModelBody =>
      'Dodaj klucz API od dostawcy takiego jak OpenAI, Anthropic lub Google. Następnie NeoAgent pokaże modele, których możesz użyć.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent potrzebuje modelu AI, aby odpowiedzieć. Dodaj klucz API od dostawcy takiego jak OpenAI, Anthropic lub Google.';

  @override
  String get noAiModelAdminHint =>
      'Jako administrator możesz także skonfigurować dostawców dla wszystkich w zakładce Administrator → Dostawcy.';

  @override
  String get addApiKey => 'Dodaj klucz API';

  @override
  String onboardingMessagingConnected(String platform) {
    return 'Połączono z $platform.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Oczekiwanie na połączenie $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Nie można zapisać konfiguracji: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Gotowe';

  @override
  String get onboardingStepRequired => 'Wymagane';

  @override
  String get onboardingStepOptional => 'Opcjonalne';

  @override
  String get onboardingStepCloudOrLocal => 'Chmura lub lokalnie';

  @override
  String get onboardingStepComputer => 'Komputer';

  @override
  String get onboardingStepRoutines => 'Automatyzacje';

  @override
  String get onboardingComputerChoiceTitle => 'Gdzie ma\npracować?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Możesz wybrać inny komputer dla każdej sesji.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Prywatne środowisko · zawsze dostępne';

  @override
  String get onboardingThisComputer => 'Ten komputer';

  @override
  String get onboardingThisComputerSubtitle =>
      'Twoje pliki, aplikacje i przeglądarka';

  @override
  String get onboardingSearchApps => 'Wyszukaj aplikacje…';

  @override
  String get onboardingRoutinesDescription =>
      'Wyniki pojawiają się w Twoich czatach.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Wyniki pojawiają się jako powiadomienia.';

  @override
  String get onboardingNotifications => 'Powiadomienia';

  @override
  String get onboardingReadyTitle => 'Wszystko\ngotowe.';

  @override
  String get onboardingReadyDescription => 'Wyślij swoją pierwszą wiadomość.';

  @override
  String get onboardingMessageNeoagent => 'Wyślij wiadomość do NeoAgenta';

  @override
  String get onboardingAskAnything => 'Zapytaj o cokolwiek…';

  @override
  String get onboardingOpenNeoagent => 'Otwórz NeoAgenta';

  @override
  String get onboardingStarterTrip => 'Zaplanuj weekendową wycieczkę';

  @override
  String get onboardingStarterLanding => 'Zbuduj stronę docelową';

  @override
  String onboardingQuickSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prostych kroków',
      few: '$count proste kroki',
      one: '$count prosty krok',
    );
    return '$_temp0';
  }

  @override
  String get taskNeedsEmail => 'Najpierw połącz e-mail';

  @override
  String get taskNeedsCalendar => 'Najpierw podłącz kalendarz';

  @override
  String get taskNeedsModel => 'Najpierw skonfiguruj model AI';

  @override
  String get taskPromptDailyRecap =>
      'Podsumuj mój dzień: podsumuj dzisiejsze rozmowy, zakończoną pracę i decyzje, a następnie wypisz wszystko, czym powinienem się zająć jutro. Zapisz to krótko i wyślij do mnie.';

  @override
  String get taskPromptInboxCheck =>
      'Sprawdź moją skrzynkę odbiorczą pod kątem wiadomości, które dotarły od ostatniego sprawdzenia. Wysyłaj mi wiadomości tylko o e-mailach, które są pilne lub wymagają odpowiedzi, z jednowierszowym podsumowaniem każdego z nich. Jeśli nic nie wymaga mojej uwagi, nie wysyłaj niczego.';

  @override
  String get taskPromptMorningBriefing =>
      'Przygotuj moją poranną odprawę: dzisiejszą pogodę w miejscu, w którym się znajduję, wydarzenia w moim kalendarzu i najważniejsze otwarte pozycje, o których wiem. Wyślij go jako krótką, możliwą do zeskanowania wiadomość.';

  @override
  String get taskPromptTomorrowPrep =>
      'Spójrz na mój kalendarz na jutro. O każdym spotkaniu powiedz mi, czego dotyczy, kto jest w nim zaangażowany i co powinienem przygotować. Jeśli jutro będzie puste, nic nie wysyłaj.';

  @override
  String get taskPromptNewsDigest =>
      'Poszukaj w sieci najważniejszych wiadomości dzisiejszego dnia na tematy, które mnie interesują (wykorzystaj to, co pamiętasz o moich zainteresowaniach). Wyślij mi streszczenie składające się z maksymalnie pięciu elementów, każdy zawierający jedno zdanie i link.';

  @override
  String get taskPromptWeeklyReview =>
      'Przejrzyj mój tydzień: co udało się zrobić, co się nie udało, a co nadal jest otwarte. Zaproponuj trzy najważniejsze rzeczy, na których warto się skupić w przyszłym tygodniu.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Połącz numer telefonu należący do agenta. Każda osoba, której zezwolisz, może z nim rozmawiać na czatach bezpośrednich i w grupach.';

  @override
  String get whatsappSelfChatDescription =>
      'Połącz swój własny numer i porozmawiaj z agentem na czacie „Napisz do siebie”. Każdy inny czat i grupa na tym koncie jest ignorowana.';

  @override
  String get chatSendHintMac => '⌘↵, aby wysłać';

  @override
  String get chatSendHintOther => 'Ctrl+Enter, aby wysłać';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Dla tego punktu końcowego wymagany jest podstawowy adres URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Zmieniony adres e-mail jest potwierdzany przed jego wykorzystaniem.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Decyzja znajdująca się wyżej w łańcuchu wygrywa.';

  @override
  String get aDeletedAccount => 'usunięte konto';

  @override
  String get aFridayLookBackAtThe =>
      'W piątek podsumowanie tygodnia i plan na następny.';

  @override
  String get aKeyThatAsksForA =>
      'Klucz, który wymaga podania kodu PIN lub odcisku palca, zastępuje również kod dwuskładnikowy.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Model językowy ocenił ten komunikat, ponieważ SystemOne jest wyłączony.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Plik metadanych instalacji NeoAgent przekroczył bezpieczny limit rozmiaru.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Na serwerze dostępna jest nowsza kompilacja internetowa. Załaduj ponownie, aby pobrać najnowszy pakiet.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Prywatny pulpit z Chromium, plikami, edytorem tekstu, terminalem i Pythonem. Twoja praca jest zapisywana pomiędzy sesjami.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Prywatny komputer z systemem Linux lub urządzenie z systemem Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Nie można pobrać wymaganego pliku instalacyjnego NeoAgent.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Członek drużyny wysyła Ci link z zaproszeniem. Kiedy już to zaakceptujesz, oni ';

  @override
  String get aTeammateSentYouAnInvite =>
      'członek drużyny wysłał Ci link z zaproszeniem. Wprowadź go tutaj, aby dołączyć do jego zespołu.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Tymczasowe pobranie zostanie usunięte później.';

  @override
  String get aValueIsStored => 'Wartość jest przechowywana.';

  @override
  String get access => 'Dostęp';

  @override
  String get accessActivity => 'Aktywność dostępu';

  @override
  String accessArg1(Object? arg1) {
    return 'Dostęp: $arg1';
  }

  @override
  String get accessMode => 'Tryb dostępu';

  @override
  String get accessPermissions => 'Uprawnienia dostępu';

  @override
  String get accessToken => 'token dostępu';

  @override
  String get accessToken2 => 'Token dostępu';

  @override
  String get account => 'Konto';

  @override
  String accountArg1(Object? arg1) {
    return 'Konto #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Powiadomienia o zmianie konta';

  @override
  String get accountEmail => 'Adres e-mail konta';

  @override
  String get accountEmailIsOffUntilThese =>
      'Adres e-mail konta jest wyłączony, dopóki nie zostaną ustawione następujące ustawienia: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent używa tego języka w całej aplikacji. Przy pierwszym logowaniu wybiera język tego urządzenia. Później Twój wybór jest zapisywany na koncie i stosowany na wszystkich urządzeniach.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nie można zmienić języka: $error';
  }

  @override
  String get accountLanguageTitle => 'Język';

  @override
  String get accountNumber => 'Numer konta';

  @override
  String get accountSettings => 'Ustawienia konta';

  @override
  String get accounts => 'Konta';

  @override
  String get accountsByTokensUsedAllTime =>
      'Konta według wykorzystanych tokenów, cały czas.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'komputery w chmurze kont. Zmiany obowiązują po serwerze ';

  @override
  String get accountsOnThisServer => 'Konta na tym serwerze';

  @override
  String get active => 'Aktywny';

  @override
  String get activeSessions => 'Aktywne sesje';

  @override
  String get activeToday => 'Aktywnie dzisiaj';

  @override
  String get add => 'Dodaj';

  @override
  String get addAProviderCredentialFirstIts =>
      'Najpierw dodaj poświadczenia dostawcy. Jej modele pojawiły się tu raz ';

  @override
  String get addAgent => 'Dodaj agenta';

  @override
  String get addAnotherSignInMethodBefore =>
      'Dodaj inną metodę logowania przed usunięciem tej.';

  @override
  String get addBinding => 'Dodaj wiązanie';

  @override
  String get addByNameOrId => 'Dodaj według nazwy lub identyfikatora';

  @override
  String get addByNameOrIdInstead =>
      'Zamiast tego dodaj według nazwy lub identyfikatora';

  @override
  String get addCredentialBinding => 'Dodaj powiązanie poświadczeń';

  @override
  String get addEntry => 'Dodaj wpis';

  @override
  String get addKey => 'Dodaj klucz';

  @override
  String get addMcpServer => 'Dodaj serwer MCP';

  @override
  String get addMemory => 'Dodaj pamięć';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Dodaj większą długość lub inny typ znaku.';

  @override
  String get addPeopleOrGroups => 'Dodaj osoby lub grupy';

  @override
  String get addSecurityKey => 'Dodaj klucz bezpieczeństwa';

  @override
  String get addSomeoneOrAGroup => 'Dodaj osobę lub grupę';

  @override
  String get addTask => 'Dodaj zadanie';

  @override
  String get addTests => 'Dodaj testy';

  @override
  String get addTestsForThePartsOf =>
      'Dodaj testy dla części projektu, które mają najmniejsze pokrycie, a następnie uruchom je.';

  @override
  String get addTheirOwnKeysInSettings => 'dodaj własne klucze w Ustawieniach.';

  @override
  String get addToPrompt => 'Dodaj do monitu';

  @override
  String get added => 'Dodano';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Dodano $arg1 · Ostatnio używane $arg2';
  }

  @override
  String get addressWithTheProvider => 'adres u dostawcy.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Dostosuj głośność głośnika, przejrzyj domyślne ustawienia przycisków sprzętowych i zarządzaj sesją programu uruchamiającego.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Dostosuj filtr wyszukiwania lub statusu, aby wyświetlić więcej kanałów przesyłania wiadomości.';

  @override
  String get adjustTheSpeakerVolumeHere => 'Tutaj dostosuj głośność głośnika.';

  @override
  String get admin => 'Administrator';

  @override
  String adminArg1(Object? arg1) {
    return 'Administrator › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Tutaj pojawiają się uprawnienia administratora, linki z zaproszeniami i zmiany w zarządzaniu.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Zaawansowany harmonogram ręczny dla przypadków specjalnych.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Zaawansowane: minuta godzina dzień miesiąc dzień powszedni.';

  @override
  String get againRightAway => 'od razu znowu.';

  @override
  String get agent => 'Agent';

  @override
  String agentArg1(Object? arg1) {
    return 'Agent: $arg1';
  }

  @override
  String get agentCalls => 'Telefony agenta';

  @override
  String get agentCommunication => 'Komunikacja agenta';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Komunikacja agenta: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Tryb agenta edytuje obszar roboczy · ⌘↵ wyślij · ⌘N nowa sesja';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agent wstrzymuje działanie i prosi o zgodę przed wykonaniem zadania.';

  @override
  String get agentProfile => 'Profil agenta';

  @override
  String get agentVisibleName => 'Nazwa widoczna dla agenta';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agent chce użyć $arg1. Kliknij, aby podjąć decyzję.';
  }

  @override
  String get agents => 'Agenci';

  @override
  String get aiAnswerUnreadable => 'Odpowiedź AI jest nieczytelna';

  @override
  String get aiProviderKeys => 'Klucze dostawcy AI';

  @override
  String get aiUnavailable => 'Sztuczna inteligencja niedostępna';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'alerty i inne wiadomości e-mail z konta.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Alerty, gdy połączenie komunikacyjne wymaga uwagi użytkownika';

  @override
  String get all => 'Wszystko';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Wszyscy agenci ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Wszystkie $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Wszystkie miejsca na komputery w chmurze są obecnie używane. Spróbuj ponownie za chwilę.';

  @override
  String get allComputerSlotsAreBusy => 'Wszystkie gniazda komputera są zajęte';

  @override
  String get allTables => 'Wszystkie tabele';

  @override
  String get allTime => 'Cały czas';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Wszystkie narzędzia są dozwolone — agent może korzystać z dowolnej możliwości bez pytania. ';

  @override
  String get allow => 'Zezwól';

  @override
  String get allowedRunsWithoutAsking => 'Dozwolone. Ucieka bez pytania.';

  @override
  String get allowAll => 'Zezwalaj na wszystko';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Zezwól na opcję „Zainstaluj nieznane aplikacje” dla NeoAgent, a następnie ponów próbę aktualizacji.';

  @override
  String get allowOnce => 'Pozwól raz';

  @override
  String get allowSender => 'Zezwól nadawcy';

  @override
  String get allowSession => 'Zezwól na sesję';

  @override
  String get allowTheAgentToStartAn =>
      'Pozwól agentowi rozpocząć z Tobą rozmowę głosową w aplikacji.';

  @override
  String get allowedOrigins => 'Dozwolone pochodzenie';

  @override
  String get allowedPathPrefix => 'Dozwolony prefiks ścieżki';

  @override
  String get allowsYouCanChangeThatPer =>
      'pozwala. Możesz to później zmienić dla każdej osoby. Linki nigdy nie są udostępniane ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'należy już do istniejącego konta';

  @override
  String get alreadyLinkedToAnotherAccount => 'już połączone z innym kontem';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'już połączone z innym kontem neoagenta';

  @override
  String get alreadyUsed => 'już używany';

  @override
  String get always => 'Zawsze';

  @override
  String get alwaysAllow => 'Zawsze pozwalaj';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Opcja „Zawsze zezwalaj” zapisuje politykę na stałe — możesz ją zmienić w Ustawieniach.';

  @override
  String get alwaysAsk => 'Zawsze pytaj';

  @override
  String get alwaysEngage => 'Zawsze angażuj się';

  @override
  String get alwaysJoins => 'Zawsze dołącza';

  @override
  String get anApiKeyIsRequired => 'Wymagany jest klucz API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Wieczorne podsumowanie tego, co się wydarzyło i co należy kontynuować.';

  @override
  String get anHttpOrHttpsUrlIs => 'Wymagany jest adres URL http lub https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'i analityka. Linki do zespołu znajdują się na stronie zespołu.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Instalacja pakietu APK na Androida jest niedostępna na tej platformie.';

  @override
  String get androidApp => 'Aplikacja na Androida';

  @override
  String get androidControl => 'Sterowanie Androidem';

  @override
  String get androidCouldNotStart => 'Nie można uruchomić Androida';

  @override
  String get androidNotificationReceived =>
      'Otrzymano powiadomienie o Androidzie';

  @override
  String get androidOnly => 'Tylko na Androida';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Nie można otworzyć instalatora pakietu dla systemu Android.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Ekran Androida — dotknij, aby dotknąć, przeciągnij, aby przesunąć';

  @override
  String get androidSdk => 'SDK dla Androida';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Odpowiada na @wzmianki dotyczące problemów i żądań ściągnięcia';

  @override
  String get anyone => 'Ktokolwiek';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Każdy na tej platformie może wysyłać wiadomości do $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Każdy na tej platformie może wysyłać wiadomości $arg1 w $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Każdy, kto może uzyskać dostęp do tego konta, może rozmawiać z $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Każda osoba posiadająca link może dołączyć do momentu jego wygaśnięcia lub cofnięcia przez Ciebie.';

  @override
  String get apiHttpsOrigin => 'Pochodzenie API HTTPS';

  @override
  String get apiKey => 'Klucz API';

  @override
  String get apiKey2 => 'klucz API';

  @override
  String get apiKey3 => 'Klucz API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'klucz api antropiczny claude openai gpt xai grok google gemini minimax nvidia nim dane uwierzytelniające openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Klucze API i punkty końcowe dla dostawców sztucznej inteligencji, wyszukiwania i usług głosowych. Oni ';

  @override
  String get apiRequest => 'Żądanie API';

  @override
  String get apiYourOwnServerASelf =>
      'API – Twój własny serwer, model hostowany samodzielnie lub inny ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Pobieranie pliku APK nie powiodło się przy użyciu protokołu HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Nazwa aplikacji jest wymagana.';

  @override
  String get appUpdates => 'Aktualizacje aplikacji';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Aktualizacje aplikacji nie są skonfigurowane dla tej kompilacji.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Zastosowano kolejkowane aktualizacje sterowania $arg1 do bieżącego przebiegu.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Zastosowano aktualizacje układu kierowniczego $arg1.';
  }

  @override
  String get apply => 'Zastosuj';

  @override
  String get applyBehaviorNotes => 'Zastosuj uwagi dotyczące zachowania';

  @override
  String get applyCoreMemory => 'Zastosuj pamięć rdzeniową';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Prośby o zatwierdzenie wrażliwych narzędzi agenta';

  @override
  String get approvalRequired => 'Wymagana zgoda';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Zatwierdzenie odbywa się w trakcie uwierzytelnionej sesji mobilnej, a każdy kod wygasa automatycznie po krótkim czasie.';

  @override
  String get approveLogin => 'Zatwierdź logowanie';

  @override
  String get approveQrLogin => 'Zatwierdź logowanie QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Zatwierdź to tylko wtedy, gdy logowanie na tym urządzeniu zostało rozpoczęte właśnie teraz.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Zatwierdzony login dla $arg1.';
  }

  @override
  String get approvedOnly => 'Tylko zatwierdzone';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Zatwierdzone parowanie dla $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Zatwierdzone osoby i grupy';

  @override
  String get approvedPeopleOnly => 'Tylko zatwierdzone osoby';

  @override
  String get archive => 'Archiwum';

  @override
  String get archiveAgent => 'Agent archiwalny?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archiwum ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archiwizować $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Zarchiwizować wybrane wspomnienia?';

  @override
  String get areSharedByEveryAccountOn =>
      'są współdzielone przez każde konto na tym serwerze; konta nadal mogą ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return 'Wejście \$$arg1 / 1M';
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
    return 'Wymagany dostęp do $arg1';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Konta $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktywny';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Dodano $arg1. Edytuj go w dowolnym momencie, aby zmienić ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1” i jego historia uruchomień zostaną trwale usunięte. Każdy aktywny bieg zostanie zatrzymany. Pliki w obszarze roboczym nie są dotykane.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Wymagana atest $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aktywne aplikacje $arg1';
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
    return '$arg1 (aktywne narzędzia $arg2)';
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
    return '$arg1 $arg2 zmieniono';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 znaków';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Utworzono $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [lokalny uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 pasujący do „$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}Przestrzeń robocza NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\nNowe konta $arg2';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 działa · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 ($arg2)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · Próbki $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · Sterowanie $arg2 w kolejce';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nTokeny $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Tokeny $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 i $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 został administratorem ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bajtów';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Kanał $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return 'Znaki $arg1';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 wyczyszczone.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return 'Skonfigurowano $arg1';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 podłączony. Wybierz repozytoria i osoby w sekcji Kto może wysyłać wiadomości.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Podstawowe wpisy $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 utworzył link z zaproszeniem';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Pulpit $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Zdarzenia $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 nie powiodło się';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return 'Błąd $arg1';
  }

  @override
  String arg1Failing(Object? arg1) {
    return 'Awaria $arg1';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 dla $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 grupy tylko oznaczone';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h temu';
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
    return 'Pomocnicy $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(Współczynnik trafień $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 jest administratorem, więc konta nie można usunąć ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 jest zablokowany na $arg2. Zaktualizuj listę dostępu, aby umożliwić odpowiedzi.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 jest podłączony i odpowiada.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 nie jest już administratorem ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 nie jest dostępny na $arg2 (brak uprawnień wykonawczych lub zależności).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 dołączył pod $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 oceniony przez LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Skonfigurowano klucz $arg1$arg2';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Usunięto klucz $arg1.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 w lewo';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 opuścił $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return 'Połączono $arg1';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m temu';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m $arg2';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Upewnij się, że działa, a następnie spróbuj ponownie.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 zarządza tym kontem';
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
    return '$arg1 min $arg2 sek';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Modele $arg1 gotowe';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 więcej';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 więcej kroków w historii uruchomień';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 przeniesiono z $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 musi być liczbą skończoną.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 musi być adresem http:// lub https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 wymaga uwagi';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Przestrzeń robocza $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nowe konta w ostatnim $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nowe wiadomości kierują tym przebiegiem';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return 'Nowe przebiegi $arg1';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 zarządza teraz tym kontem.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return 'Dozwolone $arg1 z 4 uprawnieniami. Pliki są ograniczone do folderu NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 lub $arg2 włączone';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 z grup $arg2 dołącza do zwykłego czatu';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return 'Modele $arg1 lub $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return 'Gotowe modele $arg1 i $arg2';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 zestawu $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Dozwolone narzędzia $arg1 lub $arg2';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 w dniu $arg2 o $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 odpowiada tylko osobom, które dodasz poniżej.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 odpowiada tylko wtedy, gdy jest oznaczony';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 rozmawia tylko z osobami i grupami, które zatwierdzisz';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Dodano osoby lub grupy $arg1';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Planowanie $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Dostawcy $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 gotowy';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Rekordy $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI przekierowania $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return 'Zarejestrowano $arg1';
  }

  @override
  String arg1Replied(Object? arg1) {
    return 'odpowiedział $arg1';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 unieważnił link z zaproszeniem';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 działa';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 działa · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 działa w ostatnim $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 zapisano.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Wybrano $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Pokazano $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 zachował spokój';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return 'Sterowanie $arg1 $arg2 w kolejce';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · dotknij węzła, który chcesz sprawdzić';
  }

  @override
  String arg1Steps(Object? arg1) {
    return 'Stopnie $arg1';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 przestał zarządzać $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Tokeny $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Tokeny $arg1 w ostatnim $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Narzędzia $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (niedostępne zapisane nadpisanie)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% wykorzystane · Pozostało $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 chce z tobą porozmawiać.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'Sieć $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '„$arg1” zostanie trwale usunięty.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 będzie zarządzać tym kontem';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 nie odpowie na tej platformie';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 nie odpowie na $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Przechowywanie artefaktów przez użytkownika';

  @override
  String get askAQuestionOrStartA => 'Zadaj pytanie lub rozpocznij zadanie...';

  @override
  String get askBeforeClosingToBackground => 'Zapytaj przed zamknięciem w tle';

  @override
  String get askMe => 'Zapytaj mnie';

  @override
  String get assignedAgent => 'Przypisany agent';

  @override
  String get assignedAgent2 => 'Przydzielony agent';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Przypisany agent: $arg1';
  }

  @override
  String get assigneeOptional => 'Osoba przypisana (opcjonalnie)';

  @override
  String get assistant => 'Asystent';

  @override
  String get assistantKey131 => 'Klucz asystenta 131';

  @override
  String get atLeast1 => 'Przynajmniej 1.';

  @override
  String get atLeast1000AppliesAfterA =>
      'Co najmniej 1000. Obowiązuje po ponownym uruchomieniu serwera.';

  @override
  String get attachFiles => 'Dołącz pliki';

  @override
  String attentionArg1(Object? arg1) {
    return 'Uwaga $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'dziennik audytu uprawnienia administratora unieważnij historię zespołu zaproszeń';

  @override
  String get authMethod => 'Metoda uwierzytelniania';

  @override
  String get authServerUrl => 'Adres URL serwera uwierzytelniania';

  @override
  String get authentication => 'Uwierzytelnianie';

  @override
  String get authenticationFailed => 'Uwierzytelnienie nie powiodło się.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Uwierzytelnianie nie zostało jeszcze zakończone. Dokończ logowanie w przeglądarce i spróbuj ponownie.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Uwierzytelnianie nie zostało jeszcze zakończone. Dokończ logowanie w przeglądarce i odśwież.';

  @override
  String get authenticationTimedOut => 'Upłynął limit czasu uwierzytelniania.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Uwierzytelnianie zostało anulowane przed zakończeniem.';

  @override
  String get authenticatorApp => 'Aplikacja uwierzytelniająca';

  @override
  String get authenticatorCode => 'Kod uwierzytelniający';

  @override
  String get authorOptional => 'Autor (opcjonalnie)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (pierwszy dostawca z kluczem API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatyczne wyznaczanie tras do najlepszego dostępnego modelu';

  @override
  String get automaticFast => 'Automatyczny (szybki)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatyczny odczytuje pomieszczenie i zwykle się wstrzymuje. Opcja „Tylko wzmianka” nie powoduje podjęcia decyzji, dopóki nie zostanie bezpośrednio rozwiązana.';

  @override
  String get automaticReserved => 'Automatyczny, zarezerwowany';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatyczne wycofanie wymaga ponownej próby na ekranie konfiguracji.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatycznie wybiera szybki model z normalnego katalogu modeli.';

  @override
  String get automation => 'Automatyzacja';

  @override
  String get available => 'Dostępne';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Dostępne ponownie w $arg1';
  }

  @override
  String get availableAgainShortly => 'Wkrótce znów dostępny';

  @override
  String get availableInTheDesktopAppFor =>
      'Dostępne w aplikacji komputerowej dla systemów macOS, Windows i Linux';

  @override
  String get availableToTheAgent => 'Dostępne dla agenta';

  @override
  String get averageAllTime => 'Średnio, cały czas';

  @override
  String get avgImp => 'Śr. wyśw.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Średnia/run: tokeny $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Unikaj powtarzających się znaków i oczywistych sekwencji.';

  @override
  String get awaitingScan => 'Oczekiwanie na skanowanie';

  @override
  String get back => 'Powrót';

  @override
  String backgroundTaskCount(Object? count) {
    return 'W tle $count';
  }

  @override
  String get backgroundTasks => 'Zadania w tle';

  @override
  String get backOn => 'z powrotem.';

  @override
  String get backToChat => 'Wróć do czatu';

  @override
  String get backToFolder => 'Powrót do folderu';

  @override
  String get backToSignIn => 'Wróć do logowania';

  @override
  String get backendChannel => 'Kanał backendowy';

  @override
  String get backendOnThisComputer => 'Backend na tym komputerze';

  @override
  String get backendSync => 'Synchronizacja backendu';

  @override
  String get backgroundLocationNeeded => 'Wymagana lokalizacja w tle';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Synchronizacja w tle pozostaje zaplanowana na Androidzie';

  @override
  String get badState => 'Zły stan: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Podstawowy obraz i rozmiar uruchomionych maszyn wirtualnych QEMU ';

  @override
  String get baseUrlOptional => 'Podstawowy adres URL (opcjonalnie)';

  @override
  String get baseUrlTokenLocal => 'podstawowy token adresu URL lokalny';

  @override
  String get basicAuthentication => 'Podstawowe uwierzytelnianie';

  @override
  String get behaviorModules => 'Moduły zachowania';

  @override
  String get behaviorNotes => 'notatki z zachowania';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Broker poświadczeń Bitwarden';

  @override
  String get bitwardenItem => 'Przedmiot Bitwardena';

  @override
  String get bitwardenServer => 'Serwer Bitwardena';

  @override
  String get blankUsesCommon => 'Blank używa „wspólnego”';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank używa domyślnego wywołania zwrotnego';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Puste wartości korzystają z wartości domyślnych dostawcy.';

  @override
  String get block => 'Blok';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Zablokowano wiadomość przychodzącą od $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Mostek kompatybilny z BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'Adres URL serwera BlueBubbles';

  @override
  String get botToken => 'Token bota';

  @override
  String get botTokenAndApprovedChats => 'Token bota i zatwierdzone czaty';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token bota i dostęp do serwera/kanału';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token bota, interfejs Events API i dostęp do kanału';

  @override
  String get botUserId => 'Identyfikator użytkownika bota';

  @override
  String get botUsername => 'Nazwa użytkownika bota';

  @override
  String get brandName => 'Nazwa marki';

  @override
  String get braveSearch => 'Odważne poszukiwania';

  @override
  String get breakdown => 'Podział:';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Połącz dowolnego dostawcę, który może publikować i odbierać ładunki webhooka.';

  @override
  String get bringYourOwnKey => 'przynieś swój własny klucz';

  @override
  String get bringYourOwnKey2 => 'Przynieś swój własny klucz';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Przeglądarka, pulpit systemu Linux, pliki, terminal i język Python współdzielą jeden stały komputer w chmurze.';

  @override
  String get browserLogin => 'Logowanie do przeglądarki';

  @override
  String get browserScripting => 'Skrypty przeglądarki';

  @override
  String get call => 'Zadzwoń';

  @override
  String get callAgent => 'Zadzwoń do agenta';

  @override
  String get callUser => 'Zadzwoń do użytkownika';

  @override
  String get calledByName => 'Nazywany po imieniu';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Potrafi delegować zadania innym agentom';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Można delegować do $arg1';
  }

  @override
  String get canReceiveDelegatedTasks =>
      'Potrafi przyjmować delegowane zadania';

  @override
  String get cancel => 'Anuluj';

  @override
  String get cancelTask => 'Anuluj zadanie';

  @override
  String candidateCountArg1(Object? arg1) {
    return 'Liczba kandydatów: $arg1';
  }

  @override
  String get cannotPreview => 'Nie można wyświetlić podglądu';

  @override
  String get cannotReceiveDelegatedTasks =>
      'nie może przyjmować delegowanych zadań';

  @override
  String get cannotRunYet => 'nie można jeszcze biegać.';

  @override
  String get capturedThePage => 'Przechwycono stronę';

  @override
  String get category => 'Kategoria';

  @override
  String chainArg1(Object? arg1) {
    return 'Łańcuch: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Zmień tryb konfiguracji';

  @override
  String get channel => 'Kanał';

  @override
  String get channelAccessToken => 'Token dostępu do kanału';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanał: $arg1$arg2 | Wersja aktualizacji: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory =>
      'Pamięć społeczna ograniczona do kanału';

  @override
  String get channels => 'Kanały';

  @override
  String get chat => 'Czat';

  @override
  String get chatId => 'Identyfikator czatu';

  @override
  String get chatMode => 'Tryb czatu';

  @override
  String get chatModel => 'Model czatu';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Sprawdź automatycznie po uruchomieniu';

  @override
  String get checkForMessagesEveryMs => 'Sprawdzaj wiadomości co (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automatycznie sprawdzaj dostępność nowych wiadomości';

  @override
  String get checkNow => 'Sprawdź teraz';

  @override
  String get checkYourEmailToConfirmYour =>
      'Przed zalogowaniem sprawdź swoją pocztę e-mail, aby potwierdzić swoje konto NeoAgent.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Sprawdzone $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Wybierz kategorię lub przeszukaj wszystkie ustawienia.';

  @override
  String get chooseAPerson => 'Wybierz osobę';

  @override
  String get chooseAProjectFolder => 'Wybierz folder projektu';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Wybierz ustawienia domyślne dla czatu, agentów, zachowania awaryjnego i inteligentnego routingu.';

  @override
  String get chooseGroups => 'Wybierz grupy';

  @override
  String get chooseHowMuchYouWantTo =>
      'Wybierz, ile chcesz teraz skonfigurować. Obie opcje można później zmienić.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Wybierz sposób rozpoczęcia tego zadania. Ręczne uruchamianie tylko w trybie Uruchom teraz. Harmonogram jest oparty na czasie. Integracja wyzwala ogień z podłączonych oficjalnych aplikacji.';

  @override
  String get chooseOneToGetStartedNow =>
      'Wybierz jeden, aby zacząć już teraz. Możesz dodać więcej później.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Wybierz model na żywo i głos w Ustawieniach.';

  @override
  String get chooseTheirGroup => 'Wybierz ich grupę';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Wybierz, gdzie ta osoba powinna mieć możliwość rozmowy z $arg1. Możesz to zmienić później w sekcji Kto może wysyłać wiadomości.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Wybierz, do których grup $arg1 powinien dołączyć, nawet jeśli nikt go nie oznaczy. Ta platforma może nie odróżniać tagów od zwykłych wiadomości.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Wybierz, które modele może wybrać każde konto na tym serwerze ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Wybierz, z kim $arg1 rozmawia i kiedy dołącza do czatów grupowych.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Wybierz, kto może uzyskać dostęp do $arg1, a następnie zapisz zmiany.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Wybierz, kto może wysyłać wiadomości do agenta, za pomocą opcji „Kto może wysyłać wiadomości” na karcie WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Wybierz swój\ndomyślny model.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, pliki, edytor tekstu i terminal są dostępne na pulpicie systemu Linux.';

  @override
  String get claudeCode => 'Claude\'a Koda';

  @override
  String get clear => 'Wyczyść';

  @override
  String get clearAll => 'Wyczyść wszystko';

  @override
  String clearArg1(Object? arg1) {
    return 'Wyczyścić $arg1?';
  }

  @override
  String get clearFilter => 'Wyczyść filtr';

  @override
  String get clearFilters => 'Wyczyść filtry';

  @override
  String get clearSearch => 'Wyczyść wyszukiwanie';

  @override
  String get clearView => 'Wyczyść widok';

  @override
  String get cliSession => 'Sesja CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'kliknięcie nie jest obsługiwane na tej platformie.';

  @override
  String get clickOnceToBeginCapturing =>
      'Kliknij raz, aby rozpocząć przechwytywanie';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Klikaj, pisz i korzystaj z aplikacji komputerowych.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Kliknięto w ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Kliknięty w przeglądarce';

  @override
  String get clientId => 'Identyfikator klienta';

  @override
  String get clientSecret => 'Sekret klienta';

  @override
  String get close => 'Zamknij';

  @override
  String get closeJ => 'Zamknij (⌘J)';

  @override
  String get closeTeachMode => 'Zamknij tryb uczenia';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Zamknięcie okna może spowodować, że NeoAgent będzie działał w tle z dostępem do zasobnika lub całkowicie zakończy działanie pulpitu.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Obsługiwane są instancje w chmurze i hostowane samodzielnie. Adresy URL sieci lokalnej i prywatnej działają, jeśli NeoAgent może do nich dotrzeć.';

  @override
  String get cloudComputer => 'Komputer w chmurze';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Komputer w chmurze · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Ustawienia komputera w chmurze zostały zapisane. Uruchom ponownie serwer, aby je zastosować.';

  @override
  String get cloudComputerVm => 'Komputer w chmurze (VM)';

  @override
  String get cloudComputers => 'Komputery w chmurze';

  @override
  String get codeHosting => 'Hosting kodu';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Nazwy kanałów rozdzielane przecinkami, bez znaku #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Oddzielone przecinkami, na przykład #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Oddzielone przecinkiem. Problem musi mieć je wszystkie.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Polecenie nie powiodło się ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Wymagane jest polecenie.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Akumulator wyjścia poleceń nie jest aktywny.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Przesyłanie danych wyjściowych polecenia nie powiodło się ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Przesyłanie danych wyjściowych polecenia pominęło metadane artefaktów.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Dane wyjściowe polecenia zostały już ukończone.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Polecenia i aplikacje';

  @override
  String get commandsRunInTheSamePersistent =>
      'Polecenia są uruchamiane na tym samym stałym komputerze, z którego korzysta widoczny pulpit.';

  @override
  String get communityChatops => 'Społeczność i ChatOps';

  @override
  String get completeSetup => 'Zakończ konfigurację';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Zakończ przepływ pracy na pulpicie.';

  @override
  String get completed => 'Ukończono';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Całkowicie zablokowany — agent nie może korzystać z tej kategorii.';

  @override
  String get computerShell => 'Obudowa komputera';

  @override
  String get computerUsedByThisSession => 'Komputer używany w tej sesji';

  @override
  String get computerWorkspace => 'Obszar roboczy komputera';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigurowalny osobisty mostek webhook';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigurowalny przekaźnik lub mostek webhook';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigurowalny most webhook Talk';

  @override
  String get configurableWebInboxBridge =>
      'Konfigurowalny mostek internetowej skrzynki odbiorczej';

  @override
  String get configurableWebhookBridge => 'Konfigurowalny most webhook';

  @override
  String get configurableWebhooks => 'Konfigurowalne webhooki';

  @override
  String get configurationOrInTheEnvFile => 'Konfiguracja lub w pliku .env.';

  @override
  String get configure => 'Skonfiguruj';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Skonfiguruj zachowanie obszaru roboczego i ustawienia domyślne modelu.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Skonfigurowano $arg1';
  }

  @override
  String get confirmEmailChanges => 'Potwierdź zmiany adresu e-mail';

  @override
  String get confirmNewSignUps => 'Potwierdź nowe rejestracje';

  @override
  String get confirmPassword => 'Potwierdź hasło';

  @override
  String get confirmPassword2 => 'Potwierdź hasło';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Przed zalogowaniem potwierdź swój adres e-mail. Sprawdź wiadomość e-mail dotyczącą usługi od NeoAgent.';

  @override
  String get connect => 'Połącz';

  @override
  String get connectAMessagingPlatform =>
      'Podłącz platformę do\nprzesyłania wiadomości.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Połącz publiczny punkt końcowy HTTPS Home Assistant z długotrwałym tokenem dostępu. Adresy sieci lokalnej, sprzężenia zwrotnego i prywatnego są blokowane przez serwer.';

  @override
  String get connectAccount => 'Połącz konto';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Połącz konta aplikacji indywidualnie, aby sztuczna inteligencja mogła używać odpowiedniego konta do każdej oficjalnej integracji.';

  @override
  String connectArg1(Object? arg1) {
    return 'Podłącz $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Połącz tyle kont, ile chcesz. Każda aplikacja może korzystać z innego konta.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Połącz kanały, wybierz, z kim $arg1 rozmawia i oglądaj ostatnią aktywność.';
  }

  @override
  String get connectInstance => 'Połącz instancję';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Najpierw połącz tę integrację, aby wybrać konto.';

  @override
  String get connectToThisServer => 'Połącz się z tym serwerem';

  @override
  String get connectWhatsapp => 'Połącz WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Połącz swoją instancję Nextcloud, w tym serwery hostowane samodzielnie. NeoAgent otwiera własną stronę logowania Nextcloud, dzięki czemu możesz zalogować się przy użyciu hasła, logowania jednokrotnego lub 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Połącz się z własnym serwerem NeoRecall. Po zatwierdzeniu ekranu OAuth NeoAgent uzyskuje dostęp tylko do odczytu do wyszukiwania lokalnego, wspomnień i dowodów transkrypcji.';

  @override
  String get connected => 'Połączono';

  @override
  String get connectedAccount => 'Połączone konto';

  @override
  String connectedArg1(Object? arg1) {
    return 'Połączono $arg1';
  }

  @override
  String get connectedInstance => 'Połączona instancja';

  @override
  String get connectedNeorecallUser => 'Połączony użytkownik NeoRecall';

  @override
  String get connectedNextcloudUser => 'Połączony użytkownik Nextcloud';

  @override
  String get connectedServer => 'Podłączony serwer';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Łączenie z modelem głosu na żywo...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Połączenie #$arg1';
  }

  @override
  String get connectionId => 'Identyfikator połączenia';

  @override
  String get connectionLooksGood => 'Połączenie wygląda dobrze.';

  @override
  String get connectionMethod => 'Metoda połączenia';

  @override
  String get containsTextOptional => 'Zawiera tekst (opcjonalnie)';

  @override
  String get content => 'Treść';

  @override
  String contentArg1(Object? arg1) {
    return 'Treść: $arg1';
  }

  @override
  String get contentSecurityPolicy => 'politykę bezpieczeństwa treści';

  @override
  String get continue2 => 'Kontynuuj';

  @override
  String get continueFullSetup => 'Kontynuuj pełną konfigurację';

  @override
  String get continueRun => 'Kontynuuj bieg';

  @override
  String get continueToSetup => 'Kontynuuj konfigurację';

  @override
  String get controlSurface => 'POWIERZCHNIA KONTROLNA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Kontroluje dostęp do narzędzi $arg1.';
  }

  @override
  String get conversation => 'Rozmowa';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Identyfikator rozmowy używany, gdy ten agent rozpoczyna czat.';

  @override
  String get cookieSetup => 'Konfiguracja plików cookie';

  @override
  String get cookiesNotConfigured => 'Pliki cookie nie są skonfigurowane';

  @override
  String get copiedAsCsv => 'Skopiowano jako plik CSV';

  @override
  String get copiedDebugInfo => 'Skopiowano informacje debugowania';

  @override
  String get copiedExportForTheLast5 =>
      'Skopiowano eksport ostatnich 5 wiadomości';

  @override
  String get copiedFullPrompt => 'Skopiowano pełny monit';

  @override
  String get copiedLogs => 'Skopiowane logi';

  @override
  String get copiedRunId => 'Skopiowany identyfikator uruchomienia';

  @override
  String get copy => 'Kopiuj';

  @override
  String get copyAll => 'Skopiuj wszystko';

  @override
  String get copyCodes => 'Skopiuj kody';

  @override
  String get copyCsv => 'Skopiuj plik CSV';

  @override
  String get copyDebugInfo => 'Skopiuj informacje debugowania';

  @override
  String get copyLink => 'Skopiuj link';

  @override
  String get copyLogs => 'Skopiuj logi';

  @override
  String get copyPrompt => 'Skopiuj monit';

  @override
  String get copyResponse => 'Skopiuj odpowiedź';

  @override
  String get copyRunId => 'Skopiuj identyfikator uruchomienia';

  @override
  String get copyWebhookUrl => 'Skopiuj adres URL webhooka';

  @override
  String get core => 'Rdzeń';

  @override
  String get coreMemory => 'pamięć rdzeniowa';

  @override
  String get coreServicesThisServerDependsOn =>
      'Podstawowe usługi, od których zależy ten serwer.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'domena cors https publiczne pochodzenie adresu URL';

  @override
  String get couldHelp => 'Mogłoby pomóc';

  @override
  String get couldNotApproveQrLogin => 'Nie można zatwierdzić logowania QR.';

  @override
  String get couldNotApproveQrPairing => 'Nie można zatwierdzić parowania QR.';

  @override
  String get couldNotConnect => 'Nie udało się połączyć.';

  @override
  String get couldNotCreateBinding => 'Nie można utworzyć powiązania.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nie można usunąć Twojego konta: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Nie można odłączyć Bitwardena.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Nie można odłączyć Asystenta Home.';

  @override
  String get couldNotDisconnectNeorecall => 'Nie można rozłączyć NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'Nie można odłączyć Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Nie można odłączyć Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nie można wyeksportować danych: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Nie udało się wczytać decyzji';

  @override
  String get couldNotLoadUsageData =>
      'Nie udało się załadować danych o użytkowaniu.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nie można automatycznie otworzyć ustawień systemu Linux.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Nie można otworzyć strony z łączem do dostawcy.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nie można otworzyć strony logowania dostawcy.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Nie można otworzyć zasobu wersji.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nie można otworzyć Trello w przeglądarce.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nie można otworzyć pobierania pliku obszaru roboczego.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Nie można odczytać pakietu aplikacji na Androida.';

  @override
  String get couldNotReadTheApk => 'Nie można odczytać pliku APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nie można usunąć klucza: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Nie udało się zapisać agenta.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nie można zapisać konfiguracji Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nie udało się zapisać konfiguracji Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nie można zapisać konfiguracji NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nie można zapisać konfiguracji Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Nie można zapisać konfiguracji Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nie można wysłać e-maila z potwierdzeniem';

  @override
  String get couldNotStart => 'Nie można rozpocząć';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Utwórz';

  @override
  String get createAPasswordFirstToChange =>
      'Najpierw utwórz hasło, aby zmienić adres e-mail swojego konta.';

  @override
  String get createAPasswordOrLinkAnother =>
      'utwórz hasło lub połącz innego dostawcę przed usunięciem tej metody logowania';

  @override
  String get createATaskWhileThisAgent =>
      'Utwórz zadanie, gdy ten agent jest wybrany.';

  @override
  String get createLink => 'Utwórz łącze';

  @override
  String get createOrModifyFilesInYour =>
      'Twórz lub modyfikuj pliki w swoim obszarze roboczym.';

  @override
  String get createPassword => 'Utwórz hasło';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Twórz specjalistyczne boty z oddzielną pamięcią, ustawieniami, narzędziami i przypisaniami kont.';

  @override
  String get createTheFirstAccount => 'Utwórz pierwsze konto';

  @override
  String get createUpdateOrDeleteSkills =>
      'Twórz, aktualizuj lub usuwaj umiejętności.';

  @override
  String get creatingYourSkill => 'Tworzenie umiejętności…';

  @override
  String get credentialBindings => 'Powiązania poświadczeń';

  @override
  String get credentialUse => 'Użycie poświadczeń';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Powtarzające się uruchomienia oparte na Cron i jednorazowe wykonanie w określonym czasie.';

  @override
  String get cronExpression => 'Wyrażenie Crona';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter uruchamia zapytanie.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Spacja';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Obecny e-mail: $arg1';
  }

  @override
  String get currentPassword => 'Aktualne hasło';

  @override
  String get currentPasswordIsIncorrect => 'obecne hasło jest nieprawidłowe';

  @override
  String get currentTwoStepLoginCode => 'Aktualny dwuetapowy kod logowania';

  @override
  String get customAccess => 'Dostęp niestandardowy';

  @override
  String get customCron => 'Niestandardowy Cron';

  @override
  String get customCronMustHave5Fields =>
      'Niestandardowy Cron musi mieć 5 pól.';

  @override
  String get customEndpoint => 'niestandardowy punkt końcowy';

  @override
  String get customField => 'Pole niestandardowe';

  @override
  String get customHeader => 'Niestandardowy nagłówek';

  @override
  String get customHeadersJson => 'Niestandardowe nagłówki (JSON)';

  @override
  String get customOpenaiCompatible => 'Niestandardowa kompatybilność z OpenAI';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Niestandardowy punkt końcowy zgodny z OpenAI';

  @override
  String get customOutgoingUrl => 'Niestandardowy wychodzący adres URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Codziennie';

  @override
  String get dailyRecap => 'Codzienne podsumowanie';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'zapytanie do bazy danych wybierz szablony CSV';

  @override
  String dayArg1(Object? arg1) {
    return 'Dzień $arg1';
  }

  @override
  String get dayOfMonth => 'Dzień miesiąca';

  @override
  String get decideWhichToolsYourAgentMay =>
      'zdecyduj, z jakich narzędzi może korzystać Twój agent. Widzą twoje imię i ';

  @override
  String get decisionHigherUpTheChainWins =>
      'decyzja znajdująca się wyżej w łańcuchu wygrywa i pokazuje zamek z ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Decyzje pojawiają się tutaj, ponieważ $arg1 odczytuje zatwierdzone grupy $arg2. Zachowywanych jest tylko ostatnich 30 i są one resetowane po ponownym uruchomieniu serwera.';
  }

  @override
  String get decline => 'Odmów';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'głęboki bieg · krok $arg1';
  }

  @override
  String get deepgramKey => 'Klucz Deepgramu';

  @override
  String get default2 => 'Domyślne';

  @override
  String get default3 => 'DOMYŚLNY';

  @override
  String defaultArg1(Object? arg1) {
    return 'Domyślny ($arg1)';
  }

  @override
  String get defaultConversation => 'Domyślna rozmowa';

  @override
  String get defaultForNewGroups => 'Wartość domyślna dla nowych grup';

  @override
  String get defaultGroupParticipation => 'Domyślne uczestnictwo w grupie';

  @override
  String get defaultNeoagentWorkspace => 'Domyślny obszar roboczy NeoAgent';

  @override
  String get defaultOpenai => 'Domyślny (OpenAI)';

  @override
  String get defaultRateLimits => 'Domyślne limity stawek';

  @override
  String get defaultRateLimitsSaved =>
      'Domyślne limity stawek zostały zapisane.';

  @override
  String get defaultRecommended => 'Domyślny (zalecany)';

  @override
  String get defaultRouting => 'Trasa domyślna';

  @override
  String get defaultSpace => 'Domyślna spacja';

  @override
  String get delete => 'Usuń';

  @override
  String get deleteAccount => 'Usuń konto';

  @override
  String get deleteAccountPermanently => 'Trwale usunąć konto?';

  @override
  String get deleteAnAccount => 'Usuń konto';

  @override
  String deleteArg1(Object? arg1) {
    return 'Usunąć @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Usuń ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Trwale usunąć $arg1 $arg2?';
  }

  @override
  String get deleteBinding => 'Usuń powiązanie';

  @override
  String get deleteCoreMemoryEntry => 'Usunąć wpis pamięci rdzeniowej?';

  @override
  String get deleteForever => 'Usuń na zawsze';

  @override
  String get deleteMcpServer => 'Usunąć serwer MCP?';

  @override
  String get deleteMemory => 'Usunąć pamięć?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Usuń trwale usuwa konto i wszystkie jego dane ';

  @override
  String get deleteRun => 'Usunąć bieg?';

  @override
  String get deleteRun2 => 'Usuń bieg';

  @override
  String get deleteSelectedMemories => 'Usunąć wybrane wspomnienia?';

  @override
  String get deleteSession => 'Usunąć sesję?';

  @override
  String get deleteSkill => 'Usunąć umiejętność?';

  @override
  String get deleteTask => 'Usunąć zadanie?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Usunięto „$arg1”.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Usunięto @$arg1 i wszystkie jego dane.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Usunięcie usuwa wszystkie rozmowy, wspomnienia, pliki, zadania i ';

  @override
  String get deliverableArtifactProduced =>
      'Wyprodukowano artefakt dostarczalny';

  @override
  String get deliverableCompleted => 'Dostawa ukończona';

  @override
  String get deliverableExecutionStarted => 'Rozpoczęto realizację dostawy';

  @override
  String get deliverableSelected => 'Wybrano dostawę';

  @override
  String get deliverableValidationFailed =>
      'Weryfikacja elementu dostawy nie powiodła się';

  @override
  String get deliverableValidationStarted =>
      'Rozpoczęto sprawdzanie dostarczalności';

  @override
  String get deny => 'Odmów';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Opisz wynik, a następnie zademonstruj go na pulpicie';

  @override
  String get describeWhatToBuildOrChange => 'Opisz, co zbudować lub zmienić…';

  @override
  String get description => 'Opis';

  @override
  String get desktopApp => 'Aplikacja komputerowa';

  @override
  String get desktopAppControlsAvailable =>
      'Dostępne elementy sterujące aplikacji komputerowej';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Przechwytywanie pulpitu nie jest dostępne na tej platformie.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Przesyłanie danych wyjściowych poleceń pulpitu zostało anulowane.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Polecenie towarzyszące pulpitowi zostało anulowane.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Upłynął limit czasu połączenia towarzyszącego pulpitowi.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Upłynął limit czasu uzgadniania towarzyszącego pulpitowi.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Towarzysz pulpitu nie jest tutaj dostępny.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Towarzysz pulpitu jest wstrzymany lokalnie.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Nie udało się obsłużyć komunikatu towarzyszącego na pulpicie: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Ustawienia uprawnień towarzyszących pulpitowi są niedostępne w Internecie.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Ustawienia uprawnień towarzyszących pulpitowi są niedostępne na tej platformie.';

  @override
  String get desktopCompanionRejected => 'Towarzysz pulpitu odrzucony.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Odpowiedź towarzysząca na pulpicie nie powiodła się: $arg1';
  }

  @override
  String get desktopControl => 'Sterowanie pulpitem';

  @override
  String get desktopFailedToStart => 'Nie udało się uruchomić pulpitu';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Nie udało się przechwycić strumienia z pulpitu: $arg1';
  }

  @override
  String get destinationId => 'Identyfikator miejsca docelowego';

  @override
  String get deviceAccess => 'Dostęp do urządzenia';

  @override
  String get deviceSettings => 'Ustawienia urządzenia';

  @override
  String get devices => 'Urządzenia';

  @override
  String get diagnosticsSaved => 'Diagnostyka zapisana.';

  @override
  String get directBluebubblesImessageBridge =>
      'Bezpośredni mostek BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Wiadomości bezpośrednie pozostają responsywne. Grupy znajdujące się na liście dozwolonych korzystają z poniższego trybu uczestnictwa.';

  @override
  String get directoryDoesNotExist => 'Katalog nie istnieje.';

  @override
  String get disable2fa => 'Wyłącz 2FA';

  @override
  String get disableAll => 'Wyłącz wszystko';

  @override
  String get discard => 'Odrzuć';

  @override
  String get disconnect => 'Rozłącz';

  @override
  String get disconnectHomeAssistant => 'Odłączyć Asystenta Domowego?';

  @override
  String get disconnectNeorecall => 'Odłączyć NeoRecall?';

  @override
  String get disconnectNextcloud => 'Odłączyć Nextcloud?';

  @override
  String get disconnectPlatform => 'Odłącz platformę';

  @override
  String get disconnectTrello => 'Odłączyć Trello?';

  @override
  String get discoveryFailed => 'Odkrycie nie powiodło się';

  @override
  String get dismiss => 'Odrzuć';

  @override
  String get displayIdIsRequired => 'Wymagany jest identyfikator wyświetlany.';

  @override
  String get displayName => 'Nazwa wyświetlana';

  @override
  String get displayNameMustBe64Characters =>
      'Nazwa wyświetlana może mieć maksymalnie 64 znaki.';

  @override
  String get displayNameSaved => 'Nazwa wyświetlana została zapisana.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Nie podawaj swojej nazwy użytkownika ani adresu e-mail.';

  @override
  String get done => 'Gotowe';

  @override
  String get downloadACopyOfYourData =>
      'Pobierz kopię swoich danych. Kont administratorów nie można usunąć ';

  @override
  String get downloadACopyOfYourData2 =>
      'Pobierz kopię swoich danych lub trwale usuń swoje konto. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Pobierz $arg1';
  }

  @override
  String get downloadUpdate => 'Pobierz aktualizację';

  @override
  String get downloadingTheNeoagentBackend => 'Pobieranie backendu NeoAgent';

  @override
  String get draft => 'Wersja robocza';

  @override
  String get dragIsNotSupportedOnThis =>
      'przeciąganie nie jest obsługiwane na tej platformie.';

  @override
  String get draggedOnTheScreen => 'Przeciągnięty na ekranie';

  @override
  String get dropAnApkOrApkBundle =>
      'Upuść tutaj plik APK lub pakiet APK, aby go zainstalować';

  @override
  String get dropApkOrApksHere => 'Upuść plik APK lub .apks tutaj';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Trwałe instrukcje dotyczące głosu i stylu interakcji. Zasady bezpieczeństwa i wykonania nadal mają priorytet.';

  @override
  String get eGAlexSLaptop => 'np. Laptop Alexa';

  @override
  String get eGMyLocalServer => 'np. Mój lokalny serwer';

  @override
  String get edit => 'Edytuj';

  @override
  String get editAgent => 'Edytuj agenta';

  @override
  String get editCoreMemoryEntry => 'Edytuj wpis pamięci rdzenia';

  @override
  String get editInstructions => 'Edytuj instrukcje';

  @override
  String get editMcpServer => 'Edytuj serwer MCP';

  @override
  String get editTask => 'Edytuj zadanie';

  @override
  String editedArg1(Object? arg1) {
    return 'Edytowano $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Właścicielom kont wysyłaj e-maile na temat logowań, które wyglądają nietypowo.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Wyślij e-mail do właścicieli kont, gdy zmienią się dane ich konta.';

  @override
  String get emailCode => 'Kod e-mail';

  @override
  String get emailConfirmationRequired => 'wymagane potwierdzenie e-mailem';

  @override
  String get emailIsAlreadyInUse => 'e-mail jest już używany';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail został zapisany. Jeśli wymagane jest potwierdzenie, sprawdź nowy adres, aby uzyskać link potwierdzający NeoAgent.';

  @override
  String get emailSettingsSaved => 'Ustawienia poczty e-mail zostały zapisane.';

  @override
  String get emailUnverified => 'E-mail niezweryfikowany';

  @override
  String get empty => 'Pusty';

  @override
  String get emptyFile => 'Pusty plik';

  @override
  String get emptyFolder => 'Pusty folder';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Pusty używa ustawień domyślnych serwera ($arg1).';
  }

  @override
  String get enable2fa => 'Włącz 2FA';

  @override
  String get enableAll => 'Włącz wszystko';

  @override
  String get enableBehaviorModules => 'Włącz moduły zachowania';

  @override
  String get enableOrDisableModels => 'Włącz lub wyłącz modele';

  @override
  String get enabled => 'Włączone';

  @override
  String get encryptedPrivateToYourAccount =>
      'Zaszyfrowane, prywatne na Twoim koncie';

  @override
  String get end => 'Koniec';

  @override
  String get endCall => 'Zakończ połączenie';

  @override
  String get endVoiceCall => 'Zakończyć połączenie głosowe?';

  @override
  String get endpoint => 'Punkt końcowy';

  @override
  String get enterAPassword => 'Wprowadź hasło.';

  @override
  String get enterAUsername => 'Wprowadź nazwę użytkownika.';

  @override
  String get enterAValidEmailAddress => 'Wpisz prawidłowy adres e-mail.';

  @override
  String get enterAnAddressManually => 'Wprowadź adres ręcznie';

  @override
  String get enterAnApiKeyFirst => 'Najpierw wprowadź klucz API.';

  @override
  String get enterInviteLink => 'Wpisz link z zaproszeniem';

  @override
  String get enterTheAddressOfANeoagent => 'Wprowadź adres serwera NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Wprowadź dane podane przez $arg1, aby $arg2 mógł wysyłać i odbierać wiadomości.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Wprowadź swój kod 2FA lub kod odzyskiwania.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Wprowadź swoje obecne hasło, aby je zmienić.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Wprowadź swoje obecne hasło, aby zapisać zmiany w e-mailu.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Wprowadź dane swojego konta NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Wpisz swoją nazwę użytkownika lub adres e-mail konta. NeoAgent wyśle ​​link resetujący, jeśli będzie pasował do konta.';

  @override
  String get enterYourUsernameOrEmail =>
      'Wpisz swoją nazwę użytkownika lub adres e-mail.';

  @override
  String entityArg1(Object? arg1) {
    return 'Podmiot: $arg1';
  }

  @override
  String get environment => 'Środowisko';

  @override
  String get error => 'Błąd';

  @override
  String errorArg1(Object? arg1) {
    return '\nbłąd: $arg1';
  }

  @override
  String errorArg12(Object? arg1) {
    return 'Błąd: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Błędy z ostatniego dziennika, pogrupowane według komunikatów.';

  @override
  String get errorsProblemsFailures => 'błędy, problemy, awarie';

  @override
  String get eventTypesCommaSeparated =>
      'Typy zdarzeń (oddzielone przecinkami)';

  @override
  String get every15Minutes => 'Co 15 minut';

  @override
  String get every30Minutes => 'Co 30 minut';

  @override
  String get everyAccountOnThisServerLoses =>
      'Każde konto na tym serwerze traci ten klucz wspólny. Konta ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'każde konto na tym serwerze. Sekrety są przeznaczone tylko do zapisu: wyjdź ';

  @override
  String get everyAccountOnThisServerUses =>
      'Każde konto na tym serwerze używa tego adresu do celów ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Każda aktywna sesja dla tego konta kończy się. Mogą się zalogować ';

  @override
  String get everyDay0800 => 'Codziennie · 08:00';

  @override
  String get everyDay2000 => 'Codziennie · 20:00';

  @override
  String get everyHour => 'Co godzinę';

  @override
  String get everyRunOnThisServerAll =>
      'Każde uruchomienie na tym serwerze, cały czas.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Każde wrażliwe narzędzie wymaga za każdym razem zgody.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Każde narzędzie działa bez pytania, z wyjątkiem tych, które obsługuje człowiek ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Wszyscy w tych grupach, kanałach lub pokojach mogą rozmawiać z $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Wszyscy w tej grupie';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Wszystko, co $arg1 wyłączyło dla twojego agenta, przychodzi ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Wszystko inne jest wyłączone.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Wszystko jest dostępne z poziomu pulpitu.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Wszystko, z czego może korzystać agent: oficjalne integracje, serwery MCP i umiejętności.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Wszystko, co wyłączyłeś dla $arg1, powraca ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Dokładne źródła sieciowe mogą wysyłać żądania między źródłami, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Wykonaj JavaScript w sesji przeglądarki.';

  @override
  String get execution => 'Wykonanie';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Szczegóły wykonania są niedostępne dla tego przebiegu.';

  @override
  String get executionPlanCreated => 'Utworzono plan wykonania.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Ćwicz sesje $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[wyjdź z $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Wygasa $arg1';
  }

  @override
  String get explainThisProject => 'Wyjaśnij ten projekt';

  @override
  String exploredArg1(Object? arg1) {
    return 'Zbadano $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Zbadano $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Zbadałem obszar roboczy';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Eksport nie powiódł się: $arg1';
  }

  @override
  String get exportLast5Messages => 'Eksportuj ostatnie 5 wiadomości';

  @override
  String get exportMyData => 'Eksportuj moje dane';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Uruchomienie zewnętrznej przeglądarki nie powiodło się, kod zakończenia $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Uruchamianie przeglądarki zewnętrznej nie jest obsługiwane na tej platformie.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Upłynął limit czasu uruchamiania przeglądarki zewnętrznej.';

  @override
  String get externalMcpTools => 'Narzędzia zewnętrzne i MCP';

  @override
  String get extraButtons => 'Dodatkowe guziki';

  @override
  String get extractingTheNeoagentRuntime =>
      'Wyodrębnianie środowiska wykonawczego NeoAgent';

  @override
  String get failed => 'Nie udało się';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Nie udało się połączyć: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nie udało się połączyć $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nie udało się usunąć „$arg1”: $arg2';
  }

  @override
  String get failedToFetch => 'nie udało się pobrać';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Nie udało się wygenerować podpowiedzi: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Nie udało się uruchomić zewnętrznej przeglądarki poprzez url_launcher.';

  @override
  String get failedToLaunchOauthFlow =>
      'Nie udało się uruchomić przepływu OAuth.';

  @override
  String get failedToLoadPolicies => 'Nie udało się wczytać zasad';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Nie udało się zapisać: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Nie udało się zapisać serwera MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Nie udało się zapisać wyboru: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Nie udało się wysłać powiadomienia do backendu: $arg1';
  }

  @override
  String get fair => 'Uczciwe';

  @override
  String get fasterReplies => 'Szybsze odpowiedzi';

  @override
  String get fewerModelCalls => 'Mniej połączeń modelowych';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'pole puste, aby przywrócić wbudowane ustawienia domyślne.';

  @override
  String get fileExceedsThe1MibEditor => 'Plik przekracza limit edytora 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Plik przekracza obsługiwany limit rozmiaru.';

  @override
  String get fileWrites => 'Zapisuje plik';

  @override
  String get filename => 'Nazwa pliku';

  @override
  String get files => 'Pliki';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Tutaj pojawiają się pliki, które NeoAgent zapisał lub edytował podczas tej sesji.';

  @override
  String get filesSavedByAllUsers =>
      'Pliki zapisane przez wszystkich użytkowników';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Wypełniaj zatwierdzone dane logowania lub uwierzytelniaj żądania bez ujawniania sekretów sztucznej inteligencji.';

  @override
  String get finalResponse => 'Ostateczna odpowiedź';

  @override
  String get findAPlatform => 'Znajdź platformę';

  @override
  String get findAndFixABug => 'Znajdź i napraw błąd';

  @override
  String get findRecentChats => 'Znajdź ostatnie czaty';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Znalezienie odpowiedniego środowiska wykonawczego NeoAgent';

  @override
  String get finish => 'Zakończ';

  @override
  String get finishAtTheScheduledTime => 'Zakończ o zaplanowanej godzinie';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Zakończ logowanie się do $arg1 w przeglądarce, a następnie połącz się ponownie.';
  }

  @override
  String get flowGraph => 'Wykres przepływu';

  @override
  String get flutterApp => 'Aplikacja Flutter';

  @override
  String get focusedExecutionProfile => 'Skoncentrowany profil wykonania';

  @override
  String get folderIdOptional => 'Identyfikator folderu (opcjonalnie)';

  @override
  String get folderUnavailable => 'Folder niedostępny';

  @override
  String get forExampleHttpsMatrixOrg => 'Na przykład https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Do hostowanych lub zaawansowanych konfiguracji sieciowych';

  @override
  String get forLinksInEmailsBlankUses =>
      'W przypadku linków w wiadomościach e-mail. Blank używa publicznego adresu URL serwera.';

  @override
  String get forgotPassword => 'Zapomniałeś hasła?';

  @override
  String get frameUnavailable => 'Rama niedostępna';

  @override
  String freshnessArg1(Object? arg1) {
    return 'świeżość: $arg1';
  }

  @override
  String get fridays1700 => 'Piątki · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Z BotFather po utworzeniu bota.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Od tej chwili $arg1 decyduje, z jakich narzędzi może korzystać Twój agent. Oni ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Z portalu programistów Discord, pod twoim botem.';

  @override
  String get fromTheLineDevelopersConsole => 'Z konsoli programistów LINE.';

  @override
  String get fromTheMatrixClientOrBot => 'Z klienta Matrix lub konta bota.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Na twitchapps.com/tmi lub w aplikacji dla programistów Twitcha.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Pełny monit';

  @override
  String get fullSetup => 'Pełna konfiguracja';

  @override
  String fullTextFtsArg1(Object? arg1) {
    return 'Pełny tekst (FTS): $arg1';
  }

  @override
  String get general => 'Generał';

  @override
  String get generalSettings => 'Ustawienia ogólne';

  @override
  String get generalSettingsSaved => 'Ustawienia ogólne zostały zapisane.';

  @override
  String get generateAPromptForAnotherAi =>
      'Wygeneruj monit o kolejną sztuczną inteligencję, wklej tutaj odpowiedź, aby zaimportować wspomnienia.';

  @override
  String get generatePrompt => 'Wygeneruj monit';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Błąd śledzenia geofence: $arg1';
  }

  @override
  String get getInspired => 'Zainspiruj się';

  @override
  String get githubCopilot => 'Drugi pilot GitHuba';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot i Kodeks OpenAI';

  @override
  String get githubIssueOpened => 'Problem z GitHubem został otwarty';

  @override
  String get neorecallMemoryCreated => 'Utworzono pamięć NeoRecall';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Sprawdzanie wersji GitHub nie powiodło się przy użyciu protokołu HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Ładunek wydania GitHub nie był listą wydań.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Nazwa użytkownika GitHub, który otworzył problem';

  @override
  String get globalSecurityMode => 'Globalny tryb bezpieczeństwa';

  @override
  String get gmailMessageReceived => 'Otrzymano wiadomość z Gmaila';

  @override
  String get good => 'Dobrze';

  @override
  String get goodAfternoon => 'Dzień dobry';

  @override
  String get goodEvening => 'Dobry wieczór';

  @override
  String get goodMorning => 'Dzień dobry';

  @override
  String get goodPasswordALittleMoreLength =>
      'Dobre hasło. Nieco większa długość sprawia, że ​​jest mocniejszy.';

  @override
  String get googleChat => 'Czat Google';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live używa Twojego klucza API OpenAI, a Gemini Live Twojego klucza Google AI. Zmiany obowiązują od następnego połączenia.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Przed synchronizacją przyznaj uprawnienia Health Connect.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupa, kanał lub pokój';

  @override
  String get groupType => 'Typ grupy';

  @override
  String get groupsAndChannels => 'Grupy i kanały';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupy: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupy, których $arg1 jeszcze nie widział, pójdą za tym.';
  }

  @override
  String get handlesDirectTasksItself =>
      'Samodzielnie wykonuje zadania bezpośrednie';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Zestaw głośnomówiący (rozmawiaj swobodnie, przerywaj w dowolnym momencie)';

  @override
  String get headerName => 'Nazwa nagłówka';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Nagłówki na tematy, które Cię interesują, przefiltrowane pod kątem sygnału.';

  @override
  String get health => 'Zdrowie';

  @override
  String get healthChecks => 'Kontrole stanu zdrowia';

  @override
  String get healthConnect => 'połączenie zdrowia';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Usługa Health Connect nie jest dostępna na tym urządzeniu.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Stan synchronizacji Health Connect i zapisane metryki zaplecza.';

  @override
  String get healthStatusIsUnavailable => 'Stan zdrowia jest niedostępny.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Synchronizacja stanu jest dostępna tylko na urządzeniach z Androidem.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Rekordy serca $arg1';
  }

  @override
  String get heldBack => 'Powstrzymywany';

  @override
  String get helper => 'Pomocnik';

  @override
  String helperArg1(Object? arg1) {
    return 'Pomocnik: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'tutaj. Najpierw unieważnij administratora za pomocą `neoagent admin unieważnij $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Wyższe wartości sprawiają, że NeoAgent jest bardziej selektywny w grupach.';

  @override
  String get highlyRecommended => 'Gorąco polecam';

  @override
  String get holdButton131ForTheAssistant =>
      'Przytrzymaj przycisk 131 dla asystenta.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Przytrzymaj Ctrl+Shift+Spacja, aby porozmawiać';

  @override
  String get holdToTalk => 'Przytrzymaj, aby porozmawiać.';

  @override
  String get holdToTalk2 => 'Przytrzymaj, aby porozmawiać';

  @override
  String get home => 'Dom';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Wymagany jest token dostępu o przedłużonej trwałości Home Assistant.';

  @override
  String get homeAssistantSetup => 'Konfiguracja Asystenta Domowego';

  @override
  String get homeAssistantUrl => 'Adres URL Asystenta domowego';

  @override
  String get homeAssistantUrlIsRequired =>
      'Adres URL Asystenta Domowego jest wymagany.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token serwera domowego z odpytywaniem pokoju';

  @override
  String get homeserverUrl => 'Adres URL serwera domowego';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'usługa hostowana). Twoje klucze są zaszyfrowane i mogą być używane tylko przez ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Nazwa hosta sieci IRC, na przykład irc.libera.chat';

  @override
  String get hourly => 'Co godzinę';

  @override
  String get hourlyInboxCheck => 'Cogodzinne sprawdzanie skrzynki odbiorczej';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Jak długo linki potwierdzające pozostają ważne.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Jak często ten agent szuka nowych wiadomości w pokoju.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Jak często ten agent szuka nowych wiadomości Signal.';

  @override
  String get howTeamsWork => 'Jak działają zespoły';

  @override
  String get howThisServerIsReachedPlus =>
      'Sposób osiągnięcia tego serwera oraz przełączniki obejmujące cały serwer.';

  @override
  String get httpsSessionCookie => 'Plik cookie sesji https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Nie mogłem teraz zrealizować tego żądania. Spróbuj ponownie za chwilę.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Bezczynny';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Jeśli $arg1 poprosi o adres URL webhooka, wklej go, aby wiadomości mogły dotrzeć do $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Jeśli to konto ma potwierdzony adres e-mail, NeoAgent wyśle ​​link do resetowania hasła.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Jeśli usługa wymaga tokena dla żądań wychodzących.';

  @override
  String get ignoreGroups => 'Ignoruj grupy';

  @override
  String get ignoreThisChat => 'Zignoruj ten czat';

  @override
  String get ignoredChannels => 'Ignorowane kanały';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Zignorowano zniekształcony komunikat towarzyszący pulpitowi: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Wdrażaj powyższy plan.';

  @override
  String get implementThisPlan => 'Wdrażaj ten plan';

  @override
  String get implicitTls => 'Niejawny TLS';

  @override
  String get import => 'Importuj';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Import nie powiódł się: $arg1';
  }

  @override
  String get importFromComputer => 'Importuj z komputera';

  @override
  String get importMemoryTransfer => 'Zaimportować transfer pamięci?';

  @override
  String get importance => 'Znaczenie';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Zaimportowane pamięci $arg1, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'W zespole @$arg1';
  }

  @override
  String get inBackground => 'tło';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Tutaj będą wyświetlane przychodzące i wychodzące wiadomości kanału.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Przychodzące połączenia głosowe w aplikacji od NeoAgent';

  @override
  String get incomingMessages => 'Przychodzące wiadomości';

  @override
  String get incomingNeoagentCall => 'Połączenie przychodzące z NeoAgentem';

  @override
  String get incomingNeoagentCall2 => 'PRZYCHODZĄCE POŁĄCZENIE NEOAGENTA';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Obsługa przychodzącego webhooka i wychodzącego wywołania zwrotnego';

  @override
  String get incorporatingSteering => 'Zawiera sterowanie';

  @override
  String get input => 'Wejście';

  @override
  String get inputMode => 'Tryb wprowadzania';

  @override
  String get insertATemplate => 'Wstaw szablon';

  @override
  String get inspect => 'Sprawdź';

  @override
  String get install => 'Zainstaluj';

  @override
  String get installASignedSelfContainedRuntime =>
      'Zainstaluj podpisane, samodzielne środowisko wykonawcze. Polecenia Node.js, npm, Git i terminal nie są wymagane.';

  @override
  String get installApk => 'Zainstaluj APK';

  @override
  String get installApkBundle => 'Zainstaluj APK/pakiet';

  @override
  String get installApkClickOrDropA =>
      'Zainstaluj APK — kliknij lub upuść plik .apk';

  @override
  String get installNeoagent => 'Zainstaluj NeoAgenta';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Zainstaluj NeoAgent na tym komputerze bez terminala lub połącz się z już uruchomionym.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Zainstaluj nowe wersje i wybierz kanał, z którego będzie korzystał ten serwer.';

  @override
  String get installTheBackend => 'Zainstaluj backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Zainstaluj rdzeń z dodatkową opcjonalną konfiguracją. Klucze dostawcy AI są dodawane później, tak samo jak w przewodniku Szybki Start.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Zainstaluj bezpieczny rdzeń, a następnie utwórz konto. Następnie dodaj klucze dostawcy AI.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Zainstalowano: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Zainstalowano: $arg1 • Ostatnio sprawdzano: $arg2';
  }

  @override
  String get instructions => 'Instrukcje';

  @override
  String get integration => 'Integracja';

  @override
  String get integrationApps => 'Aplikacje integracyjne';

  @override
  String get integrationConnections => 'Połączenia integracyjne';

  @override
  String get integrationSettingsSaved =>
      'Ustawienia integracji zostały zapisane.';

  @override
  String get integrations => 'Integracje';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'Integrations/oauth/callback i zarejestruj to samo ';

  @override
  String get interruptAi => 'Przerwij sztuczną inteligencję';

  @override
  String get invalid2fa => 'nieprawidłowe 2fa';

  @override
  String get invalidArgumentS => 'Nieprawidłowe argumenty: ';

  @override
  String get invalidCredentials => 'nieprawidłowe dane uwierzytelniające';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Nieprawidłowy manifest środowiska wykonawczego NeoAgent.';

  @override
  String get inviteLink => 'Zaproś link';

  @override
  String get inviteLinkReady => 'Link z zaproszeniem gotowy';

  @override
  String get inviteLinks => 'Zaproś linki';

  @override
  String get iphoneApp => 'aplikacja na iPhone\'a';

  @override
  String get issues => 'Problemy';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Problemy pojawiają się po załadowaniu dziennika.';

  @override
  String get itCanTBeUndone => 'Nie można tego cofnąć.';

  @override
  String get itMayHaveBeenDeleted => 'Być może został usunięty.';

  @override
  String get javaRuntime => 'środowisko wykonawcze Java';

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
    return 'Dołączył do $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Dołączył w ciągu ostatnich 7 dni';

  @override
  String get joiningATeam => 'Dołączanie do zespołu';

  @override
  String get joiningIsOffHere => 'Dołączanie jest tutaj wyłączone';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Pole JSON zawierające tekst wiadomości. Zwykle tekst.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Pole JSON identyfikujące do kogo skierowana jest wiadomość.';

  @override
  String get jumpToLatest => 'Przejdź do najnowszych';

  @override
  String get justNow => 'właśnie teraz';

  @override
  String get keepNeoagentRunning => 'Kontynuować działanie NeoAgenta?';

  @override
  String get keepRunning => 'Biegnij dalej';

  @override
  String get keepTaskRunning => 'Kontynuuj zadanie';

  @override
  String get keepTheVaultAvailable => 'Zachowaj dostępność skarbca';

  @override
  String get keepThisLauncherUpToDate =>
      'Aktualizuj ten program uruchamiający.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Pozostaw ten panel otwarty, dopóki platforma nie potwierdzi połączenia.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Utrzymuj widoczność komputera tej sesji';

  @override
  String get keepTrackOfYourAiUsage =>
      'Śledź wykorzystanie sztucznej inteligencji. Limity są egzekwowane, aby zapewnić uczciwe korzystanie z całej platformy.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Używaj aplikacji normalnie. NeoAgent działa na tym samym ekranie i pyta, kiedy potrzebuje nowego dostępu.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Utrzymywanie połączenia tego urządzenia';

  @override
  String get key => 'Klucz';

  @override
  String get keyIsRequired => 'Klucz jest wymagany.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Pary klucz-wartość, które utrzymują się w rozmowach.';

  @override
  String get knowledgeGraph => 'Graf wiedzy';

  @override
  String get knowledgeView => 'Widok wiedzy';

  @override
  String get labelOnlyYouSeeIt => 'Etykieta (tylko Ty ją widzisz)';

  @override
  String get labelsOptional => 'Etykiety (opcjonalnie)';

  @override
  String get last24Hours => 'Ostatnie 24 godziny';

  @override
  String get last7Days => 'Ostatnie 7 dni';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Ostatnie 7 dni: tokeny $arg1 w biegach $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Ostatni $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Ostatni: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Ostatnia niepusta synchronizacja · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Ostatni bieg: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Ostatnio widziany $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Ostatnie logowanie $arg1';
  }

  @override
  String get lastSyncSummary => 'Podsumowanie ostatniej synchronizacji';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Ostatnio używany: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Ostatnie okno zakończyło się $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'późniejszy start również wyłączony.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Najnowsze uruchomienie · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Uruchamianie aplikacji komputerowych nie jest obsługiwane na tej platformie.';

  @override
  String get learnRoomNorms => 'Poznaj normy dotyczące pokoju';

  @override
  String get leave => 'Wyjdź';

  @override
  String get leaveARedirectUriBlankTo =>
      'Pozostaw puste pole URI przekierowania, aby użyć <publiczny adres URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Opuścić zespół $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Pozostaw ustawienie domyślne, chyba że dostosowałeś BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Pozostaw token pusty, aby zachować aktualnie przechowywany token.';

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
    return 'Pozwól $arg1 mną zarządzać';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Pozwól wszystkim w tej grupie rozmawiać z $arg1.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Niech to działa, podczas\ngdy ty tego nie robisz.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Pozwól NeoAgentowi klikać, pisać i poruszać się po aplikacjach.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Pozwól NeoAgentowi zrozumieć, co jest widoczne na Twoim ekranie.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Pozwól osobie, z którą współpracujesz, zdecydować, jakich narzędzi może używać Twój agent ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Pozwól tej osobie wysłać wiadomość indywidualną do $arg1.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Pozwól tej osobie rozmawiać z $arg1 tutaj, ale nie na prywatnych czatach ani w innych grupach.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Pozwól tej osobie rozmawiać z $arg1 na prywatnych czatach i w dowolnej grupie, którą udostępnia.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Poziom $arg1/$arg2$arg3';
  }

  @override
  String lexicalArg1(Object? arg1) {
    return 'Leksykalny: $arg1';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Połącz $arg1';
  }

  @override
  String get linkCopied => 'Link skopiowany';

  @override
  String get linkExpiresAfter => 'Link wygasa po';

  @override
  String get linkLifetimeHours => 'Żywotność łącza (godziny)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Żywotność łącza musi wynosić od 1 do 8760 godzin.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link ważny do $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Połączeni dostawcy logowania';

  @override
  String get linuxApp => 'Aplikacja na Linuksa';

  @override
  String listedArg1(Object? arg1) {
    return 'Na liście $arg1/';
  }

  @override
  String get listening => 'Słuchanie';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Historia wykonania na żywo, kroki narzędzia i odpowiedzi.';

  @override
  String get liveModel => 'Modelka na żywo';

  @override
  String get liveModelProvider => 'Dostawca modeli na żywo';

  @override
  String get liveRun => 'Bieg na żywo';

  @override
  String get liveVoice => 'Głos na żywo';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Połączenie głosowe na żywo nie jest dostępne.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Połączenie głosowe na żywo zostało zamknięte.';

  @override
  String get liveVoiceDefaults => 'Domyślne ustawienia głosu na żywo';

  @override
  String get liveVoiceFailed => 'Głos na żywo nie powiódł się.';

  @override
  String get llmMemoryExportResponse => 'Odpowiedź na eksport pamięci LLM';

  @override
  String get loadFailed => 'ładowanie nie powiodło się';

  @override
  String get loadingExecutionDetails => 'Ładowanie szczegółów wykonania...';

  @override
  String get loadingNeoagent => 'Ładowanie NeoAgenta';

  @override
  String get loadingRunFlow => 'Ładowanie przebiegu przebiegu…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Adresy URL sieci lokalnej i prywatnej są obsługiwane, jeśli serwer NeoAgent może do nich dotrzeć. Dźwięk nigdy nie jest udostępniany NeoAgentowi.';

  @override
  String get localApp => 'aplikacja lokalna';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Instalacja lokalnego backendu nie jest dostępna na tej platformie.';

  @override
  String get localBaseImagePath => 'Lokalna ścieżka obrazu podstawowego';

  @override
  String get localComputerControlIsAvailableIn =>
      'Sterowanie komputerem lokalnym jest dostępne w aplikacji komputerowej NeoAgent na systemy macOS, Windows i Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Sterowanie komputerem lokalnym nie jest tutaj dostępne.';

  @override
  String get localModelsUrl => 'adres URL lokalnych modeli';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Lokalne wykrywanie NeoAgent jest tymczasowo niedostępne.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Lokalne preferencje dotyczące aplikacji NeoAgent. Sterowanie komputerem zawsze odbywa się za pośrednictwem zunifikowanego komputera w chmurze.';

  @override
  String get localSetup => 'KONFIGURACJA LOKALNA';

  @override
  String get locationCityOrPlace => 'Lokalizacja (miasto lub miejsce)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Lokalizacja jest wymagana w przypadku wyzwalaczy zdarzeń pogodowych';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Inicjalizacja usługi LocationService nie powiodła się: $arg1';
  }

  @override
  String get logCopied => 'Log skopiowany';

  @override
  String get loginPassword => 'Hasło logowania';

  @override
  String get logout => 'Wyloguj się';

  @override
  String get logs => 'Dzienniki';

  @override
  String get logsCopied => 'Logi skopiowane.';

  @override
  String get logsOnThisComputer => 'Loguje się na tym komputerze';

  @override
  String get longLivedAccessToken => 'Długowieczny token dostępu';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Przywołanie długoterminowe, ustrukturyzowane fakty i wykres wiedzy.';

  @override
  String get lookedAtTheScreen => 'Spojrzałem na ekran';

  @override
  String get lookingOnThisComputerAndYour =>
      'Patrząc na ten komputer i sieć lokalną…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Patrzy w przyszłość na jutrzejsze spotkania, więc nic Cię nie zaskoczy.';

  @override
  String get loopExecution => 'Wykonanie pętli';

  @override
  String get loopPaused => 'Pętla wstrzymana';

  @override
  String get macOsX => 'Mac OS X';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Dostępność macOS nie jest przyznawana NeoAgentowi. Zezwól na to w Ustawieniach systemu > Prywatność i bezpieczeństwo > Dostępność.';

  @override
  String get macosApp => 'aplikacja na macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'NeoAgent nie zapewnia możliwości nagrywania ekranu w systemie macOS. Zezwól na to w Ustawieniach systemu > Prywatność i bezpieczeństwo > Nagrywanie ekranu, a następnie ponownie otwórz NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Serwery pocztowe wymagające hasła odmówią wysłania do czasu otrzymania nowego ';

  @override
  String get main => 'Główny';

  @override
  String get makeDefault => 'Ustaw jako domyślny';

  @override
  String get manage => 'Zarządzaj';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Zarządzaj pocztą e-mail konta, uwierzytelnianiem dwuskładnikowym i aktywnymi sesjami.';

  @override
  String get managedBy => 'Zarządzane przez';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Menedżerowie mogą mieć własnych menedżerów (do czterech poziomów). A ';

  @override
  String get managing => 'Zarządzanie';

  @override
  String get manualDestination => 'Ręczne miejsce docelowe';

  @override
  String get manualTrigger => 'Ręczny wyzwalacz';

  @override
  String get masterPassword => 'Hasło główne';

  @override
  String get matchThisDevice => 'Dopasuj to urządzenie';

  @override
  String get matchedAgainstTitleAndBody => 'Dopasowane do tytułu i treści';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Odpowiada staremu przepływowi MCP NeoAgent: adres URL i metoda uwierzytelniania.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'Serwer MPK';

  @override
  String get mcpServer2 => 'Serwer MCP';

  @override
  String get mcpServerUrl => 'Adres URL serwera MCP';

  @override
  String get mcpServers => 'Serwery MCP';

  @override
  String get meantForSomeoneElse => 'Przeznaczone dla kogoś innego';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Zmierzony koszt modelu: $arg1';
  }

  @override
  String get memories => 'Wspomnienia';

  @override
  String get memory => 'Pamięć';

  @override
  String memoryArg1(Object? arg1) {
    return 'Pamięć: $arg1';
  }

  @override
  String get memoryImportSync => 'synchronizacja importu pamięci';

  @override
  String get memoryIngestionInterval => 'Interwał pozyskiwania pamięci';

  @override
  String get memoryIngestionIntervalMs => 'Interwał pozyskiwania pamięci (ms)';

  @override
  String get memoryIngestionIntervalMustBeAt =>
      'Interwał pozyskiwania pamięci musi wynosić co najmniej 1000 ms.';

  @override
  String get memoryInjected => 'Wstrzyknięto pamięć';

  @override
  String get mentionOrReplyOnly => 'Tylko wspomnij lub odpowiedz';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Połączone dzienniki środowiska wykonawczego serwera i Flutter dla tej sesji aplikacji.';

  @override
  String get messageBodyTemplateJson => 'Szablon treści wiadomości (JSON)';

  @override
  String get messageNeedsAccess => 'Wiadomość wymaga dostępu';

  @override
  String get messageTextField => 'Pole tekstowe wiadomości';

  @override
  String get messaging => 'Wiadomości';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Zdarzenia push i webhook interfejsu API przesyłania wiadomości';

  @override
  String get messagingConnectionNeedsAttention =>
      'Połączenie z wiadomościami wymaga uwagi';

  @override
  String get messagingConnections => 'Połączenia wiadomości';

  @override
  String get messagingDelivery => 'Dostarczanie wiadomości';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Błąd wiadomości. Spróbuj ponownie.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Przechwytywanie mikrofonu zostało nieoczekiwanie zatrzymane. Spróbuj ponownie.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Błąd mikrofonu: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofon wyciszony. Kliknij, aby wyłączyć wyciszenie.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Aby korzystać z głosu na żywo, wymagane jest pozwolenie na korzystanie z mikrofonu.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack i inne integracje. Mają zastosowanie do ';

  @override
  String get microsoftTeams => 'Zespoły Microsoftu';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimalna wartość wkładu: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Konfiguracja mobilna nie powiodła się.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Konfiguracja mobilna nie powiodła się, ponieważ Java nie jest dostępna na komputerze, na którym działa NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Konfiguracja mobilna nie powiodła się, ponieważ Java nie jest dostępna na komputerze, na którym działa NeoAgent. Zainstaluj JDK i spróbuj ponownie.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Konfiguracja mobilna nie powiodła się. Sprawdź, czy narzędzia Androida są poprawnie zainstalowane i spróbuj ponownie.';

  @override
  String modeArg1(Object? arg1) {
    return 'tryb: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Tryb blokuje się, gdy bieg jest aktywny.';

  @override
  String get model => 'Modelka';

  @override
  String modelArg1(Object? arg1) {
    return 'Model: $arg1';
  }

  @override
  String get modelAvailability => 'Dostępność modelu';

  @override
  String get modelAvailabilitySaved => 'Dostępność modelu została zapisana.';

  @override
  String get modelForThisSession => 'Modelka na tę sesję';

  @override
  String get modelOverride => 'Nadpisanie modelu';

  @override
  String get modelPending => 'Model w oczekiwaniu';

  @override
  String get modelTurn => 'Zwrot modelu';

  @override
  String get modelTurnCompleted => 'Obrót modelu zakończony';

  @override
  String get modelTurnStarted => 'Rozpoczęto turę modelu';

  @override
  String get modelVisibilityHideShowList =>
      'widoczność modelu ukryj listę pokazów';

  @override
  String get models => 'Modele';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modele, zachowanie, głos i przestrzeń robocza';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modele, przeglądarka, głos, diagnostyka...';

  @override
  String get modelsRouting => 'Modele i routing';

  @override
  String get monthly => 'Miesięcznie';

  @override
  String get moreActions => 'Więcej akcji';

  @override
  String get morningBriefing => 'Poranna odprawa';

  @override
  String get mostUsedAgents => 'Najczęściej używane środki';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Najczęściej używane modele w ostatnim $arg1.';
  }

  @override
  String get mouseKeyboard => 'Mysz i klawiatura';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'MouseMove nie jest obsługiwany na tej platformie.';

  @override
  String get mustBeReachableOnThePublic =>
      'Musi być osiągalny w publicznym Internecie – lokalnym i ';

  @override
  String get n24Hours => '24 godziny';

  @override
  String get n2faOrRecoveryCode => '2FA lub kod odzyskiwania';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA wymaga skonfigurowania SESSION_SECRET w tym wdrożeniu NeoAgent.';

  @override
  String get n30Days => '30 dni';

  @override
  String get n365Days => '365 dni';

  @override
  String get n4HourLimitTokens => 'Limit 4-godzinny (tokeny)';

  @override
  String get n4HourUsage => '4-godzinne użytkowanie';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Limit 4h $arg1';
  }

  @override
  String get n7DayUsage => '7-dniowe użytkowanie';

  @override
  String get n7Days => '7 dni';

  @override
  String get n90Days => '90 dni';

  @override
  String get name => 'Imię';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnazwa: Nowa umiejętność\nopis: Opisz działanie tej umiejętności\n---\nZapisz tutaj instrukcje dotyczące tej umiejętności.\n';

  @override
  String get nameOfWhoeverMadeIt => 'imię tego, kto to zrobił.';

  @override
  String get nameOptional => 'Imię (opcjonalnie)';

  @override
  String get nativeAndWebhookChannels => 'Kanały natywne i webhook';

  @override
  String get naturalBubbles => 'Naturalne bąbelki';

  @override
  String get nearbyNeoagentServers => 'Pobliskie serwery NeoAgent';

  @override
  String get needANewAccountRegister =>
      'Potrzebujesz nowego konta? Zarejestruj się';

  @override
  String get needAnIdea => 'Potrzebujesz pomysłu?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Trzeba odpowiedzieć · $arg1%, aby mówić';
  }

  @override
  String get needsAttention => 'Potrzebuje uwagi';

  @override
  String get needsInput => 'Wymaga wkładu';

  @override
  String get neoagentApp => 'Aplikacja NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Asystent NeoAgenta';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent nie mógł sprawdzić dostępnego środowiska wykonawczego backendu.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent nie mógł dokończyć konfiguracji lokalnej.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent nie mógł dokończyć konfiguracji lokalnej. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informacje debugowania NeoAgent';

  @override
  String get neoagentDesktopInstaller =>
      'Instalator NeoAgent na komputer stacjonarny';

  @override
  String get neoagentFlutterUpdater => 'Aktualizacja Flutter NeoAgent';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent instaluje najnowszą wersję $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent jest zainstalowany i uruchomiony.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent nie jest zainstalowany na tym komputerze.';

  @override
  String get neoagentIsReady => 'NeoAgent jest gotowy';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent nadal pracuje nad zadaniem. Zakończ połączenie i uzyskaj wynik na czacie lub anuluj zadanie.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent zamienia Twoją demonstrację w elastyczny przepływ pracy.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent czeka, aż będziesz korzystać z pulpitu.';

  @override
  String get neoagentIsWorking => 'NeoAgent działa';

  @override
  String get neoagentLinuxComputer => 'Komputer NeoAgent z systemem Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT POTRZEBUJE DECYZJI';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Pobieranie plików w środowisku wykonawczym NeoAgent wymaga bezpiecznego adresu.';

  @override
  String get neoagentServerAddress => 'Adres serwera NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'Adres e-mail usługi NeoAgent nie jest gotowy. Poproś operatora serwera o sprawdzenie ustawień środowiska poczty e-mail.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Nie można dokończyć konfiguracji NeoAgent.';

  @override
  String get neoagentUser => 'Użytkownik NeoAgenta';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent automatycznie korzysta z tego komputera i pyta, zanim użyje ekranu, myszy, klawiatury, plików lub wiersza poleceń.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent korzysta z Twojej przybliżonej lokalizacji w tle, aby uruchamiać przypomnienia o geofence (np. „Przypomnij mi, żebym kupił mleko, gdy będę przechodził obok supermarketu”).\n\n';

  @override
  String get neoagentWorkspace => 'Obszar roboczy NeoAgenta';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag] [$arg1] [stos] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'Adres URL zaplecza NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Wymagany jest adres URL backendu NeoRecall.';

  @override
  String get neorecallSetup => 'Konfiguracja NeoRecall';

  @override
  String get networkRequestFailed => 'żądanie sieciowe nie powiodło się';

  @override
  String get networkWriteRequests => 'Żądania zapisu sieciowego';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nigdy nie wlicza się do wspólnych limitów użytkowania.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Nowe konta potwierdzają swój adres e-mail przed zalogowaniem.';

  @override
  String get newAccountsPerDay => 'Nowe konta dziennie';

  @override
  String get newChat => 'Nowy czat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Nowe grupy pozostają ciche, chyba że ktoś oznaczy $arg1, dopóki ich nie włączysz.';
  }

  @override
  String get newLink => 'Nowe łącze';

  @override
  String get newPasswordsDoNotMatch => 'Nowe hasła nie pasują.';

  @override
  String get newRecoveryCodes => 'Nowe kody odzyskiwania';

  @override
  String get newSession => 'Nowa sesja';

  @override
  String get newSessionN => 'Nowa sesja (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nowa sesja z tą samą konfiguracją';

  @override
  String get newSkill => 'Nowa umiejętność';

  @override
  String get newSkill2 => 'Nowa umiejętność';

  @override
  String get newThisWeek => 'Nowość w tym tygodniu';

  @override
  String get newsDigest => 'Podsumowanie wiadomości';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Następna ponowna próba: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Proces logowania w Nextcloud';

  @override
  String get nextcloudSetup => 'Konfiguracja następnej chmury';

  @override
  String get nextcloudTalk => 'NextRozmowa w chmurze';

  @override
  String get nextcloudUrl => 'Adres URL następnej chmury';

  @override
  String get nextcloudUrlIsRequired => 'Wymagany jest adres URL Nextcloud.';

  @override
  String get nickname => 'Pseudonim';

  @override
  String get noAccountsConnectedYet => 'Nie połączono jeszcze żadnych kont.';

  @override
  String get noAccountsFound => 'Nie znaleziono kont.';

  @override
  String get noActiveSessionsFound => 'Nie znaleziono aktywnych sesji.';

  @override
  String get noAgentsYet => 'Nie ma jeszcze agentów';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nie skonfigurowano żadnego dostawcy AI, więc korzystaj z czatu i wiadomości ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Brak monitów o zatwierdzenie — agent działa bez zakłóceń.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Żadna wersja $arg1 nie pasowała do tej platformy.';
  }

  @override
  String get noArguments => '(bez argumentów)';

  @override
  String get noAuth => 'Brak autoryzacji';

  @override
  String get noBindingsYet => 'Nie ma jeszcze żadnych wiązań.';

  @override
  String get noChangesYet => 'Nie ma jeszcze żadnych zmian';

  @override
  String get noChannelsFound => 'Nie znaleziono kanałów';

  @override
  String get noCloudComputerSlotIsFree =>
      'Żadne miejsce na komputer w chmurze nie jest obecnie wolne. Spróbuj ponownie za chwilę.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Nie ma jeszcze żadnych wpisów w pamięci rdzenia.';

  @override
  String get noDescription => 'Brak opisu';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Obecnie nie są dostępne żadne wyświetlacze na komputery stacjonarne.';

  @override
  String get noDetailAvailable => 'Brak dostępnych szczegółów';

  @override
  String get noDetailedSyncSummaryYet =>
      'Nie ma jeszcze szczegółowego podsumowania synchronizacji.';

  @override
  String get noDetailsCaptured => 'Nie uchwycono żadnych szczegółów.';

  @override
  String get noEmailLinked => 'Brak powiązanego adresu e-mail';

  @override
  String get noExternalSignInProvidersLinked =>
      'Brak połączonych zewnętrznych dostawców logowania.';

  @override
  String get noGroupMessagesYet =>
      'Nie ma jeszcze żadnych wiadomości grupowych';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Nie dodano jeszcze żadnych osób należących do konkretnej grupy.';

  @override
  String get noGroupsAddedYet => 'Nie dodano jeszcze żadnych grup.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Nie znaleziono jeszcze żadnych grup. Gdy $arg1 zobaczy wiadomość grupową, użyj Znajdź ostatnie czaty, a pojawią się one tutaj.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Nie znaleziono jeszcze żadnych grup. Gdy $arg1 zobaczy wiadomość grupową, użyj opcji Znajdź ostatnie czaty.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nie zwrócono żadnego ładunku danych zdrowotnych.';

  @override
  String get noHealthSamplesStoredYet =>
      'Nie zapisano jeszcze żadnych próbek zdrowia.';

  @override
  String get noHttpClientImplementationForThis =>
      'Brak implementacji klienta HTTP dla tej platformy.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Dla tego kroku nie zarejestrowano żadnych danych wejściowych ani wyjściowych.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Żadne integracje nie pasują do tego wyszukiwania.';

  @override
  String get noLimit => 'Bez limitu';

  @override
  String get noLocalPasswordIsSetYet =>
      'Nie ustawiono jeszcze hasła lokalnego. Utwórz je, aby umożliwić logowanie za pomocą nazwy użytkownika/hasła.';

  @override
  String get noLogEntries => 'Brak wpisów w dzienniku.';

  @override
  String get noMatchingSettings => 'Brak pasujących ustawień';

  @override
  String get noMcpServersMatchThisSearch =>
      'Żaden serwer MCP nie pasuje do tego wyszukiwania.';

  @override
  String get noMemoryEntriesFound => 'Nie znaleziono wpisów w pamięci.';

  @override
  String get noMemorySync => 'Brak synchronizacji pamięci';

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Żaden model nie pasuje do „$arg1”.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Dla tego przebiegu nie zarejestrowano żadnego żądania modelu.';

  @override
  String get noModelsDiscoveredYet => 'Nie odkryto jeszcze żadnych modeli';

  @override
  String get noModelsSelected => 'Nie wybrano żadnych modeli';

  @override
  String get noModelsYet => 'Nie ma jeszcze żadnych modeli';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'żadne konto neoagent nie jest powiązane z tym dostawcą';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Dla tego komputera nie jest dostępne żadne środowisko wykonawcze NeoAgent.';

  @override
  String get noNetworkConnection => 'Brak połączenia sieciowego';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Brak połączenia sieciowego. Połącz się, aby dalej korzystać z NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Brak połączenia sieciowego. Połącz się ponownie, aby sprawdzić dostępność aktualizacji.';

  @override
  String get noOne => 'Nikt';

  @override
  String get noOneAddedYet => 'Nikt jeszcze nie dodał.';

  @override
  String get noOneCanMessage => 'Nikt nie może wysyłać wiadomości';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nie znaleziono żadnego innego serwera NeoAgent. Możesz wyszukać ponownie lub wprowadzić adres ręcznie.';

  @override
  String get noPeopleAddedYet => 'Nie dodano jeszcze żadnych osób.';

  @override
  String get noPlatformsMatch => 'Żadna platforma nie pasuje';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Nie ma jeszcze dostępnych dostawców do skonfigurowania.';

  @override
  String get noRecentChannelActivity => 'Brak ostatniej aktywności na kanale';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Brak wyników dla „$arg1”';
  }

  @override
  String get noRunsInThisRange => 'Brak biegów w tym zakresie.';

  @override
  String get noRunsMatchTheseFilters =>
      'Żadne przebiegi nie pasują do tych filtrów';

  @override
  String get noRunsYet => 'Nie ma jeszcze żadnych biegów';

  @override
  String get noRunsYet2 => 'Nie ma jeszcze żadnych biegów.';

  @override
  String get noSecurityKeyWasProvided => 'Nie podano klucza bezpieczeństwa.';

  @override
  String get noServerUrlSet => 'Nie ustawiono adresu URL serwera';

  @override
  String get noSessionMatchesThatSearch =>
      'Żadna sesja nie pasuje do tego wyszukiwania.';

  @override
  String get noSessionsYet => 'Nie ma jeszcze sesji';

  @override
  String get noSkillsMatchTheseFilters =>
      'Żadne umiejętności nie pasują do tych filtrów.';

  @override
  String get noStepsWereRecordedForThis =>
      'W tym biegu nie zarejestrowano żadnych kroków.';

  @override
  String get noSummaryAvailable => 'Brak podsumowania.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Brak zadań dla $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Żadne narzędzie nie pasuje do „$arg1”.';
  }

  @override
  String get noUpdateRunning => 'Żadna aktualizacja nie jest uruchomiona';

  @override
  String get noUsageYet => 'Jeszcze nie używany.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Nie jest jeszcze dostępne zweryfikowane środowisko wykonawcze NeoAgent.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Nikt nie może już z niego korzystać. Osoby, które już dołączyły ';

  @override
  String get none => 'Żadne';

  @override
  String get notApprovedYet => 'jeszcze nie zatwierdzony';

  @override
  String get notAuthenticated => 'nie uwierzytelnione';

  @override
  String get notCheckedYet => 'Jeszcze nie sprawdzone';

  @override
  String get notConfigured => 'Nie skonfigurowano';

  @override
  String get notConnected => 'Nie podłączony';

  @override
  String get notConnected2 => 'Brak połączenia';

  @override
  String get notInstalled => 'Nie zainstalowano';

  @override
  String get notNeeded => 'Nie potrzebne';

  @override
  String get notNeededEnough => 'Nie wystarczająco potrzebne';

  @override
  String get notNow => 'Nie teraz';

  @override
  String get notNow2 => 'Nie teraz';

  @override
  String get notSet => 'Nie ustawiono';

  @override
  String get notSetUp => 'Nie skonfigurowano';

  @override
  String get notTheSameAsAdmin => 'To nie to samo co admin';

  @override
  String get nothingFound => 'Nic nie znaleziono';

  @override
  String get nothingHereYet => 'Jeszcze nic tu nie ma.';

  @override
  String get nothingHereYet2 => 'Jeszcze nic tu nie ma';

  @override
  String get nothingMatches => 'Nic nie pasuje';

  @override
  String get nothingStoredYet => 'Jeszcze nic nie zostało zapisane.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIANIM';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'Dane uwierzytelniające aplikacji OAuth, które pozwalają kontom łączyć się z Google, ';

  @override
  String get oauthClientId => 'Identyfikator klienta OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'Klucz API przekierowania klienta OAuth';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'Identyfikator klienta oauth tajne przekierowanie dysku kalendarza Gmaila';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Uruchomienie protokołu OAuth nie jest obsługiwane na tej platformie.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'Tajny identyfikator klienta dzierżawy programu Outlook programu OAuth';

  @override
  String get oauthToken => 'Token OAuth';

  @override
  String get oauthWithPkce => 'OAuth z PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'z $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'własnego. Po zapisaniu nie jest już nigdy więcej pokazywany.';

  @override
  String get off => 'Wyłączone';

  @override
  String get officialIntegration => 'Oficjalna integracja';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Oficjalna integracja nie zwróciła adresu URL połączenia.';

  @override
  String get on => 'Włączone';

  @override
  String get onASignedInAndroidDevice =>
      'Na zalogowanym urządzeniu z Androidem otwórz Ustawienia > Logowanie i bezpieczeństwo, zeskanuj ten kod i zatwierdź logowanie.';

  @override
  String get onByDefaultForNewGroups => 'Domyślnie włączone dla nowych grup';

  @override
  String get onDemand => 'Na żądanie';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Włączone dla grup $arg1 lub $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'na. Mogą dołączyć ponownie tylko za pomocą nowego linku z zaproszeniem.';

  @override
  String get onYourOwnTheDefault => 'Samodzielnie (domyślnie)';

  @override
  String get once => 'Raz';

  @override
  String get oneBlankToKeepWhatIs =>
      'jedno puste, aby zachować to, co jest przechowywane.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'jeden jest uratowany. Zapisywane są także inne zmiany w tym formularzu.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Jedno lub więcej kont wygasło. Połącz ponownie konto, którego dotyczy problem, aby przywrócić dostęp do narzędzia.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Jedno środowisko wykonawcze kontroluje osobowość, kolejność grup, pamięć pokoju, normy, teorię umysłu i dostarczanie.';

  @override
  String get oneTimeRun => 'Jednorazowy bieg';

  @override
  String get onlyApkOrApksFilesCan =>
      'Można instalować tylko pliki .apk lub .apks.';

  @override
  String get onlyInThisGroup => 'Tylko w tej grupie';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Potrzebne tylko wtedy, gdy usługa prosi o dodatkowe nagłówki HTTP.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Potrzebne tylko wtedy, gdy chcesz zmienić kształt wychodzącego ładunku.';

  @override
  String get onlyTheyCanChangeIt => 'Tylko oni mogą to zmienić.';

  @override
  String get open => 'Otwórz';

  @override
  String get openAccountSettingsOnASigned =>
      'Otwórz Ustawienia > Logowanie i zabezpieczenia na zalogowanym urządzeniu z Androidem, zeskanuj ten kod i zatwierdź logowanie.';

  @override
  String get openComputer => 'Otwórz komputer';

  @override
  String get openDashboard => 'Otwórz pulpit nawigacyjny';

  @override
  String get openFolder => 'Otwórz folder…';

  @override
  String get openInWorkbench => 'Otwórz w warsztacie';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Otwórz NeoAgent i podłącz ponownie $arg1, aby przywrócić przesyłanie wiadomości.';
  }

  @override
  String get openTimeSettings => 'Otwórz ustawienia czasu';

  @override
  String get openToAnyone => 'Otwarte dla każdego';

  @override
  String get openTrello => 'Otwórz Trello';

  @override
  String get openVoiceAssistant => 'Otwórz asystenta głosowego';

  @override
  String get openWiFiSettings => 'Otwórz ustawienia Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Otwórz za pomocą aplikacji domyślnej';

  @override
  String get openaiCodex => 'Kodeks OpenAI';

  @override
  String get openaiCompatible => 'kompatybilny z Openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Punkt końcowy zgodny z OpenAI (własny serwer lub inny ';

  @override
  String openedArg1(Object? arg1) {
    return 'Otwarto $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Otwieranie adresów URL komputerów stacjonarnych nie jest obsługiwane na tej platformie.';

  @override
  String get openingYourSavedDesktop => 'Otwieranie zapisanego pulpitu.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Otwieranie zapisanego pulpitu. Normalne uruchomienie zajmuje mniej niż 10 sekund.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Opcjonalny dodatkowy sekret, jeśli chronisz przychodzący element webhook.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Opcjonalne zastąpienie, jeśli adres URL webhooka nie jest wystarczający.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Opcjonalny klucz tajny do weryfikacji przychodzących zdarzeń czatu.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Opcjonalny klucz tajny do weryfikacji przychodzących zdarzeń.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Opcjonalny sekret umożliwiający weryfikację przychodzących zdarzeń iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Opcjonalny klucz tajny do weryfikacji przychodzących zdarzeń LINE.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Opcjonalny sekret umożliwiający weryfikację przychodzących wydarzeń Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Opcjonalny klucz tajny służący do weryfikowania przychodzących wydarzeń w aplikacji Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Opcjonalne. Agent ma już swoją osobowość. Wszystko, co dodasz na temat tonu, jest nakładane na wierzch, więc nigdy nie musisz go definiować.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Opcjonalne. Po ustawieniu jest używany zamiast adresu URL.';

  @override
  String get orAnswerInYourOwnWords => 'Lub odpowiedz własnymi słowami';

  @override
  String get orBuildYourOwnTask => 'Lub zbuduj własne zadanie';

  @override
  String get orContinueWith => 'lub kontynuuj';

  @override
  String get orFiles => 'lub pliki.';

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
  String get originNotAllowed => 'pochodzenie niedozwolone';

  @override
  String get outgoingMessage => 'Wiadomość wychodząca';

  @override
  String get outgoingWebhookUrl => 'Adres URL wychodzącego webhooka';

  @override
  String get outlookEmailReceived => 'Otrzymano e-mail programu Outlook';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Zastąp uwagi dotyczące zachowania z importu.';

  @override
  String get ownModel => 'własny model';

  @override
  String get packageName => 'Nazwa pakietu';

  @override
  String get pairWithQrCode => 'Sparuj z kodem QR';

  @override
  String get password => 'Hasło';

  @override
  String get password2faAndActiveSessions => 'Hasło, 2FA i aktywne sesje';

  @override
  String get passwordCreated => 'Hasło utworzone.';

  @override
  String get passwordIsTooWeak => 'hasło jest za słabe';

  @override
  String get passwordMin8 => 'hasło min 8';

  @override
  String get passwordOrApiKey => 'Hasło lub klucz API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Siła hasła: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Hasła nie pasują.';

  @override
  String get pasteAKey => 'Wklej klucz.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Wklej nowy klucz, aby zastąpić $arg1';
  }

  @override
  String get pasteTheKey => 'Wklej klucz';

  @override
  String get pasteYourAccountToken => 'Wklej token swojego konta';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Wklej poniżej klucz API $arg1. To jest ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Ścieżka musi pozostać wewnątrz obszaru roboczego NeoAgent.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Ścieżka musi znajdować się w folderze obszaru roboczego.';

  @override
  String get pauseLiveUpdates => 'Wstrzymaj aktualizacje na żywo';

  @override
  String get pauseTaskLoop => 'Wstrzymaj pętlę zadań';

  @override
  String get paused => 'Wstrzymano';

  @override
  String peakArg1(Object? arg1) {
    return 'szczyt $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Ludzie na prywatnych czatach';

  @override
  String get perAccountRateLimits => 'Limity stawek za konto';

  @override
  String get perCategoryPermissions => 'Uprawnienia według kategorii';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Zasady uprawnień dla poszczególnych narzędzi, bramki zatwierdzające i izolacja procesów na potrzeby wykonywania powłoki.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Wymagane pozwolenie: $arg1';
  }

  @override
  String get permissionsNeeded => 'Potrzebne uprawnienia';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Uprawnienia. Nikt inny nie może tego zmienić.';

  @override
  String get personOrChat => 'Osoba lub czat';

  @override
  String get personaBehaviorNotes => 'Notatki dotyczące zachowania persony';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Osobisty token dostępu dla bota Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Kanały osobiste i bezpośrednie powierzchnie wsparcia.';

  @override
  String get personalSelfChat => 'Osobisty czat';

  @override
  String get phoneNumber => 'Numer telefonu';

  @override
  String get pickARunFromTheList =>
      'Wybierz bieg z listy, aby zobaczyć jego etapy.';

  @override
  String get pickARunFromTheList2 =>
      'Wybierz bieg z listy po lewej stronie, aby poznać jego przebieg.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Wybierz spośród ostatnich czatów $arg1 lub samodzielnie dodaj osobę lub grupę.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Wybierz, w jaki sposób $arg1 używa tego konta.';
  }

  @override
  String get pickOneToFillInThe =>
      'Wybierz jedną, aby wypełnić zadanie. Później możesz wszystko poprawić.';

  @override
  String get picksUpWhereYouLeftOff =>
      'Rozpoczyna się w miejscu, w którym przerwałeś';

  @override
  String get plan => 'Planuj';

  @override
  String get planning => 'Planowanie';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Proszę wybrać harmonogram.';

  @override
  String get pleaseEnterAFilename => 'Proszę wprowadzić nazwę pliku.';

  @override
  String get pleaseEnterAKey => 'Proszę wprowadzić klucz.';

  @override
  String get pleaseEnterAPrompt => 'Proszę wprowadzić monit.';

  @override
  String get pleaseEnterATaskName => 'Proszę wpisać nazwę zadania.';

  @override
  String get pleaseEnterTheMemoryContent => 'Proszę wpisać zawartość pamięci.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Proszę podać kiedy zadanie ma zostać uruchomione.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Wybierz konto lub wprowadź prawidłowy identyfikator połączenia.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Wskaż NeoAgentowi dowolne zakończenie czatu kompatybilne z OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Skieruj aparat na kod widoczny na wylogowanym urządzeniu. Zatwierdzenie pozostanie na tym telefonie.';

  @override
  String get port => 'Portu';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port węzeł_env publiczny adres URL zaufanie proxy wdrożenie bezpiecznych plików cookie';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Automatyzacja premium z wyzwalaczami harmonogramu i integracji.';

  @override
  String get prepareQrCode => 'Przygotuj kod QR';

  @override
  String get preparingNeoagent => 'Przygotowywanie NeoAgenta…';

  @override
  String get preparingNeoagent2 => 'Przygotowanie NeoAgenta';

  @override
  String get pressAndHoldForQuickCapture =>
      'Naciśnij i przytrzymaj, aby szybko wykonać zdjęcie';

  @override
  String get pressKeysIsNotSupportedOn =>
      'naciśnięcie klawiszy nie jest obsługiwane na tej platformie.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Wciśnięto $arg1';
  }

  @override
  String get priceUnknown => 'Cena nieznana';

  @override
  String get primaryDisplay => 'Główny wyświetlacz';

  @override
  String get privateChat => 'Prywatny czat';

  @override
  String get privateChats => 'Prywatne czaty';

  @override
  String get privateChats2 => 'prywatne czaty';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Prywatne czaty: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Czaty prywatne $arg1 · grupy $arg2';
  }

  @override
  String get privateChatsOnly => 'Tylko prywatne czaty';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'adresy sieci prywatnej są niedozwolone.';

  @override
  String get profileEmailAndPersonalData =>
      'Profil, adres e-mail i dane osobowe';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Monituj, zanim NeoAgent pozostanie w zasobniku systemowym.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Podręczna pamięć podręczna: tokeny buforowane $arg1 ';
  }

  @override
  String get promptCopied => 'Monit skopiowany.';

  @override
  String get promptOrSchedule => 'monit lub harmonogram.';

  @override
  String get promptToPasteIntoAnotherAi => 'Monituj o wklejenie do innego AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Nie można rozpocząć łączenia dostawców.';

  @override
  String get providerSignInCouldNotBe =>
      'Nie można rozpocząć logowania się do dostawcy.';

  @override
  String get providers => 'Dostawcy';

  @override
  String get providersEachAccountCanStillPick =>
      'Dostawcy; każde konto może nadal wybrać własny model w Ustawieniach. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Dostawcy, integracje, głos i opcjonalne funkcje można w dowolnym momencie uzupełnić w Ustawieniach.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Wątki dotyczące problemów publicznych i żądań ściągnięcia, na które odpowiedzi mają tylko zatwierdzone osoby.';

  @override
  String get publicUrl => 'Publiczny adres URL';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Publiczny adres URL i dozwolone źródła';

  @override
  String get publicUrlOverride => 'Zastąpienie publicznego adresu URL';

  @override
  String get pullsTogetherTheDayAhead => 'Zbiera siły na nadchodzący dzień';

  @override
  String get pushToTalk => 'Naciśnij i mów';

  @override
  String get qrBasedPhoneLinking => 'Łączenie telefoniczne w oparciu o kod QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Logowanie QR zostało zakończone, ale NeoAgent nie mógł utrzymać sesji. Spróbuj ponownie.';

  @override
  String get qrLoginCouldNotBeStarted => 'Nie można rozpocząć logowania QR.';

  @override
  String get qrLoginRequestHasExpired => 'Żądanie logowania qr wygasło';

  @override
  String get qrLoginRequestWasNotFound => 'Nie znaleziono żądania logowania qr';

  @override
  String get qrPairing => 'Parowanie QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'uruchamiane zapytania; wszystko, co pisze, jest odrzucane.';

  @override
  String get query => 'Zapytanie';

  @override
  String get queryFilter => 'Zapytanie / Filtr';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'W kolejce jako sterowanie dla bieżącego przebiegu: $arg1';
  }

  @override
  String get quickstart => 'Szybki start';

  @override
  String get quit => 'Przestań';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'deszcz_start, alert_wiatru';

  @override
  String get ranAScriptInThePage => 'Uruchomiłem skrypt na stronie';

  @override
  String ranArg1(Object? arg1) {
    return 'Uruchomiłem $arg1';
  }

  @override
  String get rateLimits => 'Limity stawek';

  @override
  String get readAnArtifact => 'Przeczytaj artefakt';

  @override
  String get readAndEditFilesInsideYour =>
      'Czytaj i edytuj pliki w folderze NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Przeczytaj $arg1';
  }

  @override
  String get readError => 'Przeczytaj błąd';

  @override
  String get readFiles => 'Czytaj pliki';

  @override
  String get readOnly => 'Tylko do odczytu';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Przeczytaj folder i podsumuj stos, punkty wejścia i sposób jego uruchomienia.';

  @override
  String get readThePage => 'Przeczytaj stronę';

  @override
  String get readTheUiTree => 'Przeczytaj drzewo interfejsu użytkownika';

  @override
  String get readWrite => 'Czytaj/pisz';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Odczytuje kroki, tętno, sen, ćwiczenia i wagę.';

  @override
  String get ready => 'Gotowy';

  @override
  String get readyForFirstTimeSetup => 'Gotowy do pierwszej konfiguracji';

  @override
  String get readyToConnect => 'Gotowy do podłączenia';

  @override
  String get recentChannelActivity => 'Ostatnia aktywność na kanale';

  @override
  String get recentChats => 'Ostatnie czaty';

  @override
  String get recentDecisions => 'Ostatnie decyzje';

  @override
  String get recentFailedRuns => 'Ostatnie nieudane biegi';

  @override
  String get recentGroupDecisions => 'Ostatnie decyzje grupowe';

  @override
  String get recentRuns => 'Ostatnie biegi';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Ostatnie przebiegi zajmują około $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Najnowsze dane wyjściowe serwera, najpierw najnowsze.';

  @override
  String get recentUsage4Hours => 'Ostatnie użycie (4 godziny)';

  @override
  String get recents => 'Najnowsze';

  @override
  String get recipientField => 'Pole odbiorcy';

  @override
  String get reconnectOrFinishSetup =>
      'Podłącz ponownie lub zakończ konfigurację';

  @override
  String get reconnectingThisDevice => 'Ponowne podłączanie tego urządzenia…';

  @override
  String get recurring => 'Powtarzające się';

  @override
  String get redirectUri => 'URI przekierowania';

  @override
  String get redoOnboarding => 'Ponów proces wdrażania';

  @override
  String get refresh => 'Odśwież';

  @override
  String get refreshCode => 'Odśwież kod';

  @override
  String get refreshNow => 'Odśwież teraz';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Odśwież ekran Androida, aby spróbować ponownie.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Odmawiaj wysyłania, chyba że połączenie zostanie uaktualnione do TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'niezależnie od poniższych ustawień poszczególnych kategorii.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Zarejestruj $arg1, aby uzyskać dostęp do procesu przywoływania asystenta.';
  }

  @override
  String get registrationIsClosed => 'rejestracja jest zamknięta';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'rejestracja zarejestruj nowe konta zezwól na rejestrację';

  @override
  String get rejectInvalidTlsCertificates =>
      'Odrzuć nieprawidłowe certyfikaty TLS';

  @override
  String relationArg1(Object? arg1) {
    return 'Relacja: $arg1';
  }

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'zwolnij i uruchom ponownie. Połączone aplikacje łączą się ponownie, gdy połączenie zostanie przywrócone.';

  @override
  String get releaseChannel => 'Zwolnij kanał';

  @override
  String get releaseCommitBranchNode => 'zwolnij węzeł gałęzi zatwierdzenia';

  @override
  String get releaseWhenYouAreDone => 'Zwolnij, kiedy skończysz.';

  @override
  String get reloadNow => 'Załaduj ponownie teraz';

  @override
  String get rememberThisChoice => 'Zapamiętaj ten wybór';

  @override
  String get remove => 'Usuń';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Usunąć „$arg1” i zapisane w nim kroki z historii uruchomień?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Usuń „$arg1” z pamięci rdzeniowej.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Usunąć klucz $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'usuń usuń użytkownika RODO';

  @override
  String get removeSmtpPassword => 'Usuń hasło SMTP';

  @override
  String get removeTheSmtpPassword => 'Usunąć hasło SMTP?';

  @override
  String get rename => 'Zmień nazwę';

  @override
  String get renameSecurityKey => 'Zmień nazwę klucza bezpieczeństwa';

  @override
  String get renameSession => 'Zmień nazwę sesji';

  @override
  String get repairAndRetry => 'Napraw i spróbuj ponownie';

  @override
  String get repairDesktop => 'Napraw pulpit';

  @override
  String get repeat => 'Powtórz';

  @override
  String get repliesWhenTagged => 'Odpowiedzi po oznaczeniu';

  @override
  String get replyToAddress => 'Adres zwrotny';

  @override
  String replyToArg1(Object? arg1) {
    return 'Odpowiedz na $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Repozytorium musi być w formacie właściciel/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Odtwórz opisany przeze mnie błąd, znajdź jego przyczynę i napraw ją za pomocą testu regresyjnego.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'żądanie nie powiodło się z http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Żądanie nie powiodło się przy użyciu protokołu HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Poproś o uprawnienia';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Żądanie do $arg1 nie powiodło się, zanim backend odpowiedział.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Żądano $arg1';
  }

  @override
  String get requireStarttls => 'Wymagaj STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Wymagane za serwerem proxy HTTPS lub TLS. Obowiązuje po serwerze ';

  @override
  String get requiredExampleBerlinDe => 'Wymagane. Przykład: Berlin, DE';

  @override
  String get requiredFormatOwnerRepo => 'Wymagane. Format: właściciel/repo';

  @override
  String get reserveAssistantHotkey => 'Skrót klawiszowy asystenta rezerwacji';

  @override
  String get reset => 'Zresetuj';

  @override
  String get resetPassword => 'Zresetuj hasło';

  @override
  String get resetView => 'Zresetuj widok';

  @override
  String get responsibilities => 'Obowiązki';

  @override
  String get restart => 'Uruchom ponownie';

  @override
  String get restartToFinishTheUpdate =>
      ' Uruchom ponownie, aby zakończyć aktualizację.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Przywracanie poprzedniego środowiska wykonawczego NeoAgent';

  @override
  String get restrictDelegationTargets => 'Ogranicz cele delegowania';

  @override
  String get result => 'Wynik';

  @override
  String get resultDelivery => 'Dostawa wyników';

  @override
  String get resultOneClickAddsOneYou =>
      'wynik. Jedno kliknięcie dodaje jedno; możesz go później edytować.';

  @override
  String get results => 'Wyniki';

  @override
  String get retrievalInspector => 'Inspektor odzyskiwania';

  @override
  String get retry => 'Spróbuj ponownie';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Wielokrotnego użytku · używany $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Przejrzyj niezatwierdzone zmiany';

  @override
  String get revoke => 'Odwołaj';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Najpierw unieważnij administratora za pomocą `neoagent admin unieważnij $arg1`';
  }

  @override
  String get revokeThisLink => 'Unieważnić to łącze?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Okno wsadowe pomieszczenia: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Obróć, aby kontynuować';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'wydziwianie. Aby zobaczyć, dodaj LIMIT lub węższą klauzulę WHERE ';

  @override
  String get rule => 'Reguła';

  @override
  String get run => 'Wykonanie';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Uruchom dowolne polecenia na swoim komputerze lub maszynie wirtualnej.';

  @override
  String get runAt => 'Biegnij o';

  @override
  String get runCompleted => 'Uruchomienie zakończone';

  @override
  String get runFailed => 'Uruchomienie nie powiodło się';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Uruchom git diff, przejrzyj niezatwierdzone zmiany pod kątem błędów i problemów ze stylem i podsumuj to, co znajdziesz.';

  @override
  String get runNotFound => 'Nie znaleziono uruchomienia';

  @override
  String get runNow => 'Uruchom teraz';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Uruchamiaj przychodzące osobiste wiadomości WhatsApp.';

  @override
  String get runQuery => 'Uruchom zapytanie';

  @override
  String get runShellCommandsOrInstallApps =>
      'Uruchamiaj polecenia powłoki lub instaluj aplikacje na swoim urządzeniu z Androidem.';

  @override
  String get runStarted => 'Uruchomiono bieg';

  @override
  String get runStatus => 'Stan uruchomienia';

  @override
  String get runStopped => 'Bieg zatrzymany';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Uruchamiaj polecenia terminala i otwieraj aplikacje lub strony internetowe.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Uruchom ten serwer: konta, aktualizacje, dostawcy, konfiguracja ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Uruchom, gdy nadejdzie pasująca wiadomość Gmail.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Uruchom, gdy nadejdzie pasująca wiadomość e-mail z programu Outlook.';

  @override
  String get runWhenANewIssueMatching =>
      'Uruchamiaj, gdy w repozytorium zostanie otwarta nowa sprawa pasująca do Twoich filtrów.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Uruchom, gdy zostanie utworzona nowa pamięć NeoRecall pasująca do Twoich filtrów.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Uruchom, gdy na Twoim urządzeniu pojawi się powiadomienie.';

  @override
  String get runWhenASlackMessageMatches =>
      'Uruchamiaj, gdy wiadomość Slack pasuje do wybranego zakresu.';

  @override
  String get runWhenATeamsChatMessage =>
      'Uruchom, gdy wiadomość czatu w aplikacji Teams pasuje do wybranego zakresu.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Uruchamiaj, gdy dla danej lokalizacji prognozowane są skonfigurowane zdarzenia pogodowe.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'uruchomić. Chociaż dowolny model jest wyłączony, modele dodawane przez dostawców ';

  @override
  String get running => 'W toku';

  @override
  String runningArg1(Object? arg1) {
    return 'Uruchamiam $arg1';
  }

  @override
  String get runningTask => 'Uruchomione zadanie';

  @override
  String get runningTool => 'Narzędzie do biegania';

  @override
  String get runs => 'Wykonania';

  @override
  String get runsEveryDayAtTheSelected =>
      'Uruchamia codziennie o wybranej godzinie.';

  @override
  String get runsFourTimesPerHour => 'Kursuje cztery razy na godzinę.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— przebiegi, wiadomości, wspomnienia, integracje, pliki i ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'przebiegi, wiadomości, wspomnienia, integracje, pliki i sesje. ';

  @override
  String get runsMondayThroughFriday => 'Kursuje od poniedziałku do piątku.';

  @override
  String get runsOnSelectedWeekdays => 'Kursuje w wybrane dni robocze.';

  @override
  String get runsOncePerHour => 'Działa raz na godzinę.';

  @override
  String get runsOncePerMonthOnThe =>
      'Uruchamia się raz w miesiącu w wybrany dzień.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Działa tylko po naciśnięciu przycisku Uruchom teraz.';

  @override
  String get runsPerDay => 'Kursuje dziennie';

  @override
  String get runsPerDay30Days => 'Działa dziennie (30 dni)';

  @override
  String get runsThatCompleted => 'Uruchomienia, które zostały ukończone';

  @override
  String get runsThisWeek => 'Kursuje w tym tygodniu';

  @override
  String get runsToday => 'Biega dzisiaj';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Uruchomienia, narzędzia, pamięć, planowanie, umiejętności i MCP są dostępne tutaj.';

  @override
  String get runsTwicePerHour => 'Kursuje dwa razy na godzinę.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Uruchomienia będą opierać się na współdzielonym kluczu serwera dla $arg1, jeśli taki jest skonfigurowany. Tego nie można cofnąć.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Środowisko wykonawcze $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Czas działania: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Ustawienia środowiska wykonawczego, od których zaczynał ten serwer. Edytuj je pod ';

  @override
  String get runtimeSetupRequired =>
      'Wymagana konfiguracja środowiska wykonawczego';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Klucz publiczny podpisywania środowiska wykonawczego musi mieć 32 bajty.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Zapisz';

  @override
  String get saveATrelloApiKeyFor =>
      'Zapisz klucz API Trello dla tego agenta, a następnie bezpiecznie połącz jedno konto Trello. Token konta jest przechowywany na serwerze i używany tylko dla tego agenta.';

  @override
  String get saveAccount => 'Zapisz konto';

  @override
  String get saveChanges => 'Zapisz zmiany';

  @override
  String get saveCloudComputerSettings =>
      'Zapisz ustawienia komputera w chmurze';

  @override
  String get saveConnect => 'Zapisz i połącz';

  @override
  String get saveDefaults => 'Zapisz ustawienia domyślne';

  @override
  String get saveDiagnosticReport => 'Zapisz raport diagnostyczny';

  @override
  String get saveEmail => 'Zapisz e-mail';

  @override
  String get saveEmailSettings => 'Zapisz ustawienia poczty e-mail';

  @override
  String get saveGeneralSettings => 'Zapisz ustawienia ogólne';

  @override
  String get saveName => 'Zapisz nazwę';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Zapisz diagnostykę konfiguracji NeoAgent';

  @override
  String get saveOnly => 'Tylko zapisz';

  @override
  String get saveSetup => 'Zapisz konfigurację';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Zapisz teraz te kody odzyskiwania. Nie zostaną one ponownie pokazane.';

  @override
  String get savedDeliveryDestination => 'Zapisane miejsce dostawy';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Zapisane limity szybkości dla @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Zeskanuj kod QR logowania NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Zeskanuj kod QR parowania NeoAgent z innego urządzenia i zatwierdź go w tej sesji uruchamiania.';

  @override
  String get scanLoginQr => 'Zeskanuj kod QR logowania';

  @override
  String get scanPairingQr => 'Zeskanuj parowanie QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skanuj żądania logowania QR z niezalogowanych urządzeń i zatwierdzaj je w tej uwierzytelnionej sesji mobilnej.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Zeskanuj, aby zakończyć $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Zeskanuj za pomocą NeoAgent na swoim telefonie';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Skanuje nowe wiadomości e-mail i wysyła powiadomienia tylko wtedy, gdy coś jest ważne.';

  @override
  String get schedule => 'Harmonogram';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'zaplanowany czas. Po zmierzeniu przebiegów rozpocznie się wcześniej.';

  @override
  String scoreArg1(Object? arg1) {
    return 'Wynik: $arg1';
  }

  @override
  String get screen => 'Ekran';

  @override
  String get screenAction => 'akcja ekranowa';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scroll nie jest obsługiwany na tej platformie.';

  @override
  String get scrollToBottom => 'Przewiń w dół';

  @override
  String get search => 'Szukaj';

  @override
  String get search2 => 'Szukaj…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Wyszukaj ustawienia administratora (np. SMTP, Ollama, logi)';

  @override
  String get searchAgain => 'Wyszukaj ponownie';

  @override
  String get searchByUsernameOrEmail =>
      'Szukaj według nazwy użytkownika lub adresu e-mail';

  @override
  String get searchChannels => 'Wyszukaj kanały';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Przeszukuj odkryte kanały wiadomości, kontakty, grupy i ostatnie rozmowy.';

  @override
  String get searchGroups => 'Przeszukaj grupy';

  @override
  String get searchMemory => 'Przeszukaj pamięć';

  @override
  String get searchModelsOrProviders => 'Wyszukaj modele lub dostawców';

  @override
  String get searchModelsOrProviders2 => 'Wyszukaj modele lub dostawców…';

  @override
  String get searchRecentPeopleAndGroups => 'Wyszukaj ostatnie osoby i grupy';

  @override
  String get searchSessions => 'Wyszukaj sesje';

  @override
  String get searchSettings => 'Ustawienia wyszukiwania';

  @override
  String get searchTitleModelTriggerRunId =>
      'Wyszukaj tytuł, model, wyzwalacz, identyfikator uruchomienia';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Narzędzia wyszukiwania, integracje i umiejętności';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Szukany kod dla „$arg1”';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Szukane pliki dla „$arg1”';
  }

  @override
  String get secretField => 'Tajne pole';

  @override
  String get secureCookies => 'Bezpieczne pliki cookie';

  @override
  String get security => 'Bezpieczeństwo';

  @override
  String get securityKey => 'Klucz bezpieczeństwa';

  @override
  String get securityKeyPromptWasDismissed =>
      'Monit o klucz bezpieczeństwa został odrzucony.';

  @override
  String get securityKeySignInCompletedBut =>
      'Logowanie przy użyciu klucza bezpieczeństwa zostało zakończone, ale NeoAgent nie mógł utrzymać sesji przeglądarki. Zaloguj się ponownie.';

  @override
  String get securityKeySignInCouldNot =>
      'Nie można rozpocząć logowania za pomocą klucza bezpieczeństwa.';

  @override
  String get securityKeys => 'Klucze bezpieczeństwa';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Klucze bezpieczeństwa są dostępne wyłącznie w aplikacji internetowej NeoAgent.';

  @override
  String get seeAll => 'Zobacz wszystko';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Sprawdź, z którego serwera NeoAgent korzysta to okno, i uruchom backend na tym komputerze.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'zobacz swoją nazwę użytkownika i te ustawienia, nigdy swoje czaty i wspomnienia ';

  @override
  String get selectARun => 'Wybierz bieg';

  @override
  String get selectASessionToSeeIts =>
      'Wybierz sesję, aby zobaczyć jej komputer, pliki i zmiany.';

  @override
  String get selectAll => 'Zaznacz wszystko';

  @override
  String get selectAll2 => 'Wybierz wszystko';

  @override
  String selectArg1(Object? arg1) {
    return 'Wybierz $arg1';
  }

  @override
  String get selectTrigger => 'Wybierz opcję Wyzwalacz';

  @override
  String semanticArg1(Object? arg1) {
    return 'Semantyczny: $arg1';
  }

  @override
  String get send => 'Wyślij (⌘↵)';

  @override
  String get send2 => 'Wyślij';

  @override
  String get sendATaskFromChatAnd =>
      'Wyślij zadanie z czatu, a tutaj wyświetli się historia jego wykonania.';

  @override
  String get sendItToATeammateWith =>
      'wyślij go do kolegi z drużyny posiadającego konto na tym serwerze.';

  @override
  String get sendLink => 'Wyślij link';

  @override
  String get sendPath => 'Wyślij ścieżkę';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Wysyłaj żądania POST/PUT/DELETE do zewnętrznych API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Wyślij ten link tylko do osoby, dla której jest przeznaczony. Jest pokazany raz; ';

  @override
  String get senderAddress => 'Adres nadawcy';

  @override
  String get senderFilterOptional => 'Filtr nadawcy (opcjonalnie)';

  @override
  String get sentSharedAttachments => 'Wysłano udostępnione załączniki.';

  @override
  String get separateAccount => 'Oddzielne konto';

  @override
  String get server => 'Serwer';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Domyślny serwer ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Domyślne ustawienia serwera dla połączeń głosowych w aplikacji. Połączenia odbywają się na żywo ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'sam serwer: konta, dostawcy i konfiguracja.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Serwer, nick, kanał i opcjonalnie TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'Kopia błędów ostrzeżeń konsoli wyjściowej serwera';

  @override
  String get serverProviderCredentials => 'Poświadczenia dostawcy serwera';

  @override
  String get serverUrl => 'Adres URL serwera';

  @override
  String get serverUsageLimitsDonTApply =>
      'Limity użycia serwera nie dotyczą modeli działających na własnym kluczu.';

  @override
  String get serviceEmail => 'Serwisowy e-mail';

  @override
  String get serviceEmailIsNotConfigured =>
      'Adres e-mail usługi nie jest skonfigurowany';

  @override
  String get serviceEmailSmtp => 'Usługowy adres e-mail (SMTP)';

  @override
  String get sessionActions => 'Działania sesyjne';

  @override
  String get sessions => 'Sesje';

  @override
  String get sessions2 => 'SESJE';

  @override
  String get sessionsArePinnedToAFolder =>
      'Sesje są przypinane do folderu i komputera. Zacznij od planowania, budowania, testowania i wysyłania stąd.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sesji (art. 17 RODO). Kont administratorów nie można usunąć ';

  @override
  String get sessionsLogoutRevokeForce => 'wylogowanie z sesji cofa siłę';

  @override
  String get setBlockAskAllowPerTool =>
      'Ustaw blokowanie/zapytanie/zezwolenie dla każdej kategorii narzędzia lub wybierz tryb globalny.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Skonfiguruj NeoAgent na tym komputerze';

  @override
  String get setUpOrConnectNeoagent => 'Skonfiguruj lub podłącz NeoAgent';

  @override
  String get setUrl => 'Ustaw adres URL';

  @override
  String get settings => 'Ustawienia';

  @override
  String get settingsAndCannotBeUndone => 'ustawień i nie można ich cofnąć.';

  @override
  String get settingsArea => 'Obszar ustawień';

  @override
  String get settingsAreas => 'Obszary ustawień';

  @override
  String get setup => 'Konfiguracja';

  @override
  String get setupDetails => 'Szczegóły konfiguracji';

  @override
  String get setupRequired => 'Wymagana konfiguracja';

  @override
  String get setupWasCancelled => 'Konfiguracja została anulowana.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Udostępnione załączniki z klienta NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Udostępnione z innej aplikacji';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Udostępnione klucze dostawcy są skonfigurowane na serwerze. Aby zamiast tego użyć własnego klucza API lub niestandardowego punktu końcowego, przejdź do Zaawansowane → Przynieś własny klucz.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Udostępnione czacie NeoAgent i jego pamięci.';

  @override
  String get shellCommands => 'Polecenia powłoki';

  @override
  String showAllArg1(Object? arg1) {
    return 'Pokaż wszystkie $arg1';
  }

  @override
  String get showEarlier => 'Pokaż wcześniej';

  @override
  String get showEveryStep => 'Pokaż każdy krok';

  @override
  String get showTools => 'Pokaż narzędzia';

  @override
  String get showWorkbenchJ => 'Pokaż stół warsztatowy (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Pokaz pierwszego $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Pokazane na pasku bocznym. Pozostaw puste, aby użyć swojej nazwy użytkownika.';

  @override
  String get signIn => 'Zaloguj się';

  @override
  String get signInCompletedButNeoagentCould =>
      'Logowanie zakończone, ale NeoAgent nie mógł utrzymać sesji przeglądarki. Zaloguj się ponownie. Jeśli to się będzie powtarzać, sprawdź ustawienia plików cookie sesji backendu.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Logowanie zakończone, ale NeoAgent nie mógł utrzymać sesji przeglądarki. Zaloguj się ponownie. Jeśli tak się stanie, plik cookie sesji zaplecza prawdopodobnie nie zostanie zachowany.';

  @override
  String get signInToThisNeoagentServer =>
      'Zaloguj się do tego serwera NeoAgent przed zeskanowaniem kodu QR parowania.';

  @override
  String get signInWithAHardwareKey =>
      'Zaloguj się za pomocą klucza sprzętowego lub hasła zamiast hasła. ';

  @override
  String get signInWithASecurityKey =>
      'Zaloguj się przy użyciu klucza bezpieczeństwa';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Zaloguj się za pomocą $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Zatwierdź NeoAgent na swoim koncie $arg1. Brak klucza do skopiowania.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Czekam na $arg1. Zakończ w przeglądarce.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Wklej kod $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Po zatwierdzeniu NeoAgenta, $arg1 pokazał jednorazowy kod. Wklej to tutaj.';
  }

  @override
  String get signInCode => 'Kod logowania';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Zalogowano się za pomocą $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Logowanie nie powiodło się: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Zaloguj się przy użyciu tego samego adresu e-mail i hasła głównego, którego używasz w Bitwarden. Hasło główne i kod dwuetapowy służą wyłącznie do logowania i nigdy nie są przechowywane ani wysyłane do sztucznej inteligencji.';

  @override
  String get signOut => 'Wyloguj się';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Wylogować się wszędzie z @$arg1?';
  }

  @override
  String get signOutEverywhere => 'Wyloguj się wszędzie';

  @override
  String get signalCliRestApiBridge => 'mostek API REST sygnału';

  @override
  String get signalCliServerUrl => 'Adres URL serwera sygnału-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Podpisano @$arg1 z każdej sesji.';
  }

  @override
  String get signedInDevices => 'Zalogowane urządzenia';

  @override
  String get signedInWithin24Hours => 'Zalogowano w ciągu 24 godzin';

  @override
  String get signingSecret => 'Sekret podpisu';

  @override
  String sinceArg1(Object? arg1) {
    return 'Od $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'od $arg1';
  }

  @override
  String get singleMessage => 'Pojedyncza wiadomość';

  @override
  String get singleUse => 'Jednorazowego użytku';

  @override
  String get skill => 'Umiejętność';

  @override
  String get skillChanges => 'Zmiany umiejętności';

  @override
  String get skillContent => 'Treść umiejętności';

  @override
  String get skills => 'Umiejętności';

  @override
  String get skip => 'Pomiń';

  @override
  String get skipForNow => 'Pomiń na razie';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Pomiń to zadanie, zanim wywoła ono model.';

  @override
  String get slackMessageReceived => 'Odebrano wiadomość dotyczącą Slacka';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Uśpij sesje $arg1';
  }

  @override
  String get smartSelector => 'inteligentny selektor';

  @override
  String get smartSelector2 => 'Inteligentny selektor';

  @override
  String get smartSelectorPool => 'Pula inteligentnego selektora';

  @override
  String get smtpHost => 'Host SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp hasło nadawcy poczty tls potwierdzenie powiadomień zresetowane';

  @override
  String get smtpPassword => 'Hasło SMTP';

  @override
  String get smtpPort => 'Port SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Port SMTP musi być liczbą całkowitą z zakresu od 1 do 65535.';

  @override
  String get smtpUsername => 'Nazwa użytkownika SMTP';

  @override
  String get soTheRunStartsThatMuch => 'więc bieg zaczyna się dużo wcześniej.';

  @override
  String get socialBehaviorOff => 'Zachowania społeczne wyłączone';

  @override
  String get socialIntelligence => 'inteligencja społeczna';

  @override
  String get socialIntelligence2 => 'Inteligencja społeczna';

  @override
  String get socialObservability => 'Obserwowalność społeczna';

  @override
  String get socialReach => 'zasięg społeczny';

  @override
  String get socialReach2 => 'Zasięg społeczny';

  @override
  String get socialReach3 => 'Zasięg społeczny';

  @override
  String get socialReachUpdated => 'Zaktualizowano zasięg społecznościowy.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Agenci źródeł społecznościowych mogą czytać bezpośrednio, w tym kanały, repozytoria, Reddit, X, filmy i dane rynkowe oparte na plikach cookie.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get source => 'Źródło';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Identyfikator przestrzeni lub czatu używany, gdy ten agent rozpoczyna rozmowę.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Obsługa webhooka i wywołań zwrotnych aplikacji';

  @override
  String get speaking => 'Mówienie';

  @override
  String get speechToSpeechModelUsingThe =>
      'model mowy na mowę przy użyciu klucza OpenAI lub Google pod ';

  @override
  String get speechToText => 'Zamiana mowy na tekst';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Funkcja zamiany mowy na tekst transkrybuje notatki głosowe i dyktando. Auto korzysta z OpenAI, Gemini lub Deepgram, w zależności od tego, który z nich ma klucz API. Model odpowiedzi głosowej to model czatu, który odpowiada na notatki głosowe.';

  @override
  String get sqlConsole => 'Konsola SQL';

  @override
  String get stable => 'Stabilny';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable instaluje najnowszą opublikowaną wersję backendu.';

  @override
  String get stackTrace => 'ślad stosu';

  @override
  String get standard => 'Standardowe';

  @override
  String get standardView => 'Widok standardowy';

  @override
  String get start => 'Zacznij';

  @override
  String get startASessionToPlanOr =>
      'Rozpocznij sesję, aby zaplanować lub zbudować za pomocą NeoAgent.';

  @override
  String get startAndroid => 'Uruchom Androida';

  @override
  String get startComputer => 'Uruchom komputer';

  @override
  String get startFullSetup => 'Rozpocznij pełną konfigurację';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Rozpocznij konfigurację';

  @override
  String get startTalking => 'Zacznij mówić';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Najpierw uruchom telefon z Androidem, a następnie upuść tutaj plik .apk lub .apks.';

  @override
  String get startTheServerLaterFromThe =>
      'Uruchom serwer później z listy po zapisaniu konfiguracji.';

  @override
  String get startWithARecommendedTask => 'Zacznij od zalecanego zadania';

  @override
  String get startingAndroid => 'Uruchamianie Androida';

  @override
  String get startingYourComputer => 'Uruchamianie komputera';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Zaczyna się od xoxb-. Z poświadczeń aplikacji Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Błąd: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statystyki uruchamia tokeny użytkownicy wykresy wskaźnika sukcesu';

  @override
  String get status => 'Stan';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'dostawcy środowiska wykonawczego bazy danych stanu VM';

  @override
  String get statusIsNotLoadedYet => 'Status nie został jeszcze załadowany.';

  @override
  String get stayManagedByYou => 'pozostań zarządzany przez Ciebie.';

  @override
  String get stayOnTheCall => 'Pozostań na rozmowie';

  @override
  String get stayedQuiet => 'Zachowałem ciszę';

  @override
  String get steering => 'UKŁAD KIEROWNICZY';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'KROK $arg1 $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Kroki $arg1';
  }

  @override
  String get stop => 'Zatrzymaj';

  @override
  String get stop2 => 'Zatrzymaj się (⌘.)';

  @override
  String get stopManaging => 'Przestań zarządzać';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Przestać zarządzać $arg1?';
  }

  @override
  String get stopRun => 'Zatrzymaj bieg';

  @override
  String get stopSpeaking => 'Przestań mówić';

  @override
  String get stoppedBeforeCompletion => 'Zatrzymano przed zakończeniem';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Błąd: $arg1';
  }

  @override
  String get storage => 'Przechowywanie';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'przechowywane w postaci zaszyfrowanej i wykorzystywane wyłącznie do własnych celów.';

  @override
  String get storedMetrics => 'Przechowywane metryki';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Przechowuje tylko klucz sesji Bitwarden zaszyfrowany na tym serwerze, więc połączenia przetrwają ponowne uruchomienie. Możesz go zablokować w dowolnym momencie.';

  @override
  String get strong => 'Silny';

  @override
  String get strongPassword => 'Silne hasło.';

  @override
  String get subAgent => 'Podagent';

  @override
  String get subagentUpdate => 'Aktualizacja subagenta';

  @override
  String get subagentUpdate2 => 'Aktualizacja subagenta.';

  @override
  String get successRate => 'Wskaźnik sukcesu';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Sugestie: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Podsumuj mój ostatni bieg';

  @override
  String get supportUrl => 'Adres URL wsparcia';

  @override
  String get supportedRainStartSnowStartWind =>
      'Obsługiwane: deszcz_start, śnieg_start, wind_alert, temperatura_powyżej, temperatura_poniżej';

  @override
  String get switchAgent => 'Zmień agenta';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Dowiązania symboliczne nie są dozwolone w ścieżkach NeoAgent Workspace.';

  @override
  String get syncNow => 'Zsynchronizuj teraz';

  @override
  String get synologyChat => 'Czat Synology';

  @override
  String get systemPrivacySettings => 'Ustawienia prywatności systemu';

  @override
  String get tableInfoUsers => 'Informacje o tabeli (użytkownicy)';

  @override
  String get tagsOnly => 'Tylko tagi';

  @override
  String get tasks => 'Zadania';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Zadania działają samodzielnie i wysyłają Ci wiadomość ';

  @override
  String get teach => 'Naucz';

  @override
  String get teachingInProgress => 'Trwa nauczanie';

  @override
  String get team => 'Zespół';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Linki do zespołu nigdy nie czynią nikogo administratorem serwera. Administratorzy uruchamiają ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Przestrzenie zespołu, pokoje, kanały i społeczności na żywo.';

  @override
  String get teamsMessageReceived => 'Otrzymano wiadomość zespołu';

  @override
  String get templates => 'Szablony';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Tymczasowe pliki instalacyjne zostaną wyczyszczone później.';

  @override
  String get tenantId => 'Identyfikator najemcy';

  @override
  String get testConnection => 'Połączenie testowe';

  @override
  String get testConnection2 => 'Połączenie testowe';

  @override
  String get textChat => 'Tekst i czat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'którzy dodali własny klucz, nadal go używają.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Ten adres e-mail należy już do istniejącego konta. Najpierw zaloguj się, a następnie połącz Google z poziomu ustawień konta.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Ten adres e-mail jest już powiązany z innym kontem.';

  @override
  String get thatGoogleAccountIsAlreadyLinked =>
      'To konto Google jest już połączone z innym kontem NeoAgent.';

  @override
  String get thatQrCodeIsNotA =>
      'Ten kod QR nie jest prośbą o zalogowanie się do NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Ten kod QR nie jest prośbą o parowanie NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Ten klucz bezpieczeństwa jest już zarejestrowany na tym koncie.';

  @override
  String get theAddress => 'Adres';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Adres Twojego serwera BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adres, z którego korzystają użytkownicy i dostawcy OAuth ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agent odczytuje wymienione przez Ciebie godziny i uruchamia zaplanowane zadania w tej strefie czasowej.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agent będzie pytał przed każdym wrażliwym narzędziem, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Agent zignoruje tę umiejętność.';

  @override
  String get theAppCouldNotReachThis =>
      'Aplikacja nie mogła dotrzeć do tego wdrożenia NeoAgent. Sprawdź połączenie sieciowe lub potwierdź, że adres URL usługi jest prawidłowy.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Przeglądarka zablokowała żądanie do $arg1 ze względu na Politykę bezpieczeństwa treści.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Przeglądarka zablokowała wymagane żądanie ze względu na Politykę bezpieczeństwa treści.';

  @override
  String get theCloudWorkspace => 'obszar roboczy w chmurze';

  @override
  String get theComputerCouldNotStart => 'Nie można uruchomić komputera';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Komputer potrzebuje więcej wolnego miejsca na dysku hosta NeoAgent. Zwolnij trochę miejsca i spróbuj ponownie.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Środowisko wykonawcze komputera wymaga naprawy. Uruchom NeoAgent Doctor i spróbuj ponownie.';

  @override
  String get theConnectionTestFailed => 'Test połączenia nie powiódł się.';

  @override
  String get theDesktopDidNotStart => 'Pulpit nie został uruchomiony';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Odkryty NeoAgent zwrócił niekompletne dane identyfikacyjne.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Odkryty NeoAgent używa nieobsługiwanego protokołu konfiguracji.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Odkryta usługa nie jest NeoAgentem.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Pobrane środowisko wykonawcze NeoAgent nie przeszło weryfikacji.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Webhook przestrzeni Google Chat, do którego ten agent powinien wysyłać posty.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Instalator nie jest już dostępny.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktywny pulpit systemu Linux jest dostępny w aplikacji internetowej NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Wprowadzenie nie jest dostępne na tym urządzeniu.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Najnowsze informacje są dostępne na każdym koncie.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Ostatnie okno synchronizacji zakończyło się $arg1 i nie znalazło żadnych nowych rekordów Health Connect. Przechowywane dane poniżej pochodzą z wcześniejszych synchronizacji.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Sesja graficzna systemu Linux nie jest uruchomiona.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Model głosu na żywo nie odpowiedział. Spróbuj ponownie.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Lokalna komenda NeoAgent zakończyła działanie z kodem $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Upłynął limit czasu lokalnego polecenia NeoAgent.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Lokalne środowisko wykonawcze NeoAgent wymaga naprawy.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Lokalne środowisko wykonawcze wymaga naprawy ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Lokalny katalog domowy użytkownika jest niedostępny.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Konto pocztowe NeoAgent wysyła potwierdzenia rejestracji, logowania ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Agent główny jest tworzony automatycznie w razie potrzeby.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'W tej wersji brakuje odpowiedniego środowiska wykonawczego NeoAgent.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Przychodzący webhook Mattermost, do którego ten agent powinien wysyłać wiadomości.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modele, pomiędzy którymi Inteligentny Selektor przełącza się automatycznie.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Pobieranie zaplecza NeoAgent nie zgadzało się z manifestem.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Pobieranie zaplecza NeoAgent było niekompletne.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Backend NeoAgent na tym komputerze nie odpowiada na porcie ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Nie można pobrać środowiska wykonawczego NeoAgent.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Odpowiedź backendu NeoAgent na $arg1 trwała zbyt długo.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Wdrożenie NeoAgent odpowiedziało HTTP 402 zamiast normalnego 401 w przypadku nieprawidłowych poświadczeń. Sprawdź odwrotne proxy, bramkę uwierzytelniania lub reguły związane z płatnościami na tym serwerze.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Wdrożenie NeoAgent odpowiedziało protokołem HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Wdrożenie NeoAgent odpowiedziało protokołem HTTP 402. Sprawdź odwrotne proxy, bramę uwierzytelniania lub reguły związane z płatnościami na tym serwerze.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Instancja NeoAgent, z którą połączona jest ta aplikacja.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Usługa wydania NeoAgent zwróciła nieprawidłowe dane.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Metadane artefaktu środowiska wykonawczego NeoAgent są nieprawidłowe.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Manifest środowiska wykonawczego NeoAgent nie przeszedł weryfikacji podpisu.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Manifest środowiska wykonawczego NeoAgent nie zawiera artefaktów.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Podpis manifestu środowiska wykonawczego NeoAgent jest nieprawidłowy.';

  @override
  String get thePasswordYouSetInBluebubbles => 'Hasło ustawione w BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Ludzie, którymi zarządzasz, zostają z Tobą.';

  @override
  String get theProviderAnswers => 'dostawca odpowiada.';

  @override
  String get theQueryReturnedNoRows =>
      'Zapytanie nie zwróciło żadnych wierszy.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Żądany wyświetlacz pulpitu nie jest dostępny.';

  @override
  String get theRest => 'reszta.';

  @override
  String get theRestEndpointForYourSignal =>
      'Punkt końcowy REST dla instancji sygnału-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Bieg zostanie wstrzymany do czasu Twojej odpowiedzi.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Bieg rozpoczyna się o zaplanowanej godzinie.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Środowisko wykonawcze to lekki pulpit Debian Linux z Chromium, PCManFM, podkładką pod mysz, LXTerminal, Python, Git i standardowymi narzędziami wiersza poleceń. Jego pojemnością zarządza host NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Nie można rozpocząć rejestracji klucza bezpieczeństwa.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'serwer przechowuje jedynie jego odcisk palca.';

  @override
  String get theServerOnThisComputerIs => 'Serwer na tym komputerze nie działa';

  @override
  String get theServerReportedNoHealthChecks =>
      'Serwer nie zgłosił żadnych kontroli stanu.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Numer telefonu Signal, którego używa ten bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Przychodzący webhook usługi Teams, do którego ten agent powinien wysyłać wiadomości.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Wyzwanie dwuskładnikowe wygasło. Zaloguj się ponownie.';

  @override
  String get theTwoFactorCodeIsNot => 'Kod dwuczynnikowy jest nieprawidłowy.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Nie można oznaczyć zweryfikowanego pakietu wykonawczego jako wykonywalnego.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'W zweryfikowanym pakiecie wykonawczym brakuje wymaganych plików.';

  @override
  String get theWebAppCouldNotReach =>
      'Aplikacja internetowa nie mogła połączyć się z backendem NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Aplikacja internetowa nie mogła połączyć się z backendem NeoAgent pod adresem $arg1. Sprawdź konsolę przeglądarki i konfigurację odwrotnego proxy/sieci.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'sobie; operator serwera najpierw usuwa administratora ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Te kanały milczą. Aby ponownie otrzymywać od nich wiadomości, dodaj ich w sekcji Kto może wysyłać wiadomości na tej platformie.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Listy te są opcjonalne, chyba że w powyższej sekcji ustawiono opcję Tylko zatwierdzone.';

  @override
  String get thesePeopleAnywhere => 'Ci ludzie, gdziekolwiek';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Te osoby mogą wysyłać wiadomości do $arg1 na prywatnych czatach i w dowolnej grupie, którą udostępniają.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Te osoby mogą wysyłać wiadomości do $arg1 jeden do jednego. To nie pozwala im rozmawiać w grupach.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Te osoby mogą wysyłać wiadomości do $arg1 wyłącznie w wybranej przez Ciebie grupie.';
  }

  @override
  String get thesePeopleInOneGroup => 'Ci ludzie w jednej grupie';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'te przełączniki, a nie czaty, wspomnienia i pliki.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'To konto odblokuje NeoAgent na tym komputerze.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Agent ten może delegować uprawnienia dowolnemu uprawnionemu agentowi odbierającemu.';

  @override
  String get thisAgentIsUsingAServer =>
      'Ten agent używa klucza API Trello zarządzanego przez serwer. Wystarczy autoryzować token konta poniżej.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Ta kompilacja nie może komunikować się z tym wdrożeniem NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Ten kod należy do innego serwera NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Ten pulpit jest podłączony';

  @override
  String get thisDevice => 'To urządzenie';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'To urządzenie: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'To urządzenie nie może zarejestrować kluczy bezpieczeństwa. Otwórz NeoAgent w przeglądarce przez HTTPS, aby go dodać.';

  @override
  String get thisDeviceUnavailable => 'To urządzenie — niedostępne';

  @override
  String get thisFileHasNoContent => 'Ten plik nie zawiera treści.';

  @override
  String get thisGoogleAccountIsNotLinked =>
      'To konto Google nie jest jeszcze połączone. Najpierw użyj rejestracji dostawcy lub zaloguj się normalnie i połącz go z ustawieniami konta.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Ukrywa to „$arg1” przed routingiem i wyborem.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Ta integracja obsługuje obecnie jedno połączone konto na agenta. Otwórz ponownie konfigurację, aby ją zastąpić.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Ta integracja nie jest już dostępna.';

  @override
  String get thisIntroIsDesignedForFull =>
      'To wprowadzenie jest przeznaczone do odtwarzania w orientacji poziomej na pełnym ekranie.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'To jest wdrożenie zarządzane. Wychodzi jego operator ';

  @override
  String get thisMayTakeAMoment => 'Może to chwilę potrwać.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Ten serwer MCP nie jest już skonfigurowany.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Ta pamięć zostanie trwale usunięta.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Ta kompilacja NeoAgent nie jest skonfigurowana do weryfikowania środowisk wykonawczych zaplecza.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Spowoduje to trwałe usunięcie wszystkich Twoich danych i nie będzie to możliwe ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Spowoduje to trwałe usunięcie konta i wszystkiego, co posiada: ';

  @override
  String get thisPersonAnywhere => 'Ta osoba, gdziekolwiek';

  @override
  String get thisPersonInOneGroup => 'Ta osoba w jednej grupie';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'To żądanie logowania QR wygasło. Wygeneruj nowy kod i spróbuj ponownie.';

  @override
  String get thisQrLoginRequestHasExpired => 'to żądanie logowania qr wygasło';

  @override
  String get thisQrLoginRequestIsStill =>
      'To żądanie logowania QR wciąż oczekuje na zatwierdzenie.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'To żądanie logowania QR zostało już wykorzystane.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Spowoduje to usunięcie konfiguracji Home Assistant i podłączonej instancji dla tego agenta.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Spowoduje to usunięcie adresu URL zaplecza NeoRecall i wszystkich połączonych kont NeoRecall dla tego agenta.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Spowoduje to usunięcie adresu URL Nextcloud i wszystkich połączonych kont Nextcloud dla tego agenta.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Spowoduje to usunięcie konfiguracji Trello i połączonych kont dla tego agenta.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Wymaga to uwierzytelnionej sesji na tym samym serwerze NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'To uruchomienie nie spowodowało reakcji skierowanej do użytkownika.';

  @override
  String get thisRunHasNoRecordedStep =>
      'W tym przebiegu nie zapisano danych kroków.';

  @override
  String get thisServer => 'ten serwer.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Ten serwer nie zgłasza żadnych ustawień dostawcy.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Ta umiejętność nie jest już zainstalowana.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'To zadanie nie zostało jeszcze ukończone, więc nadal zaczyna się od ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'To zadanie zostanie uruchomione tylko po naciśnięciu przycisku Uruchom teraz.';

  @override
  String get thisWeek => 'W tym tygodniu';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Spowoduje to zaimportowanie odpowiedzi do $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Spowoduje to usunięcie „$arg1”.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Spowoduje to usunięcie „$arg1” z listy serwerów.';
  }

  @override
  String get time => 'Czas';

  @override
  String get timeZone => 'strefa czasowa';

  @override
  String get timeZone2 => 'Strefa czasowa';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Upłynął limit czasu$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Nie można wyświetlić stref czasowych: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nie można odczytać strefy czasowej urządzenia: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nie można zapisać strefy czasowej urządzenia: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'do $arg1';
  }

  @override
  String get toUseTheServerDefault => 'aby użyć ustawień domyślnych serwera.';

  @override
  String get today => 'Dzisiaj';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Budżet tokena dla @$arg1. Pozostaw pole puste ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Budżet tokena dla każdego konta bez własnego zastąpienia. Zostaw ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'limit budżetu tokena 4-godzinny tygodniowy limit użytkownika';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'limit budżetu tokena 4-godzinny tygodniowy limit globalny';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Użycie tokena jest niedostępne na tej wersji serwera.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokeny, które dowolne konto może wykorzystać w ciągu 4 godzin.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokeny, które dowolne konto może wykorzystać w ciągu 7 dni.';

  @override
  String get tokensPerDay => 'Tokeny dziennie';

  @override
  String get tokensPerRun => 'Tokeny na przebieg';

  @override
  String get tokensToday => 'Tokeny dzisiaj';

  @override
  String get tokensUsed => ' użyte tokeny';

  @override
  String get tomorrowPrep => 'Jutro przygotowanie';

  @override
  String get tooManyAttempts => 'zbyt wiele prób';

  @override
  String get tooManySignInAttemptsPlease =>
      'Zbyt wiele prób logowania. Poczekaj i spróbuj ponownie.';

  @override
  String get tool => 'Narzędzie';

  @override
  String get toolApproval => 'Zatwierdzenie narzędzia';

  @override
  String get toolApprovalRequired => 'Wymagana akceptacja narzędzia';

  @override
  String get toolCompleted => 'Narzędzie ukończone';

  @override
  String get toolFailed => 'Narzędzie nie powiodło się';

  @override
  String get toolPermissions => 'Uprawnienia narzędzi';

  @override
  String get toolStarted => 'Narzędzie uruchomione';

  @override
  String get tools => 'Narzędzia';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Narzędzia, które nie są wbudowane w NeoAgent, w tym podłączone serwery MCP i niestandardowi dostawcy narzędzi.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Oferowane narzędzia ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Narzędzia, z których może korzystać zarządzane konto';

  @override
  String get topUsers => 'Najlepsi użytkownicy';

  @override
  String get topUsersAndRecentRuns =>
      'Najlepsi użytkownicy i ostatnie uruchomienia';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Łącznie: tokeny $arg1 w przebiegach $arg2';
  }

  @override
  String get totalRuns => 'Razem biegi';

  @override
  String get totalTokens => 'Suma tokenów';

  @override
  String get totalUsers => 'Całkowita liczba użytkowników';

  @override
  String get transcript => 'Transkrypcja';

  @override
  String get transcript2 => 'TRANSKRYPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkrypcja nie powiodła się: $arg1';
  }

  @override
  String get transfer => 'Przeniesienie';

  @override
  String get trelloApiKey => 'Klucz API Trello';

  @override
  String get trelloApiKeyIsRequired => 'Wymagany jest klucz Trello API.';

  @override
  String get trelloSetup => 'Konfiguracja Trello';

  @override
  String get triggerType => 'Typ wyzwalacza';

  @override
  String get tryABroaderSearchLikeModels =>
      'Spróbuj szerszego wyszukiwania, np. modeli, przeglądarki lub głosu.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Wypróbuj nazwę dostawcy, „e-mail”, „limity”, „aktualizacja” lub „dzienniki”.';

  @override
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Spróbuj ponownie. Jeżeli problem będzie się powtarzał, uruchom NeoAgent Doctor, aby sprawdzić czas działania komputera.';

  @override
  String get tryAgainInAMoment => 'Spróbuj ponownie za chwilę.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Spróbuj ponownie lub uruchom NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Spróbuj innego wyszukiwania, połącz się z platformą do przesyłania wiadomości lub ręcznie wprowadź identyfikator miejsca docelowego.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Włącz grupę, jeśli $arg1 ma także czytać wiadomości, które jej nie tagują.';
  }

  @override
  String get turnOffComputer => 'Wyłącz komputer';

  @override
  String get turnOffOnlyForAMail =>
      'Wyłącz tylko dla serwera pocztowego z certyfikatem z podpisem własnym.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Włącz, jeśli Signal ma nadal wyszukiwać przychodzące czaty.';

  @override
  String get turnTaking => 'zawracanie';

  @override
  String get turnTakingModel => 'Model rotacyjny';

  @override
  String get turnTakingOff => 'Zakręt i start';

  @override
  String get turnThisOffToKeepThis =>
      'Wyłącz tę opcję, aby ten agent był całkowicie oddzielony od innych agentów.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Wyłączone przez $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Wyłączone przez $arg1, który zarządza tym kontem. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Wyłączone dla Ciebie przez $arg1 — tylko oni mogą to zmienić';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Wyłączono dla Ciebie, więc nie możesz go rozdać';

  @override
  String get twitchChatOverIrc => 'Czat na Twitchu przez IRC';

  @override
  String get twoFactorAuthentication => 'Uwierzytelnianie dwuskładnikowe';

  @override
  String get twoFactorChallengeExpired => 'wyzwanie dwuczynnikowe wygasło';

  @override
  String get twoFactorCode => 'kod dwuczynnikowy';

  @override
  String get twoFactorSignInCompletedBut =>
      'Logowanie dwuskładnikowe zostało zakończone, ale NeoAgent nie mógł utrzymać sesji przeglądarki. Zaloguj się ponownie.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Logowanie dwuetapowe (tylko jeśli włączone)';

  @override
  String get type => 'Wpisz';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Wpisz $arg1, aby potwierdzić';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'wpisywanie tekstu nie jest obsługiwane na tej platformie.';

  @override
  String get typedInTheBrowser => 'Wpisano w przeglądarce';

  @override
  String get typedText => 'Wpisany tekst';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'nie można znaleźć środowiska wykonawczego Java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Nie można otworzyć ustawień czasu w tej kompilacji.';

  @override
  String get unableToOpenWiFiSettings =>
      'Nie można otworzyć ustawień Wi-Fi w tej kompilacji.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nie można zachować wybranego ekranu pulpitu.';

  @override
  String get unclearWhoItWasFor => 'Nie wiadomo dla kogo to było';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'cofnięte. Wpisz swoją nazwę użytkownika, aby potwierdzić.';

  @override
  String get unknownAccount => 'Nieznane konto';

  @override
  String get unknownAgent => 'Nieznany agent';

  @override
  String get unknownBrowser => 'Nieznana przeglądarka';

  @override
  String get unknownDevice => 'Nieznane urządzenie';

  @override
  String get unknownError => 'nieznany błąd';

  @override
  String get unknownLocalComputerPermission =>
      'Nieznane uprawnienia komputera lokalnego.';

  @override
  String get unknownLocation => 'Nieznana lokalizacja';

  @override
  String get unknownPublishTime => 'Nieznany czas publikacji';

  @override
  String get unknownSize => 'Nieznany rozmiar';

  @override
  String get unlink => 'Odłącz';

  @override
  String get unreadOnly => 'Tylko nieprzeczytane';

  @override
  String get unsavedChanges => 'Niezapisane zmiany';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nieobsługiwane polecenie towarzyszące na pulpicie: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nieobsługiwana metoda: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Nietypowe alerty dotyczące logowania';

  @override
  String updateArg1(Object? arg1) {
    return 'Zaktualizuj $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Zaktualizuj wpisy pamięci rdzeniowej z importu.';

  @override
  String get updateNow => 'Zaktualizuj teraz';

  @override
  String get updateReady => 'Aktualizacja gotowa';

  @override
  String get updateSetup => 'Aktualizuj konfigurację';

  @override
  String get updateTheAccessListToAllow =>
      'Zaktualizuj listę dostępu, aby umożliwić odpowiedzi.';

  @override
  String get updateTheServer => 'Zaktualizować serwer?';

  @override
  String get updateTheServer2 => 'Zaktualizuj serwer';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Aktualizuj strefę czasową automatycznie na urządzeniu, z którego korzystasz.';

  @override
  String updatedArg1(Object? arg1) {
    return 'zaktualizowano $arg1';
  }

  @override
  String get updates => 'Aktualizacje';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Aktualizacje nie są skonfigurowane dla tej kompilacji.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'aktualizacje, więc samodzielne aktualizacje i zmiany kanałów są tutaj wyłączone.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'aktualizacja zaktualizuj teraz wypuść stabilną wersję beta kanału';

  @override
  String get usageAnalytics => 'Analityka użytkowania';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Sygnały użycia i kondycji, które pomagają wyjaśnić bieżące zachowanie środowiska wykonawczego bez konieczności wcześniejszego przeglądania dzienników.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Użycie zostaje całkowicie zresetowane w $arg1';
  }

  @override
  String get usageLeaderboard => 'tabela wyników użytkowania';

  @override
  String get usageLimits => 'Wykorzystanie i ograniczenia';

  @override
  String get usageLimits2 => 'Wykorzystanie i ograniczenia';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Użyj ponad 8 znaków. Dłuższe hasła działają dobrze.';

  @override
  String get useADateAndTimeFor =>
      'Użyj daty i godziny, na przykład 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Użyj imienia i nazwiska, numeru telefonu lub identyfikatora czatu.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Użyj adresu URL NeoRecall, do którego może dotrzeć serwer NeoAgent. Aby możliwe było wywołanie zwrotne OAuth, adres PUBLIC_URL NeoAgenta musi być również osiągalny z tej przeglądarki.';

  @override
  String get useANewPasswordWithAt =>
      'Użyj nowego hasła składającego się z co najmniej 8 znaków.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Użyj adresu URL Nextcloud, do którego może dotrzeć serwer NeoAgent, na przykład https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Użyj hasła składającego się z co najmniej 8 znaków.';

  @override
  String get useASecureConnectionTls => 'Użyj bezpiecznego połączenia (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Użyj aplikacji uwierzytelniającej, takiej jak Authy, 1Password lub Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Użyj co najmniej 1 procesora wirtualnego.';

  @override
  String get maxMemoryPerComputerMb => 'Maksymalna pamięć na komputer (MB)';

  @override
  String get maxVcpusPerComputer =>
      'Maksymalna liczba procesorów wirtualnych na komputer';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Przynajmniej $arg1. Komputery otrzymują mniej, gdy host jest zajęty.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Maksymalna ilość pamięci musi wynosić co najmniej $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Użyj co najmniej 8 znaków.';

  @override
  String get useDefault => 'Użyj domyślnego';

  @override
  String get useDefaultChannel => 'Użyj kanału domyślnego';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Użyj wartości domyślnej (przestrzeń robocza NeoAgent)';

  @override
  String get useFor => 'Użyj dla';

  @override
  String get useManualDestination => 'Użyj ręcznego miejsca docelowego';

  @override
  String get useOrDoTheSameFor =>
      'użyj lub zrób to samo dla swoich kolegów z drużyny.';

  @override
  String get usePerCategorySettingsBelow =>
      'Użyj poniższych ustawień dla poszczególnych kategorii.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Użyj ustawień domyślnych ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Użyj serwera na tym komputerze';

  @override
  String get useTheseForContextIfA =>
      'Użyj ich dla kontekstu. Jeśli lokalny identyfikator URI nie jest bezpośrednio dostępny z serwera, poproś mnie o udostępnienie pliku za pośrednictwem dostępnego obszaru roboczego.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Użyj tego dla agentów programu Orchestrator. Zostaw to dla odizolowanych botów roboczych, które powinny same kończyć wiadomości bezpośrednie.';

  @override
  String get useTlsFromTheStartOf =>
      'Używaj protokołu TLS od początku połączenia, zwykle na porcie 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Użyj własnego klucza API dla dostawcy lub podłącz niestandardowy ';

  @override
  String get usedByEveryAccountOnThis =>
      'Używane przez każde konto na tym serwerze, które nie ma klucza ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Służy do sprawdzania, czy przychodzące zdarzenia Slack są autentyczne.';

  @override
  String get userSummary => 'Podsumowanie użytkownika';

  @override
  String get username => 'Nazwa użytkownika';

  @override
  String get usernameOrEmail => 'Nazwa użytkownika lub adres e-mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'użytkownicy ludzie szukają adresu e-mail nazwa użytkownika administrator odznaka zarządzany zespół';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Używa modelu czatu skonfigurowanego w Ustawieniach';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Korzystanie z zainstalowanego środowiska wykonawczego NeoAgent';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Zwykle wygląda jak @bot:matrix.org';

  @override
  String get validEmail => 'ważny adres e-mail';

  @override
  String get value => 'Wartość';

  @override
  String get vaultLocked => 'Skarbiec zamknięty';

  @override
  String get vaultOperationFailed => 'Operacja skarbca nie powiodła się.';

  @override
  String vectorRankArg1(Object? arg1) {
    return 'Ranga wektora: $arg1';
  }

  @override
  String get verification => 'Weryfikacja';

  @override
  String verificationArg1(Object? arg1) {
    return 'Weryfikacja: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'weryfikacja: $arg1';
  }

  @override
  String get verificationCompleted => 'Weryfikacja zakończona.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Status weryfikacji: $arg1';
  }

  @override
  String get verifiedTheResult => 'Zweryfikowano wynik';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Weryfikacja pobranego środowiska wykonawczego';

  @override
  String get versionAndUptime => 'Wersja i czas pracy';

  @override
  String versionArg1(Object? arg1) {
    return 'Wersja $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Wersja $arg1 jest zainstalowana, ale $arg2 nadal działa.';
  }

  @override
  String get videoLinks => 'Linki wideo';

  @override
  String get viewDesktop => 'Wyświetl pulpit';

  @override
  String get viewLastRun => 'Zobacz ostatni bieg';

  @override
  String get viewLogs => 'Wyświetl logi';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'Środowisko wykonawcze procesora qemu pamięci obrazu vm';

  @override
  String get voice => 'Głos';

  @override
  String get voiceAssistant => 'Asystent głosowy';

  @override
  String get voiceCall => 'POŁĄCZENIE GŁOSOWE';

  @override
  String get voiceCall2 => 'Połączenie głosowe';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'połączenie głosowe gpt-live Gemini model mowy na żywo w czasie rzeczywistym';

  @override
  String get voiceCallsRunOnALive =>
      'Połączenia głosowe działają w oparciu o model mowy na mowę na żywo z tą samą osobą, pamięcią i historią czatów co NeoAgent. Odpowiada natychmiast i oddaje prawdziwą pracę normalnemu agentowi, który działa w tle.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'Klucz API transkrypcji mowy głosowej';

  @override
  String get voiceNotesAndDictation => 'Notatki głosowe i dyktando';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Odtwarzanie głosu jest niedostępne na tym urządzeniu.';

  @override
  String get voiceReplyModel => 'Model odpowiedzi głosowej';

  @override
  String get waitingForApproval => 'Oczekiwanie na zatwierdzenie: ';

  @override
  String get waitingForCode => 'Czekam na kod';

  @override
  String get waitingForInput => 'Oczekiwanie na wprowadzenie';

  @override
  String get waitingForServerOrFlutterLog =>
      'Oczekiwanie na wyjście dziennika serwera lub Fluttera…';

  @override
  String get waitingForTaskEvents =>
      'Oczekiwanie na zdarzenia związane z zadaniem...';

  @override
  String get waitingForYou => 'czekam na ciebie';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Chciałem odpowiedzi od $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Chce z tobą porozmawiać · ${arg1}s';
  }

  @override
  String get weak => 'Słaby';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Pogoda, kalendarz i priorytety przed rozpoczęciem dnia.';

  @override
  String get weatherEvent => 'Wydarzenie pogodowe';

  @override
  String get web => 'Sieć';

  @override
  String get webBrowser => 'Przeglądarka internetowa';

  @override
  String get webSearchApiKey => 'klucz API wyszukiwania w Internecie';

  @override
  String get webhookOrRestChannelPosting =>
      'Publikowanie webhooka lub kanału REST';

  @override
  String get webhookSecret => 'Sekret webhooka';

  @override
  String get webhookUrlCopied => 'Skopiowano adres URL webhooka';

  @override
  String get weekdays => 'Dni powszednie';

  @override
  String get weekdays0730 => 'Dni powszednie · 07:30';

  @override
  String get weekdays1800 => 'Dni powszednie · 18:00';

  @override
  String get weekly => 'Co tydzień';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Limit tygodniowy $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Limit tygodniowy (tokeny)';

  @override
  String get weeklyReview => 'Przegląd tygodniowy';

  @override
  String get weeklyUsage => 'Tygodniowe użycie';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Waga rekordów $arg1';
  }

  @override
  String get welcomeToNeoagent => 'WITAJ W NEOAGENCIE';

  @override
  String get welcomeToNeoagent2 => 'Witamy w\nNeoAgencie';

  @override
  String get whatAreYouAdding => 'Co dodajesz?';

  @override
  String get whatIsOnTomorrow => 'Co będzie jutro?';

  @override
  String get whatShouldNeoagentLearn => 'Czego powinien się nauczyć NeoAgent?';

  @override
  String get whatShouldWeBuild => 'Co powinniśmy zbudować?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'To, co powiesz Ty i NeoAgent, pojawi się tutaj i na czacie.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Otrzymano wiadomość osobistą WhatsApp';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Jeśli wybierzesz opcję Tylko zatwierdzone, dodaj poniżej osoby lub grupy.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Gdzie ten agent powinien wysyłać odpowiedzi.';

  @override
  String get whoCanMessage => 'Kto może wysyłać wiadomości';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kto może wysyłać wiadomości na $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kto może wysłać $arg1 wiadomość indywidualną.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kto może rozmawiać z $arg1 w grupie, kanale lub pokoju.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kto zarządza tym kontem wyłączony: ';

  @override
  String get whoManagesWhom => 'Kto kim zarządza';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Osoba, która zaakceptuje link, dołącza do Twojego zespołu, mając jedynie narzędzia, które zawiera ';

  @override
  String get wholeGroup => 'Cała grupa';

  @override
  String get wholeGroups => 'Całe grupy';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Dlaczego $arg1 odpowiedział lub milczał w grupach $arg2.';
  }

  @override
  String get windowsApp => 'Aplikacja dla systemu Windows';

  @override
  String get windowsNt => 'Windows Nt';

  @override
  String get workAccount => 'Konto służbowe';

  @override
  String get workOnAProjectWithNeoagent => 'Pracuj nad projektem z NeoAgentem';

  @override
  String workflowArg1(Object? arg1) {
    return 'Przebieg pracy: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Praca w $arg1 na komputerze w chmurze. NeoAgent odczytuje i edytuje tam pliki oraz może uruchamiać polecenia i przeglądarkę.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Praca w tle: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Konfiguracja Workspace i bezpieczeństwo konta w jednym miejscu.';

  @override
  String get workspaceFiles => 'Pliki obszaru roboczego';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Obszar roboczy, modele i kontrolki diagnostyczne.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Zastąpienie obszaru roboczego musi być ścieżką bezwzględną.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Napisano $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'Błąd żądania xmlhttp';

  @override
  String get yesterday => 'Wczoraj';

  @override
  String get youAreInControl => 'Masz kontrolę';

  @override
  String get youCanFollowAlongOnThe => 'Możesz śledzić dalej na pulpicie.';

  @override
  String get youCanLeaveATeamAt =>
      'Możesz opuścić zespół w dowolnym momencie; Twoje własne ustawienia zostaną ponownie zastosowane.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Możesz opuścić drużynę w dowolnym momencie na stronie Zespół.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Ty decydujesz, z jakich narzędzi może korzystać Twój agent, w Ustawieniach › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Jeszcze nikim nie zarządzasz. Utwórz link z zaproszeniem poniżej i ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Masz niezapisane ustawienia. Co chciałbyś zrobić?';

  @override
  String get youReOnYourOwnYou =>
      'Działasz sam: Ty decydujesz, z jakich narzędzi może korzystać Twój agent. Jeśli ';

  @override
  String get yourAccountAndUsageOnA =>
      'Twoje konto — i korzystanie z modelu opartego na Twoim własnym kluczu ';

  @override
  String get yourAccountHasBeenDeleted => 'Twoje konto zostało usunięte.';

  @override
  String get yourAgentWillBeAllowed => 'Twój agent będzie mógł:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Twoje aplikacje i pliki zostaną zapisane.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Twoje aplikacje i pliki pozostaną zapisane.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Twój klucz $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Twoja warstwa asystenta do przechwytywania, kontekstu i akcji.';

  @override
  String get yourComputerIsAsleep => 'Twój komputer śpi';

  @override
  String get yourComputerIsOff => 'Twój komputer jest wyłączony';

  @override
  String get yourComputerIsReady => 'Twój komputer jest gotowy';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Twoje obecne hasło jest nieprawidłowe.';

  @override
  String get yourData => 'Twoje dane';

  @override
  String get yourDataExportWasCopiedTo =>
      'Eksport danych został skopiowany do schowka.';

  @override
  String get yourDesktopIsReady => 'Twój pulpit jest gotowy';

  @override
  String get yourLinuxComputer => 'Twój komputer z Linuksem';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Twoja lokalizacja nigdy nie jest śledzona w sposób ciągły ani przechowywana na naszych serwerach. Używamy go tylko lokalnie, aby sprawdzić Twoje aktywne zadania.';

  @override
  String get yourManager => 'twój menadżer';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Adres URL Twojej witryny Mattermost, jeśli korzystasz z interfejsu API REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Twoja sesja wygasła lub nie została zachowana przez przeglądarkę. Zaloguj się ponownie.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Twoja sesja wygasła. Zaloguj się ponownie.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Twoja nazwa użytkownika lub hasło są nieprawidłowe.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Przegląd';

  @override
  String get sectionDiagnostics => 'Diagnostyka';

  @override
  String get sectionVolume => 'Objętość';

  @override
  String get sectionSession => 'Sesja';

  @override
  String get sectionDeliverable => 'Możliwość dostarczenia';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Lokalne środowisko wykonawcze nie zapisał jeszcze pliku dziennika.';

  @override
  String get thisComputer => 'Ten komputer';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta instaluje najnowszy backend w wersji wstępnej. Spodziewaj się ostrych krawędzi.';

  @override
  String get copiedFinalResponse => 'Skopiowano ostateczną odpowiedź';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Ostateczna odpowiedź pojawia się tutaj po zakończeniu przebiegu.';

  @override
  String get waitingForTheFirstStep => 'W oczekiwaniu na pierwszy krok…';

  @override
  String get loadingPrompt => 'Komunikat o ładowaniu…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'W tym przebiegu nie zarejestrowano żadnej ostatecznej odpowiedzi.';

  @override
  String get readyToSignIn => 'Gotowy do zalogowania się';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Przełącz na opcję „Domyślne” lub „Zawsze pytaj”, aby ponownie włączyć sprawdzanie akceptacji.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Wyślij aktualizację sterowania lub następną notatkę dotyczącą bieżącego przebiegu...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Brak połączenia sieciowego. NeoAgent połączy się ponownie, gdy urządzenie będzie ponownie online.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Zastosowano najnowszą aktualizację układu kierowniczego do bieżącego przebiegu.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Przygotowuję prywatną sesję głosową…';

  @override
  String get preparingYourComputer => 'Przygotowanie komputera';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent pobiera i przygotowuje bezpieczny system Linux. Dzieje się tak tylko za pierwszym razem.';

  @override
  String get moreFreeSpaceIsNeeded => 'Potrzeba więcej wolnego miejsca';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Zwolnij trochę miejsca na dysku hosta NeoAgent, a następnie spróbuj ponownie. Twoje istniejące dane na komputerze są bezpieczne.';

  @override
  String get androidReady => 'Gotowy na Androida';

  @override
  String get startingAndroid2 => 'Uruchamiam Androida…';

  @override
  String get androidStopped => 'Android zatrzymał się';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Pierwsze uruchomienie powoduje pobranie zestawu SDK systemu Android i obrazu systemu, co może zająć kilka minut.';

  @override
  String get androidIsStopped => 'Android jest zatrzymany';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Uruchom zarządzane środowisko Android, kiedy go potrzebujesz.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Pozwól NeoAgentowi pracować na tym komputerze';

  @override
  String get firstTimeSetupIsInProgress => 'Trwa pierwsza konfiguracja.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent może korzystać z dostępu, na który pozwolisz.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Zwolnij część pamięci hosta i spróbuj ponownie.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Zacznij, gdy chcesz, aby NeoAgent tu pomógł.';

  @override
  String get systemPermissionMissing => 'Brak uprawnień systemowych';

  @override
  String get connectingThisDevice => 'Podłączanie tego urządzenia';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Nawiązywane jest bezpieczne połączenie lokalne.';

  @override
  String get recordingYourDemonstration => 'Nagrywanie demonstracji';

  @override
  String get noErrorsInTheRecentLog => 'W ostatnim logu brak błędów.';

  @override
  String get loadingAccounts => 'Ładuję konta…';

  @override
  String get neverSignedIn => 'Nigdy się nie logowałem';

  @override
  String get emptyUsesTheServerDefault =>
      'Pusty używa ustawień domyślnych serwera.';

  @override
  String get followTheSelectedSession => 'Śledź wybraną sesję';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Tylko tryb planowania sprawdza. Przejdź do trybu agenta, aby NeoAgent mógł edytować pliki.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Wymagane, aby dodać lub zmienić adres e-mail konta.';

  @override
  String get confirmNewPassword => 'Potwierdź nowe hasło';

  @override
  String get passwordChanged => 'Hasło zmienione.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'To żądanie zostało już wykorzystane.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'To żądanie wygasło. Poproś drugie urządzenie o wygenerowanie nowego kodu.';

  @override
  String get startQuickstart => 'Uruchom Szybki start';

  @override
  String get createYourAccount => 'Utwórz swoje konto';

  @override
  String get showWorkAsSummaries => 'Pokaż pracę jako podsumowanie';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokeny używane w ostatnim uruchomieniu';

  @override
  String get listedTheWorkspaceRoot =>
      'Wyświetlono katalog główny obszaru roboczego';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Nie są jeszcze dostępne żadne oficjalne integracje.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Nie skonfigurowano jeszcze żadnych serwerów MCP. Dodaj jeden, aby odsłonić jego narzędzia.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Aby rozpocząć, dodaj serwer MCP lub zainstaluj umiejętność.';

  @override
  String get setUp => 'Skonfiguruj';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Pozostaw puste, aby zachować zapisaną wartość';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Spowoduje to usunięcie adresu każdego konta na tym serwerze.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Po prostu porozmawiaj. Możesz przerwać w dowolnym momencie. Kliknij, aby wyciszyć.';

  @override
  String get tapAgainWhenYouAreDone => 'Gdy skończysz, dotknij ponownie.';

  @override
  String get workingOnATaskInTheBackground => 'Pracuję nad zadaniem w tle.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Mowa na mowę z tą samą pamięcią, narzędziami i historią czatów co NeoAgent.';

  @override
  String get checkLink => 'Sprawdź łącze';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Twój agent nie będzie miał dostępu do żadnego z kontrolowanych narzędzi.';

  @override
  String get notYoursToChange => 'Nie twoje do zmiany';

  @override
  String get setByYou => 'Ustaw przez Ciebie';

  @override
  String get noTools => 'Żadnych narzędzi';

  @override
  String get untitledLink => 'Link bez tytułu';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Przestaje działać po wykupieniu go przez jedną osobę.';

  @override
  String get theOperator => 'Operator';

  @override
  String get smartSelectorOn => 'Inteligentny selektor włączony';

  @override
  String get startASessionToBegin => 'Rozpocznij sesję, aby rozpocząć';

  @override
  String get steerTheActiveRun => 'Steruj aktywnym biegiem…';

  @override
  String get describeWhatToPlan => 'Opisz, co zaplanować…';

  @override
  String get stopDictation => 'Przestań dyktować';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Wiadomości sterują bieżącym przebiegiem · ⌘↵ wyślij · ⌘. przestań';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Tylko inspekcje w trybie planu; nic się nie zmienia, dopóki nie zaimplementujesz · ⌘↵ wyślij';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agent edytuje obszar roboczy. Planuj tylko inspekcje.';

  @override
  String get defaultModel => 'Domyślny model';

  @override
  String get openingScanner => 'Otwieram skaner...';

  @override
  String get theAgentCanUseThisSkill =>
      'Agent może skorzystać z tej umiejętności.';

  @override
  String get allSelected => 'Wszystkie wybrane';

  @override
  String get addCoreMemoryEntry => 'Dodaj wpis pamięci rdzeniowej';

  @override
  String get channelId => 'Identyfikator kanału';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Zadania utworzone przez sztuczną inteligencję i nieokreślone korzystają z bieżących ustawień domyślnych.';

  @override
  String get waitingForRunEvents => 'Czekam na wydarzenia biegowe...';

  @override
  String get hideSteps => 'Ukryj kroki';

  @override
  String get commitTheActiveLiveCapture =>
      'Zatwierdź aktywne przechwytywanie na żywo';

  @override
  String get stopCaptureAndSubmit => 'Zatrzymaj przechwytywanie i prześlij';

  @override
  String get clickTheMicToStartSpeaking => 'Kliknij mikrofon, aby zacząć mówić';

  @override
  String get connectACustomEndpoint => 'Połącz niestandardowy punkt końcowy';

  @override
  String get hostedProvider => 'dostawca hostingu.';

  @override
  String get muted => ' • wyciszony';

  @override
  String get addWhoCanMessage => 'Dodaj wiadomość, kto może';

  @override
  String get joinsGroupConversations => 'Dołącza do rozmów grupowych';

  @override
  String get label1PersonOrGroupAdded => 'Dodano 1 osobę lub grupę';

  @override
  String get inProgress => 'W toku';

  @override
  String get waitingForUpdateJobOutput =>
      'Oczekiwanie na wyniki zadania aktualizacji…';

  @override
  String get taskTrigger => 'Wyzwalacz zadania';

  @override
  String get bearerToken => 'Token okaziciela';

  @override
  String get bearerToken2 => 'Token okaziciela';

  @override
  String get notRecorded => 'Nie nagrano';

  @override
  String get sessionCookie => 'Plik cookie sesji';

  @override
  String get neverUsed => 'Nigdy nie używany';

  @override
  String get linkedRecently => 'Połączono niedawno';

  @override
  String get notUsedYet => 'Jeszcze nie używany';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Jedno lub więcej kont wygasło. Połącz się ponownie, aby przywrócić dostęp. Jeśli tak się nie stanie, Twoja aplikacja Google Cloud OAuth może znajdować się w trybie testowym — opublikuj ją w wersji produkcyjnej w Google Cloud Console, aby uzyskać długotrwałe tokeny.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Magazyn podłączony i dostępny po ponownym uruchomieniu';

  @override
  String get vaultConnectedForThisSession =>
      'Vault podłączony na potrzeby tej sesji';

  @override
  String get connectAnotherAccount => 'Połącz kolejne konto';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Wklej zastępczy długotrwały token dostępu';

  @override
  String get updateInstance => 'Zaktualizuj instancję';

  @override
  String get pasteAReplacementToken => 'Wklej token zastępczy';

  @override
  String get replaceAccount => 'Zamień konto';

  @override
  String get addAccount => 'Dodaj konto';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Może delegować dowolnemu agentowi odbierającemu';

  @override
  String get canReceiveDelegatedTasks2 => 'może otrzymywać delegowane zadania';

  @override
  String get noSyncYet => 'Jeszcze nie ma synchronizacji';

  @override
  String get noNewData => 'Brak nowych danych';

  @override
  String get syncOnceToSeedYourBackend =>
      'Zsynchronizuj raz, aby zapełnić swój backend.';

  @override
  String get lastWindowEndIsUnknown => 'Koniec ostatniego okna nie jest znany.';

  @override
  String get lastNonEmptySync => 'Ostatnia niepusta synchronizacja';

  @override
  String get stopTranscribe => 'Zatrzymaj się i dokonaj transkrypcji';

  @override
  String get steeringMode => 'Tryb kierowania';

  @override
  String get noMessageText => 'Brak tekstu wiadomości';

  @override
  String get reconnectingToServer => 'Ponowne łączenie z serwerem…';

  @override
  String get signingIn => 'Logowanie...';

  @override
  String get noGroupsFoundYet => 'Nie znaleziono jeszcze żadnych grup';

  @override
  String get onForNewGroupsOnly => 'Włączone tylko dla nowych grup';

  @override
  String get noGroupsInThisCategory => 'Brak grup w tej kategorii';

  @override
  String get groupOrChannel => 'Grupa lub kanał';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Notatki, które do siebie piszesz, rozpoczynają bieg, a odpowiedzi trafiają na ten sam czat. Lista dozwolonych nie ma tutaj zastosowania.';

  @override
  String get needToReply => 'Muszę odpowiedzieć';

  @override
  String get enter2faCode => 'Wprowadź kod 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Otwórz aplikację uwierzytelniającą i wprowadź aktualny kod NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Masz już konto? Zaloguj się';

  @override
  String get serverOnThisComputer => 'Serwer na tym komputerze';

  @override
  String get showQrCode => 'Pokaż kod QR';

  @override
  String get createAnotherNeoagentAccount => 'Utwórz kolejne konto NeoAgent.';

  @override
  String get canCoordinateDelegatedWork =>
      'Potrafi koordynować delegowaną pracę';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Nie można wyodrębnić archiwum wykonawczego NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Nie można odczytać archiwum środowiska wykonawczego NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Archiwum wykonawcze NeoAgent zawiera niebezpieczną ścieżkę.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Archiwum wykonawcze NeoAgent zawiera niebezpieczne łącze.';

  @override
  String get installingAppPackageOnThePhone =>
      'Instalowanie pakietu aplikacji na telefonie...';

  @override
  String get dragAndDropAApkOrApks =>
      'Przeciągnij i upuść tutaj plik .apk lub .apks albo kliknij, aby przeglądać.';

  @override
  String get releaseToInstallThisPackage =>
      'Zwolnij, aby zainstalować ten pakiet';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Nie można użyć klucza bezpieczeństwa.';

  @override
  String get connecting => 'Łączę…';

  @override
  String get changes => 'Zmiany';

  @override
  String get runtimeReady => 'Gotowe środowisko wykonawcze';

  @override
  String get saving => 'Zapisywanie...';

  @override
  String get earlier => 'Wcześniej';

  @override
  String get monthJan => 'styczeń';

  @override
  String get monthFeb => 'luty';

  @override
  String get monthMar => 'marca';

  @override
  String get monthApr => 'kwiecień';

  @override
  String get monthMay => 'Maj';

  @override
  String get monthJun => 'czerwca';

  @override
  String get monthJul => 'lipiec';

  @override
  String get monthAug => 'sierpień';

  @override
  String get monthSep => 'wrzesień';

  @override
  String get monthOct => 'paź';

  @override
  String get monthNov => 'listopad';

  @override
  String get monthDec => 'grudzień';

  @override
  String get steeringWord => 'Sterowanie';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Spowoduje to przełączenie backendu z kanału $arg1 na kanał $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Zaimportowano pliki cookie $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '$arg1 temu';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Sterowanie w kolejce: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Aplikacja internetowa nie mogła połączyć się z backendem NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Przeglądarka zablokowała wymagane żądanie ze względu na Politykę bezpieczeństwa treści.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return 'Dozwolona wartość $arg1 wynosząca 4';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Wykonaj zadanie w zwykły sposób.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Zmiany · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'To urządzenie · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limit osiągnięty$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Kody odzyskiwania $arg1 są nadal dostępne.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Klucz zabezpieczający $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Bieżąca sesja';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nOstatnio używany: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Pracuje w $arg1 na tym urządzeniu. NeoAgent bezpośrednio odczytuje i edytuje folder oraz może uruchamiać polecenia, otwierać aplikacje i korzystać z ekranu.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Pracował dla $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Dozwolone przez $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Linki zaproszeń $arg1 z $arg2 zostały odwołane';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Dodaj osoby i grupy, z którymi $arg1 powinien rozmawiać';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Dodaj osoby i grupy, z którymi $arg1 może rozmawiać.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Gdzie słucha $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 obserwuje te miejsca w poszukiwaniu wzmianek. Każdy może tu publikować posty, więc nadal muszą uzyskać zgodę poniżej.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Te osoby mogą zadawać $arg1, gdziekolwiek je oznaczą. Role liczą się tylko w miejscach wymienionych powyżej.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Tylko gdy $arg1 jest oznaczony';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Włączone dla wszystkich grup $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 nadal słyszy tylko osoby i grupy, które już zatwierdziłeś. Dzięki temu $arg1 może dołączyć do zwykłego czatu, a nie tylko dodawać tagi i odpowiedzi.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 nadal słyszy tylko osoby i grupy, które już zatwierdziłeś. To po prostu wybiera, do której z tych grup powinien dołączyć.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Jeśli ktoś oznaczy $arg1 lub odpowie, $arg1 zawsze odpowie. Włącz tę opcję, jeśli $arg1 powinien także włączać się na zwykłym czacie grupowym.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Nowe grupy pozwolą $arg1 dołączyć do zwykłego czatu z zatwierdzonymi osobami, dopóki ich nie wyłączysz.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Nowe grupy pozwolą $arg1 dołączyć do zwykłego czatu, dopóki ich nie wyłączysz.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Nowe grupy pozostają ciche, chyba że zatwierdzona osoba oznaczy $arg1, dopóki ich nie włączysz.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Tylko wtedy, gdy zatwierdzona osoba oznaczy $arg1, chyba że włączysz grupę';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Tylko gdy $arg1 jest oznaczony, chyba że włączysz grupę';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return 'Grupy $arg1 z $arg2 dołączają do zwykłego czatu z zatwierdzonymi osobami';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'To nie akceptuje nowych ludzi. Tagi i odpowiedzi od zatwierdzonych osób zawsze otrzymują odpowiedź. Włącz grupę, jeśli $arg1 również powinien tam dołączyć do zwykłego czatu.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'To nie akceptuje nowych ludzi. Włącz grupę, jeśli $arg1 powinien dołączyć do zwykłego czatu z osobami, które już zatwierdziłeś.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Tagi i odpowiedzi zawsze powodują reakcję. Włącz grupę, jeśli $arg1 również powinien tam dołączyć do zwykłego czatu.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 dołącza do zwykłego czatu z zatwierdzonymi osobami';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 może dołączyć do zwykłego czatu';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 odpowiada tylko wtedy, gdy oznaczy go zatwierdzona osoba';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nic dodatkowego nie jest potrzebne. Połącz się, aby rozpocząć korzystanie z $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Odświeża w $arg1';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Zarejestruj się w $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Brak wspomnień powiązanych z „$arg1”.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (domyślnie)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Oddział: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 dołącza tylko do grup i kanałów, które dodasz poniżej.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return 'Do zlokalizowania danych wykonawczych NeoAgent wymagany jest moduł $arg1.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[skrócony podgląd, łącznie $arg1 bajtów]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefakt ograniczony, łącznie $arg1 bajtów]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' w $arg1';
  }

  @override
  String get worldNews => 'Wiadomości ze świata';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Biegnij, gdy pojawią się nowe nagłówki ze świata. Twój monit decyduje, czy Cię powiadomić.';

  @override
  String get newsKeywordsOptional => 'Słowa kluczowe (opcjonalnie)';

  @override
  String get worldNewsSetup => 'Konfiguracja wiadomości ze świata';

  @override
  String get connectWorldNewsWithGnews =>
      'Dodaj klucz API GNews (bezpłatny plan dostępny na gnews.io). Jest przechowywany w postaci zaszyfrowanej i używany do odpytywania najważniejszych nagłówków pod kątem wyzwalaczy World News.';

  @override
  String get gnewsApiKey => 'Klucz API GNews';

  @override
  String get pasteReplacementGnewsApiKey => 'Wklej zastępczy klucz API GNews';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Pozostaw klucz pusty, aby zachować aktualnie zapisany klucz.';

  @override
  String get gnewsApiKeyIsRequired => 'Wymagany jest klucz API GNews.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nie udało się zapisać konfiguracji World News.';

  @override
  String get disconnectWorldNews => 'Odłącz wiadomości ze świata';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Spowoduje to usunięcie zapisanego klucza API GNews. Wyzwalacze World News przestaną działać, dopóki ponownie nie dodasz klucza.';

  @override
  String get couldNotDisconnectWorldNews => 'Nie można odłączyć World News.';

  @override
  String get systemOneModels => 'Modele SystemOne';

  @override
  String get systemOneAuto => 'Automat';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Wybiera najlepszy dostępny model SystemOne';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Model czatu podejmuje te decyzje';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modele decyzyjne, które umożliwiają podejmowanie decyzji za kulisami w ułamku sekundy: zmiana w czacie grupowym i kroki w przeglądarce. Twój model czatu nadal zapisuje każdą odpowiedź.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Model SystemOne decyduje, kiedy mówić, gdy jest włączony; ten model jest rozwiązaniem awaryjnym.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 z oceną SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne bezpośrednio ocenił tę wiadomość. Nie uruchomiono żadnego modelu językowego.';

  @override
  String get systemOneUnavailable => 'SystemOne niedostępny';

  @override
  String get systemOneAdminAvailability =>
      'Modele decyzyjne, które agenci mogą wybrać w Ustawieniach > Modele. Model wyłączony w tym miejscu opuszcza selektor, a agenci, którzy go wybrali, wracają do trybu Auto. Gdy dowolny model jest wyłączony, modele SystemOne dodane później przez dostawców również są wyłączane.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Nie ma jeszcze modeli SystemOne. Dodaj klucz TypeSafe lub OpenRouter w obszarze Providers lub pobierz model decyzyjny, taki jak zwinny w Ollama 0.35 lub nowszym.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Żaden model SystemOne nie jest jeszcze dostępny. Dodaj klucz TypeSafe lub OpenRouter w obszarze Ustawienia > Modele > Przynieś własny klucz lub pobierz model decyzyjny, taki jak zwinny w Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system jedno modele decyzyjne jev typesafe openrouter ollama dostępność włącz wyłącz';

  @override
  String get chatModels => 'Modele czatu';

  @override
  String get disabled => 'Wyłączone';

  @override
  String get enableShown => 'Włącz pokazane';

  @override
  String get disableShown => 'Pokazano wyłączenie';

  @override
  String get expandAll => 'Rozwiń wszystko';

  @override
  String get collapseAll => 'Zwiń wszystko';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 niezapisane zmiany';
  }

  @override
  String get settingsScopeAllAgents => 'Wszyscy agenci';

  @override
  String get settingsScopeAgent => 'Ten agent';

  @override
  String get settingsScopeApp => 'Aplikacja';

  @override
  String get settingsScopeAccountHint =>
      'To samo wszędzie, gdzie się zalogujesz';

  @override
  String get settingsScopeAllAgentsHint =>
      'Udostępniane wszystkim Twoim agentom';

  @override
  String get settingsAppliesTo => 'Dotyczy';

  @override
  String get settingsSaving => 'Zapisuję…';

  @override
  String get settingsSavedAutomatically => 'Zmiany zapisują się automatycznie';

  @override
  String get settingsSearchHint => 'Przeszukaj wszystkie ustawienia';

  @override
  String get settingsPageProfile => 'Profil';

  @override
  String get settingsPageSecurity => 'Logowanie i bezpieczeństwo';

  @override
  String get settingsPageUsage => 'Użycie';

  @override
  String get settingsPagePermissions => 'Uprawnienia';

  @override
  String get settingsPageComputer => 'Komputer i internet';

  @override
  String get settingsPageBehavior => 'Zachowanie';

  @override
  String get settingsPageSystem => 'Systemu';

  @override
  String get settingsPageProfileDescription =>
      'Twoje imię i nazwisko oraz adres e-mail, kopia Twoich danych i wylogowanie.';

  @override
  String get settingsPageSecurityDescription =>
      'Hasło, uwierzytelnianie dwuskładnikowe, klucze bezpieczeństwa i miejsce zalogowania.';

  @override
  String get settingsPageUsageDescription =>
      'Twoje limity i wydatki na tokeny, wszystko w jednym miejscu.';

  @override
  String get settingsPageAgentsDescription =>
      'Utwórz agentów i wybierz, który domyślnie odpowiada.';

  @override
  String get settingsPagePermissionsDescription =>
      'Co Twoi agenci mogą zrobić, nie pytając Cię wcześniej.';

  @override
  String get settingsPageComputerDescription =>
      'Komputer, na którym pracują Twoi agenci i witryny, które mogą czytać tak jak Ty.';

  @override
  String get settingsPageModelsDescription =>
      'Z jakich modeli korzysta ten agent i kluczy API, które za nie płacą.';

  @override
  String get settingsPageBehaviorDescription =>
      'Jak ten agent mówi i jak czyta czat grupowy.';

  @override
  String get settingsPageVoiceDescription =>
      'Połączenia na żywo, dyktowanie i odpowiedzi głosowe dla tego agenta.';

  @override
  String get settingsPageMessagingDescription =>
      'Gdzie ludzie mogą dotrzeć do tego agenta i jak zachowuje się na czatach.';

  @override
  String get settingsPageGeneralDescription =>
      'Wygląd, język, strefa czasowa i działanie tej aplikacji w tle.';

  @override
  String get settingsPageSystemDescription =>
      'Serwer, z którego korzysta to okno, ten na tym komputerze i aktualizacje aplikacji.';

  @override
  String get settingsYourAgents => 'Twoi agenci';

  @override
  String get settingsChatModel => 'Model czatu';

  @override
  String get settingsChatModelDescription => 'Odpowiada na Twoje wiadomości.';

  @override
  String get settingsSubAgentModel => 'Model subagenta';

  @override
  String get settingsSubAgentModelDescription =>
      'Uruchamia pracę przekazaną w trakcie zadania.';

  @override
  String get settingsDefaultModels => 'Domyślne modele';

  @override
  String get settingsDefaultModelsDescription =>
      'Używane, gdy czat lub zadanie nie wybiera własnego modelu.';

  @override
  String get settingsModelPool => 'Basen modelowy';

  @override
  String get settingsApiKeysDescription =>
      'Użyj własnych kluczy lub punktu końcowego dla tego agenta. Klucze są szyfrowane i nigdy więcej nie pokazywane.';

  @override
  String get settingsPersona => 'Osoba';

  @override
  String get settingsFineTuning => 'Dostrajanie';

  @override
  String get settingsFineTuningDescription =>
      'Rzadko potrzebne. Wartości domyślne odpowiadają większości czatów.';

  @override
  String get settingsShow => 'Pokaż';

  @override
  String get settingsHide => 'Ukryj';

  @override
  String get settingsMinimumContribution => 'Minimalna wartość wkładu';

  @override
  String get settingsBatchWindow => 'Okno wsadowe pokoju';

  @override
  String get settingsBatchWindowDescription =>
      'Czeka tak długo, aby traktować szybkie wiadomości jako jedną turę.';

  @override
  String get settingsHandsFree => 'Bez użycia rąk';

  @override
  String get settingsHandsFreeDescription =>
      'Rozmawiaj swobodnie i przerywaj w dowolnym momencie.';

  @override
  String get settingsPushToTalkDescription =>
      'Przytrzymaj, aby porozmawiać, zwolnij, aby wysłać.';

  @override
  String get settingsLiveVoice => 'Głos na żywo';

  @override
  String get settingsChannels => 'Kanały';

  @override
  String get settingsGroupChats => 'W czatach grupowych';

  @override
  String get settingsGroupChatsDescription =>
      'Jak ten agent zachowuje się w grupach na każdym kanale.';

  @override
  String get settingsGroupChatsDisabled =>
      'Aby je zmienić, włącz moduły zachowań w obszarze Zachowanie.';

  @override
  String get settingsParticipationAutomatic => 'Automatyczny';

  @override
  String get settingsParticipationMentionOnly => 'Tylko wzmianka';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Czyta pokój i przyłącza się, gdy ma coś przydatnego do dodania.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Odpowiada tylko wtedy, gdy ktoś o nim wspomniał lub na który udzielono odpowiedzi.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Odpowiedzi na każdą wiadomość.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Dzieli dłuższe odpowiedzi na krótkie wiadomości w taki sam sposób, jak zwykła osoba.';

  @override
  String get settingsDeliverySingleDescription =>
      'Wysyła każdą odpowiedź jako jedną wiadomość.';

  @override
  String get settingsComputerStatus => 'Stan';

  @override
  String get settingsTest => 'Testuj';

  @override
  String get settingsAppearance => 'Wygląd';

  @override
  String get settingsTheme => 'Temat';

  @override
  String get settingsThemeSystem => 'Systemowy';

  @override
  String get settingsThemeLight => 'Jasny';

  @override
  String get settingsThemeDark => 'Ciemny';

  @override
  String get settingsCloseWindow => 'Kiedy zamkniesz okno';

  @override
  String get settingsCloseAsk => 'Zapytaj';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent działa w tle i pozostaje osiągalny.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent całkowicie odchodzi.';

  @override
  String get settingsPhoneTriggers => 'Wyzwalacze telefonu';

  @override
  String get settingsPhoneTriggersDescription =>
      'Sygnały, które ten telefon wysyła do agentów, aby zadania mogły na nie zareagować.';

  @override
  String get settingsLocationTriggers => 'Wyzwalacze lokalizacji';

  @override
  String get settingsLocationTriggersDescription =>
      'Co kilka minut sprawdza Twoją przybliżoną lokalizację w porównaniu z miejscami obserwowanymi przez Twoje zadania.';

  @override
  String get settingsNotificationTriggers => 'Wyzwala powiadomienia';

  @override
  String get settingsNotificationTriggersDescription =>
      'Przesyła powiadomienia z innych aplikacji na tym telefonie do agentów.';

  @override
  String get settingsSetup => 'Konfiguracja';

  @override
  String get settingsOnboarding => 'Wdrożenie';

  @override
  String get settingsOnboardingDescription =>
      'Przejdź ponownie przez konfigurację pierwszego uruchomienia. Nic, co skonfigurowałeś, nie zostanie utracone.';

  @override
  String get settingsUsernameDescription =>
      'Służy do logowania. Nie można tego zmienić.';

  @override
  String get settingsExport => 'Eksportuj';

  @override
  String get settingsLeave => 'Wyloguj się i usuń';

  @override
  String get settingsSignOutDescription =>
      'Wylogowuje Cię tylko na tym urządzeniu.';

  @override
  String get settingsDeleteAccountDescription =>
      'Usuwa Twoje konto, agentów, pamięć i ustawienia. Tego nie można cofnąć.';

  @override
  String get settingsTokenUsage => 'Użycie tokena';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Żadne ustawienie nie pasuje do „$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wyników',
      few: '$count wyniki',
      one: '$count wynik',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Zaawansowane ustawienia modelu';

  @override
  String get settingsAdvancedModelsDescription =>
      'Opcjonalne. Przypnij model do jednego rodzaju pracy; przejmuje kontrolę za każdym razem, gdy agent korzysta z tych narzędzi. Wszystko, co pozostało domyślnie, jest zgodne z modelem czatu.';

  @override
  String get settingsTaskModelDefault => 'Domyślne';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Podąża za modelem czatu';

  @override
  String get settingsTaskModelCoding => 'Kodowanie';

  @override
  String get settingsTaskModelCodingDescription =>
      'Pisanie, edytowanie i debugowanie kodu.';

  @override
  String get settingsTaskModelComputerUse => 'Korzystanie z komputera';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Sterowanie przeglądarką i komputerem stacjonarnym.';

  @override
  String get settingsTaskModelAndroidUse => 'Korzystanie z Androida';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Obsługa aplikacji na urządzeniu z Androidem lub emulatorze.';

  @override
  String get settingsTaskModelResearch => 'Badania';

  @override
  String get settingsTaskModelResearchDescription =>
      'Wyszukiwanie, czytanie i podsumowywanie źródeł.';

  @override
  String get knowledgeGraphHint =>
      'Twoje najczęściej wymieniane byty, pokolorowane według klastrów. Linie łączą byty pojawiające się w tych samych wspomnieniach. Stuknij jeden, aby zobaczyć powiązane z nim łącza i wspomnienia; przeciągnij, aby przesunąć, zsuń palce lub Ctrl/⌘-przewiń, aby powiększyć.';

  @override
  String get linkedEntities => 'Powiązane podmioty';

  @override
  String get noLinkedEntities =>
      'Nie jest jeszcze powiązany z innymi podmiotami.';

  @override
  String mentionsArg1(int arg1) {
    return 'Wspomina $arg1';
  }

  @override
  String get entityKindConcept => 'Koncepcja';

  @override
  String get entityKindDomain => 'Domena';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Link';

  @override
  String get entityKindFile => 'Plik';

  @override
  String get entityKindAcronym => 'Akronim';

  @override
  String get entityKindIdentifier => 'Identyfikator';

  @override
  String get entityKindVersion => 'Wersja';

  @override
  String get openFullscreen => 'Otwórz pełny ekran';

  @override
  String get zoomIn => 'Powiększ';

  @override
  String get zoomOut => 'Pomniejsz';

  @override
  String get searchEntities => 'Znajdź podmiot';

  @override
  String get incomingCall => 'Połączenie przychodzące';

  @override
  String get answerCall => 'Odpowiedź';

  @override
  String get callMeLater => 'Zadzwoń do mnie później';

  @override
  String get callingEllipsis => 'Dzwonię…';

  @override
  String get reconnectingCall => 'Ponowne łączenie';

  @override
  String get agentWorking => 'Pracujący';

  @override
  String get micMuted => 'Wyciszony';

  @override
  String get speakerphone => 'Głośnik';

  @override
  String get muteMic => 'Wycisz';

  @override
  String get unmuteMic => 'Wyłącz wyciszenie';

  @override
  String get releaseToSend => 'Zwolnij, aby wysłać';

  @override
  String get callEnded => 'Połączenie zostało zakończone';

  @override
  String get openConversation => 'Otwarta rozmowa';

  @override
  String get callBack => 'Oddzwoń';

  @override
  String get letCallsReachYou => 'Pozwól, aby połączenia do Ciebie docierały';

  @override
  String get callPermissionsIntro =>
      'Twoi agenci mogą do Ciebie zadzwonić. Aby dzwonić jak połączenie telefoniczne, gdy NeoAgent działa w tle lub telefon jest zablokowany, potrzebuje tych elementów.';

  @override
  String get showOverOtherApps => 'Pokaż nad innymi aplikacjami';

  @override
  String get showOverOtherAppsDetail =>
      'Wyświetla ekran połączenia, gdziekolwiek jesteś.';

  @override
  String get fullScreenCalls => 'Połączenia na pełnym ekranie';

  @override
  String get fullScreenCallsDetail => 'Dzwoni na ekranie blokady.';

  @override
  String get unrestrictedBattery => 'Nieograniczona bateria';

  @override
  String get unrestrictedBatteryDetail =>
      'Utrzymuje połączenie NeoAgent, dzięki czemu połączenia przychodzą.';

  @override
  String get permissionAllowed => 'Dozwolone';

  @override
  String get triggerSectionCalendar => 'Kalendarz';

  @override
  String get triggerSectionFiles => 'Pliki i dokumenty';

  @override
  String get triggerSectionHome => 'Dom i media';

  @override
  String get triggerSectionDevices => 'Urządzenia i miejsca';

  @override
  String get triggerSectionTasks => 'Zadania';

  @override
  String get messagingMemberJoined => 'Członek dołączył';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Uruchamiaj, gdy ktoś dołączy do serwera Discord, grupy na Telegramie lub WhatsApp, kanału Slack lub pokoju Matrix.';

  @override
  String get messagingMemberLeft => 'Członek odszedł';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Uruchamiaj, gdy ktoś opuści serwer Discord, grupę na Telegramie lub WhatsApp, kanał Slack lub pokój Matrix.';

  @override
  String get messagingReactionAdded => 'Reakcja dodana';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Uruchamiaj, gdy dozwolona osoba zareaguje na wiadomość na czacie prywatnym.';

  @override
  String get messagingPlatformDisconnected => 'Wiadomości zostały rozłączone';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Uruchamiaj, gdy połączenie do przesyłania wiadomości zostanie zatrzymane i będzie Cię potrzebować, na przykład po wylogowaniu.';

  @override
  String get googleCalendarEventStarting =>
      'Rozpoczęcie wydarzenia w Kalendarzu Google';

  @override
  String get googleCalendarEventCreated =>
      'Utworzono wydarzenie w Kalendarzu Google';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Uruchom, gdy pojawi się nowe wydarzenie lub zaproszenie.';

  @override
  String get outlookCalendarEventStarting =>
      'Rozpoczęcie wydarzenia w kalendarzu programu Outlook';

  @override
  String get nextcloudCalendarEventStarting =>
      'Rozpoczęcie wydarzenia w kalendarzu Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Biegaj określoną liczbę minut przed każdym wydarzeniem.';

  @override
  String get googleDriveFileAdded => 'Dodano plik z Dysku Google';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Uruchamiaj, gdy plik zostanie dodany do Dysku lub znajdującego się na nim folderu.';

  @override
  String get googleSheetsRowAdded => 'Dodano wiersz Arkuszy Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Uruchamiaj, gdy w arkuszu pojawią się nowe wiersze.';

  @override
  String get onedriveFileAdded => 'Dodano plik OneDrive';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Uruchamiaj po dodaniu pliku do folderu OneDrive.';

  @override
  String get nextcloudFileAdded => 'Dodano plik Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Uruchamiaj, gdy plik zostanie dodany do folderu Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Plik Nextcloud udostępniony Ci';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Uruchamiaj, gdy ktoś udostępni Ci plik lub folder.';

  @override
  String get notionItemAdded => 'Dodano element bazy danych pojęć';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Uruchamiane po dodaniu elementu do bazy danych Notion.';

  @override
  String get notionItemUpdated => 'Zaktualizowano element bazy danych pojęć';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Uruchamiaj, gdy zmieni się element w bazie danych Notion.';

  @override
  String get trelloCardEnteredList => 'Karta Trello dodana do listy';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Uruchamiane, gdy karta jest tworzona lub przenoszona na listę.';

  @override
  String get figmaCommentAdded => 'Dodano komentarz Figmy';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Uruchamiaj, gdy ktoś skomentuje plik Figma.';

  @override
  String get githubPrOpened => 'Otwarto żądanie ściągnięcia GitHub';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Uruchamiaj, gdy w repozytorium zostanie otwarte nowe żądanie ściągnięcia.';

  @override
  String get githubWorkflowRunFailed =>
      'Uruchomienie przepływu pracy w GitHub nie powiodło się';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Uruchom, gdy uruchomienie akcji GitHub nie powiedzie się.';

  @override
  String get githubCommitPushed => 'Wysłano zatwierdzenie GitHub';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Uruchamiaj, gdy nowe zatwierdzenia dotrą do gałęzi.';

  @override
  String get mcpServerFailed => 'Serwer MCP uległ awarii';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Uruchom, gdy działający serwer MCP ulegnie awarii lub wymaga zalogowania.';

  @override
  String get homeAssistantStateChanged =>
      'Stan Asystenta Home został zmieniony';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Uruchamiane, gdy jednostka ulegnie zmianie, osiągnie stan lub przekroczy wartość.';

  @override
  String get spotifyTrackChanged => 'Utwór Spotify zmieniony';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Uruchom, gdy zacznie odtwarzać się inny utwór.';

  @override
  String get neorecallDailySummaryReady =>
      'Gotowe podsumowanie dzienne NeoRecall';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Uruchom, gdy podsumowanie dnia jest ostateczne.';

  @override
  String get neorecallConversationRecorded =>
      'Rozmowa NeoRecall została nagrana';

  @override
  String get runWhenARecordedConversationEnds =>
      'Uruchamiaj po zakończeniu nagranej rozmowy.';

  @override
  String get geofenceTrigger => 'Geoogrodzenie lokalizacji';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Uruchamiaj, gdy Twój telefon dotrze do danego miejsca lub je opuści. Potrzebuje śledzenia lokalizacji w telefonie.';

  @override
  String get healthMetricRecorded => 'Zarejestrowano metrykę zdrowia';

  @override
  String get runWhenAHealthReadingArrives =>
      'Uruchom po nadejściu zsynchronizowanego odczytu stanu, opcjonalnie powyżej lub poniżej wartości.';

  @override
  String get wearableConnectionChanged =>
      'Urządzenie do noszenia podłączone lub odłączone';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Uruchamiaj, gdy urządzenie do noszenia łączy się lub rozłącza.';

  @override
  String get taskRunFinished => 'Kolejne zadanie zakończone';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Uruchamiaj po zakończeniu, pomyślnym lub niepowodzeniu innego zadania.';

  @override
  String get appPackageOptional => 'Pakiet aplikacji (opcjonalnie)';

  @override
  String get appPackageHelper => 'Na przykład com.whatsapp';

  @override
  String get anyPlatform => 'Dowolna platforma';

  @override
  String get spaceIdOptional =>
      'Identyfikator serwera, grupy, kanału lub pokoju (opcjonalnie)';

  @override
  String get spaceIdHelper =>
      'Puste zegarki w każdym, w którym znajduje się bot.';

  @override
  String get emojiOptional => 'Emotikony (opcjonalnie)';

  @override
  String get chatIdOptional => 'Identyfikator czatu (opcjonalnie)';

  @override
  String get platformOptional => 'Platforma (opcjonalnie)';

  @override
  String get platformOptionalHelper =>
      'Na przykład WhatsApp. Wszystkie puste zegarki.';

  @override
  String get minutesBefore => 'Kilka minut wcześniej';

  @override
  String get calendarIdOptional => 'Identyfikator kalendarza (opcjonalnie)';

  @override
  String get calendarIdHelper => 'Pusty używa Twojego głównego kalendarza.';

  @override
  String get invitesOnly => 'Tylko zaproszenia od innych';

  @override
  String get nextcloudCalendarPath => 'Kalendarz';

  @override
  String get nextcloudCalendarPathHelper =>
      'Jego nazwa na liście kalendarza Nextcloud, na przykład osobista';

  @override
  String get folderIdOptionalHelperDrive => 'Puste zegarki na całym Dysku.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Pusty obserwuje folder główny.';

  @override
  String get driveFolderIdOptional => 'Identyfikator folderu (opcjonalnie)';

  @override
  String get spreadsheetId => 'Identyfikator arkusza kalkulacyjnego';

  @override
  String get sheetRange => 'Zasięg';

  @override
  String get sheetRangeHelper => 'Kolumny tabeli, na przykład Arkusz1!A:E';

  @override
  String get folderPathOptional => 'Ścieżka folderu (opcjonalnie)';

  @override
  String get folderPathHelper => 'Na przykład Dokumenty';

  @override
  String get notionDatabaseId => 'Identyfikator bazy danych';

  @override
  String get trelloListId => 'Identyfikator listy';

  @override
  String get figmaFileKey => 'Klucz pliku';

  @override
  String get figmaFileKeyHelper => 'Z linku do pliku: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Repozytorium';

  @override
  String get workflowOptional => 'Przepływ pracy (opcjonalnie)';

  @override
  String get workflowHelper => 'Nazwa pliku, np. ci.yml';

  @override
  String get branchOptional => 'Oddział (opcjonalnie)';

  @override
  String get branchHelper => 'Puste używa gałęzi domyślnej.';

  @override
  String get mcpServerIdOptional => 'Identyfikator serwera MCP (opcjonalnie)';

  @override
  String get entityId => 'Identyfikator jednostki';

  @override
  String get entityIdHelper => 'Na przykład binarny_sensor.front_door';

  @override
  String get targetStateOptional => 'Stan docelowy (opcjonalnie)';

  @override
  String get targetStateHelper => 'Na przykład na';

  @override
  String get aboveOptional => 'Powyżej (opcjonalnie)';

  @override
  String get belowOptional => 'Poniżej (opcjonalnie)';

  @override
  String get placeName => 'Nazwa miejsca';

  @override
  String get latitude => 'Szerokość geograficzna';

  @override
  String get longitude => 'Długość geograficzna';

  @override
  String get radiusMeters => 'Promień w metrach';

  @override
  String get geofenceTransition => 'Kiedy';

  @override
  String get arriving => 'Przybycie';

  @override
  String get leaving => 'Odejście';

  @override
  String get healthMetric => 'Metryka zdrowia';

  @override
  String get healthMetricHelper => 'Na przykład tętno, kroki, waga';

  @override
  String get wearableTransition => 'Kiedy urządzenie do noszenia';

  @override
  String get wearableConnects => 'Łączy';

  @override
  String get wearableDisconnects => 'Rozłącza';

  @override
  String get sourceTask => 'Po zadaniu';

  @override
  String get taskOutcome => 'Wynik';

  @override
  String get anyOutcome => 'Jakikolwiek wynik';

  @override
  String get succeeded => 'Udało się';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return 'Brak $arg1 lub jest on nieprawidłowy.';
  }

  @override
  String get triggerSectionMessaging => 'Wiadomości';

  @override
  String get triggerSectionDeveloper => 'Deweloper';

  @override
  String get triggerSectionMemory => 'Pamięć';

  @override
  String get triggerSectionNews => 'Wiadomości';

  @override
  String get triggerSectionSystem => 'Systemu';

  @override
  String get searchTriggersHint =>
      'Wyszukaj wyzwalacze, aplikacje lub zdarzenia';

  @override
  String get noTriggersMatch =>
      'Żaden wyzwalacz nie pasuje do Twojego wyszukiwania.';

  @override
  String get triggerAccountMissing => 'Jeszcze nie ma konta';

  @override
  String get pickTriggerKeyboardHint => 'Enter wybiera pierwszy wynik';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return 'Wyzwalacze $arg1';
  }

  @override
  String get addFromSkillsSh => 'Dodaj z Skills.sh';

  @override
  String get skillsShHint =>
      'Wyszukaj powyżej, aby znaleźć umiejętności w pliku Skills.sh, lub wklej link Skills.sh lub polecenie `npx Skills Add`.';

  @override
  String get noSkillsShMatches =>
      'Żadne umiejętności.sh umiejętności nie pasują do tego wyszukiwania.';

  @override
  String get installingSkill => 'Instaluję…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Zainstalowano $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Instaluje się $arg1';
  }

  @override
  String get authVerify => 'Zweryfikuj';

  @override
  String get authCreateAccount => 'Utwórz konto';

  @override
  String get authNewInviteLink => 'Nowy link z zaproszeniem';

  @override
  String get authShowPassword => 'Pokaż hasło';

  @override
  String get authHidePassword => 'Ukryj hasło';

  @override
  String get authPasswordWillBeRejected => 'zbyt słabe, zostanie odrzucone';

  @override
  String get authUsernameTooShort =>
      'Nazwy użytkowników muszą mieć co najmniej 3 znaki.';

  @override
  String get authUsernameTaken => 'Ta nazwa użytkownika jest już zajęta.';

  @override
  String get authSignupsClosed =>
      'Rejestracja na tym serwerze jest zamknięta. Poproś administratora o konto.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Ten serwer akceptuje logowanie wyłącznie za pośrednictwem protokołu HTTPS. Zamiast tego otwórz $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Ten serwer akceptuje logowanie wyłącznie za pośrednictwem protokołu HTTPS. Połącz się z nim za pomocą adresu https://.';

  @override
  String get authAccountNotFound => 'To konto już nie istnieje.';

  @override
  String get authQrRateLimited =>
      'Zbyt wiele żądań logowania QR. Poczekaj chwilę, a następnie odśwież kod.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Nie pamiętasz hasła? Poproś administratora serwera o jego zresetowanie w Administrator → Użytkownicy.';

  @override
  String get authChangeServer => 'Zmień serwer';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Logowanie do $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Ten adres nie odpowiada jak serwer NeoAgent. Sprawdź adres URL i spróbuj ponownie.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nie można otworzyć bezpiecznego połączenia (HTTPS) z $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nie udało się połączyć z $arg1 przez HTTPS, zwykły HTTP też nie odpowiedział. Sprawdź adres i port.';
  }

  @override
  String get adminResetPassword => 'Zresetuj hasło';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Zresetuj hasło dla $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Wybierz nowe hasło dla $arg1. Zostaną wylogowani na każdym urządzeniu i zalogują się ponownie przy użyciu tego hasła.';
  }

  @override
  String get adminNewPassword => 'Nowe hasło';

  @override
  String get adminSetPassword => 'Ustaw hasło';

  @override
  String get authMissingFields => 'Wypełnij każde wymagane pole.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 resetuje hasło $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Hasło zaktualizowane; użytkownik został wylogowany wszędzie.';

  @override
  String get authSignInTitle => 'Zaloguj się do NeoAgenta';

  @override
  String get authSignInSubtitle => 'Zeskanuj telefonem lub użyj hasła.';

  @override
  String get authOrUsePassword => 'lub użyj swojego hasła';

  @override
  String get qrLoginWaitingTitle => 'Zatwierdź na swoim telefonie';

  @override
  String get qrLoginWaitingBody =>
      'Twój telefon zeskanował kod. Potwierdź tam logowanie, aby zakończyć logowanie.';

  @override
  String get qrLoginSigningInOn => 'Zaloguj się';

  @override
  String get qrLoginLocation => 'Lokalizacja';

  @override
  String get qrLoginWaitingForApproval => 'Oczekiwanie na zatwierdzenie';

  @override
  String get qrLoginCancelAndUsePassword => 'Anuluj i użyj hasła';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Logowanie na Twoim telefonie zostało odrzucone. Zeskanuj nowy kod, aby spróbować ponownie.';

  @override
  String get signupKey => 'Klucz rejestracji';

  @override
  String get signupKeyStepSubtitle =>
      'Nowe konta na tym serwerze wymagają klucza rejestracji. Wpisz klucz otrzymany od administratora.';

  @override
  String get signupKeyChange => 'Zmień';

  @override
  String get signupKeyRequiredError => 'Wpisz swój klucz rejestracji.';

  @override
  String get signupKeyInvalidError =>
      'Ten klucz rejestracji jest nieprawidłowy. Sprawdź go i spróbuj ponownie.';

  @override
  String get signupKeyUsedError =>
      'Ten klucz rejestracji został już użyty. Poproś administratora o nowy.';

  @override
  String get adminRequireSignupKey => 'Wymagaj klucza rejestracji';

  @override
  String get adminRequireSignupKeyHint =>
      'Nowe konta wymagają jednorazowego klucza od administratora. Po wyłączeniu każdy, kto ma dostęp do tego serwera, może się zarejestrować. Pierwsze konto nigdy nie wymaga klucza.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Nowe konta wymagają teraz klucza rejestracji.';

  @override
  String get adminSignupOpenNotice => 'Teraz każdy może się zarejestrować.';

  @override
  String get signupKeys => 'Klucze rejestracji';

  @override
  String get signupKeysDescription =>
      'Jednorazowe klucze do rejestracji, gdy klucz jest wymagany. Każdy klucz tworzy dokładnie jedno konto.';

  @override
  String get signupKeysNew => 'Nowe klucze';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Nieużyte · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Użyte · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Unieważnione · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Wszystkie · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Nieużyty';

  @override
  String get signupKeyStatusUsed => 'Użyty';

  @override
  String get signupKeyStatusRevoked => 'Unieważniony';

  @override
  String get signupKeysExport => 'Eksportuj .txt';

  @override
  String get signupKeysCopied => 'Skopiowano klucze';

  @override
  String get signupKeyCopied => 'Skopiowano klucz';

  @override
  String get signupKeysEmpty => 'Brak kluczy na tej liście.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Utworzono $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Użyty przez $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Użyty $arg1 przez konto, które zostało później usunięte';
  }

  @override
  String get signupKeyRevokeTitle => 'Unieważnić ten klucz?';

  @override
  String get signupKeyRevokeMessage =>
      'Nikt nie będzie mógł się nim zarejestrować. Tej operacji nie można cofnąć.';

  @override
  String get signupKeyRevoked => 'Klucz unieważniony.';

  @override
  String signupKeysShowMore(int count) {
    return 'Pokaż jeszcze $count';
  }

  @override
  String get signupKeysCreateTitle => 'Utwórz klucze rejestracji';

  @override
  String get signupKeysCount => 'Liczba kluczy';

  @override
  String get signupKeysCountHelper => 'Od 1 do 500';

  @override
  String get signupKeysCountInvalid => 'Wpisz liczbę od 1 do 500.';

  @override
  String get signupKeysLabel => 'Etykieta (opcjonalnie)';

  @override
  String get signupKeysLabelHint => 'np. Wiosenni beta testerzy';

  @override
  String signupKeysCreateAction(int count) {
    return 'Utwórz ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Gotowe klucze: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Przekaż każdy klucz tylko jednej osobie. Nieużyte klucze pozostają na liście, więc możesz je później ponownie skopiować lub wyeksportować.';

  @override
  String get signupKeysSaveDialogTitle => 'Zapisz klucze rejestracji';

  @override
  String get signupKeysExported => 'Wyeksportowano klucze.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor utworzył(a) klucze rejestracji ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor unieważnił(a) klucz rejestracji';
  }
}
