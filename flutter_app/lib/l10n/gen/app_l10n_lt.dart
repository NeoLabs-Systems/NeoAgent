// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Lithuanian (`lt`).
class AppL10nLt extends AppL10n {
  AppL10nLt([String locale = 'lt']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Sveiki atvykę';

  @override
  String get onboardingEyebrowCommunication => 'Bendravimas';

  @override
  String get onboardingEyebrowIntelligence => 'Intelektas';

  @override
  String get onboardingEyebrowComputer => 'Kompiuteris';

  @override
  String get onboardingEyebrowAutomation => 'Automatika';

  @override
  String get onboardingNext => 'Kitas';

  @override
  String get onboardingIntroCouldNotLoad => 'Nepavyko įkelti įvado.';

  @override
  String get onboardingModelDescription =>
      'Pasirinkite modelį, kurį „NeoAgent“ turėtų naudoti pagal numatytuosius nustatymus, arba leiskite pasirinkti automatiškai.';

  @override
  String get onboardingLoadingModels => 'Įkeliami modeliai…';

  @override
  String get noAiModelTitle => 'Dar nenustatytas joks AI modelis';

  @override
  String get noAiModelBody =>
      'Pridėkite API raktą iš tiekėjo, pvz., „OpenAI“, „Anthropic“ ar „Google“. Tada „NeoAgent“ parodo modelius, kuriuos galite naudoti.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent reikia AI modelio atsakyti. Pridėkite API raktą iš tiekėjo, pvz., „OpenAI“, „Anthropic“ ar „Google“.';

  @override
  String get noAiModelAdminHint =>
      'Kaip administratorius taip pat galite nustatyti tiekėjus visiems, skiltyje Administratorius → Teikėjai.';

  @override
  String get addApiKey => 'Pridėti API raktą';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform prijungtas.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Laukiama, kol $platform prisijungs…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Sąrankos išsaugoti nepavyko: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Paruošta';

  @override
  String get onboardingStepRequired => 'Privaloma';

  @override
  String get onboardingStepOptional => 'Neprivaloma';

  @override
  String get onboardingStepCloudOrLocal => 'Debesis arba vietinis';

  @override
  String get onboardingStepComputer => 'Kompiuteris';

  @override
  String get onboardingStepRoutines => 'Rutinos';

  @override
  String get onboardingComputerChoiceTitle => 'Kur tai turėtų\nveikti?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Galite perjungti per seansą.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Privati smėlio dėžė · visada įjungta';

  @override
  String get onboardingThisComputer => 'Šis kompiuteris';

  @override
  String get onboardingThisComputerSubtitle =>
      'Jūsų failai, programos ir naršyklė';

  @override
  String get onboardingSearchApps => 'Ieškoti programų…';

  @override
  String get onboardingRoutinesDescription =>
      'Rezultatai pateikiami jūsų pokalbiuose.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Rezultatai gaunami kaip pranešimai.';

  @override
  String get onboardingNotifications => 'Pranešimai';

  @override
  String get onboardingReadyTitle => 'Viskas\nparuošta.';

  @override
  String get onboardingReadyDescription => 'Išsiųskite savo pirmąją žinutę.';

  @override
  String get onboardingMessageNeoagent => 'Pranešimas NeoAgent';

  @override
  String get onboardingAskAnything => 'Paklausk bet ko…';

  @override
  String get onboardingOpenNeoagent => 'Atidarykite „NeoAgent“.';

  @override
  String get onboardingStarterTrip => 'Suplanuokite savaitgalio kelionę';

  @override
  String get onboardingStarterLanding => 'Sukurkite nukreipimo puslapį';

  @override
  String onboardingQuickSteps(int count) {
    return '$count greiti žingsniai';
  }

  @override
  String get taskNeedsEmail => 'Pirmiausia prijunkite el';

  @override
  String get taskNeedsCalendar => 'Pirmiausia prijunkite kalendorių';

  @override
  String get taskNeedsModel => 'Pirmiausia nustatykite AI modelį';

  @override
  String get taskPromptDailyRecap =>
      'Apibendrinkite savo dieną: apibendrinkite šiandienos pokalbius, baigtus darbus ir sprendimus, tada išvardinkite viską, ko turėčiau imtis rytoj. Sutrumpinkite ir atsiųskite man.';

  @override
  String get taskPromptInboxCheck =>
      'Patikrinkite mano el. pašto dėžutę, ar nėra pranešimų, gautų po paskutinio patikrinimo. Rašykite man tik apie el. laiškus, kurie yra skubūs arba į kuriuos reikia atsakyti, su kiekvienos eilutės santrauka. Jei niekam nereikia mano dėmesio, nieko nesiųskite.';

  @override
  String get taskPromptMorningBriefing =>
      'Paruoškite mano ryto instruktažą: šiandienos oras, kur esu, įvykiai mano kalendoriuje ir svarbiausi atviri dalykai, apie kuriuos žinau. Išsiųskite jį kaip trumpą, nuskaitomą pranešimą.';

  @override
  String get taskPromptTomorrowPrep =>
      'Pažiūrėk į mano rytojaus kalendorių. Kiekvienam susitikimui pasakykite man, kas tai yra, kas dalyvauja ir ką turėčiau pasiruošti. Jei rytojus tuščias, nieko nesiųskite.';

  @override
  String get taskPromptNewsDigest =>
      'Internete ieškokite svarbiausių šiandienos naujienų man rūpimomis temomis (naudokite tai, ką prisimenate apie mano pomėgius). Atsiųskite man iki penkių elementų santrauką su vienu sakiniu ir nuoroda.';

  @override
  String get taskPromptWeeklyReview =>
      'Peržiūrėkite mano savaitę: kas nuveikta, kas paslydo ir kas dar atvira. Pasiūlykite tris svarbiausius dalykus, į kuriuos turėtumėte sutelkti dėmesį kitą savaitę.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Susiekite agentui priklausantį telefono numerį. Visi, kuriems leidžiate, gali kalbėtis su juo tiesioginiuose pokalbiuose ir grupėse.';

  @override
  String get whatsappSelfChatDescription =>
      'Susiekite savo numerį ir pasikalbėkite su agentu pokalbyje „Pranešimas sau“. Visi kiti šios paskyros pokalbiai ir grupės yra ignoruojami.';

  @override
  String get chatSendHintMac => '⌘↵ siųsti';

  @override
  String get chatSendHintOther => 'Ctrl + Enter, kad išsiųstumėte';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Šiam galutiniam taškui reikalingas pagrindinis URL.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Pasikeitęs el. pašto adresas patvirtinamas prieš jį naudojant.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Laimi sprendimas, esantis grandinėje aukščiau.';

  @override
  String get aDeletedAccount => 'ištrinta paskyra';

  @override
  String get aFridayLookBackAtThe =>
      'Penktadienio žvilgsnis į savaitę ir kitos planas.';

  @override
  String get aKeyThatAsksForA =>
      'Raktas, kuriame prašoma įvesti PIN kodą arba piršto atspaudą, taip pat pakeičia jūsų dviejų veiksnių kodą.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Kalbos modelis įvertino šį pranešimą, nes „SystemOne“ išjungta.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      '„NeoAgent“ sąrankos metaduomenų failas viršijo saugaus dydžio ribą.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Serveryje yra naujesnė žiniatinklio versija. Įkelkite iš naujo, kad gautumėte naujausią rinkinį.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Privatus darbalaukis su Chromium, failais, teksto redaktoriumi, terminalu ir Python. Jūsų darbas išsaugomas tarp seansų.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Privatus „Linux“ kompiuteris arba „Android“ įrenginys.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Nepavyko atsisiųsti reikiamo NeoAgent sąrankos failo.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Komandos draugas atsiunčia jums kvietimo nuorodą. Kai jūs tai priimsite, jie ';

  @override
  String get aTeammateSentYouAnInvite =>
      'komandos draugas atsiuntė jums kvietimo nuorodą, įveskite ją čia, kad prisijungtumėte prie jų komandos.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Laikinas atsisiuntimas bus išvalytas vėliau.';

  @override
  String get aValueIsStored => 'Išsaugoma vertė.';

  @override
  String get access => 'Prieiga';

  @override
  String get accessActivity => 'Prieigos veikla';

  @override
  String accessArg1(Object? arg1) {
    return 'Prieiga: $arg1';
  }

  @override
  String get accessMode => 'Prieigos režimas';

  @override
  String get accessPermissions => 'Prieigos leidimai';

  @override
  String get accessToken => 'prieigos raktas';

  @override
  String get accessToken2 => 'Prieigos prieigos raktas';

  @override
  String get account => 'Paskyra';

  @override
  String accountArg1(Object? arg1) {
    return 'Sąskaita Nr. $arg1';
  }

  @override
  String get accountChangeAlerts => 'Paskyros keitimo įspėjimai';

  @override
  String get accountEmail => 'Paskyros el';

  @override
  String get accountEmailIsOffUntilThese =>
      'Paskyros el. paštas išjungtas, kol nenustatyti šie: ';

  @override
  String get accountLanguageDescription =>
      '„NeoAgent“ šią kalbą naudoja visur programoje. Kai pirmą kartą prisijungiate, jis seka šį įrenginį. Po to pasirinkimas išsaugomas jūsų paskyroje ir naudojamas kiekviename įrenginyje.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Nepavyko pakeisti kalbos: $error';
  }

  @override
  String get accountLanguageTitle => 'Kalba';

  @override
  String get accountNumber => 'Sąskaitos numeris';

  @override
  String get accountSettings => 'Paskyros nustatymai';

  @override
  String get accounts => 'Paskyros';

  @override
  String get accountsByTokensUsedAllTime =>
      'Paskyros pagal panaudotus žetonus, visą laiką.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'paskyrų debesies kompiuteriuose. Pakeitimai taikomi po serverio ';

  @override
  String get accountsOnThisServer => 'Paskyros šiame serveryje';

  @override
  String get active => 'Aktyvus';

  @override
  String get activeSessions => 'Aktyvūs užsiėmimai';

  @override
  String get activeToday => 'Aktyvus šiandien';

  @override
  String get add => 'Pridėti';

  @override
  String get addAProviderCredentialFirstIts =>
      'Pirmiausia pridėkite teikėjo kredencialą. Jo modeliai čia rodomi vieną kartą ';

  @override
  String get addAgent => 'Pridėti agentą';

  @override
  String get addAnotherSignInMethodBefore =>
      'Prieš pašalindami šį, pridėkite kitą prisijungimo būdą.';

  @override
  String get addBinding => 'Pridėti įrišimą';

  @override
  String get addByNameOrId => 'Pridėti pagal vardą arba ID';

  @override
  String get addByNameOrIdInstead => 'Vietoj to pridėkite pagal vardą arba ID';

  @override
  String get addCredentialBinding => 'Pridėti kredencialų susiejimą';

  @override
  String get addEntry => 'Pridėti įrašą';

  @override
  String get addKey => 'Pridėti raktą';

  @override
  String get addMcpServer => 'Pridėti MCP serverį';

  @override
  String get addMemory => 'Pridėti atmintį';

  @override
  String get memoryReview => 'Peržiūrėti';

  @override
  String get memoryReviewPrompt =>
      'Peržiūrėk visus mano prisiminimus ir sutvarkyk juos: archyvuok dublikatus, pasenusius faktus ir viską, kas neturi ilgalaikės vertės. Tada trumpai pasakyk, ką pakeitei.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Pridėkite daugiau ilgio arba kito tipo simbolių.';

  @override
  String get addPeopleOrGroups => 'Pridėkite žmonių arba grupių';

  @override
  String get addSecurityKey => 'Pridėkite saugos raktą';

  @override
  String get addSomeoneOrAGroup => 'Pridėkite ką nors arba grupę';

  @override
  String get addTask => 'Pridėti užduotį';

  @override
  String get addTests => 'Pridėti testus';

  @override
  String get addTestsForThePartsOf =>
      'Pridėkite testus šio projekto dalims, kurios turi mažiausiai aprėpties, tada paleiskite juos.';

  @override
  String get addTheirOwnKeysInSettings => 'pridėkite savo raktus nustatymuose.';

  @override
  String get addToPrompt => 'Pridėti prie raginimo';

  @override
  String get added => 'Pridėta';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Pridėta $arg1 · Paskutinį kartą naudota $arg2';
  }

  @override
  String get addressWithTheProvider => 'adresą su paslaugų teikėju.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Sureguliuokite garsiakalbio garsumą, peržiūrėkite numatytuosius aparatūros mygtukų nustatymus ir valdykite šią paleidimo seansą.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Koreguokite paieškos arba būsenos filtrą, kad pamatytumėte daugiau pranešimų kanalų.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Čia reguliuokite garsiakalbio garsumą.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Administratorius › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Čia rodomos administratoriaus dotacijos, kvietimų nuorodos ir valdymo pakeitimai.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Išplėstinis rankinis tvarkaraštis ypatingiems atvejams.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Išplėstinė: minutė valanda diena mėnuo savaitės diena.';

  @override
  String get againRightAway => 'iš karto vėl.';

  @override
  String get agent => 'Agentas';

  @override
  String agentArg1(Object? arg1) {
    return 'Agentas: $arg1';
  }

  @override
  String get agentCalls => 'Agento skambučiai';

  @override
  String get agentCommunication => 'Agento bendravimas';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agento bendravimas: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agento režimas redaguoja darbo sritį · ⌘↵ siųsti · ⌘N naujas seansas';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agentas sustoja ir prieš vykdydamas prašo tavo leidimo.';

  @override
  String get agentProfile => 'Agento profilis';

  @override
  String get agentVisibleName => 'Agento matomas vardas';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agentas nori naudoti $arg1. Palieskite, kad nuspręstumėte.';
  }

  @override
  String get agents => 'Agentai';

  @override
  String get aiAnswerUnreadable => 'AI atsakymas neįskaitomas';

  @override
  String get aiProviderKeys => 'AI teikėjo raktai';

  @override
  String get aiUnavailable => 'AI nepasiekiamas';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'įspėjimai ir kiti paskyros el. laiškai iš.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Įspėja, kai žinučių ryšiui reikia vartotojo dėmesio';

  @override
  String get all => 'Visi';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Visi agentai ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Visi $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Šiuo metu naudojami visi debesies kompiuterių lizdai. Po akimirkos bandykite dar kartą.';

  @override
  String get allComputerSlotsAreBusy => 'Visi kompiuterių lizdai užimti';

  @override
  String get allTables => 'Visi stalai';

  @override
  String get allTime => 'Visą laiką';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Leidžiami visi įrankiai – agentas gali naudoti bet kokias galimybes neprašydamas. ';

  @override
  String get allow => 'Leisti';

  @override
  String get allowedRunsWithoutAsking => 'Leidžiama. Bėga neklausęs.';

  @override
  String get allowAll => 'Leisti visiems';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Leiskite „NeoAgent“ „Įdiegti nežinomas programas“, tada bandykite atnaujinti dar kartą.';

  @override
  String get allowOnce => 'Leisti vieną kartą';

  @override
  String get allowSender => 'Leisti siuntėjui';

  @override
  String get allowSession => 'Leisti seansą';

  @override
  String get allowTheAgentToStartAn =>
      'Leiskite agentui pradėti balso skambutį programoje su jumis.';

  @override
  String get allowedOrigins => 'Leidžiama kilmė';

  @override
  String get allowedPathPrefix => 'Leidžiamas kelio priešdėlis';

  @override
  String get allowsYouCanChangeThatPer =>
      'leidžia. Vėliau galėsite tai pakeisti kiekvienam asmeniui. Nuorodos niekada nesuteikia ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'jau priklauso esamai paskyrai';

  @override
  String get alreadyLinkedToAnotherAccount => 'jau susieta su kita paskyra';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'jau susieta su kita neoagent paskyra';

  @override
  String get alreadyUsed => 'jau naudotas';

  @override
  String get always => 'Visada';

  @override
  String get alwaysAllow => 'Visada leisti';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '„Visada leisti“ politika išsaugoma visam laikui – ją galite pakeisti nustatymuose.';

  @override
  String get alwaysAsk => 'Visada klausk';

  @override
  String get alwaysEngage => 'Visada įsitraukite';

  @override
  String get alwaysJoins => 'Visada prisijungia';

  @override
  String get anApiKeyIsRequired => 'Reikalingas API raktas.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Vakaro santrauka apie tai, kas nutiko ir ką toliau daryti.';

  @override
  String get anHttpOrHttpsUrlIs => 'Būtinas http arba https URL.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'ir analitika. Komandos nuorodos veikia komandos puslapyje.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      '„Android“ APK diegimas nepasiekiamas šioje platformoje.';

  @override
  String get androidApp => 'Android programa';

  @override
  String get androidControl => 'Android valdymas';

  @override
  String get androidCouldNotStart => '„Android“ nepavyko paleisti';

  @override
  String get androidNotificationReceived => 'Gautas Android pranešimas';

  @override
  String get androidOnly => 'Tik Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Nepavyko atidaryti „Android“ paketo diegimo programos.';

  @override
  String get androidScreenTapToTouchDrag =>
      '„Android“ ekranas – palieskite, kad paliestumėte, vilkite, kad brauktumėte';

  @override
  String get androidSdk => 'Android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Atsakymai į @minėjimus apie problemas ir užklausas';

  @override
  String get anyone => 'bet kas';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Kiekvienas šios platformos naudotojas gali pranešti apie $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Kiekvienas šios platformos naudotojas gali pranešti apie $arg1 $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Kiekvienas, galintis pasiekti šią paskyrą, gali pasikalbėti su $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Kiekvienas, turintis nuorodą, gali prisijungti, kol baigsis jos galiojimo laikas arba jūs ją atšauksite.';

  @override
  String get apiHttpsOrigin => 'API HTTPS kilmė';

  @override
  String get apiKey => 'API raktas';

  @override
  String get apiKey2 => 'api raktas';

  @override
  String get apiKey3 => 'API raktas';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api raktas antropinis claude openai gpt xai grok google gemini minimax nvidia nim openrouter kredencialai';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API raktai ir galutiniai taškai, skirti AI, paieškos ir balso paslaugų teikėjams. Jie ';

  @override
  String get apiRequest => 'API užklausa';

  @override
  String get apiYourOwnServerASelf =>
      'API – jūsų serveris, savarankiškai priglobtas modelis ar kitas ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Nepavyko atsisiųsti APK naudojant HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Būtinas programos pavadinimas.';

  @override
  String get appUpdates => 'Programų atnaujinimai';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Programos naujiniai šiai versijai nesukonfigūruoti.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Dabartiniam paleidimui pritaikyti $arg1 vairavimo eilės naujinimai.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Pritaikytas $arg1 vairo mechanizmo atnaujinimas (-ai).';
  }

  @override
  String get apply => 'Taikyti';

  @override
  String get applyBehaviorNotes => 'Taikykite elgesio pastabas';

  @override
  String get applyCoreMemory => 'Taikykite pagrindinę atmintį';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Jautrių agentų įrankių patvirtinimo užklausos';

  @override
  String get approvalRequired => 'Reikalingas patvirtinimas';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Patvirtinimas lieka autentifikuotos mobiliosios sesijos viduje, o kiekvieno kodo galiojimas automatiškai baigiasi po trumpo lango.';

  @override
  String get approveLogin => 'Patvirtinti prisijungimą';

  @override
  String get approveQrLogin => 'Patvirtinti QR prisijungimą';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Patvirtinkite tai tik tuo atveju, jei tik dabar pradėjote prisijungti tame įrenginyje.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Patvirtintas prisijungimas prie $arg1.';
  }

  @override
  String get approvedOnly => 'Tik patvirtinta';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Patvirtintas $arg1 poravimas.';
  }

  @override
  String get approvedPeopleAndGroups => 'Patvirtinti žmonės ir grupės';

  @override
  String get approvedPeopleOnly => 'Tik patvirtinti žmonės';

  @override
  String get archive => 'Archyvas';

  @override
  String get archiveAgent => 'Archyvo agentas?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archyvas ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archyvas $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Archyvuoti pasirinktus prisiminimus?';

  @override
  String get areSharedByEveryAccountOn =>
      'yra bendrinami su kiekviena šio serverio paskyra; sąskaitos vis dar gali ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M įvestis';
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
    return 'Reikia $arg1 prieigos';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 sąskaitos';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktyvus';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Pridėta $arg1. Redaguokite jį bet kuriuo metu, kad pakeistumėte ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '„$arg1“ ir jo vykdymo istorija bus visam laikui ištrinta. Bet koks aktyvus bėgimas bus sustabdytas. Failai darbo srityje neliečiami.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Reikalingas $arg1 patvirtinimas';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1 programos aktyvios';
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
    return '$arg1 (aktyvūs $arg2 įrankiai)';
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
    return '$arg1 / $arg2 $arg3: $arg4';
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
    return '$arg1 $arg2 ir $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 pakeistas';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 simboliai';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Sukurta $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '– $arg1 ($arg2) [vietinis adresas: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 atitinka „$arg3“';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent darbo sritis';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 naujos paskyros';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 veikia · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 pavyzdžiai';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 vairo eilės';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 žetonai';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 žetonai';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 ir $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 tapo administratoriumi ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 baitų';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanalas';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 simboliai';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 išvalytas.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 sukonfigūruotas';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 prijungtas. Skiltyje Kas gali siųsti žinutę pasirinkite saugyklas ir žmones.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 pagrindiniai įrašai.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 sukūrė kvietimo nuorodą';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 darbalaukis';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 įvykiai';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 nepavyko';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 nepavyko';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 sugenda';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1, skirtas $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 grupės pažymėtos tik';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'Prieš ${arg1}h';
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
    return '$arg1 pagalbininkai';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 pataikymo koeficientas)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 yra administratorius, todėl paskyros ištrinti negalima ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 užblokuotas $arg2. Atnaujinkite prieigos sąrašą, kad galėtumėte atsakyti.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 prijungtas ir reaguoja.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 nebėra administratorius ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 nepasiekiamas $arg2 (trūksta vykdymo laiko leidimo arba priklausomybės).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 sujungta su $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 vertino LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 raktas$arg2 sukonfigūruotas';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1 raktas pašalintas.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 liko';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 kairėje $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return 'Susietas $arg1';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Prieš ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Įsitikinkite, kad jis veikia, tada bandykite dar kartą.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 tvarko šią paskyrą';
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
    return '$arg1 modeliai paruošti';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 daugiau';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 daugiau žingsnių bėgimo istorijoje';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 perkeltas iš $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 turi būti baigtinis skaičius.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 turi būti http:// arba https:// adresas.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 reikia dėmesio';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent darbo sritis';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 naujos paskyros paskutiniame $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · Nauji pranešimai vadovauja šiam bėgimui';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nauji važiavimai';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 dabar tvarko šią paskyrą.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return 'Leidžiama $arg1 iš 4 leidimų. Failai yra tik jūsų NeoAgent Workspace aplanke.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return 'Įjungtas $arg1 arba $arg2';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 iš $arg2 grupių prisijungia prie įprasto pokalbio';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 iš $arg2 modelių';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 iš $arg2 modelių paruoštas';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 iš $arg2 rinkinio';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Leidžiami $arg1 arba $arg2 įrankiai';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: gerai';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 dieną $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 atsako tik tiems žmonėms, kuriuos pridedate toliau.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 atsako tik pažymėtas';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 kalba tik su žmonėmis ir grupėmis, kuriuos patvirtinate';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Pridėta $arg1 žmonių arba grupių';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 planavimas';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1 tiekėjai';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 paruoštas';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1 įrašai';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 peradresavimo URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registruotas';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 atsakė';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 atšaukė kvietimo nuorodą';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 veikia';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 veikia · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 veikia paskutiniame $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 išsaugotas.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return 'Pasirinktas $arg1';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Parodyta $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 tylėjo';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 vairo mechanizmas $arg2 stovi eilėje';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 žingsnis$arg2 · palieskite mazgą, kad patikrintumėte';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 žingsniai';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 nustojo valdyti $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1 žetonai';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 žetonai paskutiniame $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 įrankiai';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (nepasiekiamas išsaugotas nepaisymas)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return 'Panaudota $arg1 % · Liko $arg2';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 nori su jumis pasikalbėti.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 žiniatinklis';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '„$arg1“ bus pašalintas visam laikui.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 tvarkys šią paskyrą';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 neatsakys šioje platformoje';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 neatsakys į $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Artefaktų saugojimas pagal naudotoją';

  @override
  String get askAQuestionOrStartA =>
      'Užduokite klausimą arba pradėkite užduotį...';

  @override
  String get askBeforeClosingToBackground =>
      'Paklauskite prieš uždarydami foną';

  @override
  String get askMe => 'Paklausk manęs';

  @override
  String get assignedAgent => 'Paskirtas agentas';

  @override
  String get assignedAgent2 => 'Paskirtas agentas';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Paskirtas agentas: $arg1';
  }

  @override
  String get assigneeOptional => 'Perėmėjas (neprivaloma)';

  @override
  String get assistant => 'Padėjėjas';

  @override
  String get assistantKey131 => 'Asistento raktas 131';

  @override
  String get atLeast1 => 'Bent 1.';

  @override
  String get attachFiles => 'Pridėkite failus';

  @override
  String attentionArg1(Object? arg1) {
    return 'Dėmesio $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'audito žurnalas admin dotacija atšaukti kvietimo komandos istoriją';

  @override
  String get authMethod => 'Auth metodas';

  @override
  String get authServerUrl => 'Auth serverio URL';

  @override
  String get authentication => 'Autentifikavimas';

  @override
  String get authenticationFailed => 'Autentifikuoti nepavyko.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Autentifikavimas vis dar laukiamas. Užbaikite naršyklės eigą ir bandykite dar kartą.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Autentifikavimas vis dar laukiamas. Užbaikite naršyklės eigą ir atnaujinkite.';

  @override
  String get authenticationTimedOut =>
      'Baigėsi autentifikavimo skirtasis laikas.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Autentifikavimas buvo atšauktas prieš baigiant.';

  @override
  String get authenticatorApp => 'Autentifikavimo programa';

  @override
  String get authenticatorCode => 'Autentifikatoriaus kodas';

  @override
  String get authorOptional => 'Autorius (neprivaloma)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automatinis (pirmasis teikėjas su API raktu)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automatinis maršrutas į geriausią turimą modelį';

  @override
  String get automaticFast => 'Automatinis (greitas)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automatinis nuskaito kambarį ir paprastai sulaiko. „Tik paminėjimas“ nepriima jokio sprendimo, kol nebus tiesiogiai kreiptasi.';

  @override
  String get automaticReserved => 'Automatinis, rezervuotas';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automatinį atšaukimą reikia bandyti dar kartą iš sąrankos ekrano.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automatinis parenka greitą modelį per įprastą modelių katalogą.';

  @override
  String get automation => 'Automatika';

  @override
  String get available => 'Yra';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Vėl galima įsigyti $arg1';
  }

  @override
  String get availableAgainShortly => 'Greitai vėl bus galima';

  @override
  String get availableInTheDesktopAppFor =>
      'Galima naudoti darbalaukio programoje, skirtoje „MacOS“, „Windows“ ir „Linux“.';

  @override
  String get availableToTheAgent => 'Prieinama agentui';

  @override
  String get averageAllTime => 'Vidutiniškai, visą laiką';

  @override
  String get avgImp => 'Vid. parod.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Vid. / paleidimas: $arg1 žetonai';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Venkite pasikartojančių simbolių ir akivaizdžių sekų.';

  @override
  String get awaitingScan => 'Laukiama nuskaitymo';

  @override
  String get back => 'Atgal';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count fone';
  }

  @override
  String get backgroundTasks => 'Fono užduotys';

  @override
  String get backOn => 'atgal.';

  @override
  String get backToChat => 'Grįžti į pokalbį';

  @override
  String get backToFolder => 'Atgal į aplanką';

  @override
  String get backToSignIn => 'Atgal prisijungti';

  @override
  String get backendChannel => 'Backend kanalas';

  @override
  String get backendOnThisComputer => 'Backend šiame kompiuteryje';

  @override
  String get backendSync => 'Backend sinchronizavimas';

  @override
  String get backgroundLocationNeeded => 'Reikalinga fono vieta';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      '„Android“ fono sinchronizavimas išlieka suplanuotas';

  @override
  String get badState => 'Bloga būklė: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Paleidžiamų QEMU virtualių mašinų pagrindinis vaizdas ir dydis ';

  @override
  String get baseUrlOptional => 'Bazinis URL (neprivaloma)';

  @override
  String get baseUrlTokenLocal => 'bazinis URL prieigos raktas vietinis';

  @override
  String get basicAuthentication => 'Pagrindinis autentifikavimas';

  @override
  String get behaviorModules => 'Elgesio moduliai';

  @override
  String get behaviorNotes => 'elgesio pastabos';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => '„Bitwarden“ kredencialų brokeris';

  @override
  String get bitwardenItem => 'Bitwarden elementas';

  @override
  String get bitwardenServer => 'Bitwarden serveris';

  @override
  String get blankUsesCommon => 'Tuščias vartoja „įprastas“';

  @override
  String get blankUsesTheDefaultCallback =>
      'Tuščia naudoja numatytąjį atgalinį skambutį';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Tuščios vertės naudoja numatytuosius teikėjo nustatymus.';

  @override
  String get block => 'Blokuoti';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Užblokuotas gaunamas pranešimas iš $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Su BlueBubbles suderinamas tiltas';

  @override
  String get bluebubblesServerUrl => '„BlueBubbles“ serverio URL';

  @override
  String get botToken => 'Boto ženklas';

  @override
  String get botTokenAndApprovedChats =>
      'Boto prieigos raktas ir patvirtinti pokalbiai';

  @override
  String get botTokenAndServerChannelAccess =>
      'Boto prieigos raktas ir serverio / kanalo prieiga';

  @override
  String get botTokenEventsApiAndChannel =>
      'Boto prieigos raktas, įvykių API ir prieiga prie kanalo';

  @override
  String get botUserId => 'Boto vartotojo ID';

  @override
  String get botUsername => 'Boto vartotojo vardas';

  @override
  String get brandName => 'Prekės ženklo pavadinimas';

  @override
  String get braveSearch => 'Drąsi paieška';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Sujunkite bet kurį teikėją, galintį skelbti ir gauti „Webhook“ naudingąsias apkrovas.';

  @override
  String get bringYourOwnKey => 'atsinešk savo raktą';

  @override
  String get bringYourOwnKey2 => 'Atsineškite savo raktą';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Naršyklė, „Linux“ darbalaukis, failai, terminalas ir „Python“ bendrina vieną nuolatinį debesies kompiuterį.';

  @override
  String get browserLogin => 'Naršyklės prisijungimas';

  @override
  String get browserScripting => 'Naršyklės scenarijus';

  @override
  String get call => 'Skambinti';

  @override
  String get callAgent => 'Skambinkite agentui';

  @override
  String get callUser => 'Skambinti vartotojui';

  @override
  String get calledByName => 'Pašauktas vardu';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Gali deleguoti užduotis kitiems agentams';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Galima deleguoti $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Gali priimti deleguotas užduotis';

  @override
  String get cancel => 'Atšaukti';

  @override
  String get cancelTask => 'Atšaukti užduotį';

  @override
  String get cannotPreview => 'Negalima peržiūrėti';

  @override
  String get cannotReceiveDelegatedTasks => 'negali gauti deleguotų užduočių';

  @override
  String get cannotRunYet => 'dar negali bėgti.';

  @override
  String get capturedThePage => 'Užfiksavo puslapį';

  @override
  String get category => 'Kategorija';

  @override
  String chainArg1(Object? arg1) {
    return 'Grandinė: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Pakeiskite sąrankos režimą';

  @override
  String get channel => 'Kanalas';

  @override
  String get channelAccessToken => 'Prieigos prie kanalo prieigos raktas';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanalas: $arg1$arg2 | Atnaujinimo versija: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Kanalo apimties socialinė atmintis';

  @override
  String get channels => 'Kanalai';

  @override
  String get chat => 'Pokalbis';

  @override
  String get chatId => 'Pokalbio ID';

  @override
  String get chatMode => 'Pokalbių režimas';

  @override
  String get chatModel => 'Pokalbių modelis';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Patikrinkite automatiškai paleidžiant';

  @override
  String get checkForMessagesEveryMs =>
      'Patikrinkite, ar nėra pranešimų kas (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Automatiškai patikrinkite, ar nėra naujų pranešimų';

  @override
  String get checkNow => 'Patikrinkite dabar';

  @override
  String get checkYourEmailToConfirmYour =>
      'Prieš prisijungdami patikrinkite savo el. paštą, kad patvirtintumėte savo NeoAgent paskyrą.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Patikrintas $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Pasirinkite kategoriją arba ieškokite visuose nustatymuose.';

  @override
  String get chooseAPerson => 'Pasirinkite žmogų';

  @override
  String get chooseAProjectFolder => 'Pasirinkite projekto aplanką';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Pasirinkite numatytuosius pokalbių, agentų, atsarginės elgsenos ir išmaniojo maršruto parinkimo nustatymus.';

  @override
  String get chooseGroups => 'Pasirinkite grupes';

  @override
  String get chooseHowMuchYouWantTo =>
      'Pasirinkite, kiek norite konfigūruoti dabar. Abi parinktys gali būti pakeistos vėliau.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Pasirinkite, kaip ši užduotis turėtų prasidėti. Rankinis režimas veikia tik naudojant Run Now. Tvarkaraštis pagrįstas laiku. Integracija suaktyvina prijungtas oficialias programas.';

  @override
  String get chooseOneToGetStartedNow =>
      'Pasirinkite vieną, kad pradėtumėte dabar. Vėliau galėsite pridėti daugiau.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Nustatymuose pasirinkite tiesioginį modelį ir balsą.';

  @override
  String get chooseTheirGroup => 'Pasirinkite jų grupę';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Pasirinkite, kur šiam asmeniui turėtų būti leista kalbėtis su $arg1. Vėliau galėsite tai pakeisti skiltyje Kas gali pranešti.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Pasirinkite, prie kurių grupių $arg1 turėtų prisijungti net tada, kai niekas jos nepažymi. Ši platforma gali neatskirti žymų nuo įprastų pranešimų.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Pasirinkite, kuriuos modelius gali pasirinkti kiekviena šio serverio paskyra ir ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Pasirinkite, su kuo $arg1 kalbasi ir kada jis prisijungia prie grupės pokalbių.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Pasirinkite, kas gali pasiekti $arg1, tada išsaugokite pakeitimus.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Pasirinkite, kas gali pranešti agentui „WhatsApp“ kortelėje nurodydamas „Kas gali pranešti“.';

  @override
  String get chooseYourDefaultModel => 'Pasirinkite\nnumatytąjį modelį.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      '„Chromium“, failai, teksto rengyklė ir terminalas yra pasiekiami „Linux“ darbalaukyje.';

  @override
  String get claudeCode => 'Klodas Kodas';

  @override
  String get clear => 'Išvalyti';

  @override
  String get clearAll => 'Išvalyti viską';

  @override
  String clearArg1(Object? arg1) {
    return 'Išvalyti $arg1?';
  }

  @override
  String get clearFilter => 'Išvalytas filtras';

  @override
  String get clearFilters => 'Išvalyti filtrai';

  @override
  String get clearSearch => 'Išvalyti paiešką';

  @override
  String get clearView => 'Aiškus vaizdas';

  @override
  String get cliSession => 'CLI sesija';

  @override
  String get clickIsNotSupportedOnThis =>
      'paspaudimas šioje platformoje nepalaikomas.';

  @override
  String get clickOnceToBeginCapturing =>
      'Spustelėkite vieną kartą, kad pradėtumėte fiksuoti';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Spustelėkite, įveskite ir sąveikaukite su darbalaukio programomis.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Spustelėta ties ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Paspaudėte naršyklėje';

  @override
  String get clientId => 'Kliento ID';

  @override
  String get clientSecret => 'Kliento paslaptis';

  @override
  String get close => 'Uždaryti';

  @override
  String get closeJ => 'Uždaryti (⌘J)';

  @override
  String get closeTeachMode => 'Uždaryti mokymo režimą';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Uždarius langą, „NeoAgent“ gali veikti fone su prieiga prie dėklo arba visiškai išjungti darbalaukio vykdymo laiką.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Palaikomi debesies ir savarankiškai priglobti egzemplioriai. Vietiniai ir privataus tinklo URL veikia, kai „NeoAgent“ gali juos pasiekti.';

  @override
  String get cloudComputer => 'Debesų kompiuteris';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Debesų kompiuteris · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Debesų kompiuterio nustatymai išsaugoti. Iš naujo paleiskite serverį, kad juos pritaikytumėte.';

  @override
  String get cloudComputerVm => 'Debesų kompiuteris (VM)';

  @override
  String get cloudComputers => 'Debesų kompiuteriai';

  @override
  String get codeHosting => 'Kodo talpinimas';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Kableliais atskirti kanalų pavadinimai be #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Atskirti kableliais, pvz., #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Atskirtas kableliu. Problema turi turėti juos visus.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepavyko atlikti komandos ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Būtina komanda.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Komandų išvesties akumuliatorius neaktyvus.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepavyko įkelti komandos išvesties ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Komandos išvesties įkėlimas praleisti artefaktų metaduomenys.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Komandos išvestis jau buvo baigta.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Komandos ir programos';

  @override
  String get commandsRunInTheSamePersistent =>
      'Komandos vykdomos tame pačiame nuolatiniame kompiuteryje, kurį naudoja matomas darbalaukis.';

  @override
  String get communityChatops => 'Bendruomenė ir „ChatOps“.';

  @override
  String get completeSetup => 'Užbaikite sąranką';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Užbaikite darbo eigą darbalaukyje.';

  @override
  String get completed => 'Užbaigta';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Visiškai užblokuota – agentas negali naudoti šios kategorijos.';

  @override
  String get computerShell => 'Kompiuterio apvalkalas';

  @override
  String get computerUsedByThisSession =>
      'Šios sesijos metu naudojamas kompiuteris';

  @override
  String get computerWorkspace => 'Kompiuterio darbo vieta';

  @override
  String get configurablePersonalWebhookBridge =>
      'Konfigūruojamas asmeninis webhook tiltas';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Konfigūruojama relė arba webhook tiltas';

  @override
  String get configurableTalkWebhookBridge =>
      'Konfigūruojamas „Talk Webhook“ tiltas';

  @override
  String get configurableWebInboxBridge =>
      'Konfigūruojamas žiniatinklio gautųjų tiltas';

  @override
  String get configurableWebhookBridge => 'Konfigūruojamas webhook tiltas';

  @override
  String get configurableWebhooks => 'Konfigūruojami žiniatinklio kabliukai';

  @override
  String get configurationOrInTheEnvFile => 'konfigūracija arba .env faile.';

  @override
  String get configure => 'Konfigūruoti';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Konfigūruokite darbo srities elgesį ir modelio numatytuosius nustatymus.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Sukonfigūruotas $arg1';
  }

  @override
  String get confirmEmailChanges => 'Patvirtinkite el. pašto pakeitimus';

  @override
  String get confirmNewSignUps => 'Patvirtinkite naujas registracijas';

  @override
  String get confirmPassword => 'Patvirtinkite slaptažodį';

  @override
  String get confirmPassword2 => 'Patvirtinkite slaptažodį';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Prieš prisijungdami patvirtinkite savo el. pašto adresą. Patikrinkite NeoAgent tarnybos el. pašto pranešimą.';

  @override
  String get connect => 'Prisijunkite';

  @override
  String get connectAMessagingPlatform =>
      'Prisijunkite prie\npranešimų platformos.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Prijunkite viešąjį HTTPS namų asistento galinį tašką naudodami ilgalaikį prieigos raktą. Serveris blokuoja vietinio, grįžtamojo ryšio ir privataus tinklo adresus.';

  @override
  String get connectAccount => 'Prijunkite paskyrą';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Prijunkite programų paskyras atskirai, kad AI galėtų naudoti tinkamą paskyrą kiekvienai oficialiai integracijai.';

  @override
  String connectArg1(Object? arg1) {
    return 'Prijunkite $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Prijunkite tiek paskyrų, kiek norite. Kiekviena programa gali naudoti skirtingą paskyrą.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Prijunkite kanalus, pasirinkite, su kuo $arg1 kalba, ir žiūrėkite naujausią veiklą.';
  }

  @override
  String get connectInstance => 'Prisijungimo egzempliorius';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Pirmiausia prijunkite šią integraciją, kad pasirinktumėte paskyrą.';

  @override
  String get connectToThisServer => 'Prisijunkite prie šio serverio';

  @override
  String get connectWhatsapp => 'Prisijunkite prie „WhatsApp“.';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Prijunkite „Nextcloud“ egzempliorių, įskaitant savarankiškus serverius. „NeoAgent“ atidaro „Nextcloud“ prisijungimo puslapį, kad galėtumėte prisijungti naudodami slaptažodį, SSO arba 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Prijunkite savo „NeoRecall“ serverį. „NeoAgent“ gauna tik skaitymo prieigą prie vietinės paieškos, prisiminimų ir nuorašo įrodymų, kai patvirtinate „OAuth“ ekraną.';

  @override
  String get connected => 'Prisijungta';

  @override
  String get connectedAccount => 'Prijungta paskyra';

  @override
  String connectedArg1(Object? arg1) {
    return 'Prijungtas $arg1';
  }

  @override
  String get connectedInstance => 'Prijungtas egzempliorius';

  @override
  String get connectedNeorecallUser => 'Prisijungęs NeoRecall vartotojas';

  @override
  String get connectedNextcloudUser => 'Prisijungęs Nextcloud vartotojas';

  @override
  String get connectedServer => 'Prijungtas serveris';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Prisijungiama prie tiesioginio balso modelio...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Jungtis #$arg1';
  }

  @override
  String get connectionId => 'Ryšio ID';

  @override
  String get connectionLooksGood => 'Ryšys atrodo gerai.';

  @override
  String get connectionMethod => 'Prisijungimo būdas';

  @override
  String get containsTextOptional => 'Yra tekstas (neprivaloma)';

  @override
  String get content => 'Turinys';

  @override
  String get contentSecurityPolicy => 'turinio saugumo politika';

  @override
  String get continue2 => 'Tęsti';

  @override
  String get continueFullSetup => 'Tęskite visą sąranką';

  @override
  String get continueRun => 'Tęskite bėgimą';

  @override
  String get continueToSetup => 'Tęskite sąranką';

  @override
  String get controlSurface => 'VALDYMO PAVIRŠIAUS';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Valdo prieigą prie $arg1 įrankių.';
  }

  @override
  String get conversation => 'Pokalbis';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Pokalbio ID naudojamas, kai šis agentas pradeda pokalbį.';

  @override
  String get cookieSetup => 'Slapukų nustatymas';

  @override
  String get cookiesNotConfigured => 'Slapukai nesukonfigūruoti';

  @override
  String get copiedAsCsv => 'Nukopijuota kaip CSV';

  @override
  String get copiedDebugInfo => 'Nukopijuota derinimo informacija';

  @override
  String get copiedExportForTheLast5 =>
      'Nukopijuotas paskutinių 5 pranešimų eksportavimas';

  @override
  String get copiedFullPrompt => 'Nukopijuotas visas raginimas';

  @override
  String get copiedLogs => 'Nukopijuoti žurnalai';

  @override
  String get copiedRunId => 'Nukopijuotas vykdymo ID';

  @override
  String get copy => 'Kopijuoti';

  @override
  String get copyAll => 'Nukopijuoti viską';

  @override
  String get copyCodes => 'Nukopijuokite kodus';

  @override
  String get copyCsv => 'Nukopijuokite CSV';

  @override
  String get copyDebugInfo => 'Nukopijuoti derinimo informaciją';

  @override
  String get copyLink => 'Nukopijuoti nuorodą';

  @override
  String get copyLogs => 'Kopijuoti žurnalus';

  @override
  String get copyPrompt => 'Kopijuoti raginimą';

  @override
  String get copyResponse => 'Nukopijuokite atsakymą';

  @override
  String get copyRunId => 'Nukopijuokite vykdymo ID';

  @override
  String get copyWebhookUrl => 'Nukopijuokite „Webhook“ URL';

  @override
  String get core => 'Šerdis';

  @override
  String get coreMemory => 'pagrindinė atmintis';

  @override
  String get coreServicesThisServerDependsOn =>
      'Pagrindinės paslaugos, nuo kurių priklauso šis serveris.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domeno https viešojo URL kilmė';

  @override
  String get couldHelp => 'Galėtų padėti';

  @override
  String get couldNotApproveQrLogin => 'Nepavyko patvirtinti QR prisijungimo.';

  @override
  String get couldNotApproveQrPairing => 'Nepavyko patvirtinti QR susiejimo.';

  @override
  String get couldNotConnect => 'Nepavyko prisijungti.';

  @override
  String get couldNotCreateBinding => 'Nepavyko sukurti įrišimo.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Nepavyko ištrinti paskyros: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Nepavyko atjungti „Bitwarden“.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Nepavyko atjungti namų asistento.';

  @override
  String get couldNotDisconnectNeorecall => 'Nepavyko atjungti NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'Nepavyko atjungti Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'Nepavyko atjungti „Trello“.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Nepavyko eksportuoti duomenų: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Nepavyko įkelti sprendimų';

  @override
  String get couldNotLoadUsageData => 'Nepavyko įkelti naudojimo duomenų.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Nepavyko automatiškai atidaryti „Linux“ nustatymų.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Nepavyko atidaryti teikėjo susiejimo puslapio.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Nepavyko atidaryti teikėjo prisijungimo puslapio.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Nepavyko atidaryti leidimo ištekliaus.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Nepavyko atidaryti „Trello“ naršyklėje.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Nepavyko atidaryti darbo srities failo atsisiuntimo.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Nepavyko nuskaityti „Android“ programos paketo.';

  @override
  String get couldNotReadTheApk => 'Nepavyko perskaityti APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Nepavyko pašalinti rakto: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Nepavyko išsaugoti agento.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Nepavyko išsaugoti „Bitwarden“ sąrankos.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Nepavyko išsaugoti namų asistento sąrankos.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Nepavyko išsaugoti NeoRecall sąrankos.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nepavyko išsaugoti Nextcloud sąrankos.';

  @override
  String get couldNotSaveTrelloSetup => 'Nepavyko išsaugoti „Trello“ sąrankos.';

  @override
  String get couldNotSendConfirmationEmail =>
      'nepavyko išsiųsti patvirtinimo el';

  @override
  String get couldNotStart => 'Nepavyko pradėti';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Sukurti';

  @override
  String get createAPasswordFirstToChange =>
      'Pirmiausia sukurkite slaptažodį, kad pakeistumėte paskyros el.';

  @override
  String get createAPasswordOrLinkAnother =>
      'sukurkite slaptažodį arba susiekite kitą teikėją prieš pašalindami šį prisijungimo būdą';

  @override
  String get createATaskWhileThisAgent =>
      'Sukurkite užduotį, kol šis agentas pasirinktas.';

  @override
  String get createLink => 'Sukurti nuorodą';

  @override
  String get createOrModifyFilesInYour =>
      'Kurkite arba keiskite failus savo darbo srityje.';

  @override
  String get createPassword => 'Sukurti slaptažodį';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Kurkite specializuotus robotus su atskira atmintimi, nustatymais, įrankiais ir paskyros priskyrimais.';

  @override
  String get createTheFirstAccount => 'Sukurkite pirmąją paskyrą';

  @override
  String get createUpdateOrDeleteSkills =>
      'Kurkite, atnaujinkite arba ištrinkite įgūdžius.';

  @override
  String get creatingYourSkill => 'Kuriame savo įgūdžius…';

  @override
  String get credentialBindings => 'Įgaliojimų apkaustai';

  @override
  String get credentialUse => 'Kredencialų naudojimas';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron pagrįsti pasikartojantys paleidimai ir vienkartinis vykdymas su laiku.';

  @override
  String get cronExpression => 'Krono išraiška';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter vykdo užklausą.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + tarpas';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Dabartinis el. pašto adresas: $arg1';
  }

  @override
  String get currentPassword => 'Dabartinis slaptažodis';

  @override
  String get currentPasswordIsIncorrect => 'dabartinis slaptažodis neteisingas';

  @override
  String get currentTwoStepLoginCode =>
      'Dabartinis dviejų žingsnių prisijungimo kodas';

  @override
  String get customAccess => 'Pasirinktinė prieiga';

  @override
  String get customCron => 'Custom Cron';

  @override
  String get customCronMustHave5Fields => 'Custom Cron turi turėti 5 laukus.';

  @override
  String get customEndpoint => 'pasirinktinis galutinis taškas';

  @override
  String get customField => 'Pasirinktinis laukas';

  @override
  String get customHeader => 'Tinkinta antraštė';

  @override
  String get customHeadersJson => 'Tinkintos antraštės (JSON)';

  @override
  String get customOpenaiCompatible => 'Pasirinktinis su OpenAI suderinamas';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Pasirinktinis su OpenAI suderinamas galutinis taškas';

  @override
  String get customOutgoingUrl => 'Pasirinktinis siunčiamas URL';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Kasdien';

  @override
  String get dailyRecap => 'Dienos santrauka';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'duomenų bazės užklausa pasirinkite csv šablonus';

  @override
  String dayArg1(Object? arg1) {
    return 'Diena $arg1';
  }

  @override
  String get dayOfMonth => 'Mėnesio diena';

  @override
  String get decideWhichToolsYourAgentMay =>
      'nuspręsti, kokias priemones gali naudoti jūsų agentas. Jie mato tavo vardą ir ';

  @override
  String get decisionHigherUpTheChainWins =>
      'sprendimą aukščiau grandinė laimi ir parodo užraktą su ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Sprendimai rodomi čia, nes $arg1 nuskaito patvirtintas $arg2 grupes. Saugomi tik 30 naujausių ir jie nustatomi iš naujo, kai serveris paleidžiamas iš naujo.';
  }

  @override
  String get decline => 'Atmesti';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'gilus bėgimas · žingsnis $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram raktas';

  @override
  String get default2 => 'Numatytoji';

  @override
  String get default3 => 'NUMATYTOJI';

  @override
  String defaultArg1(Object? arg1) {
    return 'Numatytasis ($arg1)';
  }

  @override
  String get defaultConversation => 'Numatytasis pokalbis';

  @override
  String get defaultForNewGroups => 'Numatytoji naujoms grupėms';

  @override
  String get defaultGroupParticipation => 'Numatytasis grupės dalyvavimas';

  @override
  String get defaultNeoagentWorkspace => 'Numatytoji NeoAgent darbo sritis';

  @override
  String get defaultOpenai => 'Numatytasis (OpenAI)';

  @override
  String get defaultRateLimits => 'Numatytosios normos ribos';

  @override
  String get defaultRateLimitsSaved => 'Išsaugotos numatytosios normos ribos.';

  @override
  String get defaultRecommended => 'Numatytoji (rekomenduojama)';

  @override
  String get defaultRouting => 'Numatytasis maršrutas';

  @override
  String get defaultSpace => 'Numatytoji erdvė';

  @override
  String get delete => 'Ištrinti';

  @override
  String get deleteAccount => 'Ištrinti paskyrą';

  @override
  String get deleteAccountPermanently => 'Ištrinti paskyrą visam laikui?';

  @override
  String get deleteAnAccount => 'Ištrinti paskyrą';

  @override
  String deleteArg1(Object? arg1) {
    return 'Ištrinti @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Ištrinti ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Ištrinti $arg1 $arg2 visam laikui?';
  }

  @override
  String get deleteBinding => 'Ištrinti įrišimą';

  @override
  String get deleteCoreMemoryEntry => 'Ištrinti pagrindinės atminties įrašą?';

  @override
  String get deleteForever => 'Ištrinti visam laikui';

  @override
  String get deleteMcpServer => 'Ištrinti MCP serverį?';

  @override
  String get deleteMemory => 'Ištrinti atmintį?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Ištrinti visam laikui ištrina paskyrą ir visus jos duomenis ';

  @override
  String get deleteRun => 'Ištrinti paleidimą?';

  @override
  String get deleteRun2 => 'Ištrinti paleidimą';

  @override
  String get deleteSelectedMemories => 'Ištrinti pasirinktus prisiminimus?';

  @override
  String get deleteSession => 'Ištrinti sesiją?';

  @override
  String get deleteSkill => 'Ištrinti įgūdžius?';

  @override
  String get deleteTask => 'Ištrinti užduotį?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Ištrintas „$arg1“.';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Ištrinti @$arg1 ir visi jų duomenys.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Ištrynus pašalinami visi jūsų pokalbiai, prisiminimai, failai, užduotys ir ';

  @override
  String get deliverableArtifactProduced => 'Pagamintas pristatymas artefaktas';

  @override
  String get deliverableCompleted => 'Pristatymas baigtas';

  @override
  String get deliverableExecutionStarted => 'Pradėtas pristatymo vykdymas';

  @override
  String get deliverableSelected => 'Pasirinktas pristatymas';

  @override
  String get deliverableValidationFailed =>
      'Pateikiamas patvirtinimas nepavyko';

  @override
  String get deliverableValidationStarted =>
      'Pradėtas pristatymo patvirtinimas';

  @override
  String get deny => 'Neigti';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Aprašykite rezultatą, tada parodykite jį darbalaukyje';

  @override
  String get describeWhatToBuildOrChange => 'Aprašykite, ką statyti ar keisti…';

  @override
  String get description => 'Aprašymas';

  @override
  String get desktopApp => 'Darbalaukio programa';

  @override
  String get desktopAppControlsAvailable =>
      'Galimi darbalaukio programų valdikliai';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Darbalaukio fiksavimas šioje platformoje negalimas.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Darbalaukio komandos išvesties įkėlimas atšauktas.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Kompanioninė darbalaukio komanda buvo atšaukta.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Baigėsi stalinio kompiuterio papildomo ryšio skirtasis laikas.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Baigėsi stalinio kompiuterio kompaniono rankos paspaudimo laikas.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Darbalaukio kompanionas čia nepasiekiamas.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Darbalaukio kompanionas pristabdytas vietoje.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Nepavyko apdoroti darbalaukio papildomo pranešimo: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Stalinio kompiuterio pagalbinių leidimų nustatymai nepasiekiami žiniatinklyje.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Stalinio kompiuterio leidimo nustatymai nepasiekiami šioje platformoje.';

  @override
  String get desktopCompanionRejected => 'Darbalaukio kompanionas atmestas.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Nepavyko atsakyti į darbalaukį: $arg1';
  }

  @override
  String get desktopControl => 'Darbalaukio valdymas';

  @override
  String get desktopFailedToStart => 'Nepavyko paleisti darbalaukio';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Nepavyko užfiksuoti darbalaukio srauto: $arg1';
  }

  @override
  String get destinationId => 'Paskirties vietos ID';

  @override
  String get deviceAccess => 'Prieiga prie įrenginio';

  @override
  String get deviceSettings => 'Įrenginio nustatymai';

  @override
  String get devices => 'Prietaisai';

  @override
  String get diagnosticsSaved => 'Diagnostika išsaugota.';

  @override
  String get directBluebubblesImessageBridge =>
      'Tiesioginis BlueBubbles iMessage tiltas';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Tiesioginiai pranešimai išlieka atsakingi. Leidžiamos grupės naudoja toliau pateiktą dalyvavimo režimą.';

  @override
  String get directoryDoesNotExist => 'Katalogas neegzistuoja.';

  @override
  String get disable2fa => 'Išjungti 2FA';

  @override
  String get disableAll => 'Išjungti viską';

  @override
  String get discard => 'Išmesti';

  @override
  String get disconnect => 'Atsijungti';

  @override
  String get disconnectHomeAssistant => 'Atjungti namų asistentą?';

  @override
  String get disconnectNeorecall => 'Atjungti NeoRecall?';

  @override
  String get disconnectNextcloud => 'Atjungti Nextcloud?';

  @override
  String get disconnectPlatform => 'Atjunkite platformą';

  @override
  String get disconnectTrello => 'Atjungti „Trello“?';

  @override
  String get discoveryFailed => 'Atradimas nepavyko';

  @override
  String get dismiss => 'Atsisakyti';

  @override
  String get displayIdIsRequired => 'Reikalingas rodymo ID.';

  @override
  String get displayName => 'Rodomas vardas';

  @override
  String get displayNameMustBe64Characters =>
      'Rodomas pavadinimas turi būti sudarytas iš 64 ar mažiau simbolių.';

  @override
  String get displayNameSaved => 'Rodomas vardas išsaugotas.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Neįtraukite savo vartotojo vardo ar el.';

  @override
  String get done => 'Atlikta';

  @override
  String get downloadACopyOfYourData =>
      'Atsisiųskite savo duomenų kopiją. Administratoriaus paskyrų ištrinti negalima ';

  @override
  String get downloadACopyOfYourData2 =>
      'Atsisiųskite savo duomenų kopiją arba visam laikui ištrinkite paskyrą. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Atsisiųskite $arg1';
  }

  @override
  String get downloadUpdate => 'Atsisiųskite naujinimą';

  @override
  String get downloadingTheNeoagentBackend => 'Atsisiunčiama NeoAgent backend';

  @override
  String get draft => 'Juodraštis';

  @override
  String get dragIsNotSupportedOnThis =>
      'vilkimas šioje platformoje nepalaikomas.';

  @override
  String get draggedOnTheScreen => 'Nutemptas ekrane';

  @override
  String get dropAnApkOrApkBundle =>
      'Nuvilkite APK arba APK paketą čia, kad jį įdiegtumėte';

  @override
  String get dropApkOrApksHere => 'Nuvilkite APK arba .apks čia';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Patvarios balso ir sąveikos stiliaus instrukcijos. Saugos ir vykdymo taisyklėms vis dar teikiama pirmenybė.';

  @override
  String get eGAlexSLaptop => 'pvz. Alekso nešiojamasis kompiuteris';

  @override
  String get eGMyLocalServer => 'pvz. Mano vietinis serveris';

  @override
  String get edit => 'Redaguoti';

  @override
  String get editAgent => 'Redaguoti agentą';

  @override
  String get editCoreMemoryEntry => 'Redaguoti pagrindinės atminties įrašą';

  @override
  String get editInstructions => 'Redaguoti instrukcijas';

  @override
  String get editMcpServer => 'Redaguoti MCP serverį';

  @override
  String get editTask => 'Redaguoti užduotį';

  @override
  String editedArg1(Object? arg1) {
    return 'Redaguota $arg1';
  }

  @override
  String get email => 'El. paštas';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'El. pašto paskyrų savininkams apie neįprastai atrodančius prisijungimus.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'El. paštu paskyrų savininkams, kai pasikeičia jų paskyros duomenys.';

  @override
  String get emailCode => 'Pašto kodas';

  @override
  String get emailConfirmationRequired => 'reikalingas patvirtinimas el';

  @override
  String get emailIsAlreadyInUse => 'paštas jau naudojamas';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'El. paštas išsaugotas. Jei reikalingas patvirtinimas, patikrinkite naują adresą, kuriame yra NeoAgent patvirtinimo nuoroda.';

  @override
  String get emailSettingsSaved => 'El. pašto nustatymai išsaugoti.';

  @override
  String get emailUnverified => 'El. pašto adresas nepatvirtintas';

  @override
  String get empty => 'Tuščia';

  @override
  String get emptyFile => 'Tuščias failas';

  @override
  String get emptyFolder => 'Tuščias aplankas';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Empty naudoja numatytuosius serverio nustatymus ($arg1).';
  }

  @override
  String get enable2fa => 'Įgalinti 2FA';

  @override
  String get enableAll => 'Įgalinti viską';

  @override
  String get enableBehaviorModules => 'Įgalinti elgesio modulius';

  @override
  String get enableOrDisableModels => 'Įjungti arba išjungti modelius';

  @override
  String get enabled => 'Įjungta';

  @override
  String get encryptedPrivateToYourAccount => 'Šifruota, privati jūsų paskyrai';

  @override
  String get end => 'Pabaiga';

  @override
  String get endCall => 'Baigti skambutį';

  @override
  String get endVoiceCall => 'Baigti balso skambutį?';

  @override
  String get endpoint => 'Galutinis taškas';

  @override
  String get enterAPassword => 'Įveskite slaptažodį.';

  @override
  String get enterAUsername => 'Įveskite vartotojo vardą.';

  @override
  String get enterAValidEmailAddress => 'Įveskite galiojantį el. pašto adresą.';

  @override
  String get enterAnAddressManually => 'Įveskite adresą rankiniu būdu';

  @override
  String get enterAnApiKeyFirst => 'Pirmiausia įveskite API raktą.';

  @override
  String get enterInviteLink => 'Įveskite kvietimo nuorodą';

  @override
  String get enterTheAddressOfANeoagent => 'Įveskite NeoAgent serverio adresą.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Įveskite $arg1 pateiktą informaciją, kad $arg2 galėtų siųsti ir gauti pranešimus.';
  }

  @override
  String get enterYour2faOrRecoveryCode => 'Įveskite 2FA arba atkūrimo kodą.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Įveskite dabartinį slaptažodį, kad jį pakeistumėte.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Įveskite dabartinį slaptažodį, kad išsaugotumėte el. pašto pakeitimus.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Įveskite savo NeoAgent paskyros informaciją.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Įveskite savo vartotojo vardą arba paskyros el. „NeoAgent“ išsiųs iš naujo nustatymo nuorodą, jei ji atitiks paskyrą.';

  @override
  String get enterYourUsernameOrEmail =>
      'Įveskite savo vartotojo vardą arba el.';

  @override
  String entityArg1(Object? arg1) {
    return 'Subjektas: $arg1';
  }

  @override
  String get environment => 'Aplinka';

  @override
  String get error => 'Klaida';

  @override
  String errorArg1(Object? arg1) {
    return '\nklaida: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Klaidos iš naujausio žurnalo, sugrupuotos pagal pranešimą.';

  @override
  String get errorsProblemsFailures => 'klaidos problemos gedimai';

  @override
  String get eventTypesCommaSeparated => 'Įvykių tipai (atskirti kableliais)';

  @override
  String get every15Minutes => 'Kas 15 minučių';

  @override
  String get every30Minutes => 'Kas 30 minučių';

  @override
  String get everyAccountOnThisServerLoses =>
      'Kiekviena šio serverio paskyra praranda šį bendrinamą raktą. Sąskaitos ';

  @override
  String get everyAccountOnThisServerUses =>
      'Kiekviena šio serverio paskyra naudoja šį adresą ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Kiekviena aktyvi šios paskyros sesija baigiasi. Jie gali prisijungti ';

  @override
  String get everyDay0800 => 'Kiekvieną dieną · 08:00';

  @override
  String get everyDay2000 => 'Kiekvieną dieną · 20:00';

  @override
  String get everyHour => 'Kas valandą';

  @override
  String get everyRunOnThisServerAll =>
      'Kiekvienas paleidimas šiame serveryje, visą laiką.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Kiekvienas jautrus įrankis kiekvieną kartą reikalauja patvirtinimo.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Kiekvienas įrankis veikia be klausimo, išskyrus tuos, kuriuos naudoja asmuo ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Kiekvienas šių grupių, kanalų ar patalpų narys gali kalbėtis su $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Visi šioje grupėje';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Ateina viskas, kas $arg1 išjungta jūsų agentui ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Visa kita išjungta.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Viskas pasiekiama iš darbalaukio.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Viskas, ką gali naudoti agentas: oficialios integracijos, MCP serveriai ir įgūdžiai.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Viskas, ką išjungėte $arg1, grįžta ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Tikslios žiniatinklio kilmės vietos leidžia teikti kryžminės kilmės užklausas, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Vykdykite „JavaScript“ naršyklės seanso metu.';

  @override
  String get execution => 'Vykdymas';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Išsami šio paleidimo vykdymo informacija nepasiekiama.';

  @override
  String get executionPlanCreated => 'Sukurtas vykdymo planas.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Pratimų $arg1 sesijos';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[išeiti iš $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Baigia galioti $arg1';
  }

  @override
  String get explainThisProject => 'Paaiškinkite šį projektą';

  @override
  String exploredArg1(Object? arg1) {
    return 'Ištirtas $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Ištirtas $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Ištyrinėjo darbo vietą';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Eksportuoti nepavyko: $arg1';
  }

  @override
  String get exportLast5Messages => 'Eksportuoti paskutinius 5 pranešimus';

  @override
  String get exportMyData => 'Eksportuoti mano duomenis';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Nepavyko paleisti išorinės naršyklės su išėjimo kodu $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Išorinės naršyklės paleidimas šioje platformoje nepalaikomas.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Baigėsi išorinės naršyklės paleidimo laikas.';

  @override
  String get externalMcpTools => 'Išoriniai ir MCP įrankiai';

  @override
  String get extraButtons => 'Papildomi mygtukai';

  @override
  String get extractingTheNeoagentRuntime =>
      '„NeoAgent“ vykdymo laiko ištraukimas';

  @override
  String get failed => 'Nepavyko';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Nepavyko prisijungti: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepavyko prijungti $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Nepavyko ištrinti „$arg1“: $arg2';
  }

  @override
  String get failedToFetch => 'nepavyko atnešti';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Nepavyko sugeneruoti raginimo: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Nepavyko paleisti išorinės naršyklės naudojant url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Nepavyko paleisti OAuth srauto.';

  @override
  String get failedToLoadPolicies => 'Nepavyko įkelti politikos';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Nepavyko išsaugoti: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Nepavyko išsaugoti MCP serverio.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Nepavyko išsaugoti pasirinkimo: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Nepavyko išsiųsti pranešimo į užpakalinę programą: $arg1';
  }

  @override
  String get fair => 'Sąžininga';

  @override
  String get fasterReplies => 'Greitesni atsakymai';

  @override
  String get fewerModelCalls => 'Mažiau modelių skambučių';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'tuščias laukas, kad atkurtumėte įtaisytuosius numatytuosius nustatymus.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Failas viršija 1 MB redagavimo priemonės apribojimą.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Failas viršija palaikomo dydžio apribojimą.';

  @override
  String get fileWrites => 'Failas rašo';

  @override
  String get filename => 'Failo pavadinimas';

  @override
  String get files => 'Failai';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Failai, kuriuos NeoAgent rašo arba redagavo šioje sesijoje, rodomi čia.';

  @override
  String get filesSavedByAllUsers =>
      'Failai, kuriuos išsaugojo visi vartotojai';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Užpildykite patvirtintus prisijungimus arba patvirtinkite užklausas neparodydami AI paslapčių.';

  @override
  String get finalResponse => 'Galutinis atsakymas';

  @override
  String get findAPlatform => 'Raskite platformą';

  @override
  String get findAndFixABug => 'Raskite ir ištaisykite klaidą';

  @override
  String get findRecentChats => 'Raskite naujausius pokalbius';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Tinkamo „NeoAgent“ vykdymo laiko radimas';

  @override
  String get finish => 'Baigti';

  @override
  String get finishAtTheScheduledTime => 'Baigti numatytu laiku';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Naršyklėje užbaikite prisijungti prie $arg1, tada vėl prisijunkite.';
  }

  @override
  String get flowGraph => 'Srauto grafikas';

  @override
  String get flutterApp => '„Flutter“ programa';

  @override
  String get focusedExecutionProfile => 'Sutelktas vykdymo profilis';

  @override
  String get folderIdOptional => 'Aplanko ID (neprivaloma)';

  @override
  String get folderUnavailable => 'Aplankas nepasiekiamas';

  @override
  String get forExampleHttpsMatrixOrg => 'Pavyzdžiui, https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Priglobtoms arba išplėstinėms tinklo sąrankoms';

  @override
  String get forLinksInEmailsBlankUses =>
      'Dėl nuorodų el. Blank naudoja viešąjį serverio URL.';

  @override
  String get forgotPassword => 'Pamiršote slaptažodį?';

  @override
  String get frameUnavailable => 'Rėmas nepasiekiamas';

  @override
  String freshnessArg1(Object? arg1) {
    return 'šviežumas: $arg1';
  }

  @override
  String get fridays1700 => 'Penktadieniais · 17:00 val';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe => 'Iš „BotFather“ sukūrus robotą.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Nuo šiol $arg1 nusprendžia, kokius įrankius gali naudoti jūsų agentas. Jie ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Iš „Discord“ kūrėjų portalo, esančio jūsų robote.';

  @override
  String get fromTheLineDevelopersConsole => 'Iš LINE Developers Console.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Iš Matrix kliento arba roboto paskyros.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Iš twitchapps.com/tmi arba „Twitch“ kūrėjo programos.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Pilnas raginimas';

  @override
  String get fullSetup => 'Pilna sąranka';

  @override
  String get general => 'Generolas';

  @override
  String get generalSettings => 'Bendrieji nustatymai';

  @override
  String get generalSettingsSaved => 'Bendrieji nustatymai išsaugoti.';

  @override
  String get generateAPromptForAnotherAi =>
      'Sugeneruokite raginimą naudoti kitą AI, įklijuokite atsakymą čia, kad importuotumėte prisiminimus.';

  @override
  String get generatePrompt => 'Sukurti raginimą';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geotvoros sekimo klaida: $arg1';
  }

  @override
  String get getInspired => 'Pasisemkite įkvėpimo';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex =>
      '„GitHub Copilot“ ir „OpenAI Codex“.';

  @override
  String get githubIssueOpened => 'Atidaryta „GitHub“ problema';

  @override
  String get neorecallMemoryCreated => 'NeoRecall atmintis sukurta';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Nepavyko „GitHub“ leidimo patikrinti naudojant HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      '„GitHub“ leidimų naudingoji apkrova nebuvo leidimų sąrašas.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      '„GitHub“ naudotojo vardas, dėl kurio kilo problema';

  @override
  String get globalSecurityMode => 'Visuotinis saugumo režimas';

  @override
  String get gmailMessageReceived => 'Gautas Gmail pranešimas';

  @override
  String get good => 'Gerai';

  @override
  String get goodAfternoon => 'Laba diena';

  @override
  String get goodEvening => 'Labas vakaras';

  @override
  String get goodMorning => 'Labas rytas';

  @override
  String get goodPasswordALittleMoreLength =>
      'Geras slaptažodis. Šiek tiek didesnis ilgis daro jį tvirtesnį.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => '„Google Workspace“.';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live naudoja jūsų OpenAI API raktą, o Gemini Live - jūsų Google AI raktą. Pakeitimai taikomi kitam skambučiui.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Prieš sinchronizuodami suteikite „Health Connect“ leidimus.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupė, kanalas arba kambarys';

  @override
  String get groupType => 'Grupės tipas';

  @override
  String get groupsAndChannels => 'Grupės ir kanalai';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupės: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Grupės $arg1 dar nematė, tai seks.';
  }

  @override
  String get handlesDirectTasksItself =>
      'Pats susitvarko su tiesioginėmis užduotimis';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Laisvų rankų įranga (kalbėkite laisvai, pertraukite bet kada)';

  @override
  String get headerName => 'Antraštės pavadinimas';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Antraštės jums svarbiomis temomis, filtruojamos pagal signalą.';

  @override
  String get health => 'Sveikata';

  @override
  String get healthChecks => 'Sveikatos patikrinimai';

  @override
  String get healthConnect => 'sveikata susieti';

  @override
  String get healthConnectIsNotAvailableOn =>
      '„Health Connect“ šiame įrenginyje nepasiekiama.';

  @override
  String get healthConnectSyncStatusAndStored =>
      '„Health Connect“ sinchronizavimo būsena ir saugoma vidinė metrika.';

  @override
  String get healthStatusIsUnavailable => 'Sveikatos būklė nepasiekiama.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Sveikatos sinchronizavimas pasiekiamas tik „Android“.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Širdies $arg1 įrašai';
  }

  @override
  String get heldBack => 'Susilaikė';

  @override
  String get helper => 'Pagalbininkas';

  @override
  String helperArg1(Object? arg1) {
    return 'Pagalbininkas: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'čia. Pirmiausia panaikinkite administratorių su „neoagent admin revoke $arg1“.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Didesnės vertės daro „NeoAgent“ selektyvesnę grupėse.';

  @override
  String get highlyRecommended => 'Labai rekomenduojama';

  @override
  String get holdButton131ForTheAssistant =>
      'Palaikykite nuspaudę mygtuką 131 asistentui.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Norėdami kalbėti, laikykite nuspaudę Ctrl + Shift + tarpo klavišą';

  @override
  String get holdToTalk => 'Palaukite, kad pasikalbėtumėte.';

  @override
  String get holdToTalk2 => 'Palaukite, kad pasikalbėtumėte';

  @override
  String get home => 'Pradžia';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Reikalingas namų asistento ilgalaikės prieigos prieigos raktas.';

  @override
  String get homeAssistantSetup => 'Namų asistento sąranka';

  @override
  String get homeAssistantUrl => 'Namų asistento URL';

  @override
  String get homeAssistantUrlIsRequired => 'Būtinas namų asistento URL.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Namų serverio prieigos raktas su kambario apklausa';

  @override
  String get homeserverUrl => 'Namų serverio URL';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'priglobta paslauga). Jūsų raktai yra užšifruoti ir juos naudoti gali tik ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'IRC tinklo pagrindinio kompiuterio pavadinimas, pvz., irc.libera.chat';

  @override
  String get hourly => 'Kas valandą';

  @override
  String get hourlyInboxCheck => 'Valandinis gautųjų tikrinimas';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Kiek laiko galioja patvirtinimo nuorodos.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Kaip dažnai šis agentas ieško naujų kambario pranešimų.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Kaip dažnai šis agentas ieško naujų signalų pranešimų.';

  @override
  String get howTeamsWork => 'Kaip dirba komandos';

  @override
  String get howThisServerIsReachedPlus =>
      'Kaip pasiekiamas šis serveris ir viso serverio jungikliai.';

  @override
  String get httpsSessionCookie => 'https seanso slapukas';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Šiuo metu negalėjau įvykdyti to prašymo. Po akimirkos bandykite dar kartą.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Tuščia eiga';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Jei $arg1 prašo įvesti webhook URL, įklijuokite jį, kad pranešimai pasiektų $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Jei toje paskyroje yra patvirtintas el. paštas, „NeoAgent“ atsiųs slaptažodžio nustatymo iš naujo nuorodą.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Jei paslaugai reikalingas prieigos raktas siunčiamoms užklausoms.';

  @override
  String get ignoreGroups => 'Ignoruoti grupes';

  @override
  String get ignoreThisChat => 'Ignoruoti šį pokalbį';

  @override
  String get ignoredChannels => 'Ignoruojami kanalai';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Nepaisoma netinkamai suformuoto darbalaukio papildomo pranešimo: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Įgyvendinkite aukščiau pateiktą planą.';

  @override
  String get implementThisPlan => 'Įgyvendink šį planą';

  @override
  String get implicitTls => 'Netiesioginis TLS';

  @override
  String get import => 'Importuoti';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Importuoti nepavyko: $arg1';
  }

  @override
  String get importFromComputer => 'Importuoti iš kompiuterio';

  @override
  String get importMemoryTransfer => 'Importuoti atminties perdavimą?';

  @override
  String get importance => 'Svarba';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Importuoti $arg1 atmintis, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return '@$arg1 komandoje';
  }

  @override
  String get inBackground => 'fone';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Čia bus rodomi gaunami ir išeinantys kanalo pranešimai.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Įeinantys balso skambučiai programoje iš NeoAgent';

  @override
  String get incomingMessages => 'Įeinantys pranešimai';

  @override
  String get incomingNeoagentCall => 'Įeinantis NeoAgent skambutis';

  @override
  String get incomingNeoagentCall2 => 'Įeinantis NEOAGENT SKAMBUTIS';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Įeinančių „Webhook“ ir išeinančių atgalinio skambučių palaikymas';

  @override
  String get incorporatingSteering => 'Apima vairavimą';

  @override
  String get input => 'Įvestis';

  @override
  String get inputMode => 'Įvesties režimas';

  @override
  String get insertATemplate => 'Įdėkite šabloną';

  @override
  String get install => 'Įdiegti';

  @override
  String get installASignedSelfContainedRuntime =>
      'Įdiekite pasirašytą, savarankišką vykdymo laiką. Node.js, npm, Git ir terminalo komandos nėra būtinos.';

  @override
  String get installApk => 'Įdiekite APK';

  @override
  String get installApkBundle => 'Įdiekite APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Įdiegti APK – spustelėkite arba numeskite .apk failą';

  @override
  String get installNeoagent => 'Įdiekite „NeoAgent“.';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Įdiekite „NeoAgent“ šiame kompiuteryje be terminalo arba prisijunkite prie jau veikiančio.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Įdiekite naujus leidimus ir pasirinkite, kurį kanalą seka šis serveris.';

  @override
  String get installTheBackend => 'Įdiekite backend';

  @override
  String get installTheCoreWithExtraOptional =>
      'Įdiekite šerdį naudodami papildomą pasirenkamą sąranką. AI teikėjo raktai pridedami vėliau, kaip ir „Quickstart“.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Įdiekite saugų branduolį, tada susikurkite paskyrą. Vėliau pridėkite AI teikėjo raktus.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Įdiegta: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Įdiegta: $arg1 • Paskutinį kartą tikrinta: $arg2';
  }

  @override
  String get instructions => 'Instrukcijos';

  @override
  String get integration => 'Integracija';

  @override
  String get integrationConnections => 'Integraciniai ryšiai';

  @override
  String get integrationSettingsSaved => 'Integravimo nustatymai išsaugoti.';

  @override
  String get integrations => 'Integracijos';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback, ir užregistruokite tą patį ';

  @override
  String get interruptAi => 'Pertraukite AI';

  @override
  String get invalid2fa => 'negaliojantis 2fa';

  @override
  String get invalidArgumentS => 'Netinkamas (-i) argumentas (-ai): ';

  @override
  String get invalidCredentials => 'neteisingi kredencialai';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Neteisingas „NeoAgent“ vykdymo aprašas.';

  @override
  String get inviteLink => 'Kvietimo nuoroda';

  @override
  String get inviteLinkReady => 'Pakvietimo nuoroda paruošta';

  @override
  String get inviteLinks => 'Kvietimo nuorodos';

  @override
  String get iphoneApp => 'iPhone programa';

  @override
  String get issues => 'Problemos';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Įkeliant žurnalą atsiranda problemų.';

  @override
  String get itCanTBeUndone => 'To negalima anuliuoti.';

  @override
  String get itMayHaveBeenDeleted => 'Gali būti, kad jis buvo ištrintas.';

  @override
  String get javaRuntime => 'java vykdymo laikas';

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
    return 'Prisijungė prie $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Prisijungė per pastarąsias 7 dienas';

  @override
  String get joiningATeam => 'Prisijungimas prie komandos';

  @override
  String get joiningIsOffHere => 'Prisijungimas išjungtas čia';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON laukas, kuriame yra pranešimo tekstas. Paprastai tekstas.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON laukas, identifikuojantis, kam skirtas pranešimas.';

  @override
  String get jumpToLatest => 'Pereiti prie naujausio';

  @override
  String get justNow => 'tik dabar';

  @override
  String get keepNeoagentRunning => 'Ar „NeoAgent“ veiktų?';

  @override
  String get keepRunning => 'Bėk toliau';

  @override
  String get keepTaskRunning => 'Vykdykite užduotį';

  @override
  String get keepTheVaultAvailable => 'Laikykite saugyklą prieinamą';

  @override
  String get keepThisLauncherUpToDate => 'Atnaujinkite šią paleidimo priemonę.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Laikykite šį skydelį atidarytą, kol platforma patvirtins ryšį.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Laikykite šios sesijos kompiuterį matomą';

  @override
  String get keepTrackOfYourAiUsage =>
      'Stebėkite savo AI naudojimą. Siekiant užtikrinti sąžiningą naudojimą visoje platformoje, taikomi apribojimai.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Toliau naudokite programas įprastai. NeoAgent veikia tame pačiame ekrane ir klausia, kai reikia naujos prieigos.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Išlaikomas prijungtas šis įrenginys';

  @override
  String get key => 'Raktas';

  @override
  String get keyIsRequired => 'Reikalingas raktas.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Rakto ir verčių poros, kurios išlieka pokalbiuose.';

  @override
  String get knowledgeGraph => 'Žinių grafikas';

  @override
  String get knowledgeView => 'Žinių vaizdas';

  @override
  String get labelOnlyYouSeeIt => 'Etiketė (ją matote tik jūs)';

  @override
  String get labelsOptional => 'Etiketės (neprivaloma)';

  @override
  String get last24Hours => 'Paskutines 24 valandas';

  @override
  String get last7Days => 'Paskutines 7 dienas';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Paskutinės 7 dienos: veikia $arg1 žetonai $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Paskutinis $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Paskutinis: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Paskutinis netuščias sinchronizavimas · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Paskutinis važiavimas: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Paskutinį kartą matytas $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Paskutinis prisijungimas $arg1';
  }

  @override
  String get lastSyncSummary => 'Paskutinio sinchronizavimo suvestinė';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Paskutinį kartą naudota: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Paskutinis langas baigėsi $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'vėliau startas taip pat išjungtas.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Paskutinis važiavimas · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Staliniams kompiuteriams skirtų programų paleidimas šioje platformoje nepalaikomas.';

  @override
  String get learnRoomNorms => 'Išmokite kambario normas';

  @override
  String get leave => 'Palikti';

  @override
  String get leaveARedirectUriBlankTo =>
      'Palikite peradresavimo URI tuščią, kad galėtumėte naudoti <viešąjį URL>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Palikti $arg1 komandą?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Palikite kaip numatytąjį, nebent tinkinote „BlueBubbles“.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Palikite prieigos raktą tuščią, kad išsaugotumėte šiuo metu saugomą prieigos raktą.';

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
    return 'Leiskite $arg1 mane valdyti';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Leiskite visiems šios grupės nariams kalbėtis su $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Leisk jam\nveikti, kol ne.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Leiskite „NeoAgent“ spustelėti, įvesti tekstą ir pereiti per programas.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Leiskite NeoAgent suprasti, kas matoma jūsų ekrane.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Leiskite asmeniui, su kuriuo dirbate, nuspręsti, kokius įrankius gali naudoti jūsų agentas ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Leiskite šiam asmeniui siųsti $arg1 pranešimą „vienas su vienu“.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Leiskite šiam asmeniui kalbėtis su $arg1 čia, bet ne privačiuose pokalbiuose ar kitose grupėse.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Leiskite šiam asmeniui kalbėtis su $arg1 privačiuose pokalbiuose ir bet kurioje grupėje, kurią jie bendrina.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Lygis $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Nuoroda $arg1';
  }

  @override
  String get linkCopied => 'Nuoroda nukopijuota';

  @override
  String get linkExpiresAfter => 'Nuoroda baigiasi po';

  @override
  String get linkLifetimeHours => 'Nuorodos veikimo laikas (valandomis)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Nuorodos tarnavimo laikas turi būti nuo 1 iki 8760 valandų.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Nuoroda galioja iki $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Susieti prisijungimo paslaugų teikėjai';

  @override
  String get linuxApp => 'Linux programa';

  @override
  String listedArg1(Object? arg1) {
    return 'Į sąrašą įtraukta $arg1/';
  }

  @override
  String get listening => 'Klausymas';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Tiesioginė vykdymo istorija, įrankių veiksmai ir atsakymai.';

  @override
  String get liveModel => 'Gyvas modelis';

  @override
  String get liveModelProvider => 'Tiesioginio modelio teikėjas';

  @override
  String get liveRun => 'Tiesioginis bėgimas';

  @override
  String get liveVoice => 'Gyvas balsas';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Tiesioginis balso ryšys nepasiekiamas.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Tiesioginis balso ryšys buvo nutrauktas.';

  @override
  String get liveVoiceDefaults => 'Numatytieji tiesioginio balso nustatymai';

  @override
  String get liveVoiceFailed => 'Tiesioginis balsas nepavyko.';

  @override
  String get llmMemoryExportResponse => 'LLM atminties eksporto atsakymas';

  @override
  String get loadFailed => 'įkelti nepavyko';

  @override
  String get loadingExecutionDetails =>
      'Įkeliama išsami vykdymo informacija...';

  @override
  String get loadingNeoagent => 'Įkeliamas NeoAgent';

  @override
  String get loadingRunFlow => 'Įkeliamas eigos srautas…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Vietiniai ir privataus tinklo URL palaikomi, kai NeoAgent serveris gali juos pasiekti. Garsas niekada nėra veikiamas NeoAgent.';

  @override
  String get localApp => 'vietinė programa';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Vietinis backend diegimas negalimas šioje platformoje.';

  @override
  String get localBaseImagePath => 'Vietinio pagrindinio vaizdo kelias';

  @override
  String get localComputerControlIsAvailableIn =>
      'Vietinis kompiuterio valdymas pasiekiamas „NeoAgent“ darbalaukio programoje „MacOS“, „Windows“ ir „Linux“.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Vietinis kompiuterio valdymas čia negalimas.';

  @override
  String get localModelsUrl => 'vietinių modelių URL';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Vietinis „NeoAgent“ atradimas laikinai nepasiekiamas.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Vietinės „NeoAgent“ programos nuostatos. Kompiuterio valdymas visada vyksta per vieningą debesies kompiuterį.';

  @override
  String get localSetup => 'VIETINĖ NUSTATYMA';

  @override
  String get locationCityOrPlace => 'Vieta (miestas arba vieta)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Norint suaktyvinti orų įvykius, būtina nustatyti vietą';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Vietos paslaugos inicijavimas nepavyko: $arg1';
  }

  @override
  String get logCopied => 'Žurnalas nukopijuotas';

  @override
  String get loginPassword => 'Prisijungimo slaptažodis';

  @override
  String get logout => 'Atsijungti';

  @override
  String get logs => 'Rąstai';

  @override
  String get logsCopied => 'Žurnalai nukopijuoti.';

  @override
  String get logsOnThisComputer => 'Prisijungimai šiame kompiuteryje';

  @override
  String get longLivedAccessToken => 'Ilgalaikis prieigos raktas';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Ilgalaikis prisiminimas, struktūrizuoti faktai ir žinių grafikas.';

  @override
  String get lookedAtTheScreen => 'Pažiūrėjo į ekraną';

  @override
  String get lookingOnThisComputerAndYour =>
      'Ieškoma šiame kompiuteryje ir vietiniame tinkle...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Žiūri į rytojaus susitikimus, todėl niekas jūsų nestebina.';

  @override
  String get loopExecution => 'Ciklo vykdymas';

  @override
  String get loopPaused => 'Ciklas pristabdytas';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      '„MacOS“ prieinamumas „NeoAgent“ nesuteikiamas. Leiskite tai skiltyje Sistemos nustatymai › Privatumas ir sauga › Prieinamumas.';

  @override
  String get macosApp => 'macOS programa';

  @override
  String get macosScreenRecordingIsNotGranted =>
      '„MacOS“ ekrano įrašymas „NeoAgent“ nesuteikiamas. Leiskite tai skiltyje Sistemos nustatymai › Privatumas ir sauga › Ekrano įrašymas, tada iš naujo atidarykite „NeoAgent“.';

  @override
  String get mailServersThatNeedAPassword =>
      'Pašto serveriai, kuriems reikia slaptažodžio, atsisakys siųsti iki naujo ';

  @override
  String get main => 'Pagrindinis';

  @override
  String get makeDefault => 'Padaryti numatytąją';

  @override
  String get manage => 'Tvarkyti';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Tvarkykite savo paskyros el. paštą, dviejų veiksnių autentifikavimą ir aktyvias sesijas.';

  @override
  String get managedBy => 'Tvarko';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Vadovai gali turėti savo vadovus (iki keturių lygių). A ';

  @override
  String get managing => 'Valdymas';

  @override
  String get manualDestination => 'Rankinis tikslas';

  @override
  String get manualTrigger => 'Rankinis trigeris';

  @override
  String get masterPassword => 'Pagrindinis slaptažodis';

  @override
  String get matchThisDevice => 'Suderinkite šį įrenginį';

  @override
  String get matchedAgainstTitleAndBody => 'Atitinka pavadinimą ir turinį';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Atitinka seną NeoAgent MCP srautą: URL ir autentifikavimo metodą.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP serveris';

  @override
  String get mcpServer2 => 'MCP serveris';

  @override
  String get mcpServerUrl => 'MCP serverio URL';

  @override
  String get mcpServers => 'MCP serveriai';

  @override
  String get meantForSomeoneElse => 'Skirta kam nors kitam';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Išmatuota modelio kaina: $arg1';
  }

  @override
  String get memories => 'Prisiminimai';

  @override
  String get memory => 'Atmintis';

  @override
  String memoryArg1(Object? arg1) {
    return 'Atmintis: $arg1';
  }

  @override
  String get memoryInjected => 'Įvesta atmintis';

  @override
  String get mentionOrReplyOnly => 'Tik paminėkite arba atsakykite';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Sujungti šios programos seanso serverio ir „Flutter“ vykdymo laiko žurnalai.';

  @override
  String get messageBodyTemplateJson => 'Pranešimo teksto šablonas (JSON)';

  @override
  String get messageNeedsAccess => 'Pranešimui reikia prieigos';

  @override
  String get messageTextField => 'Pranešimo teksto laukas';

  @override
  String get messaging => 'Susirašinėjimas žinutėmis';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging API push ir webhook įvykiai';

  @override
  String get messagingConnectionNeedsAttention =>
      'Pranešimų ryšiui reikia dėmesio';

  @override
  String get messagingConnections => 'Žinučių siuntimo ryšiai';

  @override
  String get messagingDelivery => 'Pranešimų pristatymas';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Pranešimų siuntimo klaida. Bandykite dar kartą.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Mikrofono fiksavimas netikėtai nutrūko. Bandykite dar kartą.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofono klaida: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofonas nutildytas. Palieskite, kad įjungtumėte garsą.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Tiesioginiam balsui reikalingas mikrofono leidimas.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft komandos';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Minimali įnašo vertė: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobiliojo ryšio sąranka nepavyko.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobiliojo ryšio sąranka nepavyko, nes „Java“ nepasiekiama įrenginyje, kuriame veikia „NeoAgent“.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobiliojo ryšio sąranka nepavyko, nes „Java“ nepasiekiama įrenginyje, kuriame veikia „NeoAgent“. Įdiekite JDK ir bandykite dar kartą.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobiliojo ryšio sąranka nepavyko. Patikrinkite, ar „Android“ įrankiai tinkamai įdiegti, ir bandykite dar kartą.';

  @override
  String modeArg1(Object? arg1) {
    return 'režimas: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'Režimas užrakinamas, kai bėgimas aktyvus.';

  @override
  String get model => 'Modelis';

  @override
  String modelArg1(Object? arg1) {
    return 'Modelis: $arg1';
  }

  @override
  String get modelAvailability => 'Modelio prieinamumas';

  @override
  String get modelAvailabilitySaved => 'Modelio prieinamumas išsaugotas.';

  @override
  String get modelForThisSession => 'Šios sesijos modelis';

  @override
  String get modelOverride => 'Modelio nepaisymas';

  @override
  String get modelPending => 'Laukiama modelio';

  @override
  String get modelTurn => 'Modelio posūkis';

  @override
  String get modelTurnCompleted => 'Modelio posūkis baigtas';

  @override
  String get modelTurnStarted => 'Prasidėjo modelio posūkis';

  @override
  String get modelVisibilityHideShowList =>
      'modelio matomumas slėpti rodyti sąrašą';

  @override
  String get models => 'Modeliai';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modeliai, elgesys, balsas ir darbo vieta';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modeliai, naršyklė, balsas, diagnostika...';

  @override
  String get modelsRouting => 'Modeliai ir maršrutai';

  @override
  String get monthly => 'Kas mėnesį';

  @override
  String get moreActions => 'Daugiau veiksmų';

  @override
  String get morningBriefing => 'Rytinis instruktažas';

  @override
  String get mostUsedAgents => 'Dažniausiai naudojami agentai';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Dažniausiai naudojami modeliai paskutiniame $arg1.';
  }

  @override
  String get mouseKeyboard => 'Pelė ir klaviatūra';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'MouseMove nepalaikoma šioje platformoje.';

  @override
  String get mustBeReachableOnThePublic =>
      'Turi būti pasiekiamas viešuoju internetu – vietiniu ir ';

  @override
  String get n24Hours => '24 valandos';

  @override
  String get n2faOrRecoveryCode => '2FA arba atkūrimo kodas';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA reikalauja, kad šiame „NeoAgent“ diegime būtų sukonfigūruotas SESSION_SECRET.';

  @override
  String get n30Days => '30 dienų';

  @override
  String get n365Days => '365 dienos';

  @override
  String get n4HourLimitTokens => '4 valandų limitas (žetonai)';

  @override
  String get n4HourUsage => '4 valandų naudojimas';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4h riba $arg1';
  }

  @override
  String get n7DayUsage => '7 dienų naudojimas';

  @override
  String get n7Days => '7 dienos';

  @override
  String get n90Days => '90 dienų';

  @override
  String get name => 'Vardas';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\npavadinimas: Naujas įgūdis\naprašymas: apibūdinkite, ką daro šis įgūdis\n---\nParašykite šio įgūdžio instrukcijas čia.\n';

  @override
  String get nameOfWhoeverMadeIt => 'to, kas jį padarė, vardas.';

  @override
  String get nameOptional => 'Vardas (neprivaloma)';

  @override
  String get nativeAndWebhookChannels => 'Vietiniai ir „Webhook“ kanalai';

  @override
  String get naturalBubbles => 'Natūralūs burbuliukai';

  @override
  String get nearbyNeoagentServers => 'Netoliese esantys NeoAgent serveriai';

  @override
  String get needANewAccountRegister => 'Reikia naujos paskyros? Registruotis';

  @override
  String get needAnIdea => 'Reikia idėjos?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Reikia atsakyti · $arg1% kalbėti';
  }

  @override
  String get needsAttention => 'Reikia dėmesio';

  @override
  String get needsInput => 'Reikia įvesties';

  @override
  String get neoagentApp => 'NeoAgent programa';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent asistentas';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      '„NeoAgent“ negalėjo patikrinti galimos užpakalinės programos vykdymo laiko.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent negalėjo užbaigti vietinės sąrankos.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent negalėjo užbaigti vietinės sąrankos. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent derinimo informacija';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => '„NeoAgent Flutter Updater“.';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent įdiegia naujausią $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning => 'NeoAgent įdiegta ir veikia.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent šiame kompiuteryje neįdiegta.';

  @override
  String get neoagentIsReady => 'NeoAgent yra paruošta';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent vis dar dirba su užduotimi. Užbaikite skambutį ir gaukite rezultatą pokalbyje arba taip pat atšaukite užduotį.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      '„NeoAgent“ jūsų demonstraciją paverčia pritaikoma darbo eiga.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent laukia, kol naudositės darbalaukiu.';

  @override
  String get neoagentIsWorking => 'NeoAgent veikia';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux kompiuteris';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT REIKIA SPRENDIMO';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Norint atsisiųsti „NeoAgent“ vykdymo laiką, reikalingas saugus adresas.';

  @override
  String get neoagentServerAddress => 'NeoAgent serverio adresas';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgent paslaugos el. paštas neparengtas. Paprašykite serverio operatoriaus patikrinti el. pašto aplinkos nustatymus.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Nepavyko užbaigti „NeoAgent“ sąrankos.';

  @override
  String get neoagentUser => 'NeoAgent vartotojas';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent naudoja šį kompiuterį automatiškai ir klausia prieš naudojant ekraną, pelę, klaviatūrą, failus ar komandų eilutę.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      '„NeoAgent“ naudoja jūsų apytikslę vietą fone, kad suaktyvintų geotvoros priminimus (pvz., „Priminti man nusipirkti pieno, kai einu pro prekybos centrą“).\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent darbo sritis';

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
  String get neorecallBackendUrlIsRequired =>
      'Būtinas „NeoRecall“ užpakalinės programos URL.';

  @override
  String get neorecallSetup => 'NeoRecall sąranka';

  @override
  String get networkRequestFailed => 'tinklo užklausa nepavyko';

  @override
  String get networkWriteRequests => 'Tinklo rašymo užklausos';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'niekada neįskaičiuojamas į bendro naudojimo limitus.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Naujos paskyros prieš prisijungdamos patvirtina savo el. pašto adresą.';

  @override
  String get newAccountsPerDay => 'Naujos sąskaitos per dieną';

  @override
  String get newChat => 'Naujas pokalbis';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Naujos grupės tyli, nebent kas nors pažymės $arg1, kol jas neįjungsite.';
  }

  @override
  String get newLink => 'Nauja nuoroda';

  @override
  String get newPasswordsDoNotMatch => 'Nauji slaptažodžiai nesutampa.';

  @override
  String get newRecoveryCodes => 'Nauji atkūrimo kodai';

  @override
  String get newSession => 'Nauja sesija';

  @override
  String get newSessionN => 'Nauja sesija (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nauja sesija su ta pačia sąranka';

  @override
  String get newSkill => 'Naujas įgūdis';

  @override
  String get newSkill2 => 'Naujas įgūdis';

  @override
  String get newThisWeek => 'Nauja šią savaitę';

  @override
  String get newsDigest => 'Naujienų santrauka';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Kitas bandymas: $arg1';
  }

  @override
  String get nextcloudLoginFlow => '„Nextcloud“ prisijungimo srautas';

  @override
  String get nextcloudSetup => 'Nextcloud sąranka';

  @override
  String get nextcloudTalk => '„Nextcloud“ pokalbis';

  @override
  String get nextcloudUrl => 'Nextcloud URL';

  @override
  String get nextcloudUrlIsRequired => 'Būtinas Nextcloud URL.';

  @override
  String get nickname => 'Slapyvardis';

  @override
  String get noAccountsConnectedYet => 'Dar nėra susietų paskyrų.';

  @override
  String get noAccountsFound => 'Paskyrų nerasta.';

  @override
  String get noActiveSessionsFound => 'Aktyvių seansų nerasta.';

  @override
  String get noAgentsYet => 'Agentų dar nėra';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nė vienas AI teikėjas nesukonfigūruotas, todėl kalbėkite ir siųskite pranešimus ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Jokių patvirtinimo raginimų – agentas veikia be pertraukų.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Joks $arg1 leidimo išteklius neatitiko šios platformos.';
  }

  @override
  String get noArguments => '(be argumentų)';

  @override
  String get noAuth => 'Nėra autentiškumo';

  @override
  String get noBindingsYet => 'Dar nėra apkaustų.';

  @override
  String get noChangesYet => 'Kol kas jokių pakeitimų';

  @override
  String get noChannelsFound => 'Nerasta jokių kanalų';

  @override
  String get noCloudComputerSlotIsFree =>
      'Nė vienas debesies kompiuterio lizdas šiuo metu nėra nemokamas. Po akimirkos bandykite dar kartą.';

  @override
  String get noCoreMemoryEntriesYet => 'Dar nėra pagrindinės atminties įrašų.';

  @override
  String get noDescription => 'Jokio aprašymo';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Šiuo metu nėra pasiekiamų darbalaukio ekranų.';

  @override
  String get noDetailAvailable => 'Nėra informacijos';

  @override
  String get noDetailedSyncSummaryYet =>
      'Dar nėra išsamios sinchronizavimo suvestinės.';

  @override
  String get noDetailsCaptured => 'Jokių detalių neužfiksuota.';

  @override
  String get noEmailLinked => 'El. pašto adresas nesusietas';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nėra susietų išorinių prisijungimo paslaugų teikėjų.';

  @override
  String get noGroupMessagesYet => 'Grupės pranešimų dar nėra';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Konkrečių grupių žmonių dar nepridėta.';

  @override
  String get noGroupsAddedYet => 'Grupės dar nepridėtos.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Kol kas nerasta grupių. Kai $arg1 pamatys grupės pranešimą, naudokite Rasti naujausius pokalbius ir jie bus rodomi čia.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Kol kas nerasta grupių. Kai $arg1 pamatys grupės pranešimą, naudokite Rasti naujausius pokalbius.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Negrįžta jokia sveikatos duomenų naudingoji apkrova.';

  @override
  String get noHealthSamplesStoredYet => 'Dar nėra saugomų sveikatos mėginių.';

  @override
  String get noHttpClientImplementationForThis =>
      'Šioje platformoje nėra HTTP kliento įdiegimo.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Šiam veiksmui nebuvo įrašyta nei įvestis, nei išvestis.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Šią paiešką atitinkančių integracijų nėra.';

  @override
  String get noLimit => 'Nėra limito';

  @override
  String get noLocalPasswordIsSetYet =>
      'Vietinis slaptažodis dar nenustatytas. Sukurkite, kad įgalintumėte prisijungimą vartotojo vardu / slaptažodžiu.';

  @override
  String get noLogEntries => 'Nėra žurnalo įrašų.';

  @override
  String get noMatchingSettings => 'Nėra atitinkančių nustatymų';

  @override
  String get noMcpServersMatchThisSearch =>
      'Nė vienas MCP serveris neatitinka šios paieškos.';

  @override
  String get noMemoryEntriesFound => 'Atminties įrašų nerasta.';

  @override
  String get noMemorySync => 'Nėra atminties sinchronizavimo';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Vieną kartą perskaito svarbius ir išsiųstus pastarųjų 12 mėnesių laiškus, kad agentas žinotų jūsų kontaktus ir projektus.';

  @override
  String get emailMemory => 'El. pašto atmintis';

  @override
  String get importNow => 'Importuoti dabar';

  @override
  String get importOnConnect =>
      'Prijungiant paskyrą importuoti ankstesnius laiškus';

  @override
  String get sweepStarting => 'Ruošiamasi…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Skaitomi laiškai · $done iš $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Skaitomi laiškai · rasta $count';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Mokomasi iš laiškų · $done iš $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Paskutinis importas: $emails laiškai · $memories nauji prisiminimai';
  }

  @override
  String get sweepNothingNew => 'Nėra naujų laiškų importuoti';

  @override
  String sweepFailed(String error) {
    return 'Importuoti nepavyko: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Nė vienas modelis neatitinka „$arg1“.';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Šiam paleidimui nebuvo įrašyta jokia modelio užklausa.';

  @override
  String get noModelsDiscoveredYet => 'Kol kas modelių nerasta';

  @override
  String get noModelsSelected => 'Nepasirinkta jokių modelių';

  @override
  String get noModelsYet => 'Dar nėra modelių';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'su šiuo teikėju nesusieta jokia neoagent paskyra';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Šiam kompiuteriui nepasiekiama jokia „NeoAgent“ fono vykdymo programa.';

  @override
  String get noNetworkConnection => 'Nėra tinklo ryšio';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Nėra tinklo ryšio. Prisijunkite, kad galėtumėte toliau naudoti „NeoAgent“.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Nėra tinklo ryšio. Prisijunkite iš naujo, kad patikrintumėte, ar nėra naujinimų.';

  @override
  String get noOne => 'Niekas';

  @override
  String get noOneAddedYet => 'Dar niekas nepridėjo.';

  @override
  String get noOneCanMessage => 'Niekas negali pranešti';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Kito NeoAgent serverio nerasta. Galite ieškoti dar kartą arba įvesti adresą rankiniu būdu.';

  @override
  String get noPeopleAddedYet => 'Žmonių dar nepridėta.';

  @override
  String get noPlatformsMatch => 'Jokia platforma neatitinka';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Dar nėra konfigūruojamų teikėjų.';

  @override
  String get noRecentChannelActivity => 'Nėra naujausios kanalo veiklos';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Nėra rezultatų pagal „$arg1“';
  }

  @override
  String get noRunsInThisRange => 'Šiame diapazone nėra važiavimų.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nė vienas paleidimas neatitinka šių filtrų';

  @override
  String get noRunsYet => 'Dar nėra bėgimų';

  @override
  String get noRunsYet2 => 'Dar nėra bėgimų.';

  @override
  String get noSecurityKeyWasProvided => 'Saugos raktas nebuvo pateiktas.';

  @override
  String get noServerUrlSet => 'Nenustatytas serverio URL';

  @override
  String get noSessionMatchesThatSearch =>
      'Nė viena sesija neatitiko šios paieškos.';

  @override
  String get noSessionsYet => 'Dar nėra seansų';

  @override
  String get noSkillsMatchTheseFilters =>
      'Jokie įgūdžiai neatitinka šių filtrų.';

  @override
  String get noStepsWereRecordedForThis =>
      'Šiam bėgimui nebuvo įrašyti jokie žingsniai.';

  @override
  String get noSummaryAvailable => 'Santrauka nepasiekiama.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Nėra užduočių, skirtų $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Nė vienas įrankis neatitinka „$arg1“.';
  }

  @override
  String get noUpdateRunning => 'Neveikia joks atnaujinimas';

  @override
  String get noUsageYet => 'Dar nenaudota.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Patvirtintos „NeoAgent“ užpakalinės programos vykdymo laikas dar nepasiekiamas.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Niekas daugiau negali juo naudotis. Žmonės, kurie jau prisijungė ';

  @override
  String get none => 'Nėra';

  @override
  String get notApprovedYet => 'dar nepatvirtinta';

  @override
  String get notAuthenticated => 'nepatvirtinta';

  @override
  String get notCheckedYet => 'Dar nepatikrinta';

  @override
  String get notConfigured => 'Nesukonfigūruotas';

  @override
  String get notConnected => 'Neprisijungęs';

  @override
  String get notConnected2 => 'Neprisijungta';

  @override
  String get notInstalled => 'Neįdiegta';

  @override
  String get notNeeded => 'Nereikia';

  @override
  String get notNeededEnough => 'Nereikia pakankamai';

  @override
  String get notNow => 'Ne dabar';

  @override
  String get notNow2 => 'Ne dabar';

  @override
  String get notSet => 'Nenustatyta';

  @override
  String get notSetUp => 'Nenustatyta';

  @override
  String get notTheSameAsAdmin => 'Ne tas pats, kas admin';

  @override
  String get nothingFound => 'Nieko nerasta';

  @override
  String get nothingHereYet => 'Čia dar nieko.';

  @override
  String get nothingHereYet2 => 'Čia dar nieko';

  @override
  String get nothingMatches => 'Niekas neatitinka';

  @override
  String get nothingStoredYet => 'Dar nieko nėra saugoma.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      '„Notion“, „Slack“, „Figma“, „GitHub“, „Spotify“, „Trello“.';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => '„OAuth“ kliento ID';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth kliento ID slaptas peradresavimo API raktas';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      '„oauth“ kliento ID slaptas peradresavimo „Gmail“ kalendoriaus diskas';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuth paleidimas šioje platformoje nepalaikomas.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook nuomininko kliento ID paslaptis';

  @override
  String get oauthToken => 'OAuth prieigos raktas';

  @override
  String get oauthWithPkce => 'OAuth su PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'iš $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'savo. Išsaugojus jis daugiau niekada nerodomas.';

  @override
  String get off => 'Išjungta';

  @override
  String get officialIntegration => 'Oficiali integracija';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Oficiali integracija nepateikė ryšio URL.';

  @override
  String get on => 'Įjungta';

  @override
  String get onASignedInAndroidDevice =>
      'Android įrenginyje, kuriame esate prisijungę, atidarykite Nustatymai › Prisijungimas ir sauga, nuskaitykite šį kodą ir patvirtinkite prisijungimą.';

  @override
  String get onByDefaultForNewGroups =>
      'Įjungta pagal numatytuosius nustatymus naujoms grupėms';

  @override
  String get onDemand => 'Pagal pareikalavimą';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Įjungta $arg1 iš $arg2 grupių';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'įjungta. Jie vėl gali prisijungti tik naudodami naują kvietimo nuorodą.';

  @override
  String get onYourOwnTheDefault => 'Savarankiškai (numatytasis)';

  @override
  String get once => 'Kartą';

  @override
  String get oneIsSavedOtherChangesIn =>
      'vienas išgelbėtas. Kiti šios formos pakeitimai taip pat išsaugomi.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Vienos ar daugiau paskyrų galiojimo laikas baigėsi. Iš naujo prijunkite paveiktą paskyrą, kad atkurtumėte prieigą prie įrankio.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Vienas vykdymo laikas valdo asmenį, grupės eilutę, kambario atmintį, normas, proto teoriją ir pristatymą.';

  @override
  String get oneTimeRun => 'Vienkartinis bėgimas';

  @override
  String get onlyApkOrApksFilesCan =>
      'Galima įdiegti tik .apk arba .apks failus.';

  @override
  String get onlyInThisGroup => 'Tik šioje grupėje';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Reikalingas tik tuo atveju, jei paslauga prašo papildomų HTTP antraščių.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Reikalingas tik tuo atveju, jei norite pakeisti išeinančio naudingojo krovinio formą.';

  @override
  String get onlyTheyCanChangeIt => 'Tik jie gali tai pakeisti.';

  @override
  String get open => 'Atidaryti';

  @override
  String get openAccountSettingsOnASigned =>
      'Atidarykite Nustatymai › Prisijungimas ir sauga Android įrenginyje, kuriame esate prisijungę, nuskaitykite šį kodą ir patvirtinkite prisijungimą.';

  @override
  String get openComputer => 'Atidarykite kompiuterį';

  @override
  String get openDashboard => 'Atidaryti prietaisų skydelį';

  @override
  String get openFolder => 'Atidaryti aplanką…';

  @override
  String get openInWorkbench => 'Atidaryti darbastalyje';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Atidarykite „NeoAgent“ ir vėl prijunkite $arg1, kad atkurtumėte pranešimų siuntimą.';
  }

  @override
  String get openTimeSettings => 'Atidaryti laiko nustatymus';

  @override
  String get openToAnyone => 'Atvira bet kam';

  @override
  String get openTrello => 'Atidarykite „Trello“.';

  @override
  String get openVoiceAssistant => 'Atidarykite balso asistentą';

  @override
  String get openWiFiSettings => 'Atidarykite „Wi-Fi“ nustatymus';

  @override
  String get openWithTheDefaultApp =>
      'Atidarykite naudodami numatytąją programą';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai suderinamas';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Su OpenAI suderinamas galutinis taškas (jūsų serveris ar kitas ';

  @override
  String openedArg1(Object? arg1) {
    return 'Atidarytas $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Darbalaukio URL atidarymas šioje platformoje nepalaikomas.';

  @override
  String get openingYourSavedDesktop => 'Atidaromas išsaugotas darbalaukis.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Atidaromas išsaugotas darbalaukis. Įprastas paleidimas trunka mažiau nei 10 sekundžių.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Pasirenkama papildoma paslaptis, jei apsaugote įeinantį „Webhook“.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Pasirenkamas nepaisymas, jei nepakanka „webhook“ URL.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Pasirenkama paslaptis gaunamiems pokalbių įvykiams patvirtinti.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Pasirenkama paslaptis gaunamiems įvykiams patvirtinti.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Neprivaloma paslaptis, norint patikrinti gaunamus iMessage įvykius.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Pasirenkama paslaptis, skirta patvirtinti gaunamus LINE įvykius.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Neprivaloma paslaptis gaunamiems Mattermost įvykiams patikrinti.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Pasirenkama paslaptis, kad būtų galima patikrinti gaunamus Teams įvykius.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Neprivaloma. Agentas jau turi savo asmenybę. Viskas, ką pridedate apie toną, yra sluoksniuota ant jo, todėl jums niekada nereikės jo apibrėžti.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Neprivaloma. Kai nustatyta, jis naudojamas vietoj URL.';

  @override
  String get orAnswerInYourOwnWords => 'Arba atsakykite savo žodžiais';

  @override
  String get orBuildYourOwnTask => 'Arba sukurkite savo užduotį';

  @override
  String get orContinueWith => 'arba tęsti su';

  @override
  String get orFiles => 'arba failus.';

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
  String get originNotAllowed => 'kilmė neleidžiama';

  @override
  String get outgoingMessage => 'Siunčiamas pranešimas';

  @override
  String get outgoingWebhookUrl => 'Siunčiamas „Webhook“ URL';

  @override
  String get outlookEmailReceived => 'Gautas Outlook el. laiškas';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Perrašyti elgesio pastabas iš importavimo.';

  @override
  String get ownModel => 'nuosavas modelis';

  @override
  String get packageName => 'Paketo pavadinimas';

  @override
  String get pairWithQrCode => 'Susiekite su QR kodu';

  @override
  String get password => 'Slaptažodis';

  @override
  String get password2faAndActiveSessions =>
      'Slaptažodis, 2FA ir aktyvios sesijos';

  @override
  String get passwordCreated => 'Sukurtas slaptažodis.';

  @override
  String get passwordIsTooWeak => 'slaptažodis per silpnas';

  @override
  String get passwordMin8 => 'slaptažodis mažiausiai 8';

  @override
  String get passwordOrApiKey => 'Slaptažodis arba API raktas';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Slaptažodžio stiprumas: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Slaptažodžiai nesutampa.';

  @override
  String get pasteAKey => 'Įklijuokite raktą.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Įklijuokite naują raktą, kad pakeistumėte $arg1';
  }

  @override
  String get pasteTheKey => 'Įklijuokite raktą';

  @override
  String get pasteYourAccountToken => 'Įklijuokite paskyros prieigos raktą';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Toliau įklijuokite savo $arg1 API raktą. Tai ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Kelias turi likti „NeoAgent Workspace“ viduje.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Kelias turi likti darbo srities aplanke.';

  @override
  String get pauseLiveUpdates => 'Pristabdykite tiesioginius atnaujinimus';

  @override
  String get pauseTaskLoop => 'Pristabdyti užduoties ciklą';

  @override
  String get paused => 'Pristabdyta';

  @override
  String peakArg1(Object? arg1) {
    return 'piko $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Žmonės privačiuose pokalbiuose';

  @override
  String get perAccountRateLimits => 'Sąskaitos kurso limitai';

  @override
  String get perCategoryPermissions => 'Kiekvienos kategorijos leidimai';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Įrankio leidimų politika, patvirtinimo vartai ir proceso izoliacija apvalkalo vykdymui.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Reikalingas leidimas: $arg1';
  }

  @override
  String get permissionsNeeded => 'Reikalingi leidimai';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Leidimai. Niekas kitas negali to pakeisti.';

  @override
  String get personOrChat => 'Asmuo arba pokalbis';

  @override
  String get personaBehaviorNotes => 'Asmens elgesio pastabos';

  @override
  String get personalAccessTokenForTheMattermost =>
      '„Mattermost“ roboto asmeninės prieigos raktas.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Asmeniniai kanalai ir tiesioginiai atramos paviršiai.';

  @override
  String get personalSelfChat => 'Asmeninis pokalbis su savimi';

  @override
  String get phoneNumber => 'Telefono numeris';

  @override
  String get pickARunFromTheList =>
      'Iš sąrašo pasirinkite bėgimą, kad pamatytumėte jo žingsnius.';

  @override
  String get pickARunFromTheList2 =>
      'Pasirinkite bėgimą iš sąrašo kairėje, kad ištirtumėte jo eigą.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Pasirinkite iš naujausių $arg1 pokalbių arba pridėkite asmenį ar grupę patys.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Pasirinkite, kaip $arg1 naudoja šią paskyrą.';
  }

  @override
  String get pickOneToFillInThe =>
      'Pasirinkite vieną, kad užpildytumėte užduotį. Vėliau galėsite viską pakoreguoti.';

  @override
  String get picksUpWhereYouLeftOff => 'Tęsia ten, kur baigėte';

  @override
  String get plan => 'Planuoti';

  @override
  String get planning => 'Planavimas';

  @override
  String get platform => 'Platforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Platforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Pasirinkite tvarkaraštį.';

  @override
  String get pleaseEnterAFilename => 'Įveskite failo pavadinimą.';

  @override
  String get pleaseEnterAKey => 'Įveskite raktą.';

  @override
  String get pleaseEnterAPrompt => 'Įveskite raginimą.';

  @override
  String get pleaseEnterATaskName => 'Įveskite užduoties pavadinimą.';

  @override
  String get pleaseEnterTheMemoryContent => 'Įveskite atminties turinį.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Įveskite, kada užduotis turėtų būti vykdoma.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Pasirinkite paskyrą arba įveskite galiojantį ryšio ID.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Nukreipkite „NeoAgent“ į bet kurį su OpenAI suderinamą pokalbių užbaigimą ';

  @override
  String get pointTheCameraAtTheCode =>
      'Nukreipkite fotoaparatą į kodą, rodomą įrenginyje, kuriame atsijungta. Patvirtinimas lieka šiame telefone.';

  @override
  String get port => 'Uostas';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env viešasis URL patikimumo tarpinio serverio saugus slapukų diegimas';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Aukščiausios kokybės automatizavimas su tvarkaraščiu ir integravimo aktyvikliais.';

  @override
  String get prepareQrCode => 'Paruoškite QR kodą';

  @override
  String get preparingNeoagent => 'Ruošiamas NeoAgent…';

  @override
  String get preparingNeoagent2 => 'NeoAgent paruošimas';

  @override
  String get pressAndHoldForQuickCapture =>
      'Paspauskite ir palaikykite, kad greitai užfiksuotumėte';

  @override
  String get pressKeysIsNotSupportedOn =>
      'klavišų paspaudimas šioje platformoje nepalaikomas.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Suspaustas $arg1';
  }

  @override
  String get priceUnknown => 'Kaina nežinoma';

  @override
  String get primaryDisplay => 'Pagrindinis ekranas';

  @override
  String get privateChat => 'Privatus pokalbis';

  @override
  String get privateChats => 'Privatūs pokalbiai';

  @override
  String get privateChats2 => 'privatūs pokalbiai';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Privatūs pokalbiai: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Privatūs pokalbiai $arg1 · grupės $arg2';
  }

  @override
  String get privateChatsOnly => 'Tik privatūs pokalbiai';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'privataus tinklo adresai neleidžiami.';

  @override
  String get profileEmailAndPersonalData =>
      'Profilis, el. paštas ir asmeniniai duomenys';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Paraginti, kol „NeoAgent“ lieka sistemos dėkle.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Raginimo talpykla: $arg1 talpyklos prieigos raktai ';
  }

  @override
  String get promptCopied => 'Raginimas nukopijuotas.';

  @override
  String get promptOrSchedule => 'raginimas arba tvarkaraštis.';

  @override
  String get promptToPasteIntoAnotherAi => 'Raginimas įklijuoti į kitą AI';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Nepavyko pradėti tiekėjo susiejimo.';

  @override
  String get providerSignInCouldNotBe =>
      'Nepavyko pradėti teikėjo prisijungimo.';

  @override
  String get providers => 'Teikėjai';

  @override
  String get providersEachAccountCanStillPick =>
      'Teikėjai; Kiekviena paskyra vis tiek gali pasirinkti savo modelį nustatymuose. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Teikėjai, integracijos, balso ir pasirenkamos galimybės gali būti bet kada baigtos nustatymuose.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Viešos išdavimo ir ištraukimo užklausų gijos, atsakyta tik patvirtintiems žmonėms.';

  @override
  String get publicUrl => 'Viešas URL';

  @override
  String get publicUrlAndAllowedOrigins => 'Viešas URL ir leistinos kilmės';

  @override
  String get publicUrlOverride => 'Viešojo URL nepaisymas';

  @override
  String get pullsTogetherTheDayAhead => 'Sutraukia dieną į priekį';

  @override
  String get pushToTalk => 'Tiesioginis pokalbis';

  @override
  String get qrBasedPhoneLinking => 'Telefono susiejimas QR pagrindu';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR prisijungimas baigtas, bet „NeoAgent“ negalėjo išlaikyti seanso. Bandykite dar kartą.';

  @override
  String get qrLoginCouldNotBeStarted => 'Nepavyko pradėti QR prisijungimo.';

  @override
  String get qrLoginRequestHasExpired => 'qr prisijungimo užklausa pasibaigė';

  @override
  String get qrLoginRequestWasNotFound => 'qr prisijungimo užklausa nerasta';

  @override
  String get qrPairing => 'QR poravimas';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'vykdomos užklausos; viskas, kas rašo, yra atmetama.';

  @override
  String get queryFilter => 'Užklausa / filtras';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Eilėje kaip vairavimo priemonė dabartiniam važiavimui: $arg1';
  }

  @override
  String get quickstart => 'Greita pradžia';

  @override
  String get quit => 'Išeik';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, wind_alert';

  @override
  String get ranAScriptInThePage => 'Paleido scenarijų puslapyje';

  @override
  String ranArg1(Object? arg1) {
    return 'Važiavo $arg1';
  }

  @override
  String get rateLimits => 'Kainos ribos';

  @override
  String get readAnArtifact => 'Skaityti artefaktą';

  @override
  String get readAndEditFilesInsideYour =>
      'Skaitykite ir redaguokite failus aplanke NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Skaitykite $arg1';
  }

  @override
  String get readError => 'Skaitymo klaida';

  @override
  String get readFiles => 'Skaityti failus';

  @override
  String get readOnly => 'Tik skaityti';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Perskaitykite aplanką ir apibendrinkite krūvą, įvesties taškus ir kaip jį paleisti.';

  @override
  String get readThePage => 'Skaityti puslapį';

  @override
  String get readTheUiTree => 'Skaitykite vartotojo sąsajos medį';

  @override
  String get readWrite => 'Skaityti / Rašyti';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Skaito žingsnius, širdies ritmą, miegą, pratimus ir svorį.';

  @override
  String get ready => 'Paruošta';

  @override
  String get readyForFirstTimeSetup => 'Paruošta pirmą kartą nustatyti';

  @override
  String get readyToConnect => 'Paruošta prisijungti';

  @override
  String get recentChannelActivity => 'Naujausia kanalo veikla';

  @override
  String get recentChats => 'Naujausi pokalbiai';

  @override
  String get recentDecisions => 'Naujausi sprendimai';

  @override
  String get recentFailedRuns => 'Paskutiniai nesėkmingi paleidimai';

  @override
  String get recentGroupDecisions => 'Naujausi grupės sprendimai';

  @override
  String get recentRuns => 'Naujausi bėgimai';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Paskutiniai bėgimai trunka apie $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Naujausia serverio išvestis, naujausia pirmiausia.';

  @override
  String get recentUsage4Hours => 'Paskutinis naudojimas (4 valandos)';

  @override
  String get recents => 'Neseniai';

  @override
  String get recipientField => 'Gavėjo laukas';

  @override
  String get reconnectOrFinishSetup =>
      'Prisijunkite iš naujo arba užbaikite sąranką';

  @override
  String get reconnectingThisDevice => 'Iš naujo prijungiamas šis įrenginys…';

  @override
  String get recurring => 'Pasikartojantis';

  @override
  String get redirectUri => 'Peradresuoti URI';

  @override
  String get redoOnboarding => 'Pakartokite prisijungimą';

  @override
  String get refresh => 'Atnaujinti';

  @override
  String get refreshCode => 'Atnaujinti kodą';

  @override
  String get refreshNow => 'Atnaujinkite dabar';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Atnaujinkite „Android“ ekraną ir bandykite dar kartą.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Atsisakykite siųsti, nebent ryšys būtų atnaujintas į TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'neatsižvelgiant į toliau pateiktus kiekvienos kategorijos nustatymus.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Užregistruokite $arg1 asistento iškvietimo srautui.';
  }

  @override
  String get registrationIsClosed => 'registracija uždaryta';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registracija registracija naujos paskyros leidžia registruotis';

  @override
  String get rejectInvalidTlsCertificates =>
      'Atmesti netinkamus TLS sertifikatus';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'atleisti ir paleisti iš naujo. Prijungtos programos vėl prisijungia, kai tik ji grįžta.';

  @override
  String get releaseChannel => 'Išleidimo kanalas';

  @override
  String get releaseCommitBranchNode => 'atleiskite įsipareigojimo šakos mazgą';

  @override
  String get releaseWhenYouAreDone => 'Atleiskite, kai baigsite.';

  @override
  String get reloadNow => 'Įkelti iš naujo dabar';

  @override
  String get rememberThisChoice => 'Prisiminkite šį pasirinkimą';

  @override
  String get remove => 'Pašalinti';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Pašalinti „$arg1“ ir jo įrašytus veiksmus iš bėgimo istorijos?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Pašalinkite „$arg1“ iš pagrindinės atminties.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Pašalinti $arg1 raktą?';
  }

  @override
  String get removeEraseGdprUser => 'pašalinti ištrinti gdpr vartotoją';

  @override
  String get removeSmtpPassword => 'Pašalinkite SMTP slaptažodį';

  @override
  String get removeTheSmtpPassword => 'Pašalinti SMTP slaptažodį?';

  @override
  String get rename => 'Pervardyti';

  @override
  String get renameSecurityKey => 'Pervardyti saugos raktą';

  @override
  String get renameSession => 'Pervardyti sesiją';

  @override
  String get repairAndRetry => 'Pataisykite ir bandykite dar kartą';

  @override
  String get repairDesktop => 'Taisyti darbalaukį';

  @override
  String get repeat => 'Pakartokite';

  @override
  String get repliesWhenTagged => 'Atsako, kai pažymėta';

  @override
  String get replyToAddress => 'Atsakymas – adresu';

  @override
  String replyToArg1(Object? arg1) {
    return 'Atsakyti į $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Saugykla turi būti savininko / saugyklos formatu.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Atkurkite mano aprašytą klaidą, suraskite pagrindinę priežastį ir ištaisykite ją regresijos testu.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'užklausa nepavyko naudojant http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Užklausa nepavyko naudojant HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Prašyti leidimų';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Užklausa, skirta $arg1, nepavyko, prieš atsakant užpakalinei programai.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Prašė $arg1';
  }

  @override
  String get requireStarttls => 'Reikalauti STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Reikalingas už HTTPS arba TLS tarpinio serverio. Taikoma po serverio ';

  @override
  String get requiredExampleBerlinDe => 'Privaloma. Pavyzdys: Berlynas, DE';

  @override
  String get requiredFormatOwnerRepo =>
      'Privaloma. Formatas: savininkas/atpirkimas';

  @override
  String get reserveAssistantHotkey => 'Reserve asistento spartusis klavišas';

  @override
  String get reset => 'Nustatyti iš naujo';

  @override
  String get resetPassword => 'Iš naujo nustatyti slaptažodį';

  @override
  String get resetView => 'Iš naujo nustatyti rodinį';

  @override
  String get responsibilities => 'Pareigos';

  @override
  String get restart => 'Paleisti iš naujo';

  @override
  String get restartToFinishTheUpdate =>
      ' Paleiskite iš naujo, kad baigtumėte naujinimą.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Atkuriamas ankstesnis „NeoAgent“ vykdymo laikas';

  @override
  String get restrictDelegationTargets => 'Apriboti delegavimo tikslus';

  @override
  String get result => 'Rezultatas';

  @override
  String get resultDelivery => 'Rezultatų pristatymas';

  @override
  String get resultOneClickAddsOneYou =>
      'rezultatas. Vienas paspaudimas prideda vieną; vėliau galėsite redaguoti.';

  @override
  String get results => 'Rezultatai';

  @override
  String get retry => 'Bandykite dar kartą';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Daugkartinis · naudotas $arg1×';
  }

  @override
  String get reviewUncommittedChanges =>
      'Peržiūrėkite nepatvirtintus pakeitimus';

  @override
  String get revoke => 'Atšaukti';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Pirmiausia atšaukti administratorių su „neoagent admin anuliuoti $arg1“';
  }

  @override
  String get revokeThisLink => 'Atšaukti šią nuorodą?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Kambario paketinis langas: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Pasukite, kad tęstumėte';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'eilučių. Pridėkite LIMIT arba siauresnę WHERE sąlygą, kad pamatytumėte ';

  @override
  String get rule => 'Taisyklė';

  @override
  String get run => 'Vykdymas';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Vykdykite savavališkas komandas savo kompiuteryje arba VM.';

  @override
  String get runAt => 'Paleisti At';

  @override
  String get runCompleted => 'Bėgimas baigtas';

  @override
  String get runFailed => 'Paleisti nepavyko';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Vykdykite git diff, peržiūrėkite nepatvirtintus pakeitimus dėl klaidų ir stiliaus problemų ir apibendrinkite tai, ką radote.';

  @override
  String get runNotFound => 'Vykdyti nerasta';

  @override
  String get runNow => 'Vykdyti dabar';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Vykdykite gaunamus asmeninius WhatsApp pranešimus.';

  @override
  String get runQuery => 'Vykdyti užklausą';

  @override
  String get runShellCommandsOrInstallApps =>
      'Vykdykite apvalkalo komandas arba įdiekite programas „Android“ įrenginyje.';

  @override
  String get runStarted => 'Bėgimas prasidėjo';

  @override
  String get runStatus => 'Vykdymo būsena';

  @override
  String get runStopped => 'Bėgimas sustojo';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Vykdykite terminalo komandas ir atidarykite programas arba tinklalapius.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Paleiskite šį serverį: paskyros, naujinimai, teikėjai, konfigūracija ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Vykdyti, kai gaunamas atitinkamas „Gmail“ pranešimas.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Vykdyti, kai gaunamas atitinkamas Outlook el.';

  @override
  String get runWhenANewIssueMatching =>
      'Paleisti, kai saugykloje atidaroma nauja, filtrus atitinkanti problema.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Paleiskite, kai sukuriama nauja filtrus atitinkanti NeoRecall atmintis.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Vykdykite, kai į įrenginį gausite pranešimą.';

  @override
  String get runWhenASlackMessageMatches =>
      'Vykdyti, kai Slack pranešimas atitinka pasirinktą sritį.';

  @override
  String get runWhenATeamsChatMessage =>
      'Vykdyti, kai Teams pokalbio pranešimas atitinka pasirinktą sritį.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Vykdyti, kai tam tikroje vietoje prognozuojami sukonfigūruoti orų įvykiai.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'paleisti. Kol bet kuris modelis išjungtas, modeliai, kuriuos prideda tiekėjai ';

  @override
  String get running => 'Vykdoma';

  @override
  String runningArg1(Object? arg1) {
    return 'Veikia $arg1';
  }

  @override
  String get runningTask => 'Bėgimo užduotis';

  @override
  String get runningTool => 'Bėgimo įrankis';

  @override
  String get runs => 'Vykdymai';

  @override
  String get runsEveryDayAtTheSelected =>
      'Veikia kiekvieną dieną pasirinktu laiku.';

  @override
  String get runsFourTimesPerHour => 'Važiuoja keturis kartus per valandą.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— paleidimai, pranešimai, atmintis, integracijos, failai ir ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'paleidimai, pranešimai, prisiminimai, integracijos, failai ir seansai. ';

  @override
  String get runsMondayThroughFriday =>
      'Veikia nuo pirmadienio iki penktadienio.';

  @override
  String get runsOnSelectedWeekdays => 'Veikia pasirinktomis darbo dienomis.';

  @override
  String get runsOncePerHour => 'Veikia kartą per valandą.';

  @override
  String get runsOncePerMonthOnThe =>
      'Veikia kartą per mėnesį pasirinktą dieną.';

  @override
  String get runsOnlyWhenYouPressRun => 'Veikia tik paspaudus Vykdyti dabar.';

  @override
  String get runsPerDay => 'Veikia per dieną';

  @override
  String get runsPerDay30Days => 'Veikia per dieną (30 dienų)';

  @override
  String get runsThatCompleted => 'Paleidžia, kad baigtas';

  @override
  String get runsThisWeek => 'Veikia šią savaitę';

  @override
  String get runsToday => 'Veikia šiandien';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Čia rasite paleidimus, įrankius, atmintį, planavimą, įgūdžius ir MCP.';

  @override
  String get runsTwicePerHour => 'Veikia du kartus per valandą.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Paleidimai bus grąžinti į bendrinamą $arg1 serverio raktą, jei jis sukonfigūruotas. To negalima anuliuoti.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Veikimo laikas $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Veikimo laikas: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Vykdymo laiko nustatymai buvo pradėti nuo šio serverio. Redaguokite juos žemiau ';

  @override
  String get runtimeSetupRequired => 'Būtina nustatyti vykdymo laiką';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Vykdymo laiko pasirašymo viešasis raktas turi būti 32 baitai.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Išsaugoti';

  @override
  String get saveATrelloApiKeyFor =>
      'Išsaugokite šio agento Trello API raktą, tada saugiai prijunkite vieną Trello paskyrą. Paskyros prieigos raktas saugomas serveryje ir naudojamas tik šiam agentui.';

  @override
  String get saveAccount => 'Išsaugoti paskyrą';

  @override
  String get saveChanges => 'Išsaugoti pakeitimus';

  @override
  String get saveCloudComputerSettings =>
      'Išsaugokite debesies kompiuterio nustatymus';

  @override
  String get saveConnect => 'Išsaugoti ir prisijungti';

  @override
  String get saveDefaults => 'Išsaugoti numatytuosius nustatymus';

  @override
  String get saveDiagnosticReport => 'Išsaugoti diagnostikos ataskaitą';

  @override
  String get saveEmail => 'Išsaugoti el';

  @override
  String get saveEmailSettings => 'Išsaugokite el. pašto nustatymus';

  @override
  String get saveGeneralSettings => 'Išsaugokite bendruosius nustatymus';

  @override
  String get saveName => 'Išsaugoti vardą';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Išsaugokite „NeoAgent“ sąrankos diagnostiką';

  @override
  String get saveOnly => 'Tik išsaugoti';

  @override
  String get saveSetup => 'Išsaugoti sąranką';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Išsaugokite šiuos atkūrimo kodus dabar. Daugiau jie nebus rodomi.';

  @override
  String get savedDeliveryDestination => 'Išsaugota pristatymo vieta';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Išsaugotos @$arg1 tarifų ribos.';
  }

  @override
  String get scanANeoagentLoginQr =>
      'Nuskaitykite „NeoAgent“ prisijungimo QR kodą';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Nuskaitykite NeoAgent susiejimo QR iš kito įrenginio ir patvirtinkite jį per šią paleidimo seansą.';

  @override
  String get scanLoginQr => 'Nuskaitykite prisijungimo QR kodą';

  @override
  String get scanPairingQr => 'Nuskaityti susiejimo QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Nuskaitykite QR prisijungimo užklausas iš įrenginių, kuriuose atsijungta, ir patvirtinkite jas per šią autentifikuotą mobiliojo ryšio seansą.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Nuskaitykite, kad baigtumėte $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Nuskaitykite naudodami „NeoAgent“ savo telefone';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Nuskaito naujus el. laiškus ir praneša jums tik tada, kai kas nors svarbu.';

  @override
  String get schedule => 'Tvarkaraštis';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'numatytu laiku. Kai bėgiai bus išmatuoti, jie prasidės anksčiau.';

  @override
  String get screen => 'Ekranas';

  @override
  String get screenAction => 'ekrano veiksmas';

  @override
  String get scrollIsNotSupportedOnThis =>
      'slinkimas šioje platformoje nepalaikomas.';

  @override
  String get scrollToBottom => 'Slinkite į apačią';

  @override
  String get search => 'Ieškoti';

  @override
  String get search2 => 'Ieškoti…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Ieškoti administratoriaus nustatymų (pvz., SMTP, Ollama, žurnalai)';

  @override
  String get searchAgain => 'Ieškokite dar kartą';

  @override
  String get searchByUsernameOrEmail =>
      'Ieškokite pagal vartotojo vardą arba el';

  @override
  String get searchChannels => 'Ieškoti kanalų';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Ieškokite aptiktų pranešimų kanalų, kontaktų, grupių ir naujausių pokalbių.';

  @override
  String get searchGroups => 'Ieškoti grupių';

  @override
  String get searchMemory => 'Ieškoti atminties';

  @override
  String get searchModelsOrProviders => 'Ieškokite modelių ar tiekėjų';

  @override
  String get searchModelsOrProviders2 => 'Ieškoti modelių ar tiekėjų…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Ieškokite naujausių žmonių ir grupių';

  @override
  String get searchSessions => 'Paieškos seansai';

  @override
  String get searchSettings => 'Paieškos nustatymai';

  @override
  String get searchTitleModelTriggerRunId =>
      'Ieškokite pavadinimo, modelio, aktyviklio, paleidimo ID';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Paieškos įrankiai, integracijos ir įgūdžiai';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Ieškojo kodo \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Ieškojo failų „$arg1“';
  }

  @override
  String get secretField => 'Slaptas laukas';

  @override
  String get secureCookies => 'Saugūs slapukai';

  @override
  String get security => 'Saugumas';

  @override
  String get securityKey => 'Saugos raktas';

  @override
  String get securityKeyPromptWasDismissed =>
      'Saugos rakto raginimas buvo atmestas.';

  @override
  String get securityKeySignInCompletedBut =>
      'Prisijungimas saugos raktu baigtas, bet „NeoAgent“ negalėjo išlaikyti naršyklės seanso. Prisijunkite dar kartą.';

  @override
  String get securityKeySignInCouldNot =>
      'Nepavyko pradėti prisijungti prie saugos rakto.';

  @override
  String get securityKeys => 'Saugos raktai';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Saugos raktai pasiekiami tik „NeoAgent“ žiniatinklio programoje.';

  @override
  String get seeAll => 'Žiūrėti viską';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Pažiūrėkite, kurį NeoAgent serverį naudoja šis langas, ir paleiskite užpakalinę programą šiame kompiuteryje.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'matyti savo vartotojo vardą ir šiuos nustatymus, o ne pokalbius, prisiminimus ';

  @override
  String get selectARun => 'Pasirinkite bėgimą';

  @override
  String get selectASessionToSeeIts =>
      'Pasirinkite sesiją, kad pamatytumėte jos kompiuterį, failus ir pakeitimus.';

  @override
  String get selectAll => 'Pasirinkite viską';

  @override
  String get selectAll2 => 'Pasirinkite Viskas';

  @override
  String selectArg1(Object? arg1) {
    return 'Pasirinkite $arg1';
  }

  @override
  String get selectTrigger => 'Pasirinkite Trigger';

  @override
  String get send => 'Siųsti (⌘↵)';

  @override
  String get send2 => 'Siųsti';

  @override
  String get sendATaskFromChatAnd =>
      'Siųskite užduotį iš pokalbio ir čia bus rodoma jos vykdymo istorija.';

  @override
  String get sendItToATeammateWith =>
      'nusiųskite jį komandos draugui, turinčiam paskyrą šiame serveryje.';

  @override
  String get sendLink => 'Siųsti nuorodą';

  @override
  String get sendPath => 'Siųsti kelią';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Siųskite POST / PUT / DELETE užklausas išorinėms API.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Siųskite šią nuorodą tik tam asmeniui, kuriam ji skirta. Rodomas vieną kartą; ';

  @override
  String get senderAddress => 'Siuntėjo adresas';

  @override
  String get senderFilterOptional => 'Siuntėjo filtras (pasirenkamas)';

  @override
  String get sentSharedAttachments => 'Išsiuntė bendrinamus priedus.';

  @override
  String get separateAccount => 'Atskira sąskaita';

  @override
  String get server => 'Serveris';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Numatytasis serveris ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Numatytieji serverio balso skambučiai programoje. Skambučiai vyksta tiesiogiai ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'pats serveris: paskyros, teikėjai ir konfigūracija.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Serveris, slapyvardis, kanalas ir pasirenkamas TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'serverio išvesties konsolės įspėjimų klaidų kopija';

  @override
  String get serverProviderCredentials => 'Serverio teikėjo kredencialai';

  @override
  String get serverUrl => 'Serverio URL';

  @override
  String get serverUsageLimitsDonTApply =>
      'Serverio naudojimo apribojimai netaikomi modeliams, kuriuose veikia jūsų raktas.';

  @override
  String get serviceEmail => 'Paslaugos el';

  @override
  String get serviceEmailIsNotConfigured =>
      'paslaugų el. paštas nesukonfigūruotas';

  @override
  String get serviceEmailSmtp => 'Paslaugos el. paštas (SMTP)';

  @override
  String get sessionActions => 'Sesijos veiksmai';

  @override
  String get sessions => 'Sesijos';

  @override
  String get sessions2 => 'SESIJAS';

  @override
  String get sessionsArePinnedToAFolder =>
      'Seansai prisegti prie aplanko ir kompiuterio. Pradėkite planuoti, kurti, išbandyti ir išsiųsti iš čia.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sesijos (BDAR 17 str.). Administratoriaus paskyrų ištrinti negalima ';

  @override
  String get sessionsLogoutRevokeForce => 'seansų atsijungimas atšaukti jėgą';

  @override
  String get setBlockAskAllowPerTool =>
      'Nustatykite blokuoti / klausti / leisti pagal įrankių kategoriją arba pasirinkite visuotinį režimą.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Šiame kompiuteryje nustatykite „NeoAgent“.';

  @override
  String get setUpOrConnectNeoagent =>
      'Nustatykite arba prijunkite „NeoAgent“.';

  @override
  String get setUrl => 'Nustatyti URL';

  @override
  String get settings => 'Nustatymai';

  @override
  String get settingsAndCannotBeUndone =>
      'nustatymai ir jo negalima anuliuoti.';

  @override
  String get settingsArea => 'Nustatymų sritis';

  @override
  String get settingsAreas => 'Nustatymų sritys';

  @override
  String get setup => 'Sąranka';

  @override
  String get setupDetails => 'Išsami sąrankos informacija';

  @override
  String get setupRequired => 'Reikalinga sąranka';

  @override
  String get setupWasCancelled => 'Sąranka buvo atšaukta.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Bendrinami NeoAgent kliento priedai:';

  @override
  String get sharedFromAnotherApp => 'Bendrinama iš kitos programos';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Bendrinami teikėjo raktai sukonfigūruoti serveryje. Jei norite naudoti savo API raktą arba pasirinktinį galinį tašką, eikite į Išplėstinė → Atsineškite savo raktą.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Bendrinamas su NeoAgent pokalbiu ir jo atmintimi.';

  @override
  String get shellCommands => '„Shell“ komandos';

  @override
  String showAllArg1(Object? arg1) {
    return 'Rodyti visus $arg1';
  }

  @override
  String get showEarlier => 'Rodyti anksčiau';

  @override
  String get showEveryStep => 'Parodykite kiekvieną žingsnį';

  @override
  String get showTools => 'Rodyti įrankius';

  @override
  String get showWorkbenchJ => 'Rodyti darbastalį (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Rodomas pirmasis $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Rodoma šoninėje juostoje. Jei norite naudoti savo vartotojo vardą, palikite tuščią.';

  @override
  String get signIn => 'Prisijunkite';

  @override
  String get signInCompletedButNeoagentCould =>
      'Prisijungimas baigtas, bet „NeoAgent“ negalėjo išlaikyti naršyklės seanso. Prisijunkite dar kartą. Jei tai kartojasi, patikrinkite vidinės sesijos slapukų nustatymus.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Prisijungimas baigtas, bet „NeoAgent“ negalėjo išlaikyti naršyklės seanso. Prisijunkite dar kartą. Jei tai kartojasi, gali būti, kad galinio seanso slapukas nebus išsaugotas.';

  @override
  String get signInToThisNeoagentServer =>
      'Prieš nuskaitydami susiejimo QR kodą, prisijunkite prie šio NeoAgent serverio.';

  @override
  String get signInWithAHardwareKey =>
      'Prisijunkite naudodami aparatinės įrangos raktą arba prieigos raktą, o ne slaptažodį. ';

  @override
  String get signInWithASecurityKey => 'Prisijunkite naudodami saugos raktą';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Prisijunkite naudodami $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Patvirtinkite „NeoAgent“ savo $arg1 paskyroje. Nėra rakto kopijuoti.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Laukiu $arg1. Užbaikite naršyklėje.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Įklijuokite kodą $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Patvirtinus NeoAgent, $arg1 parodė vienkartinį kodą. Įklijuokite jį čia.';
  }

  @override
  String get signInCode => 'Prisijungimo kodas';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Prisijungta naudojant $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Nepavyko prisijungti: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Prisijunkite naudodami tą patį el. pašto adresą ir pagrindinį slaptažodį, kuriuos naudojate „Bitwarden“. Pagrindinis slaptažodis ir dviejų žingsnių kodas naudojami tik prisijungimui ir niekada nėra saugomi arba nesiunčiami dirbtiniam intelektui.';

  @override
  String get signOut => 'Atsijungti';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Visur atsijungti @$arg1?';
  }

  @override
  String get signOutEverywhere => 'Atsijunkite visur';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API tiltas';

  @override
  String get signalCliServerUrl => 'signal-cli serverio URL';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Pasirašyta @$arg1 po kiekvienos sesijos.';
  }

  @override
  String get signedInDevices => 'Prisijungę įrenginiai';

  @override
  String get signedInWithin24Hours => 'Prisijungta per 24 valandas';

  @override
  String get signingSecret => 'Pasirašymo paslaptis';

  @override
  String sinceArg1(Object? arg1) {
    return 'Nuo $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'nuo $arg1';
  }

  @override
  String get singleMessage => 'Viena žinutė';

  @override
  String get singleUse => 'Vienkartinis naudojimas';

  @override
  String get skill => 'Įgūdis';

  @override
  String get skillChanges => 'Įgūdžių pokyčiai';

  @override
  String get skillContent => 'Įgūdžių turinys';

  @override
  String get skills => 'Įgūdžiai';

  @override
  String get skip => 'Praleisti';

  @override
  String get skipForNow => 'Kol kas praleiskite';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Praleiskite šią užduotį prieš iškviečiant modelį.';

  @override
  String get slackMessageReceived => 'Gautas silpnas pranešimas';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Miegokite $arg1 seansus';
  }

  @override
  String get smartSelector => 'išmanusis parinkiklis';

  @override
  String get smartSelector2 => 'Išmanusis parinkiklis';

  @override
  String get smartSelectorPool => '„Smart Selector“ baseinas';

  @override
  String get smtpHost => 'SMTP priegloba';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp pašto siuntėjo slaptažodis tls patvirtinimo pranešimai nustatyti iš naujo';

  @override
  String get smtpPassword => 'SMTP slaptažodis';

  @override
  String get smtpPort => 'SMTP prievadas';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP prievadas turi būti sveikas skaičius nuo 1 iki 65535.';

  @override
  String get smtpUsername => 'SMTP vartotojo vardas';

  @override
  String get soTheRunStartsThatMuch => 'todėl bėgimas prasideda daug anksčiau.';

  @override
  String get socialBehaviorOff => 'Išjungtas socialinis elgesys';

  @override
  String get socialIntelligence => 'socialinis intelektas';

  @override
  String get socialIntelligence2 => 'Socialinis intelektas';

  @override
  String get socialObservability => 'Socialinis stebėjimas';

  @override
  String get socialReach => 'socialinis pasiekiamumas';

  @override
  String get socialReach2 => 'Socialinis pasiekiamumas';

  @override
  String get socialReach3 => 'Socialinis pasiekiamumas';

  @override
  String get socialReachUpdated => 'Socialinis pasiekiamumas atnaujintas.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Socialinių šaltinių agentai gali skaityti tiesiogiai, įskaitant sklaidos kanalus, saugyklas, „Reddit“, X, vaizdo įrašus ir slapukais paremtus rinkos duomenis.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Kažkas nutiko. Bandykite dar kartą.';

  @override
  String get source => 'Šaltinis';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Erdvės arba pokalbio ID naudojamas, kai šis agentas pradeda pokalbį.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      '„Space Webhook“ ir programos atgalinio skambinimo palaikymas';

  @override
  String get speaking => 'Kalbėdamas';

  @override
  String get speechToSpeechModelUsingThe =>
      'Kalbos į kalbą modelį naudodami OpenAI arba Google raktą ';

  @override
  String get speechToText => 'Iš kalbos į tekstą';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Iš kalbos į tekstą perrašomos balso pastabos ir diktantas. Automatiškai naudoja OpenAI, Gemini arba Deepgram, atsižvelgiant į tai, kuris turi API raktą. Balso atsakymo modelis yra pokalbio modelis, kuris atsako į balso pastabas.';

  @override
  String get sqlConsole => 'SQL konsolė';

  @override
  String get stable => 'Stabilus';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      '„Stable“ įdiegia naujausią paskelbtą backend leidimą.';

  @override
  String get stackTrace => 'kamino pėdsakas';

  @override
  String get standard => 'Standartinis';

  @override
  String get standardView => 'Standartinis vaizdas';

  @override
  String get start => 'Pradėti';

  @override
  String get startASessionToPlanOr =>
      'Pradėkite seansą planuoti arba kurti naudodami „NeoAgent“.';

  @override
  String get startAndroid => 'Paleiskite „Android“.';

  @override
  String get startComputer => 'Paleiskite kompiuterį';

  @override
  String get startFullSetup => 'Pradėkite visą sąranką';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Pradėti sąranką';

  @override
  String get startTalking => 'Pradėkite kalbėti';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Pirmiausia paleiskite „Android“ telefoną, tada numeskite .apk arba .apks failą čia.';

  @override
  String get startTheServerLaterFromThe =>
      'Paleiskite serverį vėliau iš sąrašo, kai tik bus išsaugota konfigūracija.';

  @override
  String get startWithARecommendedTask =>
      'Pradėkite nuo rekomenduojamos užduoties';

  @override
  String get startingAndroid => '„Android“ paleidimas';

  @override
  String get startingYourComputer => 'Kompiuterio paleidimas';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Prasideda xoxb-. Iš „Slack“ programos kredencialų.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting klaida: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'statistika vykdo žetonus, vartotojų diagramas sėkmės rodiklio';

  @override
  String get status => 'Būsena';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'būsenos duomenų bazės vykdymo VM teikėjai';

  @override
  String get statusIsNotLoadedYet => 'Būsena dar neįkelta.';

  @override
  String get stayManagedByYou => 'likite valdomi jūsų.';

  @override
  String get stayOnTheCall => 'Likite pokalbyje';

  @override
  String get stayedQuiet => 'Tyli';

  @override
  String get steering => 'VAIRAVIMAS';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return '$arg2 ŽINGSNIS $arg1';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Žingsniai $arg1';
  }

  @override
  String get stop => 'Sustabdyti';

  @override
  String get stop2 => 'Sustabdyti (⌘.)';

  @override
  String get stopManaging => 'Nustokite valdyti';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Nustoti valdyti $arg1?';
  }

  @override
  String get stopRun => 'Nustokite bėgioti';

  @override
  String get stopSpeaking => 'Nustok kalbėti';

  @override
  String get stoppedBeforeCompletion => 'Sustojo prieš baigiant';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting klaida: $arg1';
  }

  @override
  String get storage => 'Sandėliavimas';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'saugomi užšifruoti ir naudojami tik jūsų pačių paleidimams.';

  @override
  String get storedMetrics => 'Išsaugota metrika';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Saugo tik šiame serveryje užšifruotą „Bitwarden“ seanso raktą, todėl ryšiai išgyvena paleidus iš naujo. Galite bet kada užrakinti.';

  @override
  String get strong => 'Stiprus';

  @override
  String get strongPassword => 'Stiprus slaptažodis.';

  @override
  String get subAgent => 'Subagentas';

  @override
  String get subagentUpdate => 'Subagento atnaujinimas';

  @override
  String get subagentUpdate2 => 'Subagento atnaujinimas.';

  @override
  String get successRate => 'Sėkmės rodiklis';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Pasiūlymai: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Apibendrinkite mano paskutinį bėgimą';

  @override
  String get supportUrl => 'Palaikymo URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Palaikoma: rain_start, snow_start, wind_alert, temperatūra_aukščiau, temperatūra_žemiau';

  @override
  String get switchAgent => 'Perjungti agentą';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Simbolinės nuorodos neleidžiamos „NeoAgent Workspace“ keliuose.';

  @override
  String get syncNow => 'Sinchronizuoti dabar';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Sistemos privatumo nustatymai';

  @override
  String get tableInfoUsers => 'Lentelės informacija (naudotojai)';

  @override
  String get tagsOnly => 'Tik žymos';

  @override
  String get tasks => 'Užduotys';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Užduotys vykdomos pačios ir praneša jums ';

  @override
  String get teach => 'Mokyti';

  @override
  String get teachingInProgress => 'Vyksta mokymas';

  @override
  String get team => 'Komanda';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Komandos nuorodos niekada nepadaro serverio administratoriumi. Administratoriai paleidžia ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Komandos erdvės, kambariai, kanalai ir gyvos bendruomenės.';

  @override
  String get teamsMessageReceived => 'Gautas komandos pranešimas';

  @override
  String get templates => 'Šablonai';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Laikini sąrankos failai bus išvalyti vėliau.';

  @override
  String get tenantId => 'Nuomininko ID';

  @override
  String get testConnection => 'Bandomasis ryšys';

  @override
  String get testConnection2 => 'Bandomasis ryšys';

  @override
  String get textChat => 'Tekstas ir pokalbiai';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'kurie pridėjo savo raktą ir toliau juo naudojasi.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Šis el. paštas jau priklauso esamai paskyrai. Pirmiausia prisijunkite, tada susiekite „Google“ paskyros nustatymuose.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Šis el. paštas jau susietas su kita paskyra.';

  @override
  String get thatQrCodeIsNotA =>
      'Šis QR kodas nėra „NeoAgent“ prisijungimo užklausa.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Šis QR kodas nėra „NeoAgent“ susiejimo užklausa.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Šis saugos raktas jau užregistruotas šioje paskyroje.';

  @override
  String get theAddress => 'Adresas';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Jūsų BlueBubbles serverio adresas.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Adresas, kurį žmonės ir „OAuth“ teikėjai naudoja norėdami pasiekti ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agentas nuskaito jūsų paminėtus laikus ir vykdo suplanuotas užduotis šioje laiko juostoje.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Agentas paklaus prieš kiekvieną jautrų įrankį, ';

  @override
  String get theAgentWillIgnoreThisSkill => 'Agentas nepaisys šio įgūdžio.';

  @override
  String get theAppCouldNotReachThis =>
      'Programai nepavyko pasiekti šio „NeoAgent“ diegimo. Patikrinkite tinklo ryšį arba įsitikinkite, kad paslaugos URL teisingas.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Naršyklė užblokavo užklausą $arg1 dėl turinio saugos politikos.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Naršyklė užblokavo reikalingą užklausą dėl turinio saugos politikos.';

  @override
  String get theCloudWorkspace => 'debesies darbo sritis';

  @override
  String get theComputerCouldNotStart => 'Kompiuteris negalėjo paleisti';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Kompiuteriui reikia daugiau laisvos vietos NeoAgent pagrindiniame diske. Atlaisvinkite vietos, tada bandykite dar kartą.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Kompiuterio veikimo laikas reikalauja remonto. Paleiskite NeoAgent Doctor, tada bandykite dar kartą.';

  @override
  String get theConnectionTestFailed => 'Ryšio testas nepavyko.';

  @override
  String get theDesktopDidNotStart => 'Darbalaukis nepasileido';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Aptikta NeoAgent grąžino neišsamius tapatybės duomenis.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Aptikta NeoAgent naudoja nepalaikomą sąrankos protokolą.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Aptikta paslauga nėra „NeoAgent“.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Atsisiųstas „NeoAgent“ vykdymo laikas nepraėjo patvirtinimo.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      '„Google“ pokalbių erdvės žiniatinklio kabliukas, kuriame šis agentas turėtų skelbti.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Diegimo programa nebepasiekiama.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktyvus „Linux“ darbalaukis pasiekiamas „NeoAgent“ žiniatinklio programoje.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Įvadas nepasiekiamas šiame įrenginyje.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Naujausia informacija pateikiama kiekvienoje paskyroje.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Naujausias sinchronizavimo langas baigėsi $arg1 ir nerasta jokių naujų „Health Connect“ įrašų. Toliau saugomos metrikos gautos iš ankstesnių sinchronizacijų.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      '„Linux“ grafinė sesija neveikia.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Tiesioginio balso modelis neatsakė. Bandykite dar kartą.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Vietinė NeoAgent komanda išjungta su kodu $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Baigėsi vietos „NeoAgent“ komandos skirtasis laikas.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Reikia taisyti vietinę „NeoAgent“ vykdymo programą.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Reikia pataisyti vietinį vykdymo laiką ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Vietinio vartotojo namų katalogas nepasiekiamas.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Pašto paskyra NeoAgent siunčia registracijos patvirtinimus, prisijungimą ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Pagrindinis agentas sukuriamas automatiškai, kai reikia.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Šiame leidime trūksta atitinkamo „NeoAgent“ vykdymo laiko.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Svarbiausias gaunamas žiniatinklio kabliukas, kurį šis agentas turėtų paskelbti.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Modeliai, tarp kurių „Smart Selector“ nukreipia automatiškai.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      '„NeoAgent“ foninės programos atsisiuntimas neatitiko jo aprašo.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'NeoAgent backend atsisiuntimas buvo nebaigtas.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Šiame kompiuteryje esanti „NeoAgent“ programa neatsako per prievadą ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Nepavyko atsisiųsti „NeoAgent“ foninės programos vykdymo laiko.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return '„NeoAgent“ užtruko per ilgai, kad atsakytų į $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      '„NeoAgent“ diegimas atsakė HTTP 402, o ne įprastu 401 dėl neteisingų kredencialų. Patikrinkite atvirkštinio tarpinio serverio, autentifikavimo šliuzo arba su mokėjimu susijusias taisykles tame serveryje.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return '„NeoAgent“ diegimas atsakė HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'NeoAgent diegimas atsakė HTTP 402. Patikrinkite atvirkštinio tarpinio serverio, autentifikavimo šliuzo arba su mokėjimu susijusias taisykles tame serveryje.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'NeoAgent egzempliorius, prie kurio prijungta ši programa.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'NeoAgent išleidimo tarnyba pateikė neteisingus duomenis.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      '„NeoAgent“ vykdymo laiko artefakto metaduomenys neteisingi.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      '„NeoAgent“ vykdymo laiko aprašas nepraėjo parašo patvirtinimo.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      '„NeoAgent“ vykdymo laiko apraše nėra artefaktų.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      '„NeoAgent“ vykdymo laiko aprašo parašas neteisingas.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'Slaptažodis, kurį nustatėte „BlueBubbles“.';

  @override
  String get thePeopleYouManageStayWith =>
      'Žmonės, kuriuos valdote, lieka su jumis.';

  @override
  String get theProviderAnswers => 'atsako teikėjas.';

  @override
  String get theQueryReturnedNoRows => 'Užklausa nepateikė jokių eilučių.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Prašomas darbalaukio ekranas nepasiekiamas.';

  @override
  String get theRest => 'likusieji.';

  @override
  String get theRestEndpointForYourSignal =>
      'Signal-cli egzemplioriaus REST galutinis taškas.';

  @override
  String get theRunIsPausedUntilYou => 'Bėgimas pristabdytas, kol atsakysite.';

  @override
  String get theRunStartsAtTheScheduled => 'Bėgimas prasideda numatytu laiku.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Vykdymo laikas yra lengvas Debian Linux darbalaukis su Chromium, PCManFM, Mousepad, LXTerminal, Python, Git ir standartiniais komandinės eilutės įrankiais. Jo pajėgumus valdo „NeoAgent“ pagrindinis kompiuteris.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Nepavyko pradėti saugos rakto registracijos.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'serveris išsaugo tik jo piršto atspaudą.';

  @override
  String get theServerOnThisComputerIs =>
      'Serveris šiame kompiuteryje neveikia';

  @override
  String get theServerReportedNoHealthChecks =>
      'Serveris nepranešė apie sveikatos patikrinimus.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Signalo telefono numeris, kurį naudoja šis robotas.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Teams gaunamų žiniatinklio kabliukas, kuriam šis agentas turėtų skelbti.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Dviejų veiksnių iššūkis baigėsi. Prisijunkite dar kartą.';

  @override
  String get theTwoFactorCodeIsNot => 'Dviejų veiksnių kodas negalioja.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Patvirtintas vykdymo laikas negali būti pažymėtas kaip vykdomasis.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Patvirtintame vykdymo laiko pakete trūksta reikalingų failų.';

  @override
  String get theWebAppCouldNotReach =>
      'Žiniatinklio programai nepavyko pasiekti „NeoAgent“ sistemos.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Žiniatinklio programai nepavyko pasiekti „NeoAgent“ sistemos $arg1. Patikrinkite naršyklės konsolę ir atvirkštinio tarpinio serverio / tinklo konfigūraciją.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'patys; serverio operatorius pirmiausia pašalina administratorių ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Šie kanalai tyli. Jei norite dar kartą išgirsti, pridėkite juos skiltyje Kas gali pranešti apie tai platformai.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Šie sąrašai yra neprivalomi, nebent aukščiau esanti skiltis nustatyta kaip patvirtinta.';

  @override
  String get thesePeopleAnywhere => 'Šie žmonės bet kur';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Šie žmonės gali siųsti pranešimus $arg1 privačiuose pokalbiuose ir bet kurioje grupėje, kurią jie bendrina.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Šie žmonės gali siųsti žinutę $arg1 vienas su vienu. Tai neleidžia jiems kalbėti grupėmis.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Šie žmonės gali pranešti tik jūsų pasirinktoje grupėje $arg1.';
  }

  @override
  String get thesePeopleInOneGroup => 'Šie žmonės vienoje grupėje';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'šie jungikliai, niekada jūsų pokalbiai, prisiminimai ar failai.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Ši paskyra atrakins „NeoAgent“ šiame įrenginyje.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Šis agentas gali deleguoti bet kuriam tinkamam gaunančiam agentui.';

  @override
  String get thisAgentIsUsingAServer =>
      'Šis agentas naudoja serverio valdomą Trello API raktą. Toliau reikia tik įgalioti paskyros prieigos raktą.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Šiai versijai neleidžiama bendrauti su šiuo „NeoAgent“ diegimu.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Šis kodas priklauso kitam NeoAgent serveriui: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Šis darbalaukis yra prijungtas';

  @override
  String get thisDevice => 'Šis prietaisas';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Šis įrenginys: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Šis įrenginys negali užregistruoti saugos raktų. Atidarykite „NeoAgent“ naršyklėje per HTTPS, kad ją pridėtumėte.';

  @override
  String get thisDeviceUnavailable => 'Šis įrenginys – nepasiekiamas';

  @override
  String get thisFileHasNoContent => 'Šiame faile nėra turinio.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Tai paslepia „$arg1“ nuo maršruto parinkimo ir pasirinkimo.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Šiuo metu ši integracija palaiko vieną prijungtą paskyrą vienam agentui. Iš naujo atidarykite sąranką, kad ją pakeistumėte.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Ši integracija nebepasiekiama.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Šis įvadas skirtas kraštovaizdžio atkūrimui visame ekrane.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Tai valdomas diegimas. Jo operatorius išrieda ';

  @override
  String get thisMayTakeAMoment => 'Tai gali šiek tiek užtrukti.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Šis MCP serveris nebėra sukonfigūruotas.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Ši atmintis bus pašalinta visam laikui.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Ši „NeoAgent“ versija nesukonfigūruota patvirtinti užpakalinės programos vykdymo laikus.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Tai visam laikui ištrina visus jūsų duomenis ir negali būti ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Tai visam laikui ištrina paskyrą ir viską, kas jai priklauso: ';

  @override
  String get thisPersonAnywhere => 'Šis žmogus, bet kur';

  @override
  String get thisPersonInOneGroup => 'Šis asmuo vienoje grupėje';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Šios QR prisijungimo užklausos galiojimo laikas baigėsi. Sugeneruokite naują kodą ir bandykite dar kartą.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'ši qr prisijungimo užklausa pasibaigė';

  @override
  String get thisQrLoginRequestIsStill =>
      'Ši QR prisijungimo užklausa vis dar laukia patvirtinimo.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Ši QR prisijungimo užklausa jau buvo panaudota.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Taip pašalinama šio agento „Home Assistant“ sąranka ir prijungtas egzempliorius.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Tai pašalins NeoRecall backend URL ir visas prijungtas šio agento NeoRecall paskyras.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Tai pašalins Nextcloud URL ir visas prijungtas šio agento Nextcloud paskyras.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Taip pašalinama šio agento „Trello“ sąranka ir prijungtos paskyros.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Tam reikalinga autentifikuota sesija tame pačiame NeoAgent serveryje.';

  @override
  String get thisRunDidNotProduceA =>
      'Šis paleidimas nesukėlė vartotojui skirto atsakymo.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Šiam paleidimui nėra įrašytų žingsnių duomenų.';

  @override
  String get thisServer => 'šis serveris.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Šis serveris nepraneša apie jokius teikėjo nustatymus.';

  @override
  String get thisSkillIsNoLongerInstalled => 'Šis įgūdis nebėra įdiegtas.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Ši užduotis dar nebaigta, todėl ji vis tiek prasideda ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Ši užduotis bus vykdoma tik tada, kai paspausite Vykdyti dabar.';

  @override
  String get thisWeek => 'Šią savaitę';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Taip atsakymas bus importuotas į $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Tai pašalins „$arg1“.';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Tai pašalins „$arg1“ iš serverių sąrašo.';
  }

  @override
  String get time => 'Laikas';

  @override
  String get timeZone => 'laiko juosta';

  @override
  String get timeZone2 => 'Laiko juosta';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Baigėsi laikas$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Nepavyko išvardyti laiko juostų: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Nepavyko nuskaityti įrenginio laiko juostos: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Nepavyko išsaugoti įrenginio laiko juostos: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'iki $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'naudoti numatytuosius serverio nustatymus.';

  @override
  String get today => 'Šiandien';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return '@$arg1 simbolinis biudžetas. Palikite lauką tuščią ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Tokeno biudžetas kiekvienai paskyrai be atskiro nepaisymo. Palikite a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'žetono biudžeto limitas 4 valandų savaitės kvotos naudotojas';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'žetono biudžeto limitas 4 valandų savaitės kvota visuotinė';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Šioje serverio versijoje prieigos rakto naudojimas negalimas.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Žetonai gali būti panaudoti bet kuriai paskyrai per 4 valandas.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Žetonai gali būti panaudoti bet kuriai paskyrai per 7 dienas.';

  @override
  String get tokensPerDay => 'Žetonai per dieną';

  @override
  String get tokensPerRun => 'Žetonai už bėgimą';

  @override
  String get tokensToday => 'Žetonai šiandien';

  @override
  String get tokensUsed => ' naudojami žetonai';

  @override
  String get tomorrowPrep => 'Rytoj pasiruošimas';

  @override
  String get tooManyAttempts => 'per daug bandymų';

  @override
  String get tooManySignInAttemptsPlease =>
      'Per daug bandymų prisijungti. Palaukite ir bandykite dar kartą.';

  @override
  String get tool => 'Įrankis';

  @override
  String get toolApproval => 'Įrankio patvirtinimas';

  @override
  String get toolApprovalRequired => 'Reikalingas įrankio patvirtinimas';

  @override
  String get toolCompleted => 'Įrankis baigtas';

  @override
  String get toolFailed => 'Įrankis nepavyko';

  @override
  String get toolPermissions => 'Įrankio leidimai';

  @override
  String get toolStarted => 'Įrankis paleistas';

  @override
  String get tools => 'Įrankiai';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Įrankiai, neįtraukti į „NeoAgent“, įskaitant prijungtus MCP serverius ir pasirinktinių įrankių tiekėjus.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Siūlomi įrankiai ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Įrankiai, kuriuos gali naudoti valdoma paskyra';

  @override
  String get topUsers => 'Populiariausi vartotojai';

  @override
  String get topUsersAndRecentRuns =>
      'Populiariausi vartotojai ir paskutiniai paleidimai';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Iš viso: $arg1 žetonai per $arg2 paleidimus';
  }

  @override
  String get totalRuns => 'Iš viso bėgimų';

  @override
  String get totalTokens => 'Iš viso žetonų';

  @override
  String get totalUsers => 'Iš viso vartotojų';

  @override
  String get transcript => 'Nuorašas';

  @override
  String get transcript2 => 'ATRAŠAS';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Nepavyko transkribuoti: $arg1';
  }

  @override
  String get transfer => 'Perdavimas';

  @override
  String get trelloApiKey => 'Trello API raktas';

  @override
  String get trelloApiKeyIsRequired => 'Reikalingas Trello API raktas.';

  @override
  String get trelloSetup => '„Trello“ sąranka';

  @override
  String get triggerType => 'Trigerio tipas';

  @override
  String get tryABroaderSearchLikeModels =>
      'Išbandykite platesnę paiešką, pvz., modelius, naršyklę ar balsą.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Išbandykite teikėjo pavadinimą, „el. paštą“, „ribojimus“, „atnaujinti“ arba „žurnalus“.';

  @override
  String get tryAgain => 'Bandykite dar kartą';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Bandykite dar kartą. Jei tai kartojasi, paleiskite „NeoAgent Doctor“, kad patikrintumėte kompiuterio veikimo laiką.';

  @override
  String get tryAgainInAMoment => 'Po akimirkos bandykite dar kartą.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Bandykite dar kartą arba paleiskite NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Išbandykite kitą paiešką, prisijunkite prie pranešimų platformos arba rankiniu būdu įveskite paskirties ID.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Įjunkite grupę, jei $arg1 taip pat turėtų skaityti pranešimus, kuriuose ji nepažymėta.';
  }

  @override
  String get turnOffComputer => 'Išjunkite kompiuterį';

  @override
  String get turnOffOnlyForAMail =>
      'Išjungti tik pašto serveriui su savarankiškai pasirašytu sertifikatu.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Įjunkite, jei signalas turėtų ir toliau ieškoti gaunamų pokalbių.';

  @override
  String get turnTaking => 'posūkis imdamas';

  @override
  String get turnTakingModel => 'Posūkio modelis';

  @override
  String get turnTakingOff => 'Nusileidimas';

  @override
  String get turnThisOffToKeepThis =>
      'Išjunkite, kad šis agentas būtų visiškai atskirtas nuo kitų agentų.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Išjungė $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Išjungė $arg1, kuris tvarko šią paskyrą. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Jums išjungė $arg1 – tik jie gali tai pakeisti';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Išjungta jums, todėl negalite jo perduoti';

  @override
  String get twitchChatOverIrc => 'Twitch pokalbis per IRC';

  @override
  String get twoFactorAuthentication => 'Dviejų veiksnių autentifikavimas';

  @override
  String get twoFactorChallengeExpired => 'dviejų veiksnių iššūkis pasibaigė';

  @override
  String get twoFactorCode => 'dviejų faktorių kodas';

  @override
  String get twoFactorSignInCompletedBut =>
      'Dviejų veiksnių prisijungimas baigtas, bet „NeoAgent“ negalėjo išlaikyti naršyklės seanso. Prisijunkite dar kartą.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Prisijungimas dviem veiksmais (tik jei įjungta)';

  @override
  String get type => 'Tipas';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Įveskite $arg1, kad patvirtintumėte';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'tipo tekstas nepalaikomas šioje platformoje.';

  @override
  String get typedInTheBrowser => 'Įvedėte naršyklėje';

  @override
  String get typedText => 'Įvestas tekstas';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'nepavyksta rasti java vykdymo laiko';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Nepavyko atidaryti šios versijos laiko nustatymų.';

  @override
  String get unableToOpenWiFiSettings =>
      'Nepavyko atidaryti šios versijos „Wi-Fi“ nustatymų.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Nepavyko išlaikyti pasirinkto darbalaukio ekrano.';

  @override
  String get unclearWhoItWasFor => 'Neaišku, kam jis skirtas';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'atšauktas. Įveskite savo vartotojo vardą, kad patvirtintumėte.';

  @override
  String get unknownAccount => 'Nežinoma paskyra';

  @override
  String get unknownAgent => 'Nežinomas agentas';

  @override
  String get unknownBrowser => 'Nežinoma naršyklė';

  @override
  String get unknownDevice => 'Nežinomas įrenginys';

  @override
  String get unknownError => 'nežinoma klaida';

  @override
  String get unknownLocalComputerPermission =>
      'Nežinomas vietinio kompiuterio leidimas.';

  @override
  String get unknownLocation => 'Nežinoma vieta';

  @override
  String get unknownPublishTime => 'Nežinomas paskelbimo laikas';

  @override
  String get unknownSize => 'Nežinomas dydis';

  @override
  String get unlink => 'Atsieti';

  @override
  String get unreadOnly => 'Tik neskaitytas';

  @override
  String get unsavedChanges => 'Neišsaugoti pakeitimai';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Nepalaikoma papildoma darbalaukio komanda: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Nepalaikomas metodas: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Neįprasti prisijungimo įspėjimai';

  @override
  String updateArg1(Object? arg1) {
    return 'Atnaujinkite $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Atnaujinkite pagrindinės atminties įrašus iš importavimo.';

  @override
  String get updateNow => 'Atnaujinkite dabar';

  @override
  String get updateReady => 'Atnaujinimas paruoštas';

  @override
  String get updateSetup => 'Atnaujinkite sąranką';

  @override
  String get updateTheAccessListToAllow =>
      'Atnaujinkite prieigos sąrašą, kad galėtumėte atsakyti.';

  @override
  String get updateTheServer => 'Atnaujinti serverį?';

  @override
  String get updateTheServer2 => 'Atnaujinkite serverį';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Automatiškai atnaujinkite laiko juostą iš naudojamo įrenginio.';

  @override
  String updatedArg1(Object? arg1) {
    return 'atnaujintas $arg1';
  }

  @override
  String get updates => 'Atnaujinimai';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Šios versijos naujiniai nesukonfigūruoti.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'naujinimai, todėl savarankiškas atnaujinimas ir kanalų keitimai čia išjungti.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'atnaujinti naujinimą dabar išleiskite kanalo stabilią beta versiją';

  @override
  String get usageAnalytics => 'Naudojimo analizė';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Naudojimo ir būklės signalai, padedantys paaiškinti esamą vykdymo laiką, prieš tai nesigilinus į žurnalus.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Naudojimas visiškai iš naujo nustatomas $arg1';
  }

  @override
  String get usageLeaderboard => 'naudojimo lyderių lentelė';

  @override
  String get usageLimits => 'Naudojimas ir apribojimai';

  @override
  String get usageLimits2 => 'Naudojimas ir apribojimai';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Naudokite daugiau nei 8 simbolius. Gerai veikia ilgesnės slaptafrazės.';

  @override
  String get useADateAndTimeFor =>
      'Naudokite datą ir laiką, pavyzdžiui, 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Naudokite vardą, telefono numerį arba pokalbio ID.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Naudokite NeoRecall URL, kurį gali pasiekti NeoAgent serveris. NeoAgent PUBLIC_URL taip pat turi būti pasiekiamas iš šios naršyklės, kad būtų galima atlikti OAuth atgalinį skambinimą.';

  @override
  String get useANewPasswordWithAt =>
      'Naudokite naują slaptažodį, kurį sudaro mažiausiai 8 simboliai.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Naudokite Nextcloud URL, kurį gali pasiekti NeoAgent serveris, pvz., https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast => 'Naudokite bent 8 simbolių slaptažodį.';

  @override
  String get useASecureConnectionTls => 'Naudokite saugų ryšį (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Naudokite autentifikavimo programą, pvz., Authy, 1Password arba Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Naudokite bent 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb =>
      'Maksimali atmintis vienam kompiuteriui (MB)';

  @override
  String get maxVcpusPerComputer => 'Maksimalus vCPU viename kompiuteryje';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Bent jau $arg1. Kompiuteriai gauna mažiau, kai šeimininkas užimtas.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Didžiausia atmintis turi būti bent $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Naudokite bent 8 simbolius.';

  @override
  String get useDefault => 'Naudoti numatytąjį';

  @override
  String get useDefaultChannel => 'Naudokite numatytąjį kanalą';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Naudoti numatytąjį („NeoAgent Workspace“)';

  @override
  String get useFor => 'Naudoti';

  @override
  String get useManualDestination => 'Naudokite rankinį tikslą';

  @override
  String get useOrDoTheSameFor =>
      'naudokite arba darykite tą patį savo komandos draugams.';

  @override
  String get usePerCategorySettingsBelow =>
      'Toliau naudokite kiekvienos kategorijos nustatymus.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Naudoti numatytuosius nustatymus ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Naudokite serverį šiame kompiuteryje';

  @override
  String get useTheseForContextIfA =>
      'Naudokite juos kontekstui. Jei vietinis URI nėra tiesiogiai pasiekiamas iš serverio, paprašykite manęs pateikti failą per prieinamą darbo sritį.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Naudokite tai orkestrantams. Išjunkite pavienius darbo robotus, kurie patys turėtų baigti tiesioginius pranešimus.';

  @override
  String get useTlsFromTheStartOf =>
      'Naudokite TLS nuo ryšio pradžios, paprastai 465 prievade.';

  @override
  String get useYourOwnApiKeyFor =>
      'Teikėjui naudokite savo API raktą arba prijunkite pasirinktinį ';

  @override
  String get usedByEveryAccountOnThis =>
      'Naudojama kiekvienoje šio serverio paskyroje, kuri neturi rakto ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Naudojamas norint patikrinti, ar gaunami Slack įvykiai yra tikri.';

  @override
  String get userSummary => 'Vartotojo santrauka';

  @override
  String get username => 'Vartotojo vardas';

  @override
  String get usernameOrEmail => 'Vartotojo vardas arba el';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'naudotojai žmonės ieško el. pašto vartotojo vardo administratoriaus ženklelis valdoma komanda';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Naudoja nustatymuose sukonfigūruotą pokalbių modelį';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Naudojant įdiegtą NeoAgent vykdymo laiką';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Paprastai atrodo kaip @bot:matrix.org';

  @override
  String get validEmail => 'galiojantis el';

  @override
  String get value => 'Vertė';

  @override
  String get vaultLocked => 'Skliautas užrakintas';

  @override
  String get vaultOperationFailed => 'Skliauto operacija nepavyko.';

  @override
  String get verification => 'Patikrinimas';

  @override
  String verificationArg1(Object? arg1) {
    return 'Patikrinimas: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'patikra: $arg1';
  }

  @override
  String get verificationCompleted => 'Patikrinimas baigtas.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Patikrinimo būsena: $arg1';
  }

  @override
  String get verifiedTheResult => 'Patvirtino rezultatą';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Tikrinama atsisiųsta vykdymo laikas';

  @override
  String get versionAndUptime => 'Versija ir veikimo laikas';

  @override
  String versionArg1(Object? arg1) {
    return 'Versija $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Versija $arg1 įdiegta, bet $arg2 vis dar veikia.';
  }

  @override
  String get videoLinks => 'Vaizdo įrašų nuorodos';

  @override
  String get viewDesktop => 'Žiūrėti darbalaukį';

  @override
  String get viewLastRun => 'Žiūrėti paskutinį važiavimą';

  @override
  String get viewLogs => 'Peržiūrėti žurnalus';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm vaizdo atminties procesoriaus qemu vykdymo laikas';

  @override
  String get voice => 'Balsas';

  @override
  String get voiceAssistant => 'Balso asistentas';

  @override
  String get voiceCall => 'BALSO SKAMBUTIS';

  @override
  String get voiceCall2 => 'Balso skambutis';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'balso skambutis gpt-live gemini gyvo modelio kalba realiuoju laiku';

  @override
  String get voiceCallsRunOnALive =>
      'Balso skambučiai vykdomi naudojant tiesioginės kalbos į kalbą modelį, turintį tą pačią asmenybę, atmintį ir pokalbių istoriją kaip ir NeoAgent. Jis atsako iš karto ir perduoda tikrą darbą įprastam agentui, kuris ir toliau veikia fone.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'balso pastabos kalbos transkripcijos API raktas';

  @override
  String get voiceNotesAndDictation => 'Balso natos ir diktantas';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Balso atkūrimas šiame įrenginyje nepasiekiamas.';

  @override
  String get voiceReplyModel => 'Balso atsakymo modelis';

  @override
  String get waitingForApproval => 'Laukiama patvirtinimo: ';

  @override
  String get waitingForCode => 'Laukiama kodo';

  @override
  String get waitingForInput => 'Laukiama įvesties';

  @override
  String get waitingForServerOrFlutterLog =>
      'Laukiama serverio arba „Flutter“ žurnalo išvesties…';

  @override
  String get waitingForTaskEvents => 'Laukiama užduočių įvykių...';

  @override
  String get waitingForYou => 'laukia tavęs';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Norėjau gauti atsakymą iš $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Nori su jumis pasikalbėti · ${arg1}s';
  }

  @override
  String get weak => 'Silpnas';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Orai, kalendorius ir prioritetai prieš prasidedant dienai.';

  @override
  String get weatherEvent => 'Orų įvykis';

  @override
  String get web => 'Žiniatinklis';

  @override
  String get webBrowser => 'Interneto naršyklė';

  @override
  String get webSearchApiKey => 'žiniatinklio paieškos API raktas';

  @override
  String get webhookOrRestChannelPosting =>
      'Webhook arba REST kanalo paskelbimas';

  @override
  String get webhookSecret => 'Webhook paslaptis';

  @override
  String get webhookUrlCopied => 'Webhook URL nukopijuotas';

  @override
  String get weekdays => 'Darbo dienomis';

  @override
  String get weekdays0730 => 'Darbo dienomis · 07:30';

  @override
  String get weekdays1800 => 'Darbo dienomis · 18:00';

  @override
  String get weekly => 'Kas savaitę';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Savaitės limitas $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Savaitės limitas (žetonai)';

  @override
  String get weeklyReview => 'Savaitės apžvalga';

  @override
  String get weeklyUsage => 'Savaitinis naudojimas';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Svorio $arg1 rekordai';
  }

  @override
  String get welcomeToNeoagent => 'SVEIKI Į NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Sveiki atvykę\nį NeoAgent';

  @override
  String get whatAreYouAdding => 'Ką tu pridedi?';

  @override
  String get whatIsOnTomorrow => 'Kas bus rytoj?';

  @override
  String get whatShouldNeoagentLearn => 'Ko „NeoAgent“ turėtų išmokti?';

  @override
  String get whatShouldWeBuild => 'Ką turėtume statyti?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Tai, ką sakote jūs ir „NeoAgent“, rodoma čia ir pokalbyje.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Gauta WhatsApp asmeninė žinutė';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Kai pasirenkate tik patvirtintą, toliau pridėkite žmonių arba grupių.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Kur šis agentas turėtų siųsti atsakymus.';

  @override
  String get whoCanMessage => 'Kas gali pranešti';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kas gali pranešti $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kas gali siųsti $arg1 asmeninį pranešimą.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kas gali kalbėti su $arg1 grupėje, kanale ar kambaryje.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kas valdo šią paskyrą išjungta: ';

  @override
  String get whoManagesWhom => 'Kas kam vadovauja';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Kas priima nuorodą, prisijungia prie jūsų komandos naudodamas tik jos įrankius ';

  @override
  String get wholeGroup => 'Visa grupė';

  @override
  String get wholeGroups => 'Ištisos grupės';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Kodėl $arg1 atsakė arba tylėjo $arg2 grupėse.';
  }

  @override
  String get windowsApp => '„Windows“ programa';

  @override
  String get windowsNt => 'langai nt';

  @override
  String get workAccount => 'Darbo sąskaita';

  @override
  String get workOnAProjectWithNeoagent => 'Darbas su projektu su NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Darbo eiga: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Darbas $arg1 debesies kompiuteryje. NeoAgent skaito ir redaguoja ten esančius failus ir gali paleisti komandas bei naršyklę.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Darbas fone: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Darbo srities konfigūracija ir paskyros sauga vienoje vietoje.';

  @override
  String get workspaceFiles => 'Darbo srities failai';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Darbo sritis, modeliai ir diagnostikos valdikliai.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Darbo srities nepaisymas turi būti absoliutus kelias.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Parašė $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttp užklausos klaida';

  @override
  String get yesterday => 'vakar';

  @override
  String get youAreInControl => 'Jūs kontroliuojate';

  @override
  String get youCanFollowAlongOnThe => 'Galite sekti darbalaukyje.';

  @override
  String get youCanLeaveATeamAt =>
      'Galite palikti komandą bet kuriuo metu; jūsų nustatymai vėl taikomi.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Galite bet kada išeiti iš komandos puslapio.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Galite nuspręsti, kokius įrankius gali naudoti jūsų agentas, skiltyje „Nustatymai“ › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Jūs dar niekam nevaldote. Toliau sukurkite kvietimo nuorodą ir ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Turite neišsaugotų nustatymų. Ką norėtum veikti?';

  @override
  String get youReOnYourOwnYou =>
      'Jūs esate vienas: jūs nusprendžiate, kokius įrankius gali naudoti jūsų agentas. Jeigu ';

  @override
  String get yourAccountAndUsageOnA =>
      'savo paskyrą ir naudojimą modeliu, paremtu jūsų raktu ';

  @override
  String get yourAccountHasBeenDeleted => 'Jūsų paskyra ištrinta.';

  @override
  String get yourAgentWillBeAllowed => 'Jūsų agentui bus leidžiama:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Jūsų programos ir failai yra išsaugoti.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Jūsų programos ir failai lieka išsaugoti.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Jūsų $arg1 raktas';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Jūsų asistento sluoksnis, skirtas užfiksuoti, kontekstui ir veiksmui.';

  @override
  String get yourComputerIsAsleep => 'Jūsų kompiuteris miega';

  @override
  String get yourComputerIsOff => 'Jūsų kompiuteris išjungtas';

  @override
  String get yourComputerIsReady => 'Jūsų kompiuteris paruoštas';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Jūsų dabartinis slaptažodis yra neteisingas.';

  @override
  String get yourData => 'Jūsų duomenys';

  @override
  String get yourDataExportWasCopiedTo =>
      'Jūsų eksportuoti duomenys buvo nukopijuoti į mainų sritį.';

  @override
  String get yourDesktopIsReady => 'Jūsų darbalaukis paruoštas';

  @override
  String get yourLinuxComputer => 'Jūsų Linux kompiuteris';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Jūsų vieta niekada nėra nuolat stebima ir nesaugoma mūsų serveriuose. Jį naudojame tik lokaliai, kad patikrintume, ar jūsų aktyvios užduotys atitinka.';

  @override
  String get yourManager => 'jūsų vadovas';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Jūsų Mattermost svetainės URL, jei naudojate REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Jūsų sesija baigėsi arba naršyklė jos neišlaikė. Prisijunkite dar kartą.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Jūsų sesija baigėsi. Prisijunkite dar kartą.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Jūsų vartotojo vardas arba slaptažodis neteisingas.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Apžvalga';

  @override
  String get sectionDiagnostics => 'Diagnostika';

  @override
  String get sectionVolume => 'Apimtis';

  @override
  String get sectionSession => 'Sesija';

  @override
  String get sectionDeliverable => 'Pristatomas';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Vietinis vykdymo laikas dar neparašė žurnalo failo.';

  @override
  String get thisComputer => 'Šis kompiuteris';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta versija įdiegia naujausią išankstinio leidimo užpakalinę programą. Tikėtis šiurkščių kraštų.';

  @override
  String get copiedFinalResponse => 'Nukopijuotas galutinis atsakymas';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Galutinis atsakymas rodomas čia, kai paleidimas baigiasi.';

  @override
  String get waitingForTheFirstStep => 'Laukiam pirmojo žingsnio…';

  @override
  String get loadingPrompt => 'Įkeliamas raginimas…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Šiam bėgimui galutinis atsakymas nebuvo užfiksuotas.';

  @override
  String get readyToSignIn => 'Paruošta prisijungti';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Perjunkite į „Numatytasis“ arba „Visada klausti“, kad iš naujo įgalintumėte patvirtinimo patikras.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Siųsti vairavimo naujinį arba kitą pastabą apie dabartinį bėgimą...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Nėra tinklo ryšio. NeoAgent vėl prisijungs, kai įrenginys vėl prisijungs.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Dabartiniam važiavimui pritaikytas naujausias vairavimo atnaujinimas.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Ruošiamasi privačiam balso seansui…';

  @override
  String get preparingYourComputer => 'Kompiuterio paruošimas';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent atsisiunčia ir ruošia saugią Linux sistemą. Taip nutinka tik pirmą kartą.';

  @override
  String get moreFreeSpaceIsNeeded => 'Reikia daugiau laisvos vietos';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Atlaisvinkite vietos diske „NeoAgent“ priegloboje, tada bandykite dar kartą. Jūsų esami kompiuterio duomenys yra saugūs.';

  @override
  String get androidReady => 'Android paruošta';

  @override
  String get startingAndroid2 => 'Paleidžiama „Android“…';

  @override
  String get androidStopped => '„Android“ sustojo';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Pirmą kartą paleidus atsisiunčiamas „Android“ SDK ir sistemos vaizdas, o tai gali užtrukti kelias minutes.';

  @override
  String get androidIsStopped => 'Android sustabdytas';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Paleiskite valdomą „Android“ aplinką, kai jos reikia.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Leiskite NeoAgent dirbti šiame kompiuteryje';

  @override
  String get firstTimeSetupIsInProgress => 'Vykdoma pirmoji sąranka.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent gali naudoti jūsų leidžiamą prieigą.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Atlaisvinkite dalį prieglobos saugyklos ir bandykite dar kartą.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Pradėkite, kai norite, kad „NeoAgent“ padėtų čia.';

  @override
  String get systemPermissionMissing => 'Trūksta sistemos leidimo';

  @override
  String get connectingThisDevice => 'Šio įrenginio prijungimas';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Užmezgamas saugus vietinis ryšys.';

  @override
  String get recordingYourDemonstration => 'Jūsų demonstracijos įrašymas';

  @override
  String get noErrorsInTheRecentLog => 'Naujausiame žurnale klaidų nėra.';

  @override
  String get loadingAccounts => 'Įkeliamos paskyros…';

  @override
  String get neverSignedIn => 'Niekada neprisijungė';

  @override
  String get emptyUsesTheServerDefault =>
      'Empty naudoja numatytuosius serverio nustatymus.';

  @override
  String get followTheSelectedSession => 'Sekite pasirinktą seansą';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Tik planavimo režimas tikrina. Perjunkite į agento režimą, kad „NeoAgent“ redaguotų failus.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Būtina pridėti arba pakeisti paskyros el. pašto adresą.';

  @override
  String get confirmNewPassword => 'Patvirtinkite naują slaptažodį';

  @override
  String get passwordChanged => 'Slaptažodis pakeistas.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Ši užklausa jau panaudota.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Šios užklausos galiojimo laikas baigėsi. Paprašykite kito įrenginio sugeneruoti naują kodą.';

  @override
  String get startQuickstart => 'Pradėkite Greitą paleidimą';

  @override
  String get createYourAccount => 'Susikurkite paskyrą';

  @override
  String get showWorkAsSummaries => 'Rodyti darbus kaip santraukas';

  @override
  String get tokensUsedByTheLatestRun =>
      'Paskutiniame paleidime naudojami žetonai';

  @override
  String get listedTheWorkspaceRoot => 'Nurodyta darbo srities šaknis';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Dar nėra oficialių integracijų.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Dar nesukonfigūruota jokių MCP serverių. Pridėkite vieną, kad atskleistumėte jo įrankius.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Norėdami pradėti, pridėkite MCP serverį arba įdiekite įgūdžius.';

  @override
  String get setUp => 'Nustatyti';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Palikite tuščią, kad išsaugotumėte išsaugotą vertę';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Taip pašalinamas kiekvienos šio serverio paskyros adresas.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Tiesiog kalbėkite. Galite bet kada nutraukti. Palieskite, kad nutildytumėte.';

  @override
  String get tapAgainWhenYouAreDone => 'Baigę bakstelėkite dar kartą.';

  @override
  String get workingOnATaskInTheBackground => 'Darbas su užduotimi fone.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Iš kalbos į kalbą su ta pačia atmintimi, įrankiais ir pokalbių istorija kaip „NeoAgent“.';

  @override
  String get checkLink => 'Patikrinkite nuorodą';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Jūsų agentui nebus leidžiama naudoti jokių kontroliuojamų įrankių.';

  @override
  String get notYoursToChange => 'Ne tavo reikalas keistis';

  @override
  String get setByYou => 'Jūsų nustatyta';

  @override
  String get noTools => 'Jokių įrankių';

  @override
  String get untitledLink => 'Nuoroda be pavadinimo';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Nustoja veikti, kai vienas asmuo jį išpirks.';

  @override
  String get theOperator => 'Operatorius';

  @override
  String get smartSelectorOn => 'Išmanusis parinkiklis įjungtas';

  @override
  String get startASessionToBegin => 'Pradėkite seansą';

  @override
  String get steerTheActiveRun => 'Valdykite aktyvų bėgimą…';

  @override
  String get describeWhatToPlan => 'Aprašykite ką planuoti…';

  @override
  String get stopDictation => 'Sustabdykite diktavimą';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Pranešimai nukreipia einamąjį paleidimą · ⌘↵ siųsti · ⌘. sustoti';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Tik plano režimas tikrina; niekas nepasikeis, kol neįgyvendinsite · ⌘↵ siųsti';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agentas redaguoja darbo sritį. Planuokite tik patikrinimus.';

  @override
  String get defaultModel => 'Numatytasis modelis';

  @override
  String get openingScanner => 'Atidaromas skaitytuvas...';

  @override
  String get theAgentCanUseThisSkill => 'Agentas gali panaudoti šį įgūdį.';

  @override
  String get allSelected => 'Visi atrinkti';

  @override
  String get addCoreMemoryEntry => 'Pridėti pagrindinės atminties įrašą';

  @override
  String get channelId => 'Kanalo ID';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Dirbtinio intelekto sukurtos ir nenurodytos užduotys naudoja dabartinę numatytąją reikšmę.';

  @override
  String get waitingForRunEvents => 'Laukiam bėgimo renginių...';

  @override
  String get hideSteps => 'Slėpti žingsnius';

  @override
  String get commitTheActiveLiveCapture =>
      'Atlikite aktyvų tiesioginį filmavimą';

  @override
  String get stopCaptureAndSubmit => 'Sustabdykite fiksavimą ir pateikite';

  @override
  String get clickTheMicToStartSpeaking =>
      'Norėdami pradėti kalbėti, spustelėkite mikrofoną';

  @override
  String get connectACustomEndpoint => 'Prijunkite pasirinktinį galinį tašką';

  @override
  String get hostedProvider => 'priglobtas teikėjas.';

  @override
  String get muted => ' • nutildytas';

  @override
  String get addWhoCanMessage => 'Pridėkite, kas gali pranešti';

  @override
  String get joinsGroupConversations => 'Prisijungia prie grupės pokalbių';

  @override
  String get label1PersonOrGroupAdded => 'Pridėtas 1 asmuo arba grupė';

  @override
  String get inProgress => 'Vykdoma';

  @override
  String get waitingForUpdateJobOutput =>
      'Laukiama atnaujinimo užduoties išvesties…';

  @override
  String get taskTrigger => 'Užduočių paleidiklis';

  @override
  String get bearerToken => 'Nešėjo žetonas';

  @override
  String get bearerToken2 => 'Nešėjo Žetonas';

  @override
  String get notRecorded => 'Neįrašyta';

  @override
  String get sessionCookie => 'Seanso slapukas';

  @override
  String get neverUsed => 'Niekada nenaudota';

  @override
  String get linkedRecently => 'Neseniai susieta';

  @override
  String get notUsedYet => 'Dar nenaudota';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Vienos ar daugiau paskyrų galiojimo laikas baigėsi. Prisijunkite iš naujo, kad atkurtumėte prieigą. Jei tai kartojasi, jūsų „Google Cloud OAuth“ programa gali veikti testavimo režimu – paskelbkite ją „Google Cloud Console“ gamyboje, kad gautumėte ilgalaikius prieigos raktus.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      '„Vault“ prijungtas ir pasiekiamas paleidus iš naujo';

  @override
  String get vaultConnectedForThisSession =>
      'Prie šios sesijos prijungta saugykla';

  @override
  String get connectAnotherAccount => 'Prijunkite kitą paskyrą';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Įklijuokite pakaitinį ilgalaikį prieigos raktą';

  @override
  String get updateInstance => 'Atnaujinti egzempliorių';

  @override
  String get pasteAReplacementToken => 'Įklijuokite pakaitinį prieigos raktą';

  @override
  String get replaceAccount => 'Pakeiskite paskyrą';

  @override
  String get addAccount => 'Pridėti paskyrą';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Gali deleguoti bet kuriam priimančiam agentui';

  @override
  String get canReceiveDelegatedTasks2 => 'gali gauti deleguotas užduotis';

  @override
  String get noSyncYet => 'Dar nėra sinchronizavimo';

  @override
  String get noNewData => 'Naujų duomenų nėra';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sinchronizuokite vieną kartą, kad pradėtumėte savo užpakalinę programą.';

  @override
  String get lastWindowEndIsUnknown => 'Paskutinis lango galas nežinomas.';

  @override
  String get lastNonEmptySync => 'Paskutinis netuščias sinchronizavimas';

  @override
  String get stopTranscribe => 'Sustabdyti ir perrašyti';

  @override
  String get steeringMode => 'Vairavimo režimas';

  @override
  String get noMessageText => 'Nėra žinutės teksto';

  @override
  String get reconnectingToServer => 'Iš naujo prisijungiama prie serverio…';

  @override
  String get signingIn => 'Prisijungiama...';

  @override
  String get noGroupsFoundYet => 'Kol kas nerasta grupių';

  @override
  String get onForNewGroupsOnly => 'Įjungta tik naujoms grupėms';

  @override
  String get noGroupsInThisCategory => 'Šioje kategorijoje nėra grupių';

  @override
  String get groupOrChannel => 'Grupė arba kanalas';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Užrašai, kuriuos rašote sau, pradeda bėgioti, o atsakymai patenka į tą patį pokalbį. Leidžiamasis sąrašas čia netaikomas.';

  @override
  String get needToReply => 'Reikia atsakyti';

  @override
  String get enter2faCode => 'Įveskite 2FA kodą';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Atidarykite autentifikavimo programą ir įveskite dabartinį NeoAgent kodą.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Jau turite paskyrą? Prisijunkite';

  @override
  String get serverOnThisComputer => 'Serveris šiame kompiuteryje';

  @override
  String get showQrCode => 'Rodyti QR kodą';

  @override
  String get createAnotherNeoagentAccount => 'Sukurkite kitą NeoAgent paskyrą.';

  @override
  String get canCoordinateDelegatedWork => 'Gali koordinuoti deleguotą darbą';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Nepavyko išskleisti „NeoAgent“ vykdymo laiko archyvo.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Nepavyko nuskaityti „NeoAgent“ vykdymo laiko archyvo.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      '„NeoAgent“ vykdymo laiko archyve yra nesaugus kelias.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      '„NeoAgent“ vykdymo laiko archyve yra nesaugi nuoroda.';

  @override
  String get installingAppPackageOnThePhone =>
      'Įdiegiamas programos paketas telefone...';

  @override
  String get dragAndDropAApkOrApks =>
      'Nuvilkite .apk arba .apks failą čia arba spustelėkite, kad naršytumėte.';

  @override
  String get releaseToInstallThisPackage =>
      'Atleiskite, kad įdiegtumėte šį paketą';

  @override
  String get theSecurityKeyCouldNotBeUsed => 'Nepavyko naudoti saugos rakto.';

  @override
  String get connecting => 'Jungiamasi…';

  @override
  String get changes => 'Pakeitimai';

  @override
  String get runtimeReady => 'Veikimo laikas paruoštas';

  @override
  String get saving => 'Išsaugoma...';

  @override
  String get earlier => 'Anksčiau';

  @override
  String get monthJan => 'sausio mėn';

  @override
  String get monthFeb => 'vasario mėn';

  @override
  String get monthMar => 'Kov';

  @override
  String get monthApr => 'Balandžio mėn';

  @override
  String get monthMay => 'gegužės mėn';

  @override
  String get monthJun => 'birželio mėn';

  @override
  String get monthJul => 'liepos mėn';

  @override
  String get monthAug => 'rugpjūčio mėn';

  @override
  String get monthSep => 'rugsėjis';

  @override
  String get monthOct => 'spalio mėn';

  @override
  String get monthNov => 'Lapkričio mėn';

  @override
  String get monthDec => 'gruod';

  @override
  String get steeringWord => 'Vairavimas';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Tai perjungia užpakalinę dalį iš $arg1 kanalo į $arg2 kanalą.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Importuoti $arg1 slapukai';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Prieš $arg1';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Vairavimas eilėje: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Žiniatinklio programai nepavyko pasiekti „NeoAgent“ sistemos.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Naršyklė užblokavo reikalingą užklausą dėl turinio saugos politikos.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return 'Leidžiama $arg1 iš 4';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Atlikite užduotį kaip įprastai.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Pakeitimai · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Šis prietaisas · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Pasiektas limitas$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1 atkūrimo kodai vis dar galimi.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Saugos raktas $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Dabartinė sesija';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nPaskutinį kartą naudota: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Šiame įrenginyje veikia $arg1. NeoAgent skaito ir redaguoja aplanką tiesiogiai ir gali vykdyti komandas, atidaryti programas ir naudoti ekraną.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Dirbo $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Leidžiama $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1 kvietimo nuorodos iš $arg2 buvo atšauktos';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Pridėkite žmones ir grupes, su kuriomis $arg1 turėtų kalbėti';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Pridėkite žmones ir grupes, su kuriomis $arg1 leidžiama kalbėti.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Kur klauso $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 stebi šias vietas, kad būtų paminėta. Čia paskelbti gali bet kas, todėl žmonėms vis tiek reikalingas jų pačių patvirtinimas.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Šie žmonės gali paklausti $arg1, kad ir kur jį pažymėtų. Vaidmenys skaičiuojami tik aukščiau nurodytose vietose.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Tik tada, kai pažymėtas $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Įjungta visoms $arg1 grupėms';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 vis tiek girdi tik tuos žmones ir grupes, kuriuos jau patvirtinote. Tai tiesiog leidžia $arg1 prisijungti prie įprasto pokalbio, o ne tik pažymėti žymas ir atsakymus.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 vis tiek girdi tik tuos žmones ir grupes, kuriuos jau patvirtinote. Tai tik pasirenka, prie kurios iš tų grupių jis turėtų prisijungti.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Jei kas nors pažymi $arg1 arba atsako, $arg1 visada atsako. Įjunkite, jei $arg1 taip pat turėtų skambėti įprastame grupės pokalbyje.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Naujos grupės leis $arg1 prisijungti prie įprastų pokalbių su patvirtintais žmonėmis, kol juos išjungsite.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Naujos grupės leis $arg1 prisijungti prie įprasto pokalbio, kol jas išjungsite.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Naujos grupės tyli, nebent patvirtintas asmuo pažymės $arg1, kol jas neįjungsite.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Tik tada, kai patvirtintas asmuo pažymi $arg1, nebent įjungsite grupę';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Tik tada, kai pažymėtas $arg1, nebent įjungsite grupę';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 iš $arg2 grupių prisijungia prie įprasto pokalbio su patvirtintais žmonėmis';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Tai nepatvirtina naujų žmonių. Patvirtintų žmonių žymos ir atsakymai visada sulaukia atsakymo. Įjunkite grupę, jei $arg1 taip pat turėtų prisijungti prie įprasto pokalbio.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Tai nepatvirtina naujų žmonių. Įjunkite grupę, jei $arg1 turėtų prisijungti prie įprasto pokalbio su žmonėmis, kuriuos jau patvirtinote.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Žymos ir atsakymai visada sulaukia atsakymo. Įjunkite grupę, jei $arg1 taip pat turėtų prisijungti prie įprasto pokalbio.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 prisijungia prie įprastų pokalbių su patvirtintais žmonėmis';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 gali prisijungti prie įprasto pokalbio';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 atsako tik tada, kai jį pažymi patvirtintas asmuo';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nieko papildomai nereikia. Prisijunkite, kad pradėtumėte naudoti $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Atnaujina ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registruokitės $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Su „$arg1“ nėra susietų prisiminimų.';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (numatytasis)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filialas: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 prisijungia tik prie grupių ir kanalų, kuriuos pridedate toliau.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 reikalingas norint rasti „NeoAgent“ vykdymo laiko duomenis.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[sutrumpinta peržiūra, iš viso $arg1 baitų]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[ribojamas artefaktas, iš viso $arg1 baitų]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' $arg1';
  }

  @override
  String get worldNews => 'Pasaulio naujienos';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Paleiskite, kai pasirodys naujos pasaulio antraštės. Jūsų raginimas nusprendžia, ar jums pranešti.';

  @override
  String get newsKeywordsOptional => 'Raktiniai žodžiai (neprivaloma)';

  @override
  String get worldNewsSetup => 'Pasaulio naujienų sąranka';

  @override
  String get connectWorldNewsWithGnews =>
      'Pridėkite GNews API raktą (nemokamą planą rasite adresu gnews.io). Jis saugomas užšifruotas ir naudojamas populiariausioms pasaulio naujienų antraštėms apklausti.';

  @override
  String get gnewsApiKey => 'GNews API raktas';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Įklijuokite pakaitinį GNews API raktą';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Palikite raktą tuščią, kad išsaugotumėte šiuo metu saugomą raktą.';

  @override
  String get gnewsApiKeyIsRequired => 'Reikalingas GNews API raktas.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Nepavyko išsaugoti Pasaulio naujienų sąrankos.';

  @override
  String get disconnectWorldNews => 'Atjunkite Pasaulio naujienas';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Tai pašalina išsaugotą GNews API raktą. Pasaulio naujienų aktyvikliai nustos suaktyvinti, kol vėl pridėsite raktą.';

  @override
  String get couldNotDisconnectWorldNews => 'Nepavyko atjungti „World News“.';

  @override
  String get systemOneModels => 'SystemOne modeliai';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Parenka geriausią galimą SystemOne modelį';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Šiuos sprendimus priima pokalbių modelis';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Sprendimų modeliai, kurie skambina užkulisiuose per sekundės dalį: grupinio pokalbio eilė ir naršyklės veiksmai. Jūsų pokalbio modelis vis tiek rašo kiekvieną atsakymą.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      '„SystemOne“ modelis nusprendžia, kada kalbėti, kai jis įjungtas; šis modelis yra atsarginis.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 surinko SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne šį pranešimą įvertino tiesiogiai. Joks kalbos modelis nebuvo paleistas.';

  @override
  String get systemOneUnavailable => '„SystemOne“ nepasiekiamas';

  @override
  String get systemOneAdminAvailability =>
      'Sprendimų modelių agentai gali pasirinkti skiltyje Nustatymai › Modeliai. Čia išjungtas modelis palieka rinkiklį, o jį pasirinkę agentai grįžta į „Auto“. Kai bet kuris modelis yra išjungtas, SystemOne modeliai, kuriuos teikėjai prideda vėliau, taip pat išjungiami.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Dar nėra SystemOne modelių. Pridėkite „TypeSafe“ arba „OpenRouter“ raktą dalyje „Providers“ arba paimkite sprendimo modelį, pvz., „Nimble“ „Ollama 0.35“ ar naujesnėje versijoje.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Dar nėra „SystemOne“ modelio. Pridėkite „TypeSafe“ arba „OpenRouter“ raktą skiltyje „Nustatymai“ › Modeliai › Atsineškite savo raktą arba pasiimkite sprendimo modelį, pvz., „Nimble in Ollama“.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistemos vieno sprendimo modeliai jev typesafe openrouter ollama prieinamumas įjungti išjungti';

  @override
  String get chatModels => 'Pokalbių modeliai';

  @override
  String get disabled => 'Išjungta';

  @override
  String get enableShown => 'Įgalinti rodomą';

  @override
  String get disableShown => 'Rodoma išjungti';

  @override
  String get expandAll => 'Išskleisti viską';

  @override
  String get collapseAll => 'Sutraukti viską';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 neišsaugoti pakeitimai';
  }

  @override
  String get settingsScopeAllAgents => 'Visi agentai';

  @override
  String get settingsScopeAgent => 'Šis agentas';

  @override
  String get settingsScopeApp => 'Programėlė';

  @override
  String get settingsScopeAccountHint => 'Tas pats visur, kur prisijungiate';

  @override
  String get settingsScopeAllAgentsHint => 'Bendrino visi jūsų agentai';

  @override
  String get settingsAppliesTo => 'Taikoma';

  @override
  String get settingsSaving => 'Išsaugoma…';

  @override
  String get settingsSavedAutomatically => 'Pakeitimai išsaugomi automatiškai';

  @override
  String get settingsSearchHint => 'Ieškokite visų nustatymų';

  @override
  String get settingsPageProfile => 'Profilis';

  @override
  String get settingsPageSecurity => 'Prisijungimas ir sauga';

  @override
  String get settingsPageUsage => 'Naudojimas';

  @override
  String get settingsPagePermissions => 'Leidimai';

  @override
  String get settingsPageComputer => 'Kompiuteris ir žiniatinklis';

  @override
  String get settingsPageBehavior => 'Elgesys';

  @override
  String get settingsPageSystem => 'Sistema';

  @override
  String get settingsPagePlatforms => 'Platformos';

  @override
  String get settingsPageProfileDescription =>
      'Jūsų vardas ir el. pašto adresas, jūsų duomenų kopija ir atsijungimas.';

  @override
  String get settingsPageSecurityDescription =>
      'Slaptažodis, dviejų veiksnių autentifikavimas, saugos raktai ir vieta, kur esate prisijungę.';

  @override
  String get settingsPageUsageDescription =>
      'Jūsų limitai ir žetonų išlaidos – viskas vienoje vietoje.';

  @override
  String get settingsPageAgentsDescription =>
      'Sukurkite agentus ir pasirinkite, kuris iš jų atsakys pagal numatytuosius nustatymus.';

  @override
  String get settingsPagePermissionsDescription =>
      'Ką jūsų agentai gali daryti prieš tai jūsų nepaklausę.';

  @override
  String get settingsPageComputerDescription =>
      'Kompiuteris, kuriame dirba jūsų agentai, ir svetainės, kurias jie gali skaityti kaip jūs.';

  @override
  String get settingsPageModelsDescription =>
      'Kokius modelius naudoja šis agentas, ir API raktus, už kuriuos mokama.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kaip šis agentas kalba ir kaip skaito grupės pokalbį.';

  @override
  String get settingsPageVoiceDescription =>
      'Tiesioginiai šio agento skambučiai, diktavimas ir atsakymai žodžiu.';

  @override
  String get settingsPageMessagingDescription =>
      'Kur žmonės gali susisiekti su šiuo agentu ir kaip jis elgiasi pokalbiuose.';

  @override
  String get settingsPageGeneralDescription =>
      'Išvaizda, kalba, laiko juosta ir tai, ką ši programa veikia fone.';

  @override
  String get settingsPageSystemDescription =>
      'Serveris, kurį naudoja šis langas, serveris, esantis šiame kompiuteryje, ir programos naujiniai.';

  @override
  String get settingsYourAgents => 'Jūsų agentai';

  @override
  String get settingsChatModel => 'Pokalbių modelis';

  @override
  String get settingsChatModelDescription => 'Atsako į jūsų žinutes.';

  @override
  String get settingsSubAgentModel => 'Subagento modelis';

  @override
  String get settingsSubAgentModelDescription =>
      'Vykdo darbą, perduotą atliekant užduotį.';

  @override
  String get settingsDefaultModels => 'Numatytieji modeliai';

  @override
  String get settingsDefaultModelsDescription =>
      'Naudojama, kai pokalbis ar užduotis nepasirenka savo modelio.';

  @override
  String get settingsModelPool => 'Modelinis baseinas';

  @override
  String get settingsApiKeysDescription =>
      'Šiam agentui naudokite savo raktus arba galutinį tašką. Raktai yra užšifruoti ir daugiau niekada nerodomi.';

  @override
  String get settingsPersona => 'Persona';

  @override
  String get settingsFineTuning => 'Tikslus derinimas';

  @override
  String get settingsFineTuningDescription =>
      'Retai reikia. Numatytieji nustatymai tinka daugumai pokalbių.';

  @override
  String get settingsShow => 'Rodyti';

  @override
  String get settingsHide => 'Slėpti';

  @override
  String get settingsMinimumContribution => 'Minimali įnašo vertė';

  @override
  String get settingsBatchWindow => 'Kambario paketinis langas';

  @override
  String get settingsBatchWindowDescription =>
      'Laukia tiek ilgai, kad greitieji pranešimai būtų traktuojami kaip vienas posūkis.';

  @override
  String get settingsHandsFree => 'Laisvų rankų įranga';

  @override
  String get settingsHandsFreeDescription =>
      'Kalbėkite laisvai ir pertraukite bet kuriuo metu.';

  @override
  String get settingsPushToTalkDescription =>
      'Laikykite norėdami kalbėti, atleiskite, kad išsiųstumėte.';

  @override
  String get settingsLiveVoice => 'Gyvas balsas';

  @override
  String get settingsChannels => 'Kanalai';

  @override
  String get settingsGroupChats => 'Grupiniuose pokalbiuose';

  @override
  String get settingsGroupChatsDescription =>
      'Kaip šis agentas elgiasi grupėse kiekviename kanale.';

  @override
  String get settingsGroupChatsDisabled =>
      'Įjunkite elgesio modulius skiltyje „Elgesys“, kad juos pakeistumėte.';

  @override
  String get settingsParticipationAutomatic => 'Automatinis';

  @override
  String get settingsParticipationMentionOnly => 'Tik paminėti';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Skaito kambarį ir prisijungia, kai turi ką naudingo pridėti.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Atsako tik paminėjus arba į juos atsakius.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Atsako į kiekvieną žinutę.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Padalina ilgesnius atsakymus į trumpąsias žinutes, kaip tai darytų asmuo.';

  @override
  String get settingsDeliverySingleDescription =>
      'Kiekvieną atsakymą siunčia kaip vieną žinutę.';

  @override
  String get settingsComputerStatus => 'Būsena';

  @override
  String get settingsTest => 'Testas';

  @override
  String get settingsAppearance => 'Išvaizda';

  @override
  String get settingsTheme => 'tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Šviesi';

  @override
  String get settingsThemeDark => 'Tamsi';

  @override
  String get settingsCloseWindow => 'Kai uždarai langą';

  @override
  String get settingsCloseAsk => 'Paklausk';

  @override
  String get settingsCloseKeepRunningDescription =>
      '„NeoAgent“ veikia fone ir išlieka pasiekiamas.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent visiškai išsijungia.';

  @override
  String get settingsPhoneTriggers => 'Telefono paleidikliai';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signalai, kuriuos šis telefonas siunčia jūsų agentams, kad užduotys galėtų į juos reaguoti.';

  @override
  String get settingsLocationTriggers => 'Vietos aktyvikliai';

  @override
  String get settingsLocationTriggersDescription =>
      'Kas kelias minutes tikrina jūsų apytikslę vietą, palyginti su vietomis, kurias stebi jūsų užduotys.';

  @override
  String get settingsNotificationTriggers => 'Pranešimų aktyvikliai';

  @override
  String get settingsNotificationTriggersDescription =>
      'Persiunčia pranešimus iš kitų šio telefono programų agentams.';

  @override
  String get settingsSetup => 'Sąranka';

  @override
  String get settingsOnboarding => 'Prisijungimas';

  @override
  String get settingsOnboardingDescription =>
      'Dar kartą atlikite pirmojo paleidimo sąranką. Niekas, kurį nustatėte, neprarasta.';

  @override
  String get settingsUsernameDescription =>
      'Naudota prisijungti. Jo pakeisti negalima.';

  @override
  String get settingsExport => 'Eksportuoti';

  @override
  String get settingsLeave => 'Atsijunkite ir ištrinkite';

  @override
  String get settingsSignOutDescription => 'Atsijungia tik šiame įrenginyje.';

  @override
  String get settingsDeleteAccountDescription =>
      'Ištrina paskyrą, agentus, atmintį ir nustatymus. To negalima anuliuoti.';

  @override
  String get settingsTokenUsage => 'Žetonų naudojimas';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Nė vienas nustatymas neatitinka „$query“.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rezultatų',
      few: '$count rezultatai',
      one: '$count rezultatas',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Išplėstiniai modelio nustatymai';

  @override
  String get settingsAdvancedModelsDescription =>
      'Neprivaloma. Prisegti modelį prie vienos rūšies darbo; ji perima, kai agentas naudoja tuos įrankius. Viskas, kas palikta pagal numatytuosius nustatymus, atitinka pokalbių modelį.';

  @override
  String get settingsTaskModelDefault => 'Numatytoji';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Vadovaujasi pokalbių modeliu';

  @override
  String get settingsTaskModelCoding => 'Kodavimas';

  @override
  String get settingsTaskModelCodingDescription =>
      'Kodo rašymas, redagavimas ir derinimas.';

  @override
  String get settingsTaskModelComputerUse => 'Kompiuterio naudojimas';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Naršyklės ir darbalaukio valdymas.';

  @override
  String get settingsTaskModelAndroidUse => 'Android naudojimas';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Programų valdymas „Android“ įrenginyje arba emuliatoriuje.';

  @override
  String get settingsTaskModelResearch => 'Tyrimas';

  @override
  String get settingsTaskModelResearchDescription =>
      'Šaltinių paieška, skaitymas ir apibendrinimas.';

  @override
  String get knowledgeGraphHint =>
      'Jūsų dažniausiai minimi subjektai, nuspalvinti pagal grupes. Linijos jungia objektus, kurie atsiranda tuose pačiuose prisiminimuose. Bakstelėkite vieną, kad pamatytumėte jo nuorodas ir prisiminimus; vilkite, kad pastumtumėte, suimkite arba Ctrl / ⌘ - slinkite, kad padidintumėte.';

  @override
  String get linkedEntities => 'Susieti subjektai';

  @override
  String get noLinkedEntities => 'Dar nesusietas su kitais subjektais.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 mini';
  }

  @override
  String get entityKindConcept => 'Koncepcija';

  @override
  String get entityKindDomain => 'Domenas';

  @override
  String get entityKindEmail => 'El. paštas';

  @override
  String get entityKindLink => 'Nuoroda';

  @override
  String get entityKindFile => 'Failas';

  @override
  String get entityKindAcronym => 'Akronimas';

  @override
  String get entityKindIdentifier => 'Identifikatorius';

  @override
  String get entityKindVersion => 'Versija';

  @override
  String get openFullscreen => 'Atidaryti per visą ekraną';

  @override
  String get zoomIn => 'Priartinti';

  @override
  String get zoomOut => 'Nutolinti';

  @override
  String get searchEntities => 'Raskite subjektą';

  @override
  String get incomingCall => 'Įeinantis skambutis';

  @override
  String get answerCall => 'Atsakymas';

  @override
  String get callMeLater => 'Paskambink man vėliau';

  @override
  String get callingEllipsis => 'Skambina…';

  @override
  String get reconnectingCall => 'Prisijungiama iš naujo';

  @override
  String get agentWorking => 'Darbas';

  @override
  String get micMuted => 'Nutildyta';

  @override
  String get speakerphone => 'Pranešėjas';

  @override
  String get muteMic => 'Nutildyti';

  @override
  String get unmuteMic => 'Įjungti garsą';

  @override
  String get releaseToSend => 'Atleiskite siųsti';

  @override
  String get callEnded => 'Skambutis baigtas';

  @override
  String get openConversation => 'Atidaryti pokalbį';

  @override
  String get callBack => 'Perskambinkite';

  @override
  String get letCallsReachYou => 'Tegul skambučiai jus pasiekia';

  @override
  String get callPermissionsIntro =>
      'Jūsų agentai gali jums paskambinti. Jei norite skambėti kaip telefono skambutis, kai NeoAgent veikia fone arba jūsų telefonas yra užrakintas, jam reikia šių dalykų.';

  @override
  String get showOverOtherApps => 'Rodyti virš kitų programų';

  @override
  String get showOverOtherAppsDetail =>
      'Iškelia skambučių ekraną, kad ir kur būtumėte.';

  @override
  String get fullScreenCalls => 'Skambučiai per visą ekraną';

  @override
  String get fullScreenCallsDetail => 'Skamba virš užrakinimo ekrano.';

  @override
  String get unrestrictedBattery => 'Neribota baterija';

  @override
  String get unrestrictedBatteryDetail =>
      'Palaiko NeoAgent prijungtą, todėl skambučiai sulaukia.';

  @override
  String get permissionAllowed => 'Leidžiama';

  @override
  String get triggerSectionCalendar => 'Kalendorius';

  @override
  String get triggerSectionFiles => 'Failai ir dokumentai';

  @override
  String get triggerSectionHome => 'Namai ir žiniasklaida';

  @override
  String get triggerSectionDevices => 'Prietaisai ir vietos';

  @override
  String get triggerSectionTasks => 'Užduotys';

  @override
  String get messagingMemberJoined => 'Narys prisijungė';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Paleiskite, kai kas nors prisijungia prie „Discord“ serverio, „Telegram“ ar „WhatsApp“ grupės, „Slack“ kanalo ar „Matrix“ kambario.';

  @override
  String get messagingMemberLeft => 'Narys išėjo';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Paleiskite, kai kas nors palieka „Discord“ serverį, „Telegram“ ar „WhatsApp“ grupę, „Slack“ kanalą ar „Matrix“ kambarį.';

  @override
  String get messagingReactionAdded => 'Pridėta reakcija';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Paleisti, kai leidžiamas asmuo reaguoja į pranešimą privačiame pokalbyje.';

  @override
  String get messagingPlatformDisconnected => 'Susirašinėjimas atjungtas';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Paleiskite, kai pranešimų ryšys nutrūksta ir jums reikia, pvz., atsijungus.';

  @override
  String get googleCalendarEventStarting =>
      '„Google“ kalendoriaus įvykis prasideda';

  @override
  String get googleCalendarEventCreated =>
      'Sukurtas „Google“ kalendoriaus įvykis';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Vykdykite, kai pasirodys naujas įvykis arba kvietimas.';

  @override
  String get outlookCalendarEventStarting =>
      '„Outlook“ kalendoriaus įvykis prasideda';

  @override
  String get nextcloudCalendarEventStarting =>
      '„Nextcloud“ kalendoriaus įvykis prasideda';

  @override
  String get runMinutesBeforeEachEvent =>
      'Prieš kiekvieną įvykį paleiskite nustatytą minučių skaičių.';

  @override
  String get googleDriveFileAdded => 'Pridėtas „Google“ disko failas';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Paleisti, kai failas įtraukiamas į Diską arba jame esantį aplanką.';

  @override
  String get googleSheetsRowAdded => 'Pridėta „Google“ skaičiuoklių eilutė';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Vykdyti, kai lape atsiranda naujų eilučių.';

  @override
  String get onedriveFileAdded => 'Pridėtas OneDrive failas';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Vykdyti, kai failas įtraukiamas į OneDrive aplanką.';

  @override
  String get nextcloudFileAdded => 'Pridėtas Nextcloud failas';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Vykdyti, kai failas įtraukiamas į Nextcloud aplanką.';

  @override
  String get nextcloudShareReceived =>
      '„Nextcloud“ failas bendrinamas su jumis';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Paleiskite, kai kas nors bendrina failą ar aplanką su jumis.';

  @override
  String get notionItemAdded => 'Pridėtas sąvokų duomenų bazės elementas';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Vykdyti, kai elementas įtraukiamas į Notion duomenų bazę.';

  @override
  String get notionItemUpdated => 'Sąvokų duomenų bazės elementas atnaujintas';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Vykdyti, kai pasikeičia elementas Notion duomenų bazėje.';

  @override
  String get trelloCardEnteredList => 'Trello kortelė įtraukta į sąrašą';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Vykdyti, kai kortelė sukuriama arba perkeliama į sąrašą.';

  @override
  String get figmaCommentAdded => 'Pridėtas Figma komentaras';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Paleisti, kai kas nors komentuoja Figma failą.';

  @override
  String get githubPrOpened => 'Atidaryta „GitHub“ ištraukimo užklausa';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Vykdyti, kai saugykloje atidaroma nauja ištraukimo užklausa.';

  @override
  String get githubWorkflowRunFailed => 'Nepavyko vykdyti „GitHub“ darbo eigos';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Vykdykite, kai nepavyksta paleisti „GitHub Actions“.';

  @override
  String get githubCommitPushed => '„GitHub“ įsipareigojimas nustumtas';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Vykdykite, kai nauji įsipareigojimai pasiekia šaką.';

  @override
  String get mcpServerFailed => 'MCP serveris nepavyko';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Paleiskite, kai veikiantis MCP serveris sugenda arba reikia prisijungti.';

  @override
  String get homeAssistantStateChanged => 'Pasikeitė namų asistento būsena';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Vykdyti, kai objektas pasikeičia, pasiekia būseną arba kerta vertę.';

  @override
  String get spotifyTrackChanged => 'Spotify takelis pakeistas';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Paleiskite, kai pradeda groti kitas takelis.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecall dienos suvestinė paruošta';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Vykdykite, kai dienos santrauka yra galutinė.';

  @override
  String get neorecallConversationRecorded => 'NeoRecall pokalbis įrašytas';

  @override
  String get runWhenARecordedConversationEnds =>
      'Paleiskite, kai baigiasi įrašytas pokalbis.';

  @override
  String get geofenceTrigger => 'Vietos geotvora';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Bėkite, kai telefonas atkeliauja į vietą arba išvažiuoja iš jos. Reikia telefono buvimo vietos sekimo.';

  @override
  String get healthMetricRecorded => 'Užregistruota sveikatos metrika';

  @override
  String get runWhenAHealthReadingArrives =>
      'Paleisti, kai gaunamas sinchronizuotas būklės rodmuo, pasirinktinai virš arba mažesnis už vertę.';

  @override
  String get wearableConnectionChanged =>
      'Nešiojamas prijungtas arba atjungtas';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Paleiskite, kai nešiojamasis prietaisas prisijungia arba atsijungia.';

  @override
  String get taskRunFinished => 'Dar viena užduotis baigta';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Vykdykite, kai kita užduotis bus baigta, sėkminga arba nepavykusi.';

  @override
  String get appPackageOptional => 'Programų paketas (neprivaloma)';

  @override
  String get appPackageHelper => 'Pavyzdžiui, com.whatsapp';

  @override
  String get anyPlatform => 'Bet kokia platforma';

  @override
  String get spaceIdOptional =>
      'Serverio, grupės, kanalo arba patalpos ID (neprivaloma)';

  @override
  String get spaceIdHelper => 'Tušti laikrodžiai, kuriuose yra robotas.';

  @override
  String get emojiOptional => 'Jaustukai (neprivaloma)';

  @override
  String get chatIdOptional => 'Pokalbio ID (neprivaloma)';

  @override
  String get platformOptional => 'Platforma (neprivaloma)';

  @override
  String get platformOptionalHelper =>
      'Pavyzdžiui, whatsapp. Tušti visi laikrodžiai.';

  @override
  String get minutesBefore => 'Minutės prieš';

  @override
  String get calendarIdOptional => 'Kalendoriaus ID (pasirenkama)';

  @override
  String get calendarIdHelper => 'Tuščias naudoja pagrindinį kalendorių.';

  @override
  String get invitesOnly => 'Tik kvietimai iš kitų';

  @override
  String get nextcloudCalendarPath => 'Kalendorius';

  @override
  String get nextcloudCalendarPathHelper =>
      'Jos pavadinimas Nextcloud kalendorių sąraše, pavyzdžiui, asmeninis';

  @override
  String get folderIdOptionalHelperDrive => 'Tušti laikrodžiai visame Diske.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Empty stebi šakninį aplanką.';

  @override
  String get driveFolderIdOptional => 'Aplanko ID (neprivaloma)';

  @override
  String get spreadsheetId => 'Skaičiuoklės ID';

  @override
  String get sheetRange => 'Diapazonas';

  @override
  String get sheetRangeHelper => 'Lentelės stulpeliai, pvz., Sheet1!A:E';

  @override
  String get folderPathOptional => 'Aplanko kelias (neprivaloma)';

  @override
  String get folderPathHelper => 'Pavyzdžiui, dokumentai';

  @override
  String get notionDatabaseId => 'Duomenų bazės ID';

  @override
  String get trelloListId => 'Sąrašo ID';

  @override
  String get figmaFileKey => 'Failo raktas';

  @override
  String get figmaFileKeyHelper => 'Iš failo nuorodos: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Saugykla';

  @override
  String get workflowOptional => 'Darbo eiga (neprivaloma)';

  @override
  String get workflowHelper => 'Failo pavadinimas, pvz., ci.yml';

  @override
  String get branchOptional => 'Filialas (neprivaloma)';

  @override
  String get branchHelper => 'Empty naudoja numatytąją šaką.';

  @override
  String get mcpServerIdOptional => 'MCP serverio ID (neprivaloma)';

  @override
  String get entityId => 'Subjekto ID';

  @override
  String get entityIdHelper => 'Pavyzdžiui, binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Tikslinė būsena (neprivaloma)';

  @override
  String get targetStateHelper => 'Pavyzdžiui, ant';

  @override
  String get aboveOptional => 'Aukščiau (neprivaloma)';

  @override
  String get belowOptional => 'Žemiau (neprivaloma)';

  @override
  String get placeName => 'Vietos pavadinimas';

  @override
  String get latitude => 'Platuma';

  @override
  String get longitude => 'Ilguma';

  @override
  String get radiusMeters => 'Spindulys metrais';

  @override
  String get geofenceTransition => 'Kada';

  @override
  String get arriving => 'Atvyksta';

  @override
  String get leaving => 'Išvykimas';

  @override
  String get healthMetric => 'Sveikatos metrika';

  @override
  String get healthMetricHelper => 'Pavyzdžiui, pulsas, žingsniai, svoris';

  @override
  String get wearableTransition => 'Kai nešiojamas';

  @override
  String get wearableConnects => 'Jungiasi';

  @override
  String get wearableDisconnects => 'Atsijungia';

  @override
  String get sourceTask => 'Po užduoties';

  @override
  String get taskOutcome => 'Rezultatas';

  @override
  String get anyOutcome => 'Bet koks rezultatas';

  @override
  String get succeeded => 'Pavyko';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return 'Trūksta $arg1 arba jis negalioja.';
  }

  @override
  String get triggerSectionMessaging => 'Susirašinėjimas žinutėmis';

  @override
  String get triggerSectionDeveloper => 'Kūrėjas';

  @override
  String get triggerSectionMemory => 'Atmintis';

  @override
  String get triggerSectionNews => 'Naujienos';

  @override
  String get triggerSectionSystem => 'Sistema';

  @override
  String get searchTriggersHint => 'Paieškos aktyvikliai, programos ar įvykiai';

  @override
  String get noTriggersMatch => 'Joks aktyviklis neatitinka jūsų paieškos.';

  @override
  String get triggerAccountMissing => 'Dar nėra paskyros';

  @override
  String get pickTriggerKeyboardHint => 'Enter pasirenka pirmąjį rezultatą';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 paleidikliai';
  }

  @override
  String get addFromSkillsSh => 'Pridėti iš įgūdžių.sh';

  @override
  String get skillsShHint =>
      'Ieškokite aukščiau, kad rastumėte įgūdžių adresu skill.sh, arba įklijuokite skill.sh nuorodą arba komandą „npx skills add“.';

  @override
  String get noSkillsShMatches =>
      'Jokių įgūdžių.sh įgūdžių neatitinka šios paieškos.';

  @override
  String get installingSkill => 'Diegiama…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Įdiegtas $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 įdiegimas';
  }

  @override
  String get authVerify => 'Patvirtinti';

  @override
  String get authCreateAccount => 'Sukurti paskyrą';

  @override
  String get authNewInviteLink => 'Nauja kvietimo nuoroda';

  @override
  String get authShowPassword => 'Rodyti slaptažodį';

  @override
  String get authHidePassword => 'Slėpti slaptažodį';

  @override
  String get authPasswordWillBeRejected => 'per silpnas, bus atmestas';

  @override
  String get authUsernameTooShort =>
      'Vartotojo vardus turi sudaryti bent 3 simboliai.';

  @override
  String get authUsernameTaken => 'Šis vartotojo vardas jau užimtas.';

  @override
  String get authSignupsClosed =>
      'Registracija šiame serveryje uždaryta. Paprašykite administratoriaus paskyros.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Šis serveris priima tik prisijungimus per HTTPS. Vietoj to atidarykite $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Šis serveris priima tik prisijungimus per HTTPS. Prisijunkite prie jo naudodami https:// adresą.';

  @override
  String get authAccountNotFound => 'Tos paskyros nebėra.';

  @override
  String get authQrRateLimited =>
      'Per daug QR prisijungimo užklausų. Šiek tiek palaukite, tada atnaujinkite kodą.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Pamiršote slaptažodį? Paprašykite savo serverio administratoriaus jį iš naujo nustatyti skiltyje Administratorius → Vartotojai.';

  @override
  String get authChangeServer => 'Keisti serverį';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Prisijungimas prie $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Šis adresas neatsako kaip „NeoAgent“ serveris. Patikrinkite URL ir bandykite dar kartą.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Nepavyko atidaryti saugaus (HTTPS) ryšio su $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Nepavyko pasiekti $arg1 per HTTPS, o paprastas HTTP taip pat neatsakė. Patikrinkite adresą ir prievadą.';
  }

  @override
  String get adminResetPassword => 'Iš naujo nustatyti slaptažodį';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Iš naujo nustatykite $arg1 slaptažodį';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Pasirinkite naują $arg1 slaptažodį. Jie bus atjungti kiekviename įrenginyje ir vėl prisijungs naudodami šį slaptažodį.';
  }

  @override
  String get adminNewPassword => 'Naujas slaptažodis';

  @override
  String get adminSetPassword => 'Nustatyti slaptažodį';

  @override
  String get authMissingFields => 'Užpildykite kiekvieną privalomą lauką.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 iš naujo nustatė $arg2 slaptažodį';
  }

  @override
  String get adminPasswordUpdated =>
      'Slaptažodis atnaujintas; vartotojas buvo atjungtas visur.';

  @override
  String get authSignInTitle => 'Prisijunkite prie „NeoAgent“.';

  @override
  String get authSignInSubtitle =>
      'Nuskaitykite telefonu arba naudokite slaptažodį.';

  @override
  String get authOrUsePassword => 'arba naudokite savo slaptažodį';

  @override
  String get qrLoginWaitingTitle => 'Patvirtinkite savo telefone';

  @override
  String get qrLoginWaitingBody =>
      'Jūsų telefonas nuskaitė kodą. Patvirtinkite prisijungimą, kad užbaigtumėte prisijungimą.';

  @override
  String get qrLoginSigningInOn => 'Prisijungimas';

  @override
  String get qrLoginLocation => 'Vieta';

  @override
  String get qrLoginWaitingForApproval => 'Laukiama patvirtinimo';

  @override
  String get qrLoginCancelAndUsePassword => 'Atšaukti ir naudoti slaptažodį';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Prisijungimas buvo atmestas jūsų telefone. Nuskaitykite naują kodą ir bandykite dar kartą.';

  @override
  String get signupKey => 'Registracijos raktas';

  @override
  String get signupKeyStepSubtitle =>
      'Naujoms paskyroms šiame serveryje reikia registracijos rakto. Įveskite raktą, kurį gavote iš administratoriaus.';

  @override
  String get signupKeyChange => 'Keisti';

  @override
  String get signupKeyRequiredError => 'Įveskite savo registracijos raktą.';

  @override
  String get signupKeyInvalidError =>
      'Šis registracijos raktas negalioja. Patikrinkite jį ir bandykite dar kartą.';

  @override
  String get signupKeyUsedError =>
      'Šis registracijos raktas jau panaudotas. Paprašykite administratoriaus naujo.';

  @override
  String get adminRequireSignupKey => 'Reikalauti registracijos rakto';

  @override
  String get adminRequireSignupKeyHint =>
      'Naujoms paskyroms reikia vienkartinio administratoriaus rakto. Išjungus, užsiregistruoti gali bet kas, pasiekiantis šį serverį. Pirmajai paskyrai raktas niekada nereikalingas.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Naujoms paskyroms dabar reikia registracijos rakto.';

  @override
  String get adminSignupOpenNotice => 'Dabar užsiregistruoti gali bet kas.';

  @override
  String get signupKeys => 'Registracijos raktai';

  @override
  String get signupKeysDescription =>
      'Vienkartiniai raktai registracijai, kol raktas yra privalomas. Kiekvienas raktas sukuria lygiai vieną paskyrą.';

  @override
  String get signupKeysNew => 'Nauji raktai';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Nepanaudoti · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Panaudoti · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Atšaukti · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Visi · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Nepanaudotas';

  @override
  String get signupKeyStatusUsed => 'Panaudotas';

  @override
  String get signupKeyStatusRevoked => 'Atšauktas';

  @override
  String get signupKeysExport => 'Eksportuoti .txt';

  @override
  String get signupKeysCopied => 'Raktai nukopijuoti';

  @override
  String get signupKeyCopied => 'Raktas nukopijuotas';

  @override
  String get signupKeysEmpty => 'Šiame sąraše raktų nėra.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Sukurtas $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Panaudojo $arg1, $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Panaudotas $arg1 paskyros, kuri vėliau ištrinta';
  }

  @override
  String get signupKeyRevokeTitle => 'Atšaukti šį raktą?';

  @override
  String get signupKeyRevokeMessage =>
      'Niekas nebegalės juo užsiregistruoti. Šio veiksmo anuliuoti negalima.';

  @override
  String get signupKeyRevoked => 'Raktas atšauktas.';

  @override
  String signupKeysShowMore(int count) {
    return 'Rodyti dar $count';
  }

  @override
  String get signupKeysCreateTitle => 'Kurti registracijos raktus';

  @override
  String get signupKeysCount => 'Raktų skaičius';

  @override
  String get signupKeysCountHelper => 'Nuo 1 iki 500';

  @override
  String get signupKeysCountInvalid => 'Įveskite skaičių nuo 1 iki 500.';

  @override
  String get signupKeysLabel => 'Etiketė (neprivaloma)';

  @override
  String get signupKeysLabelHint => 'pvz., pavasario beta testuotojai';

  @override
  String signupKeysCreateAction(int count) {
    return 'Kurti ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Paruošta raktų: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Kiekvieną raktą duokite tik vienam asmeniui. Nepanaudoti raktai lieka sąraše, todėl vėliau galėsite juos vėl nukopijuoti ar eksportuoti.';

  @override
  String get signupKeysSaveDialogTitle => 'Išsaugoti registracijos raktus';

  @override
  String get signupKeysExported => 'Raktai eksportuoti.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor sukūrė registracijos raktų ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor atšaukė registracijos raktą';
  }

  @override
  String get providerChooseUsername => 'Pasirinkite naudotojo vardą';

  @override
  String get providerChooseUsernameBody =>
      'Pasirinkite laisvą naudotojo vardą, kad užbaigtumėte paskyros kūrimą.';

  @override
  String get dataSharingTitle => 'Bendrinti naudojimo duomenis';

  @override
  String get dataSharingDescription =>
      'Padėkite šio serverio prižiūrėtojams jį tobulinti. Bendrinama, kaip naudojate NeoAgent, bet niekada ne tai, ką rašote ar saugote.';

  @override
  String dataSharingSince(String date) {
    return 'Bendrinama nuo $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Kas bendrinama';

  @override
  String get dataSharingIncluded => 'Bendrinama';

  @override
  String get dataSharingExcluded => 'Niekada nebendrinama';

  @override
  String get dataSharingIncludedDevice =>
      'Įrenginio tipas ir programėlės versija';

  @override
  String get dataSharingIncludedLocale =>
      'Programėlės kalba ir laiko juostos regionas, pvz., Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Kokias funkcijas esate nustatę, pvz., užduotis, įgūdžius ir integracijas';

  @override
  String get dataSharingIncludedRuns =>
      'Kokius įrankius ir modelius naudoja jūsų vykdymai, su trukme ir žetonų skaičiumi';

  @override
  String get dataSharingIncludedActivity =>
      'Kada naudojate NeoAgent, pagal savaitės dieną ir valandą';

  @override
  String get dataSharingExcludedContent => 'Žinutės, užklausos ir atsakymai';

  @override
  String get dataSharingExcludedRuns =>
      'Vykdymų pavadinimai, įrankių įvestys ir rezultatai';

  @override
  String get dataSharingExcludedFiles =>
      'Failai, prisiminimai ir visa kita, ką saugote';

  @override
  String get dataSharingExcludedIdentity =>
      'Jūsų vardas, el. paštas, IP adresas ir vieta';

  @override
  String get dataSharingExcludedAccounts =>
      'Paskyros, su kuriomis jungiate integracijas';

  @override
  String get dataSharingPooledNote =>
      'Administratoriai mato tik visų bendrinančiųjų sumas, niekada jūsų atskirai. Išjunkite bet kada ir iškart dingsite iš sumų.';

  @override
  String get dataSharingConfirmTitle => 'Bendrinti naudojimo duomenis?';

  @override
  String get dataSharingConfirmAction => 'Bendrinti';

  @override
  String get sharedUsageTitle => 'Bendrinamas naudojimas';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Naudojimo duomenis bendrinančios paskyros: $sharing iš $total. Tik sumos, jokio turinio.';
  }

  @override
  String get sharedUsageEmpty =>
      'Dar niekas nebendrina naudojimo duomenų. Įjungti galima čia: Nustatymai, Profilis, Jūsų duomenys.';

  @override
  String get sharedUsageRuns => 'Bendrinami vykdymai';

  @override
  String get sharedUsageAvgDuration => 'Vid. trukmė';

  @override
  String get sharedUsageCompletedRuns => 'Užbaigti vykdymai';

  @override
  String get sharedUsageStepsPerRun => 'Žingsniai per vykdymą';

  @override
  String get sharedUsageDevices => 'Įrenginiai';

  @override
  String get sharedUsageAppVersions => 'Programėlės versijos';

  @override
  String get sharedUsageLanguages => 'Kalbos';

  @override
  String get sharedUsageRegions => 'Regionai';

  @override
  String get sharedUsageFeatures => 'Funkcijų naudojimas';

  @override
  String get sharedUsageFeaturesDescription =>
      'Bendrinančių paskyrų dalis, kuri ją nustatė.';

  @override
  String get sharedUsageTools => 'Įrankiai';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Dažniausiai kviečiami įrankiai ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Kvietimai: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Nepavyko: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integracijos';

  @override
  String get sharedUsageMessaging => 'Žinučių kanalai';

  @override
  String get sharedUsageTriggers => 'Kaip prasideda vykdymai';

  @override
  String get sharedUsageActivity => 'Kada naudojama';

  @override
  String get sharedUsageActivityDescription =>
      'Vykdymai pagal savaitės dieną ir valandą, UTC.';

  @override
  String get sharedUsageModels => 'Modelių našumas';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'vid. $latency · $cached % iš talpyklos · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Paskyros: $count';
  }

  @override
  String get sharedUsageNoData => 'Šiuo laikotarpiu nieko nėra.';

  @override
  String get sharedUsageNotReported => 'Dar nepranešta';

  @override
  String get sharedUsageFeatureAgents => 'Daugiau nei vienas agentas';

  @override
  String get sharedUsageFeatureTasks => 'Suplanuotos užduotys';

  @override
  String get sharedUsageFeatureSkills => 'Įgūdžiai';

  @override
  String get sharedUsageFeatureMcp => 'MCP serveriai';

  @override
  String get sharedUsageFeatureIntegrations => 'Integracijos';

  @override
  String get sharedUsageFeatureMessaging => 'Žinučių kanalai';

  @override
  String get sharedUsageFeatureMemory => 'Atmintis';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in duomenų bendrinimas telemetrija įrenginiai funkcijos įrankiai modeliai veikla';

  @override
  String get yourOAuthApp => 'Jūsų OAuth programa';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Jūsų $provider OAuth programa';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Šiame serveryje nėra visuotinės $provider programos, todėl jungiatės naudodami patys užregistruotą OAuth programą. Kliento paslaptis saugoma užšifruota ir daugiau niekada nerodoma.';
  }

  @override
  String get oauthAppStepCreate => '1. Sukurkite programą';

  @override
  String get openDeveloperConsole => 'Atidaryti kūrėjų konsolę';

  @override
  String get oauthAppStepCallback =>
      '2. Užregistruokite šį atgalinio iškvietimo URL';

  @override
  String get callbackUrlCopied => 'Atgalinio iškvietimo URL nukopijuotas';

  @override
  String get oauthAppScopes => 'Leistinos aprėptys';

  @override
  String get scopesCopied => 'Aprėptys nukopijuotos';

  @override
  String get oauthAppStepCredentials =>
      '3. Įklijuokite programos prisijungimo duomenis';

  @override
  String get couldNotSaveOAuthApp => 'Nepavyko išsaugoti OAuth programos.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Pašalinti jūsų $provider programą?';
  }

  @override
  String get removeOAuthAppBody =>
      'Prijungtos paskyros lieka sąraše, bet nustoja veikti, kol vėl pridėsite programą.';

  @override
  String get globalIntegrationConfiguration =>
      'Visuotinė integracijų konfigūracija';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Pasirenkamos viso serverio OAuth programos. Kai integracija tokią turi, ją naudoja kiekviena paskyra ir negali pridėti savos. Palikite integraciją nenustatytą ir kiekvienas naudotojas nustatys savo programą. Paslaptys tik įrašomos: palikite tuščią, kad išliktų išsaugota reikšmė.';

  @override
  String get globalStatus => 'Visuotinė';

  @override
  String get perUserStatus => 'Kiekvienam naudotojui';

  @override
  String get phoneSyncGuidance =>
      'Bendrinkite šio telefono kalendorius ir kontaktus su agentu. Veikia su visomis telefone jau esančiomis paskyromis.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Atidarykite NeoAgent telefone ir ten įjunkite bendrinimą. Agentas matys visų to telefono paskyrų kalendorius ir kontaktus.';

  @override
  String get manageOnThisPhone => 'Tvarkyti šiame telefone';

  @override
  String get setUpOnThisPhone => 'Nustatyti šiame telefone';

  @override
  String get setUpOnPhone => 'Nustatyti telefone';

  @override
  String emailConnectedArg1(String email) {
    return 'Prijungta $email';
  }

  @override
  String get couldNotConnectEmail => 'Nepavyko prijungti paskyros.';

  @override
  String get emailSetupTitle => 'Prijungti el. paštą ir kalendorių';

  @override
  String get emailChecking => 'Tikrinama pašto dėžutė…';

  @override
  String get emailSetupIntro =>
      'Naudokite programėlės slaptažodį iš el. pašto paslaugų teikėjo. Be kūrėjų konsolės, paruošta per kelias minutes.';

  @override
  String emailOpenArg1(String provider) {
    return 'Atidaryti $provider';
  }

  @override
  String get emailStepServers => '1. Įveskite serverius';

  @override
  String get emailStepPassword => '1. Sukurkite programėlės slaptažodį';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Atidaryti $provider programėlių slaptažodžius';
  }

  @override
  String get emailStepSignIn => '2. Prisijungimas';

  @override
  String get appPassword => 'Programėlės slaptažodis';

  @override
  String get appPasswordHelper =>
      'Tarpai nesvarbūs. NeoAgent jį saugo užšifruotą.';

  @override
  String get emailUsernameOptional =>
      'Naudotojo vardas, jei tai ne jūsų el. paštas';

  @override
  String get emailIncludeCalendar => 'Įtraukti kalendorių';

  @override
  String get emailIncludeContacts => 'Įtraukti kontaktus';

  @override
  String get imapServer => 'IMAP serveris';

  @override
  String get smtpServer => 'SMTP serveris';

  @override
  String get caldavUrlOptional => 'CalDAV URL (nebūtina)';

  @override
  String get carddavUrlOptional => 'CardDAV URL (nebūtina)';

  @override
  String get alternativeEmail =>
      'Prijunkite pašto dėžutę programėlės slaptažodžiu arba kalendorių jo iCal nuoroda. Paruošta per kelias minutes.';

  @override
  String get alternativePhone =>
      'Bendrinkite telefone jau esantį kalendorių ir kontaktus per NeoAgent programėlę.';

  @override
  String get alternativePhoneElsewhere =>
      'Bendrinkite telefone jau esantį kalendorių ir kontaktus. Nustatykite tai NeoAgent programėlėje telefone.';

  @override
  String get skipTheDeveloperConsole => 'Be kūrėjų konsolės';

  @override
  String get phoneSyncPromptTitle => 'Leisti agentui matyti jūsų kalendorių?';

  @override
  String get phoneSyncPromptBody =>
      'Bendrinkite šio telefono kalendorius ir kontaktus, kad agentas galėtų planuoti pagal jūsų dieną. Pakeisti galite bet kada skiltyje Įrankiai › Integracijos.';

  @override
  String get phoneSyncTitle => 'Bendrinti telefono kalendorių ir kontaktus';

  @override
  String get phoneSyncIntro =>
      'Agentas mato visų šio telefono paskyrų kalendorius ir kontaktus. Be kūrėjų konsolės ir papildomo prisijungimo.';

  @override
  String get phoneSyncPointAccounts =>
      'Veikia su šio telefono Google, Outlook, iCloud ir Exchange paskyromis.';

  @override
  String get phoneSyncPointPrivate =>
      'Bendrinama tik su jūsų NeoAgent serveriu, kuris juos saugo užšifruotus.';

  @override
  String get phoneSyncPointWrites =>
      'Agento pridėtus įvykius sukuria šis telefonas, ir jie sinchronizuojami kaip įprasta.';

  @override
  String get phoneSyncCalendarHint =>
      'Įvykiai nuo 30 dienų atgal iki 90 dienų į priekį';

  @override
  String get phoneSyncContacts => 'Kontaktai';

  @override
  String get phoneSyncContactsHint =>
      'Vardai, el. pašto adresai ir telefono numeriai';

  @override
  String get phoneSyncOtherAgent =>
      'Šis telefonas bendrina su kitu agentu. Bendrinant čia jis perkeliamas šiam agentui.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent dar neturi prieigos. Leiskite ją nustatymuose ir grįžkite.';

  @override
  String get openPhoneSettings => 'Atidaryti nustatymus';

  @override
  String get phoneSyncShare => 'Bendrinti su NeoAgent';

  @override
  String get phoneSyncStop => 'Nebendrinti';

  @override
  String get phoneSyncWaiting => 'Laukiama pirmojo sinchronizavimo…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Paskutinį kartą sinchronizuota $time';
  }

  @override
  String get calendarLink => 'Kalendoriaus nuoroda';

  @override
  String get calendarLinkHelper =>
      'Kalendoriaus iCal adresas. Kas jį turi, gali skaityti kalendorių, todėl laikykite jį privačiu.';

  @override
  String get calendarLinkName => 'Pavadinimas (nebūtina)';

  @override
  String get calendarLinkAdded => 'Kalendorius pridėtas';

  @override
  String get toolsApps => 'Programos';

  @override
  String get reconnect => 'Prijungti iš naujo';

  @override
  String get reconnectNeeded => 'Reikia prijungti iš naujo';

  @override
  String get mixedAccess => 'Mišri prieiga';

  @override
  String disconnectAccountTitle(String account) {
    return 'Atjungti $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agentas per šią paskyrą praras prieigą prie $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Prijunkite savo NeoRouter vieną kartą ir kiekviena paskyra čia naudos jį toliau įjungtiems darbams.';

  @override
  String get neoRouterUserDescription =>
      'Toliau įjungtiems darbams naudokite savo NeoRouter paskyrą vietoj šio serverio teikėjų.';

  @override
  String get neoRouterAddress => 'NeoRouter adresas';

  @override
  String get neoRouterConnect => 'Prijungti NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Patvirtinkite NeoAgent NeoRouter. Jis rodo kodą $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Atidaryti dar kartą';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Prisijungta prie $arg1';
  }

  @override
  String get neoRouterUnreachable => 'NeoRouter šiuo metu nepasiekiamas.';

  @override
  String get neoRouterDisconnect => 'Atjungti';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent nustoja naudoti šį NeoRouter. Norėdami atšaukti ir raktą, atšaukite jį NeoRouter skiltyje API raktai.';

  @override
  String neoRouterServerInUseArg1(Object? arg1) {
    return 'Šis serveris jau naudoja NeoRouter adresu $arg1. Prijunkite ten savo paskyrą, kad turėtumėte savo modelius ir biudžetą.';
  }

  @override
  String get neoRouterConnected => 'NeoRouter prijungtas.';

  @override
  String get neoRouterRoleChat => 'Pokalbiai ir vaizdų atpažinimas';

  @override
  String get neoRouterRoleSystemOne => 'System One sprendimai';

  @override
  String get neoRouterRoleTranscription => 'Kalba į tekstą';

  @override
  String get neoRouterRoleLive => 'Tiesioginis balsas';

  @override
  String get neoRouterRoleEmbeddings => 'Paieška atmintyje';

  @override
  String get neoRouterRoleImages => 'Vaizdų kūrimas';

  @override
  String get neoRouterRoleSearch => 'Paieška internete';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'Jūsų NeoRouter pasiekiama: $arg1';
  }

  @override
  String get neoRouterNoModels => 'Jūsų NeoRouter dar nieko nėra.';
}
