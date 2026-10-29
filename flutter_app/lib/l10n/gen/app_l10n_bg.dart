// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppL10nBg extends AppL10n {
  AppL10nBg([String locale = 'bg']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Добре дошли';

  @override
  String get onboardingEyebrowCommunication => 'Комуникация';

  @override
  String get onboardingEyebrowIntelligence => 'Интелигентност';

  @override
  String get onboardingEyebrowComputer => 'компютър';

  @override
  String get onboardingEyebrowAutomation => 'Автоматизация';

  @override
  String get onboardingNext => 'Следваща';

  @override
  String get onboardingIntroCouldNotLoad => 'Интрото не можа да се зареди.';

  @override
  String get onboardingModelDescription =>
      'Изберете модела, който NeoAgent трябва да използва по подразбиране, или го оставете да избере автоматично.';

  @override
  String get onboardingLoadingModels => 'Моделите се зареждат...';

  @override
  String get noAiModelTitle => 'Все още не е настроен AI модел';

  @override
  String get noAiModelBody =>
      'Добавете API ключ от доставчик като OpenAI, Anthropic или Google. След това NeoAgent показва моделите, които можете да използвате.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent се нуждае от AI модел, за да отговори. Добавете API ключ от доставчик като OpenAI, Anthropic или Google.';

  @override
  String get noAiModelAdminHint =>
      'Като администратор можете също да настроите доставчици за всички под Администратор → Доставчици.';

  @override
  String get addApiKey => 'Добавяне на API ключ';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform е свързан.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Изчаква се $platform да се свърже...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Настройката не можа да бъде запазена: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Готови';

  @override
  String get onboardingStepRequired => 'Задължително';

  @override
  String get onboardingStepOptional => 'Не е задължително';

  @override
  String get onboardingStepCloudOrLocal => 'Облачно или локално';

  @override
  String get onboardingStepComputer => 'компютър';

  @override
  String get onboardingStepRoutines => 'Съчетания';

  @override
  String get onboardingComputerChoiceTitle => 'Къде трябва\nда работи?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Можете да превключвате на сесия.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Частен пясъчник · винаги включен';

  @override
  String get onboardingThisComputer => 'Този компютър';

  @override
  String get onboardingThisComputerSubtitle =>
      'Вашите файлове, приложения и браузър';

  @override
  String get onboardingSearchApps => 'Търсене на приложения...';

  @override
  String get onboardingRoutinesDescription =>
      'Резултатите пристигат във вашите чатове.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Резултатите пристигат като известия.';

  @override
  String get onboardingNotifications => 'Известия';

  @override
  String get onboardingReadyTitle => 'Всичко е\nготово.';

  @override
  String get onboardingReadyDescription => 'Изпратете първото си съобщение.';

  @override
  String get onboardingMessageNeoagent => 'Съобщение NeoAgent';

  @override
  String get onboardingAskAnything => 'Попитайте каквото и да е...';

  @override
  String get onboardingOpenNeoagent => 'Отворете NeoAgent';

  @override
  String get onboardingStarterTrip => 'Планирайте пътуване през уикенда';

  @override
  String get onboardingStarterLanding => 'Създайте целева страница';

  @override
  String onboardingQuickSteps(int count) {
    return '$count бързи стъпки';
  }

  @override
  String get taskNeedsEmail => 'Първо свържете имейл';

  @override
  String get taskNeedsCalendar => 'Първо свържете календар';

  @override
  String get taskNeedsModel => 'Първо настройте AI модел';

  @override
  String get taskPromptDailyRecap =>
      'Обобщете деня си: обобщете разговорите, свършената работа и решенията от днес, след това избройте всичко, което трябва да проследя утре. Бъдете кратки и ми го изпратете.';

  @override
  String get taskPromptInboxCheck =>
      'Проверете моята входяща кутия за съобщения, пристигнали след последната проверка. Изпращайте ми съобщения само за имейли, които са спешни или се нуждаят от отговор, с резюме от един ред. Ако нищо не се нуждае от моето внимание, не изпращайте нищо.';

  @override
  String get taskPromptMorningBriefing =>
      'Подгответе сутрешния ми брифинг: днешното време там, където съм, събитията в календара ми и най-важните отворени елементи, за които знам. Изпратете го като кратко, сканируемо съобщение.';

  @override
  String get taskPromptTomorrowPrep =>
      'Погледнете календара ми за утре. За всяка среща ми кажете за какво става въпрос, кой участва и всичко, което трябва да подготвя. Ако утрешният ден е празен, не изпращайте нищо.';

  @override
  String get taskPromptNewsDigest =>
      'Потърсете в мрежата днешните най-важни новини по темите, които ме вълнуват (използвайте това, което си спомняте за моите интереси). Изпратете ми резюме от до пет елемента с по едно изречение и връзка.';

  @override
  String get taskPromptWeeklyReview =>
      'Преглед на моята седмица: какво е направено, какво се е пропуснало и какво все още е отворено. Предложете трите най-важни неща, върху които да се съсредоточите следващата седмица.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Свържете телефонен номер, който принадлежи на агента. Всеки, на когото разрешите, може да разговаря с него в директни чатове и групи.';

  @override
  String get whatsappSelfChatDescription =>
      'Свържете собствения си номер и говорете с агента в чата си „Изпратете си съобщение“. Всеки друг чат и група в този акаунт се игнорира.';

  @override
  String get chatSendHintMac => '⌘↵ за изпращане';

  @override
  String get chatSendHintOther => 'Ctrl+Enter за изпращане';

  @override
  String get aBaseUrlIsRequiredFor =>
      'За тази крайна точка се изисква основен URL адрес.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Променен имейл адрес се потвърждава преди да бъде използван.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Решение по-високо във веригата печели.';

  @override
  String get aDeletedAccount => 'изтрит акаунт';

  @override
  String get aFridayLookBackAtThe =>
      'Петък поглед назад към седмицата и план за следващата.';

  @override
  String get aKeyThatAsksForA =>
      'Ключ, който изисква ПИН или пръстов отпечатък, също замества вашия двуфакторен код.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Езиков модел прецени това съобщение, защото SystemOne е изключен.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Файл с метаданни за настройка на NeoAgent надхвърли ограничението за безопасен размер.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'На сървъра е налична по-нова уеб компилация. Презаредете, за да изтеглите най-новия пакет.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Частен работен плот с Chromium, файлове, текстов редактор, терминал и Python. Вашата работа остава запазена между сесиите.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Частен компютър с Linux или устройство с Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Задължителният инсталационен файл на NeoAgent не можа да бъде изтеглен.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Съотборник ви изпраща връзка за покана. След като го приемете, те ';

  @override
  String get aTeammateSentYouAnInvite =>
      'съотборник ви изпрати връзка за покана, въведете я тук, за да се присъедините към техния екип.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Временно изтегляне ще бъде изчистено по-късно.';

  @override
  String get aValueIsStored => 'Запаметява се стойност.';

  @override
  String get access => 'Достъп';

  @override
  String get accessActivity => 'Дейност за достъп';

  @override
  String accessArg1(Object? arg1) {
    return 'Достъп: $arg1';
  }

  @override
  String get accessMode => 'Режим на достъп';

  @override
  String get accessPermissions => 'Разрешения за достъп';

  @override
  String get accessToken => 'токен за достъп';

  @override
  String get accessToken2 => 'Токен за достъп';

  @override
  String get account => 'Акаунт';

  @override
  String accountArg1(Object? arg1) {
    return 'Акаунт #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Сигнали за промяна на акаунта';

  @override
  String get accountEmail => 'Имейл на акаунта';

  @override
  String get accountEmailIsOffUntilThese =>
      'Имейлът на акаунта е изключен, докато не бъдат зададени следните: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent използва този език навсякъде в приложението. Първият път, когато влезете, следва това устройство. След това изборът се запазва във вашия акаунт и се използва на всяко устройство.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Не може да се промени езикът: $error';
  }

  @override
  String get accountLanguageTitle => 'език';

  @override
  String get accountNumber => 'Номер на сметката';

  @override
  String get accountSettings => 'Настройки на акаунта';

  @override
  String get accounts => 'Акаунти';

  @override
  String get accountsByTokensUsedAllTime =>
      'Акаунти по използвани токени, през цялото време.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'облачни компютри на акаунти. Промените се прилагат след сървър ';

  @override
  String get accountsOnThisServer => 'Акаунти на този сървър';

  @override
  String get active => 'Активен';

  @override
  String get activeSessions => 'Активни сесии';

  @override
  String get activeToday => 'Активен днес';

  @override
  String get add => 'Добавете';

  @override
  String get addAProviderCredentialFirstIts =>
      'Първо добавете идентификационни данни на доставчик. Моделите му се появяват тук веднъж ';

  @override
  String get addAgent => 'Добавяне на агент';

  @override
  String get addAnotherSignInMethodBefore =>
      'Добавете друг метод за влизане, преди да премахнете този.';

  @override
  String get addBinding => 'Добавете обвързване';

  @override
  String get addByNameOrId => 'Добавете по име или ID';

  @override
  String get addByNameOrIdInstead => 'Вместо това добавете по име или ID';

  @override
  String get addCredentialBinding =>
      'Добавете обвързване на идентификационни данни';

  @override
  String get addEntry => 'Добавяне на запис';

  @override
  String get addKey => 'Добавете ключ';

  @override
  String get addMcpServer => 'Добавете MCP сървър';

  @override
  String get addMemory => 'Добавяне на памет';

  @override
  String get memoryReview => 'Преглед';

  @override
  String get memoryReviewPrompt =>
      'Прегледай всички мои спомени и ги подреди: архивирай дубликатите, остарелите факти и всичко без трайна стойност. След това ми кажи накратко какво промени.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Добавете повече дължина или друг тип знак.';

  @override
  String get addPeopleOrGroups => 'Добавете хора или групи';

  @override
  String get addSecurityKey => 'Добавете ключ за сигурност';

  @override
  String get addSomeoneOrAGroup => 'Добавете някого или група';

  @override
  String get addTask => 'Добавяне на задача';

  @override
  String get addTests => 'Добавете тестове';

  @override
  String get addTestsForThePartsOf =>
      'Добавете тестове за частите от този проект, които имат най-малко покритие, след което ги изпълнете.';

  @override
  String get addTheirOwnKeysInSettings =>
      'добавят свои собствени ключове в Настройки.';

  @override
  String get addToPrompt => 'Добавяне към подкана';

  @override
  String get added => 'Добавено';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Добавен $arg1 · Последно използван $arg2';
  }

  @override
  String get addressWithTheProvider => 'адрес с доставчика.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Регулирайте силата на звука на високоговорителя, прегледайте настройките по подразбиране на хардуерните бутони и управлявайте тази сесия за стартиране.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Регулирайте филтъра за търсене или състояние, за да видите повече канали за съобщения.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Регулирайте силата на звука на високоговорителя тук.';

  @override
  String get admin => 'Админ';

  @override
  String adminArg1(Object? arg1) {
    return 'Администратор › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Тук се показват административни субсидии, връзки за покани и промени в управлението.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Разширен ръчен график за специални случаи.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Разширено: минута час ден месец делничен ден.';

  @override
  String get againRightAway => 'пак веднага.';

  @override
  String get agent => 'агент';

  @override
  String agentArg1(Object? arg1) {
    return 'Агент: $arg1';
  }

  @override
  String get agentCalls => 'Агент се обажда';

  @override
  String get agentCommunication => 'Комуникация с агент';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Комуникация с агент: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Режимът на агент редактира работното пространство · ⌘↵ изпращане · ⌘N нова сесия';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Агентът спира и иска разрешение, преди да започне изпълнението.';

  @override
  String get agentProfile => 'Профил на агент';

  @override
  String get agentVisibleName => 'Видно от агента име';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Агентът иска да използва $arg1. Докоснете, за да решите.';
  }

  @override
  String get agents => 'Агенти';

  @override
  String get aiAnswerUnreadable => 'AI отговорът е нечетлив';

  @override
  String get aiProviderKeys => 'Ключове за доставчик на AI';

  @override
  String get aiUnavailable => 'AI не е наличен';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'сигнали и други имейли от акаунта.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Предупреждава, когато връзката за съобщения изисква внимание от страна на потребителя';

  @override
  String get all => 'Всички';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Всички агенти ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Всички $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Всички слотове за облачен компютър в момента се използват. Опитайте отново след малко.';

  @override
  String get allComputerSlotsAreBusy => 'Всички компютърни слотове са заети';

  @override
  String get allTables => 'Всички маси';

  @override
  String get allTime => 'През цялото време';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Всички инструменти са разрешени — агентът може да използва всяка възможност, без да иска. ';

  @override
  String get allow => 'Разрешете';

  @override
  String get allowedRunsWithoutAsking => 'Разрешено. Бяга без да пита.';

  @override
  String get allowAll => 'Разрешете всички';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Разрешете „Инсталиране на неизвестни приложения“ за NeoAgent, след което опитайте отново актуализацията.';

  @override
  String get allowOnce => 'Разрешете веднъж';

  @override
  String get allowSender => 'Разрешаване на подателя';

  @override
  String get allowSession => 'Разрешаване на сесия';

  @override
  String get allowTheAgentToStartAn =>
      'Позволете на агента да започне гласово повикване в приложението с вас.';

  @override
  String get allowedOrigins => 'Разрешен произход';

  @override
  String get allowedPathPrefix => 'Позволен префикс на пътя';

  @override
  String get allowsYouCanChangeThatPer =>
      'позволява. Можете да промените това за всеки човек по-късно. Връзките никога не се предоставят ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'вече принадлежи към съществуващ акаунт';

  @override
  String get alreadyLinkedToAnotherAccount => 'вече е свързан с друг акаунт';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'вече е свързан с друг акаунт на neoagent';

  @override
  String get alreadyUsed => 'вече използвани';

  @override
  String get always => 'Винаги';

  @override
  String get alwaysAllow => 'Винаги позволявайте';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '„Разрешаване винаги“ запазва правилото за постоянно — можете да го промените в Настройки.';

  @override
  String get alwaysAsk => 'Винаги питайте';

  @override
  String get alwaysEngage => 'Винаги се ангажирайте';

  @override
  String get alwaysJoins => 'Винаги се присъединява';

  @override
  String get anApiKeyIsRequired => 'Изисква се API ключ.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Вечерно обобщение на случилото се и какво да проследим.';

  @override
  String get anHttpOrHttpsUrlIs => 'Изисква се http или https URL адрес.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'и анализи. Екипните връзки са активни на страницата на Екипа.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Инсталирането на Android APK не е налично на тази платформа.';

  @override
  String get androidApp => 'Приложение за Android';

  @override
  String get androidControl => 'Управление на Android';

  @override
  String get androidCouldNotStart => 'Android не може да стартира';

  @override
  String get androidNotificationReceived => 'Получено известие за Android';

  @override
  String get androidOnly => 'Само за Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Инсталаторът на пакети за Android не можа да бъде отворен.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Екран на Android — докоснете за докосване, плъзнете за плъзгане';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Отговаря на @mentions за проблеми и заявки за изтегляне';

  @override
  String get anyone => 'всеки';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Всеки в тази платформа може да изпраща съобщения до $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Всеки в тази платформа може да изпраща съобщения до $arg1 в $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Всеки, който може да достигне до този акаунт, може да говори с $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Всеки с връзката може да се присъедини, докато не изтече или не я отмените.';

  @override
  String get apiHttpsOrigin => 'API HTTPS произход';

  @override
  String get apiKey => 'API ключ';

  @override
  String get apiKey2 => 'api ключ';

  @override
  String get apiKey3 => 'API ключ';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api ключ anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter идентификационни данни';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API ключове и крайни точки за AI, търсене и доставчици на глас. Те ';

  @override
  String get apiRequest => 'API заявка';

  @override
  String get apiYourOwnServerASelf =>
      'API - ваш собствен сървър, самостоятелно хостван модел или друг ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Неуспешно изтегляне на APK с HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Изисква се име на приложението.';

  @override
  String get appUpdates => 'Актуализации на приложения';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Актуализациите на приложението не са конфигурирани за тази компилация.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Приложени $arg1 актуализации на кормилното управление в опашка към текущото изпълнение.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Приложени $arg1 актуализация(и) на кормилното управление.';
  }

  @override
  String get apply => 'Кандидатствайте';

  @override
  String get applyBehaviorNotes => 'Приложете бележки за поведение';

  @override
  String get applyCoreMemory => 'Приложете основна памет';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Искания за одобрение за чувствителни агентски инструменти';

  @override
  String get approvalRequired => 'Изисква се одобрение';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Одобрението остава във вашата удостоверена мобилна сесия и всеки код изтича автоматично след кратък прозорец.';

  @override
  String get approveLogin => 'Одобри влизане';

  @override
  String get approveQrLogin => 'Одобряване на QR влизане';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Одобрете това само ако сте започнали влизането на това устройство току-що.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Одобрено влизане за $arg1.';
  }

  @override
  String get approvedOnly => 'Само одобрени';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Одобрено сдвояване за $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Одобрени хора и групи';

  @override
  String get approvedPeopleOnly => 'Само одобрени хора';

  @override
  String get archive => 'Архив';

  @override
  String get archiveAgent => 'Архив агент?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Архив ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Архив $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Архивиране на избраните спомени?';

  @override
  String get areSharedByEveryAccountOn =>
      'се споделят от всеки акаунт на този сървър; акаунти все още могат ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M вход';
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
    return 'Необходим е $arg1 достъп';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 сметки';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 активен';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 добавен. Редактирайте го по всяко време, за да промените ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1“ и неговата хронология на изпълнение ще бъдат изтрити за постоянно. Всяко активно изпълнение ще бъде спряно. Файловете в работното пространство не се пипат.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Необходимо е одобрение $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 приложенията са активни';
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
    return '$arg1 ($arg2 активни инструменти)';
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
    return '$arg1 $arg2 при $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 променен';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 знаци';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Създаден $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [локален uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2, съответстващ на „$arg3“';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent Работно пространство';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 нови акаунти';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 работи · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 проби';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 управление на опашка';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 токени';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 токени';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 при $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 Б';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 стана администратор ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 байта';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 канал';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 знаци';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 изчистено.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 е конфигуриран';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 свързан. Изберете хранилища и хора под Кой може да изпраща съобщения.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 основни записи.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 създаде връзка за покана';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 десктоп';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 събития';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 неуспешно';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 не успя';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 се проваля';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 за $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 групи само с етикети';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'преди ${arg1}h';
  }

  @override
  String arg1HArg2M(Object? arg1, Object? arg2) {
    return '${arg1}h ${arg2}m';
  }

  @override
  String arg1HArg2Min(Object? arg1, Object? arg2) {
    return '$arg1 h $arg2 мин';
  }

  @override
  String arg1Helpers(Object? arg1) {
    return '$arg1 помощници';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 коефициент на попадение)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 е администратор, така че акаунтът не може да бъде изтрит ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 е блокиран на $arg2. Актуализирайте списъка за достъп, за да позволите отговори.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 е свързан и отговаря.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 вече не е администратор ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 не е наличен на $arg2 (липсва разрешение за изпълнение или зависимост).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 се присъедини под $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 съден от LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 key$arg2 конфигуриран';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Ключът $arg1 е премахнат.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 наляво';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 остави $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 свързан';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'преди ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Уверете се, че работи, след което опитайте отново.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 управлява този акаунт';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 мин';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 мин. $arg2 сек';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Готови модели $arg1';
  }

  @override
  String arg1More(Object? arg1) {
    return '+ още $arg1';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 още стъпки в хронологията на изпълнението';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 се премести от $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 мс';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 трябва да е крайно число.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 трябва да е http:// или https:// адрес.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 се нуждае от внимание';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Работно пространство $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 нови акаунти в последния $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · нови съобщения ръководят това бягане';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 нови писти';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 сега управлява този акаунт.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 от 4 разрешени разрешения. Файловете са ограничени до вашата папка NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 от $arg2 активиран';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 от $arg2 групи се присъединяват към обикновен чат';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 от моделите $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 от моделите $arg2 готови';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 от комплекта $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Разрешени са $arg1 от $arg2 инструменти';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Добре';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 на ден $arg2 при $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 отговаря само на хората, които добавите по-долу.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 отговаря само когато е маркиран';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 говори само с хора и групи, които одобрявате';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Добавени са $arg1 хора или групи';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 планиране';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 доставчици';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 готов';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 записи';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 URI за пренасочване';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 регистриран';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 отговори';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 отмени връзка за покана';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 бяга';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 работи · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 работи в последния $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 запазен.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 сек';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Избран $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Показан $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 остана тих';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 управление $arg2 на опашка';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · докоснете възел за проверка';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 стъпки';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 спря да управлява $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 токени';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 токени в последния $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 инструменти';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (недостъпна запазена отмяна)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return 'Използвано $arg1% · Оставащо $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 wants to talk with you.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 уеб';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '„$arg1“ ще бъде премахнат за постоянно.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 will manage this account';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 will not reply on this platform';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 няма да отговори на $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Съхранение на артефакт от потребителя';

  @override
  String get askAQuestionOrStartA => 'Ask a question or start a task...';

  @override
  String get askBeforeClosingToBackground => 'Ask before closing to background';

  @override
  String get askMe => 'питай ме';

  @override
  String get assignedAgent => 'Назначен агент';

  @override
  String get assignedAgent2 => 'Назначен агент';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Назначен агент: $arg1';
  }

  @override
  String get assigneeOptional => 'Assignee (optional)';

  @override
  String get assistant => 'Помощник';

  @override
  String get assistantKey131 => 'Асистент ключ 131';

  @override
  String get atLeast1 => 'Най-малко 1.';

  @override
  String get attachFiles => 'Прикачване на файлове';

  @override
  String attentionArg1(Object? arg1) {
    return 'Внимание $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'audit log admin grant revoke invite team history';

  @override
  String get authMethod => 'Метод за удостоверяване';

  @override
  String get authServerUrl => 'Auth Server URL';

  @override
  String get authentication => 'Удостоверяване';

  @override
  String get authenticationFailed => 'Authentication failed.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Удостоверяването все още предстои. Finish the browser flow and try again.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Authentication is still pending. Finish the browser flow and refresh.';

  @override
  String get authenticationTimedOut =>
      'Времето за изчакване на удостоверяването изтече.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Удостоверяването беше отменено преди завършване.';

  @override
  String get authenticatorApp => 'Приложение за удостоверяване';

  @override
  String get authenticatorCode => 'Код за удостоверяване';

  @override
  String get authorOptional => 'Автор (по избор)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Автоматично (първият доставчик с API ключ)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Автоматични маршрути до най-добрия наличен модел';

  @override
  String get automaticFast => 'Автоматично (бързо)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatic reads the room and normally holds back. Mention-only makes no decision call until directly addressed.';

  @override
  String get automaticReserved => 'Автоматичен, запазен';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatic rollback needs a retry from the setup screen.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatic selects a fast model through the normal model catalog.';

  @override
  String get automation => 'Автоматизация';

  @override
  String get available => 'Наличен';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Предлага се отново в $arg1';
  }

  @override
  String get availableAgainShortly => 'Наличен отново след малко';

  @override
  String get availableInTheDesktopAppFor =>
      'Available in the desktop app for macOS, Windows and Linux';

  @override
  String get availableToTheAgent => 'На разположение на агента';

  @override
  String get averageAllTime => 'Средно за всички времена';

  @override
  String get avgImp => 'Ср. имп.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Средно/изпълнение: $arg1 токени';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Avoid repeated characters and obvious sequences.';

  @override
  String get awaitingScan => 'Awaiting scan';

  @override
  String get back => 'Назад';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count in the background';
  }

  @override
  String get backgroundTasks => 'Background tasks';

  @override
  String get backOn => 'обратно на.';

  @override
  String get backToChat => 'Back to chat';

  @override
  String get backToFolder => 'Назад към папката';

  @override
  String get backToSignIn => 'Назад към влизане';

  @override
  String get backendChannel => 'Бекенд канал';

  @override
  String get backendOnThisComputer => 'Бекенд на този компютър';

  @override
  String get backendSync => 'Синхронизиране на задния край';

  @override
  String get backgroundLocationNeeded => 'Необходимо е фоново местоположение';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Background sync stays scheduled on Android';

  @override
  String get badState => 'Лошо състояние: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Base image and size of the QEMU virtual machines that run ';

  @override
  String get baseUrlOptional => 'Основен URL (по избор)';

  @override
  String get baseUrlTokenLocal => 'основен url токен локален';

  @override
  String get basicAuthentication => 'Основно удостоверяване';

  @override
  String get behaviorModules => 'Behavior Modules';

  @override
  String get behaviorNotes => 'бележки за поведението';

  @override
  String get beta => 'Бета';

  @override
  String get bitwardenCredentialBroker =>
      'Брокер на идентификационни данни на Bitwarden';

  @override
  String get bitwardenItem => 'Артикул Bitwarden';

  @override
  String get bitwardenServer => 'Bitwarden server';

  @override
  String get blankUsesCommon => 'Blank uses \"common\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank използва обратното извикване по подразбиране';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Празните стойности използват настройките по подразбиране на доставчика.';

  @override
  String get block => 'Блокирайте';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Blocked incoming message from $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Мост, съвместим с BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL адрес на сървъра на BlueBubbles';

  @override
  String get botToken => 'Бот токен';

  @override
  String get botTokenAndApprovedChats => 'Bot token and approved chats';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bot token and server/channel access';

  @override
  String get botTokenEventsApiAndChannel =>
      'Бот токен, API за събития и достъп до канала';

  @override
  String get botUserId => 'Потребителски идентификатор на бот';

  @override
  String get botUsername => 'Потребителско име на бот';

  @override
  String get brandName => 'Име на марката';

  @override
  String get braveSearch => 'Brave Search';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Bridge any provider that can post and receive webhook payloads.';

  @override
  String get bringYourOwnKey => 'bring your own key';

  @override
  String get bringYourOwnKey2 => 'Носете свой собствен ключ';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Browser, Linux desktop, files, terminal, and Python share one persistent cloud computer.';

  @override
  String get browserLogin => 'Вход в браузъра';

  @override
  String get browserScripting => 'Скриптове на браузъра';

  @override
  String get call => 'Обадете се';

  @override
  String get callAgent => 'Обадете се на агент';

  @override
  String get callUser => 'Повикване на потребител';

  @override
  String get calledByName => 'Наречен по име';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Може да делегира задачи на други агенти';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Може да делегира на $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Can receive delegated tasks';

  @override
  String get cancel => 'Отказ';

  @override
  String get cancelTask => 'Отмени задачата';

  @override
  String get cannotPreview => 'Не може да се визуализира';

  @override
  String get cannotReceiveDelegatedTasks => 'cannot receive delegated tasks';

  @override
  String get cannotRunYet => 'cannot run yet.';

  @override
  String get capturedThePage => 'Заснехте страницата';

  @override
  String get category => 'Категория';

  @override
  String chainArg1(Object? arg1) {
    return 'Верига: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Change setup mode';

  @override
  String get channel => 'Канал';

  @override
  String get channelAccessToken => 'Токен за достъп до канал';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Channel: $arg1$arg2 | Update Version: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Channel-scoped social memory';

  @override
  String get channels => 'Канали';

  @override
  String get chat => 'Чат';

  @override
  String get chatId => 'ID на чата';

  @override
  String get chatMode => 'Chat mode';

  @override
  String get chatModel => 'Модел на чат';

  @override
  String get checkAutomaticallyOnLaunch => 'Check automatically on launch';

  @override
  String get checkForMessagesEveryMs => 'Check for messages every (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Check for new messages automatically';

  @override
  String get checkNow => 'Проверете сега';

  @override
  String get checkYourEmailToConfirmYour =>
      'Проверете имейла си, за да потвърдите акаунта си в NeoAgent, преди да влезете.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Проверено $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Choose a category or search across all settings.';

  @override
  String get chooseAPerson => 'Изберете човек';

  @override
  String get chooseAProjectFolder => 'Изберете папка на проекта';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Изберете настройки по подразбиране за чат, агенти, резервно поведение и интелигентно маршрутизиране.';

  @override
  String get chooseGroups => 'Изберете групи';

  @override
  String get chooseHowMuchYouWantTo =>
      'Choose how much you want to configure now. Both options can be changed later.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Choose how this task should start. Manual runs only on Run Now. Графикът е базиран на времето. Интегрирането задейства пожар от свързани официални приложения.';

  @override
  String get chooseOneToGetStartedNow =>
      'Choose one to get started now. Можете да добавите още по-късно.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Choose the live model and voice in Settings.';

  @override
  String get chooseTheirGroup => 'Изберете тяхната група';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Изберете къде този човек да може да говори с $arg1. You can change this later under Who can message.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Изберете към кои групи $arg1 да се присъедини дори когато никой не го маркира. Тази платформа може да не различава етикетите от обикновените съобщения.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Изберете кои модели всеки акаунт на този сървър може да избере и ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Изберете с кого говори $arg1 и кога се присъединява към групови чатове.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Изберете кой може да достигне до $arg1, след което запазете промените си.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Изберете кой може да изпраща съобщения до агента с „Кой може да изпраща съобщения“ на картата WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Изберете своя модел\nпо подразбиране.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, файлове, текстов редактор и терминал са достъпни от работния плот на Linux.';

  @override
  String get claudeCode => 'Клод Код';

  @override
  String get clear => 'Изчисти';

  @override
  String get clearAll => 'Изчисти всички';

  @override
  String clearArg1(Object? arg1) {
    return 'Изчистване на $arg1?';
  }

  @override
  String get clearFilter => 'Изчистване на филтъра';

  @override
  String get clearFilters => 'Изчистване на филтрите';

  @override
  String get clearSearch => 'Изчистете търсенето';

  @override
  String get clearView => 'Ясен изглед';

  @override
  String get cliSession => 'CLI сесия';

  @override
  String get clickIsNotSupportedOnThis =>
      'кликването не се поддържа на тази платформа.';

  @override
  String get clickOnceToBeginCapturing => 'Click once to begin capturing';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Click, type, and interact with desktop apps.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Clicked at ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Щракна в браузъра';

  @override
  String get clientId => 'ID на клиента';

  @override
  String get clientSecret => 'Тайна на клиента';

  @override
  String get close => 'затвори';

  @override
  String get closeJ => 'Затваряне (⌘J)';

  @override
  String get closeTeachMode => 'Затворете режима на обучение';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Затварянето на прозореца може или да остави NeoAgent да работи във фонов режим с достъп до трея, или напълно да напусне средата за изпълнение на работния плот.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Cloud and self-hosted instances are supported. Локалните и частните мрежови URL адреси работят, когато NeoAgent може да ги достигне.';

  @override
  String get cloudComputer => 'Облачен компютър';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Cloud computer · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Настройките на облачния компютър са запазени. Restart the server to apply them.';

  @override
  String get cloudComputerVm => 'Облачен компютър (VM)';

  @override
  String get cloudComputers => 'Облачни компютри';

  @override
  String get codeHosting => 'Код хостинг';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Имена на канали, разделени със запетая, без #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Comma-separated, for example #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Разделени със запетая. Броят трябва да има всички от тях.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Command failed ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Необходима е команда.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Акумулаторът на изхода на командата не е активен.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Command output upload failed ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Изход на командата качване на пропуснати метаданни за артефакт.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Изходът на командата вече беше финализиран.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Команди и приложения';

  @override
  String get commandsRunInTheSamePersistent =>
      'Командите се изпълняват в същия постоянен компютър, използван от видимия работен плот.';

  @override
  String get communityChatops => 'Общност и ChatOps';

  @override
  String get completeSetup => 'Пълна настройка';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Завършете работния процес на работния плот.';

  @override
  String get completed => 'Завършено';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Напълно блокиран — агентът не може да използва тази категория.';

  @override
  String get computerShell => 'Обвивка на компютъра';

  @override
  String get computerUsedByThisSession => 'Компютър, използван от тази сесия';

  @override
  String get computerWorkspace => 'Работно пространство на компютъра';

  @override
  String get configurablePersonalWebhookBridge =>
      'Конфигурируем персонален мост за уеб кукичка';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Конфигурируемо реле или мост за уеб кукичка';

  @override
  String get configurableTalkWebhookBridge =>
      'Конфигурируем мост за уеб кукичка на Talk';

  @override
  String get configurableWebInboxBridge =>
      'Мост за конфигурируема уеб входяща кутия';

  @override
  String get configurableWebhookBridge => 'Конфигурируем мост за уеб кукичка';

  @override
  String get configurableWebhooks => 'Конфигурируеми уебкукички';

  @override
  String get configurationOrInTheEnvFile => 'Конфигурация или във файла .env.';

  @override
  String get configure => 'Конфигуриране';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configure workspace behavior and model defaults.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Конфигуриран $arg1';
  }

  @override
  String get confirmEmailChanges => 'Потвърдете промените в имейла';

  @override
  String get confirmNewSignUps => 'Потвърждаване на нови регистрации';

  @override
  String get confirmPassword => 'Потвърдете паролата';

  @override
  String get confirmPassword2 => 'Потвърдете паролата';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Потвърдете имейла си, преди да влезете. Проверете служебното имейл съобщение от NeoAgent.';

  @override
  String get connect => 'Свържете се';

  @override
  String get connectAMessagingPlatform => 'Свържете платформа\nза съобщения.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Свържете публична крайна точка на HTTPS Home Assistant с Long-Lived Access Token. Локалните, loopback и частните мрежови адреси се блокират от сървъра.';

  @override
  String get connectAccount => 'Свързване на акаунт';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Свържете акаунтите на приложения поотделно, така че AI да може да използва правилния акаунт за всяка официална интеграция.';

  @override
  String connectArg1(Object? arg1) {
    return 'Свържете $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Connect as many accounts as you want. Each app can use a different account.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Свържете канали, изберете с кого говори $arg1 и гледайте скорошна активност.';
  }

  @override
  String get connectInstance => 'Свържете екземпляр';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Първо свържете тази интеграция, за да изберете акаунт.';

  @override
  String get connectToThisServer => 'Свържете се с този сървър';

  @override
  String get connectWhatsapp => 'Свържете WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Свържете своя екземпляр на Nextcloud, включително самостоятелно хоствани сървъри. NeoAgent отваря собствената страница за вход на Nextcloud, за да можете да влезете с парола, SSO или 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Connect your self-hosted NeoRecall server. NeoAgent получава достъп само за четене до локално търсене, спомени и доказателства за препис, след като одобрите екрана на OAuth.';

  @override
  String get connected => 'Свързан';

  @override
  String get connectedAccount => 'Свързан акаунт';

  @override
  String connectedArg1(Object? arg1) {
    return 'Connected $arg1';
  }

  @override
  String get connectedInstance => 'Свързан екземпляр';

  @override
  String get connectedNeorecallUser => 'Свързан потребител на NeoRecall';

  @override
  String get connectedNextcloudUser => 'Свързан потребител на Nextcloud';

  @override
  String get connectedServer => 'Свързан сървър';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Connecting to the live voice model...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Връзка #$arg1';
  }

  @override
  String get connectionId => 'ID на връзката';

  @override
  String get connectionLooksGood => 'Connection looks good.';

  @override
  String get connectionMethod => 'Метод на свързване';

  @override
  String get containsTextOptional => 'Съдържа текст (по избор)';

  @override
  String get content => 'Съдържание';

  @override
  String get contentSecurityPolicy => 'политика за сигурност на съдържанието';

  @override
  String get continue2 => 'Продължи';

  @override
  String get continueFullSetup => 'Продължете пълната настройка';

  @override
  String get continueRun => 'Continue run';

  @override
  String get continueToSetup => 'Continue to setup';

  @override
  String get controlSurface => 'CONTROL SURFACE';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Контролира достъпа до $arg1 инструменти.';
  }

  @override
  String get conversation => 'Разговор';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID на разговор, използван, когато този агент започне чат.';

  @override
  String get cookieSetup => 'Cookie setup';

  @override
  String get cookiesNotConfigured => 'Cookies not configured';

  @override
  String get copiedAsCsv => 'Copied as CSV';

  @override
  String get copiedDebugInfo => 'Copied debug info';

  @override
  String get copiedExportForTheLast5 => 'Copied export for the last 5 messages';

  @override
  String get copiedFullPrompt => 'Copied full prompt';

  @override
  String get copiedLogs => 'Copied logs';

  @override
  String get copiedRunId => 'Copied run ID';

  @override
  String get copy => 'копие';

  @override
  String get copyAll => 'Copy all';

  @override
  String get copyCodes => 'Copy codes';

  @override
  String get copyCsv => 'Копирайте CSV';

  @override
  String get copyDebugInfo =>
      'Копиране на информация за отстраняване на грешки';

  @override
  String get copyLink => 'Копиране на връзката';

  @override
  String get copyLogs => 'Copy logs';

  @override
  String get copyPrompt => 'Подкана за копиране';

  @override
  String get copyResponse => 'Копиране на отговора';

  @override
  String get copyRunId => 'Копирайте ID на изпълнение';

  @override
  String get copyWebhookUrl => 'Копирайте URL адреса на уеб кукичката';

  @override
  String get core => 'Ядро';

  @override
  String get coreMemory => 'основна памет';

  @override
  String get coreServicesThisServerDependsOn =>
      'Core services this server depends on.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https public url origins';

  @override
  String get couldHelp => 'Може да помогне';

  @override
  String get couldNotApproveQrLogin => 'QR влизането не може да бъде одобрено.';

  @override
  String get couldNotApproveQrPairing => 'Could not approve QR pairing.';

  @override
  String get couldNotConnect => 'Не може да се свърже.';

  @override
  String get couldNotCreateBinding => 'Не можа да се създаде обвързване.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Не можах да изтрия вашия акаунт: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Не можа да се прекъсне връзката с Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Could not disconnect Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Не можа да се прекъсне връзката с NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Не можа да се прекъсне връзката с Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Could not disconnect Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Не можах да експортирам вашите данни: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Решенията не можаха да се заредят';

  @override
  String get couldNotLoadUsageData =>
      'Данните за употребата не можаха да се заредят.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Настройките на Linux не могат да се отворят автоматично.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Страницата за свързване на доставчика не можа да се отвори.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Страницата за вход на доставчика не можа да се отвори.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Could not open the release asset.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Trello не може да се отвори във вашия браузър.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Не можа да се отвори изтеглянето на файла на работното пространство.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Could not read the Android app package.';

  @override
  String get couldNotReadTheApk => 'Не можах да прочета APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Ключът не можа да бъде премахнат: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Агентът не можа да бъде запазен.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Не можа да се запази настройката на Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Could not save Home Assistant setup.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Не можа да се запази настройката на NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup => 'Could not save Nextcloud setup.';

  @override
  String get couldNotSaveTrelloSetup => 'Could not save Trello setup.';

  @override
  String get couldNotSendConfirmationEmail =>
      'could not send confirmation email';

  @override
  String get couldNotStart => 'Не може да започне';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Създавайте';

  @override
  String get createAPasswordFirstToChange =>
      'Първо създайте парола, за да промените имейла на акаунта си.';

  @override
  String get createAPasswordOrLinkAnother =>
      'създайте парола или свържете друг доставчик, преди да премахнете този метод за влизане';

  @override
  String get createATaskWhileThisAgent =>
      'Създайте задача, докато този агент е избран.';

  @override
  String get createLink => 'Създаване на връзка';

  @override
  String get createOrModifyFilesInYour =>
      'Create or modify files in your workspace.';

  @override
  String get createPassword => 'Създайте парола';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Създавайте специализирани ботове с отделна памет, настройки, инструменти и присвояване на акаунти.';

  @override
  String get createTheFirstAccount => 'Създайте първия акаунт';

  @override
  String get createUpdateOrDeleteSkills => 'Create, update, or delete skills.';

  @override
  String get creatingYourSkill => 'Създаване на вашето умение...';

  @override
  String get credentialBindings => 'Обвързване на идентификационни данни';

  @override
  String get credentialUse => 'Използване на идентификационни данни';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Базирани на Cron повтарящи се изпълнявания и еднократно изпълнение във време.';

  @override
  String get cronExpression => 'Cron израз';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter runs the query.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + интервал';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Текущ имейл: $arg1';
  }

  @override
  String get currentPassword => 'Текуща парола';

  @override
  String get currentPasswordIsIncorrect => 'current password is incorrect';

  @override
  String get currentTwoStepLoginCode => 'Current two-step login code';

  @override
  String get customAccess => 'Custom access';

  @override
  String get customCron => 'Персонализиран Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron must have 5 fields.';

  @override
  String get customEndpoint => 'персонализирана крайна точка';

  @override
  String get customField => 'Персонализирано поле';

  @override
  String get customHeader => 'Custom header';

  @override
  String get customHeadersJson => 'Персонализирани заглавки (JSON)';

  @override
  String get customOpenaiCompatible => 'Персонализиран OpenAI-съвместим';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Custom OpenAI-compatible endpoint';

  @override
  String get customOutgoingUrl => 'Персонализиран изходящ URL адрес';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Ежедневно';

  @override
  String get dailyRecap => 'Daily recap';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'database query select csv templates';

  @override
  String dayArg1(Object? arg1) {
    return 'Ден $arg1';
  }

  @override
  String get dayOfMonth => 'Ден от месеца';

  @override
  String get decideWhichToolsYourAgentMay =>
      'решите кои инструменти може да използва вашият агент. Те виждат вашето име и ';

  @override
  String get decisionHigherUpTheChainWins =>
      'решение по-високо във веригата печели и показва заключване с ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Решенията се показват тук, когато $arg1 чете одобрени $arg2 групи. Запазват се само последните 30 и те се нулират, когато сървърът се рестартира.';
  }

  @override
  String get decline => 'Откажи';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'deep run · step $arg1';
  }

  @override
  String get deepgramKey => 'Ключ за Deepgram';

  @override
  String get default2 => 'По подразбиране';

  @override
  String get default3 => 'DEFAULT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Default ($arg1)';
  }

  @override
  String get defaultConversation => 'Default conversation';

  @override
  String get defaultForNewGroups => 'По подразбиране за нови групи';

  @override
  String get defaultGroupParticipation => 'Default group participation';

  @override
  String get defaultNeoagentWorkspace => 'Default NeoAgent Workspace';

  @override
  String get defaultOpenai => 'Default (OpenAI)';

  @override
  String get defaultRateLimits => 'Default rate limits';

  @override
  String get defaultRateLimitsSaved => 'Default rate limits saved.';

  @override
  String get defaultRecommended => 'Default (recommended)';

  @override
  String get defaultRouting => 'Default Routing';

  @override
  String get defaultSpace => 'Пространство по подразбиране';

  @override
  String get delete => 'Изтриване';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountPermanently => 'Изтриване на акаунта за постоянно?';

  @override
  String get deleteAnAccount => 'Delete an account';

  @override
  String deleteArg1(Object? arg1) {
    return 'Delete @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Delete ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Изтриване на $arg1 $arg2 за постоянно?';
  }

  @override
  String get deleteBinding => 'Изтриване на обвързването';

  @override
  String get deleteCoreMemoryEntry => 'Delete core memory entry?';

  @override
  String get deleteForever => 'Изтрий завинаги';

  @override
  String get deleteMcpServer => 'Изтриване на MCP сървър?';

  @override
  String get deleteMemory => 'Изтриване на паметта?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Изтриването изтрива за постоянно акаунт и всички данни в него ';

  @override
  String get deleteRun => 'Delete run?';

  @override
  String get deleteRun2 => 'Изтриване на изпълнение';

  @override
  String get deleteSelectedMemories => 'Изтриване на избраните спомени?';

  @override
  String get deleteSession => 'Изтриване на сесия?';

  @override
  String get deleteSkill => 'Изтриване на умението?';

  @override
  String get deleteTask => 'Изтриване на задача?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Изтрит \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Изтрити @$arg1 и всички техни данни.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Изтриването премахва всички ваши разговори, спомени, файлове, задачи и ';

  @override
  String get deliverableArtifactProduced => 'Произведен артефакт за доставка';

  @override
  String get deliverableCompleted => 'Доставката е завършена';

  @override
  String get deliverableExecutionStarted => 'Изпълнението за доставка започна';

  @override
  String get deliverableSelected => 'Избран продукт за доставка';

  @override
  String get deliverableValidationFailed =>
      'Проверката на доставката е неуспешна';

  @override
  String get deliverableValidationStarted =>
      'Започна валидирането на доставката';

  @override
  String get deny => 'Отказвам';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Опишете резултата, след което го демонстрирайте на работния плот';

  @override
  String get describeWhatToBuildOrChange =>
      'Опишете какво да построите или промените...';

  @override
  String get description => 'Описание';

  @override
  String get desktopApp => 'Настолно приложение';

  @override
  String get desktopAppControlsAvailable =>
      'Налични контроли за настолни приложения';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Заснемането на работния плот не е налично на тази платформа.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Качването на изход от команди на работния плот е анулирано.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Командата за придружител на работния плот беше анулирана.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Времето за изчакване на придружаващата връзка на работния плот изтече.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Времето за изчакване на придружаващото ръкостискане на работния плот изтече.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Desktop companion is not available here.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Desktop companion is paused locally.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Неуспешно обработване на придружаващото съобщение на работния плот: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Настройките за разрешение за компаньон на работния плот не са достъпни в мрежата.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Настройките за разрешения за компаньон на работния плот не са налични на тази платформа.';

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
  String get destinationId => 'ID на местоназначението';

  @override
  String get deviceAccess => 'Device access';

  @override
  String get deviceSettings => 'Настройки на устройството';

  @override
  String get devices => 'устройства';

  @override
  String get diagnosticsSaved => 'Diagnostics saved.';

  @override
  String get directBluebubblesImessageBridge =>
      'Direct BlueBubbles iMessage bridge';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Direct messages remain responsive. Позволените групи използват режима на участие по-долу.';

  @override
  String get directoryDoesNotExist => 'Directory does not exist.';

  @override
  String get disable2fa => 'Disable 2FA';

  @override
  String get disableAll => 'Disable all';

  @override
  String get discard => 'Изхвърлете';

  @override
  String get disconnect => 'Прекъснете връзката';

  @override
  String get disconnectHomeAssistant => 'Disconnect Home Assistant?';

  @override
  String get disconnectNeorecall => 'Прекъсване на връзката с NeoRecall?';

  @override
  String get disconnectNextcloud => 'Прекъсване на връзката с Nextcloud?';

  @override
  String get disconnectPlatform => 'Disconnect platform';

  @override
  String get disconnectTrello => 'Прекъсване на връзката с Trello?';

  @override
  String get discoveryFailed => 'Discovery failed';

  @override
  String get dismiss => 'Отхвърляне';

  @override
  String get displayIdIsRequired => 'Изисква се ID на дисплея.';

  @override
  String get displayName => 'Екранно име';

  @override
  String get displayNameMustBe64Characters =>
      'Display name must be 64 characters or fewer.';

  @override
  String get displayNameSaved => 'Екранното име е запазено.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Do not include your username or email.';

  @override
  String get done => 'Готово';

  @override
  String get downloadACopyOfYourData =>
      'Download a copy of your data. Admin accounts can’t delete ';

  @override
  String get downloadACopyOfYourData2 =>
      'Изтеглете копие на данните си или изтрийте завинаги акаунта си. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Изтеглете $arg1';
  }

  @override
  String get downloadUpdate => 'Изтеглете актуализация';

  @override
  String get downloadingTheNeoagentBackend =>
      'Downloading the NeoAgent backend';

  @override
  String get draft => 'Чернова';

  @override
  String get dragIsNotSupportedOnThis =>
      'drag is not supported on this platform.';

  @override
  String get draggedOnTheScreen => 'Dragged on the screen';

  @override
  String get dropAnApkOrApkBundle =>
      'Пуснете APK или APK пакет тук, за да го инсталирате';

  @override
  String get dropApkOrApksHere => 'Drop APK or .apks Here';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Устойчиви инструкции за глас и стил на взаимодействие. Правилата за безопасност и изпълнение все още имат приоритет.';

  @override
  String get eGAlexSLaptop => 'напр. Лаптопът на Алекс';

  @override
  String get eGMyLocalServer => 'напр. Моят локален сървър';

  @override
  String get edit => 'Редактиране';

  @override
  String get editAgent => 'Edit Agent';

  @override
  String get editCoreMemoryEntry => 'Edit Core Memory Entry';

  @override
  String get editInstructions => 'Редактирайте инструкциите';

  @override
  String get editMcpServer => 'Редактиране на MCP сървър';

  @override
  String get editTask => 'Редактиране на задача';

  @override
  String editedArg1(Object? arg1) {
    return 'Редактирано $arg1';
  }

  @override
  String get email => 'Имейл';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Изпратете имейл на собствениците на акаунти за влизания, които изглеждат необичайни.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Изпращайте имейл на собствениците на акаунти, когато данните за акаунта им се променят.';

  @override
  String get emailCode => 'Имейл код';

  @override
  String get emailConfirmationRequired => 'изисква се имейл потвърждение';

  @override
  String get emailIsAlreadyInUse => 'email is already in use';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Имейлът е запазен. Ако се изисква потвърждение, проверете новия адрес за връзка за потвърждение на NeoAgent.';

  @override
  String get emailSettingsSaved => 'Настройките за имейл са запазени.';

  @override
  String get emailUnverified => 'Email unverified';

  @override
  String get empty => 'празна';

  @override
  String get emptyFile => 'Празен файл';

  @override
  String get emptyFolder => 'Празна папка';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty uses the server default ($arg1).';
  }

  @override
  String get enable2fa => 'Активирайте 2FA';

  @override
  String get enableAll => 'Enable all';

  @override
  String get enableBehaviorModules => 'Активиране на модули за поведение';

  @override
  String get enableOrDisableModels => 'Активиране или деактивиране на модели';

  @override
  String get enabled => 'Активирано';

  @override
  String get encryptedPrivateToYourAccount =>
      'Encrypted, private to your account';

  @override
  String get end => 'Край';

  @override
  String get endCall => 'End call';

  @override
  String get endVoiceCall => 'Прекратяване на гласовото повикване?';

  @override
  String get endpoint => 'Крайна точка';

  @override
  String get enterAPassword => 'Въведете парола.';

  @override
  String get enterAUsername => 'Въведете потребителско име.';

  @override
  String get enterAValidEmailAddress => 'Enter a valid email address.';

  @override
  String get enterAnAddressManually => 'Enter an address manually';

  @override
  String get enterAnApiKeyFirst => 'Първо въведете API ключ.';

  @override
  String get enterInviteLink => 'Въведете връзка за покана';

  @override
  String get enterTheAddressOfANeoagent =>
      'Въведете адреса на сървър на NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Въведете данните, които $arg1 ви даде, за да може $arg2 да изпраща и получава съобщения.';
  }

  @override
  String get enterYour2faOrRecoveryCode => 'Enter your 2FA or recovery code.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Enter your current password to change it.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Въведете текущата си парола, за да запазите промените в имейла.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Enter your NeoAgent account details.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Enter your username or account email. NeoAgent ще изпрати връзка за нулиране, ако може да съответства на акаунта.';

  @override
  String get enterYourUsernameOrEmail => 'Enter your username or email.';

  @override
  String entityArg1(Object? arg1) {
    return 'Обект: $arg1';
  }

  @override
  String get environment => 'Околна среда';

  @override
  String get error => 'Грешка';

  @override
  String errorArg1(Object? arg1) {
    return '\nгрешка: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Грешки от последния дневник, групирани по съобщение.';

  @override
  String get errorsProblemsFailures => 'грешки проблеми неуспехи';

  @override
  String get eventTypesCommaSeparated =>
      'Типове събития (разделени със запетая)';

  @override
  String get every15Minutes => 'На всеки 15 минути';

  @override
  String get every30Minutes => 'На всеки 30 минути';

  @override
  String get everyAccountOnThisServerLoses =>
      'Всеки акаунт на този сървър губи този споделен ключ. Сметки ';

  @override
  String get everyAccountOnThisServerUses =>
      'Всеки акаунт на този сървър използва този адрес за ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Всяка активна сесия за този акаунт приключва. Те могат да влязат ';

  @override
  String get everyDay0800 => 'Всеки ден · 08:00ч';

  @override
  String get everyDay2000 => 'Всеки ден · 20:00ч';

  @override
  String get everyHour => 'Всеки час';

  @override
  String get everyRunOnThisServerAll =>
      'Всяко стартиране на този сървър, през цялото време.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Всеки чувствителен инструмент изисква одобрение, всеки път.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Всеки инструмент работи без да пита, с изключение на този, който е човекът ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Всеки в тези групи, канали или стаи може да говори със $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Всички в тази група';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Всичко, което $arg1 е изключил за вашия агент, идва ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Everything else is turned off.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Всичко е достъпно от работния плот.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Всичко, което агентът може да използва: официални интеграции, MCP сървъри и умения.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Everything you turned off for $arg1 comes back ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Точните уеб източници, разрешени за отправяне на заявки от различни източници, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Execute JavaScript inside your browser session.';

  @override
  String get execution => 'Изпълнение';

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
    return 'Изтича $arg1';
  }

  @override
  String get explainThisProject => 'Explain this project';

  @override
  String exploredArg1(Object? arg1) {
    return 'Explored $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Изследван $arg1$arg2';
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
  String get exportMyData => 'Експортиране на моите данни';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Стартирането на външен браузър е неуспешно с изходен код $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Стартирането на външен браузър не се поддържа на тази платформа.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Времето за изчакване при стартиране на външен браузър изтече.';

  @override
  String get externalMcpTools => 'Външни и MCP инструменти';

  @override
  String get extraButtons => 'Допълнителни бутони';

  @override
  String get extractingTheNeoagentRuntime =>
      'Извличане на времето за изпълнение на NeoAgent';

  @override
  String get failed => 'Failed';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Неуспешно свързване: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Неуспешно свързване на $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Неуспешно изтриване на „$arg1“: $arg2';
  }

  @override
  String get failedToFetch => 'failed to fetch';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Неуспешно генериране на подкана: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Неуспешно стартиране на външен браузър чрез url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Failed to launch OAuth flow.';

  @override
  String get failedToLoadPolicies => 'Failed to load policies';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Failed to save: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Неуспешно запазване на MCP сървъра.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Неуспешно запазване на избора: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Неуспешно изпращане на известие до бекенда: $arg1';
  }

  @override
  String get fair => 'Справедлива';

  @override
  String get fasterReplies => 'Faster replies';

  @override
  String get fewerModelCalls => 'По-малко обаждания на модели';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'празно поле за възстановяване на вградената настройка по подразбиране.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Файлът надвишава ограничението за редактор от 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Файлът надвишава поддържания лимит за размер.';

  @override
  String get fileWrites => 'File Writes';

  @override
  String get filename => 'Име на файл';

  @override
  String get files => 'файлове';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Файловете, които NeoAgent пише или редактира в тази сесия, се показват тук.';

  @override
  String get filesSavedByAllUsers => 'Files saved by all users';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Попълвайте одобрени влизания или удостоверявайте заявки, без да показвате тайни на AI.';

  @override
  String get finalResponse => 'Final Response';

  @override
  String get findAPlatform => 'Find a platform';

  @override
  String get findAndFixABug => 'Намерете и поправете грешка';

  @override
  String get findRecentChats => 'Намерете скорошни чатове';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Намиране на правилното време за изпълнение на NeoAgent';

  @override
  String get finish => 'Завършете';

  @override
  String get finishAtTheScheduledTime => 'Завършете в определеното време';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Завършете влизането в $arg1 във вашия браузър, след което се свържете отново.';
  }

  @override
  String get flowGraph => 'Графика на потока';

  @override
  String get flutterApp => 'Приложение Flutter';

  @override
  String get focusedExecutionProfile => 'Фокусиран профил на изпълнение';

  @override
  String get folderIdOptional => 'ID на папка (по избор)';

  @override
  String get folderUnavailable => 'Папката е недостъпна';

  @override
  String get forExampleHttpsMatrixOrg => 'Например https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'За хоствани или разширени мрежови настройки';

  @override
  String get forLinksInEmailsBlankUses =>
      'За връзки в имейли. Празното използва публичния URL адрес на сървъра.';

  @override
  String get forgotPassword => 'Забравена парола?';

  @override
  String get frameUnavailable => 'Рамката не е налична';

  @override
  String freshnessArg1(Object? arg1) {
    return 'свежест: $arg1';
  }

  @override
  String get fridays1700 => 'Петък · 17:00ч';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'От BotFather, след като създадете бота.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Отсега нататък $arg1 решава кои инструменти може да използва вашият агент. Те ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'От портала за разработчици на Discord, под вашия бот.';

  @override
  String get fromTheLineDevelopersConsole => 'От LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot => 'От Matrix клиент или бот акаунт.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'От twitchapps.com/tmi или вашето приложение за разработчици на Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Пълна подкана';

  @override
  String get fullSetup => 'Пълна настройка';

  @override
  String get general => 'генерал';

  @override
  String get generalSettings => 'Общи настройки';

  @override
  String get generalSettingsSaved => 'Общите настройки са запазени.';

  @override
  String get generateAPromptForAnotherAi =>
      'Генерирайте подкана за друг AI, поставете отговора тук, за да импортирате спомени.';

  @override
  String get generatePrompt => 'Генериране на подкана';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Грешка при проследяване на геозона: $arg1';
  }

  @override
  String get getInspired => 'Вдъхновете се';

  @override
  String get githubCopilot => 'Копилот на GitHub';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot и OpenAI Codex';

  @override
  String get githubIssueOpened => 'Проблемът с GitHub е отворен';

  @override
  String get neorecallMemoryCreated => 'NeoRecall памет е създадена';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Проверката на версията на GitHub е неуспешна с HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Полезният товар на изданието на GitHub не беше списък с версии.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Потребителско име на GitHub, което е отворило проблема';

  @override
  String get globalSecurityMode => 'Режим на глобална защита';

  @override
  String get gmailMessageReceived => 'Съобщението в Gmail е получено';

  @override
  String get good => 'добре';

  @override
  String get goodAfternoon => 'добър ден';

  @override
  String get goodEvening => 'Добър вечер';

  @override
  String get goodMorning => 'добро утро';

  @override
  String get goodPasswordALittleMoreLength =>
      'Добра парола. Малко повече дължина го прави по-здрав.';

  @override
  String get googleChat => 'Чат в Google';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live използва вашия OpenAI API ключ, Gemini Live вашия Google AI ключ. Промените важат за следващото обаждане.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Предоставете разрешения на Health Connect преди синхронизиране.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Група, канал или стая';

  @override
  String get groupType => 'Групов тип';

  @override
  String get groupsAndChannels => 'Групи и канали';

  @override
  String groupsArg1(Object? arg1) {
    return 'Групи: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Групите, които $arg1 все още не е виждал, ще последват това.';
  }

  @override
  String get handlesDirectTasksItself => 'Сам се справя с преките задачи';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Без ръце (говорете свободно, прекъсвайте по всяко време)';

  @override
  String get headerName => 'Име на заглавката';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Заглавия по темите, които ви интересуват, филтрирани за сигнал.';

  @override
  String get health => 'здраве';

  @override
  String get healthChecks => 'Здравни проверки';

  @override
  String get healthConnect => 'здравна връзка';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect не е наличен на това устройство.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Статус на синхронизиране на Health Connect и съхранени показатели на бекенда.';

  @override
  String get healthStatusIsUnavailable => 'Здравният статус е недостъпен.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Здравното синхронизиране е налично само за Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Сърце $arg1 записи';
  }

  @override
  String get heldBack => 'Задържано';

  @override
  String get helper => 'Помощник';

  @override
  String helperArg1(Object? arg1) {
    return 'Помощник: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'тук Първо отменете администратора с `neoagent admin revoke $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'По-високите стойности правят NeoAgent по-селективен в групите.';

  @override
  String get highlyRecommended => 'Силно препоръчително';

  @override
  String get holdButton131ForTheAssistant => 'Задръжте бутон 131 за асистента.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Задръжте Ctrl+Shift+Space, за да говорите';

  @override
  String get holdToTalk => 'Задръжте, за да говорите.';

  @override
  String get holdToTalk2 => 'Задръжте, за да говорите';

  @override
  String get home => 'Начало';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Изисква се токен за дълготраен достъп на Home Assistant.';

  @override
  String get homeAssistantSetup => 'Настройка на домашен асистент';

  @override
  String get homeAssistantUrl => 'URL адрес на домашен асистент';

  @override
  String get homeAssistantUrlIsRequired =>
      'Изисква се URL адрес на Home Assistant.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Homeserver токен с анкета на стая';

  @override
  String get homeserverUrl => 'URL адрес на домашния сървър';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'хоствана услуга). Вашите ключове са криптирани и могат да се използват само от ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Име на хост на IRC мрежата, например irc.libera.chat';

  @override
  String get hourly => 'Почасово';

  @override
  String get hourlyInboxCheck => 'Ежечасова проверка на входящата кутия';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Колко време остават валидни връзките за потвърждение.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Колко често този агент търси съобщения за нови стаи.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Колко често този агент търси нови съобщения от Signal.';

  @override
  String get howTeamsWork => 'Как работят екипите';

  @override
  String get howThisServerIsReachedPlus =>
      'Как се достига до този сървър, плюс превключвания за целия сървър.';

  @override
  String get httpsSessionCookie => 'https сесийна бисквитка';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Не можах да изпълня тази заявка в момента. Моля, опитайте отново след малко.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'празен ход';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Ако $arg1 поиска URL адрес за уеб кукичка, поставете го, за да могат съобщенията да достигат до $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Ако този акаунт има потвърден имейл, NeoAgent ще изпрати връзка за повторно задаване на парола.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Ако услугата изисква токен при изходящи заявки.';

  @override
  String get ignoreGroups => 'Игнориране на групи';

  @override
  String get ignoreThisChat => 'Игнорирайте този чат';

  @override
  String get ignoredChannels => 'Игнорирани канали';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Игнорирано неправилно формирано придружаващо съобщение на работния плот: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Имп $arg1';
  }

  @override
  String get implementThePlanAbove => 'Приложете горния план.';

  @override
  String get implementThisPlan => 'Приложете този план';

  @override
  String get implicitTls => 'Неявен TLS';

  @override
  String get import => 'Импортиране';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Неуспешно импортиране: $arg1';
  }

  @override
  String get importFromComputer => 'Импортиране от компютър';

  @override
  String get importMemoryTransfer => 'Импортиране на прехвърляне на памет?';

  @override
  String get importance => 'Важност';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Импортирани $arg1 памети, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'В екипа на @$arg1';
  }

  @override
  String get inBackground => 'фон';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Входящите и изходящите канални съобщения ще се показват тук.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Входящи гласови повиквания в приложението от NeoAgent';

  @override
  String get incomingMessages => 'Входящи съобщения';

  @override
  String get incomingNeoagentCall => 'Входящо обаждане на NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'ВХОДЯЩО ОБАЖДАНЕ НА НЕОАГЕНТ';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Поддръжка на входящ webhook и изходящо обратно повикване';

  @override
  String get incorporatingSteering => 'Включващ кормилно управление';

  @override
  String get input => 'Вход';

  @override
  String get inputMode => 'Режим на въвеждане';

  @override
  String get insertATemplate => 'Поставете шаблон';

  @override
  String get install => 'Инсталирайте';

  @override
  String get installASignedSelfContainedRuntime =>
      'Инсталирайте подписана, самостоятелна среда за изпълнение. Не се изискват команди Node.js, npm, Git и терминал.';

  @override
  String get installApk => 'Инсталирайте APK';

  @override
  String get installApkBundle => 'Инсталирайте APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Инсталирайте APK - щракнете или пуснете .apk файл';

  @override
  String get installNeoagent => 'Инсталирайте NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Инсталирайте NeoAgent на този компютър без терминал или се свържете с такъв, който вече работи.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Инсталирайте нови версии и изберете кой канал следва този сървър.';

  @override
  String get installTheBackend => 'Инсталирайте бекенда';

  @override
  String get installTheCoreWithExtraOptional =>
      'Инсталирайте ядрото с допълнителна опционална настройка. Ключовете за доставчик на изкуствен интелект се добавят след това, същото като Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Инсталирайте защитеното ядро, след което създайте своя акаунт. След това добавете ключове за доставчик на AI.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Инсталиран: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Инсталиран: $arg1 • Последна проверка: $arg2';
  }

  @override
  String get instructions => 'Инструкции';

  @override
  String get integration => 'Интеграция';

  @override
  String get integrationConnections => 'Интеграционни връзки';

  @override
  String get integrationSettingsSaved =>
      'Настройките за интегриране са запазени.';

  @override
  String get integrations => 'Интеграции';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'интеграции/oauth/обратно повикване и регистрирайте същото ';

  @override
  String get interruptAi => 'Прекъснете AI';

  @override
  String get invalid2fa => 'невалиден 2fa';

  @override
  String get invalidArgumentS => 'Невалиден аргумент(и): ';

  @override
  String get invalidCredentials => 'невалидни идентификационни данни';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Невалиден манифест за изпълнение на NeoAgent.';

  @override
  String get inviteLink => 'Връзка за покана';

  @override
  String get inviteLinkReady => 'Връзката за покана е готова';

  @override
  String get inviteLinks => 'Връзки за покани';

  @override
  String get iphoneApp => 'приложение за iPhone';

  @override
  String get issues => 'Проблеми';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Проблемите се появяват, след като регистрационният файл се зареди.';

  @override
  String get itCanTBeUndone => 'Не може да се отмени.';

  @override
  String get itMayHaveBeenDeleted => 'Може да е изтрит.';

  @override
  String get javaRuntime => 'време за изпълнение на java';

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
    return 'Присъедини се към $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Присъединил се през последните 7 дни';

  @override
  String get joiningATeam => 'Присъединяване към екип';

  @override
  String get joiningIsOffHere => 'Присъединяването е изключено тук';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON поле, което съдържа текста на съобщението. Обикновено текст.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON поле, което идентифицира за кого е съобщението.';

  @override
  String get jumpToLatest => 'Преминете към най-новото';

  @override
  String get justNow => 'точно сега';

  @override
  String get keepNeoagentRunning => 'НеоАгент да продължи да работи?';

  @override
  String get keepRunning => 'Продължавайте да бягате';

  @override
  String get keepTaskRunning => 'Продължете да изпълнявате задачата';

  @override
  String get keepTheVaultAvailable => 'Дръжте трезора на разположение';

  @override
  String get keepThisLauncherUpToDate => 'Поддържайте този стартер актуален.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Дръжте този панел отворен, докато платформата потвърди връзката.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Дръжте компютъра на тази сесия видим';

  @override
  String get keepTrackOfYourAiUsage =>
      'Следете използването на AI. Ограниченията се прилагат, за да се гарантира справедливо използване в цялата платформа.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Продължете да използвате приложенията си нормално. NeoAgent работи на същия екран и пита, когато има нужда от нов достъп.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Поддържане на това устройство свързано';

  @override
  String get key => 'Ключ';

  @override
  String get keyIsRequired => 'Изисква се ключ.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Двойки ключ-стойност, които се запазват в разговорите.';

  @override
  String get knowledgeGraph => 'Графика на знанието';

  @override
  String get knowledgeView => 'Изглед на знания';

  @override
  String get labelOnlyYouSeeIt => 'Етикет (само вие го виждате)';

  @override
  String get labelsOptional => 'Етикети (по избор)';

  @override
  String get last24Hours => 'Последни 24 часа';

  @override
  String get last7Days => 'Последните 7 дни';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Последните 7 дни: $arg1 токени в $arg2 се изпълнява';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Последно $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Последно: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Последна непразна синхронизация · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Последно изпълнение: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Последно видян $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Последно влизане $arg1';
  }

  @override
  String get lastSyncSummary => 'Резюме на последното синхронизиране';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Последно използвано: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Последният прозорец приключи $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'по-късно стартиране също е изключено.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Последно изпълнение · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Стартирането на настолни приложения не се поддържа на тази платформа.';

  @override
  String get learnRoomNorms => 'Научете нормите за стаята';

  @override
  String get leave => 'тръгвай';

  @override
  String get leaveARedirectUriBlankTo =>
      'Оставете URI за пренасочване празен, за да използвате <публичен URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Напускане на екипа на $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Оставете по подразбиране, освен ако не сте персонализирали BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Оставете токена празен, за да запазите текущо съхранения токен.';

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
    return 'Нека $arg1 ме управлява';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Нека всички в тази група говорят на $arg1.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Оставете го да работи,\nдокато вие не го правите.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Оставете NeoAgent да кликва, да въвежда и да се движи през вашите приложения.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Нека NeoAgent разбере какво се вижда на вашия екран.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Нека някой, с когото работите, реши кои инструменти може да използва вашият агент ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Нека този човек изпрати $arg1 съобщение един към един.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Нека този човек говори с $arg1 тук, но не в лични чатове или други групи.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Нека този човек говори със $arg1 в лични чатове и във всяка група, която споделя.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Ниво $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Линк $arg1';
  }

  @override
  String get linkCopied => 'Връзката е копирана';

  @override
  String get linkExpiresAfter => 'Линкът изтича след';

  @override
  String get linkLifetimeHours => 'Живот на връзката (часове)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Животът на връзката трябва да бъде от 1 до 8760 часа.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Линкът е валиден до $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Свързани доставчици за влизане';

  @override
  String get linuxApp => 'Приложение за Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'В списъка $arg1/';
  }

  @override
  String get listening => 'Слушане';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'История на изпълнението на живо, стъпки на инструмента и отговори.';

  @override
  String get liveModel => 'Жив модел';

  @override
  String get liveModelProvider => 'Доставчик на модели на живо';

  @override
  String get liveRun => 'Бягане на живо';

  @override
  String get liveVoice => 'Жив глас';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Гласовата връзка на живо не е налична.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Гласовата връзка на живо беше затворена.';

  @override
  String get liveVoiceDefaults => 'Глас на живо по подразбиране';

  @override
  String get liveVoiceFailed => 'Гласът на живо не успя.';

  @override
  String get llmMemoryExportResponse => 'LLM отговор за експортиране на памет';

  @override
  String get loadFailed => 'зареждането е неуспешно';

  @override
  String get loadingExecutionDetails =>
      'Подробностите за изпълнението се зареждат...';

  @override
  String get loadingNeoagent => 'Зарежда се NeoAgent';

  @override
  String get loadingRunFlow => 'Зареждане на цикъла на изпълнение...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Локални и частни мрежови URL адреси се поддържат, когато сървърът на NeoAgent може да ги достигне. Аудиото никога не се излага на NeoAgent.';

  @override
  String get localApp => 'локално приложение';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Локална бекенд инсталация не е налична на тази платформа.';

  @override
  String get localBaseImagePath => 'Път на локално основно изображение';

  @override
  String get localComputerControlIsAvailableIn =>
      'Локалният компютърен контрол е достъпен в настолното приложение NeoAgent на macOS, Windows и Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Тук не е налично локално компютърно управление.';

  @override
  String get localModelsUrl => 'местни модели url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Локалното откриване на NeoAgent е временно недостъпно.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Местни предпочитания за приложението NeoAgent. Компютърният контрол винаги протича през единния облачен компютър.';

  @override
  String get localSetup => 'ЛОКАЛНА НАСТРОЙКА';

  @override
  String get locationCityOrPlace => 'Местоположение (град или място)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Изисква се местоположение за задействане на метеорологични събития';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Неуспешна инициализация на LocationService: $arg1';
  }

  @override
  String get logCopied => 'Дневникът е копиран';

  @override
  String get loginPassword => 'Парола за вход';

  @override
  String get logout => 'Изход';

  @override
  String get logs => 'трупи';

  @override
  String get logsCopied => 'Дневниците са копирани.';

  @override
  String get logsOnThisComputer => 'Регистрации на този компютър';

  @override
  String get longLivedAccessToken => 'Токен за дълготраен достъп';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Дългосрочно припомняне, структурирани факти и графика на знанието.';

  @override
  String get lookedAtTheScreen => 'Погледна към екрана';

  @override
  String get lookingOnThisComputerAndYour =>
      'Гледайки този компютър и вашата локална мрежа...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Гледа напред към утрешните срещи, така че нищо да не ви изненада.';

  @override
  String get loopExecution => 'Изпълнение на цикъл';

  @override
  String get loopPaused => 'Цикълът е на пауза';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'Достъпността на macOS не се предоставя на NeoAgent. Разрешете го в Системни настройки › Поверителност и сигурност › Достъпност.';

  @override
  String get macosApp => 'приложение за macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'Записът на екрана на macOS не се предоставя на NeoAgent. Разрешете го в System Settings › Privacy & Security › Screen Recording, след което отворете отново NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Пощенските сървъри, които се нуждаят от парола, ще откажат да изпратят, докато не получат нова ';

  @override
  String get main => 'Основен';

  @override
  String get makeDefault => 'Направи по подразбиране';

  @override
  String get manage => 'Управлявайте';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Управлявайте имейла на вашия акаунт, двуфакторното удостоверяване и активните сесии.';

  @override
  String get managedBy => 'Управляван от';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Мениджърите могат да имат свои собствени мениджъри (до четири нива). А ';

  @override
  String get managing => 'Управление';

  @override
  String get manualDestination => 'Ръчна дестинация';

  @override
  String get manualTrigger => 'Ръчно задействане';

  @override
  String get masterPassword => 'Главна парола';

  @override
  String get matchThisDevice => 'Съпоставете това устройство';

  @override
  String get matchedAgainstTitleAndBody =>
      'Съпоставени със заглавието и тялото';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Съвпада със стария поток на NeoAgent MCP: URL плюс метод за удостоверяване.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP сървър';

  @override
  String get mcpServer2 => 'MCP сървър';

  @override
  String get mcpServerUrl => 'URL адрес на MCP сървър';

  @override
  String get mcpServers => 'MCP сървъри';

  @override
  String get meantForSomeoneElse => 'Предназначен за някой друг';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Измерена цена на модела: $arg1';
  }

  @override
  String get memories => 'Спомени';

  @override
  String get memory => 'памет';

  @override
  String memoryArg1(Object? arg1) {
    return 'Памет: $arg1';
  }

  @override
  String get memoryInjected => 'Инжектирана памет';

  @override
  String get mentionOrReplyOnly => 'Само споменаване или отговор';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Обединени регистрационни файлове на сървъра и времето за изпълнение на Flutter за тази сесия на приложението.';

  @override
  String get messageBodyTemplateJson =>
      'Шаблон на тялото на съобщението (JSON)';

  @override
  String get messageNeedsAccess => 'Съобщението се нуждае от достъп';

  @override
  String get messageTextField => 'Поле за текст на съобщението';

  @override
  String get messaging => 'Съобщения';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Изпращане на API за съобщения и събития за уеб кукичка';

  @override
  String get messagingConnectionNeedsAttention =>
      'Връзката за съобщения изисква внимание';

  @override
  String get messagingConnections => 'Връзки за съобщения';

  @override
  String get messagingDelivery => 'Доставка на съобщения';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Грешка в съобщенията. Моля, опитайте отново.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Заснемането на микрофона спря неочаквано. Опитайте отново.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Грешка на микрофона: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Микрофонът е изключен. Докоснете, за да включите звука.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Изисква се разрешение за микрофон за глас на живо.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Минимална стойност на вноската: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Мобилната настройка е неуспешна.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Мобилната настройка е неуспешна, защото Java не е налична на машината, работеща с NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Мобилната настройка е неуспешна, защото Java не е налична на машината, работеща с NeoAgent. Инсталирайте JDK и опитайте отново.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Мобилната настройка е неуспешна. Проверете дали инструментите за Android са инсталирани правилно и опитайте отново.';

  @override
  String modeArg1(Object? arg1) {
    return 'режим: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Режимът се заключва, докато изпълнението е активно.';

  @override
  String get model => 'Модел';

  @override
  String modelArg1(Object? arg1) {
    return 'Модел: $arg1';
  }

  @override
  String get modelAvailability => 'Наличност на модела';

  @override
  String get modelAvailabilitySaved => 'Наличността на модела е запазена.';

  @override
  String get modelForThisSession => 'Модел за тази сесия';

  @override
  String get modelOverride => 'Отмяна на модела';

  @override
  String get modelPending => 'Модел в очакване';

  @override
  String get modelTurn => 'Модел завой';

  @override
  String get modelTurnCompleted => 'Моделът е завършен';

  @override
  String get modelTurnStarted => 'Обръщането на модела започна';

  @override
  String get modelVisibilityHideShowList =>
      'видимост на модела скрий покажи списък';

  @override
  String get models => 'Модели';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Модели, поведение, глас и работно пространство';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Модели, браузър, глас, диагностика...';

  @override
  String get modelsRouting => 'Модели и маршрути';

  @override
  String get monthly => 'Месечно';

  @override
  String get moreActions => 'Още действия';

  @override
  String get morningBriefing => 'Сутрешен брифинг';

  @override
  String get mostUsedAgents => 'Най-използваните агенти';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Най-използваните модели в последния $arg1.';
  }

  @override
  String get mouseKeyboard => 'Мишка и клавиатура';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove не се поддържа на тази платформа.';

  @override
  String get mustBeReachableOnThePublic =>
      'Трябва да бъде достъпен в публичния интернет -- локален и ';

  @override
  String get n24Hours => '24 часа';

  @override
  String get n2faOrRecoveryCode => '2FA или код за възстановяване';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA изисква SESSION_SECRET да бъде конфигуриран в това внедряване на NeoAgent.';

  @override
  String get n30Days => '30 дни';

  @override
  String get n365Days => '365 дни';

  @override
  String get n4HourLimitTokens => '4-часов лимит (токени)';

  @override
  String get n4HourUsage => '4-часово използване';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4 часа лимит $arg1';
  }

  @override
  String get n7DayUsage => '7-дневна употреба';

  @override
  String get n7Days => '7 дни';

  @override
  String get n90Days => '90 дни';

  @override
  String get name => 'Име';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nиме: Ново умение\nописание: Опишете какво прави това умение\n---\nНапишете инструкциите за това умение тук.\n';

  @override
  String get nameOfWhoeverMadeIt => 'името на този, който го е направил.';

  @override
  String get nameOptional => 'Име (по избор)';

  @override
  String get nativeAndWebhookChannels => 'Нативни и webhook канали';

  @override
  String get naturalBubbles => 'Естествени мехурчета';

  @override
  String get nearbyNeoagentServers => 'Близки сървъри NeoAgent';

  @override
  String get needANewAccountRegister =>
      'Нуждаете се от нов акаунт? Регистрирайте се';

  @override
  String get needAnIdea => 'Нуждаете се от идея?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Трябва да отговорите · $arg1%, за да говорите';
  }

  @override
  String get needsAttention => 'Нуждае се от внимание';

  @override
  String get needsInput => 'Нуждае се от въвеждане';

  @override
  String get neoagentApp => 'Приложение NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent Assistant';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent не можа да провери наличното време за изпълнение на бекенда.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent не можа да завърши локалната настройка.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent не можа да завърши локалната настройка. $arg1';
  }

  @override
  String get neoagentDebugInfo =>
      'Информация за отстраняване на грешки на NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent инсталира най-новия $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning => 'NeoAgent е инсталиран и работи.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent не е инсталиран на този компютър.';

  @override
  String get neoagentIsReady => 'NeoAgent е готов';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent все още работи по задача. Прекратете разговора и получете резултата в чата или също отменете задачата.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent превръща вашата демонстрация в адаптивен работен процес.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent чака, докато използвате работния плот.';

  @override
  String get neoagentIsWorking => 'NeoAgent работи';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux компютър';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT СЕ НУЖДАЕ ОТ РЕШЕНИЕ';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Изтеглянията по време на изпълнение на NeoAgent изискват защитен адрес.';

  @override
  String get neoagentServerAddress => 'Адрес на сървъра на NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'Имейлът на услугата NeoAgent не е готов. Помолете оператора на сървъра да провери настройките на имейл средата.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Настройката на NeoAgent не можа да завърши.';

  @override
  String get neoagentUser => 'Потребител на NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent използва този компютър автоматично и пита, преди да използва вашия екран, мишка, клавиатура, файлове или команден ред.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent използва вашето приблизително фоново местоположение, за да задейства напомняния за геозона (напр. „Напомнете ми да купя мляко, когато минавам покрай супермаркета“).\n\n';

  @override
  String get neoagentWorkspace => 'Работно пространство NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][стек] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall Backend URL';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Необходим е URL адрес на бекенда на NeoRecall.';

  @override
  String get neorecallSetup => 'Настройка на NeoRecall';

  @override
  String get networkRequestFailed => 'мрежовата заявка е неуспешна';

  @override
  String get networkWriteRequests => 'Мрежови заявки за запис';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'никога не се брои в лимитите за споделено използване.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Новите акаунти потвърждават своя имейл адрес, преди да влязат.';

  @override
  String get newAccountsPerDay => 'Нови акаунти на ден';

  @override
  String get newChat => 'Нов чат';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Новите групи остават тихи, освен ако някой не маркира $arg1, докато не ги включите.';
  }

  @override
  String get newLink => 'Нова връзка';

  @override
  String get newPasswordsDoNotMatch => 'Новите пароли не съвпадат.';

  @override
  String get newRecoveryCodes => 'Нови кодове за възстановяване';

  @override
  String get newSession => 'Нова сесия';

  @override
  String get newSessionN => 'Нова сесия (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Нова сесия със същата настройка';

  @override
  String get newSkill => 'Ново умение';

  @override
  String get newSkill2 => 'Ново умение';

  @override
  String get newThisWeek => 'Ново тази седмица';

  @override
  String get newsDigest => 'Дайджест на новини';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Следващ повторен опит: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Поток на влизане в Nextcloud';

  @override
  String get nextcloudSetup => 'Настройка на Nextcloud';

  @override
  String get nextcloudTalk => 'Nextcloud Talk';

  @override
  String get nextcloudUrl => 'URL адрес на Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'Изисква се URL адрес на Nextcloud.';

  @override
  String get nickname => 'Псевдоним';

  @override
  String get noAccountsConnectedYet => 'Все още няма свързани акаунти.';

  @override
  String get noAccountsFound => 'Няма намерени акаунти.';

  @override
  String get noActiveSessionsFound => 'Няма намерени активни сесии.';

  @override
  String get noAgentsYet => 'Все още няма агенти';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Не е конфигуриран доставчик на AI, така че чат и съобщения ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Няма подкани за одобрение — агентът работи без прекъсване.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Нито един актив за издание на $arg1 не съответства на тази платформа.';
  }

  @override
  String get noArguments => '(без аргументи)';

  @override
  String get noAuth => 'Няма удостоверение';

  @override
  String get noBindingsYet => 'Все още няма обвързвания.';

  @override
  String get noChangesYet => 'Все още няма промени';

  @override
  String get noChannelsFound => 'Няма намерени канали';

  @override
  String get noCloudComputerSlotIsFree =>
      'Никой слот за облачен компютър не е свободен в момента. Опитайте отново след малко.';

  @override
  String get noCoreMemoryEntriesYet => 'Все още няма записи в основната памет.';

  @override
  String get noDescription => 'Без описание';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'В момента няма налични настолни дисплеи.';

  @override
  String get noDetailAvailable => 'Няма налични подробности';

  @override
  String get noDetailedSyncSummaryYet =>
      'Все още няма подробно обобщение на синхронизирането.';

  @override
  String get noDetailsCaptured => 'Няма заснети подробности.';

  @override
  String get noEmailLinked => 'Няма свързан имейл';

  @override
  String get noExternalSignInProvidersLinked =>
      'Няма свързани външни доставчици за влизане.';

  @override
  String get noGroupMessagesYet => 'Все още няма групови съобщения';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Все още няма добавени хора за конкретна група.';

  @override
  String get noGroupsAddedYet => 'Все още няма добавени групи.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Все още няма намерени групи. След като $arg1 види групово съобщение, използвайте Намиране на скорошни чатове и те ще се покажат тук.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Все още няма намерени групи. След като $arg1 види групово съобщение, използвайте Намиране на скорошни чатове.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Няма върнат полезен товар със здравни данни.';

  @override
  String get noHealthSamplesStoredYet =>
      'Все още няма съхранени здравни проби.';

  @override
  String get noHttpClientImplementationForThis =>
      'Няма реализация на HTTP клиент за тази платформа.';

  @override
  String get noInputOrOutputWasRecorded =>
      'За тази стъпка не е записан вход или изход.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Няма интеграции, които отговарят на това търсене.';

  @override
  String get noLimit => 'Без ограничение';

  @override
  String get noLocalPasswordIsSetYet =>
      'Все още не е зададена локална парола. Създайте такъв, за да активирате влизане с потребителско име/парола.';

  @override
  String get noLogEntries => 'Няма записи в дневника.';

  @override
  String get noMatchingSettings => 'Няма съответстващи настройки';

  @override
  String get noMcpServersMatchThisSearch =>
      'Няма MCP сървъри, отговарящи на това търсене.';

  @override
  String get noMemoryEntriesFound => 'Няма намерени записи в паметта.';

  @override
  String get noMemorySync => 'Няма синхронизиране на паметта';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Прочита еднократно важните и изпратените писма от последните 12 месеца, за да познава агентът вашите контакти и проекти.';

  @override
  String get emailMemory => 'Памет от имейли';

  @override
  String get importNow => 'Импортирай сега';

  @override
  String get importOnConnect =>
      'Импортиране на минали писма при свързване на акаунт';

  @override
  String get sweepStarting => 'Подготовка…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Четене на имейли · $done от $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Четене на имейли · $count намерени';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Учене от имейлите · $done от $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Последен импорт: $emails имейла · $memories нови спомена';
  }

  @override
  String get sweepNothingNew => 'Няма нови имейли за импортиране';

  @override
  String sweepFailed(String error) {
    return 'Импортирането не бе успешно: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Няма модел, съответстващ на „$arg1“.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Не е записана заявка за модел за това изпълнение.';

  @override
  String get noModelsDiscoveredYet => 'Все още няма открити модели';

  @override
  String get noModelsSelected => 'Няма избрани модели';

  @override
  String get noModelsYet => 'Все още няма модели';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'нито един акаунт на neoagent не е свързан с този доставчик';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'За този компютър няма налично време за изпълнение на NeoAgent.';

  @override
  String get noNetworkConnection => 'Няма мрежова връзка';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Няма мрежова връзка. Свържете се, за да продължите да използвате NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Няма мрежова връзка. Свържете се отново, за да проверите за актуализации.';

  @override
  String get noOne => 'Никой';

  @override
  String get noOneAddedYet => 'Все още никой не е добавил.';

  @override
  String get noOneCanMessage => 'Никой не може да изпраща съобщения';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Не е намерен друг NeoAgent сървър. Можете да търсите отново или да въведете адрес ръчно.';

  @override
  String get noPeopleAddedYet => 'Все още няма добавени хора.';

  @override
  String get noPlatformsMatch => 'Няма съответстващи платформи';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Все още няма налични доставчици за конфигуриране.';

  @override
  String get noRecentChannelActivity => 'Няма скорошна активност в канала';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Няма резултати за \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Няма писти в този диапазон.';

  @override
  String get noRunsMatchTheseFilters =>
      'Няма серии, които отговарят на тези филтри';

  @override
  String get noRunsYet => 'Все още няма писти';

  @override
  String get noRunsYet2 => 'Все още няма писти.';

  @override
  String get noSecurityKeyWasProvided => 'Не е предоставен ключ за сигурност.';

  @override
  String get noServerUrlSet => 'Няма зададен URL адрес на сървъра';

  @override
  String get noSessionMatchesThatSearch =>
      'Нито една сесия не отговаря на това търсене.';

  @override
  String get noSessionsYet => 'Все още няма сесии';

  @override
  String get noSkillsMatchTheseFilters =>
      'Никакви умения не отговарят на тези филтри.';

  @override
  String get noStepsWereRecordedForThis =>
      'Не са записани стъпки за това бягане.';

  @override
  String get noSummaryAvailable => 'Няма налично резюме.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Няма задачи за $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Нито един инструмент не отговаря на \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Не се изпълнява актуализация';

  @override
  String get noUsageYet => 'Все още не е използвано.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Все още не е налично потвърдено време за изпълнение на бекенда на NeoAgent.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Никой повече не може да го използва. Хора, които вече са се присъединили ';

  @override
  String get none => 'Няма';

  @override
  String get notApprovedYet => 'все още не е одобрен';

  @override
  String get notAuthenticated => 'не е удостоверено';

  @override
  String get notCheckedYet => 'Все още не е проверено';

  @override
  String get notConfigured => 'Не е конфигуриран';

  @override
  String get notConnected => 'Не е свързан';

  @override
  String get notConnected2 => 'Не е свързан';

  @override
  String get notInstalled => 'Не е инсталиран';

  @override
  String get notNeeded => 'Не е необходимо';

  @override
  String get notNeededEnough => 'Не е необходимо достатъчно';

  @override
  String get notNow => 'Не сега';

  @override
  String get notNow2 => 'Не сега';

  @override
  String get notSet => 'Не е зададено';

  @override
  String get notSetUp => 'Не е настроен';

  @override
  String get notTheSameAsAdmin => 'Не е същото като администратор';

  @override
  String get nothingFound => 'Нищо не е намерено';

  @override
  String get nothingHereYet => 'Тук още няма нищо.';

  @override
  String get nothingHereYet2 => 'Тук още няма нищо';

  @override
  String get nothingMatches => 'Нищо не съвпада';

  @override
  String get nothingStoredYet => 'Все още нищо не е съхранено.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'OAuth ИД на клиента';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth клиент id тайно пренасочване api ключ';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth клиент id тайно пренасочване gmail календар устройство';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Стартирането на OAuth не се поддържа на тази платформа.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook tenant client id secret';

  @override
  String get oauthToken => 'OAuth токен';

  @override
  String get oauthWithPkce => 'OAuth с PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'на $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'собствено. Никога не се показва отново след запазване.';

  @override
  String get off => 'Изключено';

  @override
  String get officialIntegration => 'Официална интеграция';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Официалната интеграция не върна URL адрес за връзка.';

  @override
  String get on => 'Включено';

  @override
  String get onASignedInAndroidDevice =>
      'На устройство с Android, на което сте влезли, отворете Настройки › Вход и сигурност, сканирайте този код и одобрете влизането.';

  @override
  String get onByDefaultForNewGroups =>
      'Включено по подразбиране за нови групи';

  @override
  String get onDemand => 'При поискване';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Включено за $arg1 от $arg2 групи';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'на. Те могат да се присъединят отново само с нова връзка за покана.';

  @override
  String get onYourOwnTheDefault => 'Сами (по подразбиране)';

  @override
  String get once => 'Веднъж';

  @override
  String get oneIsSavedOtherChangesIn =>
      'един е спасен. Други промени в тази форма също се запазват.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Един или повече акаунти са изтекли. Свържете отново засегнатия акаунт, за да възстановите достъпа до инструмента.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Едно време за изпълнение контролира личността, груповото редуване, паметта на стаята, нормите, теорията на ума и доставката.';

  @override
  String get oneTimeRun => 'Еднократно бягане';

  @override
  String get onlyApkOrApksFilesCan =>
      'Могат да се инсталират само .apk или .apks файлове.';

  @override
  String get onlyInThisGroup => 'Само в тази група';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Необходимо е само ако услугата поиска допълнителни HTTP заглавки.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Необходимо е само ако искате да промените формата на изходящия полезен товар.';

  @override
  String get onlyTheyCanChangeIt => 'Само те могат да го променят.';

  @override
  String get open => 'Отворете';

  @override
  String get openAccountSettingsOnASigned =>
      'Отворете Настройки › Влизане и защита на устройство с Android, на което сте влезли, сканирайте този код и одобрете влизането.';

  @override
  String get openComputer => 'Отворете компютъра';

  @override
  String get openDashboard => 'Отворете таблото за управление';

  @override
  String get openFolder => 'Отворете папката...';

  @override
  String get openInWorkbench => 'Отворете в работна маса';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Отворете NeoAgent и свържете отново $arg1, за да възстановите съобщенията.';
  }

  @override
  String get openTimeSettings => 'Настройки за отворено време';

  @override
  String get openToAnyone => 'Отворено за всеки';

  @override
  String get openTrello => 'Отворете Trello';

  @override
  String get openVoiceAssistant => 'Отворете гласов асистент';

  @override
  String get openWiFiSettings => 'Отворете Wi-Fi настройките';

  @override
  String get openWithTheDefaultApp => 'Отворете с приложението по подразбиране';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai съвместим';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Крайна точка, съвместима с OpenAI (ваш собствен сървър или друг ';

  @override
  String openedArg1(Object? arg1) {
    return 'Отворен $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Отварянето на URL адреси на работния плот не се поддържа на тази платформа.';

  @override
  String get openingYourSavedDesktop =>
      'Отваряне на вашия запазен работен плот.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Отваряне на вашия запазен работен плот. Нормалните стартирания отнемат по-малко от 10 секунди.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Допълнителна тайна по избор, ако защитите входящата уебкукичка.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Незадължителна отмяна, ако URL адресът на уеб кукичката не е достатъчен.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Незадължителна тайна за проверка на входящи събития в чата.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Незадължителна тайна за проверка на входящи събития.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Незадължителна тайна за проверка на входящите iMessage събития.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Незадължителна тайна за проверка на входящи LINE събития.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Незадължителна тайна за проверка на входящи събития Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Незадължителна тайна за проверка на входящи събития на Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Не е задължително. Агентът вече има своя индивидуалност. Всичко, което добавите относно тона, се наслоява върху него, така че никога не се налага да го дефинирате.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Не е задължително. Когато е зададен, той се използва вместо URL.';

  @override
  String get orAnswerInYourOwnWords => 'Или отговорете със собствените си думи';

  @override
  String get orBuildYourOwnTask => 'Или създайте своя собствена задача';

  @override
  String get orContinueWith => 'или продължете с';

  @override
  String get orFiles => 'или файлове.';

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
  String get originNotAllowed => 'произход не е разрешен';

  @override
  String get outgoingMessage => 'Изходящо съобщение';

  @override
  String get outgoingWebhookUrl => 'URL адрес на изходящ уеб кукичка';

  @override
  String get outlookEmailReceived => 'Имейлът на Outlook е получен';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Презаписване на бележки за поведение от импортирането.';

  @override
  String get ownModel => 'собствен модел';

  @override
  String get packageName => 'Име на пакета';

  @override
  String get pairWithQrCode => 'Сдвояване с QR код';

  @override
  String get password => 'Парола';

  @override
  String get password2faAndActiveSessions => 'Парола, 2FA и активни сесии';

  @override
  String get passwordCreated => 'Паролата е създадена.';

  @override
  String get passwordIsTooWeak => 'паролата е твърде слаба';

  @override
  String get passwordMin8 => 'парола мин. 8';

  @override
  String get passwordOrApiKey => 'Парола или API ключ';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Сила на паролата: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Паролите не съвпадат.';

  @override
  String get pasteAKey => 'Поставете ключ.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Поставете нов ключ, за да замените $arg1';
  }

  @override
  String get pasteTheKey => 'Поставете ключа';

  @override
  String get pasteYourAccountToken => 'Поставете токена на вашия акаунт';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Поставете вашия $arg1 API ключ по-долу. Това е ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Пътят трябва да остане в работното пространство на NeoAgent.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Пътят трябва да остане в папката на работното пространство.';

  @override
  String get pauseLiveUpdates => 'Поставяне на актуализации на живо на пауза';

  @override
  String get pauseTaskLoop => 'Поставете на пауза цикъла на задачите';

  @override
  String get paused => 'На пауза';

  @override
  String peakArg1(Object? arg1) {
    return 'пик $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Хора в лични чатове';

  @override
  String get perAccountRateLimits => 'Лимити за лихви по сметка';

  @override
  String get perCategoryPermissions => 'Разрешения за всяка категория';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Политики за разрешения за всеки инструмент, пропуски за одобрение и изолация на процеса за изпълнение на shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Изисква се разрешение: $arg1';
  }

  @override
  String get permissionsNeeded => 'Необходими са разрешения';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Разрешения. Никой друг не може да промени това.';

  @override
  String get personOrChat => 'Лице или чат';

  @override
  String get personaBehaviorNotes => 'Бележки за поведението на личността';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Личен токен за достъп за бота Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Персонални канали и директни опорни повърхности.';

  @override
  String get personalSelfChat => 'Личен самостоятелен чат';

  @override
  String get phoneNumber => 'телефонен номер';

  @override
  String get pickARunFromTheList =>
      'Изберете бягане от списъка, за да видите стъпките му.';

  @override
  String get pickARunFromTheList2 =>
      'Изберете изпълнение от списъка вляво, за да изследвате потока му.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Изберете от последните $arg1 чатове или добавете човек или група сами.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Изберете как $arg1 използва този акаунт.';
  }

  @override
  String get pickOneToFillInThe =>
      'Изберете един, за да попълните задачата. Можете да промените всичко след това.';

  @override
  String get picksUpWhereYouLeftOff => 'Продължава откъдето сте спрели';

  @override
  String get plan => 'Планирайте';

  @override
  String get planning => 'Планиране';

  @override
  String get platform => 'Платформа';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Платформа $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Моля, изберете график.';

  @override
  String get pleaseEnterAFilename => 'Моля, въведете име на файл.';

  @override
  String get pleaseEnterAKey => 'Моля, въведете ключ.';

  @override
  String get pleaseEnterAPrompt => 'Моля, въведете подкана.';

  @override
  String get pleaseEnterATaskName => 'Моля, въведете име на задача.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Моля, въведете съдържанието на паметта.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Моля, въведете кога трябва да се изпълни задачата.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Моля, изберете акаунт или въведете валиден ID за връзка.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Насочете NeoAgent към всяко завършване на чат, съвместимо с OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Насочете камерата към кода, показан на устройството, от което сте излезли. Одобрението остава на този телефон.';

  @override
  String get port => 'Порт';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'порт node_env публичен url доверие прокси защитени бисквитки разполагане';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Първокласна автоматизация с график и тригери за интеграция.';

  @override
  String get prepareQrCode => 'Подгответе QR код';

  @override
  String get preparingNeoagent => 'Подготвя се NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Приготвяне на NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Натиснете и задръжте за бързо заснемане';

  @override
  String get pressKeysIsNotSupportedOn =>
      'натискане на клавиши не се поддържа на тази платформа.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Натиснат $arg1';
  }

  @override
  String get priceUnknown => 'Цена неизвестна';

  @override
  String get primaryDisplay => 'Основен дисплей';

  @override
  String get privateChat => 'Частен чат';

  @override
  String get privateChats => 'Частни чатове';

  @override
  String get privateChats2 => 'лични чатове';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Частни чатове: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Частни чатове $arg1 · групи $arg2';
  }

  @override
  String get privateChatsOnly => 'Само частни чатове';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'частните мрежови адреси не са разрешени.';

  @override
  String get profileEmailAndPersonalData => 'Профил, имейл и лични данни';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Подкана, преди NeoAgent да остане резидентен в системната област.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Кеш подкана: $arg1 кеширани токени ';
  }

  @override
  String get promptCopied => 'Подканата е копирана.';

  @override
  String get promptOrSchedule => 'подкана или график.';

  @override
  String get promptToPasteIntoAnotherAi => 'Подкана за поставяне в друг AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Свързването на доставчик не можа да бъде стартирано.';

  @override
  String get providerSignInCouldNotBe =>
      'Влизането на доставчика не можа да бъде стартирано.';

  @override
  String get providers => 'Доставчици';

  @override
  String get providersEachAccountCanStillPick =>
      'Доставчици; всеки акаунт все още може да избере свой собствен модел в настройките. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Доставчици, интеграции, глас и допълнителни възможности могат да бъдат завършени от Настройки по всяко време.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Публични теми за издаване и заявка за изтегляне, отговорени само за одобрени хора.';

  @override
  String get publicUrl => 'Обществен URL адрес';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Публичен URL адрес и разрешени източници';

  @override
  String get publicUrlOverride => 'Отмяна на публичен URL адрес';

  @override
  String get pullsTogetherTheDayAhead => 'Обединява предстоящия ден';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'Свързване на телефон чрез QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR влизането е завършено, но NeoAgent не може да поддържа сесията. Моля, опитайте отново.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'QR влизането не можа да бъде стартирано.';

  @override
  String get qrLoginRequestHasExpired => 'qr заявката за влизане е изтекла';

  @override
  String get qrLoginRequestWasNotFound =>
      'qr заявката за влизане не беше намерена';

  @override
  String get qrPairing => 'QR сдвояване';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'изпълнение на заявки; всичко, което пише, се отхвърля.';

  @override
  String get queryFilter => 'Заявка / Филтър';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'На опашка като управление за текущото изпълнение: $arg1';
  }

  @override
  String get quickstart => 'Бърз старт';

  @override
  String get quit => 'Откажете се';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'дъжд_начало, вятър_предупреждение';

  @override
  String get ranAScriptInThePage => 'Стартира скрипт в страницата';

  @override
  String ranArg1(Object? arg1) {
    return 'Стартира $arg1';
  }

  @override
  String get rateLimits => 'Ограничения на скоростта';

  @override
  String get readAnArtifact => 'Прочетете артефакт';

  @override
  String get readAndEditFilesInsideYour =>
      'Четете и редактирайте файлове във вашата папка NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Прочетете $arg1';
  }

  @override
  String get readError => 'Грешка при четене';

  @override
  String get readFiles => 'Четене на файлове';

  @override
  String get readOnly => 'Само за четене';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Прочетете папката и обобщете стека, входните точки и как да го стартирате.';

  @override
  String get readThePage => 'Прочетете страницата';

  @override
  String get readTheUiTree => 'Прочетете дървото на потребителския интерфейс';

  @override
  String get readWrite => 'Четене / Пишете';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Отчита стъпки, пулс, сън, упражнения и тегло.';

  @override
  String get ready => 'Готови';

  @override
  String get readyForFirstTimeSetup => 'Готов за първоначална настройка';

  @override
  String get readyToConnect => 'Готов за свързване';

  @override
  String get recentChannelActivity => 'Скорошна активност на канала';

  @override
  String get recentChats => 'Последни чатове';

  @override
  String get recentDecisions => 'Последни решения';

  @override
  String get recentFailedRuns => 'Скорошни неуспешни изпълнения';

  @override
  String get recentGroupDecisions => 'Последни групови решения';

  @override
  String get recentRuns => 'Скорошни изпълнения';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Скорошните изпълнения отнемат около $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Скорошен резултат от сървъра, първо най-новите.';

  @override
  String get recentUsage4Hours => 'Скорошна употреба (4 часа)';

  @override
  String get recents => 'Скорошни';

  @override
  String get recipientField => 'Поле за получател';

  @override
  String get reconnectOrFinishSetup =>
      'Свържете отново или завършете настройката';

  @override
  String get reconnectingThisDevice => 'Това устройство се свързва отново...';

  @override
  String get recurring => 'Повтарящи се';

  @override
  String get redirectUri => 'URI за пренасочване';

  @override
  String get redoOnboarding => 'Повторете интегрирането';

  @override
  String get refresh => 'Опресняване';

  @override
  String get refreshCode => 'Опресняване на кода';

  @override
  String get refreshNow => 'Опресни сега';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Обновете екрана на Android, за да опитате отново.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Откажете да изпратите, освен ако връзката не се надстрои до TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'независимо от настройките по категория по-долу.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Регистрирайте $arg1 за потока за призоваване на асистент.';
  }

  @override
  String get registrationIsClosed => 'регистрацията е затворена';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'регистрация регистрация нови акаунти позволяват регистрация';

  @override
  String get rejectInvalidTlsCertificates =>
      'Отхвърляне на невалидни TLS сертификати';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'освобождаване и рестартиране. Свързаните приложения се свързват отново, след като се върне.';

  @override
  String get releaseChannel => 'Канал за освобождаване';

  @override
  String get releaseCommitBranchNode =>
      'освобождаване на ангажимент клон възел';

  @override
  String get releaseWhenYouAreDone => 'Освободете, когато сте готови.';

  @override
  String get reloadNow => 'Презареди сега';

  @override
  String get rememberThisChoice => 'Запомнете този избор';

  @override
  String get remove => 'Премахнете';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Да се премахне ли \"$arg1\" и записаните стъпки от хронологията на изпълнението?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Премахнете \"$arg1\" от основната памет.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Премахване на $arg1 ключ?';
  }

  @override
  String get removeEraseGdprUser =>
      'премахване на изтриване на потребител на gdpr';

  @override
  String get removeSmtpPassword => 'Премахнете SMTP паролата';

  @override
  String get removeTheSmtpPassword => 'Премахване на SMTP паролата?';

  @override
  String get rename => 'Преименуване';

  @override
  String get renameSecurityKey => 'Преименувайте ключа за сигурност';

  @override
  String get renameSession => 'Преименуване на сесия';

  @override
  String get repairAndRetry => 'Поправете и опитайте отново';

  @override
  String get repairDesktop => 'Ремонт на работния плот';

  @override
  String get repeat => 'Повторете';

  @override
  String get repliesWhenTagged => 'Отговаря при маркиране';

  @override
  String get replyToAddress => 'Адрес за отговор';

  @override
  String replyToArg1(Object? arg1) {
    return 'Отговор на $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Хранилището трябва да е във формат собственик/репо.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Възпроизведете грешката, която описвам, намерете основната причина и я поправете с регресионен тест.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'заявката е неуспешна с http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Неуспешна заявка с HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Поискайте разрешения';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Заявката до $arg1 е неуспешна, преди бекендът да отговори.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Поискано $arg1';
  }

  @override
  String get requireStarttls => 'Изискване на STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Изисква се зад HTTPS или TLS прокси. Прилага се след сървър ';

  @override
  String get requiredExampleBerlinDe =>
      'Задължително. Пример: Берлин, Германия';

  @override
  String get requiredFormatOwnerRepo => 'Задължително. Формат: собственик/репо';

  @override
  String get reserveAssistantHotkey => 'Бърз клавиш за резервен асистент';

  @override
  String get reset => 'Нулиране';

  @override
  String get resetPassword => 'Нулирайте паролата';

  @override
  String get resetView => 'Нулиране на изгледа';

  @override
  String get responsibilities => 'Отговорности';

  @override
  String get restart => 'Рестартирайте';

  @override
  String get restartToFinishTheUpdate =>
      ' Рестартирайте, за да завършите актуализацията.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Възстановяване на предишната среда за изпълнение на NeoAgent';

  @override
  String get restrictDelegationTargets =>
      'Ограничаване на целите за делегиране';

  @override
  String get result => 'Резултат';

  @override
  String get resultDelivery => 'Доставка на резултат';

  @override
  String get resultOneClickAddsOneYou =>
      'резултат. Едно кликване добавя едно; можете да го редактирате по-късно.';

  @override
  String get results => 'Резултати';

  @override
  String get retry => 'Опитайте отново';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'За многократна употреба · използван $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Прегледайте незавършените промени';

  @override
  String get revoke => 'Отмени';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Първо отменете администратора с `neoagent admin revoke $arg1`';
  }

  @override
  String get revokeThisLink => 'Да се отмени тази връзка?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Партиден прозорец на стаята: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Завъртете, за да продължите';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'редове. Добавете LIMIT или по-тясна клауза WHERE, за да видите ';

  @override
  String get rule => 'правило';

  @override
  String get run => 'Изпълнение';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Изпълнявайте произволни команди на вашата машина или виртуална машина.';

  @override
  String get runAt => 'Бягай при';

  @override
  String get runCompleted => 'Изпълнението е завършено';

  @override
  String get runFailed => 'Неуспешно изпълнение';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Стартирайте git diff, прегледайте неизвършените промени за грешки и проблеми със стила и обобщете какво сте открили.';

  @override
  String get runNotFound => 'Изпълнението не е намерено';

  @override
  String get runNow => 'Изпълни сега';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Работете с входящи лични съобщения в WhatsApp.';

  @override
  String get runQuery => 'Изпълнение на заявка';

  @override
  String get runShellCommandsOrInstallApps =>
      'Изпълнявайте команди на обвивката или инсталирайте приложения на устройството си с Android.';

  @override
  String get runStarted => 'Бягането започна';

  @override
  String get runStatus => 'Състояние на изпълнение';

  @override
  String get runStopped => 'Бягането спря';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Изпълнявайте терминални команди и отваряйте приложения или уеб страници.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Стартирайте този сървър: акаунти, актуализации, доставчици, конфигурация ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Стартирайте, когато пристигне съответстващо съобщение в Gmail.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Стартирайте, когато пристигне съответстващ имейл на Outlook.';

  @override
  String get runWhenANewIssueMatching =>
      'Стартирайте, когато нов проблем, съответстващ на вашите филтри, се отвори в хранилище.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Стартирайте, когато бъде създадена нова NeoRecall памет, съответстваща на вашите филтри.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Стартирайте, когато на вашето устройство пристигне известие.';

  @override
  String get runWhenASlackMessageMatches =>
      'Изпълнение, когато Slack съобщение отговаря на избрания обхват.';

  @override
  String get runWhenATeamsChatMessage =>
      'Изпълнение, когато съобщение за чат на Teams съответства на избрания обхват.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Стартирайте, когато се прогнозират конфигурирани метеорологични събития за местоположение.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'тичам. Докато всеки модел е изключен, моделите, които доставчиците добавят ';

  @override
  String get running => 'Изпълнява се';

  @override
  String runningArg1(Object? arg1) {
    return 'Работи $arg1';
  }

  @override
  String get runningTask => 'Изпълняваща се задача';

  @override
  String get runningTool => 'Инструмент за бягане';

  @override
  String get runs => 'Изпълнения';

  @override
  String get runsEveryDayAtTheSelected =>
      'Изпълнява се всеки ден в избрания час.';

  @override
  String get runsFourTimesPerHour => 'Работи четири пъти на час.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— работи, съобщения, спомени, интеграции, файлове и ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'работи, съобщения, спомени, интеграции, файлове и сесии. ';

  @override
  String get runsMondayThroughFriday => 'Работи от понеделник до петък.';

  @override
  String get runsOnSelectedWeekdays => 'Работи в избрани дни от седмицата.';

  @override
  String get runsOncePerHour => 'Пуска се веднъж на час.';

  @override
  String get runsOncePerMonthOnThe =>
      'Изпълнява се веднъж месечно в избрания ден.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Стартира само когато натиснете Run Now.';

  @override
  String get runsPerDay => 'Работи на ден';

  @override
  String get runsPerDay30Days => 'Работи на ден (30 дни)';

  @override
  String get runsThatCompleted => 'Изпълнения, които са завършени';

  @override
  String get runsThisWeek => 'Изпълнява се тази седмица';

  @override
  String get runsToday => 'Работи днес';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Изпълнения, инструменти, памет, планиране, умения и MCP са налични тук.';

  @override
  String get runsTwicePerHour => 'Работи два пъти на час.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Изпълненията ще се върнат към споделения сървърен ключ за $arg1, ако такъв е конфигуриран. Това не може да бъде отменено.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Време на изпълнение $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Време на изпълнение: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Настройки за изпълнение, с които този сървър стартира. Редактирайте ги под ';

  @override
  String get runtimeSetupRequired =>
      'Необходима е настройка на времето за изпълнение';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Публичният ключ за подписване по време на изпълнение трябва да бъде 32 байта.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Запазване';

  @override
  String get saveATrelloApiKeyFor =>
      'Запазете ключ за API на Trello за този агент, след което свържете сигурно един акаунт в Trello. Токенът на акаунта се съхранява на сървъра и се използва само за този агент.';

  @override
  String get saveAccount => 'Запазване на акаунта';

  @override
  String get saveChanges => 'Запазете промените';

  @override
  String get saveCloudComputerSettings =>
      'Запазете настройките на облачния компютър';

  @override
  String get saveConnect => 'Запазване и свързване';

  @override
  String get saveDefaults => 'Запазване на настройките по подразбиране';

  @override
  String get saveDiagnosticReport => 'Запазване на диагностичния отчет';

  @override
  String get saveEmail => 'Запазване на имейл';

  @override
  String get saveEmailSettings => 'Запазете имейл настройките';

  @override
  String get saveGeneralSettings => 'Запазете общите настройки';

  @override
  String get saveName => 'Запазете името';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Запазете диагностиката на настройката на NeoAgent';

  @override
  String get saveOnly => 'Само запазване';

  @override
  String get saveSetup => 'Запазване на настройките';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Запазете тези кодове за възстановяване сега. Те няма да бъдат показвани отново.';

  @override
  String get savedDeliveryDestination => 'Запазена дестинация за доставка';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Запазени ограничения на скоростта за @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Сканирайте QR за влизане в NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Сканирайте QR за сдвояване на NeoAgent от друго устройство и го одобрете от тази сесия за стартиране.';

  @override
  String get scanLoginQr => 'Сканирайте QR за влизане';

  @override
  String get scanPairingQr => 'Сканирайте QR за сдвояване';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Сканирайте QR заявки за влизане от излезли устройства и ги одобрявайте от тази удостоверена мобилна сесия.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Сканирайте, за да завършите $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Сканирайте с NeoAgent на вашия телефон';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Сканира нов имейл и ви пингва само когато нещо има значение.';

  @override
  String get schedule => 'График';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'планирано време. След като бяганията бъдат измерени, ще започне по-рано.';

  @override
  String get screen => 'екран';

  @override
  String get screenAction => 'действие на екрана';

  @override
  String get scrollIsNotSupportedOnThis =>
      'превъртане не се поддържа на тази платформа.';

  @override
  String get scrollToBottom => 'Превъртете надолу';

  @override
  String get search => 'Търсене';

  @override
  String get search2 => 'Търсене...';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Настройки на администратора за търсене (напр. SMTP, Ollama, регистрационни файлове)';

  @override
  String get searchAgain => 'Търсете отново';

  @override
  String get searchByUsernameOrEmail =>
      'Търсете по потребителско име или имейл';

  @override
  String get searchChannels => 'Търсене на канали';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Търсете открити канали за съобщения, контакти, групи и скорошни разговори.';

  @override
  String get searchGroups => 'Групи за търсене';

  @override
  String get searchMemory => 'Търсене в паметта';

  @override
  String get searchModelsOrProviders => 'Търсете модели или доставчици';

  @override
  String get searchModelsOrProviders2 => 'Търсете модели или доставчици...';

  @override
  String get searchRecentPeopleAndGroups => 'Търсете скорошни хора и групи';

  @override
  String get searchSessions => 'Сесии за търсене';

  @override
  String get searchSettings => 'Настройки за търсене';

  @override
  String get searchTitleModelTriggerRunId =>
      'Заглавие за търсене, модел, тригер, ID на изпълнение';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Инструменти за търсене, интеграции и умения';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Търсен код за \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Търсени файлове за \"$arg1\"';
  }

  @override
  String get secretField => 'Тайно поле';

  @override
  String get secureCookies => 'Защитени бисквитки';

  @override
  String get security => 'сигурност';

  @override
  String get securityKey => 'Ключ за сигурност';

  @override
  String get securityKeyPromptWasDismissed =>
      'Подканата за ключ за сигурност беше отхвърлена.';

  @override
  String get securityKeySignInCompletedBut =>
      'Влизането с ключ за сигурност завърши, но NeoAgent не можа да запази сесията на браузъра. Моля, влезте отново.';

  @override
  String get securityKeySignInCouldNot =>
      'Влизането с ключ за сигурност не може да бъде стартирано.';

  @override
  String get securityKeys => 'Ключове за сигурност';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Ключовете за сигурност са налични само в уеб приложението NeoAgent.';

  @override
  String get seeAll => 'Вижте всички';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Вижте кой NeoAgent сървър използва този прозорец и стартирайте бекенда на този компютър.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'вижте вашето потребителско име и тези настройки, никога вашите чатове, спомени ';

  @override
  String get selectARun => 'Изберете изпълнение';

  @override
  String get selectASessionToSeeIts =>
      'Изберете сесия, за да видите нейния компютър, файлове и промени.';

  @override
  String get selectAll => 'Изберете всички';

  @override
  String get selectAll2 => 'Изберете Всички';

  @override
  String selectArg1(Object? arg1) {
    return 'Изберете $arg1';
  }

  @override
  String get selectTrigger => 'Изберете Тригер';

  @override
  String get send => 'Изпрати (⌘↵)';

  @override
  String get send2 => 'Изпратете';

  @override
  String get sendATaskFromChatAnd =>
      'Изпратете задача от чата и историята на нейното изпълнение ще се покаже тук.';

  @override
  String get sendItToATeammateWith =>
      'изпрати го на съотборник с акаунт на този сървър.';

  @override
  String get sendLink => 'Изпратете връзка';

  @override
  String get sendPath => 'Път за изпращане';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Изпращайте POST / PUT / DELETE заявки към външни API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Изпратете тази връзка само до лицето, за което е предназначена. Показва се веднъж; ';

  @override
  String get senderAddress => 'Адрес на изпращача';

  @override
  String get senderFilterOptional => 'Филтър за подателя (по избор)';

  @override
  String get sentSharedAttachments => 'Изпратени споделени прикачени файлове.';

  @override
  String get separateAccount => 'Отделна сметка';

  @override
  String get server => 'сървър';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Сървър по подразбиране ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Сървърът по подразбиране за гласови повиквания в приложението. Обажданията се провеждат на живо ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'самия сървър: акаунти, доставчици и конфигурация.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Сървър, псевдоним, канал и незадължителен TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'сървър изход конзола предупреждения грешки копиране';

  @override
  String get serverProviderCredentials =>
      'Идентификационни данни на доставчик на сървър';

  @override
  String get serverUrl => 'URL адрес на сървъра';

  @override
  String get serverUsageLimitsDonTApply =>
      'Ограниченията за използване на сървъра не се прилагат за модели, работещи на вашия собствен ключ.';

  @override
  String get serviceEmail => 'Служебен имейл';

  @override
  String get serviceEmailIsNotConfigured =>
      'служебният имейл не е конфигуриран';

  @override
  String get serviceEmailSmtp => 'Служебен имейл (SMTP)';

  @override
  String get sessionActions => 'Действия на сесията';

  @override
  String get sessions => 'Сесии';

  @override
  String get sessions2 => 'СЕСИИ';

  @override
  String get sessionsArePinnedToAFolder =>
      'Сесиите са фиксирани към папка и компютър. Започнете да планирате, изграждате, тествате и изпращате от тук.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'сесии (член 17 от GDPR). Администраторските акаунти не могат да бъдат изтрити ';

  @override
  String get sessionsLogoutRevokeForce => 'сесии излизане отмяна сила';

  @override
  String get setBlockAskAllowPerTool =>
      'Задайте блокиране/питане/разрешаване за категория инструменти или изберете глобален режим.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Настройте NeoAgent на този компютър';

  @override
  String get setUpOrConnectNeoagent => 'Настройте или свържете NeoAgent';

  @override
  String get setUrl => 'Задаване на URL';

  @override
  String get settings => 'Настройки';

  @override
  String get settingsAndCannotBeUndone =>
      'настройки и не може да бъде отменено.';

  @override
  String get settingsArea => 'Област за настройки';

  @override
  String get settingsAreas => 'Области за настройки';

  @override
  String get setup => 'Настройка';

  @override
  String get setupDetails => 'Подробности за настройката';

  @override
  String get setupRequired => 'Изисква се настройка';

  @override
  String get setupWasCancelled => 'Настройката беше отменена.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Споделени прикачени файлове от клиента NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Споделено от друго приложение';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Споделените ключове на доставчика са конфигурирани на сървъра. За да използвате вместо това свой собствен API ключ или персонализирана крайна точка, отидете на Разширени → Донесете свой собствен ключ.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Споделено с чата на NeoAgent и неговата памет.';

  @override
  String get shellCommands => 'Shell команди';

  @override
  String showAllArg1(Object? arg1) {
    return 'Покажи всички $arg1';
  }

  @override
  String get showEarlier => 'Покажи по-рано';

  @override
  String get showEveryStep => 'Покажете всяка стъпка';

  @override
  String get showTools => 'Показване на инструменти';

  @override
  String get showWorkbenchJ => 'Показване на работната маса (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Показване на първия $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Показва се в страничната лента. Оставете празно, за да използвате вашето потребителско име.';

  @override
  String get signIn => 'влезте';

  @override
  String get signInCompletedButNeoagentCould =>
      'Входът е завършен, но NeoAgent не успя да запази сесията на браузъра. Моля, влезте отново. Ако това продължава, проверете настройките на бисквитките на задната сесия.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Входът е завършен, но NeoAgent не успя да запази сесията на браузъра. Моля, влезте отново. Ако това продължава да се случва, бисквитката на задната сесия вероятно не се запазва.';

  @override
  String get signInToThisNeoagentServer =>
      'Влезте в този сървър на NeoAgent, преди да сканирате QR код за сдвояване.';

  @override
  String get signInWithAHardwareKey =>
      'Влезте с хардуерен ключ или парола вместо вашата парола. ';

  @override
  String get signInWithASecurityKey => 'Влезте с ключ за сигурност';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Влезте с $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Одобрете NeoAgent във вашия $arg1 акаунт. Няма ключ за копиране.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'В очакване на $arg1. Завършете във вашия браузър.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Поставете кода $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'След като одобрихте NeoAgent, $arg1 показа еднократен код. Поставете го тук.';
  }

  @override
  String get signInCode => 'Код за вход';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Влезли сте с $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Неуспешно влизане: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Влезте със същия имейл и главна парола, които използвате в Bitwarden. Главната парола и кодът в две стъпки се използват само за влизане и никога не се съхраняват или изпращат на AI.';

  @override
  String get signOut => 'Излезте';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Излезте @$arg1 навсякъде?';
  }

  @override
  String get signOutEverywhere => 'Излезте навсякъде';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API мост';

  @override
  String get signalCliServerUrl => 'signal-cli сървър URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Изписване @$arg1 от всяка сесия.';
  }

  @override
  String get signedInDevices => 'Устройства, на които сте влезли';

  @override
  String get signedInWithin24Hours => 'Влезте в рамките на 24 часа';

  @override
  String get signingSecret => 'Тайно подписване';

  @override
  String sinceArg1(Object? arg1) {
    return 'От $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'от $arg1';
  }

  @override
  String get singleMessage => 'Едно съобщение';

  @override
  String get singleUse => 'Еднократна употреба';

  @override
  String get skill => 'Умение';

  @override
  String get skillChanges => 'Промени в уменията';

  @override
  String get skillContent => 'Съдържание на умения';

  @override
  String get skills => 'Умения';

  @override
  String get skip => 'Пропускане';

  @override
  String get skipForNow => 'Пропуснете за сега';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Пропуснете тази задача, преди да извика модела.';

  @override
  String get slackMessageReceived => 'Получено е слабо съобщение';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Сън $arg1 сесии';
  }

  @override
  String get smartSelector => 'интелигентен селектор';

  @override
  String get smartSelector2 => 'Интелигентен селектор';

  @override
  String get smartSelectorPool => 'Интелигентен селекторен басейн';

  @override
  String get smtpHost => 'SMTP хост';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'известия за потвърждение на smtp имейл подател tls нулиране';

  @override
  String get smtpPassword => 'SMTP парола';

  @override
  String get smtpPort => 'SMTP порт';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP портът трябва да е цяло число от 1 до 65535.';

  @override
  String get smtpUsername => 'SMTP потребителско име';

  @override
  String get soTheRunStartsThatMuch =>
      'така че бягането започва много по-рано.';

  @override
  String get socialBehaviorOff => 'Изключено социално поведение';

  @override
  String get socialIntelligence => 'социална интелигентност';

  @override
  String get socialIntelligence2 => 'Социална интелигентност';

  @override
  String get socialObservability => 'Социална наблюдаемост';

  @override
  String get socialReach => 'социален обхват';

  @override
  String get socialReach2 => 'Социален обхват';

  @override
  String get socialReach3 => 'Социален обхват';

  @override
  String get socialReachUpdated => 'Социалният обхват е актуализиран.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Агентите на социални източници могат да четат директно, включително емисии, хранилища, Reddit, X, видеоклипове и пазарни данни, поддържани от бисквитки.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Нещо се обърка. Моля, опитайте отново.';

  @override
  String get source => 'Източник';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Идентификатор на пространство или чат, използван, когато този агент започне разговор.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space webhook и поддръжка за обратно извикване на приложението';

  @override
  String get speaking => 'Говорейки';

  @override
  String get speechToSpeechModelUsingThe =>
      'модел реч-към-говор с помощта на ключа OpenAI или Google под ';

  @override
  String get speechToText => 'Преобразуване на реч в текст';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Преобразуването на говор в текст транскрибира гласови бележки и диктовки. Auto използва OpenAI, Gemini или Deepgram, което от двете има API ключ. Моделът за гласов отговор е моделът за чат, който отговаря на гласови бележки.';

  @override
  String get sqlConsole => 'SQL конзола';

  @override
  String get stable => 'Стабилен';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable инсталира последната публикувана бекенд версия.';

  @override
  String get stackTrace => 'проследяване на стека';

  @override
  String get standard => 'Стандартен';

  @override
  String get standardView => 'Стандартен изглед';

  @override
  String get start => 'Започнете';

  @override
  String get startASessionToPlanOr =>
      'Започнете сесия за планиране или изграждане с NeoAgent.';

  @override
  String get startAndroid => 'Стартирайте Android';

  @override
  String get startComputer => 'Стартирайте компютъра';

  @override
  String get startFullSetup => 'Стартирайте пълната настройка';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Стартирайте настройката';

  @override
  String get startTalking => 'Започнете да говорите';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Първо стартирайте телефона с Android, след което пуснете .apk или .apks файл тук.';

  @override
  String get startTheServerLaterFromThe =>
      'Стартирайте сървъра по-късно от списъка, след като конфигурацията бъде запазена.';

  @override
  String get startWithARecommendedTask => 'Започнете с препоръчана задача';

  @override
  String get startingAndroid => 'Стартиране на Android';

  @override
  String get startingYourComputer => 'Стартиране на вашия компютър';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Започва с xoxb-. От вашите идентификационни данни за приложението Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'Грешка при стартиране на TelecomCallRouting: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'статистика изпълнява токени потребителски графики процент на успех';

  @override
  String get status => 'Статус';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'доставчици на виртуална среда за изпълнение на база данни за състояние';

  @override
  String get statusIsNotLoadedYet => 'Статусът все още не е зареден.';

  @override
  String get stayManagedByYou => 'останете управлявани от вас.';

  @override
  String get stayOnTheCall => 'Остани на разговора';

  @override
  String get stayedQuiet => 'Остана тихо';

  @override
  String get steering => 'КОРМИЛНО УПРАВЛЕНИЕ';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'СТЪПКА $arg1 ОТ $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Стъпки $arg1';
  }

  @override
  String get stop => 'Спри';

  @override
  String get stop2 => 'Спри (⌘.)';

  @override
  String get stopManaging => 'Спрете да управлявате';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Спиране на управлението на $arg1?';
  }

  @override
  String get stopRun => 'Спрете да бягате';

  @override
  String get stopSpeaking => 'Спри да говориш';

  @override
  String get stoppedBeforeCompletion => 'Спряно преди завършване';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'StopTelecomCallRouting грешка: $arg1';
  }

  @override
  String get storage => 'Съхранение';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'съхранявани криптирани и използвани само за вашите собствени изпълнения.';

  @override
  String get storedMetrics => 'Съхранени показатели';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Съхранява само сесийния ключ на Bitwarden, шифрован на този сървър, така че връзките оцеляват след рестартиране. Можете да го заключите по всяко време.';

  @override
  String get strong => 'Силен';

  @override
  String get strongPassword => 'Силна парола.';

  @override
  String get subAgent => 'Подагент';

  @override
  String get subagentUpdate => 'Актуализация на субагента';

  @override
  String get subagentUpdate2 => 'Актуализация на субагента.';

  @override
  String get successRate => 'Успеваемост';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Предложения: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Обобщете последното ми бягане';

  @override
  String get supportUrl => 'URL адрес за поддръжка';

  @override
  String get supportedRainStartSnowStartWind =>
      'Поддържани: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Превключете агент';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Символните връзки не са разрешени в пътеките на NeoAgent Workspace.';

  @override
  String get syncNow => 'Синхронизиране сега';

  @override
  String get synologyChat => 'Чат на Synology';

  @override
  String get systemPrivacySettings => 'Системни настройки за поверителност';

  @override
  String get tableInfoUsers => 'Информация за таблица (потребители)';

  @override
  String get tagsOnly => 'Само етикети';

  @override
  String get tasks => 'Задачи';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Задачите се изпълняват сами и ви изпращат съобщения с ';

  @override
  String get teach => 'Учете';

  @override
  String get teachingInProgress => 'Преподаването в ход';

  @override
  String get team => 'Екип';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Екипните връзки никога не правят никого администратор на сървър. Администраторите управляват ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Екипни пространства, стаи, канали и общности на живо.';

  @override
  String get teamsMessageReceived => 'Съобщението на екипите е получено';

  @override
  String get templates => 'Шаблони';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Временните инсталационни файлове ще бъдат изчистени по-късно.';

  @override
  String get tenantId => 'ID на наемател';

  @override
  String get testConnection => 'Тестова връзка';

  @override
  String get testConnection2 => 'Тестова връзка';

  @override
  String get textChat => 'Текст и чат';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'които добавиха свой собствен ключ, продължават да го използват.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Този имейл вече принадлежи на съществуващ акаунт. Първо влезте, след това свържете Google от настройките на акаунта.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Този имейл вече е свързан с друг акаунт.';

  @override
  String get thatQrCodeIsNotA =>
      'Този QR код не е заявка за влизане в NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Този QR код не е заявка за сдвояване на NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Този ключ за сигурност вече е регистриран в този акаунт.';

  @override
  String get theAddress => 'Адресът';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Адресът на вашия BlueBubbles сървър.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Адресът, който хората и доставчиците на OAuth използват за достигане ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Агентът чете пъти, което споменавате, и изпълнява планирани задачи в тази часова зона.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Агентът ще попита преди всеки чувствителен инструмент, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Агентът ще пренебрегне това умение.';

  @override
  String get theAppCouldNotReachThis =>
      'Приложението не можа да достигне до това внедряване на NeoAgent. Проверете вашата мрежова връзка или потвърдете, че URL адресът на услугата е правилен.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Браузърът блокира заявка до $arg1 поради правилата за сигурност на съдържанието.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Браузърът блокира изисквана заявка поради правилата за сигурност на съдържанието.';

  @override
  String get theCloudWorkspace => 'облачното работно пространство';

  @override
  String get theComputerCouldNotStart => 'Компютърът не може да стартира';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Компютърът се нуждае от повече свободно дисково пространство на хоста NeoAgent. Освободете малко място и опитайте отново.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Работното време на компютъра се нуждае от ремонт. Стартирайте NeoAgent Doctor, след което опитайте отново.';

  @override
  String get theConnectionTestFailed => 'Тестът на връзката е неуспешен.';

  @override
  String get theDesktopDidNotStart => 'Работният плот не стартира';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Откритият NeoAgent върна непълни данни за самоличност.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Откритият NeoAgent използва неподдържан протокол за настройка.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Откритата услуга не е NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Изтегленото време за изпълнение на NeoAgent не премина проверка.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Уеб кукичката на Google Chat space, в която този агент трябва да публикува.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Инсталаторът вече не е наличен.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Интерактивният работен плот на Linux е достъпен в уеб приложението NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Интрото не е налично на това устройство.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Най-новото работи във всеки акаунт.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Последният прозорец за синхронизиране завърши $arg1 и не намери нови записи на Health Connect. Съхранените показатели по-долу идват от по-ранни синхронизации.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Графичната сесия на Linux не работи.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Гласовият модел на живо не отговори. Опитайте отново.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Локалната команда NeoAgent излезе с код $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Времето за изчакване на локалната команда NeoAgent изтече.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Локалното време за изпълнение на NeoAgent се нуждае от ремонт.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Локалното време за изпълнение се нуждае от ремонт ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Домашната директория на локалния потребител е недостъпна.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Пощенският акаунт NeoAgent изпраща потвърждения за регистрация, влизане ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Главният агент се създава автоматично, когато е необходимо.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Съответстващото време за изпълнение на NeoAgent липсва в тази версия.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Най-важната входяща уебкукичка, в която този агент трябва да публикува.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Моделите, между които Smart Selector маршрутизира автоматично.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Изтеглянето на бекенда на NeoAgent не съответства на неговия манифест.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Бекенд изтеглянето на NeoAgent беше непълно.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Бекендът на NeoAgent на този компютър не отговаря на порт ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Бекендът на NeoAgent не можа да бъде изтеглен.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Бекендът на NeoAgent отне твърде много време, за да отговори за $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'Внедряването на NeoAgent отговори с HTTP 402 вместо нормалното 401 за невалидни идентификационни данни. Проверете правилата за обратен прокси, шлюз за удостоверяване или свързани с плащането на този сървър.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'Внедряването на NeoAgent отговори с HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'Внедряването на NeoAgent отговори с HTTP 402. Проверете правилата за обратен прокси, шлюз за удостоверяване или свързани с плащането на този сървър.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Екземплярът на NeoAgent, към който е свързано това приложение.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Услугата за освобождаване на NeoAgent върна невалидни данни.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Метаданните на артефакта по време на изпълнение на NeoAgent са невалидни.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Манифестът за изпълнение на NeoAgent не премина проверка на подпис.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Манифестът за изпълнение на NeoAgent няма артефакти.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Сигнатурата на манифеста за изпълнение на NeoAgent е невалидна.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Паролата, която сте задали в BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Хората, които управлявате, остават с вас.';

  @override
  String get theProviderAnswers => 'доставчикът отговаря.';

  @override
  String get theQueryReturnedNoRows => 'Заявката не върна нито един ред.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Заявеният дисплей на работния плот не е наличен.';

  @override
  String get theRest => 'останалото.';

  @override
  String get theRestEndpointForYourSignal =>
      'Крайната REST точка за вашия екземпляр на signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Бягането е на пауза, докато не отговорите.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Бягането започва в определения час.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Средата за изпълнение е лек работен плот на Debian Linux с Chromium, PCManFM, Mousepad, LXTerminal, Python, Git и стандартни инструменти от командния ред. Капацитетът му се управлява от хоста NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Регистрацията на ключа за сигурност не можа да бъде стартирана.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'сървърът пази само пръстов отпечатък от него.';

  @override
  String get theServerOnThisComputerIs => 'Сървърът на този компютър не работи';

  @override
  String get theServerReportedNoHealthChecks =>
      'Сървърът не съобщи за проверки на здравето.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Телефонният номер на Signal, който този бот използва.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Входящият webhook на Teams, в който този агент трябва да публикува.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Двуфакторното предизвикателство изтече. Влезте отново.';

  @override
  String get theTwoFactorCodeIsNot => 'Двуфакторният код не е валиден.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Провереният пакет за изпълнение не можа да бъде маркиран като изпълним.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'В проверения пакет за изпълнение липсват необходимите файлове.';

  @override
  String get theWebAppCouldNotReach =>
      'Уеб приложението не можа да достигне до бекенда на NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Уеб приложението не можа да достигне до бекенда на NeoAgent в $arg1. Проверете конзолата на браузъра и конфигурацията на обратен прокси/мрежа.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'себе си; операторът на сървъра първо премахва администратора с ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Тези канали мълчат. За да ги чуете отново, добавете ги под Кой може да изпраща съобщения за тази платформа.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Тези списъци не са задължителни, освен ако раздел по-горе не е зададен само като одобрен.';

  @override
  String get thesePeopleAnywhere => 'Тези хора навсякъде';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Тези хора могат да изпращат съобщения на $arg1 в лични чатове и във всяка група, която споделят.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Тези хора могат да изпращат съобщения $arg1 един към един. Това не им позволява да говорят в групи.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Тези хора могат да изпращат съобщения само до $arg1 в групата, която сте избрали.';
  }

  @override
  String get thesePeopleInOneGroup => 'Тези хора, в една група';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'тези превключватели, никога вашите чатове, спомени или файлове.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Този акаунт ще отключи NeoAgent на тази машина.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Този агент може да делегира на всеки отговарящ на условията получаващ агент.';

  @override
  String get thisAgentIsUsingAServer =>
      'Този агент използва управляван от сървъра Trello API ключ. Трябва само да упълномощите токен за акаунт по-долу.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'На тази компилация не е разрешено да общува с това внедряване на NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Този код принадлежи на различен сървър на NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Този работен плот е свързан';

  @override
  String get thisDevice => 'Това устройство';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Това устройство: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Това устройство не може да регистрира ключове за сигурност. Отворете NeoAgent в браузър през HTTPS, за да добавите такъв.';

  @override
  String get thisDeviceUnavailable => 'Това устройство — недостъпно';

  @override
  String get thisFileHasNoContent => 'Този файл няма съдържание.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Това скрива \"$arg1\" от маршрутизиране и избор.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Понастоящем тази интеграция поддържа един свързан акаунт на агент. Отворете отново настройката, за да я замените.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Тази интеграция вече не е налична.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Това въведение е предназначено за пейзажно възпроизвеждане на цял екран.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Това е управлявано внедряване. Неговият оператор се разгръща ';

  @override
  String get thisMayTakeAMoment => 'Това може да отнеме малко време.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Този MCP сървър вече не е конфигуриран.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Тази памет ще бъде премахната за постоянно.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Тази компилация на NeoAgent не е конфигурирана да проверява времената за изпълнение на бекенда.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Това изтрива завинаги всичките ви данни и не може да бъде ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Това изтрива завинаги акаунта и всичко, което притежава: ';

  @override
  String get thisPersonAnywhere => 'Този човек, навсякъде';

  @override
  String get thisPersonInOneGroup => 'Този човек, в една група';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Тази QR заявка за влизане е изтекла. Генерирайте нов код и опитайте отново.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'тази qr заявка за влизане е изтекла';

  @override
  String get thisQrLoginRequestIsStill =>
      'Тази QR заявка за влизане все още чака одобрение.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Тази QR заявка за влизане вече беше използвана.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Това премахва настройката на Home Assistant и свързаното копие за този агент.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Това премахва URL адреса на бекенда на NeoRecall и всички свързани акаунти на NeoRecall за този агент.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Това премахва URL адреса на Nextcloud и всички свързани Nextcloud акаунти за този агент.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Това премахва настройката на Trello и свързаните акаунти за този агент.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Това изисква удостоверена сесия на същия NeoAgent сървър.';

  @override
  String get thisRunDidNotProduceA =>
      'Това изпълнение не доведе до отговор от потребителя.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Това бягане няма записани данни за стъпките.';

  @override
  String get thisServer => 'този сървър.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Този сървър не съобщава за настройки на доставчика.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Това умение вече не е инсталирано.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Тази задача все още няма завършено изпълнение, така че все още започва от ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Тази задача ще се изпълни само когато натиснете Изпълни сега.';

  @override
  String get thisWeek => 'Тази седмица';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Това ще импортира отговора в $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Това ще премахне \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Това ще премахне \"$arg1\" от списъка със сървъри.';
  }

  @override
  String get time => 'време';

  @override
  String get timeZone => 'часова зона';

  @override
  String get timeZone2 => 'Часова зона';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Времето изтече $arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[Часова зона] Не може да се изброят часовите зони: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Не можа да се прочете часовата зона на устройството: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Не можа да се запази часовата зона на устройството: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'към $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'за да използвате сървъра по подразбиране.';

  @override
  String get today => 'Днес';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Токен бюджет за @$arg1. Оставете поле празно ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Токен бюджет за всеки акаунт без собствена замяна. Оставете а ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'токен бюджетен лимит 4 часа седмична квота потребител';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'токен бюджетен лимит 4 часа седмична квота глобално';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Използването на токени не е налично на тази версия на сървъра.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Токени, които всеки акаунт може да използва за 4 часа.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Токени, които всеки акаунт може да използва за 7 дни.';

  @override
  String get tokensPerDay => 'Токени на ден';

  @override
  String get tokensPerRun => 'Жетони за изпълнение';

  @override
  String get tokensToday => 'Токени днес';

  @override
  String get tokensUsed => ' използвани токени';

  @override
  String get tomorrowPrep => 'Утре подготовка';

  @override
  String get tooManyAttempts => 'твърде много опити';

  @override
  String get tooManySignInAttemptsPlease =>
      'Твърде много опити за влизане. Моля, изчакайте и опитайте отново.';

  @override
  String get tool => 'Инструмент';

  @override
  String get toolApproval => 'Одобрение на инструмента';

  @override
  String get toolApprovalRequired => 'Изисква се одобрение на инструмента';

  @override
  String get toolCompleted => 'Инструментът е завършен';

  @override
  String get toolFailed => 'Инструментът е неуспешен';

  @override
  String get toolPermissions => 'Разрешения за инструмента';

  @override
  String get toolStarted => 'Инструментът стартира';

  @override
  String get tools => 'Инструменти';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Инструменти, които не са вградени в NeoAgent, включително свързани MCP сървъри и персонализирани доставчици на инструменти.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Предлагани инструменти ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Инструменти, които управляваният акаунт може да използва';

  @override
  String get topUsers => 'Топ потребители';

  @override
  String get topUsersAndRecentRuns =>
      'Водещи потребители и скорошни изпълнения';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Общо: $arg1 токени в сериите на $arg2';
  }

  @override
  String get totalRuns => 'Общо бягания';

  @override
  String get totalTokens => 'Общо токени';

  @override
  String get totalUsers => 'Общо потребители';

  @override
  String get transcript => 'Препис';

  @override
  String get transcript2 => 'ПРЕПИС';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Неуспешна транскрипция: $arg1';
  }

  @override
  String get transfer => 'Трансфер';

  @override
  String get trelloApiKey => 'API ключ на Trello';

  @override
  String get trelloApiKeyIsRequired => 'Изисква се API ключ на Trello.';

  @override
  String get trelloSetup => 'Настройка на Trello';

  @override
  String get triggerType => 'Тип тригер';

  @override
  String get tryABroaderSearchLikeModels =>
      'Опитайте по-широко търсене като модели, браузър или глас.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Опитайте име на доставчик, „имейл“, „ограничения“, „актуализация“ или „дневници“.';

  @override
  String get tryAgain => 'Опитайте отново';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Опитайте отново. Ако това продължава да се случва, стартирайте NeoAgent Doctor, за да проверите времето за изпълнение на компютъра.';

  @override
  String get tryAgainInAMoment => 'Опитайте отново след малко.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Опитайте отново или стартирайте NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Опитайте друго търсене, свържете платформа за съобщения или въведете ръчно ID на дестинация.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Включете група, ако $arg1 трябва също да чете съобщения, които не го маркират.';
  }

  @override
  String get turnOffComputer => 'Изключете компютъра';

  @override
  String get turnOffOnlyForAMail =>
      'Изключете само за пощенски сървър със самоподписан сертификат.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Включете, ако Signal трябва да продължи да търси входящи чатове.';

  @override
  String get turnTaking => 'вземане на ред';

  @override
  String get turnTakingModel => 'Поредният модел';

  @override
  String get turnTakingOff => 'Завъртане-излитане';

  @override
  String get turnThisOffToKeepThis =>
      'Изключете това, за да запазите този агент напълно отделен от другите агенти.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Изключено от $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Изключено от $arg1, който управлява този акаунт. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Изключено за вас от $arg1 — само те могат да го променят';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Изключен за вас, така че не можете да го раздадете';

  @override
  String get twitchChatOverIrc => 'Twitch чат през IRC';

  @override
  String get twoFactorAuthentication => 'Двуфакторна автентификация';

  @override
  String get twoFactorChallengeExpired =>
      'двуфакторното предизвикателство изтече';

  @override
  String get twoFactorCode => 'двуфакторен код';

  @override
  String get twoFactorSignInCompletedBut =>
      'Двуфакторното влизане е завършено, но NeoAgent не успя да запази сесията на браузъра. Моля, влезте отново.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Влизане в две стъпки (само ако е активирано)';

  @override
  String get type => 'Тип';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Въведете $arg1 за потвърждение';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'тип текст не се поддържа на тази платформа.';

  @override
  String get typedInTheBrowser => 'Написано в браузъра';

  @override
  String get typedText => 'Набран текст';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'не може да намери среда за изпълнение на java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Не могат да се отворят настройките за време на тази компилация.';

  @override
  String get unableToOpenWiFiSettings =>
      'Не могат да се отворят настройките за Wi-Fi на тази компилация.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Не може да се запази избраният дисплей на работния плот.';

  @override
  String get unclearWhoItWasFor => 'Неясно за кого е било';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'отменено. Въведете вашето потребителско име, за да потвърдите.';

  @override
  String get unknownAccount => 'Неизвестен акаунт';

  @override
  String get unknownAgent => 'Неизвестен агент';

  @override
  String get unknownBrowser => 'Неизвестен браузър';

  @override
  String get unknownDevice => 'Неизвестно устройство';

  @override
  String get unknownError => 'неизвестна грешка';

  @override
  String get unknownLocalComputerPermission =>
      'Неизвестно разрешение за локален компютър.';

  @override
  String get unknownLocation => 'Неизвестно местоположение';

  @override
  String get unknownPublishTime => 'Неизвестен час на публикуване';

  @override
  String get unknownSize => 'Неизвестен размер';

  @override
  String get unlink => 'Прекратете връзката';

  @override
  String get unreadOnly => 'Само непрочетени';

  @override
  String get unsavedChanges => 'Незапазени промени';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Неподдържана придружаваща команда за настолен компютър: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Неподдържан метод: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Необичайни сигнали за влизане';

  @override
  String updateArg1(Object? arg1) {
    return 'Актуализирайте $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Актуализирайте записите в основната памет от импортирането.';

  @override
  String get updateNow => 'Актуализирайте сега';

  @override
  String get updateReady => 'Актуализацията е готова';

  @override
  String get updateSetup => 'Актуализиране на настройките';

  @override
  String get updateTheAccessListToAllow =>
      'Актуализирайте списъка за достъп, за да позволите отговори.';

  @override
  String get updateTheServer => 'Актуализиране на сървъра?';

  @override
  String get updateTheServer2 => 'Актуализирайте сървъра';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Актуализирайте часовата зона автоматично от устройството, което използвате.';

  @override
  String updatedArg1(Object? arg1) {
    return 'актуализиран $arg1';
  }

  @override
  String get updates => 'Актуализации';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Актуализациите не са конфигурирани за тази компилация.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'актуализации, така че самоактуализацията и промените в каналите са изключени тук.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'ъпгрейд актуализация сега пуска стабилна бета версия на канала';

  @override
  String get usageAnalytics => 'Анализ на използването';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Сигнали за употреба и здраве, които помагат да се обясни текущото поведение по време на изпълнение, без първо да се рови в регистрационни файлове.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Използването се нулира напълно в $arg1';
  }

  @override
  String get usageLeaderboard => 'класация за използване';

  @override
  String get usageLimits => 'Използване и ограничения';

  @override
  String get usageLimits2 => 'Използване и ограничения';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Използвайте 8+ знака. По-дългите пароли работят добре.';

  @override
  String get useADateAndTimeFor =>
      'Използвайте дата и час, например 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Използвайте име, телефонен номер или ID за чат.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Използвайте URL на NeoRecall, до който сървърът на NeoAgent може да достигне. PUBLIC_URL на NeoAgent също трябва да бъде достъпен от този браузър за обратното извикване на OAuth.';

  @override
  String get useANewPasswordWithAt => 'Използвайте нова парола с поне 8 знака.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Използвайте URL адрес на Nextcloud, до който сървърът на NeoAgent може да достигне, например https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast => 'Използвайте парола с поне 8 знака.';

  @override
  String get useASecureConnectionTls => 'Използвайте защитена връзка (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Използвайте приложение за удостоверяване като Authy, 1Password или Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Използвайте поне 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Максимална памет на компютър (MB)';

  @override
  String get maxVcpusPerComputer => 'Макс vCPU на компютър';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Най-малко $arg1. Компютрите получават по-малко, когато хостът е зает.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Максималната памет трябва да бъде поне $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Използвайте поне 8 знака.';

  @override
  String get useDefault => 'Използвайте по подразбиране';

  @override
  String get useDefaultChannel => 'Използвайте канал по подразбиране';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Използване по подразбиране (NeoAgent Workspace)';

  @override
  String get useFor => 'Използвайте за';

  @override
  String get useManualDestination => 'Използвайте ръчна дестинация';

  @override
  String get useOrDoTheSameFor =>
      'използвайте или направете същото за вашите съотборници.';

  @override
  String get usePerCategorySettingsBelow =>
      'Използвайте настройките по категория по-долу.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Използване на настройките по подразбиране ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Използвайте сървъра на този компютър';

  @override
  String get useTheseForContextIfA =>
      'Използвайте ги за контекст. Ако локален URI адрес не е директно достъпен от сървъра, помолете ме да предоставя файла чрез достъпно работно пространство.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Използвайте това за оркестроващи агенти. Оставете за изолирани работни ботове, които трябва сами да завършат директните съобщения.';

  @override
  String get useTlsFromTheStartOf =>
      'Използвайте TLS от началото на връзката, обикновено на порт 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Използвайте свой собствен API ключ за доставчик или свържете персонализиран ';

  @override
  String get usedByEveryAccountOnThis =>
      'Използва се от всеки акаунт на този сървър, който няма ключ ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Използва се за проверка дали входящите Slack събития са истински.';

  @override
  String get userSummary => 'Потребителско резюме';

  @override
  String get username => 'Потребителско име';

  @override
  String get usernameOrEmail => 'Потребителско име или имейл';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'потребители хора търсене имейл потребителско име администратор значка управляван екип';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Използва модела на чат, конфигуриран в Настройки';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Използване на инсталираната среда за изпълнение NeoAgent';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Обикновено изглежда като @bot:matrix.org';

  @override
  String get validEmail => 'валиден имейл';

  @override
  String get value => 'Стойност';

  @override
  String get vaultLocked => 'Трезорът е заключен';

  @override
  String get vaultOperationFailed => 'Операцията на хранилището е неуспешна.';

  @override
  String get verification => 'Проверка';

  @override
  String verificationArg1(Object? arg1) {
    return 'Проверка: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'проверка: $arg1';
  }

  @override
  String get verificationCompleted => 'Проверката е завършена.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Статус на проверка: $arg1';
  }

  @override
  String get verifiedTheResult => 'Проверен резултатът';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Проверка на изтегленото време за изпълнение';

  @override
  String get versionAndUptime => 'Версия и ъптайм';

  @override
  String versionArg1(Object? arg1) {
    return 'Версия $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Версията $arg1 е инсталирана, но $arg2 все още работи.';
  }

  @override
  String get videoLinks => 'Видео връзки';

  @override
  String get viewDesktop => 'Преглед на работния плот';

  @override
  String get viewLastRun => 'Вижте последното изпълнение';

  @override
  String get viewLogs => 'Преглед на регистрационни файлове';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm изображение памет cpu qemu време за изпълнение';

  @override
  String get voice => 'глас';

  @override
  String get voiceAssistant => 'Гласов асистент';

  @override
  String get voiceCall => 'ГЛАСОВО ОБАЖДАНЕ';

  @override
  String get voiceCall2 => 'Гласово повикване';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'гласово повикване gpt-live Gemini модел на живо реч в реално време';

  @override
  String get voiceCallsRunOnALive =>
      'Гласовите повиквания се изпълняват на жив модел говор към говор със същата личност, памет и чат история като NeoAgent. Той отговаря незабавно и предава реална работа на нормалния агент, който продължава да работи във фонов режим.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'api ключ за транскрипция на гласова бележка';

  @override
  String get voiceNotesAndDictation => 'Гласови бележки и диктовки';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Възпроизвеждането на глас не е налично на това устройство.';

  @override
  String get voiceReplyModel => 'Модел на гласов отговор';

  @override
  String get waitingForApproval => 'Очаква се одобрение: ';

  @override
  String get waitingForCode => 'Изчакване на код';

  @override
  String get waitingForInput => 'Изчакване на въвеждане';

  @override
  String get waitingForServerOrFlutterLog =>
      'Изчакване на изходен файл от сървъра или Flutter...';

  @override
  String get waitingForTaskEvents => 'Изчакване на събития със задачи...';

  @override
  String get waitingForYou => 'чакам те';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Исках отговор от $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Иска да говори с вас · ${arg1}s';
  }

  @override
  String get weak => 'слаб';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Време, календар и приоритети преди началото на деня ви.';

  @override
  String get weatherEvent => 'Времето Събитие';

  @override
  String get web => 'Мрежа';

  @override
  String get webBrowser => 'Уеб браузър';

  @override
  String get webSearchApiKey => 'api ключ за уеб търсене';

  @override
  String get webhookOrRestChannelPosting =>
      'Публикуване на Webhook или REST канал';

  @override
  String get webhookSecret => 'Тайна за уеб кукичка';

  @override
  String get webhookUrlCopied => 'URL адресът на уебкукичката е копиран';

  @override
  String get weekdays => 'Делнични дни';

  @override
  String get weekdays0730 => 'Делнични дни · 07:30ч';

  @override
  String get weekdays1800 => 'Делнични дни · 18:00ч';

  @override
  String get weekly => 'Ежеседмично';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Седмичен лимит $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Седмичен лимит (токени)';

  @override
  String get weeklyReview => 'Седмичен преглед';

  @override
  String get weeklyUsage => 'Седмична употреба';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Тегло $arg1 записи';
  }

  @override
  String get welcomeToNeoagent => 'ДОБРЕ ДОШЛИ В NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Добре дошли\nв NeoAgent';

  @override
  String get whatAreYouAdding => 'Какво добавяте?';

  @override
  String get whatIsOnTomorrow => 'Какво има утре?';

  @override
  String get whatShouldNeoagentLearn => 'Какво трябва да научи NeoAgent?';

  @override
  String get whatShouldWeBuild => 'Какво да построим?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Това, което вие и NeoAgent казвате, се появява тук и в чата.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Получено е лично съобщение в WhatsApp';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Когато изберете само одобрени, добавете хора или групи по-долу.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Къде този агент трябва да изпраща отговори.';

  @override
  String get whoCanMessage => 'Кой може да изпраща съобщения';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Кой може да изпраща съобщения на $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Кой може да изпрати $arg1 съобщение един към един.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Кой може да говори с $arg1 в група, канал или стая.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'който управлява този акаунт е изключен: ';

  @override
  String get whoManagesWhom => 'Кой кого управлява';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Който приеме връзка, се присъединява към вашия екип само с инструментите, които има ';

  @override
  String get wholeGroup => 'Цялата група';

  @override
  String get wholeGroups => 'Цели групи';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Защо $arg1 отговори или мълчи в групите $arg2.';
  }

  @override
  String get windowsApp => 'Приложение за Windows';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Работен акаунт';

  @override
  String get workOnAProjectWithNeoagent => 'Работа по проект с NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Работен процес: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Работа в $arg1 на облачен компютър. NeoAgent чете и редактира файлове там и може да изпълнява команди и браузър.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Работи във фонов режим: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Конфигурация на работното пространство и сигурност на акаунта на едно място.';

  @override
  String get workspaceFiles => 'Файлове на работното пространство';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Работно пространство, модели и контроли за диагностика.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Замяната на работното пространство трябва да бъде абсолютен път.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Написа $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttprequest грешка';

  @override
  String get yesterday => 'Вчера';

  @override
  String get youAreInControl => 'Вие контролирате';

  @override
  String get youCanFollowAlongOnThe => 'Можете да следвате на работния плот.';

  @override
  String get youCanLeaveATeamAt =>
      'Можете да напуснете екип по всяко време; вашите собствени настройки се прилагат отново.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Можете да напуснете по всяко време от страницата на екипа.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Вие решавате кои инструменти може да използва вашият агент в Настройки › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Все още не управлявате никого. Създайте връзка за покана по-долу и ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Имате незапазени настройки. Какво бихте искали да правите?';

  @override
  String get youReOnYourOwnYou =>
      'Вие сте сами: вие решавате кои инструменти може да използва вашият агент. Ако ';

  @override
  String get yourAccountAndUsageOnA =>
      'вашия акаунт -- и използване на модел, поддържан от вашия собствен ключ ';

  @override
  String get yourAccountHasBeenDeleted => 'Вашият акаунт е изтрит.';

  @override
  String get yourAgentWillBeAllowed => 'Вашият агент ще има право:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Вашите приложения и файлове са запазени.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Вашите приложения и файлове остават запазени.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Вашият $arg1 ключ';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Вашият помощен слой за улавяне, контекст и действие.';

  @override
  String get yourComputerIsAsleep => 'Вашият компютър е заспал';

  @override
  String get yourComputerIsOff => 'Вашият компютър е изключен';

  @override
  String get yourComputerIsReady => 'Вашият компютър е готов';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Текущата ви парола е неправилна.';

  @override
  String get yourData => 'Вашите данни';

  @override
  String get yourDataExportWasCopiedTo =>
      'Експортираните ви данни бяха копирани в клипборда.';

  @override
  String get yourDesktopIsReady => 'Вашият работен плот е готов';

  @override
  String get yourLinuxComputer => 'Вашият Linux компютър';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Вашето местоположение никога не се проследява непрекъснато или се съхранява на нашите сървъри. Използваме го само локално, за да проверяваме вашите активни задачи.';

  @override
  String get yourManager => 'вашият мениджър';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Вашият URL адрес на най-важния сайт, ако използвате REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Вашата сесия е изтекла или не е била запазена от браузъра. Моля, влезте отново.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Вашата сесия изтече. Моля, влезте отново.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Вашето потребителско име или парола са неправилни.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID, …';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Преглед';

  @override
  String get sectionDiagnostics => 'Диагностика';

  @override
  String get sectionVolume => 'Обем';

  @override
  String get sectionSession => 'Сесия';

  @override
  String get sectionDeliverable => 'Доставимо';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Локалното време за изпълнение все още не е написало лог файл.';

  @override
  String get thisComputer => 'Този компютър';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Бета инсталира най-новия предварителен бекенд. Очаквайте груби ръбове.';

  @override
  String get copiedFinalResponse => 'Окончателният отговор е копиран';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Последният отговор се появява тук, когато изпълнението приключи.';

  @override
  String get waitingForTheFirstStep => 'В очакване на първата стъпка…';

  @override
  String get loadingPrompt => 'Подканата се зарежда...';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Не беше уловен окончателен отговор за това изпълнение.';

  @override
  String get readyToSignIn => 'Готов за влизане';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Превключете на „По подразбиране“ или „Винаги питай“, за да активирате отново проверките за одобрение.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Изпратете актуализация на управлението или следваща бележка за текущото изпълнение...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Няма мрежова връзка. NeoAgent ще се свърже отново, когато устройството отново е онлайн.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Приложена е последната актуализация на кормилното управление към текущото изпълнение.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Подготвя се частната гласова сесия…';

  @override
  String get preparingYourComputer => 'Подготовка на вашия компютър';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent изтегля и подготвя защитената Linux система. Това се случва само първия път.';

  @override
  String get moreFreeSpaceIsNeeded =>
      'Необходимо е повече свободно пространство';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Освободете малко дисково пространство на хоста NeoAgent, след което опитайте отново. Вашите съществуващи компютърни данни са в безопасност.';

  @override
  String get androidReady => 'Готов за Android';

  @override
  String get startingAndroid2 => 'Android се стартира...';

  @override
  String get androidStopped => 'Android спря';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Първото стартиране изтегля Android SDK и системния образ, което може да отнеме няколко минути.';

  @override
  String get androidIsStopped => 'Android е спрян';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Стартирайте управляваната среда на Android, когато имате нужда от нея.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Оставете NeoAgent да работи на този компютър';

  @override
  String get firstTimeSetupIsInProgress =>
      'Извършва се настройка за първи път.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent може да използва разрешения от вас достъп.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Освободете място за съхранение на хоста и опитайте отново.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Започнете, когато искате NeoAgent да ви помогне тук.';

  @override
  String get systemPermissionMissing => 'Липсва системно разрешение';

  @override
  String get connectingThisDevice => 'Свързване на това устройство';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Защитената локална връзка се установява.';

  @override
  String get recordingYourDemonstration => 'Записване на вашата демонстрация';

  @override
  String get noErrorsInTheRecentLog => 'Няма грешки в последния дневник.';

  @override
  String get loadingAccounts => 'Профилите се зареждат...';

  @override
  String get neverSignedIn => 'Никога не съм влизал';

  @override
  String get emptyUsesTheServerDefault =>
      'Empty използва сървъра по подразбиране.';

  @override
  String get followTheSelectedSession => 'Следвайте избраната сесия';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Режимът на план инспектира само. Превключете в режим на агент, за да позволите на NeoAgent да редактира файлове.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Изисква се за добавяне или промяна на имейл адреса на вашия акаунт.';

  @override
  String get confirmNewPassword => 'Потвърдете новата парола';

  @override
  String get passwordChanged => 'Паролата е променена.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Тази заявка вече е използвана.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Тази заявка е изтекла. Помолете другото устройство да генерира нов код.';

  @override
  String get startQuickstart => 'Стартирайте Quickstart';

  @override
  String get createYourAccount => 'Създайте своя акаунт';

  @override
  String get showWorkAsSummaries => 'Показване на работата като резюмета';

  @override
  String get tokensUsedByTheLatestRun =>
      'Токени, използвани от последното изпълнение';

  @override
  String get listedTheWorkspaceRoot =>
      'Изброи корена на работното пространство';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Все още няма налични официални интеграции.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Все още няма конфигурирани MCP сървъри. Добавете такъв, за да разкриете неговите инструменти.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Добавете MCP сървър или инсталирайте умение, за да започнете.';

  @override
  String get setUp => 'Настройка';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Оставете празно, за да запазите съхранената стойност';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Това премахва адреса за всеки акаунт на този сървър.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Просто говори. Можете да прекъснете по всяко време. Докоснете за заглушаване.';

  @override
  String get tapAgainWhenYouAreDone => 'Докоснете отново, когато сте готови.';

  @override
  String get workingOnATaskInTheBackground =>
      'Работа по задача във фонов режим.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Реч към реч със същата памет, инструменти и хронология на чата като NeoAgent.';

  @override
  String get checkLink => 'Проверете връзката';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'На вашия агент няма да бъде позволен нито един от контролираните инструменти.';

  @override
  String get notYoursToChange => 'Не е твое да променяш';

  @override
  String get setByYou => 'Зададен от вас';

  @override
  String get noTools => 'Без инструменти';

  @override
  String get untitledLink => 'Линк без заглавие';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Спира да работи, след като един човек го изкупи.';

  @override
  String get theOperator => 'Операторът';

  @override
  String get smartSelectorOn => 'Интелигентен селектор включен';

  @override
  String get startASessionToBegin => 'Стартирайте сесия, за да започнете';

  @override
  String get steerTheActiveRun => 'Насочвайте активното бягане...';

  @override
  String get describeWhatToPlan => 'Опишете какво да планирате...';

  @override
  String get stopDictation => 'Спрете диктовката';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Съобщенията управляват текущото изпълнение · ⌘↵ изпращане · ⌘. спрете';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Режимът на план инспектира само; нищо не се променя, докато не приложите · ⌘↵ изпрати';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Агент редактира работното пространство. План само инспектира.';

  @override
  String get defaultModel => 'Модел по подразбиране';

  @override
  String get openingScanner => 'Скенерът се отваря...';

  @override
  String get theAgentCanUseThisSkill => 'Агентът може да използва това умение.';

  @override
  String get allSelected => 'Всички избрани';

  @override
  String get addCoreMemoryEntry => 'Добавяне на запис за основна памет';

  @override
  String get channelId => 'ID на канала';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Създадените от AI и неопределените задачи използват текущата настройка по подразбиране.';

  @override
  String get waitingForRunEvents => 'Изчакване на събития за изпълнение...';

  @override
  String get hideSteps => 'Скриване на стъпки';

  @override
  String get commitTheActiveLiveCapture =>
      'Ангажирайте активното заснемане на живо';

  @override
  String get stopCaptureAndSubmit => 'Спрете заснемането и изпратете';

  @override
  String get clickTheMicToStartSpeaking =>
      'Кликнете върху микрофона, за да започнете да говорите';

  @override
  String get connectACustomEndpoint => 'Свържете персонализирана крайна точка';

  @override
  String get hostedProvider => 'хостван доставчик.';

  @override
  String get muted => ' • заглушен';

  @override
  String get addWhoCanMessage => 'Добавете кой може да изпраща съобщения';

  @override
  String get joinsGroupConversations => 'Присъединява се към групови разговори';

  @override
  String get label1PersonOrGroupAdded => 'Добавен е 1 човек или група';

  @override
  String get inProgress => 'В ход';

  @override
  String get waitingForUpdateJobOutput =>
      'Изчакване на резултат от задачата за актуализация...';

  @override
  String get taskTrigger => 'Задействане на задача';

  @override
  String get bearerToken => 'Токен на носител';

  @override
  String get bearerToken2 => 'Токен на носител';

  @override
  String get notRecorded => 'Не е записано';

  @override
  String get sessionCookie => 'Сесийна бисквитка';

  @override
  String get neverUsed => 'Никога не е използван';

  @override
  String get linkedRecently => 'Свързан наскоро';

  @override
  String get notUsedYet => 'Все още не е използван';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Един или повече акаунти са изтекли. Свържете се отново, за да възстановите достъпа. Ако това продължава, вашето приложение Google Cloud OAuth може да е в тестов режим — публикувайте го в Production в Google Cloud Console, за да получите дълготрайни токени.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault е свързан и достъпен след рестартиране';

  @override
  String get vaultConnectedForThisSession => 'Vault е свързан за тази сесия';

  @override
  String get connectAnotherAccount => 'Свържете друг акаунт';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Поставете заместващ дълготраен маркер за достъп';

  @override
  String get updateInstance => 'Екземпляр за актуализиране';

  @override
  String get pasteAReplacementToken => 'Поставете заместващ токен';

  @override
  String get replaceAccount => 'Замяна на акаунт';

  @override
  String get addAccount => 'Добавяне на акаунт';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Може да делегира на всеки получаващ агент';

  @override
  String get canReceiveDelegatedTasks2 => 'може да получава делегирани задачи';

  @override
  String get noSyncYet => 'Все още няма синхронизация';

  @override
  String get noNewData => 'Няма нови данни';

  @override
  String get syncOnceToSeedYourBackend =>
      'Синхронизирайте веднъж, за да заредите своя бекенд.';

  @override
  String get lastWindowEndIsUnknown =>
      'Краят на последния прозорец е неизвестен.';

  @override
  String get lastNonEmptySync => 'Последна непразна синхронизация';

  @override
  String get stopTranscribe => 'Спри и транскрибирай';

  @override
  String get steeringMode => 'Режим на управление';

  @override
  String get noMessageText => 'Няма текст на съобщение';

  @override
  String get reconnectingToServer => 'Повторно свързване със сървъра...';

  @override
  String get signingIn => 'Влизам...';

  @override
  String get noGroupsFoundYet => 'Все още няма намерени групи';

  @override
  String get onForNewGroupsOnly => 'Включено само за нови групи';

  @override
  String get noGroupsInThisCategory => 'Няма групи в тази категория';

  @override
  String get groupOrChannel => 'Група или канал';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Бележките, които си пишете, започват да се изпълняват и отговорите се приземяват в същия чат. Списъкът с разрешени не се прилага тук.';

  @override
  String get needToReply => 'Трябва да отговорите';

  @override
  String get enter2faCode => 'Въведете 2FA код';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Отворете вашето приложение за удостоверяване и въведете текущия код на NeoAgent.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Вече имате акаунт? влезте';

  @override
  String get serverOnThisComputer => 'Сървър на този компютър';

  @override
  String get showQrCode => 'Показване на QR код';

  @override
  String get createAnotherNeoagentAccount => 'Създайте друг акаунт в NeoAgent.';

  @override
  String get canCoordinateDelegatedWork =>
      'Може да координира делегирана работа';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Архивът за изпълнение на NeoAgent не можа да бъде извлечен.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Архивът за изпълнение на NeoAgent не може да бъде прочетен.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Архивът за изпълнение на NeoAgent съдържа опасен път.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Архивът за изпълнение на NeoAgent съдържа опасна връзка.';

  @override
  String get installingAppPackageOnThePhone =>
      'Инсталиране на пакет с приложения на телефона...';

  @override
  String get dragAndDropAApkOrApks =>
      'Плъзнете и пуснете .apk или .apks файл тук или щракнете, за да прегледате.';

  @override
  String get releaseToInstallThisPackage =>
      'Освободете, за да инсталирате този пакет';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Ключът за сигурност не може да се използва.';

  @override
  String get connecting => 'Свързване...';

  @override
  String get changes => 'Промени';

  @override
  String get runtimeReady => 'Времето за изпълнение е готово';

  @override
  String get saving => 'Запазва се...';

  @override
  String get earlier => 'По-рано';

  @override
  String get monthJan => 'януари';

  @override
  String get monthFeb => 'февр';

  @override
  String get monthMar => 'март';

  @override
  String get monthApr => 'апр';

  @override
  String get monthMay => 'май';

  @override
  String get monthJun => 'юни';

  @override
  String get monthJul => 'юли';

  @override
  String get monthAug => 'авг';

  @override
  String get monthSep => 'септ';

  @override
  String get monthOct => 'окт';

  @override
  String get monthNov => 'ноем';

  @override
  String get monthDec => 'дек';

  @override
  String get steeringWord => 'Кормилно управление';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Това превключва бекенда от канала $arg1 към канала $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Импортирани бисквитки $arg1';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'преди ${arg1}s';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Управление на опашка: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Уеб приложението не можа да достигне до бекенда на NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Браузърът блокира изисквана заявка поради правилата за сигурност на съдържанието.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 от 4 разрешени';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Работете със задачата както обикновено.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Промени · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Това устройство · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Лимитът е достигнат$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 кодовете за възстановяване все още са налични.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Ключ за сигурност $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Текуща сесия';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nПоследно използвано: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Работи в $arg1 на това устройство. NeoAgent чете и редактира папката директно и може да изпълнява команди, да отваря приложения и да използва екрана.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Работил за $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Разрешено от $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 връзките за покани от $arg2 бяха отменени';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Добавете хората и групите, с които $arg1 трябва да разговаря';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Добавете хората и групите, с които $arg1 има право да говори.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Където $arg1 слуша';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 следи тези места за споменавания. Всеки може да публикува тук, така че хората все още се нуждаят от собственото си одобрение по-долу.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Тези хора могат да попитат $arg1 където и да го маркират. Ролите се броят само на местата, изброени по-горе.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Само когато $arg1 е маркиран';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Включено за всички $arg1 групи';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 все още чува само хора и групи, които вече сте одобрили. Това просто позволява на $arg1 да се присъедини към обикновен чат там, не само към тагове и отговори.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 все още чува само хора и групи, които вече сте одобрили. Това просто избира към коя от тези групи да се присъедини.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Ако някой маркира $arg1 или отговори, $arg1 винаги отговаря. Включете това, ако $arg1 трябва да се включи и в обикновен групов чат.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Новите групи ще позволят на $arg1 да се присъедини към обикновен чат с одобрени хора, докато не ги изключите.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Новите групи ще позволят на $arg1 да се присъедини към обикновен чат, докато не ги изключите.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Новите групи остават тихи, освен ако одобрено лице не маркира $arg1, докато не ги включите.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Само когато одобрено лице маркира $arg1, освен ако не включите група';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Само когато $arg1 е маркиран, освен ако не включите група';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 от $arg2 групи се присъединяват към обикновен чат с одобрени хора';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Това не одобрява нови хора. Етикети и отговори от одобрени хора винаги получават отговор. Включете група, ако $arg1 също трябва да се присъедини към обикновен чат там.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Това не одобрява нови хора. Включете група, ако $arg1 трябва да се присъедини към обикновен чат с хора, които вече сте одобрили.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Етикетите и отговорите винаги получават отговор. Включете група, ако $arg1 също трябва да се присъедини към обикновен чат там.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 се присъединява към обикновен чат с одобрени хора';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 може да се присъедини към обикновен чат';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 отговаря само когато одобрено лице го маркира';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Не е необходимо нищо допълнително. Свържете се, за да започнете да използвате $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Опреснява се в ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Регистрирайте се с $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Няма спомени, свързани с „$arg1“.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (по подразбиране)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Клон: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 се присъединява само към групите и каналите, които добавите по-долу.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 е необходим за намиране на данни за изпълнение на NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[съкратен преглед, общо $arg1 байта]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[ограничен артефакт, общо $arg1 байта]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' в $arg1';
  }

  @override
  String get worldNews => 'Световни новини';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Стартирайте, когато се появят нови световни заглавия. Вашата подкана решава дали да ви уведоми.';

  @override
  String get newsKeywordsOptional => 'Ключови думи (по избор)';

  @override
  String get worldNewsSetup => 'Настройка на световните новини';

  @override
  String get connectWorldNewsWithGnews =>
      'Добавете GNews API ключ (безплатен план, достъпен на gnews.io). Съхранява се криптирано и се използва за анкетиране на водещи заглавия за задействания на Световните новини.';

  @override
  String get gnewsApiKey => 'API ключ за GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Поставете заместващ GNews API ключ';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Оставете ключа празен, за да запазите текущо съхранения ключ.';

  @override
  String get gnewsApiKeyIsRequired => 'Изисква се ключ за GNews API.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Настройката на Световните новини не можа да бъде запазена.';

  @override
  String get disconnectWorldNews => 'Изключете World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Това премахва съхранения ключ за GNews API. Тригерите за световни новини ще спрат да се задействат, докато не добавите ключ отново.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Световните новини не можаха да прекъснат връзката.';

  @override
  String get systemOneModels => 'Модели SystemOne';

  @override
  String get systemOneAuto => 'Авто';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Избира най-добрия наличен модел SystemOne';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Моделът на чат взема тези решения';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Модели за вземане на решения, които правят разговорите зад кулисите за части от секундата: редовен групов чат и стъпки на браузъра. Вашият модел на чат все още пише всеки отговор.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Моделът SystemOne решава кога да говори, докато е включен; този модел е резервен.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 отбеляза гол от SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne отбеляза директно това съобщение. Не се изпълнява езиков модел.';

  @override
  String get systemOneUnavailable => 'SystemOne не е наличен';

  @override
  String get systemOneAdminAvailability =>
      'Агентите могат да избират модели за вземане на решения в Настройки › Модели. Модел, изключен тук, напуска този инструмент за избор и агентите, които са го избрали, се връщат към Auto. Докато всеки модел е изключен, моделите SystemOne, които доставчиците добавят по-късно, също започват да се изключват.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Все още няма модели SystemOne. Добавете ключ TypeSafe или OpenRouter под Providers или изтеглете модел на решение като nimble в Ollama 0.35 или по-нова версия.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Все още не е наличен модел SystemOne. Добавете ключ TypeSafe или OpenRouter в Настройки › Модели › Донесете свой собствен ключ или изтеглете модел за решение като nimble в Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone система едно решение модели jev typesafe openrouter ollama наличност активиране деактивиране';

  @override
  String get chatModels => 'Чат модели';

  @override
  String get disabled => 'Изключено';

  @override
  String get enableShown => 'Показано активиране';

  @override
  String get disableShown => 'Показано деактивиране';

  @override
  String get expandAll => 'Разгънете всички';

  @override
  String get collapseAll => 'Свиване на всички';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 незапазени промени';
  }

  @override
  String get settingsScopeAllAgents => 'Всички агенти';

  @override
  String get settingsScopeAgent => 'Този агент';

  @override
  String get settingsScopeApp => 'Приложение';

  @override
  String get settingsScopeAccountHint => 'Същото навсякъде, където влизате';

  @override
  String get settingsScopeAllAgentsHint => 'Споделено от всички ваши агенти';

  @override
  String get settingsAppliesTo => 'Отнася се за';

  @override
  String get settingsSaving => 'Запазва се...';

  @override
  String get settingsSavedAutomatically => 'Промените се запазват автоматично';

  @override
  String get settingsSearchHint => 'Търсене във всички настройки';

  @override
  String get settingsPageProfile => 'Профил';

  @override
  String get settingsPageSecurity => 'Вход и сигурност';

  @override
  String get settingsPageUsage => 'Използване';

  @override
  String get settingsPagePermissions => 'Разрешения';

  @override
  String get settingsPageComputer => 'Компютър и мрежа';

  @override
  String get settingsPageBehavior => 'Поведение';

  @override
  String get settingsPageSystem => 'система';

  @override
  String get settingsPagePlatforms => 'Платформи';

  @override
  String get settingsPageProfileDescription =>
      'Вашето име и имейл, копие на вашите данни и излизане.';

  @override
  String get settingsPageSecurityDescription =>
      'Парола, двуфакторно удостоверяване, ключове за сигурност и къде сте влезли.';

  @override
  String get settingsPageUsageDescription =>
      'Вашите лимити и символични разходи, всичко на едно място.';

  @override
  String get settingsPageAgentsDescription =>
      'Създайте агенти и изберете кой отговаря по подразбиране.';

  @override
  String get settingsPagePermissionsDescription =>
      'Какво могат да направят вашите агенти, без първо да ви попитат.';

  @override
  String get settingsPageComputerDescription =>
      'Компютърът, на който работят вашите агенти, и сайтовете, които могат да четат като вас.';

  @override
  String get settingsPageModelsDescription =>
      'Кои модели използва този агент и API ключовете, които плащат за тях.';

  @override
  String get settingsPageBehaviorDescription =>
      'Как говори този агент и как разчита групов чат.';

  @override
  String get settingsPageVoiceDescription =>
      'Обаждания на живо, диктовки и устни отговори за този агент.';

  @override
  String get settingsPageMessagingDescription =>
      'Къде хората могат да достигнат до този агент и как се държи в чатове.';

  @override
  String get settingsPageGeneralDescription =>
      'Външен вид, език, часова зона и какво прави това приложение във фонов режим.';

  @override
  String get settingsPageSystemDescription =>
      'Сървърът, който този прозорец използва, този на този компютър и актуализации на приложения.';

  @override
  String get settingsYourAgents => 'Вашите агенти';

  @override
  String get settingsChatModel => 'Модел на чат';

  @override
  String get settingsChatModelDescription => 'Отговаря на вашите съобщения.';

  @override
  String get settingsSubAgentModel => 'Модел на подагент';

  @override
  String get settingsSubAgentModelDescription =>
      'Изпълнява работа, предадена по време на задача.';

  @override
  String get settingsDefaultModels => 'Модели по подразбиране';

  @override
  String get settingsDefaultModelsDescription =>
      'Използва се винаги, когато чат или задача не избере собствен модел.';

  @override
  String get settingsModelPool => 'Модел басейн';

  @override
  String get settingsApiKeysDescription =>
      'Използвайте свои собствени ключове или крайна точка за този агент. Ключовете са криптирани и никога повече не се показват.';

  @override
  String get settingsPersona => 'Персона';

  @override
  String get settingsFineTuning => 'Фина настройка';

  @override
  String get settingsFineTuningDescription =>
      'Рядко е необходимо. Стандартните настройки отговарят на повечето чатове.';

  @override
  String get settingsShow => 'Покажи';

  @override
  String get settingsHide => 'Скрий се';

  @override
  String get settingsMinimumContribution => 'Минимална стойност на вноската';

  @override
  String get settingsBatchWindow => 'Партиден прозорец на стаята';

  @override
  String get settingsBatchWindowDescription =>
      'Чака толкова дълго, за да третира бързите съобщения като един ход.';

  @override
  String get settingsHandsFree => 'Без ръце';

  @override
  String get settingsHandsFreeDescription =>
      'Говорете свободно и прекъсвайте по всяко време.';

  @override
  String get settingsPushToTalkDescription =>
      'Задръжте, за да говорите, отпуснете, за да изпратите.';

  @override
  String get settingsLiveVoice => 'Жив глас';

  @override
  String get settingsChannels => 'Канали';

  @override
  String get settingsGroupChats => 'В групови чатове';

  @override
  String get settingsGroupChatsDescription =>
      'Как този агент се държи в групи на всеки канал.';

  @override
  String get settingsGroupChatsDisabled =>
      'Включете модулите за поведение в Behavior, за да ги промените.';

  @override
  String get settingsParticipationAutomatic => 'Автоматичен';

  @override
  String get settingsParticipationMentionOnly => 'Споменете само';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Чете стаята и се включва, когато има нещо полезно за добавяне.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Отговаря само когато се споменава или се отговаря.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Отговаря на всяко съобщение.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Разделя по-дългите отговори на кратки съобщения, както би го направил човек.';

  @override
  String get settingsDeliverySingleDescription =>
      'Изпраща всеки отговор като едно съобщение.';

  @override
  String get settingsComputerStatus => 'Статус';

  @override
  String get settingsTest => 'Тест';

  @override
  String get settingsAppearance => 'Външен вид';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get settingsThemeSystem => 'система';

  @override
  String get settingsThemeLight => 'Светла';

  @override
  String get settingsThemeDark => 'Тъмна';

  @override
  String get settingsCloseWindow => 'Когато затворите прозореца';

  @override
  String get settingsCloseAsk => 'Попитайте';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent продължава да работи във фонов режим и остава достъпен.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent се отказва напълно.';

  @override
  String get settingsPhoneTriggers => 'Телефонни задействания';

  @override
  String get settingsPhoneTriggersDescription =>
      'Сигнали, които този телефон изпраща на вашите агенти, така че задачите да могат да реагират на тях.';

  @override
  String get settingsLocationTriggers => 'Задействания за местоположение';

  @override
  String get settingsLocationTriggersDescription =>
      'Проверява приблизителното ви местоположение на всеки няколко минути спрямо местата, които вашите задачи гледат.';

  @override
  String get settingsNotificationTriggers => 'Задействане на известия';

  @override
  String get settingsNotificationTriggersDescription =>
      'Препраща известия от други приложения на този телефон към вашите агенти.';

  @override
  String get settingsSetup => 'Настройка';

  @override
  String get settingsOnboarding => 'Включване';

  @override
  String get settingsOnboardingDescription =>
      'Преминете отново през първоначалната настройка. Нищо, което сте настроили, не се губи.';

  @override
  String get settingsUsernameDescription =>
      'Използва се за влизане. Не може да се променя.';

  @override
  String get settingsExport => 'Експортиране';

  @override
  String get settingsLeave => 'Излезте и изтрийте';

  @override
  String get settingsSignOutDescription => 'Излиза ви само на това устройство.';

  @override
  String get settingsDeleteAccountDescription =>
      'Изтрива вашия акаунт, агенти, памет и настройки. Това не може да бъде отменено.';

  @override
  String get settingsTokenUsage => 'Използване на токени';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Нито една настройка не съответства на „$query“.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count резултата',
      one: '$count резултат',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Разширени настройки на модела';

  @override
  String get settingsAdvancedModelsDescription =>
      'Не е задължително. Закачете модел към един вид работа; той поема всеки път, когато агентът използва тези инструменти. Всичко, което е оставено по подразбиране, следва модела на чат.';

  @override
  String get settingsTaskModelDefault => 'По подразбиране';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Следва модела на чат';

  @override
  String get settingsTaskModelCoding => 'Кодиране';

  @override
  String get settingsTaskModelCodingDescription =>
      'Писане, редактиране и отстраняване на грешки в код.';

  @override
  String get settingsTaskModelComputerUse => 'Използване на компютър';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Управление на браузъра и работния плот.';

  @override
  String get settingsTaskModelAndroidUse => 'Използване на Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Работа с приложения на Android устройство или емулатор.';

  @override
  String get settingsTaskModelResearch => 'Проучване';

  @override
  String get settingsTaskModelResearchDescription =>
      'Търсене, четене и обобщаване на източници.';

  @override
  String get knowledgeGraphHint =>
      'Вашите най-споменавани обекти, оцветени по клъстер. Линиите свързват обекти, които се появяват в едни и същи спомени. Докоснете един, за да видите неговите връзки и спомени; плъзнете за панорамиране, щипнете или Ctrl/⌘-превъртете за мащабиране.';

  @override
  String get linkedEntities => 'Свързани субекти';

  @override
  String get noLinkedEntities => 'Все още не е свързан с други субекти.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 споменава';
  }

  @override
  String get entityKindConcept => 'Концепция';

  @override
  String get entityKindDomain => 'Домейн';

  @override
  String get entityKindEmail => 'Имейл';

  @override
  String get entityKindLink => 'Връзка';

  @override
  String get entityKindFile => 'Файл';

  @override
  String get entityKindAcronym => 'акроним';

  @override
  String get entityKindIdentifier => 'Идентификатор';

  @override
  String get entityKindVersion => 'Версия';

  @override
  String get openFullscreen => 'Отворете цял екран';

  @override
  String get zoomIn => 'Увеличете мащаба';

  @override
  String get zoomOut => 'Намаляване';

  @override
  String get searchEntities => 'Намерете обект';

  @override
  String get incomingCall => 'Входящо повикване';

  @override
  String get answerCall => 'отговор';

  @override
  String get callMeLater => 'Обади ми се по-късно';

  @override
  String get callingEllipsis => 'Обаждане...';

  @override
  String get reconnectingCall => 'Повторно свързване';

  @override
  String get agentWorking => 'Работещ';

  @override
  String get micMuted => 'Заглушен';

  @override
  String get speakerphone => 'Говорител';

  @override
  String get muteMic => 'Без звук';

  @override
  String get unmuteMic => 'Включване на звука';

  @override
  String get releaseToSend => 'Освободете, за да изпратите';

  @override
  String get callEnded => 'Обаждането приключи';

  @override
  String get openConversation => 'Отворен разговор';

  @override
  String get callBack => 'Обадете се обратно';

  @override
  String get letCallsReachYou => 'Нека обажданията достигат до вас';

  @override
  String get callPermissionsIntro =>
      'Вашите агенти могат да ви се обадят. За да звъни като телефонно обаждане, докато NeoAgent е във фонов режим или телефонът ви е заключен, той се нуждае от тези.';

  @override
  String get showOverOtherApps => 'Показване над други приложения';

  @override
  String get showOverOtherAppsDetail =>
      'Извежда екрана за повикване където и да сте.';

  @override
  String get fullScreenCalls => 'Обаждания на цял екран';

  @override
  String get fullScreenCallsDetail => 'Звъни над заключения екран.';

  @override
  String get unrestrictedBattery => 'Неограничена батерия';

  @override
  String get unrestrictedBatteryDetail =>
      'Поддържа NeoAgent свързан, така че обажданията да пристигат.';

  @override
  String get permissionAllowed => 'Разрешено';

  @override
  String get triggerSectionCalendar => 'Календар';

  @override
  String get triggerSectionFiles => 'Файлове и документи';

  @override
  String get triggerSectionHome => 'Начало и медии';

  @override
  String get triggerSectionDevices => 'Устройства и места';

  @override
  String get triggerSectionTasks => 'Задачи';

  @override
  String get messagingMemberJoined => 'Член се присъедини';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Стартирайте, когато някой се присъедини към Discord сървър, Telegram или WhatsApp група, Slack канал или Matrix стая.';

  @override
  String get messagingMemberLeft => 'Напуснал член';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Стартирайте, когато някой напусне сървър на Discord, група в Telegram или WhatsApp, канал Slack или стая на Matrix.';

  @override
  String get messagingReactionAdded => 'Добавена е реакция';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Стартирайте, когато разрешено лице реагира на съобщение в личен чат.';

  @override
  String get messagingPlatformDisconnected => 'Съобщенията са прекъснати';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Стартирайте, когато връзката за съобщения спре и се нуждае от вас, като например след излизане.';

  @override
  String get googleCalendarEventStarting => 'Започва събитие в Google Календар';

  @override
  String get googleCalendarEventCreated =>
      'Създадено събитие в Google Календар';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Стартирайте, когато се появи ново събитие или покана.';

  @override
  String get outlookCalendarEventStarting =>
      'Стартира събитие в календара на Outlook';

  @override
  String get nextcloudCalendarEventStarting =>
      'Започва събитие в календара на Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Пуснете определен брой минути преди всяко събитие.';

  @override
  String get googleDriveFileAdded => 'Добавен е файл в Google Диск';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Изпълнява се, когато файл се добави към Диск или папка в него.';

  @override
  String get googleSheetsRowAdded => 'Добавен е ред в Google Таблици';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Изпълнение, когато се появят нови редове в лист.';

  @override
  String get onedriveFileAdded => 'Файлът на OneDrive е добавен';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Стартирайте, когато файл е добавен към папка на OneDrive.';

  @override
  String get nextcloudFileAdded => 'Добавен файл Nextcloud';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Стартирайте, когато файл е добавен към папка Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Nextcloud файл, споделен с вас';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Стартирайте, когато някой сподели файл или папка с вас.';

  @override
  String get notionItemAdded =>
      'Добавен е елемент от базата данни на понятието';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Изпълнява се, когато даден елемент е добавен към база данни на Notion.';

  @override
  String get notionItemUpdated =>
      'Актуализиран е елемент от базата данни на Notion';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Стартирайте, когато се промени елемент в база данни на Notion.';

  @override
  String get trelloCardEnteredList => 'Картата Trello е добавена към списъка';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Изпълнява се, когато карта е създадена в или преместена в списък.';

  @override
  String get figmaCommentAdded => 'Добавен е коментар на Figma';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Стартирайте, когато някой коментира файл на Figma.';

  @override
  String get githubPrOpened => 'Заявката за изтегляне на GitHub е отворена';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Изпълнение, когато в хранилище се отвори нова заявка за изтегляне.';

  @override
  String get githubWorkflowRunFailed =>
      'Неуспешно изпълнение на работния поток на GitHub';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Изпълнение при неуспешно изпълнение на GitHub Actions.';

  @override
  String get githubCommitPushed => 'Изпратен ангажимент на GitHub';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Стартирайте, когато новите ангажименти достигнат клон.';

  @override
  String get mcpServerFailed => 'MCP сървърът е неуспешен';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Стартирайте, когато работещ MCP сървър се повреди или се нуждае от влизане.';

  @override
  String get homeAssistantStateChanged =>
      'Състоянието на Home Assistant е променено';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Изпълнение, когато обект се промени, достигне състояние или пресече стойност.';

  @override
  String get spotifyTrackChanged => 'Песента на Spotify е променена';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Стартирайте, когато започне да се възпроизвежда друга песен.';

  @override
  String get neorecallDailySummaryReady =>
      'Готово ежедневно резюме на NeoRecall';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Стартирайте, когато обобщението за деня е окончателно.';

  @override
  String get neorecallConversationRecorded =>
      'Разговорът на NeoRecall е записан';

  @override
  String get runWhenARecordedConversationEnds =>
      'Стартирайте, когато записан разговор приключи.';

  @override
  String get geofenceTrigger => 'Геопреграда за местоположение';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Стартирайте, когато телефонът ви пристигне или напусне дадено място. Нуждае се от проследяване на местоположението на телефона.';

  @override
  String get healthMetricRecorded => 'Здравният показател е записан';

  @override
  String get runWhenAHealthReadingArrives =>
      'Изпълнение, когато пристигне синхронизирано отчитане на здравето, по желание над или под стойност.';

  @override
  String get wearableConnectionChanged => 'Носимо свързано или изключено';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Стартирайте, когато вашето носимо устройство се свързва или прекъсва.';

  @override
  String get taskRunFinished => 'Друга задача приключи';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Стартирайте, след като друга задача приключи, успее или се провали.';

  @override
  String get appPackageOptional => 'Пакет за приложения (по избор)';

  @override
  String get appPackageHelper => 'Например com.whatsapp';

  @override
  String get anyPlatform => 'Всякаква платформа';

  @override
  String get spaceIdOptional =>
      'ID на сървър, група, канал или стая (по избор)';

  @override
  String get spaceIdHelper => 'Empty наблюдава всеки, в който е ботът.';

  @override
  String get emojiOptional => 'Емоджи (по избор)';

  @override
  String get chatIdOptional => 'ID на чата (по избор)';

  @override
  String get platformOptional => 'Платформа (по избор)';

  @override
  String get platformOptionalHelper =>
      'Например whatsapp. Празни часовници всички.';

  @override
  String get minutesBefore => 'Минути преди';

  @override
  String get calendarIdOptional => 'ID на календара (по избор)';

  @override
  String get calendarIdHelper => 'Empty използва основния ви календар.';

  @override
  String get invitesOnly => 'Само покани от други';

  @override
  String get nextcloudCalendarPath => 'Календар';

  @override
  String get nextcloudCalendarPathHelper =>
      'Името му в списъка с календари Nextcloud, например лично';

  @override
  String get folderIdOptionalHelperDrive => 'Празните часовници на целия Диск.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Empty наблюдава основната папка.';

  @override
  String get driveFolderIdOptional => 'ID на папка (по избор)';

  @override
  String get spreadsheetId => 'ИД на електронна таблица';

  @override
  String get sheetRange => 'Обхват';

  @override
  String get sheetRangeHelper => 'Колоните на таблицата, например Sheet1!A:E';

  @override
  String get folderPathOptional => 'Път на папката (по избор)';

  @override
  String get folderPathHelper => 'Например Документи';

  @override
  String get notionDatabaseId => 'ID на база данни';

  @override
  String get trelloListId => 'ID на списъка';

  @override
  String get figmaFileKey => 'Файлов ключ';

  @override
  String get figmaFileKeyHelper =>
      'От връзката към файла: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Хранилище';

  @override
  String get workflowOptional => 'Работен процес (по избор)';

  @override
  String get workflowHelper => 'Име на файл като ci.yml';

  @override
  String get branchOptional => 'Клон (по избор)';

  @override
  String get branchHelper => 'Empty използва клона по подразбиране.';

  @override
  String get mcpServerIdOptional => 'ID на MCP сървър (по избор)';

  @override
  String get entityId => 'ID на обекта';

  @override
  String get entityIdHelper => 'Например binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Целево състояние (по избор)';

  @override
  String get targetStateHelper => 'Например на';

  @override
  String get aboveOptional => 'Горе (по избор)';

  @override
  String get belowOptional => 'По-долу (по избор)';

  @override
  String get placeName => 'Име на място';

  @override
  String get latitude => 'Географска ширина';

  @override
  String get longitude => 'Географска дължина';

  @override
  String get radiusMeters => 'Радиус в метри';

  @override
  String get geofenceTransition => 'Кога';

  @override
  String get arriving => 'Пристигане';

  @override
  String get leaving => 'напускане';

  @override
  String get healthMetric => 'Здравен показател';

  @override
  String get healthMetricHelper => 'Например heart_rate, стъпки, тегло';

  @override
  String get wearableTransition => 'Когато носими';

  @override
  String get wearableConnects => 'Свързва се';

  @override
  String get wearableDisconnects => 'Прекъсва връзката';

  @override
  String get sourceTask => 'След задача';

  @override
  String get taskOutcome => 'Резултат';

  @override
  String get anyOutcome => 'Всякакъв резултат';

  @override
  String get succeeded => 'Успял';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 липсва или не е валиден.';
  }

  @override
  String get triggerSectionMessaging => 'Съобщения';

  @override
  String get triggerSectionDeveloper => 'Разработчик';

  @override
  String get triggerSectionMemory => 'памет';

  @override
  String get triggerSectionNews => 'Новини';

  @override
  String get triggerSectionSystem => 'система';

  @override
  String get searchTriggersHint =>
      'Задействания за търсене, приложения или събития';

  @override
  String get noTriggersMatch =>
      'Нито един тригер не отговаря на вашето търсене.';

  @override
  String get triggerAccountMissing => 'Все още няма акаунт';

  @override
  String get pickTriggerKeyboardHint => 'Enter избира първия резултат';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 задейства';
  }

  @override
  String get addFromSkillsSh => 'Добавете от skills.sh';

  @override
  String get skillsShHint =>
      'Търсете по-горе, за да намерите умения в Skills.sh, или поставете връзка Skills.sh или команда `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Няма умения на skills.sh, които отговарят на това търсене.';

  @override
  String get installingSkill => 'Инсталиране...';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Инсталиран $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 инсталира';
  }

  @override
  String get authVerify => 'Проверете';

  @override
  String get authCreateAccount => 'Създаване на акаунт';

  @override
  String get authNewInviteLink => 'Нова връзка за покана';

  @override
  String get authShowPassword => 'Покажи парола';

  @override
  String get authHidePassword => 'Скриване на паролата';

  @override
  String get authPasswordWillBeRejected => 'твърде слаб, ще бъде отхвърлен';

  @override
  String get authUsernameTooShort =>
      'Потребителските имена трябва да съдържат поне 3 знака.';

  @override
  String get authUsernameTaken => 'Това потребителско име вече е заето.';

  @override
  String get authSignupsClosed =>
      'Регистрациите са затворени на този сървър. Попитайте администратора за акаунт.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Този сървър приема влизания само през HTTPS. Вместо това отворете $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Този сървър приема влизания само през HTTPS. Свържете се с него с https:// адрес.';

  @override
  String get authAccountNotFound => 'Този акаунт вече не съществува.';

  @override
  String get authQrRateLimited =>
      'Твърде много заявки за влизане с QR. Изчакайте малко, след което обновете кода.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Забравена парола? Помолете администратора на вашия сървър да го нулира в Администратор → Потребители.';

  @override
  String get authChangeServer => 'Промяна на сървъра';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Влизане в $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Този адрес не отговаря като сървър на NeoAgent. Проверете URL адреса и опитайте отново.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Не можа да се отвори защитена (HTTPS) връзка към $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Не можах да достигна до $arg1 през HTTPS и обикновеният HTTP също не отговори. Проверете адреса и порта.';
  }

  @override
  String get adminResetPassword => 'Нулирайте паролата';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Нулирайте паролата за $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Изберете нова парола за $arg1. Те ще излязат от всяко устройство и ще влязат отново с тази парола.';
  }

  @override
  String get adminNewPassword => 'Нова парола';

  @override
  String get adminSetPassword => 'Задайте парола';

  @override
  String get authMissingFields => 'Попълнете всяко задължително поле.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 нулирайте паролата на $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Паролата е актуализирана; потребителят беше излязъл навсякъде.';

  @override
  String get authSignInTitle => 'Влезте в NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Сканирайте с телефона си или използвайте паролата си.';

  @override
  String get authOrUsePassword => 'или използвайте вашата парола';

  @override
  String get qrLoginWaitingTitle => 'Одобрете на телефона си';

  @override
  String get qrLoginWaitingBody =>
      'Вашият телефон сканира кода. Потвърдете влизането там, за да завършите влизането.';

  @override
  String get qrLoginSigningInOn => 'Влизане в';

  @override
  String get qrLoginLocation => 'Местоположение';

  @override
  String get qrLoginWaitingForApproval => 'Чака одобрение';

  @override
  String get qrLoginCancelAndUsePassword => 'Отказ и използване на парола';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Влизането беше отказано на вашия телефон. Сканирайте новия код, за да опитате отново.';

  @override
  String get signupKey => 'Ключ за регистрация';

  @override
  String get signupKeyStepSubtitle =>
      'Новите акаунти на този сървър изискват ключ за регистрация. Въведете ключа, който сте получили от администратор.';

  @override
  String get signupKeyChange => 'Промяна';

  @override
  String get signupKeyRequiredError => 'Въведете своя ключ за регистрация.';

  @override
  String get signupKeyInvalidError =>
      'Този ключ за регистрация е невалиден. Проверете го и опитайте отново.';

  @override
  String get signupKeyUsedError =>
      'Този ключ за регистрация вече е използван. Поискайте нов от администратор.';

  @override
  String get adminRequireSignupKey => 'Изисквай ключ за регистрация';

  @override
  String get adminRequireSignupKeyHint =>
      'Новите акаунти изискват еднократен ключ от администратор. Когато е изключено, всеки, който има достъп до този сървър, може да се регистрира. Първият акаунт никога не изисква ключ.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Новите акаунти вече изискват ключ за регистрация.';

  @override
  String get adminSignupOpenNotice => 'Вече всеки може да се регистрира.';

  @override
  String get signupKeys => 'Ключове за регистрация';

  @override
  String get signupKeysDescription =>
      'Еднократни ключове за регистрация, докато се изисква ключ. Всеки ключ създава точно един акаунт.';

  @override
  String get signupKeysNew => 'Нови ключове';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Неизползвани · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Използвани · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Отменени · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Всички · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Неизползван';

  @override
  String get signupKeyStatusUsed => 'Използван';

  @override
  String get signupKeyStatusRevoked => 'Отменен';

  @override
  String get signupKeysExport => 'Експорт в .txt';

  @override
  String get signupKeysCopied => 'Ключовете са копирани';

  @override
  String get signupKeyCopied => 'Ключът е копиран';

  @override
  String get signupKeysEmpty => 'Няма ключове в този списък.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Създаден на $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Използван от $arg1 на $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Използван на $arg1 от акаунт, който междувременно е изтрит';
  }

  @override
  String get signupKeyRevokeTitle => 'Да се отмени ли този ключ?';

  @override
  String get signupKeyRevokeMessage =>
      'Никой вече няма да може да се регистрира с него. Това не може да бъде отменено.';

  @override
  String get signupKeyRevoked => 'Ключът е отменен.';

  @override
  String signupKeysShowMore(int count) {
    return 'Покажи още $count';
  }

  @override
  String get signupKeysCreateTitle => 'Създаване на ключове за регистрация';

  @override
  String get signupKeysCount => 'Брой ключове';

  @override
  String get signupKeysCountHelper => 'От 1 до 500';

  @override
  String get signupKeysCountInvalid => 'Въведете число от 1 до 500.';

  @override
  String get signupKeysLabel => 'Етикет (по избор)';

  @override
  String get signupKeysLabelHint => 'напр. Пролетни бета тестери';

  @override
  String signupKeysCreateAction(int count) {
    return 'Създай ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Готови ключове: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Давайте всеки ключ само на един човек. Неизползваните ключове остават в списъка, така че по-късно можете отново да ги копирате или експортирате.';

  @override
  String get signupKeysSaveDialogTitle =>
      'Запазване на ключовете за регистрация';

  @override
  String get signupKeysExported => 'Ключовете са експортирани.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor създаде ключове за регистрация ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor отмени ключ за регистрация';
  }

  @override
  String get providerChooseUsername => 'Изберете потребителско име';

  @override
  String get providerChooseUsernameBody =>
      'Изберете свободно потребителско име, за да завършите създаването на акаунта си.';

  @override
  String get dataSharingTitle => 'Споделяне на данни за използването';

  @override
  String get dataSharingDescription =>
      'Помогнете на хората, които поддържат този сървър, да го подобрят. Споделя как използвате NeoAgent, никога какво пишете или съхранявате.';

  @override
  String dataSharingSince(String date) {
    return 'Споделя се от $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Какво се споделя';

  @override
  String get dataSharingIncluded => 'Споделя се';

  @override
  String get dataSharingExcluded => 'Никога не се споделя';

  @override
  String get dataSharingIncludedDevice =>
      'Вид устройство и версия на приложението';

  @override
  String get dataSharingIncludedLocale =>
      'Език на приложението и регион на часовата зона, например Европа';

  @override
  String get dataSharingIncludedFeatures =>
      'Кои функции сте настроили, като задачи, умения и интеграции';

  @override
  String get dataSharingIncludedRuns =>
      'Кои инструменти и модели използват вашите изпълнения, с продължителност и брой токени';

  @override
  String get dataSharingIncludedActivity =>
      'Кога използвате NeoAgent, по ден от седмицата и час';

  @override
  String get dataSharingExcludedContent => 'Съобщения, промптове и отговори';

  @override
  String get dataSharingExcludedRuns =>
      'Заглавия на изпълнения, входни данни и резултати от инструменти';

  @override
  String get dataSharingExcludedFiles =>
      'Файлове, спомени и всичко друго, което съхранявате';

  @override
  String get dataSharingExcludedIdentity =>
      'Вашето име, имейл, IP адрес и местоположение';

  @override
  String get dataSharingExcludedAccounts =>
      'Акаунтите, с които свързвате интеграции';

  @override
  String get dataSharingPooledNote =>
      'Администраторите виждат само общи суми за всички, които споделят, никога само вас. Изключете го по всяко време и веднага отпадате от сумите.';

  @override
  String get dataSharingConfirmTitle =>
      'Да се споделят ли данните за използването?';

  @override
  String get dataSharingConfirmAction => 'Споделяне';

  @override
  String get sharedUsageTitle => 'Споделено използване';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Акаунти, които споделят данни за използването: $sharing от $total. Само суми, без съдържание.';
  }

  @override
  String get sharedUsageEmpty =>
      'Все още никой не споделя данни за използването. Може да се включи в Настройки, Профил, Вашите данни.';

  @override
  String get sharedUsageRuns => 'Споделени изпълнения';

  @override
  String get sharedUsageAvgDuration => 'Средна продълж.';

  @override
  String get sharedUsageCompletedRuns => 'Завършени изпълнения';

  @override
  String get sharedUsageStepsPerRun => 'Стъпки на изпълнение';

  @override
  String get sharedUsageDevices => 'Устройства';

  @override
  String get sharedUsageAppVersions => 'Версии на приложението';

  @override
  String get sharedUsageLanguages => 'Езици';

  @override
  String get sharedUsageRegions => 'Региони';

  @override
  String get sharedUsageFeatures => 'Използване на функции';

  @override
  String get sharedUsageFeaturesDescription =>
      'Дял на споделящите акаунти, които са я настроили.';

  @override
  String get sharedUsageTools => 'Инструменти';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Най-извиквани инструменти ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Извиквания: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Неуспешни: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Интеграции';

  @override
  String get sharedUsageMessaging => 'Канали за съобщения';

  @override
  String get sharedUsageTriggers => 'Как започват изпълненията';

  @override
  String get sharedUsageActivity => 'Кога се използва';

  @override
  String get sharedUsageActivityDescription =>
      'Изпълнения по ден от седмицата и час, UTC.';

  @override
  String get sharedUsageModels => 'Производителност на моделите';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'средно $latency · $cached% от кеша · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Акаунти: $count';
  }

  @override
  String get sharedUsageNoData => 'Няма нищо за този период.';

  @override
  String get sharedUsageNotReported => 'Все още не е отчетено';

  @override
  String get sharedUsageFeatureAgents => 'Повече от един агент';

  @override
  String get sharedUsageFeatureTasks => 'Планирани задачи';

  @override
  String get sharedUsageFeatureSkills => 'Умения';

  @override
  String get sharedUsageFeatureMcp => 'MCP сървъри';

  @override
  String get sharedUsageFeatureIntegrations => 'Интеграции';

  @override
  String get sharedUsageFeatureMessaging => 'Канали за съобщения';

  @override
  String get sharedUsageFeatureMemory => 'Памет';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in споделяне на данни телеметрия устройства функции инструменти модели активност';

  @override
  String get yourOAuthApp => 'Вашето OAuth приложение';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Вашето OAuth приложение за $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Този сървър няма глобално приложение за $provider, затова се свързвате с OAuth приложение, което регистрирате сами. Клиентската тайна се съхранява криптирана и никога повече не се показва.';
  }

  @override
  String get oauthAppStepCreate => '1. Създайте приложението';

  @override
  String get openDeveloperConsole => 'Отвори конзолата за разработчици';

  @override
  String get oauthAppStepCallback => '2. Регистрирайте този callback URL';

  @override
  String get callbackUrlCopied => 'Callback URL е копиран';

  @override
  String get oauthAppScopes => 'Обхвати за разрешаване';

  @override
  String get scopesCopied => 'Обхватите са копирани';

  @override
  String get oauthAppStepCredentials =>
      '3. Поставете данните за достъп на приложението';

  @override
  String get couldNotSaveOAuthApp =>
      'OAuth приложението не можа да бъде запазено.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Да се премахне ли вашето приложение за $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Свързаните акаунти остават в списъка, но спират да работят, докато не добавите приложение отново.';

  @override
  String get globalIntegrationConfiguration =>
      'Глобална конфигурация на интеграциите';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Незадължителни OAuth приложения за целия сървър. Когато интеграция има такова, всеки акаунт го използва и не може да добави свое. Оставете интеграцията незададена и всеки потребител настройва собствено приложение. Тайните са само за запис: оставете празно, за да запазите съхранената стойност.';

  @override
  String get globalStatus => 'Глобално';

  @override
  String get perUserStatus => 'За потребител';

  @override
  String get phoneSyncGuidance =>
      'Споделете календарите и контактите на този телефон с вашия агент. Работи с всеки акаунт, който вече е на телефона.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Отворете NeoAgent на телефона и включете споделянето там. Агентът ще вижда календарите и контактите на всички акаунти на този телефон.';

  @override
  String get manageOnThisPhone => 'Управление на този телефон';

  @override
  String get setUpOnThisPhone => 'Настройка на този телефон';

  @override
  String get setUpOnPhone => 'Настройка на телефона';

  @override
  String emailConnectedArg1(String email) {
    return '$email е свързан';
  }

  @override
  String get couldNotConnectEmail => 'Акаунтът не можа да бъде свързан.';

  @override
  String get emailSetupTitle => 'Свързване на имейл и календар';

  @override
  String get emailChecking => 'Проверка на пощата…';

  @override
  String get emailSetupIntro =>
      'Използвайте парола за приложение от доставчика на имейл. Без конзола за разработчици, готово за няколко минути.';

  @override
  String emailOpenArg1(String provider) {
    return 'Отвори $provider';
  }

  @override
  String get emailStepServers => '1. Въведете сървърите';

  @override
  String get emailStepPassword => '1. Създайте парола за приложение';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Отвори паролите за приложения на $provider';
  }

  @override
  String get emailStepSignIn => '2. Вход';

  @override
  String get appPassword => 'Парола за приложение';

  @override
  String get appPasswordHelper =>
      'Интервалите нямат значение. NeoAgent я съхранява криптирана.';

  @override
  String get emailUsernameOptional => 'Потребителско име, ако не е имейлът ви';

  @override
  String get emailIncludeCalendar => 'Включи календара';

  @override
  String get emailIncludeContacts => 'Включи контактите';

  @override
  String get imapServer => 'IMAP сървър';

  @override
  String get smtpServer => 'SMTP сървър';

  @override
  String get caldavUrlOptional => 'CalDAV URL (по избор)';

  @override
  String get carddavUrlOptional => 'CardDAV URL (по избор)';

  @override
  String get alternativeEmail =>
      'Свържете пощата с парола за приложение или календара чрез неговата iCal връзка. Готово за няколко минути.';

  @override
  String get alternativePhone =>
      'Споделете календара и контактите от телефона чрез приложението NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Споделете календара и контактите от телефона. Настройте го в приложението NeoAgent на телефона.';

  @override
  String get skipTheDeveloperConsole => 'Без конзола за разработчици';

  @override
  String get phoneSyncPromptTitle => 'Да вижда ли агентът календара ви?';

  @override
  String get phoneSyncPromptBody =>
      'Споделете календарите и контактите на този телефон, за да планира агентът деня ви. Можете да промените това по всяко време в Инструменти › Интеграции.';

  @override
  String get phoneSyncTitle =>
      'Споделяне на календара и контактите на телефона';

  @override
  String get phoneSyncIntro =>
      'Агентът вижда календарите и контактите на всички акаунти на този телефон. Без конзола за разработчици и допълнителен вход.';

  @override
  String get phoneSyncPointAccounts =>
      'Работи с акаунтите в Google, Outlook, iCloud и Exchange на този телефон.';

  @override
  String get phoneSyncPointPrivate =>
      'Споделя се само с вашия сървър NeoAgent, който ги съхранява криптирани.';

  @override
  String get phoneSyncPointWrites =>
      'Събитията, добавени от агента, се създават от този телефон и се синхронизират както обикновено.';

  @override
  String get phoneSyncCalendarHint =>
      'Събития от преди 30 дни до 90 дни напред';

  @override
  String get phoneSyncContacts => 'Контакти';

  @override
  String get phoneSyncContactsHint => 'Имена, имейл адреси и телефонни номера';

  @override
  String get phoneSyncOtherAgent =>
      'Този телефон споделя с друг агент. Споделянето тук го премества към този агент.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent все още няма достъп. Разрешете го в Настройки и се върнете.';

  @override
  String get openPhoneSettings => 'Отвори Настройки';

  @override
  String get phoneSyncShare => 'Сподели с NeoAgent';

  @override
  String get phoneSyncStop => 'Спри споделянето';

  @override
  String get phoneSyncWaiting => 'Изчакване на първата синхронизация…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Последна синхронизация $time';
  }

  @override
  String get calendarLink => 'Връзка към календара';

  @override
  String get calendarLinkHelper =>
      'iCal адресът на календара. Всеки с него може да чете календара, затова го пазете в тайна.';

  @override
  String get calendarLinkName => 'Име (по избор)';

  @override
  String get calendarLinkAdded => 'Календарът е добавен';

  @override
  String get toolsApps => 'Приложения';

  @override
  String get reconnect => 'Свържи отново';

  @override
  String get reconnectNeeded => 'Нужно е повторно свързване';

  @override
  String get mixedAccess => 'Смесен достъп';

  @override
  String disconnectAccountTitle(String account) {
    return 'Да се прекъсне ли $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Агентът губи достъп до $apps чрез този акаунт.';
  }

  @override
  String get neoRouterServerDescription =>
      'Свържете своя NeoRouter веднъж и всеки акаунт тук ще го използва за задачите, включени по-долу.';

  @override
  String get neoRouterUserDescription =>
      'Използвайте собствения си акаунт в NeoRouter за задачите, включени по-долу, вместо доставчиците на този сървър.';

  @override
  String get neoRouterAddress => 'Адрес на NeoRouter';

  @override
  String get neoRouterConnect => 'Свързване на NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Одобрете NeoAgent в NeoRouter. Там е показан кодът $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Отваряне отново';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Свързано с $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter не е достъпен в момента.';

  @override
  String get neoRouterDisconnect => 'Прекъсване';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent спира да използва този NeoRouter. За да оттеглите и ключа, отменете го в NeoRouter в API ключове.';

  @override
  String neoRouterServerInUseArg1(Object? arg1) {
    return 'Този сървър вече използва NeoRouter на $arg1. Свържете там собствения си акаунт за свои модели и бюджет.';
  }

  @override
  String get neoRouterConnected => 'NeoRouter е свързан.';

  @override
  String get neoRouterRoleChat => 'Чат и разпознаване на изображения';

  @override
  String get neoRouterRoleSystemOne => 'Решения на System One';

  @override
  String get neoRouterRoleTranscription => 'Говор в текст';

  @override
  String get neoRouterRoleLive => 'Глас на живо';

  @override
  String get neoRouterRoleEmbeddings => 'Търсене в паметта';

  @override
  String get neoRouterRoleImages => 'Създаване на изображения';

  @override
  String get neoRouterRoleSearch => 'Търсене в мрежата';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Налични във вашия NeoRouter: $arg1';
  }

  @override
  String get neoRouterNoModels => 'Във вашия NeoRouter все още няма нищо.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter избира модела за всяка заявка, затова тази селекция не се използва.';

  @override
  String neoRouterNotAllowedArg1(Object? arg1) {
    return 'Във вашия NeoRouter: $arg1, но ключът на NeoAgent още не може да ги използва (напр. платените). Разрешете ги за NeoAgent в API ключове в NeoRouter.';
  }

  @override
  String get neoRouterNoDecisionModels =>
      'Нужни са модели за решения като Jev. Класификаторите за безопасност не отговарят на тези въпроси.';
}
