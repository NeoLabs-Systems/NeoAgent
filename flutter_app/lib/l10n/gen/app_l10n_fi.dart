// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppL10nFi extends AppL10n {
  AppL10nFi([String locale = 'fi']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Tervetuloa';

  @override
  String get onboardingEyebrowCommunication => 'Viestintä';

  @override
  String get onboardingEyebrowIntelligence => 'Älykkyys';

  @override
  String get onboardingEyebrowComputer => 'Tietokone';

  @override
  String get onboardingEyebrowAutomation => 'Automaatio';

  @override
  String get onboardingNext => 'Seuraavaksi';

  @override
  String get onboardingIntroCouldNotLoad => 'Johdantoa ei voitu ladata.';

  @override
  String get onboardingModelDescription =>
      'Valitse malli, jota NeoAgent käyttää oletuksena, tai anna sen valita automaattisesti.';

  @override
  String get onboardingLoadingModels => 'Ladataan malleja…';

  @override
  String get noAiModelTitle => 'Tekoälymallia ei ole vielä asetettu';

  @override
  String get noAiModelBody =>
      'Lisää API-avain palveluntarjoajalta, kuten OpenAI, Anthropic tai Google. NeoAgent näyttää sitten mallit, joita voit käyttää.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent tarvitsee tekoälymallin vastatakseen. Lisää API-avain palveluntarjoajalta, kuten OpenAI, Anthropic tai Google.';

  @override
  String get noAiModelAdminHint =>
      'Järjestelmänvalvojana voit myös määrittää palveluntarjoajia kaikille kohdassa Järjestelmänvalvoja → Palveluntarjoajat.';

  @override
  String get addApiKey => 'Lisää API-avain';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform on kytketty.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Odotetaan, että $platform muodostaa yhteyden…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Asennusta ei voitu tallentaa: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Valmis';

  @override
  String get onboardingStepRequired => 'Pakollinen';

  @override
  String get onboardingStepOptional => 'Valinnainen';

  @override
  String get onboardingStepCloudOrLocal => 'Pilvi tai paikallinen';

  @override
  String get onboardingStepComputer => 'Tietokone';

  @override
  String get onboardingStepRoutines => 'Rutiinit';

  @override
  String get onboardingComputerChoiceTitle => 'Missä sen\npitäisi toimia?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Voit vaihtaa istunnon aikana.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Yksityinen hiekkalaatikko · aina päällä';

  @override
  String get onboardingThisComputer => 'Tämä tietokone';

  @override
  String get onboardingThisComputerSubtitle =>
      'Tiedostosi, sovelluksesi ja selaimesi';

  @override
  String get onboardingSearchApps => 'Hae sovelluksia…';

  @override
  String get onboardingRoutinesDescription => 'Tulokset saapuvat chateihisi.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Tulokset saapuvat ilmoituksina.';

  @override
  String get onboardingNotifications => 'Ilmoitukset';

  @override
  String get onboardingReadyTitle => 'Kaikki on\nvalmista.';

  @override
  String get onboardingReadyDescription => 'Lähetä ensimmäinen viestisi.';

  @override
  String get onboardingMessageNeoagent => 'Viesti NeoAgent';

  @override
  String get onboardingAskAnything => 'Kysy mitä tahansa…';

  @override
  String get onboardingOpenNeoagent => 'Avaa NeoAgent';

  @override
  String get onboardingStarterTrip => 'Suunnittele viikonloppumatka';

  @override
  String get onboardingStarterLanding => 'Rakenna aloitussivu';

  @override
  String onboardingQuickSteps(int count) {
    return '$count nopeat askeleet';
  }

  @override
  String get taskNeedsEmail => 'Yhdistä sähköposti ensin';

  @override
  String get taskNeedsCalendar => 'Yhdistä ensin kalenteri';

  @override
  String get taskNeedsModel => 'Määritä ensin AI-malli';

  @override
  String get taskPromptDailyRecap =>
      'Kertaa päivääni: tee yhteenveto tämän päivän keskusteluista, valmiista töistä ja päätöksistä ja lue sitten kaikki, mitä minun pitäisi seurata huomenna. Pidä se lyhyt ja lähetä se minulle.';

  @override
  String get taskPromptInboxCheck =>
      'Tarkista sähköpostilaatikostani viestit, jotka ovat saapuneet edellisen tarkistuksen jälkeen. Lähetä minulle viestiä vain kiireellisistä tai vastauksen vaativista sähköposteista. Jokaisella on yksirivinen yhteenveto. Jos mikään ei vaadi huomiotani, älä lähetä mitään.';

  @override
  String get taskPromptMorningBriefing =>
      'Valmistele aamun tiedotustilaisuus: tämän päivän sää missä olen, kalenterissani olevat tapahtumat ja tärkeimmät avoimet asiat, joista tiedän. Lähetä se lyhyenä, skannattavana viestinä.';

  @override
  String get taskPromptTomorrowPrep =>
      'Katso kalenteriani huomiselle. Kerro jokaisessa tapaamisessa, mistä siinä on kyse, kuka on mukana ja mitä minun pitäisi valmistautua. Jos huominen on tyhjä, älä lähetä mitään.';

  @override
  String get taskPromptNewsDigest =>
      'Hae verkosta päivän tärkeimpiä uutisia minulle tärkeistä aiheista (käytä mitä muistat kiinnostuksen kohteistani). Lähetä minulle enintään viiden kohteen tiivistelmä, joissa kussakin on yksi lause ja linkki.';

  @override
  String get taskPromptWeeklyReview =>
      'Kertokaa viikkoni: mitä saatiin tehtyä, mikä lipsahti ja mikä on vielä auki. Ehdota kolme tärkeintä asiaa, joihin keskittyä ensi viikolla.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Linkitä edustajalle kuuluva puhelinnumero. Kaikki sallimasi voivat keskustella sen kanssa suorissa chateissa ja ryhmissä.';

  @override
  String get whatsappSelfChatDescription =>
      'Linkitä oma numerosi ja keskustele agentin kanssa \"Viesti itse\" -chatissa. Kaikki muut tämän tilin keskustelut ja ryhmät ohitetaan.';

  @override
  String get chatSendHintMac => '⌘↵ lähettää';

  @override
  String get chatSendHintOther => 'Ctrl+Enter lähettääksesi';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Tälle päätepisteelle vaaditaan perus-URL-osoite.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Vaihtunut sähköpostiosoite vahvistetaan ennen sen käyttöä.';

  @override
  String get aDecisionHigherUpTheChain => 'Päätös ketjun yläpuolella voittaa.';

  @override
  String get aDeletedAccount => 'poistettu tili';

  @override
  String get aFridayLookBackAtThe =>
      'Perjantaina katsaus viikkoon ja suunnitelma seuraavalle.';

  @override
  String get aKeyThatAsksForA =>
      'Avain, joka pyytää PIN-koodia tai sormenjälkeä, korvaa myös kaksivaiheisen koodisi.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Kielimalli arvioi tämän viestin, koska SystemOne on pois päältä.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'NeoAgent-asetusten metatietotiedosto ylitti turvallisen kokorajan.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Palvelimella on saatavilla uudempi verkkoversio. Lataa uusin paketti uudelleen.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Yksityinen työpöytä, jossa on Chromium, tiedostot, tekstieditori, pääte ja Python. Työsi säilyvät tallessa istuntojen välillä.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Yksityinen Linux-tietokone tai Android-laite.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Vaadittua NeoAgent-asennustiedostoa ei voitu ladata.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Joukkuekaveri lähettää sinulle kutsulinkin. Kun hyväksyt sen, he ';

  @override
  String get aTeammateSentYouAnInvite =>
      'joukkuetoveri lähetti sinulle kutsulinkin, kirjoita se tähän liittyäksesi heidän tiimiinsä.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Väliaikainen lataus siivotaan myöhemmin.';

  @override
  String get aValueIsStored => 'Arvo tallennetaan.';

  @override
  String get access => 'Pääsy';

  @override
  String get accessActivity => 'Pääsytoimintaan';

  @override
  String accessArg1(Object? arg1) {
    return 'Käyttöoikeus: $arg1';
  }

  @override
  String get accessMode => 'Pääsytila';

  @override
  String get accessPermissions => 'Käyttöoikeudet';

  @override
  String get accessToken => 'pääsytunnus';

  @override
  String get accessToken2 => 'Käyttöoikeustunnus';

  @override
  String get account => 'Tili';

  @override
  String accountArg1(Object? arg1) {
    return 'Tili #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Tilin muutosilmoitukset';

  @override
  String get accountEmail => 'Tilin sähköpostiosoite';

  @override
  String get accountEmailIsOffUntilThese =>
      'Tilin sähköposti on pois päältä, kunnes nämä on asetettu: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent käyttää tätä kieltä kaikkialla sovelluksessa. Kun kirjaudut sisään ensimmäisen kerran, se seuraa tätä laitetta. Tämän jälkeen valinta tallennetaan tilillesi ja sitä käytetään kaikilla laitteilla.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Kieltä ei voitu vaihtaa: $error';
  }

  @override
  String get accountLanguageTitle => 'Kieli';

  @override
  String get accountNumber => 'Tilinumero';

  @override
  String get accountSettings => 'Tilin asetukset';

  @override
  String get accounts => 'Tilit';

  @override
  String get accountsByTokensUsedAllTime =>
      'Tilit käytettyjen tunnuksien mukaan, koko ajan.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'tilien pilvitietokoneet. Muutokset tulevat voimaan palvelimen jälkeen ';

  @override
  String get accountsOnThisServer => 'Tilit tällä palvelimella';

  @override
  String get active => 'Aktiivinen';

  @override
  String get activeSessions => 'Aktiiviset istunnot';

  @override
  String get activeToday => 'Aktiivinen tänään';

  @override
  String get add => 'Lisää';

  @override
  String get addAProviderCredentialFirstIts =>
      'Lisää ensin palveluntarjoajan tunnistetiedot. Sen mallit näkyvät täällä kerran ';

  @override
  String get addAgent => 'Lisää agentti';

  @override
  String get addAnotherSignInMethodBefore =>
      'Lisää toinen kirjautumistapa ennen tämän poistamista.';

  @override
  String get addBinding => 'Lisää sidonta';

  @override
  String get addByNameOrId => 'Lisää nimen tai tunnuksen mukaan';

  @override
  String get addByNameOrIdInstead => 'Lisää sen sijaan nimellä tai tunnuksella';

  @override
  String get addCredentialBinding => 'Lisää valtuustietojen sidonta';

  @override
  String get addEntry => 'Lisää merkintä';

  @override
  String get addKey => 'Lisää avain';

  @override
  String get addMcpServer => 'Lisää MCP-palvelin';

  @override
  String get addMemory => 'Lisää muistia';

  @override
  String get memoryReview => 'Tarkista';

  @override
  String get memoryReviewPrompt =>
      'Käy läpi kaikki muistoni ja siivoa ne: arkistoi kaksoiskappaleet, vanhentuneet tiedot ja kaikki, millä ei ole pysyvää arvoa. Kerro sitten lyhyesti, mitä muutit.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Lisää pituutta tai muuta merkkityyppiä.';

  @override
  String get addPeopleOrGroups => 'Lisää ihmisiä tai ryhmiä';

  @override
  String get addSecurityKey => 'Lisää suojausavain';

  @override
  String get addSomeoneOrAGroup => 'Lisää joku tai ryhmä';

  @override
  String get addTask => 'Lisää tehtävä';

  @override
  String get addTests => 'Lisää testejä';

  @override
  String get addTestsForThePartsOf =>
      'Lisää testejä tämän projektin osille, joilla on vähiten kattavuus, ja suorita ne sitten.';

  @override
  String get addTheirOwnKeysInSettings => 'lisää omat avaimensa asetuksissa.';

  @override
  String get addToPrompt => 'Lisää kehotteeseen';

  @override
  String get added => 'Lisätty';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Lisätty $arg1 · Viimeksi käytetty $arg2';
  }

  @override
  String get addressWithTheProvider => 'osoite palveluntarjoajan kanssa.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Säädä kaiuttimen äänenvoimakkuutta, tarkista laitteistopainikkeiden oletusasetukset ja hallitse tätä käynnistysistuntoa.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Säädä haku- tai tilasuodatinta nähdäksesi lisää viestikanavia.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Säädä kaiuttimen äänenvoimakkuutta tästä.';

  @override
  String get admin => 'Admin';

  @override
  String adminArg1(Object? arg1) {
    return 'Järjestelmänvalvoja › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Järjestelmänvalvojan apurahat, kutsulinkit ja hallintamuutokset näkyvät täällä.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Edistynyt manuaalinen aikataulu erikoistapauksia varten.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Lisäasetukset: minuutti tunti päivä kuukausi arkipäivä.';

  @override
  String get againRightAway => 'heti uudestaan.';

  @override
  String get agent => 'Agentti';

  @override
  String agentArg1(Object? arg1) {
    return 'Agentti: $arg1';
  }

  @override
  String get agentCalls => 'Agentti soittaa';

  @override
  String get agentCommunication => 'Agenttiviestintä';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Agenttiviestintä: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Agenttitila muokkaa työtilaa · ⌘↵ lähetä · ⌘N uutta istuntoa';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Agentti pysähtyy ja pyytää lupaasi ennen suoritusta.';

  @override
  String get agentProfile => 'Agentin profiili';

  @override
  String get agentVisibleName => 'Agentille näkyvä nimi';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Agentti haluaa käyttää $arg1:tä. Päätä napauttamalla.';
  }

  @override
  String get agents => 'Agentit';

  @override
  String get aiAnswerUnreadable => 'AI vastaus lukematon';

  @override
  String get aiProviderKeys => 'AI-palveluntarjoajan avaimet';

  @override
  String get aiUnavailable => 'AI ei ole käytettävissä';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'hälytykset ja muut tilin sähköpostit osoitteesta.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Hälyttää, kun viestiyhteys tarvitsee käyttäjän huomiota';

  @override
  String get all => 'Kaikki';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Kaikki edustajat ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Kaikki $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Kaikki pilvitietokoneiden paikat ovat tällä hetkellä käytössä. Yritä hetken kuluttua uudelleen.';

  @override
  String get allComputerSlotsAreBusy => 'Kaikki tietokonepaikat ovat varattuja';

  @override
  String get allTables => 'Kaikki pöydät';

  @override
  String get allTime => 'Koko ajan';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Kaikki työkalut ovat sallittuja - agentti voi käyttää mitä tahansa kykyä kysymättä. ';

  @override
  String get allow => 'Salli';

  @override
  String get allowedRunsWithoutAsking => 'Sallittu. Juoksee kysymättä.';

  @override
  String get allowAll => 'Salli kaikki';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Salli \"Asenna tuntemattomat sovellukset\" NeoAgentille ja yritä sitten päivitystä uudelleen.';

  @override
  String get allowOnce => 'Salli kerran';

  @override
  String get allowSender => 'Salli lähettäjä';

  @override
  String get allowSession => 'Salli istunto';

  @override
  String get allowTheAgentToStartAn =>
      'Salli agentin aloittaa sovelluksen sisäinen äänipuhelu kanssasi.';

  @override
  String get allowedOrigins => 'Sallitut alkuperät';

  @override
  String get allowedPathPrefix => 'Sallittu polun etuliite';

  @override
  String get allowsYouCanChangeThatPer =>
      'sallii. Voit muuttaa sen henkilökohtaisesti myöhemmin. Linkit eivät koskaan myönnä ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'kuuluu jo olemassa olevaan tiliin';

  @override
  String get alreadyLinkedToAnotherAccount => 'linkitetty jo toiseen tiliin';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'on jo linkitetty toiseen neoagent-tiliin';

  @override
  String get alreadyUsed => 'jo käytetty';

  @override
  String get always => 'Aina';

  @override
  String get alwaysAllow => 'Salli aina';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Salli aina\" tallentaa käytännön pysyvästi – voit muuttaa sitä asetuksissa.';

  @override
  String get alwaysAsk => 'Kysy aina';

  @override
  String get alwaysEngage => 'Ota aina yhteyttä';

  @override
  String get alwaysJoins => 'Aina mukana';

  @override
  String get anApiKeyIsRequired => 'API-avain vaaditaan.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Iltainen yhteenveto tapahtuneesta ja jatkotoimista.';

  @override
  String get anHttpOrHttpsUrlIs => 'http- tai https-URL vaaditaan.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'ja analytiikka. Joukkueen linkit näkyvät Team-sivulla.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Android APK -asennus ei ole saatavilla tälle alustalle.';

  @override
  String get androidApp => 'Android-sovellus';

  @override
  String get androidControl => 'Android-ohjaus';

  @override
  String get androidCouldNotStart => 'Android ei voinut käynnistyä';

  @override
  String get androidNotificationReceived => 'Android-ilmoitus vastaanotettu';

  @override
  String get androidOnly => 'vain Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Android-paketin asennusohjelmaa ei voitu avata.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Android-näyttö — kosketa napauttamalla, pyyhkäise vetämällä';

  @override
  String get androidSdk => 'Android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Vastaukset @maininnat ongelmiin ja vetopyyntöihin';

  @override
  String get anyone => 'Kuka tahansa';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Kuka tahansa tällä alustalla voi lähettää viestin $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Kuka tahansa tällä alustalla voi lähettää viestin $arg1:lle $arg2:ssä.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Jokainen tämän tilin saavuttava voi puhua $arg1:lle.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Kuka tahansa linkin saanut voi liittyä, kunnes se vanhenee tai peruutat sen.';

  @override
  String get apiHttpsOrigin => 'API HTTPS-alkuperä';

  @override
  String get apiKey => 'API-avain';

  @override
  String get apiKey2 => 'api-avain';

  @override
  String get apiKey3 => 'API-avain';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'api key anthropic claude openai gpt xai grok google gemini minimax nvidia nim openrouter valtuustiedot';

  @override
  String get apiKeysAndEndpointsForAi =>
      'API-avaimet ja päätepisteet tekoäly-, haku- ja puhepalveluntarjoajille. He ';

  @override
  String get apiRequest => 'API-pyyntö';

  @override
  String get apiYourOwnServerASelf =>
      'API – oma palvelin, itseisännöity malli tai jokin muu ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'APK:n lataus epäonnistui HTTP $arg1:n kanssa.';
  }

  @override
  String get appNameIsRequired => 'Sovelluksen nimi vaaditaan.';

  @override
  String get appUpdates => 'Sovelluspäivitykset';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Sovelluspäivityksiä ei ole määritetty tälle koontiversiolle.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Otettiin käyttöön $arg1-jonossa olevat ohjauspäivitykset nykyiseen ajoon.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Käytetty $arg1-ohjauspäivitykset.';
  }

  @override
  String get apply => 'Käytä';

  @override
  String get applyBehaviorNotes => 'Käytä huomautuksia käyttäytymisestä';

  @override
  String get applyCoreMemory => 'Käytä ydinmuistia';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Arkaluontoisten agenttityökalujen hyväksyntäpyynnöt';

  @override
  String get approvalRequired => 'Hyväksyntä vaaditaan';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Hyväksyntä pysyy todetun mobiiliistunnon sisällä, ja jokainen koodi vanhenee automaattisesti lyhyen ajan kuluttua.';

  @override
  String get approveLogin => 'Hyväksy kirjautuminen';

  @override
  String get approveQrLogin => 'Hyväksy QR-kirjautuminen';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Hyväksy tämä vain, jos aloitit kirjautumisen kyseisellä laitteella juuri nyt.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Hyväksytty kirjautuminen $arg1:lle.';
  }

  @override
  String get approvedOnly => 'Vain hyväksytty';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Hyväksytty pariliitos mallille $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Hyväksytyt ihmiset ja ryhmät';

  @override
  String get approvedPeopleOnly => 'Vain hyväksytyt ihmiset';

  @override
  String get archive => 'Arkisto';

  @override
  String get archiveAgent => 'Arkiston agentti?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arkisto ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arkistoi $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arkistoidaanko valitut muistot?';

  @override
  String get areSharedByEveryAccountOn =>
      'ovat kaikkien tämän palvelimen tilien jakamia; tilit voivat silti ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M sisääntulo';
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
    return '$arg1 pääsy vaaditaan';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return '$arg1 tilit';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 aktiivinen';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 lisätty. Muokkaa sitä milloin tahansa muuttaaksesi ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '\"$arg1\" ja sen ajohistoria poistetaan pysyvästi. Kaikki aktiivinen ajo pysäytetään. Työtilassa oleviin tiedostoihin ei kosketa.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return '$arg1-hyväksyntä vaaditaan';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return '$arg1-sovellukset käytössä';
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
    return '$arg1 (aktiiviset $arg2-työkalut)';
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
    return '$arg1 $arg2 osoitteessa $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 vaihdettu';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 merkkiä';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Luotu $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [paikallinen uri: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 vastaa \"$arg3\"';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}NeoAgent-työtila';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 uusia tilejä';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 kulkee · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 näytteet';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 ohjaus jonossa';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2-merkit';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return '$arg1 / $arg2 rahakkeita';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 osoitteessa $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1:stä tuli järjestelmänvalvoja ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 tavua';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 kanava';
  }

  @override
  String arg1Chars(Object? arg1) {
    return '$arg1 merkit';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 tyhjennetty.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 määritetty';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 kytketty. Valitse arkistot ja ihmiset kohdasta Kuka voi lähettää viestin.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return '$arg1 ydinmerkinnät.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 loi kutsulinkin';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return '$arg1 pöytäkone';
  }

  @override
  String arg1Events(Object? arg1) {
    return '$arg1 -tapahtumat';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 epäonnistui';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 epäonnistui';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 epäonnistuu';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 mallille $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return '$arg1 ryhmät, jotka on merkitty vain';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h sitten';
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
    return '$arg1 apulaiset';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '($arg1 osumasuhde)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 on järjestelmänvalvoja, joten tiliä ei voi poistaa ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 on estetty mallissa $arg2. Päivitä käyttöoikeusluettelo salliaksesi vastaukset.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 on yhdistetty ja vastaa.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 ei ole enää järjestelmänvalvoja ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 ei ole saatavilla mallille $arg2 (puuttuu suoritusaikalupa tai riippuvuus).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 liittyi $arg2:n alle';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 arvosteli LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 avain$arg2 määritetty';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return '$arg1 avain poistettu.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 jäljellä';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 vasen $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 linkitetty';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m sitten';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Varmista, että se on käynnissä, ja yritä sitten uudelleen.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 hallinnoi tätä tiliä';
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
    return '$arg1 mallit valmiina';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 lisää';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 lisää vaiheita ajohistoriassa';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 siirretty $arg2:stä ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1:n on oltava äärellinen luku.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1:n on oltava http://- tai https://-osoite.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 vaatii huomiota';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/NeoAgent-työtila';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 uusia tilejä edellisessä $arg2:ssä.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · uudet viestit ohjaavat tätä ajoa';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 uusia ajoja';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 hallinnoi nyt tätä tiliä.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 / 4 lupaa sallittu. Tiedostot on rajoitettu NeoAgent Workspace -kansioosi.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1/$arg2 käytössä';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 $arg2-ryhmistä liittyy tavalliseen chattiin';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 $arg2-malleista';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 $arg2-malleista valmiina';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 $arg2-sarjasta';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 ja $arg2 työkalut sallittu';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 päivänä $arg2 klo $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 vastaa vain alle lisäämillesi ihmisille.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 vastaa vain tunnisteella';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 puhuu vain hyväksymillesi ihmisille ja ryhmille';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'Lisätty $arg1 ihmisiä tai ryhmiä';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 suunnittelu';
  }

  @override
  String arg1Providers(Object? arg1) {
    return '$arg1-palveluntarjoajat';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 valmiina';
  }

  @override
  String arg1Records(Object? arg1) {
    return '$arg1-tietueita';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1-uudelleenohjaus-URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 rekisteröity';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 vastasi';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 peruutti kutsulinkin';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 toimii';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 toimii · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 toimii viimeisessä $arg2:ssä.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 tallennettu.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 sek';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 valittu';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Kuvassa $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 pysyi hiljaa';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 ohjaus $arg2 jonossa';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 vaihe$arg2 · napauta solmua tarkastaaksesi';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 portaat';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 lopetti $arg2:n hallinnan';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return '$arg1-merkit';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1-merkit viimeisessä $arg2:ssä.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return '$arg1 työkalut';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (ei käytettävissä tallennettu ohitus)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1 % käytetty · $arg2 jäljellä';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 haluaa puhua kanssasi.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 verkko';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" poistetaan pysyvästi.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 hallinnoi tätä tiliä';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 ei vastaa tällä alustalla';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 ei vastaa viestiin $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Artefaktien tallennus käyttäjän toimesta';

  @override
  String get askAQuestionOrStartA => 'Esitä kysymys tai aloita tehtävä...';

  @override
  String get askBeforeClosingToBackground => 'Kysy ennen taustan sulkemista';

  @override
  String get askMe => 'Kysy minulta';

  @override
  String get assignedAgent => 'Määrätty agentti';

  @override
  String get assignedAgent2 => 'Määrätty agentti';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Määrätty agentti: $arg1';
  }

  @override
  String get assigneeOptional => 'Valtuutettu (valinnainen)';

  @override
  String get assistant => 'Assistant';

  @override
  String get assistantKey131 => 'Avustajan avain 131';

  @override
  String get atLeast1 => 'Ainakin 1.';

  @override
  String get attachFiles => 'Liitä tiedostot';

  @override
  String attentionArg1(Object? arg1) {
    return 'Huomio $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'tarkastusloki järjestelmänvalvoja myöntää peruuttaa kutsun tiimihistoria';

  @override
  String get authMethod => 'Todennusmenetelmä';

  @override
  String get authServerUrl => 'Auth-palvelimen URL-osoite';

  @override
  String get authentication => 'Todennus';

  @override
  String get authenticationFailed => 'Todennus epäonnistui.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Todennus on vielä kesken. Viimeistele selaimen kulku ja yritä uudelleen.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Todennus on vielä kesken. Viimeistele selaimen kulku ja päivitä.';

  @override
  String get authenticationTimedOut => 'Todennus aikakatkaistiin.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Todennus peruutettiin ennen valmistumista.';

  @override
  String get authenticatorApp => 'Authenticator-sovellus';

  @override
  String get authenticatorCode => 'Authenticator-koodi';

  @override
  String get authorOptional => 'Tekijä (valinnainen)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automaattinen (ensimmäinen tarjoaja API-avaimella)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Automaattinen reititys parhaaseen saatavilla olevaan malliin';

  @override
  String get automaticFast => 'Automaattinen (nopea)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automaattinen lukee huoneen ja normaalisti pidättelee. Vain mainitseminen ei tee päätöskutsua ennen kuin siihen on suoraan osoitettu.';

  @override
  String get automaticReserved => 'Automaattinen, varattu';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Automaattinen palautus vaatii uudelleenyrityksen asetusnäytöstä.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automaattinen valitsee nopean mallin normaalin malliluettelon kautta.';

  @override
  String get automation => 'Automaatio';

  @override
  String get available => 'Saatavilla';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Saatavana jälleen mallissa $arg1';
  }

  @override
  String get availableAgainShortly => 'Saatavilla taas pian';

  @override
  String get availableInTheDesktopAppFor =>
      'Saatavilla macOS-, Windows- ja Linux-työpöytäsovelluksessa';

  @override
  String get availableToTheAgent => 'Edustajan käytettävissä';

  @override
  String get averageAllTime => 'Keskimääräinen, koko ajan';

  @override
  String get avgImp => 'Keskim. imp.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Keskim./ajo: $arg1-merkit';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Vältä toistuvia merkkejä ja ilmeisiä sarjoja.';

  @override
  String get awaitingScan => 'Odottaa skannausta';

  @override
  String get back => 'Takaisin';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count taustalla';
  }

  @override
  String get backgroundTasks => 'Taustatehtävät';

  @override
  String get backOn => 'takaisin päälle.';

  @override
  String get backToChat => 'Takaisin chattiin';

  @override
  String get backToFolder => 'Takaisin kansioon';

  @override
  String get backToSignIn => 'Takaisin kirjautumaan sisään';

  @override
  String get backendChannel => 'Taustakanava';

  @override
  String get backendOnThisComputer => 'Tämän tietokoneen taustaohjelma';

  @override
  String get backendSync => 'Taustasynkronointi';

  @override
  String get backgroundLocationNeeded => 'Taustasijainti tarvitaan';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Taustasynkronointi pysyy ajoitettuna Androidissa';

  @override
  String get badState => 'Huono tila: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Käytettävissä olevien QEMU-virtuaalikoneiden peruskuva ja koko ';

  @override
  String get baseUrlOptional => 'Perus-URL (valinnainen)';

  @override
  String get baseUrlTokenLocal => 'paikallinen perus-url-tunnus';

  @override
  String get basicAuthentication => 'Perustodennus';

  @override
  String get behaviorModules => 'Käyttäytymismoduulit';

  @override
  String get behaviorNotes => 'huomautuksia käyttäytymisestä';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker =>
      'Bitwardenin valtuustietojen välittäjä';

  @override
  String get bitwardenItem => 'Bitwarden-tuote';

  @override
  String get bitwardenServer => 'Bitwarden-palvelin';

  @override
  String get blankUsesCommon => 'Tyhjä käyttää \"yleistä\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Tyhjä käyttää oletusarvoista takaisinsoittoa';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Tyhjät arvot käyttävät palveluntarjoajan oletusasetuksia.';

  @override
  String get block => 'Estä';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Estetty saapuva viesti käyttäjältä $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'BlueBubbles-yhteensopiva silta';

  @override
  String get bluebubblesServerUrl => 'BlueBubbles-palvelimen URL-osoite';

  @override
  String get botToken => 'Botin tunnus';

  @override
  String get botTokenAndApprovedChats =>
      'Bottitunnus ja hyväksytyt keskustelut';

  @override
  String get botTokenAndServerChannelAccess =>
      'Bottitunnus ja palvelimen/kanavan käyttöoikeus';

  @override
  String get botTokenEventsApiAndChannel =>
      'Bot-tunnus, Events API ja kanavan käyttöoikeus';

  @override
  String get botUserId => 'Botin käyttäjätunnus';

  @override
  String get botUsername => 'Botin käyttäjätunnus';

  @override
  String get brandName => 'Tuotemerkki';

  @override
  String get braveSearch => 'Rohkea haku';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Yhdistä kaikki palveluntarjoajat, jotka voivat lähettää ja vastaanottaa webhook-hyötykuormia.';

  @override
  String get bringYourOwnKey => 'tuo oma avain';

  @override
  String get bringYourOwnKey2 => 'Oma avain mukaan';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Selain, Linux-työpöytä, tiedostot, pääte ja Python jakavat yhden jatkuvan pilvitietokoneen.';

  @override
  String get browserLogin => 'Selaimen kirjautuminen';

  @override
  String get browserScripting => 'Selaimen komentosarjat';

  @override
  String get call => 'Soita';

  @override
  String get callAgent => 'Soita agentille';

  @override
  String get callUser => 'Soita käyttäjälle';

  @override
  String get calledByName => 'Kutsuttiin nimellä';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Voi delegoida tehtäviä muille edustajille';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Voidaan delegoida $arg1:lle';
  }

  @override
  String get canReceiveDelegatedTasks =>
      'Voi vastaanottaa delegoituja tehtäviä';

  @override
  String get cancel => 'Peruuta';

  @override
  String get cancelTask => 'Peruuta tehtävä';

  @override
  String get cannotPreview => 'Ei voi esikatsella';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ei voi vastaanottaa delegoituja tehtäviä';

  @override
  String get cannotRunYet => 'ei voi juosta vielä.';

  @override
  String get capturedThePage => 'Otettiin sivu kiinni';

  @override
  String get category => 'Luokka';

  @override
  String chainArg1(Object? arg1) {
    return 'Ketju: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Muuta asetustilaa';

  @override
  String get channel => 'kanava';

  @override
  String get channelAccessToken => 'Kanavan käyttöoikeustunnus';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Kanava: $arg1$arg2 | Päivitysversio: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Kanavalaajuinen sosiaalinen muisti';

  @override
  String get channels => 'Kanavat';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'Chat-tunnus';

  @override
  String get chatMode => 'Chat-tila';

  @override
  String get chatModel => 'Chat malli';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Tarkista automaattisesti käynnistyksen yhteydessä';

  @override
  String get checkForMessagesEveryMs => 'Tarkista viestit joka (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Tarkista uudet viestit automaattisesti';

  @override
  String get checkNow => 'Tarkista nyt';

  @override
  String get checkYourEmailToConfirmYour =>
      'Tarkista sähköpostisi vahvistaaksesi NeoAgent-tilisi ennen kirjautumista.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Tarkistettu $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Valitse luokka tai hae kaikista asetuksista.';

  @override
  String get chooseAPerson => 'Valitse henkilö';

  @override
  String get chooseAProjectFolder => 'Valitse projektikansio';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Valitse oletusasetukset chatille, agenteille, varakäyttäytymiselle ja älykkäälle reititykselle.';

  @override
  String get chooseGroups => 'Valitse ryhmät';

  @override
  String get chooseHowMuchYouWantTo =>
      'Valitse, kuinka paljon haluat määrittää nyt. Molempia vaihtoehtoja voidaan muuttaa myöhemmin.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Valitse, miten tämän tehtävän pitäisi alkaa. Manuaalinen toimii vain Run Now -tilassa. Aikataulu on aikaperusteinen. Integrointi laukaisee tulen yhdistetyistä virallisista sovelluksista.';

  @override
  String get chooseOneToGetStartedNow =>
      'Aloita valitsemalla yksi. Voit lisätä myöhemmin lisää.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Valitse live-malli ja ääni asetuksista.';

  @override
  String get chooseTheirGroup => 'Valitse heidän ryhmänsä';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Valitse, missä tämän henkilön pitäisi saada puhua $arg1:lle. Voit muuttaa tätä myöhemmin kohdassa Kuka voi lähettää viestin.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Valitse, mihin ryhmiin $arg1 tulee liittyä, vaikka kukaan ei merkitse sitä. Tämä alusta ei välttämättä erota tunnisteita tavallisista viesteistä.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Valitse, mitä malleja jokainen tämän palvelimen tili voi valita ja ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Valitse, kenen kanssa $arg1 puhuu ja milloin se liittyy ryhmäkeskusteluihin.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Valitse, kuka voi tavoittaa $arg1:n, ja tallenna sitten muutokset.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Valitse, kuka voi lähettää viestin agentille WhatsApp-kortissa olevalla \"Kuka voi lähettää viestin\".';

  @override
  String get chooseYourDefaultModel => 'Valitse\noletusmalli.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, tiedostot, tekstieditori ja pääte ovat kaikki saatavilla Linux-työpöydältä.';

  @override
  String get claudeCode => 'Claude Code';

  @override
  String get clear => 'Tyhjennä';

  @override
  String get clearAll => 'Tyhjennä kaikki';

  @override
  String clearArg1(Object? arg1) {
    return 'Tyhjennä $arg1?';
  }

  @override
  String get clearFilter => 'Tyhjennä suodatin';

  @override
  String get clearFilters => 'Selkeät suodattimet';

  @override
  String get clearSearch => 'Tyhjennä haku';

  @override
  String get clearView => 'Selkeä näkymä';

  @override
  String get cliSession => 'CLI-istunto';

  @override
  String get clickIsNotSupportedOnThis =>
      'klikkausta ei tueta tällä alustalla.';

  @override
  String get clickOnceToBeginCapturing =>
      'Aloita kuvaaminen napsauttamalla kerran';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Napsauta, kirjoita ja käytä työpöytäsovelluksia.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Napsautettu kohdassa ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Klikattiin selaimessa';

  @override
  String get clientId => 'Asiakastunnus';

  @override
  String get clientSecret => 'Asiakkaan salaisuus';

  @override
  String get close => 'Sulje';

  @override
  String get closeJ => 'Sulje (⌘J)';

  @override
  String get closeTeachMode => 'Sulje opetustila';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Ikkunan sulkeminen voi joko pitää NeoAgentin käynnissä taustalla käyttämällä lokeroa tai sulkea työpöydän suoritusajan kokonaan.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Pilvi- ja itseisännöityjä esiintymiä tuetaan. Paikallisen ja yksityisen verkon URL-osoitteet toimivat, kun NeoAgent voi tavoittaa ne.';

  @override
  String get cloudComputer => 'Pilvi tietokone';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Pilvitietokone · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Pilvitietokoneen asetukset tallennettu. Käynnistä palvelin uudelleen ottaaksesi ne käyttöön.';

  @override
  String get cloudComputerVm => 'Pilvitietokone (VM)';

  @override
  String get cloudComputers => 'Pilvitietokoneet';

  @override
  String get codeHosting => 'Code Hosting';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Pilkuilla erotetut kanavien nimet ilman #-merkkiä.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Pilkuilla erotettuna, esimerkiksi #yleinen, #apu';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Pilkulla erotettuna. Ongelman täytyy sisältää ne kaikki.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Komento epäonnistui ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Komento vaaditaan.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Komentolähtöakku ei ole aktiivinen.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Komennon lähdön lataus epäonnistui ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Komennon lähdön lataus jätetty pois artefaktin metatiedot.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Komentotulostus oli jo viimeistelty.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Komennot ja sovellukset';

  @override
  String get commandsRunInTheSamePersistent =>
      'Komennot suoritetaan samassa jatkuvassa tietokoneessa, jota näkyvä työpöytä käyttää.';

  @override
  String get communityChatops => 'Yhteisö & ChatOps';

  @override
  String get completeSetup => 'Täydellinen asennus';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Suorita työnkulku loppuun työpöydällä.';

  @override
  String get completed => 'Valmis';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Täysin estetty – agentti ei voi käyttää tätä luokkaa.';

  @override
  String get computerShell => 'Tietokoneen kuori';

  @override
  String get computerUsedByThisSession => 'Tämän istunnon käyttämä tietokone';

  @override
  String get computerWorkspace => 'Tietokoneen työtila';

  @override
  String get configurablePersonalWebhookBridge =>
      'Muokattava henkilökohtainen webhook-silta';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Muokattava rele tai webhook-silta';

  @override
  String get configurableTalkWebhookBridge => 'Muokattava Talk webhook -silta';

  @override
  String get configurableWebInboxBridge =>
      'Muokattava verkkopostilaatikon silta';

  @override
  String get configurableWebhookBridge => 'Muokattava webhook-silta';

  @override
  String get configurableWebhooks => 'Muokattavat Webhookit';

  @override
  String get configurationOrInTheEnvFile => '.env-tiedostossa.';

  @override
  String get configure => 'Määritä';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Määritä työtilan toiminta ja mallin oletusasetukset.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Konfiguroitu $arg1';
  }

  @override
  String get confirmEmailChanges => 'Vahvista sähköpostimuutokset';

  @override
  String get confirmNewSignUps => 'Vahvista uudet ilmoittautumiset';

  @override
  String get confirmPassword => 'Vahvista salasana';

  @override
  String get confirmPassword2 => 'Vahvista salasana';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Vahvista sähköpostiosoitteesi ennen kirjautumista. Tarkista palvelusähköpostiviesti NeoAgentilta.';

  @override
  String get connect => 'Yhdistä';

  @override
  String get connectAMessagingPlatform => 'Yhdistä\nviestintäalusta.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Yhdistä julkinen HTTPS Home Assistant -päätepiste Long-Lived Access Tokenilla. Palvelin estää paikallis-, takaisinkytkentä- ja yksityisverkko-osoitteet.';

  @override
  String get connectAccount => 'Yhdistä tili';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Yhdistä sovellustilit yksitellen, jotta tekoäly voi käyttää oikeaa tiliä jokaisessa virallisessa integraatiossa.';

  @override
  String connectArg1(Object? arg1) {
    return 'Yhdistä $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Yhdistä niin monta tiliä kuin haluat. Jokainen sovellus voi käyttää eri tiliä.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Yhdistä kanavat, valitse kenelle $arg1 puhuu ja katso viimeaikaista toimintaa.';
  }

  @override
  String get connectInstance => 'Yhdistä ilmentymä';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Yhdistä tämä integrointi ensin tilin valitsemiseksi.';

  @override
  String get connectToThisServer => 'Yhdistä tähän palvelimeen';

  @override
  String get connectWhatsapp => 'Yhdistä WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Yhdistä Nextcloud-instanssi, mukaan lukien itseisännöidyt palvelimet. NeoAgent avaa Nextcloudin oman kirjautumissivun, jotta voit kirjautua sisään salasanalla, SSO:lla tai 2FA:lla.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Yhdistä itse isännöity NeoRecall-palvelin. NeoAgent saa vain luku -oikeuden paikallishakuun, muisteihin ja transkriptiotodisteisiin, kun olet hyväksynyt OAuth-näytön.';

  @override
  String get connected => 'Yhdistetty';

  @override
  String get connectedAccount => 'Yhdistetty tili';

  @override
  String connectedArg1(Object? arg1) {
    return 'Kytketty $arg1';
  }

  @override
  String get connectedInstance => 'Yhdistetty ilmentymä';

  @override
  String get connectedNeorecallUser => 'Yhdistetty NeoRecall-käyttäjä';

  @override
  String get connectedNextcloudUser => 'Yhdistetty Nextcloud-käyttäjä';

  @override
  String get connectedServer => 'Yhdistetty palvelin';

  @override
  String get connectingToTheLiveVoiceModel => 'Yhdistetään live-äänimalliin...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Liitäntä #$arg1';
  }

  @override
  String get connectionId => 'Yhteystunnus';

  @override
  String get connectionLooksGood => 'Yhteys näyttää hyvältä.';

  @override
  String get connectionMethod => 'Yhteysmenetelmä';

  @override
  String get containsTextOptional => 'Sisältää tekstiä (valinnainen)';

  @override
  String get content => 'Sisältö';

  @override
  String get contentSecurityPolicy => 'sisällön turvallisuuspolitiikka';

  @override
  String get continue2 => 'Jatka';

  @override
  String get continueFullSetup => 'Jatka täydellistä asennusta';

  @override
  String get continueRun => 'Jatka juoksua';

  @override
  String get continueToSetup => 'Jatka määritykseen';

  @override
  String get controlSurface => 'OHJAUSPINTA';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Ohjaa pääsyä $arg1-työkaluihin.';
  }

  @override
  String get conversation => 'Keskustelu';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Keskustelutunnus, jota käytetään, kun tämä agentti aloittaa keskustelun.';

  @override
  String get cookieSetup => 'Evästeen asetukset';

  @override
  String get cookiesNotConfigured => 'Evästeitä ei ole määritetty';

  @override
  String get copiedAsCsv => 'Kopioitu CSV-muodossa';

  @override
  String get copiedDebugInfo => 'Kopioitu virheenkorjaustiedot';

  @override
  String get copiedExportForTheLast5 =>
      'Kopioitu vienti viidelle viimeiselle viestille';

  @override
  String get copiedFullPrompt => 'Kopioitu koko kehote';

  @override
  String get copiedLogs => 'Kopioitu lokit';

  @override
  String get copiedRunId => 'Kopioitu ajotunnus';

  @override
  String get copy => 'Kopioi';

  @override
  String get copyAll => 'Kopioi kaikki';

  @override
  String get copyCodes => 'Kopioi koodit';

  @override
  String get copyCsv => 'Kopioi CSV';

  @override
  String get copyDebugInfo => 'Kopioi virheenkorjaustiedot';

  @override
  String get copyLink => 'Kopioi linkki';

  @override
  String get copyLogs => 'Kopioi lokit';

  @override
  String get copyPrompt => 'Kopioi kehote';

  @override
  String get copyResponse => 'Kopioi vastaus';

  @override
  String get copyRunId => 'Kopioi ajotunnus';

  @override
  String get copyWebhookUrl => 'Kopioi webhookin URL-osoite';

  @override
  String get core => 'Core';

  @override
  String get coreMemory => 'ydinmuisti';

  @override
  String get coreServicesThisServerDependsOn =>
      'Ydinpalvelut, joista tämä palvelin riippuu.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors-verkkotunnuksen https julkisen URL-osoitteen alkuperä';

  @override
  String get couldHelp => 'Voisi auttaa';

  @override
  String get couldNotApproveQrLogin => 'QR-kirjautumista ei voitu hyväksyä.';

  @override
  String get couldNotApproveQrPairing =>
      'QR-parin muodostamista ei voitu hyväksyä.';

  @override
  String get couldNotConnect => 'Yhteyttä ei voitu muodostaa.';

  @override
  String get couldNotCreateBinding => 'Sidontaa ei voitu luoda.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Tiliäsi ei voitu poistaa: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'Bitwardenia ei voitu katkaista.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Home Assistantin yhteyttä ei voitu katkaista.';

  @override
  String get couldNotDisconnectNeorecall =>
      'NeoRecallin yhteyttä ei voitu katkaista.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Nextcloud-yhteyttä ei voitu katkaista.';

  @override
  String get couldNotDisconnectTrello => 'Trellon yhteyttä ei voitu katkaista.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Tietojasi ei voitu viedä: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Päätöksiä ei voitu ladata';

  @override
  String get couldNotLoadUsageData => 'Käyttötietoja ei voitu ladata.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Linux-asetuksia ei voitu avata automaattisesti.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Palveluntarjoajan linkityssivua ei voitu avata.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Palveluntarjoajan kirjautumissivua ei voitu avata.';

  @override
  String get couldNotOpenTheReleaseAsset => 'Julkaisusisältöä ei voitu avata.';

  @override
  String get couldNotOpenTrelloInYour => 'Trelloa ei voitu avata selaimessasi.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Työtilan tiedoston latausta ei voitu avata.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Android-sovelluspakettia ei voitu lukea.';

  @override
  String get couldNotReadTheApk => 'APK:ta ei voitu lukea.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Avainta ei voitu poistaa: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Edustajaa ei voitu tallentaa.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Bitwarden-asetuksia ei voitu tallentaa.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Home Assistantin asetuksia ei voitu tallentaa.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'NeoRecall-asetuksia ei voitu tallentaa.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Nextcloud-asetuksia ei voitu tallentaa.';

  @override
  String get couldNotSaveTrelloSetup => 'Trellon asennusta ei voitu tallentaa.';

  @override
  String get couldNotSendConfirmationEmail =>
      'vahvistussähköpostin lähettäminen ei onnistunut';

  @override
  String get couldNotStart => 'Ei voitu käynnistää';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Luo';

  @override
  String get createAPasswordFirstToChange =>
      'Luo ensin salasana vaihtaaksesi tilisi sähköpostiosoitteen.';

  @override
  String get createAPasswordOrLinkAnother =>
      'luo salasana tai linkitä toinen palveluntarjoaja ennen tämän kirjautumistavan poistamista';

  @override
  String get createATaskWhileThisAgent =>
      'Luo tehtävä, kun tämä agentti on valittuna.';

  @override
  String get createLink => 'Luo linkki';

  @override
  String get createOrModifyFilesInYour =>
      'Luo tai muokkaa tiedostoja työtilassasi.';

  @override
  String get createPassword => 'Luo salasana';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Luo erikoisbotteja erillisellä muistilla, asetuksilla, työkaluilla ja tilitehtävillä.';

  @override
  String get createTheFirstAccount => 'Luo ensimmäinen tili';

  @override
  String get createUpdateOrDeleteSkills => 'Luo, päivitä tai poista taitoja.';

  @override
  String get creatingYourSkill => 'Luodaan taitojasi…';

  @override
  String get credentialBindings => 'Valtuustietojen sidokset';

  @override
  String get credentialUse => 'Tunnistetietojen käyttö';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Cron-pohjaiset toistuvat ajot ja kerta-ajastettu suoritus.';

  @override
  String get cronExpression => 'Cronin ilme';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter suorittaa kyselyn.';

  @override
  String get ctrlShiftSpace => 'Ctrl + vaihto + välilyönti';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Nykyinen sähköpostiosoite: $arg1';
  }

  @override
  String get currentPassword => 'Nykyinen salasana';

  @override
  String get currentPasswordIsIncorrect => 'nykyinen salasana on väärä';

  @override
  String get currentTwoStepLoginCode =>
      'Nykyinen kaksivaiheinen kirjautumiskoodi';

  @override
  String get customAccess => 'Mukautettu pääsy';

  @override
  String get customCron => 'Mukautettu Cron';

  @override
  String get customCronMustHave5Fields =>
      'Custom Cronissa on oltava 5 kenttää.';

  @override
  String get customEndpoint => 'mukautettu päätepiste';

  @override
  String get customField => 'Mukautettu kenttä';

  @override
  String get customHeader => 'Muokattu otsikko';

  @override
  String get customHeadersJson => 'Muokatut otsikot (JSON)';

  @override
  String get customOpenaiCompatible => 'Mukautettu OpenAI-yhteensopiva';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Mukautettu OpenAI-yhteensopiva päätepiste';

  @override
  String get customOutgoingUrl => 'Muokattu lähtevä URL-osoite';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Päivittäin';

  @override
  String get dailyRecap => 'Päivittäinen yhteenveto';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'tietokantakysely valitse csv-malleja';

  @override
  String dayArg1(Object? arg1) {
    return 'Päivä $arg1';
  }

  @override
  String get dayOfMonth => 'Kuukauden päivä';

  @override
  String get decideWhichToolsYourAgentMay =>
      'päättää, mitä työkaluja edustajasi voi käyttää. He näkevät nimesi ja ';

  @override
  String get decisionHigherUpTheChainWins =>
      'Päätös ylempänä ketju voittaa ja näyttää lukon ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Päätökset näkyvät tässä, kun $arg1 lukee hyväksyttyjä $arg2-ryhmiä. Vain 30 viimeisintä säilytetään, ja ne nollataan, kun palvelin käynnistyy uudelleen.';
  }

  @override
  String get decline => 'Hylkää';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'syväajo · vaihe $arg1';
  }

  @override
  String get deepgramKey => 'Deepgram-avain';

  @override
  String get default2 => 'Oletus';

  @override
  String get default3 => 'OLETUS';

  @override
  String defaultArg1(Object? arg1) {
    return 'Oletus ($arg1)';
  }

  @override
  String get defaultConversation => 'Oletuskeskustelu';

  @override
  String get defaultForNewGroups => 'Oletusarvo uusille ryhmille';

  @override
  String get defaultGroupParticipation =>
      'Oletusarvoinen ryhmän osallistuminen';

  @override
  String get defaultNeoagentWorkspace => 'NeoAgentin oletustyötila';

  @override
  String get defaultOpenai => 'Oletus (OpenAI)';

  @override
  String get defaultRateLimits => 'Oletusnopeusrajat';

  @override
  String get defaultRateLimitsSaved => 'Oletusnopeusrajat tallennettu.';

  @override
  String get defaultRecommended => 'Oletus (suositus)';

  @override
  String get defaultRouting => 'Oletusreititys';

  @override
  String get defaultSpace => 'Oletustila';

  @override
  String get delete => 'Poista';

  @override
  String get deleteAccount => 'Poista tili';

  @override
  String get deleteAccountPermanently => 'Poistetaanko tili pysyvästi?';

  @override
  String get deleteAnAccount => 'Poista tili';

  @override
  String deleteArg1(Object? arg1) {
    return 'Poistetaanko @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Poista ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Poistetaanko $arg1 $arg2 pysyvästi?';
  }

  @override
  String get deleteBinding => 'Poista sidonta';

  @override
  String get deleteCoreMemoryEntry => 'Poistetaanko ydinmuistimerkintä?';

  @override
  String get deleteForever => 'Poista ikuisesti';

  @override
  String get deleteMcpServer => 'Poistetaanko MCP-palvelin?';

  @override
  String get deleteMemory => 'Poistetaanko muisti?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Poista poistaa pysyvästi tilin ja kaikki sen tiedot ';

  @override
  String get deleteRun => 'Poistetaanko juoksu?';

  @override
  String get deleteRun2 => 'Poista ajo';

  @override
  String get deleteSelectedMemories => 'Poistetaanko valitut muistot?';

  @override
  String get deleteSession => 'Poistetaanko istunto?';

  @override
  String get deleteSkill => 'Poistetaanko taito?';

  @override
  String get deleteTask => 'Poistetaanko tehtävä?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Poistettu \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Poistettu @$arg1 ja kaikki heidän tiedot.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Poistaminen poistaa kaikki keskustelusi, muistosi, tiedostosi, tehtäväsi ja ';

  @override
  String get deliverableArtifactProduced =>
      'Toimitettava artefakti valmistettu';

  @override
  String get deliverableCompleted => 'Toimitettava valmiina';

  @override
  String get deliverableExecutionStarted => 'Toimitettava toteutus aloitettu';

  @override
  String get deliverableSelected => 'Toimitettava valittu';

  @override
  String get deliverableValidationFailed =>
      'Toimitettava vahvistus epäonnistui';

  @override
  String get deliverableValidationStarted =>
      'Toimitettavan validointi aloitettu';

  @override
  String get deny => 'Kiellä';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Kuvaile tulos ja näytä se sitten työpöydällä';

  @override
  String get describeWhatToBuildOrChange =>
      'Kuvaile mitä rakentaa tai muuttaa…';

  @override
  String get description => 'Kuvaus';

  @override
  String get desktopApp => 'Työpöytäsovellus';

  @override
  String get desktopAppControlsAvailable =>
      'Työpöytäsovellusten ohjaimet saatavilla';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Työpöytäkaappaus ei ole käytettävissä tällä alustalla.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Työpöytäkomennon lähdön lataus peruutettu.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Työpöydän kumppanikomento peruutettiin.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Työpöytäkumppaniyhteys aikakatkaistiin.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Työpöytäkumppanin kättely aikakatkaistiin.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Työpöytäkumppani ei ole saatavilla täällä.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Työpöytäkumppani on keskeytetty paikallisesti.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Työpöytäkumppaniviestin käsittely epäonnistui: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Työpöytäkumppanin käyttöoikeusasetukset eivät ole käytettävissä verkossa.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Työpöytäkumppanien käyttöoikeusasetukset eivät ole käytettävissä tällä alustalla.';

  @override
  String get desktopCompanionRejected => 'Työpöytäkumppani hylätty.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Työpöytäkumppanin vastaus epäonnistui: $arg1';
  }

  @override
  String get desktopControl => 'Työpöydän ohjaus';

  @override
  String get desktopFailedToStart => 'Työpöytä ei käynnistynyt';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Työpöytävirran sieppaus epäonnistui: $arg1';
  }

  @override
  String get destinationId => 'Kohteen tunnus';

  @override
  String get deviceAccess => 'Laitteen käyttöoikeus';

  @override
  String get deviceSettings => 'Laitteen asetukset';

  @override
  String get devices => 'Laitteet';

  @override
  String get diagnosticsSaved => 'Diagnostiikka tallennettu.';

  @override
  String get directBluebubblesImessageBridge =>
      'Suora BlueBubbles iMessage -silta';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Suorat viestit pysyvät responsiivisina. Sallitut ryhmät käyttävät alla olevaa osallistumistilaa.';

  @override
  String get directoryDoesNotExist => 'Hakemistoa ei ole olemassa.';

  @override
  String get disable2fa => 'Poista 2FA käytöstä';

  @override
  String get disableAll => 'Poista kaikki käytöstä';

  @override
  String get discard => 'Hävitä';

  @override
  String get disconnect => 'Katkaise yhteys';

  @override
  String get disconnectHomeAssistant =>
      'Katkaisetko Home Assistantin yhteyden?';

  @override
  String get disconnectNeorecall => 'Irrota NeoRecallin yhteys?';

  @override
  String get disconnectNextcloud => 'Katkaisetko yhteyden Nextcloudiin?';

  @override
  String get disconnectPlatform => 'Irrota alusta';

  @override
  String get disconnectTrello => 'Katkaisetko Trellon yhteyden?';

  @override
  String get discoveryFailed => 'Löytö epäonnistui';

  @override
  String get dismiss => 'Hylkää';

  @override
  String get displayIdIsRequired => 'Näyttötunnus vaaditaan.';

  @override
  String get displayName => 'Näyttönimi';

  @override
  String get displayNameMustBe64Characters =>
      'Näyttönimessä saa olla enintään 64 merkkiä.';

  @override
  String get displayNameSaved => 'Näyttönimi tallennettu.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Älä kirjoita käyttäjätunnustasi tai sähköpostiosoitettasi.';

  @override
  String get done => 'Valmis';

  @override
  String get downloadACopyOfYourData =>
      'Lataa kopio tiedoistasi. Järjestelmänvalvojan tilejä ei voi poistaa ';

  @override
  String get downloadACopyOfYourData2 =>
      'Lataa kopio tiedoistasi tai poista tilisi pysyvästi. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Lataa $arg1';
  }

  @override
  String get downloadUpdate => 'Lataa päivitys';

  @override
  String get downloadingTheNeoagentBackend =>
      'Ladataan NeoAgent-taustaohjelmaa';

  @override
  String get draft => 'Luonnos';

  @override
  String get dragIsNotSupportedOnThis => 'vetää ei tueta tällä alustalla.';

  @override
  String get draggedOnTheScreen => 'Vedettiin näytöllä';

  @override
  String get dropAnApkOrApkBundle => 'Asenna APK tai APK-paketti tähän';

  @override
  String get dropApkOrApksHere => 'Pudota APK tai .apks tähän';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Kestävät ohjeet äänelle ja vuorovaikutustapalle. Turvallisuus- ja suoritussäännöt ovat edelleen etusijalla.';

  @override
  String get eGAlexSLaptop => 'esim. Alexin kannettava tietokone';

  @override
  String get eGMyLocalServer => 'esim. Oma paikallinen palvelin';

  @override
  String get edit => 'Muokkaa';

  @override
  String get editAgent => 'Muokkaa agenttia';

  @override
  String get editCoreMemoryEntry => 'Muokkaa ydinmuistimerkintää';

  @override
  String get editInstructions => 'Muokkaa ohjeita';

  @override
  String get editMcpServer => 'Muokkaa MCP-palvelinta';

  @override
  String get editTask => 'Muokkaa tehtävää';

  @override
  String editedArg1(Object? arg1) {
    return 'Muokattu $arg1';
  }

  @override
  String get email => 'Sähköposti';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Sähköpostitilin omistajille epätavallisilta näyttävistä kirjautumisista.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Lähetä sähköpostia tilin omistajille, kun heidän tilitietonsa muuttuvat.';

  @override
  String get emailCode => 'Sähköpostikoodi';

  @override
  String get emailConfirmationRequired => 'sähköpostivahvistus vaaditaan';

  @override
  String get emailIsAlreadyInUse => 'sähköposti on jo käytössä';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Sähköposti tallennettu. Jos vahvistus vaaditaan, tarkista uudesta osoitteesta NeoAgent-vahvistuslinkki.';

  @override
  String get emailSettingsSaved => 'Sähköpostiasetukset tallennettu.';

  @override
  String get emailUnverified => 'Sähköposti vahvistamaton';

  @override
  String get empty => 'Tyhjä';

  @override
  String get emptyFile => 'Tyhjä tiedosto';

  @override
  String get emptyFolder => 'Tyhjä kansio';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Tyhjä käyttää palvelimen oletusarvoa ($arg1).';
  }

  @override
  String get enable2fa => 'Ota 2FA käyttöön';

  @override
  String get enableAll => 'Ota kaikki käyttöön';

  @override
  String get enableBehaviorModules => 'Ota käyttäytymismoduulit käyttöön';

  @override
  String get enableOrDisableModels =>
      'Ota mallit käyttöön tai poista ne käytöstä';

  @override
  String get enabled => 'Käytössä';

  @override
  String get encryptedPrivateToYourAccount => 'Salattu, yksityinen tilillesi';

  @override
  String get end => 'Loppu';

  @override
  String get endCall => 'Lopeta puhelu';

  @override
  String get endVoiceCall => 'Lopetetaanko äänipuhelu?';

  @override
  String get endpoint => 'Päätepiste';

  @override
  String get enterAPassword => 'Anna salasana.';

  @override
  String get enterAUsername => 'Anna käyttäjänimi.';

  @override
  String get enterAValidEmailAddress => 'Anna kelvollinen sähköpostiosoite.';

  @override
  String get enterAnAddressManually => 'Anna osoite manuaalisesti';

  @override
  String get enterAnApiKeyFirst => 'Anna ensin API-avain.';

  @override
  String get enterInviteLink => 'Anna kutsulinkki';

  @override
  String get enterTheAddressOfANeoagent => 'Anna NeoAgent-palvelimen osoite.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Anna tiedot, jotka $arg1 antoi sinulle, jotta $arg2 voi lähettää ja vastaanottaa viestejä.';
  }

  @override
  String get enterYour2faOrRecoveryCode => 'Anna 2FA- tai palautuskoodisi.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Anna nykyinen salasanasi vaihtaaksesi sen.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Kirjoita nykyinen salasanasi tallentaaksesi sähköpostimuutokset.';

  @override
  String get enterYourNeoagentAccountDetails => 'Anna NeoAgent-tilisi tiedot.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Anna käyttäjätunnuksesi tai tilisi sähköpostiosoite. NeoAgent lähettää nollauslinkin, jos se vastaa tiliä.';

  @override
  String get enterYourUsernameOrEmail =>
      'Kirjoita käyttäjätunnuksesi tai sähköpostiosoitteesi.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entiteetti: $arg1';
  }

  @override
  String get environment => 'Ympäristö';

  @override
  String get error => 'Virhe';

  @override
  String errorArg1(Object? arg1) {
    return '\nvirhe: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Virheet viimeaikaisesta lokista, ryhmitelty viestin mukaan.';

  @override
  String get errorsProblemsFailures => 'virheet ongelmat epäonnistumiset';

  @override
  String get eventTypesCommaSeparated =>
      'Tapahtumatyypit (pilkuilla erotettuna)';

  @override
  String get every15Minutes => '15 minuutin välein';

  @override
  String get every30Minutes => '30 minuutin välein';

  @override
  String get everyAccountOnThisServerLoses =>
      'Jokainen tämän palvelimen tili menettää tämän jaetun avaimen. Tilit ';

  @override
  String get everyAccountOnThisServerUses =>
      'Jokainen tili tällä palvelimella käyttää tätä osoitetta ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Jokainen tämän tilin aktiivinen istunto päättyy. He voivat kirjautua sisään ';

  @override
  String get everyDay0800 => 'Joka päivä · 08:00';

  @override
  String get everyDay2000 => 'Joka päivä · 20:00';

  @override
  String get everyHour => 'Joka tunti';

  @override
  String get everyRunOnThisServerAll =>
      'Jokainen ajo tällä palvelimella, koko ajan.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Jokainen herkkä työkalu vaatii hyväksynnän joka kerta.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Jokainen työkalu toimii kysymättä, paitsi ne, jotka henkilö ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Kaikki näiden ryhmien, kanavien tai huoneiden jäsenet voivat puhua $arg1:lle.';
  }

  @override
  String get everyoneInThisGroup => 'Kaikki tässä ryhmässä';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Kaikki $arg1, joka on poistettu käytöstä agentiltasi, tulee ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Kaikki muu on kytketty pois päältä.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Kaikki on saatavilla työpöydältä.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Kaikki mitä agentti voi käyttää: viralliset integraatiot, MCP-palvelimet ja taidot.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Kaikki, mitä poistit käytöstä $arg1:lle, tulee takaisin ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Tarkat Web-alkuperät sallivat lähteiden välisten pyyntöjen tekemisen, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Suorita JavaScript selainistunnon sisällä.';

  @override
  String get execution => 'Toteutus';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Tämän ajon suoritustiedot eivät ole saatavilla.';

  @override
  String get executionPlanCreated => 'Toteutussuunnitelma luotu.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Harjoitus $arg1 istunnot';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[poistu $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Vanhenee $arg1';
  }

  @override
  String get explainThisProject => 'Selitä tämä projekti';

  @override
  String exploredArg1(Object? arg1) {
    return 'Tutkittu $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Tutkittu $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Tutkittu työtilaa';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Vienti epäonnistui: $arg1';
  }

  @override
  String get exportLast5Messages => 'Vie 5 viimeistä viestiä';

  @override
  String get exportMyData => 'Vie tietoni';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Ulkoisen selaimen käynnistys epäonnistui poistumiskoodilla $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Ulkoisen selaimen käynnistämistä ei tueta tällä alustalla.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Ulkoisen selaimen käynnistys aikakatkaistiin.';

  @override
  String get externalMcpTools => 'Ulkoiset ja MCP-työkalut';

  @override
  String get extraButtons => 'Lisäpainikkeet';

  @override
  String get extractingTheNeoagentRuntime => 'Puretaan NeoAgent-ajoaika';

  @override
  String get failed => 'Epäonnistui';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Yhteyden muodostaminen epäonnistui: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1:n yhdistäminen epäonnistui: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return '\"$arg1\":n poistaminen epäonnistui: $arg2';
  }

  @override
  String get failedToFetch => 'nouto epäonnistui';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Kehotteen luominen epäonnistui: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Ulkoisen selaimen käynnistäminen url_launcherin kautta epäonnistui.';

  @override
  String get failedToLaunchOauthFlow =>
      'OAuth-virran käynnistäminen epäonnistui.';

  @override
  String get failedToLoadPolicies => 'Käytäntöjen lataaminen epäonnistui';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Tallennus epäonnistui: $arg1';
  }

  @override
  String get failedToSaveMcpServer =>
      'MCP-palvelimen tallentaminen epäonnistui.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Valinnan tallentaminen epäonnistui: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Ilmoituksen lähettäminen taustajärjestelmään epäonnistui: $arg1';
  }

  @override
  String get fair => 'Reilu';

  @override
  String get fasterReplies => 'Nopeampia vastauksia';

  @override
  String get fewerModelCalls => 'Vähemmän mallipuheluita';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'tyhjä kenttä palauttaaksesi sisäänrakennetun oletusarvon.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Tiedosto ylittää 1 MiB editorin rajan.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Tiedosto ylittää tuetun kokorajoituksen.';

  @override
  String get fileWrites => 'Tiedosto kirjoittaa';

  @override
  String get filename => 'Tiedostonimi';

  @override
  String get files => 'Tiedostot';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'NeoAgentin tässä istunnossa kirjoittamat tai muokkaamat tiedostot näkyvät tässä.';

  @override
  String get filesSavedByAllUsers =>
      'Kaikkien käyttäjien tallentamat tiedostot';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Täytä hyväksytyt kirjautumiset tai todenna pyynnöt näyttämättä salaisuuksia tekoälylle.';

  @override
  String get finalResponse => 'Lopullinen vastaus';

  @override
  String get findAPlatform => 'Etsi alusta';

  @override
  String get findAndFixABug => 'Etsi ja korjaa virhe';

  @override
  String get findRecentChats => 'Etsi viimeisimmät keskustelut';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Oikean NeoAgent-ajoajan löytäminen';

  @override
  String get finish => 'Valmis';

  @override
  String get finishAtTheScheduledTime => 'Lopeta sovittuun aikaan';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Viimeistele $arg1-kirjautuminen selaimessasi ja yhdistä sitten uudelleen.';
  }

  @override
  String get flowGraph => 'Virtauskaavio';

  @override
  String get flutterApp => 'Flutter-sovellus';

  @override
  String get focusedExecutionProfile => 'Keskittynyt toteutusprofiili';

  @override
  String get folderIdOptional => 'Kansion tunnus (valinnainen)';

  @override
  String get folderUnavailable => 'Kansio ei ole käytettävissä';

  @override
  String get forExampleHttpsMatrixOrg => 'Esimerkiksi https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Isännöityihin tai edistyneisiin verkkoasetuksiin';

  @override
  String get forLinksInEmailsBlankUses =>
      'Sähköpostissa oleville linkeille. Tyhjä käyttää palvelimen julkista URL-osoitetta.';

  @override
  String get forgotPassword => 'Unohditko salasanan?';

  @override
  String get frameUnavailable => 'Kehys ei ole käytettävissä';

  @override
  String freshnessArg1(Object? arg1) {
    return 'tuoreus: $arg1';
  }

  @override
  String get fridays1700 => 'Perjantaisin · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'BotFatherista botin luomisen jälkeen.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'Tästä eteenpäin $arg1 päättää, mitä työkaluja edustajasi voi käyttää. He ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Discord-kehittäjäportaalista, bottisi alla.';

  @override
  String get fromTheLineDevelopersConsole => 'LINE Developers Consolesta.';

  @override
  String get fromTheMatrixClientOrBot => 'Matrix-asiakas- tai bottitililtä.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Osoitteesta twitchapps.com/tmi tai Twitch-kehittäjäsovelluksestasi.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Täysi kehote';

  @override
  String get fullSetup => 'Täysi asennus';

  @override
  String get general => 'Kenraali';

  @override
  String get generalSettings => 'Yleiset asetukset';

  @override
  String get generalSettingsSaved => 'Yleiset asetukset tallennettu.';

  @override
  String get generateAPromptForAnotherAi =>
      'Luo kehote toiselle tekoälylle, liitä vastaus tähän tuodaksesi muistoja.';

  @override
  String get generatePrompt => 'Luo kehote';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Geoaidan seurantavirhe: $arg1';
  }

  @override
  String get getInspired => 'Inspiroidu';

  @override
  String get githubCopilot => 'GitHub Copilot';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot ja OpenAI Codex';

  @override
  String get githubIssueOpened => 'GitHub-ongelma avattu';

  @override
  String get neorecallMemoryCreated => 'NeoRecall-muisti luotu';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'GitHubin julkaisun tarkistus epäonnistui HTTP $arg1:n kanssa.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'GitHubin julkaisun hyötykuorma ei ollut julkaisuluettelo.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'GitHub-käyttäjänimi, joka avasi ongelman';

  @override
  String get globalSecurityMode => 'Globaali suojaustila';

  @override
  String get gmailMessageReceived => 'Gmail-viesti vastaanotettu';

  @override
  String get good => 'Hyvä';

  @override
  String get goodAfternoon => 'Hyvää iltapäivää';

  @override
  String get goodEvening => 'Hyvää iltaa';

  @override
  String get goodMorning => 'Hyvää huomenta';

  @override
  String get goodPasswordALittleMoreLength =>
      'Hyvä salasana. Vähän enemmän pituutta tekee siitä vahvemman.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live käyttää OpenAI API -avainta ja Gemini Live Google AI -avainta. Muutokset koskevat seuraavaa puhelua.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Myönnä Health Connect -käyttöoikeudet ennen synkronointia.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Ryhmä, kanava tai huone';

  @override
  String get groupType => 'Ryhmän tyyppi';

  @override
  String get groupsAndChannels => 'Ryhmät ja kanavat';

  @override
  String groupsArg1(Object? arg1) {
    return 'Ryhmät: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Ryhmät $arg1, joita ei ole vielä nähnyt, seuraavat tätä.';
  }

  @override
  String get handlesDirectTasksItself => 'Hoitaa suoria tehtäviä itse';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Handsfree (puhu vapaasti, keskeytä milloin tahansa)';

  @override
  String get headerName => 'Otsikon nimi';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Sinua kiinnostavien aiheiden otsikot, suodatettu signaalin mukaan.';

  @override
  String get health => 'Terveys';

  @override
  String get healthChecks => 'Terveystarkastukset';

  @override
  String get healthConnect => 'terveysyhteys';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect ei ole käytettävissä tällä laitteella.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Health Connectin synkronoinnin tila ja tallennetut taustatiedot.';

  @override
  String get healthStatusIsUnavailable => 'Terveystila ei ole saatavilla.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Terveyssynkronointi on käytettävissä vain Androidissa.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Sydän $arg1 -levyt';
  }

  @override
  String get heldBack => 'Pidätettynä';

  @override
  String get helper => 'Auttaja';

  @override
  String helperArg1(Object? arg1) {
    return 'Apulainen: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'täällä. Peru järjestelmänvalvoja valitsemalla ensin \"neoagent admin revoke $arg1\".';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Korkeammat arvot tekevät NeoAgentista valikoivamman ryhmissä.';

  @override
  String get highlyRecommended => 'Erittäin suositeltavaa';

  @override
  String get holdButton131ForTheAssistant =>
      'Pidä assistentin painiketta 131 painettuna.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Pidä Ctrl+Shift+välilyönti painettuna puhuaksesi';

  @override
  String get holdToTalk => 'Odota puhuaksesi.';

  @override
  String get holdToTalk2 => 'Odota puhuaksesi';

  @override
  String get home => 'Kotiin';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Kotiavustajan pitkäikäinen käyttötunnus vaaditaan.';

  @override
  String get homeAssistantSetup => 'Home Assistantin asetukset';

  @override
  String get homeAssistantUrl => 'Home Assistantin URL-osoite';

  @override
  String get homeAssistantUrlIsRequired =>
      'Kotiavustajan URL-osoite vaaditaan.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Kotipalvelintunnus huonekyselyllä';

  @override
  String get homeserverUrl => 'Kotipalvelimen URL-osoite';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'isännöity palvelu). Avaimesi ovat salattuja ja niitä voivat käyttää vain ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'IRC-verkon isäntänimi, esimerkiksi irc.libera.chat';

  @override
  String get hourly => 'Tunneittain';

  @override
  String get hourlyInboxCheck => 'Tuntikohtainen postilaatikon tarkistus';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Kuinka kauan vahvistuslinkit ovat voimassa.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Kuinka usein tämä agentti etsii uusia huoneviestejä.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Kuinka usein tämä agentti etsii uusia signaaliviestejä.';

  @override
  String get howTeamsWork => 'Miten tiimit toimivat';

  @override
  String get howThisServerIsReachedPlus =>
      'Miten tämä palvelin saavutetaan, sekä palvelimenlaajuiset kytkimet.';

  @override
  String get httpsSessionCookie => 'https-istunnon eväste';

  @override
  String get iCouldNotCompleteThatRequest =>
      'En voinut täyttää pyyntöä juuri nyt. Yritä hetken kuluttua uudelleen.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Tyhjäkäynti';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Jos $arg1 pyytää webhookin URL-osoitetta, liitä tämä, jotta viestit voivat tavoittaa $arg2:n.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Jos tilillä on vahvistettu sähköposti, NeoAgent lähettää salasanan palautuslinkin.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Jos palvelu vaatii tunnuksen lähteville pyynnöille.';

  @override
  String get ignoreGroups => 'Ohita ryhmät';

  @override
  String get ignoreThisChat => 'Ohita tämä keskustelu';

  @override
  String get ignoredChannels => 'Ohitetut kanavat';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Ohitettu väärin muotoiltu työpöytäpariviesti: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Toteuta yllä oleva suunnitelma.';

  @override
  String get implementThisPlan => 'Toteuta tämä suunnitelma';

  @override
  String get implicitTls => 'Implisiittinen TLS';

  @override
  String get import => 'Tuo';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Tuonti epäonnistui: $arg1';
  }

  @override
  String get importFromComputer => 'Tuo tietokoneelta';

  @override
  String get importMemoryTransfer => 'Tuodaanko muistin siirto?';

  @override
  String get importance => 'Tärkeys';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Tuodut $arg1-muistit, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return '@$arg1:n tiimissä';
  }

  @override
  String get inBackground => 'tausta';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Saapuvat ja lähtevät kanavaviestit näkyvät täällä.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Saapuvat sovelluksen sisäiset äänipuhelut NeoAgentilta';

  @override
  String get incomingMessages => 'Saapuvat viestit';

  @override
  String get incomingNeoagentCall => 'Saapuva NeoAgent-puhelu';

  @override
  String get incomingNeoagentCall2 => 'TULEVA NEOAGENT-PUHELU';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Saapuvien webhook- ja lähtevien takaisinsoittojen tuki';

  @override
  String get incorporatingSteering => 'Sisältää ohjauksen';

  @override
  String get input => 'Syöte';

  @override
  String get inputMode => 'Syöttötila';

  @override
  String get insertATemplate => 'Lisää malli';

  @override
  String get install => 'Asenna';

  @override
  String get installASignedSelfContainedRuntime =>
      'Asenna allekirjoitettu, itsenäinen suoritusaika. Node.js-, npm-, Git- ja terminaalikomentoja ei vaadita.';

  @override
  String get installApk => 'Asenna APK';

  @override
  String get installApkBundle => 'Asenna APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Asenna APK — napsauta tai pudota .apk-tiedosto';

  @override
  String get installNeoagent => 'Asenna NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Asenna NeoAgent tähän tietokoneeseen ilman päätettä tai muodosta yhteys jo käynnissä olevaan tietokoneeseen.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Asenna uudet julkaisut ja valitse mitä kanavaa tämä palvelin seuraa.';

  @override
  String get installTheBackend => 'Asenna taustaosa';

  @override
  String get installTheCoreWithExtraOptional =>
      'Asenna ydin ylimääräisellä valinnaisella asetuksella. AI-palveluntarjoajan avaimet lisätään myöhemmin, kuten Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Asenna suojattu ydin ja luo sitten tili. Lisää AI-palveluntarjoajan avaimet jälkeenpäin.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Asennettu: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Asennettu: $arg1 • Viimeksi tarkistettu: $arg2';
  }

  @override
  String get instructions => 'Ohjeet';

  @override
  String get integration => 'Integrointi';

  @override
  String get integrationConnections => 'Integraatioyhteydet';

  @override
  String get integrationSettingsSaved => 'Integrointiasetukset tallennettu.';

  @override
  String get integrations => 'Integraatiot';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrations/oauth/callback ja rekisteröi se ';

  @override
  String get interruptAi => 'Keskeytä AI';

  @override
  String get invalid2fa => 'virheellinen 2fa';

  @override
  String get invalidArgumentS => 'Virheelliset argumentit: ';

  @override
  String get invalidCredentials => 'virheelliset tunnistetiedot';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Virheellinen NeoAgent-ajonaikainen luettelo.';

  @override
  String get inviteLink => 'Kutsulinkki';

  @override
  String get inviteLinkReady => 'Kutsulinkki valmis';

  @override
  String get inviteLinks => 'Kutsulinkit';

  @override
  String get iphoneApp => 'iPhone-sovellus';

  @override
  String get issues => 'Ongelmat';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Ongelmat ilmenevät, kun loki latautuu.';

  @override
  String get itCanTBeUndone => 'Sitä ei voi kumota.';

  @override
  String get itMayHaveBeenDeleted => 'Se on ehkä poistettu.';

  @override
  String get javaRuntime => 'java-ajoaika';

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
    return 'Liittyi $arg1:hen';
  }

  @override
  String get joinedInTheLast7Days => 'Liittynyt viimeisen 7 päivän aikana';

  @override
  String get joiningATeam => 'Joukkueeseen liittyminen';

  @override
  String get joiningIsOffHere => 'Liittyminen on poissa tästä';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'JSON-kenttä, joka sisältää viestin tekstin. Yleensä tekstiä.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'JSON-kenttä, joka tunnistaa, kenelle viesti on tarkoitettu.';

  @override
  String get jumpToLatest => 'Siirry uusimpaan';

  @override
  String get justNow => 'juuri nyt';

  @override
  String get keepNeoagentRunning => 'Pitääkö NeoAgent käynnissä?';

  @override
  String get keepRunning => 'Jatka juoksemista';

  @override
  String get keepTaskRunning => 'Pidä tehtävä käynnissä';

  @override
  String get keepTheVaultAvailable => 'Pidä holvi saatavilla';

  @override
  String get keepThisLauncherUpToDate =>
      'Pidä tämä käynnistysohjelma ajan tasalla.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Pidä tämä paneeli auki, kunnes alusta vahvistaa yhteyden.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Pidä tämän istunnon tietokone näkyvissä';

  @override
  String get keepTrackOfYourAiUsage =>
      'Seuraa tekoälyn käyttöäsi. Rajoja valvotaan oikeudenmukaisen käytön varmistamiseksi koko alustalla.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Jatka sovellusten käyttöä normaalisti. NeoAgent toimii samalla näytöllä ja kysyy aina, kun se tarvitsee uuden käyttöoikeuden.\n\n';

  @override
  String get keepingThisDeviceConnected => 'Tämä laite pidetään kytkettynä';

  @override
  String get key => 'Avain';

  @override
  String get keyIsRequired => 'Avain vaaditaan.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Avainarvoparit, jotka säilyvät keskusteluissa.';

  @override
  String get knowledgeGraph => 'Tietograafi';

  @override
  String get knowledgeView => 'Tietonäkymä';

  @override
  String get labelOnlyYouSeeIt => 'Etiketti (vain sinä näet sen)';

  @override
  String get labelsOptional => 'Tunnisteet (valinnainen)';

  @override
  String get last24Hours => 'Viimeiset 24 tuntia';

  @override
  String get last7Days => 'Viimeiset 7 päivää';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Viimeiset 7 päivää: $arg1-tunnukset kohteessa $arg2 toimivat';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Viimeinen $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Viimeisin: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Viimeisin ei-tyhjä synkronointi · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Viimeinen ajo: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Viimeksi nähty $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Viimeisin kirjautuminen $arg1';
  }

  @override
  String get lastSyncSummary => 'Viimeisimmän synkronoinnin yhteenveto';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Viimeksi käytetty: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Viimeinen ikkuna päättyi $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'myöhempi käynnistys myös pois päältä.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Viimeisin ajo · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Työpöytäsovellusten käynnistämistä ei tueta tällä alustalla.';

  @override
  String get learnRoomNorms => 'Opi huonenormit';

  @override
  String get leave => 'Lähde';

  @override
  String get leaveARedirectUriBlankTo =>
      'Jätä uudelleenohjaus-URI tyhjäksi, jos haluat käyttää <julkista URL-osoitetta>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Poistutaanko $arg1:n tiimistä?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Jätä oletusasetukseksi, ellet mukauttanut BlueBubblesia.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Jätä token tyhjäksi, jos haluat säilyttää tallennetun tunnuksen.';

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
    return 'Anna $arg1:n hallita minua';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Anna kaikkien tässä ryhmässä puhua $arg1:lle.';
  }

  @override
  String get letItWorkWhileYouDon => 'Anna sen\ntoimia, kun et.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Anna NeoAgentin napsauttaa, kirjoittaa ja selata sovelluksiasi.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Anna NeoAgentin ymmärtää, mitä näytölläsi näkyy.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Anna jonkun, jonka kanssa työskentelet, päättää, mitä työkaluja edustajasi voi ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Anna tämän henkilön lähettää $arg1:lle henkilökohtainen viesti.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Anna tämän henkilön puhua $arg1:lle täällä, mutta ei yksityisissä chateissa tai muissa ryhmissä.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Anna tämän henkilön puhua $arg1:lle yksityisissä chateissa ja missä tahansa jakamassaan ryhmässä.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Taso $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Linkki $arg1';
  }

  @override
  String get linkCopied => 'Linkki kopioitu';

  @override
  String get linkExpiresAfter => 'Linkki vanhenee tämän jälkeen';

  @override
  String get linkLifetimeHours => 'Linkin käyttöikä (tuntia)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Linkin käyttöiän on oltava 1-8760 tuntia.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Linkki voimassa $arg1 asti.';
  }

  @override
  String get linkedSignInProviders => 'Linkitetyt kirjautumispalveluntarjoajat';

  @override
  String get linuxApp => 'Linux-sovellus';

  @override
  String listedArg1(Object? arg1) {
    return 'Listattu $arg1/';
  }

  @override
  String get listening => 'Kuunteleminen';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Live-suoritushistoria, työkalun vaiheet ja vastaukset.';

  @override
  String get liveModel => 'Live malli';

  @override
  String get liveModelProvider => 'Live-mallin tarjoaja';

  @override
  String get liveRun => 'Live-juoksu';

  @override
  String get liveVoice => 'Elävä ääni';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'Live-ääniyhteys ei ole käytettävissä.';

  @override
  String get liveVoiceConnectionWasClosed => 'Live-ääniyhteys suljettiin.';

  @override
  String get liveVoiceDefaults => 'Liveäänen oletusasetukset';

  @override
  String get liveVoiceFailed => 'Live-ääni epäonnistui.';

  @override
  String get llmMemoryExportResponse => 'LLM-muistin vientivastaus';

  @override
  String get loadFailed => 'lataus epäonnistui';

  @override
  String get loadingExecutionDetails => 'Ladataan suoritustietoja...';

  @override
  String get loadingNeoagent => 'Ladataan NeoAgentia';

  @override
  String get loadingRunFlow => 'Ladataan ajokulkua…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Paikallisia ja yksityisen verkon URL-osoitteita tuetaan, kun NeoAgent-palvelin voi tavoittaa ne. Ääni ei koskaan altistu NeoAgentille.';

  @override
  String get localApp => 'paikallinen sovellus';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Paikallinen tausta-asennus ei ole käytettävissä tällä alustalla.';

  @override
  String get localBaseImagePath => 'Paikallinen peruskuvapolku';

  @override
  String get localComputerControlIsAvailableIn =>
      'Paikallinen tietokoneen ohjaus on saatavilla NeoAgent-työpöytäsovelluksessa macOS:ssä, Windowsissa ja Linuxissa.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Paikallinen tietokoneohjaus ei ole käytettävissä täällä.';

  @override
  String get localModelsUrl => 'paikallisten mallien URL-osoite';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Paikallinen NeoAgent-etsintä ei ole tilapäisesti käytettävissä.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'NeoAgent-sovelluksen paikalliset asetukset. Tietokoneohjaus toimii aina yhtenäisen pilvitietokoneen kautta.';

  @override
  String get localSetup => 'PAIKALLINEN ASETUS';

  @override
  String get locationCityOrPlace => 'Sijainti (kaupunki tai paikka)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Sijainti vaaditaan säätapahtuman laukaisemiseksi';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'LocationServicen alustus epäonnistui: $arg1';
  }

  @override
  String get logCopied => 'Loki kopioitu';

  @override
  String get loginPassword => 'Kirjautumissalasana';

  @override
  String get logout => 'Kirjaudu ulos';

  @override
  String get logs => 'Lokit';

  @override
  String get logsCopied => 'Lokit kopioitu.';

  @override
  String get logsOnThisComputer => 'Lokit tälle tietokoneelle';

  @override
  String get longLivedAccessToken => 'Pitkäikäinen pääsytunnus';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Pitkäaikainen muisti, jäsennellyt tosiasiat ja tietokaavio.';

  @override
  String get lookedAtTheScreen => 'Katsoi näyttöä';

  @override
  String get lookingOnThisComputerAndYour =>
      'Tarkastellaan tätä tietokonetta ja paikallista verkkoasi…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Katsoo eteenpäin huomisen kokouksissa, joten mikään ei yllätä sinua.';

  @override
  String get loopExecution => 'Silmukan suoritus';

  @override
  String get loopPaused => 'Silmukka keskeytetty';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS:n käytettävyyttä ei myönnetä NeoAgentille. Salli se kohdassa Järjestelmäasetukset › Yksityisyys ja suojaus › Esteettömyys.';

  @override
  String get macosApp => 'macOS-sovellus';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'macOS-näytön tallennusta ei myönnetä NeoAgentille. Salli se kohdassa Järjestelmäasetukset › Tietosuoja ja suojaus › Näytön tallennus ja avaa sitten NeoAgent uudelleen.';

  @override
  String get mailServersThatNeedAPassword =>
      'Salasanaa tarvitsevat sähköpostipalvelimet kieltäytyvät lähettämästä ennen uutta ';

  @override
  String get main => 'Main';

  @override
  String get makeDefault => 'Tee oletukseksi';

  @override
  String get manage => 'Hallitse';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Hallitse tilisi sähköpostia, kaksivaiheista todennusta ja aktiivisia istuntoja.';

  @override
  String get managedBy => 'Hallinnoija';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Esimiehillä voi olla omia johtajia (enintään neljä tasoa). A ';

  @override
  String get managing => 'Hallitseminen';

  @override
  String get manualDestination => 'Manuaalinen kohde';

  @override
  String get manualTrigger => 'Manuaalinen laukaisu';

  @override
  String get masterPassword => 'Pääsalasana';

  @override
  String get matchThisDevice => 'Yhdistä tämä laite';

  @override
  String get matchedAgainstTitleAndBody => 'Vastaa otsikkoa ja runkoa';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Vastaa vanhaa NeoAgent MCP -kulkua: URL plus todennusmenetelmä.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP-palvelin';

  @override
  String get mcpServer2 => 'MCP-palvelin';

  @override
  String get mcpServerUrl => 'MCP-palvelimen URL-osoite';

  @override
  String get mcpServers => 'MCP-palvelimet';

  @override
  String get meantForSomeoneElse => 'Jollekin muulle tarkoitettu';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Mitattu mallihinta: $arg1';
  }

  @override
  String get memories => 'Muistoja';

  @override
  String get memory => 'Muisti';

  @override
  String memoryArg1(Object? arg1) {
    return 'Muisti: $arg1';
  }

  @override
  String get memoryInjected => 'Muisti ruiskutettu';

  @override
  String get mentionOrReplyOnly => 'Vain mainitse tai vastaa';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Yhdistetty palvelin- ja Flutter-ajonaikaiset lokit tälle sovellusistunnolle.';

  @override
  String get messageBodyTemplateJson => 'Viestin tekstimalli (JSON)';

  @override
  String get messageNeedsAccess => 'Viesti vaatii pääsyn';

  @override
  String get messageTextField => 'Viestin tekstikenttä';

  @override
  String get messaging => 'Viestit';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Messaging API push- ja webhook-tapahtumat';

  @override
  String get messagingConnectionNeedsAttention =>
      'Viestiyhteys vaatii huomiota';

  @override
  String get messagingConnections => 'Viestintäyhteydet';

  @override
  String get messagingDelivery => 'Viestien toimitus';

  @override
  String get messagingErrorPleaseTryAgain => 'Viestivirhe. Yritä uudelleen.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Mikrofonin sieppaus pysähtyi odottamatta. Yritä uudelleen.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Mikrofonivirhe: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Mikrofoni mykistetty. Poista mykistys napauttamalla.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Suoraan ääneen tarvitaan mikrofonin lupa.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Microsoft Teams';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Maksun vähimmäisarvo: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Mobiiliasennus epäonnistui.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Mobiiliasennus epäonnistui, koska Java ei ole saatavilla koneessa, jossa on NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Mobiiliasennus epäonnistui, koska Java ei ole saatavilla koneessa, jossa on NeoAgent. Asenna JDK ja yritä uudelleen.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Mobiiliasennus epäonnistui. Tarkista, että Android-työkalut on asennettu oikein, ja yritä uudelleen.';

  @override
  String modeArg1(Object? arg1) {
    return 'tila: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Tila lukittuu juoksun ollessa käynnissä.';

  @override
  String get model => 'Malli';

  @override
  String modelArg1(Object? arg1) {
    return 'Malli: $arg1';
  }

  @override
  String get modelAvailability => 'Mallin saatavuus';

  @override
  String get modelAvailabilitySaved => 'Mallin saatavuus tallennettu.';

  @override
  String get modelForThisSession => 'Malli tälle istunnolle';

  @override
  String get modelOverride => 'Mallin ohitus';

  @override
  String get modelPending => 'Malli vireillä';

  @override
  String get modelTurn => 'Mallin käännös';

  @override
  String get modelTurnCompleted => 'Mallin käännös valmis';

  @override
  String get modelTurnStarted => 'Mallin vuoro alkoi';

  @override
  String get modelVisibilityHideShowList =>
      'mallin näkyvyys piilota esityslista';

  @override
  String get models => 'Mallit';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Mallit, käyttäytyminen, ääni ja työtila';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Mallit, selain, ääni, diagnostiikka...';

  @override
  String get modelsRouting => 'Mallit ja reititys';

  @override
  String get monthly => 'Kuukausittain';

  @override
  String get moreActions => 'Lisää toimintoja';

  @override
  String get morningBriefing => 'Aamun tiedotustilaisuus';

  @override
  String get mostUsedAgents => 'Eniten käytetyt aineet';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Viimeisimmän $arg1:n käytetyimmät mallit.';
  }

  @override
  String get mouseKeyboard => 'Hiiri & näppäimistö';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMovea ei tueta tällä alustalla.';

  @override
  String get mustBeReachableOnThePublic =>
      'On oltava tavoitettavissa julkisesta Internetistä – paikallisesta ja ';

  @override
  String get n24Hours => '24 tuntia';

  @override
  String get n2faOrRecoveryCode => '2FA tai palautuskoodi';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA edellyttää, että SESSION_SECRET on määritetty tässä NeoAgent-asennuksessa.';

  @override
  String get n30Days => '30 päivää';

  @override
  String get n365Days => '365 päivää';

  @override
  String get n4HourLimitTokens => '4 tunnin raja (tokenit)';

  @override
  String get n4HourUsage => '4 tunnin käyttö';

  @override
  String n4hLimitArg1(Object? arg1) {
    return '4 tunnin raja $arg1';
  }

  @override
  String get n7DayUsage => '7 päivän käyttö';

  @override
  String get n7Days => '7 päivää';

  @override
  String get n90Days => '90 päivää';

  @override
  String get name => 'Nimi';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnimi: Uusi taito\nkuvaus: Kuvaile, mitä tämä taito tekee\n---\nKirjoita tähän taitoon liittyvät ohjeet.\n';

  @override
  String get nameOfWhoeverMadeIt => 'sen tekijän nimi.';

  @override
  String get nameOptional => 'Nimi (valinnainen)';

  @override
  String get nativeAndWebhookChannels => 'Natiivi- ja webhook-kanavat';

  @override
  String get naturalBubbles => 'Luonnolliset kuplat';

  @override
  String get nearbyNeoagentServers => 'Lähellä NeoAgent-palvelimia';

  @override
  String get needANewAccountRegister => 'Tarvitsetko uuden tilin? Rekisteröidy';

  @override
  String get needAnIdea => 'Tarvitsetko idean?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Tarve vastata · $arg1% puhuaksesi';
  }

  @override
  String get needsAttention => 'Vaatii huomiota';

  @override
  String get needsInput => 'Tarvitsee syötteen';

  @override
  String get neoagentApp => 'NeoAgent-sovellus';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'NeoAgent Assistant';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent ei voinut tarkistaa käytettävissä olevaa taustajärjestelmän suoritusaikaa.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent ei voinut viimeistellä paikallista asennusta.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent ei voinut viimeistellä paikallista asennusta. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'NeoAgent-virheenkorjaustiedot';

  @override
  String get neoagentDesktopInstaller => 'NeoAgent Desktop Installer';

  @override
  String get neoagentFlutterUpdater => 'NeoAgent Flutter Updater';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent asentaa uusimman $arg1:n ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent on asennettu ja käynnissä.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgentia ei ole asennettu tähän tietokoneeseen.';

  @override
  String get neoagentIsReady => 'NeoAgent on valmis';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent työskentelee edelleen tehtävän parissa. Lopeta puhelu ja saat tuloksen chatissa tai peruuta myös tehtävä.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent muuttaa esittelystäsi mukautuvan työnkulun.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent odottaa, kun käytät työpöytää.';

  @override
  String get neoagentIsWorking => 'NeoAgent toimii';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux -tietokone';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT tarvitsee PÄÄTÖKSEN';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'NeoAgent-ajonaikaiset lataukset vaativat suojatun osoitteen.';

  @override
  String get neoagentServerAddress => 'NeoAgent-palvelimen osoite';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'NeoAgent-palvelusähköposti ei ole valmis. Pyydä palvelimen operaattoria tarkistamaan sähköpostiympäristön asetukset.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'NeoAgentin asennusta ei voitu suorittaa loppuun.';

  @override
  String get neoagentUser => 'NeoAgent-käyttäjä';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent käyttää tätä tietokonetta automaattisesti ja kysyy ennen kuin se käyttää näyttöäsi, hiirtä, näppäimistöä, tiedostoja tai komentoriviä.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent käyttää likimääräistä taustasijaintiasi käynnistääkseen geoaidan muistutuksia (esim. \"Muistuta minua ostamaan maitoa, kun kävelen supermarketin ohi\").\n\n';

  @override
  String get neoagentWorkspace => 'NeoAgent-työtila';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][pino] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'NeoRecall-taustajärjestelmän URL-osoite';

  @override
  String get neorecallBackendUrlIsRequired => 'NeoRecall-tausta-URL vaaditaan.';

  @override
  String get neorecallSetup => 'NeoRecall-asennus';

  @override
  String get networkRequestFailed => 'verkkopyyntö epäonnistui';

  @override
  String get networkWriteRequests => 'Verkkokirjoituspyynnöt';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'ei koskaan laske jaettuja käyttörajoja.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Uudet tilit vahvistavat sähköpostiosoitteensa ennen sisäänkirjautumista.';

  @override
  String get newAccountsPerDay => 'Uusia tilejä päivässä';

  @override
  String get newChat => 'Uusi chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Uudet ryhmät pysyvät hiljaa, ellei joku merkitse $arg1:tä, kunnes otat ne käyttöön.';
  }

  @override
  String get newLink => 'Uusi linkki';

  @override
  String get newPasswordsDoNotMatch => 'Uudet salasanat eivät täsmää.';

  @override
  String get newRecoveryCodes => 'Uudet palautuskoodit';

  @override
  String get newSession => 'Uusi istunto';

  @override
  String get newSessionN => 'Uusi istunto (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Uusi istunto samoilla asetuksilla';

  @override
  String get newSkill => 'Uusi taito';

  @override
  String get newSkill2 => 'Uusi Taito';

  @override
  String get newThisWeek => 'Uutta tällä viikolla';

  @override
  String get newsDigest => 'Uutisten yhteenveto';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Seuraava yritys: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Nextcloud-kirjautumiskulku';

  @override
  String get nextcloudSetup => 'Nextcloudin asennus';

  @override
  String get nextcloudTalk => 'Nextcloud-keskustelu';

  @override
  String get nextcloudUrl => 'Nextcloud-URL-osoite';

  @override
  String get nextcloudUrlIsRequired => 'Nextcloud-URL vaaditaan.';

  @override
  String get nickname => 'Lempinimi';

  @override
  String get noAccountsConnectedYet => 'Ei vielä yhdistettyjä tilejä.';

  @override
  String get noAccountsFound => 'Tilejä ei löytynyt.';

  @override
  String get noActiveSessionsFound => 'Aktiivisia istuntoja ei löytynyt.';

  @override
  String get noAgentsYet => 'Ei agentteja vielä';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Tekoälypalveluntarjoajaa ei ole määritetty, joten chattaile ja viestit ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Ei hyväksymiskehotteita – agentti toimii keskeytyksettä.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Yksikään $arg1-julkaisusisältö ei vastannut tätä alustaa.';
  }

  @override
  String get noArguments => '(ei argumentteja)';

  @override
  String get noAuth => 'Ei todennusta';

  @override
  String get noBindingsYet => 'Ei vielä sidoksia.';

  @override
  String get noChangesYet => 'Ei muutoksia vielä';

  @override
  String get noChannelsFound => 'Kanavia ei löytynyt';

  @override
  String get noCloudComputerSlotIsFree =>
      'Mikään pilvitietokonepaikka ei ole tällä hetkellä ilmaista. Yritä hetken kuluttua uudelleen.';

  @override
  String get noCoreMemoryEntriesYet => 'Ei vielä ydinmuistimerkintöjä.';

  @override
  String get noDescription => 'Ei kuvausta';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Työpöytänäyttöjä ei ole tällä hetkellä saatavilla.';

  @override
  String get noDetailAvailable => 'Yksityiskohtia ei ole saatavilla';

  @override
  String get noDetailedSyncSummaryYet =>
      'Yksityiskohtaista synkronointiyhteenvetoa ei vielä ole.';

  @override
  String get noDetailsCaptured => 'Yksityiskohtia ei ole tallennettu.';

  @override
  String get noEmailLinked => 'Sähköpostia ei ole linkitetty';

  @override
  String get noExternalSignInProvidersLinked =>
      'Ulkoisia kirjautumispalveluita ei ole linkitetty.';

  @override
  String get noGroupMessagesYet => 'Ei vielä ryhmäviestejä';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Ryhmäkohtaisia ihmisiä ei ole vielä lisätty.';

  @override
  String get noGroupsAddedYet => 'Ryhmiä ei ole vielä lisätty.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Ryhmiä ei vielä löytynyt. Kun $arg1 näkee ryhmäviestin, käytä Etsi viimeisimmät keskustelut ja ne näkyvät täällä.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Ryhmiä ei vielä löytynyt. Kun $arg1 näkee ryhmäviestin, käytä Etsi viimeisimmät keskustelut.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Terveystietojen hyötykuormaa ei palautettu.';

  @override
  String get noHealthSamplesStoredYet =>
      'Terveysnäytteitä ei ole vielä tallennettu.';

  @override
  String get noHttpClientImplementationForThis =>
      'Ei HTTP-asiakassovellusta tälle alustalle.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Tässä vaiheessa ei tallennettu tuloa tai lähtöä.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Mikään integraatio ei vastaa tätä hakua.';

  @override
  String get noLimit => 'Ei rajaa';

  @override
  String get noLocalPasswordIsSetYet =>
      'Paikallista salasanaa ei ole vielä asetettu. Luo käyttäjätunnus/salasana kirjautuminen käyttöön.';

  @override
  String get noLogEntries => 'Ei lokimerkintöjä.';

  @override
  String get noMatchingSettings => 'Ei vastaavia asetuksia';

  @override
  String get noMcpServersMatchThisSearch =>
      'Mikään MCP-palvelin ei vastaa tätä hakua.';

  @override
  String get noMemoryEntriesFound => 'Muistimerkintöjä ei löytynyt.';

  @override
  String get noMemorySync => 'Ei muistin synkronointia';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Lukee kerran viimeisen 12 kuukauden tärkeät ja lähetetyt viestit, jotta agentti tuntee yhteystietosi ja projektisi.';

  @override
  String get emailMemory => 'Sähköpostimuisti';

  @override
  String get importNow => 'Tuo nyt';

  @override
  String get importOnConnect => 'Tuo aiemmat viestit, kun tili yhdistetään';

  @override
  String get sweepStarting => 'Valmistellaan…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Luetaan sähköposteja · $done/$total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Luetaan sähköposteja · $count löydetty';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Opitaan sähköposteista · $done/$total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Viimeisin tuonti: $emails sähköpostia · $memories uutta muistoa';
  }

  @override
  String get sweepNothingNew => 'Ei uusia sähköposteja tuotavaksi';

  @override
  String sweepFailed(String error) {
    return 'Tuonti epäonnistui: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Mikään malli ei vastaa \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Tälle ajolle ei tallennettu mallipyyntöä.';

  @override
  String get noModelsDiscoveredYet => 'Mallia ei ole vielä löydetty';

  @override
  String get noModelsSelected => 'Ei valittuja malleja';

  @override
  String get noModelsYet => 'Ei vielä malleja';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'tähän palveluntarjoajaan ei ole linkitetty neoagent-tiliä';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Tälle tietokoneelle ei ole saatavilla NeoAgent-taustajärjestelmän suoritusaikaa.';

  @override
  String get noNetworkConnection => 'Ei verkkoyhteyttä';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Ei verkkoyhteyttä. Yhdistä jatkaaksesi NeoAgentin käyttöä.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Ei verkkoyhteyttä. Yhdistä uudelleen tarkistaaksesi päivitykset.';

  @override
  String get noOne => 'Ei kukaan';

  @override
  String get noOneAddedYet => 'Kukaan ei ole vielä lisännyt.';

  @override
  String get noOneCanMessage => 'Kukaan ei voi viestiä';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Toista NeoAgent-palvelinta ei löytynyt. Voit etsiä uudelleen tai kirjoittaa osoitteen manuaalisesti.';

  @override
  String get noPeopleAddedYet => 'Henkilöitä ei ole vielä lisätty.';

  @override
  String get noPlatformsMatch => 'Mikään alusta ei vastaa';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Määritettäviä palveluntarjoajia ei ole vielä saatavilla.';

  @override
  String get noRecentChannelActivity => 'Ei viimeaikaista kanavatoimintaa';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Ei tuloksia haulle \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Ei juoksuja tällä alueella.';

  @override
  String get noRunsMatchTheseFilters =>
      'Yksikään ajo ei vastaa näitä suodattimia';

  @override
  String get noRunsYet => 'Ei vielä juoksuja';

  @override
  String get noRunsYet2 => 'Ei vielä juoksuja.';

  @override
  String get noSecurityKeyWasProvided => 'Suojausavainta ei annettu.';

  @override
  String get noServerUrlSet => 'Palvelimen URL-osoitetta ei ole asetettu';

  @override
  String get noSessionMatchesThatSearch => 'Mikään istunto ei vastaa hakua.';

  @override
  String get noSessionsYet => 'Ei istuntoja vielä';

  @override
  String get noSkillsMatchTheseFilters =>
      'Mikään taito ei vastaa näitä suodattimia.';

  @override
  String get noStepsWereRecordedForThis =>
      'Tälle ajolle ei tallennettu yhtään askelta.';

  @override
  String get noSummaryAvailable => 'Yhteenvetoa ei ole saatavilla.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Ei tehtäviä mallille $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Mikään työkalu ei vastaa \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Ei päivitys käynnissä';

  @override
  String get noUsageYet => 'Ei vielä käyttöä.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Vahvistettua NeoAgent-taustajärjestelmän suoritusaikaa ei ole vielä saatavilla.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Kukaan ei voi käyttää sitä enää. Ihmiset, jotka ovat jo liittyneet ';

  @override
  String get none => 'Ei mitään';

  @override
  String get notApprovedYet => 'ei ole vielä hyväksytty';

  @override
  String get notAuthenticated => 'ei todennettu';

  @override
  String get notCheckedYet => 'Ei vielä tarkistettu';

  @override
  String get notConfigured => 'Ei määritetty';

  @override
  String get notConnected => 'Ei yhdistetty';

  @override
  String get notConnected2 => 'Ei yhdistetty';

  @override
  String get notInstalled => 'Ei asennettu';

  @override
  String get notNeeded => 'Ei tarvita';

  @override
  String get notNeededEnough => 'Ei tarvittu tarpeeksi';

  @override
  String get notNow => 'Ei nyt';

  @override
  String get notNow2 => 'Ei nyt';

  @override
  String get notSet => 'Ei asetettu';

  @override
  String get notSetUp => 'Ei asetettu';

  @override
  String get notTheSameAsAdmin => 'Ei sama kuin admin';

  @override
  String get nothingFound => 'Mitään ei löytynyt';

  @override
  String get nothingHereYet => 'Ei täällä vielä mitään.';

  @override
  String get nothingHereYet2 => 'Ei täällä vielä mitään';

  @override
  String get nothingMatches => 'Mikään ei vastaa';

  @override
  String get nothingStoredYet => 'Mitään ei ole vielä tallennettu.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Notion, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'OAuth-asiakastunnus';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth-asiakastunnuksen salainen uudelleenohjaussovellusliittymäavain';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth-asiakastunnuksen salainen uudelleenohjaus gmail-kalenteriasema';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'OAuthin käynnistystä ei tueta tällä alustalla.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook vuokralaisen asiakastunnuksen salaisuus';

  @override
  String get oauthToken => 'OAuth-tunnus';

  @override
  String get oauthWithPkce => 'OAuth PKCE:n kanssa';

  @override
  String ofArg1(Object? arg1) {
    return '$arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'omasta. Sitä ei näytetä enää koskaan tallennuksen jälkeen.';

  @override
  String get off => 'Pois päältä';

  @override
  String get officialIntegration => 'Virallinen integraatio';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Virallinen integraatio ei palauttanut yhteyden URL-osoitetta.';

  @override
  String get on => 'Päällä';

  @override
  String get onASignedInAndroidDevice =>
      'Avaa sisäänkirjautuneella Android-laitteella Asetukset › Kirjautuminen ja suojaus, skannaa tämä koodi ja hyväksy kirjautuminen.';

  @override
  String get onByDefaultForNewGroups =>
      'Oletusarvoisesti käytössä uusille ryhmille';

  @override
  String get onDemand => 'On Demand';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Käytössä $arg2-ryhmille $arg1';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'päällä. He voivat liittyä uudelleen vain uudella kutsulinkillä.';

  @override
  String get onYourOwnTheDefault => 'Yksin (oletus)';

  @override
  String get once => 'Kerran';

  @override
  String get oneIsSavedOtherChangesIn =>
      'yksi on pelastettu. Myös muut tämän lomakkeen muutokset tallennetaan.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Yksi tai useampi tili on vanhentunut. Yhdistä ongelmallinen tili uudelleen palauttaaksesi työkalun käyttöoikeudet.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Yksi suoritusaika ohjaa persoonaa, ryhmävuoroja, huoneen muistia, normeja, mielen teoriaa ja toimitusta.';

  @override
  String get oneTimeRun => 'Kerran lenkki';

  @override
  String get onlyApkOrApksFilesCan =>
      'Vain .apk- tai .apks-tiedostoja voidaan asentaa.';

  @override
  String get onlyInThisGroup => 'Vain tässä ryhmässä';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Tarvitaan vain, jos palvelu pyytää ylimääräisiä HTTP-otsikoita.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Tarvitaan vain, jos haluat muokata lähtevää hyötykuormaa.';

  @override
  String get onlyTheyCanChangeIt => 'Vain he voivat muuttaa sen.';

  @override
  String get open => 'Avaa';

  @override
  String get openAccountSettingsOnASigned =>
      'Avaa Asetukset › Sisäänkirjautuminen ja suojaus sisäänkirjautuneella Android-laitteella, skannaa tämä koodi ja hyväksy kirjautuminen.';

  @override
  String get openComputer => 'Avaa tietokone';

  @override
  String get openDashboard => 'Avaa kojelauta';

  @override
  String get openFolder => 'Avaa kansio…';

  @override
  String get openInWorkbench => 'Avaa työpöydällä';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Avaa NeoAgent ja yhdistä $arg1 uudelleen palauttaaksesi viestit.';
  }

  @override
  String get openTimeSettings => 'Avaa aikaasetukset';

  @override
  String get openToAnyone => 'Avoinna kenelle tahansa';

  @override
  String get openTrello => 'Avaa Trello';

  @override
  String get openVoiceAssistant => 'Avaa ääniavustaja';

  @override
  String get openWiFiSettings => 'Avaa Wi-Fi-asetukset';

  @override
  String get openWithTheDefaultApp => 'Avaa oletussovelluksella';

  @override
  String get openaiCodex => 'OpenAI Codex';

  @override
  String get openaiCompatible => 'openai yhteensopiva';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'OpenAI-yhteensopiva päätepiste (oma palvelin tai jokin muu ';

  @override
  String openedArg1(Object? arg1) {
    return 'Avattu $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Työpöytä-URL-osoitteiden avaamista ei tueta tällä alustalla.';

  @override
  String get openingYourSavedDesktop => 'Tallennetun työpöydän avaaminen.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Tallennetun työpöydän avaaminen. Normaali käynnistys kestää alle 10 sekuntia.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Valinnainen ylimääräinen salaisuus, jos suojaat saapuvan webhookin.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Valinnainen ohitus, jos webhookin URL-osoite ei riitä.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Valinnainen salaisuus saapuvien Chat-tapahtumien vahvistamiseen.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Valinnainen salaisuus saapuvien tapahtumien tarkistamiseen.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Valinnainen salaisuus saapuvien iMessage-tapahtumien tarkistamiseen.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Valinnainen salaisuus saapuvien LINE-tapahtumien tarkistamiseen.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Valinnainen salaisuus saapuvien Mattermost-tapahtumien tarkistamiseen.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Valinnainen salaisuus saapuvien Teams-tapahtumien vahvistamiseen.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Valinnainen. Agentilla on jo oma persoonallisuutensa. Kaikki, mitä lisäät sävyyn, kerrostetaan sen päälle, joten sinun ei koskaan tarvitse määritellä sitä.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Valinnainen. Kun se on asetettu, sitä käytetään URL-osoitteen sijasta.';

  @override
  String get orAnswerInYourOwnWords => 'Tai vastaa omin sanoin';

  @override
  String get orBuildYourOwnTask => 'Tai rakenna oma tehtäväsi';

  @override
  String get orContinueWith => 'tai jatka eteenpäin';

  @override
  String get orFiles => 'tai tiedostoja.';

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
  String get originNotAllowed => 'alkuperä kielletty';

  @override
  String get outgoingMessage => 'Lähtevä viesti';

  @override
  String get outgoingWebhookUrl => 'Lähtevän webhookin URL-osoite';

  @override
  String get outlookEmailReceived => 'Outlook-sähköposti vastaanotettu';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Korvaa tuonnin käyttäytymishuomautukset.';

  @override
  String get ownModel => 'oma malli';

  @override
  String get packageName => 'Paketin nimi';

  @override
  String get pairWithQrCode => 'Yhdistä QR-koodilla';

  @override
  String get password => 'Salasana';

  @override
  String get password2faAndActiveSessions =>
      'Salasana, 2FA ja aktiiviset istunnot';

  @override
  String get passwordCreated => 'Salasana luotu.';

  @override
  String get passwordIsTooWeak => 'salasana on liian heikko';

  @override
  String get passwordMin8 => 'salasana min 8';

  @override
  String get passwordOrApiKey => 'Salasana tai API-avain';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Salasanan vahvuus: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Salasanat eivät täsmää.';

  @override
  String get pasteAKey => 'Liitä avain.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Liitä uusi avain $arg1:n tilalle';
  }

  @override
  String get pasteTheKey => 'Liitä avain';

  @override
  String get pasteYourAccountToken => 'Liitä tilisi tunnus';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Liitä $arg1 API-avain alle. Se on ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Polun on pysyttävä NeoAgent Workspacessa.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Polun on pysyttävä työtilakansion sisällä.';

  @override
  String get pauseLiveUpdates => 'Keskeytä live-päivitykset';

  @override
  String get pauseTaskLoop => 'Keskeytä tehtäväsilmukka';

  @override
  String get paused => 'Keskeytetty';

  @override
  String peakArg1(Object? arg1) {
    return 'huippu $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Ihmiset yksityisissä chateissa';

  @override
  String get perAccountRateLimits => 'Tilikohtaiset korkorajat';

  @override
  String get perCategoryPermissions => 'Luokkakohtaiset käyttöoikeudet';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Työkalukohtaiset käyttöoikeuskäytännöt, hyväksyntäportit ja prosessin eristys komentotulkin suorittamista varten.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Lupa vaaditaan: $arg1';
  }

  @override
  String get permissionsNeeded => 'Luvat tarvitaan';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Käyttöoikeudet. Kukaan muu ei voi muuttaa sitä.';

  @override
  String get personOrChat => 'Henkilö tai chat';

  @override
  String get personaBehaviorNotes =>
      'Huomautuksia henkilöiden käyttäytymisestä';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Henkilökohtainen pääsytunnus Mattermost-botille.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Henkilökohtaiset kanavat ja suorat tukipinnat.';

  @override
  String get personalSelfChat => 'Henkilökohtainen itsekeskustelu';

  @override
  String get phoneNumber => 'Puhelinnumero';

  @override
  String get pickARunFromTheList =>
      'Valitse juoksu luettelosta nähdäksesi sen vaiheet.';

  @override
  String get pickARunFromTheList2 =>
      'Valitse juoksu vasemmalla olevasta luettelosta tutkiaksesi sen kulkua.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Valitse viimeisimmistä $arg1-keskusteluista tai lisää henkilö tai ryhmä itse.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Valitse, kuinka $arg1 käyttää tätä tiliä.';
  }

  @override
  String get pickOneToFillInThe =>
      'Valitse yksi tehtävä täytettäväksi. Kaikkea voi muokata jälkikäteen.';

  @override
  String get picksUpWhereYouLeftOff => 'Jatkaa siitä mihin jäit';

  @override
  String get plan => 'Suunnittele';

  @override
  String get planning => 'Suunnittelu';

  @override
  String get platform => 'Alusta';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Alusta $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Valitse aikataulu.';

  @override
  String get pleaseEnterAFilename => 'Anna tiedostonimi.';

  @override
  String get pleaseEnterAKey => 'Anna avain.';

  @override
  String get pleaseEnterAPrompt => 'Anna kehote.';

  @override
  String get pleaseEnterATaskName => 'Anna tehtävän nimi.';

  @override
  String get pleaseEnterTheMemoryContent => 'Anna muistin sisältö.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Anna, milloin tehtävän pitäisi suorittaa.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Valitse tili tai anna kelvollinen yhteystunnus.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Osoita NeoAgentia missä tahansa OpenAI-yhteensopivassa chatissa ';

  @override
  String get pointTheCameraAtTheCode =>
      'Osoita kamera uloskirjautuneen laitteen koodia kohti. Hyväksyntä pysyy tässä puhelimessa.';

  @override
  String get port => 'Portti';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'portti node_env julkisen url:n luottamus välityspalvelimen suojattujen evästeiden käyttöönotto';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Ensiluokkaista automaatiota aikataulu- ja integraatiotriggereillä.';

  @override
  String get prepareQrCode => 'Valmistele QR-koodi';

  @override
  String get preparingNeoagent => 'Valmistellaan NeoAgentia…';

  @override
  String get preparingNeoagent2 => 'NeoAgentin valmistelu';

  @override
  String get pressAndHoldForQuickCapture =>
      'Paina ja pidä painettuna saadaksesi nopean kaappauksen';

  @override
  String get pressKeysIsNotSupportedOn =>
      'paina näppäimiä ei tueta tällä alustalla.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Puristettu $arg1';
  }

  @override
  String get priceUnknown => 'Hinta tuntematon';

  @override
  String get primaryDisplay => 'Ensisijainen näyttö';

  @override
  String get privateChat => 'Yksityinen chat';

  @override
  String get privateChats => 'Yksityiset chatit';

  @override
  String get privateChats2 => 'yksityiset chatit';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Yksityiset chatit: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Yksityiset chatit $arg1 · ryhmät $arg2';
  }

  @override
  String get privateChatsOnly => 'Vain yksityiset chatit';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'yksityiset verkko-osoitteet eivät ole sallittuja.';

  @override
  String get profileEmailAndPersonalData =>
      'Profiili, sähköposti ja henkilötiedot';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Kysy ennen kuin NeoAgent pysyy ilmaisinalueella.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Välimuisti: $arg1 välimuistissa olevat tunnukset ';
  }

  @override
  String get promptCopied => 'Kehote kopioitu.';

  @override
  String get promptOrSchedule => 'kehotus tai aikataulu.';

  @override
  String get promptToPasteIntoAnotherAi =>
      'Kehotetaan liittää toiseen tekoälyyn';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Palveluntarjoajan linkitystä ei voitu aloittaa.';

  @override
  String get providerSignInCouldNotBe =>
      'Palveluntarjoajan kirjautumista ei voitu aloittaa.';

  @override
  String get providers => 'Palveluntarjoajat';

  @override
  String get providersEachAccountCanStillPick =>
      'Palveluntarjoajat; kukin tili voi silti valita oman mallinsa asetuksista. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Palveluntarjoajat, integraatiot, ääni ja valinnaiset ominaisuudet voidaan täydentää asetuksista milloin tahansa.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Julkiset julkaisu- ja vetopyyntöketjut, joihin on vastattu vain hyväksytyille henkilöille.';

  @override
  String get publicUrl => 'Julkinen URL-osoite';

  @override
  String get publicUrlAndAllowedOrigins =>
      'Julkinen URL-osoite ja sallitut alkuperät';

  @override
  String get publicUrlOverride => 'Julkisen URL-osoitteen ohitus';

  @override
  String get pullsTogetherTheDayAhead => 'Kokoaa seuraavan päivän';

  @override
  String get pushToTalk => 'Push-to-talk';

  @override
  String get qrBasedPhoneLinking => 'QR-pohjainen puhelinlinkitys';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'QR-kirjautuminen suoritettu, mutta NeoAgent ei voinut pitää istuntoa. Yritä uudelleen.';

  @override
  String get qrLoginCouldNotBeStarted => 'QR-kirjautumista ei voitu aloittaa.';

  @override
  String get qrLoginRequestHasExpired => 'qr-kirjautumispyyntö on vanhentunut';

  @override
  String get qrLoginRequestWasNotFound => 'qr-kirjautumispyyntöä ei löytynyt';

  @override
  String get qrPairing => 'QR-pariliitos';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'kyselyt suoritetaan; kaikki kirjoittava hylätään.';

  @override
  String get queryFilter => 'Kysely / suodatin';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Jonossa ohjaajana nykyiselle ajolle: $arg1';
  }

  @override
  String get quickstart => 'Pika-aloitus';

  @override
  String get quit => 'Lopeta';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'rain_start, tuulihälytys';

  @override
  String get ranAScriptInThePage => 'Ajoi skriptin sivulla';

  @override
  String ranArg1(Object? arg1) {
    return 'Ajettu $arg1';
  }

  @override
  String get rateLimits => 'Hintarajoitukset';

  @override
  String get readAnArtifact => 'Lue artefakti';

  @override
  String get readAndEditFilesInsideYour =>
      'Lue ja muokkaa tiedostoja NeoAgent Workspace -kansiossasi.';

  @override
  String readArg1(Object? arg1) {
    return 'Lue $arg1';
  }

  @override
  String get readError => 'Lukuvirhe';

  @override
  String get readFiles => 'Lue tiedostoja';

  @override
  String get readOnly => 'Vain luku';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Lue kansio ja tee yhteenveto pinosta, sisääntulokohdista ja sen suorittamisesta.';

  @override
  String get readThePage => 'Lue sivu';

  @override
  String get readTheUiTree => 'Lue käyttöliittymäpuuta';

  @override
  String get readWrite => 'Lue / kirjoita';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Lukee askeleet, sykkeen, unen, harjoituksen ja painon.';

  @override
  String get ready => 'Valmis';

  @override
  String get readyForFirstTimeSetup => 'Valmis ensiasennusta varten';

  @override
  String get readyToConnect => 'Valmis yhdistämään';

  @override
  String get recentChannelActivity => 'Kanavan viimeaikainen toiminta';

  @override
  String get recentChats => 'Viimeaikaiset keskustelut';

  @override
  String get recentDecisions => 'Viimeaikaiset päätökset';

  @override
  String get recentFailedRuns => 'Viimeaikaiset epäonnistuneet ajot';

  @override
  String get recentGroupDecisions => 'Viimeaikaiset ryhmäpäätökset';

  @override
  String get recentRuns => 'Viimeisimmät juoksut';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Viimeaikaiset juoksut kestävät noin $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Viimeisin palvelintulostus, uusin ensin.';

  @override
  String get recentUsage4Hours => 'Viimeaikainen käyttö (4 tuntia)';

  @override
  String get recents => 'Viimeaikaiset';

  @override
  String get recipientField => 'Vastaanottaja-kenttä';

  @override
  String get reconnectOrFinishSetup =>
      'Yhdistä uudelleen tai viimeistele asennus';

  @override
  String get reconnectingThisDevice => 'Yhdistetään tätä laitetta uudelleen…';

  @override
  String get recurring => 'Toistuva';

  @override
  String get redirectUri => 'Uudelleenohjaus URI';

  @override
  String get redoOnboarding => 'Toista käyttöönotto';

  @override
  String get refresh => 'Päivitä';

  @override
  String get refreshCode => 'Päivitä koodi';

  @override
  String get refreshNow => 'Päivitä nyt';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Päivitä Android-näyttö ja yritä uudelleen.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Kieltäytyä lähettämästä, ellei yhteys päivity TLS:ään.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'riippumatta alla olevista luokkakohtaisista asetuksista.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Rekisteröi $arg1 avustajan kutsukulkuun.';
  }

  @override
  String get registrationIsClosed => 'ilmoittautuminen on suljettu';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'rekisteröinti rekisteröi uudet tilit mahdollistaa kirjautumisen';

  @override
  String get rejectInvalidTlsCertificates =>
      'Hylkää virheelliset TLS-varmenteet';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'vapauttaa ja käynnistää uudelleen. Yhdistetyt sovellukset muodostavat yhteyden uudelleen, kun ne ovat palanneet.';

  @override
  String get releaseChannel => 'Vapauta kanava';

  @override
  String get releaseCommitBranchNode => 'vapauta sitoutumishaarasolmu';

  @override
  String get releaseWhenYouAreDone => 'Vapauta, kun olet valmis.';

  @override
  String get reloadNow => 'Lataa nyt uudelleen';

  @override
  String get rememberThisChoice => 'Muista tämä valinta';

  @override
  String get remove => 'Poista';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Poistetaanko \"$arg1\" ja sen tallennetut vaiheet ajohistoriasta?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Poista \"$arg1\" ydinmuistista.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Poistetaanko $arg1-avain?';
  }

  @override
  String get removeEraseGdprUser => 'poista poista gdpr-käyttäjä';

  @override
  String get removeSmtpPassword => 'Poista SMTP-salasana';

  @override
  String get removeTheSmtpPassword => 'Poistetaanko SMTP-salasana?';

  @override
  String get rename => 'Nimeä uudelleen';

  @override
  String get renameSecurityKey => 'Nimeä suojausavain uudelleen';

  @override
  String get renameSession => 'Nimeä istunto uudelleen';

  @override
  String get repairAndRetry => 'Korjaa ja yritä uudelleen';

  @override
  String get repairDesktop => 'Korjaa työpöytä';

  @override
  String get repeat => 'Toista';

  @override
  String get repliesWhenTagged => 'Vastaa tunnisteella';

  @override
  String get replyToAddress => 'Vastaus-osoite';

  @override
  String replyToArg1(Object? arg1) {
    return 'Vastaa käyttäjälle $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Arkiston on oltava muodossa omistaja/varasto.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Toista kuvaamani bugi, etsi perimmäinen syy ja korjaa se regressiotestillä.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'pyyntö epäonnistui osoitteessa http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Pyyntö epäonnistui HTTP $arg1:n kanssa';
  }

  @override
  String get requestPermissions => 'Pyydä käyttöoikeuksia';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Pyyntö $arg1:lle epäonnistui ennen kuin taustaohjelma vastasi.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Pyydetty $arg1';
  }

  @override
  String get requireStarttls => 'Vaadi STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Vaaditaan HTTPS:n tai TLS-välityspalvelimen takana. Koskee palvelimen jälkeen ';

  @override
  String get requiredExampleBerlinDe => 'Pakollinen. Esimerkki: Berliini, DE';

  @override
  String get requiredFormatOwnerRepo => 'Pakollinen. Muoto: omistaja/repo';

  @override
  String get reserveAssistantHotkey => 'Varausavustajan pikanäppäin';

  @override
  String get reset => 'Nollaa';

  @override
  String get resetPassword => 'Palauta salasana';

  @override
  String get resetView => 'Palauta näkymä';

  @override
  String get responsibilities => 'Vastuut';

  @override
  String get restart => 'Käynnistä uudelleen';

  @override
  String get restartToFinishTheUpdate =>
      ' Viimeistele päivitys käynnistämällä se uudelleen.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Palautetaan edellinen NeoAgent-ajoaika';

  @override
  String get restrictDelegationTargets => 'Rajoita delegointitavoitteita';

  @override
  String get result => 'Tulos';

  @override
  String get resultDelivery => 'Tulos Toimitus';

  @override
  String get resultOneClickAddsOneYou =>
      'tuloksena. Yksi napsautus lisää yhden; voit muokata sitä myöhemmin.';

  @override
  String get results => 'Tulokset';

  @override
  String get retry => 'Yritä uudelleen';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Uudelleen käytettävä · käytetty $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Tarkista sitomattomat muutokset';

  @override
  String get revoke => 'Peruuta';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Peru järjestelmänvalvoja ensin komennolla \"neoagent admin revoke $arg1\"';
  }

  @override
  String get revokeThisLink => 'Perutaanko tämä linkki?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Huoneen eräikkuna: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Kierrä jatkaaksesi';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'rivit. Lisää LIMIT tai kapeampi WHERE-lause nähdäksesi ';

  @override
  String get rule => 'Sääntö';

  @override
  String get run => 'Suoritus';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Suorita mielivaltaisia komentoja koneellasi tai virtuaalikoneellasi.';

  @override
  String get runAt => 'Juokse klo';

  @override
  String get runCompleted => 'Ajo suoritettu';

  @override
  String get runFailed => 'Juoksu epäonnistui';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Suorita git diff, tarkasta sitomattomat muutokset virheiden ja tyyliongelmien varalta ja tee yhteenveto löytämistäsi asioista.';

  @override
  String get runNotFound => 'Suoritusta ei löydy';

  @override
  String get runNow => 'Suorita nyt';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Käytä saapuvia henkilökohtaisia WhatsApp-viestejä.';

  @override
  String get runQuery => 'Suorita kysely';

  @override
  String get runShellCommandsOrInstallApps =>
      'Suorita komentotulkkikomentoja tai asenna sovelluksia Android-laitteellesi.';

  @override
  String get runStarted => 'Juoksu alkoi';

  @override
  String get runStatus => 'Suoritustila';

  @override
  String get runStopped => 'Juoksu pysähtyi';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Suorita päätekomentoja ja avaa sovelluksia tai verkkosivuja.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Suorita tämä palvelin: tilit, päivitykset, palveluntarjoajat, määritykset ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Suorita, kun vastaava Gmail-viesti saapuu.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Suorita, kun vastaava Outlook-sähköposti saapuu.';

  @override
  String get runWhenANewIssueMatching =>
      'Suorita, kun uusi suodattimiasi vastaava ongelma avataan arkistossa.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Suorita, kun suodattimiasi vastaava uusi NeoRecall-muisti luodaan.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Suorita, kun ilmoitus saapuu laitteellesi.';

  @override
  String get runWhenASlackMessageMatches =>
      'Suorita, kun Slack-viesti vastaa valittua laajuutta.';

  @override
  String get runWhenATeamsChatMessage =>
      'Suorita, kun Teamsin chat-viesti vastaa valittua laajuutta.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Suorita, kun määritetyt säätapahtumat on ennustettu sijainnille.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'juosta. Kun mikä tahansa malli on pois päältä, toimittajat lisäävät mallit ';

  @override
  String get running => 'Käynnissä';

  @override
  String runningArg1(Object? arg1) {
    return 'Käynnissä $arg1';
  }

  @override
  String get runningTask => 'Juokseva tehtävä';

  @override
  String get runningTool => 'Juokseva työkalu';

  @override
  String get runs => 'Suoritukset';

  @override
  String get runsEveryDayAtTheSelected => 'Toimii joka päivä valittuna aikana.';

  @override
  String get runsFourTimesPerHour => 'Käynnistyy neljä kertaa tunnissa.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— suoritukset, viestit, muistit, integraatiot, tiedostot ja ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'ajot, viestit, muistit, integraatiot, tiedostot ja istunnot. ';

  @override
  String get runsMondayThroughFriday => 'Kulkee maanantaista perjantaihin.';

  @override
  String get runsOnSelectedWeekdays => 'Toimii valittuina arkipäivinä.';

  @override
  String get runsOncePerHour => 'Käynnistyy kerran tunnissa.';

  @override
  String get runsOncePerMonthOnThe =>
      'Toimii kerran kuukaudessa valittuna päivänä.';

  @override
  String get runsOnlyWhenYouPressRun => 'Toimii vain, kun painat Suorita nyt.';

  @override
  String get runsPerDay => 'Juokse päivässä';

  @override
  String get runsPerDay30Days => 'Käynnistyy päivässä (30 päivää)';

  @override
  String get runsThatCompleted => 'Suorittaa sen valmiiksi';

  @override
  String get runsThisWeek => 'Juokse tällä viikolla';

  @override
  String get runsToday => 'Juokse tänään';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Ajot, työkalut, muisti, aikataulut, taidot ja MCP ovat kaikki saatavilla täältä.';

  @override
  String get runsTwicePerHour => 'Käynnistyy kahdesti tunnissa.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Suoritukset palautuvat $arg1:n jaettuun palvelinavaimeen, jos sellainen on määritetty. Tätä ei voi kumota.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Käyttöaika $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Kesto: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Ajonaikaiset asetukset, joilla tämä palvelin alkoi. Muokkaa niitä alla ';

  @override
  String get runtimeSetupRequired => 'Suoritusajan asetukset vaaditaan';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Ajonaikaisen allekirjoituksen julkisen avaimen on oltava 32 tavua.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Tallenna';

  @override
  String get saveATrelloApiKeyFor =>
      'Tallenna Trello API -avain tälle agentille ja yhdistä sitten yksi Trello-tili turvallisesti. Tilitunnus tallennetaan palvelimelle ja sitä käytetään vain tälle agentille.';

  @override
  String get saveAccount => 'Tallenna tili';

  @override
  String get saveChanges => 'Tallenna muutokset';

  @override
  String get saveCloudComputerSettings => 'Tallenna pilvitietokoneen asetukset';

  @override
  String get saveConnect => 'Tallenna ja yhdistä';

  @override
  String get saveDefaults => 'Tallenna oletusasetukset';

  @override
  String get saveDiagnosticReport => 'Tallenna diagnostiikkaraportti';

  @override
  String get saveEmail => 'Tallenna sähköposti';

  @override
  String get saveEmailSettings => 'Tallenna sähköpostiasetukset';

  @override
  String get saveGeneralSettings => 'Tallenna yleisasetukset';

  @override
  String get saveName => 'Tallenna nimi';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Tallenna NeoAgentin asennusdiagnostiikka';

  @override
  String get saveOnly => 'Tallenna vain';

  @override
  String get saveSetup => 'Tallenna asetukset';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Tallenna nämä palautuskoodit nyt. Niitä ei näytetä uudelleen.';

  @override
  String get savedDeliveryDestination => 'Tallennettu toimituskohde';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Tallennetut nopeusrajat @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Skannaa NeoAgent-kirjautumiskoodi';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Skannaa NeoAgent-parin muodostava QR toiselta laitteelta ja hyväksy se tästä käynnistysistunnosta.';

  @override
  String get scanLoginQr => 'Skannaa sisäänkirjautumis QR';

  @override
  String get scanPairingQr => 'Skannaa pariliitos QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Skannaa QR-sisäänkirjautumispyynnöt uloskirjautuneilta laitteilta ja hyväksy ne tästä todistetusta mobiiliistunnosta.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Skannaa loppuun $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone => 'Skannaa puhelimesi NeoAgentilla';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Tarkistaa uudet sähköpostit ja lähettää ping-lähetyksen vain, kun jollakin on merkitystä.';

  @override
  String get schedule => 'Aikataulu';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'sovittu aika. Kun juoksut on mitattu, se alkaa aikaisemmin.';

  @override
  String get screen => 'Näyttö';

  @override
  String get screenAction => 'näytön toiminta';

  @override
  String get scrollIsNotSupportedOnThis => 'scrollia ei tueta tällä alustalla.';

  @override
  String get scrollToBottom => 'Vieritä alas';

  @override
  String get search => 'Etsi';

  @override
  String get search2 => 'Hae…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Hae järjestelmänvalvojan asetuksia (esim. SMTP, Ollama, lokit)';

  @override
  String get searchAgain => 'Etsi uudelleen';

  @override
  String get searchByUsernameOrEmail =>
      'Hae käyttäjätunnuksella tai sähköpostilla';

  @override
  String get searchChannels => 'Hae kanavia';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Hae löydettyjä viestikanavia, yhteystietoja, ryhmiä ja viimeaikaisia keskusteluja.';

  @override
  String get searchGroups => 'Etsi ryhmiä';

  @override
  String get searchMemory => 'Etsi muistista';

  @override
  String get searchModelsOrProviders => 'Hae malleja tai palveluntarjoajia';

  @override
  String get searchModelsOrProviders2 => 'Hae malleja tai palveluntarjoajia…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Hae viimeaikaisia ihmisiä ja ryhmiä';

  @override
  String get searchSessions => 'Hae istuntoja';

  @override
  String get searchSettings => 'Hakuasetukset';

  @override
  String get searchTitleModelTriggerRunId =>
      'Hae otsikkoa, mallia, laukaisinta, suoritustunnusta';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Hakutyökalut, integraatiot ja taidot';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Haettiin koodia \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Haettiin tiedostoja \"$arg1\"';
  }

  @override
  String get secretField => 'Salainen kenttä';

  @override
  String get secureCookies => 'Turvalliset evästeet';

  @override
  String get security => 'Turvallisuus';

  @override
  String get securityKey => 'Suojausavain';

  @override
  String get securityKeyPromptWasDismissed =>
      'Suojausavaimen kehote hylättiin.';

  @override
  String get securityKeySignInCompletedBut =>
      'Suojausavaimen sisäänkirjautuminen valmis, mutta NeoAgent ei voinut pitää selainistuntoa. Kirjaudu uudelleen sisään.';

  @override
  String get securityKeySignInCouldNot =>
      'Suojausavaimella kirjautumista ei voitu aloittaa.';

  @override
  String get securityKeys => 'Suojausavaimet';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Suojausavaimet ovat saatavilla vain NeoAgent-verkkosovelluksessa.';

  @override
  String get seeAll => 'Katso kaikki';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Katso, mitä NeoAgent-palvelinta tämä ikkuna käyttää, ja suorita taustaohjelma tässä tietokoneessa.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'nähdä käyttäjänimesi ja nämä asetukset, ei koskaan keskustelujasi, muistojasi ';

  @override
  String get selectARun => 'Valitse juoksu';

  @override
  String get selectASessionToSeeIts =>
      'Valitse istunto nähdäksesi sen tietokoneen, tiedostot ja muutokset.';

  @override
  String get selectAll => 'Valitse kaikki';

  @override
  String get selectAll2 => 'Valitse Kaikki';

  @override
  String selectArg1(Object? arg1) {
    return 'Valitse $arg1';
  }

  @override
  String get selectTrigger => 'Valitse Trigger';

  @override
  String get send => 'Lähetä (⌘↵)';

  @override
  String get send2 => 'Lähetä';

  @override
  String get sendATaskFromChatAnd =>
      'Lähetä tehtävä chatista ja sen suoritushistoria näkyy täällä.';

  @override
  String get sendItToATeammateWith =>
      'lähetä se joukkuetoverillesi, jolla on tili tällä palvelimella.';

  @override
  String get sendLink => 'Lähetä linkki';

  @override
  String get sendPath => 'Lähetä polku';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Lähetä POST / PUT / DELETE -pyynnöt ulkoisille sovellusliittymille.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Lähetä tämä linkki vain henkilölle, jolle se on tarkoitettu. Se näytetään kerran; ';

  @override
  String get senderAddress => 'Lähettäjän osoite';

  @override
  String get senderFilterOptional => 'Lähettäjäsuodatin (valinnainen)';

  @override
  String get sentSharedAttachments => 'Lähetetyt jaetut liitteet.';

  @override
  String get separateAccount => 'Erillinen tili';

  @override
  String get server => 'Palvelin';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Palvelimen oletusarvo ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Palvelin on oletusarvoinen sovelluksen sisäisille äänipuheluille. Puhelut toimivat livenä ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'itse palvelin: tilit, palveluntarjoajat ja määritykset.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Palvelin, nimimerkki, kanava ja valinnainen TLS';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'palvelimen ulostulon konsolin varoitukset virheet kopio';

  @override
  String get serverProviderCredentials => 'Palvelimen tarjoajan tunnistetiedot';

  @override
  String get serverUrl => 'Palvelimen URL-osoite';

  @override
  String get serverUsageLimitsDonTApply =>
      'Palvelimen käyttörajoitukset eivät koske malleja, jotka toimivat omalla avaimellasi.';

  @override
  String get serviceEmail => 'Palvelun sähköposti';

  @override
  String get serviceEmailIsNotConfigured =>
      'palvelusähköpostia ei ole määritetty';

  @override
  String get serviceEmailSmtp => 'Palvelusähköposti (SMTP)';

  @override
  String get sessionActions => 'Istuntotoiminnot';

  @override
  String get sessions => 'Istunnot';

  @override
  String get sessions2 => 'ISTUNTOJA';

  @override
  String get sessionsArePinnedToAFolder =>
      'Istunnot on kiinnitetty kansioon ja tietokoneeseen. Aloita suunnittelu, rakentaminen, testaus ja toimitus täältä.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'istunnot (GDPR Art. 17). Järjestelmänvalvojan tilejä ei voi poistaa ';

  @override
  String get sessionsLogoutRevokeForce =>
      'istunnot uloskirjautuminen peruuttaa voimassa';

  @override
  String get setBlockAskAllowPerTool =>
      'Aseta lohko / kysy / salli työkaluluokkakohtaisesti tai valitse yleinen tila.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Asenna NeoAgent tälle tietokoneelle';

  @override
  String get setUpOrConnectNeoagent => 'Asenna tai yhdistä NeoAgent';

  @override
  String get setUrl => 'Aseta URL-osoite';

  @override
  String get settings => 'Asetukset';

  @override
  String get settingsAndCannotBeUndone => 'asetuksia, eikä niitä voi kumota.';

  @override
  String get settingsArea => 'Asetukset-alue';

  @override
  String get settingsAreas => 'Asetusalueet';

  @override
  String get setup => 'Asennus';

  @override
  String get setupDetails => 'Asennustiedot';

  @override
  String get setupRequired => 'Asennus vaaditaan';

  @override
  String get setupWasCancelled => 'Asennus peruutettiin.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Jaetut liitteet NeoAgent-asiakasohjelmasta:';

  @override
  String get sharedFromAnotherApp => 'Jaettu toisesta sovelluksesta';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Jaetut palveluntarjoajan avaimet on määritetty palvelimella. Jos haluat käyttää sen sijaan omaa API-avainta tai mukautettua päätepistettä, siirry kohtaan Lisäasetukset → Tuo oma avain.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Jaettu NeoAgent-chatin ja sen muistin kanssa.';

  @override
  String get shellCommands => 'Shell-komennot';

  @override
  String showAllArg1(Object? arg1) {
    return 'Näytä kaikki $arg1';
  }

  @override
  String get showEarlier => 'Näytä aikaisemmin';

  @override
  String get showEveryStep => 'Näytä jokainen askel';

  @override
  String get showTools => 'Näytä työkalut';

  @override
  String get showWorkbenchJ => 'Näytä työpöytä (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Näytössä ensimmäinen $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Näkyy sivupalkissa. Jätä tyhjäksi käyttääksesi käyttäjätunnustasi.';

  @override
  String get signIn => 'Kirjaudu sisään';

  @override
  String get signInCompletedButNeoagentCould =>
      'Kirjautuminen valmis, mutta NeoAgent ei voinut pitää selainistuntoa. Kirjaudu uudelleen sisään. Jos tämä toistuu, tarkista taustapalvelimen istunnon evästeasetukset.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Kirjautuminen valmis, mutta NeoAgent ei voinut pitää selainistuntoa. Kirjaudu uudelleen sisään. Jos tämä toistuu, backend-istunnon evästettä ei todennäköisesti säilytetä.';

  @override
  String get signInToThisNeoagentServer =>
      'Kirjaudu tähän NeoAgent-palvelimeen ennen QR-koodin skannaamista.';

  @override
  String get signInWithAHardwareKey =>
      'Kirjaudu sisään laitteistoavaimella tai salasanalla salasanasi sijaan. ';

  @override
  String get signInWithASecurityKey => 'Kirjaudu sisään suojausavaimella';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Kirjaudu sisään $arg1:llä';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Hyväksy NeoAgent $arg1-tililläsi. Ei avainta kopioitavaksi.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return '$arg1:tä odotellessa. Viimeistele selaimessasi.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Liitä $arg1-koodi';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Kun olet hyväksynyt NeoAgentin, $arg1 näytti kertaluontoisen koodin. Liitä se tähän.';
  }

  @override
  String get signInCode => 'Kirjautumiskoodi';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Kirjautunut sisään $arg1:lla.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Kirjautuminen epäonnistui: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Kirjaudu sisään samalla sähköpostiosoitteella ja pääsalasanalla, jota käytät Bitwardenissa. Pääsalasanaa ja kaksivaiheista koodia käytetään vain sisäänkirjautumiseen, eikä niitä koskaan tallenneta tai lähetetä tekoälylle.';

  @override
  String get signOut => 'Kirjaudu ulos';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Kirjaudu ulos @$arg1 kaikkialta?';
  }

  @override
  String get signOutEverywhere => 'Kirjaudu ulos kaikkialta';

  @override
  String get signalCliRestApiBridge => 'signal-cli REST API -silta';

  @override
  String get signalCliServerUrl => 'signal-cli-palvelimen URL-osoite';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Allekirjoitettu @$arg1 jokaisen istunnon jälkeen.';
  }

  @override
  String get signedInDevices => 'Sisäänkirjautuneet laitteet';

  @override
  String get signedInWithin24Hours => 'Kirjautunut sisään 24 tunnin sisällä';

  @override
  String get signingSecret => 'Allekirjoituksen salaisuus';

  @override
  String sinceArg1(Object? arg1) {
    return '$arg1:stä lähtien';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'alkaen $arg1';
  }

  @override
  String get singleMessage => 'Yksittäinen viesti';

  @override
  String get singleUse => 'Kertakäyttöinen';

  @override
  String get skill => 'Taito';

  @override
  String get skillChanges => 'Taitojen muutokset';

  @override
  String get skillContent => 'Taitojen sisältö';

  @override
  String get skills => 'Taidot';

  @override
  String get skip => 'Ohita';

  @override
  String get skipForNow => 'Ohita toistaiseksi';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Ohita tämä tehtävä ennen kuin se kutsuu mallia.';

  @override
  String get slackMessageReceived => 'Hidas viesti vastaanotettu';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Nuku $arg1-istunnot';
  }

  @override
  String get smartSelector => 'älykäs valitsin';

  @override
  String get smartSelector2 => 'Älykäs valitsin';

  @override
  String get smartSelectorPool => 'Smart Selector Pool';

  @override
  String get smtpHost => 'SMTP-isäntä';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'smtp-sähköpostin lähettäjän salasana tls-vahvistusilmoitukset nollataan';

  @override
  String get smtpPassword => 'SMTP-salasana';

  @override
  String get smtpPort => 'SMTP-portti';

  @override
  String get smtpPortMustBeAWhole =>
      'SMTP-portin on oltava kokonaisluku väliltä 1 - 65535.';

  @override
  String get smtpUsername => 'SMTP-käyttäjänimi';

  @override
  String get soTheRunStartsThatMuch => 'joten juoksu alkaa paljon aikaisemmin.';

  @override
  String get socialBehaviorOff => 'Sosiaalinen käyttäytyminen pois';

  @override
  String get socialIntelligence => 'sosiaalinen älykkyys';

  @override
  String get socialIntelligence2 => 'Sosiaalinen älykkyys';

  @override
  String get socialObservability => 'Sosiaalinen havaittavuus';

  @override
  String get socialReach => 'sosiaalinen ulottuvuus';

  @override
  String get socialReach2 => 'Sosiaalinen kattavuus';

  @override
  String get socialReach3 => 'Sosiaalinen tavoittavuus';

  @override
  String get socialReachUpdated => 'Social Reach päivitetty.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Sosiaaliset lähteet agentit voivat lukea suoraan, mukaan lukien syötteet, tietovarastot, Reddit, X, videot ja evästeiden tukemat markkinatiedot.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Jotain meni pieleen. Yritä uudelleen.';

  @override
  String get source => 'lähde';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Tila- tai keskustelutunnus, jota käytetään, kun tämä agentti aloittaa keskustelun.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Space-webhook- ja sovellussoittotuki';

  @override
  String get speaking => 'Puhuminen';

  @override
  String get speechToSpeechModelUsingThe =>
      'puheesta puheeksi -malli käyttämällä OpenAI- tai Google-avainta alla ';

  @override
  String get speechToText => 'Puhe tekstiksi';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Puhe tekstiksi litteroi äänimuistiinpanot ja sanelun. Auto käyttää OpenAI:ta, Geminiä tai Deepgramia sen mukaan, kummalla on API-avain. Äänivastausmalli on chat-malli, joka vastaa äänimuistiinpanoihin.';

  @override
  String get sqlConsole => 'SQL-konsoli';

  @override
  String get stable => 'Vakaa';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable asentaa uusimman julkaistun taustaversion.';

  @override
  String get stackTrace => 'pinon jälki';

  @override
  String get standard => 'Vakio';

  @override
  String get standardView => 'Vakionäkymä';

  @override
  String get start => 'Aloita';

  @override
  String get startASessionToPlanOr =>
      'Aloita istunto suunnitella tai rakentaa NeoAgentilla.';

  @override
  String get startAndroid => 'Käynnistä Android';

  @override
  String get startComputer => 'Käynnistä tietokone';

  @override
  String get startFullSetup => 'Aloita täysi asennus';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Aloita asennus';

  @override
  String get startTalking => 'Aloita puhuminen';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Käynnistä ensin Android-puhelin ja pudota sitten .apk- tai .apks-tiedosto tähän.';

  @override
  String get startTheServerLaterFromThe =>
      'Käynnistä palvelin myöhemmin luettelosta, kun asetukset on tallennettu.';

  @override
  String get startWithARecommendedTask => 'Aloita suositellulla tehtävällä';

  @override
  String get startingAndroid => 'Android käynnistyy';

  @override
  String get startingYourComputer => 'Tietokoneen käynnistäminen';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Alkaa xoxb-. Slack-sovelluksesi kirjautumistiedoistasi.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Error: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'stats runs tokens käyttäjäkaaviot onnistumisprosentti';

  @override
  String get status => 'Tila';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'tilatietokannan ajonaikaiset vm-palveluntarjoajat';

  @override
  String get statusIsNotLoadedYet => 'Tilaa ei ole vielä ladattu.';

  @override
  String get stayManagedByYou => 'pysy hallussasi.';

  @override
  String get stayOnTheCall => 'Pysy puhelussa';

  @override
  String get stayedQuiet => 'Pysyi hiljaa';

  @override
  String get steering => 'OHJAUS';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'VAIHE $arg1 OF $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Vaiheet $arg1';
  }

  @override
  String get stop => 'Pysäytä';

  @override
  String get stop2 => 'Pysäytä (⌘.)';

  @override
  String get stopManaging => 'Lopeta hallinta';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Lopetetaanko $arg1:n hallinta?';
  }

  @override
  String get stopRun => 'Lopeta juoksu';

  @override
  String get stopSpeaking => 'Lopeta puhuminen';

  @override
  String get stoppedBeforeCompletion => 'Pysäytettiin ennen valmistumista';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Error: $arg1';
  }

  @override
  String get storage => 'Varastointi';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'tallennetaan salattuna ja käytetään vain omiin ajoihin.';

  @override
  String get storedMetrics => 'Tallennetut mittarit';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Tallentaa vain Bitwarden-istuntoavaimen salattuna tälle palvelimelle, joten yhteydet selviävät uudelleenkäynnistyksistä. Voit lukita sen milloin tahansa.';

  @override
  String get strong => 'Vahva';

  @override
  String get strongPassword => 'Vahva salasana.';

  @override
  String get subAgent => 'Aliagentti';

  @override
  String get subagentUpdate => 'Subagentin päivitys';

  @override
  String get subagentUpdate2 => 'Subagentin päivitys.';

  @override
  String get successRate => 'Menestysprosentti';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Ehdotukset: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Tee yhteenveto viimeisestä juoksustani';

  @override
  String get supportUrl => 'Tuen URL-osoite';

  @override
  String get supportedRainStartSnowStartWind =>
      'Tuetut: rain_start, snow_start, wind_alert, temperature_bove, temperature_below';

  @override
  String get switchAgent => 'Vaihda agenttia';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Symboliset linkit eivät ole sallittuja NeoAgent Workspace -poluissa.';

  @override
  String get syncNow => 'Synkronoi nyt';

  @override
  String get synologyChat => 'Synology Chat';

  @override
  String get systemPrivacySettings => 'Järjestelmän tietosuoja-asetukset';

  @override
  String get tableInfoUsers => 'Taulukon tiedot (käyttäjät)';

  @override
  String get tagsOnly => 'Vain tunnisteet';

  @override
  String get tasks => 'Tehtävät';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Tehtävät toimivat itsestään ja lähettää sinulle viestin ';

  @override
  String get teach => 'Opeta';

  @override
  String get teachingInProgress => 'Opetus käynnissä';

  @override
  String get team => 'Joukkue';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Tiimin linkit eivät koskaan tee kenestäkään palvelimen järjestelmänvalvojaa. Järjestelmänvalvojat suorittavat ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Tiimitilat, huoneet, kanavat ja live-yhteisöt.';

  @override
  String get teamsMessageReceived => 'Joukkueen viesti vastaanotettu';

  @override
  String get templates => 'Mallit';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Väliaikaiset asennustiedostot siivotaan myöhemmin.';

  @override
  String get tenantId => 'Vuokralaisen tunnus';

  @override
  String get testConnection => 'Testaa yhteys';

  @override
  String get testConnection2 => 'Testaa yhteys';

  @override
  String get textChat => 'Teksti & Chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'jotka lisäsivät oman avaimensa, jatkavat sen käyttöä.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Sähköpostiosoite kuuluu jo olemassa olevaan tiliin. Kirjaudu ensin sisään ja linkitä sitten Google tilin asetuksista.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Tämä sähköposti on jo linkitetty toiseen tiliin.';

  @override
  String get thatQrCodeIsNotA =>
      'Tämä QR-koodi ei ole NeoAgent-kirjautumispyyntö.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Tämä QR-koodi ei ole NeoAgent-pariliitospyyntö.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Tämä suojausavain on jo rekisteröity tälle tilille.';

  @override
  String get theAddress => 'Osoite';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'BlueBubbles-palvelimesi osoite.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Osoite, jolla ihmiset ja OAuth-palveluntarjoajat tavoittavat ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Agentti lukee mainitsemasi ajat ja suorittaa ajoitetut tehtävät tällä aikavyöhykkeellä.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Välittäjä kysyy ennen jokaista herkkää työkalua, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Agentti jättää tämän taidon huomioimatta.';

  @override
  String get theAppCouldNotReachThis =>
      'Sovellus ei saanut yhteyttä tähän NeoAgent-asetuksiin. Tarkista verkkoyhteytesi tai varmista, että palvelun URL-osoite on oikea.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Selain esti pyynnön $arg1:lle sisällön suojauskäytännön vuoksi.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Selain esti vaaditun pyynnön sisällön suojauskäytännön vuoksi.';

  @override
  String get theCloudWorkspace => 'pilvityötila';

  @override
  String get theComputerCouldNotStart => 'Tietokone ei voinut käynnistyä';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Tietokone tarvitsee lisää vapaata levytilaa NeoAgent-isännässä. Vapauta tilaa ja yritä sitten uudelleen.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Tietokoneen käyttöaika kaipaa korjausta. Suorita NeoAgent Doctor ja yritä sitten uudelleen.';

  @override
  String get theConnectionTestFailed => 'Yhteystesti epäonnistui.';

  @override
  String get theDesktopDidNotStart => 'Työpöytä ei käynnistynyt';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Löytynyt NeoAgent palautti epätäydellisiä henkilötietoja.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Löytynyt NeoAgent käyttää ei-tuettua asennusprotokollaa.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Löytynyt palvelu ei ole NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Ladattu NeoAgent-ajoaika ei läpäissyt vahvistusta.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'Google Chat -tilan webhook, johon tämän edustajan tulee lähettää viestejä.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Asennusohjelma ei ole enää saatavilla.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Interaktiivinen Linux-työpöytä on saatavilla NeoAgent-verkkosovelluksessa.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Johdanto ei ole saatavilla tällä laitteella.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Uusimmat näkyvät kaikilla tileillä.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Viimeisin synkronointiikkuna päättyi $arg1 eikä löytänyt uusia Health Connect -tietueita. Alla tallennetut tiedot ovat peräisin aikaisemmista synkronoinneista.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Linuxin graafinen istunto ei ole käynnissä.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Live-äänimalli ei vastannut. Yritä uudelleen.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'Paikallinen NeoAgent-komento lopetettiin koodilla $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Paikallinen NeoAgent-komento aikakatkaistiin.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Paikallinen NeoAgent-ajonaika tarvitsee korjausta.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Paikallinen suoritusaika kaipaa korjausta ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Paikallisen käyttäjän kotihakemisto ei ole käytettävissä.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Sähköpostitili NeoAgent lähettää kirjautumisvahvistuksia, kirjautumista ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Pääagentti luodaan automaattisesti tarvittaessa.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Vastaava NeoAgent-ajoaika puuttuu tästä julkaisusta.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'Tärkein saapuva webhook, johon tämän edustajan pitäisi lähettää.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Mallit, joiden välillä Smart Selector reitittää automaattisesti.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'NeoAgent-taustalataus ei vastannut luetteloa.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'NeoAgent-taustaohjelmiston lataus oli epätäydellinen.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Tämän tietokoneen NeoAgent-taustajärjestelmä ei vastaa portissa ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'NeoAgent-taustajärjestelmän suoritusaikaa ei voitu ladata.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'NeoAgent-taustajärjestelmältä kesti liian kauan vastata $arg1:lle.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'NeoAgent-käyttöönotto vastasi HTTP 402:lla normaalin 401:n sijaan virheellisten valtuustietojen vuoksi. Tarkista käänteisen välityspalvelimen, todennusyhdyskäytävän tai maksuihin liittyvät säännöt kyseisellä palvelimella.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'NeoAgent-käyttöönotto vastasi HTTP 402:lla.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'NeoAgent-asennus vastasi HTTP 402:lla. Tarkista käänteisen välityspalvelimen, todennusyhdyskäytävän tai maksuihin liittyvät säännöt kyseisessä palvelimessa.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'NeoAgent-esiintymä, johon tämä sovellus on yhdistetty.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'NeoAgent-julkaisupalvelu palautti virheelliset tiedot.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'NeoAgent-ajonaikaisen artefaktin metatiedot ovat virheelliset.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'NeoAgentin ajonaikainen luettelo ei läpäissyt allekirjoituksen tarkistusta.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'NeoAgentin ajonaikaisessa luettelossa ei ole artefakteja.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'NeoAgentin ajonaikainen luettelon allekirjoitus on virheellinen.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'BlueBubblesissa määrittämäsi salasana.';

  @override
  String get thePeopleYouManageStayWith =>
      'Hallitsemasi ihmiset pysyvät kanssasi.';

  @override
  String get theProviderAnswers => 'palveluntarjoaja vastaa.';

  @override
  String get theQueryReturnedNoRows => 'Kysely ei palauttanut rivejä.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Pyydetty työpöytänäyttö ei ole käytettävissä.';

  @override
  String get theRest => 'loput.';

  @override
  String get theRestEndpointForYourSignal =>
      'Signal-cli-instanssisi REST-päätepiste.';

  @override
  String get theRunIsPausedUntilYou => 'Juoksu keskeytetään, kunnes vastaat.';

  @override
  String get theRunStartsAtTheScheduled => 'Juoksu alkaa sovittuna aikana.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Ajonaika on kevyt Debian Linux -työpöytä, jossa on Chromium, PCManFM, Mousepad, LXTerminal, Python, Git ja tavalliset komentorivityökalut. Sen kapasiteettia hallinnoi NeoAgent-isäntä.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Suojausavaimen rekisteröintiä ei voitu aloittaa.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'palvelin säilyttää siitä vain sormenjäljen.';

  @override
  String get theServerOnThisComputerIs =>
      'Tämän tietokoneen palvelin ei ole käynnissä';

  @override
  String get theServerReportedNoHealthChecks =>
      'Palvelin ei ilmoittanut terveystarkastuksista.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'Tämän botin käyttämä signaalin puhelinnumero.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Teams-saapuvien verkkohook, johon tämän edustajan tulee lähettää.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Kahden tekijän haaste vanheni. Kirjaudu uudelleen sisään.';

  @override
  String get theTwoFactorCodeIsNot => 'Kaksivaiheinen koodi ei kelpaa.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Vahvistettua ajonaikaista pakettia ei voitu merkitä suoritettavaksi.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Vahvistetusta suoritusaikapaketista puuttuu vaaditut tiedostot.';

  @override
  String get theWebAppCouldNotReach =>
      'Verkkosovellus ei saanut yhteyttä NeoAgent-taustajärjestelmään.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Verkkosovellus ei saanut yhteyttä NeoAgent-taustajärjestelmään osoitteessa $arg1. Tarkista selainkonsoli ja käänteisen välityspalvelimen/verkkoasetukset.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'itse; palvelimen operaattori poistaa admin ensin ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Nämä kanavat ovat hiljaa. Jos haluat kuulla heistä uudelleen, lisää heidät kohtaan Kuka voi lähettää viestin kyseiselle alustalle.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Nämä luettelot ovat valinnaisia, ellei yllä olevaa osiota ole asetettu vain hyväksytyksi.';

  @override
  String get thesePeopleAnywhere => 'Nämä ihmiset missä tahansa';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Nämä ihmiset voivat lähettää viestejä $arg1:lle yksityisissä chateissa ja missä tahansa jakamassaan ryhmässä.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Nämä ihmiset voivat lähettää $arg1:lle kahdenkeskisen viestin. Tämä ei anna heidän puhua ryhmissä.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Nämä ihmiset voivat lähettää viestin $arg1 vain valitsemassasi ryhmässä.';
  }

  @override
  String get thesePeopleInOneGroup => 'Nämä ihmiset yhdessä ryhmässä';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'nämä kytkimet, ei koskaan keskustelujasi, muistojasi tai tiedostojasi.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Tämä tili avaa NeoAgentin lukituksen tälle koneelle.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Tämä edustaja voi delegoida kenelle tahansa kelvolliselle vastaanottavalle edustajalle.';

  @override
  String get thisAgentIsUsingAServer =>
      'Tämä agentti käyttää palvelimen hallinnoimaa Trello API-avainta. Sinun tarvitsee vain valtuuttaa alla oleva tilitunnus.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Tämä koontiversio ei saa keskustella tämän NeoAgent-asennuksen kanssa.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Tämä koodi kuuluu toiselle NeoAgent-palvelimelle: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Tämä työpöytä on yhdistetty';

  @override
  String get thisDevice => 'Tämä laite';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Tämä laite: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Tämä laite ei voi rekisteröidä suojausavaimia. Lisää sellainen avaamalla NeoAgent selaimessa HTTPS:n kautta.';

  @override
  String get thisDeviceUnavailable => 'Tämä laite – ei saatavilla';

  @override
  String get thisFileHasNoContent => 'Tällä tiedostolla ei ole sisältöä.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Tämä piilottaa \"$arg1\" reitityksestä ja valinnasta.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Tämä integrointi tukee tällä hetkellä yhtä yhdistettyä tiliä agenttia kohden. Avaa asennus uudelleen vaihtaaksesi se.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Tämä integrointi ei ole enää saatavilla.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Tämä johdanto on suunniteltu koko näytön vaakatoistoon.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Tämä on hallittu käyttöönotto. Sen operaattori rullaa ulos ';

  @override
  String get thisMayTakeAMoment => 'Tämä voi kestää hetken.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Tätä MCP-palvelinta ei ole enää määritetty.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Tämä muisti poistetaan pysyvästi.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Tätä NeoAgent-koontiversiota ei ole määritetty varmistamaan backend-ajoaikoja.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Tämä poistaa pysyvästi kaikki tietosi, eikä sitä voi tehdä ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Tämä poistaa pysyvästi tilin ja kaiken sen omistaman: ';

  @override
  String get thisPersonAnywhere => 'Tämä henkilö missä tahansa';

  @override
  String get thisPersonInOneGroup => 'Tämä henkilö yhdessä ryhmässä';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Tämä QR-kirjautumispyyntö on vanhentunut. Luo uusi koodi ja yritä uudelleen.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'tämä qr-kirjautumispyyntö on vanhentunut';

  @override
  String get thisQrLoginRequestIsStill =>
      'Tämä QR-kirjautumispyyntö odottaa edelleen hyväksyntää.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Tämä QR-kirjautumispyyntö oli jo käytössä.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Tämä poistaa tämän agentin Home Assistant -asetukset ja yhdistetyn ilmentymän.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Tämä poistaa tämän agentin NeoRecall-tausta-URL-osoitteen ja kaikki yhdistetyt NeoRecall-tilit.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Tämä poistaa tämän agentin Nextcloud-URL-osoitteen ja kaikki yhdistetyt Nextcloud-tilit.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Tämä poistaa tämän agentin Trellon asetukset ja yhdistetyt tilit.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Tämä edellyttää todennettua istuntoa samalla NeoAgent-palvelimella.';

  @override
  String get thisRunDidNotProduceA =>
      'Tämä ajo ei tuottanut käyttäjälle suunnattua vastausta.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Tässä ajossa ei ole tallennettuja askeltietoja.';

  @override
  String get thisServer => 'tämä palvelin.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Tämä palvelin ei raportoi palveluntarjoajan asetuksia.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Tätä taitoa ei ole enää asennettu.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Tätä tehtävää ei ole vielä suoritettu loppuun, joten se alkaa edelleen klo ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Tämä tehtävä suoritetaan vain, kun painat Suorita nyt.';

  @override
  String get thisWeek => 'Tällä viikolla';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Tämä tuo vastauksen tiedostoon $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Tämä poistaa \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Tämä poistaa \"$arg1\" palvelinluettelosta.';
  }

  @override
  String get time => 'Aika';

  @override
  String get timeZone => 'aikavyöhyke';

  @override
  String get timeZone2 => 'Aikavyöhyke';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Aikakatkaisu$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Aikavyöhykkeitä ei voitu luetteloida: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Laitteen aikavyöhykettä ei voitu lukea: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Laitteen aikavyöhykettä ei voitu tallentaa: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'kohtaan $arg1';
  }

  @override
  String get toUseTheServerDefault => 'käyttääksesi palvelimen oletusasetusta.';

  @override
  String get today => 'Tänään';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Token-budjetti @$arg1. Jätä kenttä tyhjäksi ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Token-budjetti jokaiselle tilille ilman omaa ohitusta. Jätä a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'token-budjettiraja 4 tunnin viikoittainen kiintiön käyttäjä';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'token-budjettiraja 4 tunnin viikoittainen kiintiö';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Tokenin käyttö ei ole käytettävissä tässä palvelinversiossa.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Kaikki tilit voivat käyttää tunnukset 4 tunnissa.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tunnuksia mikä tahansa tili voi käyttää 7 päivässä.';

  @override
  String get tokensPerDay => 'Tokeneja päivässä';

  @override
  String get tokensPerRun => 'Tokeneja per juoksu';

  @override
  String get tokensToday => 'Tokenit tänään';

  @override
  String get tokensUsed => ' käytettyjä tokeneja';

  @override
  String get tomorrowPrep => 'Huomenna valmistautuminen';

  @override
  String get tooManyAttempts => 'liian monta yritystä';

  @override
  String get tooManySignInAttemptsPlease =>
      'Liian monta kirjautumisyritystä. Odota ja yritä uudelleen.';

  @override
  String get tool => 'Työkalu';

  @override
  String get toolApproval => 'Työkalun hyväksyntä';

  @override
  String get toolApprovalRequired => 'Työkalun hyväksyntä vaaditaan';

  @override
  String get toolCompleted => 'Työkalu valmis';

  @override
  String get toolFailed => 'Työkalu epäonnistui';

  @override
  String get toolPermissions => 'Työkalun käyttöoikeudet';

  @override
  String get toolStarted => 'Työkalu käynnistyi';

  @override
  String get tools => 'Työkalut';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'NeoAgentiin sisältymättömät työkalut, mukaan lukien yhdistetyt MCP-palvelimet ja mukautetut työkalujen toimittajat.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Tarjotut työkalut ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Työkalut, joita hallinnoitu tili voi käyttää';

  @override
  String get topUsers => 'Huippukäyttäjät';

  @override
  String get topUsersAndRecentRuns => 'Parhaat käyttäjät ja viimeisimmät ajot';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Yhteensä: $arg1-rahakkeita $arg2-ajoissa';
  }

  @override
  String get totalRuns => 'Ajoja yhteensä';

  @override
  String get totalTokens => 'Tokeneja yhteensä';

  @override
  String get totalUsers => 'Käyttäjiä yhteensä';

  @override
  String get transcript => 'Transkriptio';

  @override
  String get transcript2 => 'LIITTEET';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Transkriptio epäonnistui: $arg1';
  }

  @override
  String get transfer => 'Siirto';

  @override
  String get trelloApiKey => 'Trello API-avain';

  @override
  String get trelloApiKeyIsRequired => 'Trello API Key vaaditaan.';

  @override
  String get trelloSetup => 'Trellon asennus';

  @override
  String get triggerType => 'Liipaisimen tyyppi';

  @override
  String get tryABroaderSearchLikeModels =>
      'Kokeile laajempaa hakua, kuten malleja, selainta tai puhetta.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Kokeile palveluntarjoajan nimeä, \"email\", \"limits\", \"update\" tai \"logs\".';

  @override
  String get tryAgain => 'Yritä uudelleen';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Yritä uudelleen. Jos tämä toistuu, suorita NeoAgent Doctor tarkistaaksesi tietokoneen suoritusajan.';

  @override
  String get tryAgainInAMoment => 'Yritä hetken kuluttua uudelleen.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Yritä uudelleen tai suorita NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Kokeile toista hakua, yhdistä viestintäalusta tai anna kohdetunnus manuaalisesti.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Ota ryhmä käyttöön, jos $arg1:n pitäisi lukea myös viestejä, joissa sitä ei ole merkitty.';
  }

  @override
  String get turnOffComputer => 'Sammuta tietokone';

  @override
  String get turnOffOnlyForAMail =>
      'Poista käytöstä vain sähköpostipalvelimelle, jolla on itse allekirjoitettu varmenne.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Ota käyttöön, jos Signal etsii edelleen saapuvia keskusteluja.';

  @override
  String get turnTaking => 'käännös ottaa';

  @override
  String get turnTakingModel => 'Vuorottelumalli';

  @override
  String get turnTakingOff => 'Käännetty pois päältä';

  @override
  String get turnThisOffToKeepThis =>
      'Kytke tämä pois päältä, jotta tämä agentti pysyy täysin erillään muista agenteista.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Sammutti $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Tämän tilin hallinnoija $arg1 on poistanut sen käytöstä. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return '$arg1 on poistanut sen käytöstä – vain he voivat muuttaa sen';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Poistettu sinulta, joten et voi jakaa sitä';

  @override
  String get twitchChatOverIrc => 'Twitch chat IRC:n kautta';

  @override
  String get twoFactorAuthentication => 'Kaksivaiheinen todennus';

  @override
  String get twoFactorChallengeExpired => 'kaksitekijähaaste vanhentunut';

  @override
  String get twoFactorCode => 'kaksifaktorinen koodi';

  @override
  String get twoFactorSignInCompletedBut =>
      'Kaksivaiheinen kirjautuminen valmis, mutta NeoAgent ei voinut pitää selainistuntoa. Kirjaudu uudelleen sisään.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Kaksivaiheinen kirjautuminen (vain jos käytössä)';

  @override
  String get type => 'Kirjoita';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Vahvista kirjoittamalla $arg1';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'tekstityyppiä ei tueta tällä alustalla.';

  @override
  String get typedInTheBrowser => 'Kirjoitettu selaimeen';

  @override
  String get typedText => 'Kirjoitettu teksti';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'Java-ajonaikaa ei löydy';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Tämän koontiversion aika-asetuksia ei voi avata.';

  @override
  String get unableToOpenWiFiSettings =>
      'Tämän koontiversion Wi-Fi-asetuksia ei voi avata.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Valittua työpöytänäyttöä ei voi säilyttää.';

  @override
  String get unclearWhoItWasFor => 'Epäselvää kenelle se oli tarkoitettu';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'kumottu. Vahvista kirjoittamalla käyttäjätunnuksesi.';

  @override
  String get unknownAccount => 'Tuntematon tili';

  @override
  String get unknownAgent => 'Tuntematon agentti';

  @override
  String get unknownBrowser => 'Tuntematon selain';

  @override
  String get unknownDevice => 'Tuntematon laite';

  @override
  String get unknownError => 'tuntematon virhe';

  @override
  String get unknownLocalComputerPermission =>
      'Tuntematon paikallisen tietokoneen käyttöoikeus.';

  @override
  String get unknownLocation => 'Tuntematon sijainti';

  @override
  String get unknownPublishTime => 'Julkaisuaika tuntematon';

  @override
  String get unknownSize => 'Tuntematon koko';

  @override
  String get unlink => 'Poista linkitys';

  @override
  String get unreadOnly => 'Vain lukematon';

  @override
  String get unsavedChanges => 'Tallentamattomat muutokset';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Ei-tuettu työpöytäparikomento: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Ei tuettu menetelmä: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Epätavalliset kirjautumisilmoitukset';

  @override
  String updateArg1(Object? arg1) {
    return 'Päivitä $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Päivitä ydinmuistimerkinnät tuonnista.';

  @override
  String get updateNow => 'Päivitä nyt';

  @override
  String get updateReady => 'Päivitys valmis';

  @override
  String get updateSetup => 'Päivitä asetukset';

  @override
  String get updateTheAccessListToAllow =>
      'Päivitä käyttöoikeusluettelo salliaksesi vastaukset.';

  @override
  String get updateTheServer => 'Päivitä palvelin?';

  @override
  String get updateTheServer2 => 'Päivitä palvelin';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Päivitä aikavyöhyke automaattisesti käyttämästäsi laitteesta.';

  @override
  String updatedArg1(Object? arg1) {
    return 'päivitetty $arg1';
  }

  @override
  String get updates => 'Päivitykset';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Päivityksiä ei ole määritetty tälle koontiversiolle.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'päivitykset, joten itsepäivitykset ja kanavamuutokset eivät ole käytössä täällä.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'päivitä päivitys nyt julkaise kanavan vakaa beta';

  @override
  String get usageAnalytics => 'Käyttöanalytiikka';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Käyttö- ja terveyssignaalit, jotka auttavat selittämään nykyisen ajonaikaisen käyttäytymisen kaivamatta ensin lokeja.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Käyttö nollautuu täysin $arg1:ssä';
  }

  @override
  String get usageLeaderboard => 'käytön tulostaulukko';

  @override
  String get usageLimits => 'Käyttö ja rajoitukset';

  @override
  String get usageLimits2 => 'Käyttö ja rajoitukset';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Käytä yli 8 merkkiä. Pidemmät tunnuslauseet toimivat hyvin.';

  @override
  String get useADateAndTimeFor =>
      'Käytä päivämäärää ja aikaa, esimerkiksi 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Käytä nimeä, puhelinnumeroa tai chat-tunnusta.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Käytä NeoRecall-URL-osoitetta, jonka NeoAgent-palvelin voi tavoittaa. NeoAgentin PUBLIC_URL-osoitteen on oltava myös tavoitettavissa tästä selaimesta OAuth-vastakutsua varten.';

  @override
  String get useANewPasswordWithAt =>
      'Käytä uutta salasanaa, jossa on vähintään 8 merkkiä.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Käytä Nextcloud-URL-osoitetta, jonka NeoAgent-palvelin voi tavoittaa, esimerkiksi https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Käytä salasanaa, jossa on vähintään 8 merkkiä.';

  @override
  String get useASecureConnectionTls => 'Käytä suojattua yhteyttä (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Käytä todennussovellusta, kuten Authy, 1Password tai Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Käytä vähintään yhtä vCPU:ta.';

  @override
  String get maxMemoryPerComputerMb => 'Enimmäismuisti tietokonetta kohti (MB)';

  @override
  String get maxVcpusPerComputer => 'Maksimi vCPU:ta tietokonetta kohti';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Ainakin $arg1. Tietokoneet saavat vähemmän, kun isäntä on kiireinen.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Enimmäismuistin on oltava vähintään $arg1 Mt.';
  }

  @override
  String get useAtLeast8Characters => 'Käytä vähintään 8 merkkiä.';

  @override
  String get useDefault => 'Käytä oletusarvoa';

  @override
  String get useDefaultChannel => 'Käytä oletuskanavaa';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Käytä oletusarvoa (NeoAgent Workspace)';

  @override
  String get useFor => 'Käytä';

  @override
  String get useManualDestination => 'Käytä manuaalista kohdetta';

  @override
  String get useOrDoTheSameFor => 'käytä tai tee sama joukkuetovereillesi.';

  @override
  String get usePerCategorySettingsBelow =>
      'Käytä alla olevia luokkakohtaisia ​​asetuksia.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Käytä oletusasetuksia ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Käytä palvelinta tässä tietokoneessa';

  @override
  String get useTheseForContextIfA =>
      'Käytä näitä kontekstiin. Jos paikallinen URI ei ole suoraan käytettävissä palvelimelta, pyydä minua toimittamaan tiedosto esteettömän työtilan kautta.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Käytä tätä orkesteriagenteille. Jätä pois yksittäisille työboteille, joiden pitäisi lopettaa suorat viestit itse.';

  @override
  String get useTlsFromTheStartOf =>
      'Käytä TLS:ää yhteyden alusta lähtien, yleensä portissa 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Käytä omaa API-avainta palveluntarjoajalle tai yhdistä mukautettu ';

  @override
  String get usedByEveryAccountOnThis =>
      'Käyttää jokainen tämän palvelimen tili, jolla ei ole avainta ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Käytetään varmistamaan, että saapuvat Slack-tapahtumat ovat aitoja.';

  @override
  String get userSummary => 'Käyttäjän yhteenveto';

  @override
  String get username => 'Käyttäjätunnus';

  @override
  String get usernameOrEmail => 'Käyttäjätunnus tai sähköpostiosoite';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'käyttäjät ihmiset hakevat sähköpostin käyttäjänimi järjestelmänvalvojan merkki hallinnoitu tiimi';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Käyttää Asetuksissa määritettyä chat-mallia';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Käyttämällä asennettua NeoAgent-ajoaikaa';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Yleensä näyttää tältä @bot:matrix.org';

  @override
  String get validEmail => 'voimassa oleva sähköposti';

  @override
  String get value => 'Arvo';

  @override
  String get vaultLocked => 'Holvi lukittu';

  @override
  String get vaultOperationFailed => 'Holvin toiminta epäonnistui.';

  @override
  String get verification => 'Vahvistus';

  @override
  String verificationArg1(Object? arg1) {
    return 'Vahvistus: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'vahvistus: $arg1';
  }

  @override
  String get verificationCompleted => 'Vahvistus suoritettu.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Varmennustila: $arg1';
  }

  @override
  String get verifiedTheResult => 'Vahvistettu tulos';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Ladatun suoritusajan tarkistaminen';

  @override
  String get versionAndUptime => 'Versio ja käyttöaika';

  @override
  String versionArg1(Object? arg1) {
    return 'Versio $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Versio $arg1 on asennettu, mutta $arg2 on edelleen käynnissä.';
  }

  @override
  String get videoLinks => 'Videolinkit';

  @override
  String get viewDesktop => 'Näytä työpöytä';

  @override
  String get viewLastRun => 'Näytä viimeinen ajo';

  @override
  String get viewLogs => 'Näytä lokit';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'vm-kuvamuisti cpu qemu runtime';

  @override
  String get voice => 'Ääni';

  @override
  String get voiceAssistant => 'Ääniavustaja';

  @override
  String get voiceCall => 'ÄÄNIPUHELU';

  @override
  String get voiceCall2 => 'Äänipuhelu';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'äänipuhelu gpt-live gemini live malli puhe reaaliajassa';

  @override
  String get voiceCallsRunOnALive =>
      'Äänipuhelut toimivat puheesta puheeksi -mallilla, jolla on sama persoona, muisti ja chat-historia kuin NeoAgentilla. Se vastaa heti ja antaa todellisen työn tavalliselle agentille, joka toimii jatkuvasti taustalla.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'äänimuistiinpano puheen transkriptio api-avain';

  @override
  String get voiceNotesAndDictation => 'Äänimuistiinpanot ja sanelu';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Äänentoisto ei ole käytettävissä tällä laitteella.';

  @override
  String get voiceReplyModel => 'Äänivastausmalli';

  @override
  String get waitingForApproval => 'Hyväksyntää odotellessa: ';

  @override
  String get waitingForCode => 'Koodia odotellessa';

  @override
  String get waitingForInput => 'Odotetaan syöttöä';

  @override
  String get waitingForServerOrFlutterLog =>
      'Odotetaan palvelimen tai Flutter-lokin tulosta…';

  @override
  String get waitingForTaskEvents => 'Tehtävätapahtumia odotellessa...';

  @override
  String get waitingForYou => 'odottaa sinua';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Halusi vastauksen käyttäjältä $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Haluaa puhua kanssasi · ${arg1}s';
  }

  @override
  String get weak => 'Heikko';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Sää, kalenteri ja prioriteetit ennen päivän alkamista.';

  @override
  String get weatherEvent => 'Säätapahtuma';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'Web-selain';

  @override
  String get webSearchApiKey => 'verkkohaun sovellusliittymäavain';

  @override
  String get webhookOrRestChannelPosting =>
      'Webhook- tai REST-kanavan lähettäminen';

  @override
  String get webhookSecret => 'Webhookin salaisuus';

  @override
  String get webhookUrlCopied => 'Webhookin URL-osoite kopioitu';

  @override
  String get weekdays => 'arkipäivisin';

  @override
  String get weekdays0730 => 'Arkisin · 07:30';

  @override
  String get weekdays1800 => 'Arkisin · 18:00';

  @override
  String get weekly => 'viikoittain';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Viikkoraja $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Viikkoraja (tunnukset)';

  @override
  String get weeklyReview => 'Viikkokatsaus';

  @override
  String get weeklyUsage => 'Viikoittainen käyttö';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Paino $arg1 ennätys';
  }

  @override
  String get welcomeToNeoagent => 'TERVETULOA NEOAGENTiin';

  @override
  String get welcomeToNeoagent2 => 'Tervetuloa\nNeoAgentiin';

  @override
  String get whatAreYouAdding => 'Mitä lisäät?';

  @override
  String get whatIsOnTomorrow => 'Mitä huomenna tapahtuu?';

  @override
  String get whatShouldNeoagentLearn => 'Mitä NeoAgentin pitäisi oppia?';

  @override
  String get whatShouldWeBuild => 'Mitä meidän pitäisi rakentaa?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Se, mitä sinä ja NeoAgent sanotte, näkyy täällä ja chatissa.';

  @override
  String get whatsappPersonalMessageReceived =>
      'WhatsApp henkilökohtainen viesti vastaanotettu';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Kun valitset vain hyväksytty, lisää ihmisiä tai ryhmiä alle.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Minne tämän edustajan pitäisi lähettää vastaukset.';

  @override
  String get whoCanMessage => 'Kuka voi lähettää viestin';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Kuka voi lähettää viestin numeroon $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Kuka voi lähettää $arg1:lle henkilökohtaisen viestin.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Kuka voi puhua $arg1:lle ryhmässä, kanavassa tai huoneessa.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'kuka hallinnoi tätä tiliä pois päältä: ';

  @override
  String get whoManagesWhom => 'Kuka hallitsee ketä';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Jokainen, joka hyväksyy linkin, liittyy tiimiisi vain sen työkaluilla ';

  @override
  String get wholeGroup => 'Koko ryhmä';

  @override
  String get wholeGroups => 'Kokonaisia ryhmiä';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Miksi $arg1 vastasi tai pysyi hiljaa $arg2-ryhmissä.';
  }

  @override
  String get windowsApp => 'Windows-sovellus';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'Työtili';

  @override
  String get workOnAProjectWithNeoagent =>
      'Työskentele projektin parissa NeoAgentin kanssa';

  @override
  String workflowArg1(Object? arg1) {
    return 'Työnkulku: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Työskentely $arg1:ssä pilvitietokoneella. NeoAgent lukee ja muokkaa siellä olevia tiedostoja ja voi suorittaa komentoja ja selainta.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Työskentely taustalla: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Työtilan määritys ja tilin suojaus yhdessä paikassa.';

  @override
  String get workspaceFiles => 'Työtilan tiedostot';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Työtila, mallit ja diagnostiikkaohjaimet.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Työtilan ohituksen on oltava absoluuttinen polku.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Kirjoitti $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'xmlhttp-pyyntövirhe';

  @override
  String get yesterday => 'eilen';

  @override
  String get youAreInControl => 'Sinä hallitset';

  @override
  String get youCanFollowAlongOnThe => 'Voit seurata mukana työpöydällä.';

  @override
  String get youCanLeaveATeamAt =>
      'Voit jättää tiimin milloin tahansa; omat asetuksesi ovat taas voimassa.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Voit poistua milloin tahansa Team-sivulta.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Päätät, mitä työkaluja edustajasi voi käyttää kohdassa Asetukset › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Et hallitse vielä ketään. Luo kutsulinkki alle ja ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Sinulla on tallentamattomia asetuksia. Mitä haluaisit tehdä?';

  @override
  String get youReOnYourOwnYou =>
      'Olet itsesi: päätät, mitä työkaluja agenttisi voi käyttää. Jos ';

  @override
  String get yourAccountAndUsageOnA =>
      'tilisi – ja käyttö mallissa, jota tukee oma avaimesi ';

  @override
  String get yourAccountHasBeenDeleted => 'Tilisi on poistettu.';

  @override
  String get yourAgentWillBeAllowed => 'Edustajasi saavat:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Sovelluksesi ja tiedostosi tallennetaan.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Sovelluksesi ja tiedostosi pysyvät tallennettuina.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Sinun $arg1-avain';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Avustajatasosi sieppaamiseen, kontekstiin ja toimintaan.';

  @override
  String get yourComputerIsAsleep => 'Tietokoneesi on lepotilassa';

  @override
  String get yourComputerIsOff => 'Tietokoneesi on pois päältä';

  @override
  String get yourComputerIsReady => 'Tietokoneesi on valmis';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Nykyinen salasanasi on virheellinen.';

  @override
  String get yourData => 'Tietosi';

  @override
  String get yourDataExportWasCopiedTo =>
      'Tietojen vienti kopioitiin leikepöydälle.';

  @override
  String get yourDesktopIsReady => 'Työpöytäsi on valmis';

  @override
  String get yourLinuxComputer => 'Linux-tietokoneesi';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Sijaintiasi ei koskaan seurata jatkuvasti tai tallenneta palvelimillemme. Käytämme sitä vain paikallisesti tarkistaaksemme aktiivisten tehtäviesi suhteen.';

  @override
  String get yourManager => 'esimiehesi';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'Mattermost-sivustosi URL-osoite, jos käytät REST-sovellusliittymää.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Istunto on vanhentunut tai selain ei säilyttänyt sitä. Kirjaudu uudelleen sisään.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Istunto on vanhentunut. Kirjaudu uudelleen sisään.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Käyttäjätunnuksesi tai salasanasi on virheellinen.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Yleiskatsaus';

  @override
  String get sectionDiagnostics => 'Diagnostiikka';

  @override
  String get sectionVolume => 'Äänenvoimakkuus';

  @override
  String get sectionSession => 'Istunto';

  @override
  String get sectionDeliverable => 'Toimitettava';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Paikallinen suoritin ei ole vielä kirjoittanut lokitiedostoa.';

  @override
  String get thisComputer => 'Tämä tietokone';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta asentaa uusimman esijulkaisun taustajärjestelmän. Odota karkeita reunoja.';

  @override
  String get copiedFinalResponse => 'Kopioitu lopullinen vastaus';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Lopullinen vastaus näkyy tässä, kun ajo päättyy.';

  @override
  String get waitingForTheFirstStep => 'Ensiaskelta odotellessa…';

  @override
  String get loadingPrompt => 'Ladataan kehotetta…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Lopullista vastausta ei saatu tälle ajolle.';

  @override
  String get readyToSignIn => 'Valmiina kirjautumaan sisään';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Ota hyväksyntätarkistukset uudelleen käyttöön valitsemalla Oletus- tai Kysy aina.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Lähetä ohjauspäivitys tai seuraava huomautus nykyisestä ajosta...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Ei verkkoyhteyttä. NeoAgent muodostaa yhteyden uudelleen, kun laite on taas online-tilassa.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Uusin ohjauspäivitys on otettu käyttöön nykyiseen ajoon.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Valmistellaan yksityistä puheistuntoa…';

  @override
  String get preparingYourComputer => 'Tietokoneen valmistelu';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent lataa ja valmistelee suojattua Linux-järjestelmää. Tämä tapahtuu vain ensimmäistä kertaa.';

  @override
  String get moreFreeSpaceIsNeeded => 'Vapaata tilaa tarvitaan lisää';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Vapauta levytilaa NeoAgent-isännässä ja yritä sitten uudelleen. Nykyiset tietokoneesi tiedot ovat turvassa.';

  @override
  String get androidReady => 'Android valmis';

  @override
  String get startingAndroid2 => 'Käynnistetään Android…';

  @override
  String get androidStopped => 'Android pysähtyi';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Ensimmäinen käynnistys lataa Android SDK:n ja järjestelmäkuvan, mikä voi kestää useita minuutteja.';

  @override
  String get androidIsStopped => 'Android on pysäytetty';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Käynnistä hallittu Android-ympäristö, kun tarvitset sitä.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Anna NeoAgentin toimia tällä tietokoneella';

  @override
  String get firstTimeSetupIsInProgress => 'Ensiasennus on käynnissä.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent voi käyttää sallimaasi käyttöoikeutta.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Vapauta isäntätallennustila ja yritä uudelleen.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Aloita, kun haluat NeoAgentin auttavan täällä.';

  @override
  String get systemPermissionMissing => 'Järjestelmän käyttöoikeus puuttuu';

  @override
  String get connectingThisDevice => 'Tämän laitteen yhdistäminen';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Suojattua paikallista yhteyttä muodostetaan.';

  @override
  String get recordingYourDemonstration => 'Esittelysi tallentaminen';

  @override
  String get noErrorsInTheRecentLog => 'Ei virheitä viimeaikaisessa lokissa.';

  @override
  String get loadingAccounts => 'Ladataan tilejä…';

  @override
  String get neverSignedIn => 'Ei koskaan kirjautunut sisään';

  @override
  String get emptyUsesTheServerDefault =>
      'Tyhjä käyttää palvelimen oletusarvoa.';

  @override
  String get followTheSelectedSession => 'Seuraa valittua istuntoa';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Suunnittelutila tarkastelee vain. Vaihda agenttitilaan antaaksesi NeoAgentin muokata tiedostoja.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Pakollinen tilisi sähköpostiosoitteen lisäämiseen tai vaihtamiseen.';

  @override
  String get confirmNewPassword => 'Vahvista uusi salasana';

  @override
  String get passwordChanged => 'Salasana vaihdettu.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Tätä pyyntöä on jo käytetty.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Tämä pyyntö on vanhentunut. Pyydä toista laitetta luomaan uusi koodi.';

  @override
  String get startQuickstart => 'Käynnistä Pika-aloitus';

  @override
  String get createYourAccount => 'Luo tili';

  @override
  String get showWorkAsSummaries => 'Näytä työt yhteenvetoina';

  @override
  String get tokensUsedByTheLatestRun =>
      'Viimeisimmän ajon käyttämät tunnukset';

  @override
  String get listedTheWorkspaceRoot => 'Luetteloi työtilan juuren';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Virallisia integraatioita ei ole vielä saatavilla.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'MCP-palvelimia ei ole vielä määritetty. Lisää yksi paljastaaksesi sen työkalut.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Aloita lisäämällä MCP-palvelin tai asentamalla taito.';

  @override
  String get setUp => 'Määritä';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Jätä tyhjäksi tallennetun arvon säilyttämiseksi';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Tämä poistaa osoitteen jokaiselta tililtä tällä palvelimella.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Puhu vain. Voit keskeyttää milloin tahansa. Mykistä napauttamalla.';

  @override
  String get tapAgainWhenYouAreDone => 'Napauta uudelleen, kun olet valmis.';

  @override
  String get workingOnATaskInTheBackground =>
      'Työskentely tehtävän parissa taustalla.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Puheesta puheeksi sama muisti, työkalut ja keskusteluhistoria kuin NeoAgent.';

  @override
  String get checkLink => 'Tarkista linkki';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Edustajasi ei saa käyttää valvottuja työkaluja.';

  @override
  String get notYoursToChange => 'Ei sinun tarvitse muuttaa';

  @override
  String get setByYou => 'Sinun asettamasi';

  @override
  String get noTools => 'Ei työkaluja';

  @override
  String get untitledLink => 'Nimetön linkki';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'lakkaa toimimasta, kun yksi henkilö on lunastanut sen.';

  @override
  String get theOperator => 'Operaattori';

  @override
  String get smartSelectorOn => 'Älykäs valitsin päällä';

  @override
  String get startASessionToBegin => 'Aloita istunto';

  @override
  String get steerTheActiveRun => 'Ohjaa aktiivista juoksua…';

  @override
  String get describeWhatToPlan => 'Kuvaile mitä suunnitella…';

  @override
  String get stopDictation => 'Lopeta sanelu';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Viestit ohjaavat nykyistä ajoa · ⌘↵ lähetä · ⌘. lopeta';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Suunnittelutila tarkastelee vain; mitään ei muuteta ennen kuin otat käyttöön · ⌘↵ send';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Agentti muokkaa työtilaa. Suunnittele vain tarkastuksia.';

  @override
  String get defaultModel => 'Oletusmalli';

  @override
  String get openingScanner => 'Avataan skanneria...';

  @override
  String get theAgentCanUseThisSkill => 'Välittäjä voi käyttää tätä taitoa.';

  @override
  String get allSelected => 'Kaikki valitut';

  @override
  String get addCoreMemoryEntry => 'Lisää ydinmuistin syöttö';

  @override
  String get channelId => 'Kanavan tunnus';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Tekoälyn luomat ja määrittelemättömät tehtävät käyttävät nykyistä oletusarvoa.';

  @override
  String get waitingForRunEvents => 'Juoksutapahtumia odotellessa...';

  @override
  String get hideSteps => 'Piilota vaiheet';

  @override
  String get commitTheActiveLiveCapture => 'Tee aktiivinen livekaappaus';

  @override
  String get stopCaptureAndSubmit => 'Lopeta sieppaus ja lähetä';

  @override
  String get clickTheMicToStartSpeaking =>
      'Aloita puhuminen napsauttamalla mikrofonia';

  @override
  String get connectACustomEndpoint => 'Yhdistä mukautettu päätepiste';

  @override
  String get hostedProvider => 'isännöity palveluntarjoaja.';

  @override
  String get muted => ' • mykistetty';

  @override
  String get addWhoCanMessage => 'Lisää kuka voi lähettää viestin';

  @override
  String get joinsGroupConversations => 'Liittyy ryhmäkeskusteluihin';

  @override
  String get label1PersonOrGroupAdded => '1 henkilö tai ryhmä lisätty';

  @override
  String get inProgress => 'Käynnissä';

  @override
  String get waitingForUpdateJobOutput => 'Odotetaan päivitystyön tulosta…';

  @override
  String get taskTrigger => 'Tehtävän laukaisin';

  @override
  String get bearerToken => 'Kantajatunnus';

  @override
  String get bearerToken2 => 'Kantajan Token';

  @override
  String get notRecorded => 'Ei tallennettu';

  @override
  String get sessionCookie => 'Istuntoeväste';

  @override
  String get neverUsed => 'Ei koskaan käytetty';

  @override
  String get linkedRecently => 'Linkitetty äskettäin';

  @override
  String get notUsedYet => 'Ei vielä käytetty';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Yksi tai useampi tili on vanhentunut. Muodosta yhteys uudelleen palauttaaksesi käyttöoikeudet. Jos tämä toistuu, Google Cloud OAuth -sovelluksesi saattaa olla testaustilassa – julkaise se Google Cloud Consolen tuotannossa saadaksesi pitkäikäisiä tunnuksia.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Holvi yhdistetty ja käytettävissä uudelleenkäynnistyksen jälkeen';

  @override
  String get vaultConnectedForThisSession => 'Holvi yhdistetty tähän istuntoon';

  @override
  String get connectAnotherAccount => 'Yhdistä toinen tili';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Liitä korvaava Long Lived Access Token';

  @override
  String get updateInstance => 'Päivitä ilmentymä';

  @override
  String get pasteAReplacementToken => 'Liitä korvaava tunnus';

  @override
  String get replaceAccount => 'Vaihda tili';

  @override
  String get addAccount => 'Lisää tili';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Voidaan delegoida mille tahansa vastaanottavalle edustajalle';

  @override
  String get canReceiveDelegatedTasks2 =>
      'voi vastaanottaa delegoituja tehtäviä';

  @override
  String get noSyncYet => 'Ei synkronointia vielä';

  @override
  String get noNewData => 'Ei uusia tietoja';

  @override
  String get syncOnceToSeedYourBackend =>
      'Synkronoi kerran käynnistääksesi taustasi.';

  @override
  String get lastWindowEndIsUnknown => 'Ikkunan viimeinen pää on tuntematon.';

  @override
  String get lastNonEmptySync => 'Viimeisin ei-tyhjä synkronointi';

  @override
  String get stopTranscribe => 'Pysäytä ja litteröi';

  @override
  String get steeringMode => 'Ohjaustila';

  @override
  String get noMessageText => 'Ei viestitekstiä';

  @override
  String get reconnectingToServer => 'Yhdistetään uudelleen palvelimeen…';

  @override
  String get signingIn => 'Kirjaudutaan sisään...';

  @override
  String get noGroupsFoundYet => 'Ryhmiä ei vielä löytynyt';

  @override
  String get onForNewGroupsOnly => 'Käytössä vain uusille ryhmille';

  @override
  String get noGroupsInThisCategory => 'Ei ryhmiä tässä luokassa';

  @override
  String get groupOrChannel => 'Ryhmä tai kanava';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Itsellesi kirjoittamasi muistiinpanot aloittavat juoksun ja vastaukset laskeutuvat samaan chattiin. Sallittu lista ei päde tähän.';

  @override
  String get needToReply => 'Pitää vastata';

  @override
  String get enter2faCode => 'Syötä 2FA-koodi';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Avaa todennussovellus ja anna nykyinen NeoAgent-koodi.';

  @override
  String get alreadyHaveAnAccountSignIn =>
      'Onko sinulla jo tili? Kirjaudu sisään';

  @override
  String get serverOnThisComputer => 'Palvelin tällä tietokoneella';

  @override
  String get showQrCode => 'Näytä QR-koodi';

  @override
  String get createAnotherNeoagentAccount => 'Luo toinen NeoAgent-tili.';

  @override
  String get canCoordinateDelegatedWork => 'Voi koordinoida delegoitua työtä';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'NeoAgent-ajonaikaista arkistoa ei voitu purkaa.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'NeoAgent-ajonaikaista arkistoa ei voitu lukea.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'NeoAgentin ajonaikainen arkisto sisältää vaarallisen polun.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'NeoAgent-ajonaikainen arkisto sisältää vaarallisen linkin.';

  @override
  String get installingAppPackageOnThePhone =>
      'Asennetaan sovelluspakettia puhelimeen...';

  @override
  String get dragAndDropAApkOrApks =>
      'Vedä ja pudota .apk- tai .apks-tiedosto tähän tai selaa napsauttamalla.';

  @override
  String get releaseToInstallThisPackage => 'Asenna tämä paketti vapauttamalla';

  @override
  String get theSecurityKeyCouldNotBeUsed => 'Suojausavainta ei voitu käyttää.';

  @override
  String get connecting => 'Yhdistetään…';

  @override
  String get changes => 'Muutokset';

  @override
  String get runtimeReady => 'Käyttöaika valmis';

  @override
  String get saving => 'Tallennetaan...';

  @override
  String get earlier => 'Aikaisemmin';

  @override
  String get monthJan => 'tammikuu';

  @override
  String get monthFeb => 'helmikuuta';

  @override
  String get monthMar => 'maaliskuu';

  @override
  String get monthApr => 'huhtikuu';

  @override
  String get monthMay => 'toukokuuta';

  @override
  String get monthJun => 'kesäkuuta';

  @override
  String get monthJul => 'heinäkuuta';

  @override
  String get monthAug => 'elokuu';

  @override
  String get monthSep => 'syyskuu';

  @override
  String get monthOct => 'lokakuu';

  @override
  String get monthNov => 'marraskuu';

  @override
  String get monthDec => 'joulukuuta';

  @override
  String get steeringWord => 'Ohjaus';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Tämä vaihtaa taustajärjestelmän $arg1-kanavasta $arg2-kanavaan.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return '$arg1-evästeet tuotu';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s sitten';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Ohjausjonossa: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Verkkosovellus ei saanut yhteyttä NeoAgent-taustajärjestelmään.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Selain esti vaaditun pyynnön sisällön suojauskäytännön vuoksi.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 / 4 sallittu';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Suorita tehtävä normaalisti.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Muutokset · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Tämä laite · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Raja saavutettu$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return '$arg1-palautuskoodit ovat edelleen saatavilla.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Suojausavain $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Nykyinen istunto';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nViimeksi käytetty: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Toimii $arg1:ssä tässä laitteessa. NeoAgent lukee ja muokkaa kansiota suoraan ja voi suorittaa komentoja, avata sovelluksia ja käyttää näyttöä.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Toiminut $arg1:lle';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Sallittu: $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return '$arg1-kutsulinkit kohteesta $arg2 peruutettiin';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Lisää ihmiset ja ryhmät, joille $arg1:n tulisi puhua';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Lisää ihmiset ja ryhmät, joille $arg1 saa puhua.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Missä $arg1 kuuntelee';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 tarkkailee näitä paikkoja mainitsemista varten. Kuka tahansa voi kirjoittaa tänne, joten ihmiset tarvitsevat edelleen oman hyväksyntänsä alla.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Nämä ihmiset voivat kysyä $arg1:ltä minne he merkitsevät sen. Roolit lasketaan vain yllä luetelluissa paikoissa.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Vain kun $arg1 on merkitty';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Käytössä kaikissa $arg1-ryhmissä';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 kuulee edelleen vain jo hyväksymäsi ihmiset ja ryhmät. Tämä antaa $arg1:n liittyä tavalliseen keskusteluun, ei vain tunnisteisiin ja vastauksiin.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 kuulee edelleen vain jo hyväksymäsi ihmiset ja ryhmät. Tämä vain valitsee, mihin ryhmistä sen pitäisi liittyä.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Jos joku merkitsee $arg1 tai vastaa, $arg1 vastaa aina. Ota tämä käyttöön, jos $arg1 soittaa myös tavalliseen ryhmäkeskusteluun.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Uudet ryhmät antavat $arg1:n liittyä tavalliseen keskusteluun hyväksyttyjen ihmisten kanssa, kunnes poistat ne käytöstä.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Uudet ryhmät antavat $arg1:n liittyä tavalliseen chattiin, kunnes sammutat ne.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Uudet ryhmät pysyvät hiljaa, ellei hyväksytty henkilö merkitse $arg1:ää, kunnes otat ne käyttöön.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Vain kun hyväksytty henkilö merkitsee $arg1:n, ellet ota ryhmää käyttöön';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Vain kun $arg1 on merkitty, ellet ota ryhmää käyttöön';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 $arg2-ryhmistä liittyy tavalliseen keskusteluun hyväksyttyjen ihmisten kanssa';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Tämä ei hyväksy uusia ihmisiä. Tunnisteet ja vastaukset hyväksytyiltä ihmisiltä saavat aina vastauksen. Ota ryhmä käyttöön, jos $arg1:n pitäisi liittyä myös tavalliseen chattiin.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Tämä ei hyväksy uusia ihmisiä. Ota ryhmä käyttöön, jos $arg1:n pitäisi liittyä tavalliseen keskusteluun jo hyväksymiesi ihmisten kanssa.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Tunnisteet ja vastaukset saavat aina vastauksen. Ota ryhmä käyttöön, jos $arg1:n pitäisi liittyä myös tavalliseen chattiin.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 liittyy tavalliseen keskusteluun hyväksyttyjen ihmisten kanssa';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 voi liittyä tavalliseen chattiin';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 vastaa vain, kun hyväksytty henkilö merkitsee sen';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Mitään ylimääräistä ei tarvita. Yhdistä aloittaaksesi $arg1:n käytön.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Virkistyy $arg1:ssä';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Rekisteröidy $arg1:lle';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Ei muistoja linkitettynä \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (oletus)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Haara: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 liittyy vain alla lisäämiisi ryhmiin ja kanaviin.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 tarvitaan NeoAgent-ajonaikaisten tietojen paikantamiseen.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[typistetty esikatselu, $arg1 tavua yhteensä]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefaktirajoitettu, $arg1 tavua yhteensä]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' mallissa $arg1';
  }

  @override
  String get worldNews => 'Maailman uutisia';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Suorita, kun uudet maailmanotsikot ilmestyvät. Kehottesi päättää, ilmoittaako siitä sinulle.';

  @override
  String get newsKeywordsOptional => 'Avainsanat (valinnainen)';

  @override
  String get worldNewsSetup => 'World News -asetukset';

  @override
  String get connectWorldNewsWithGnews =>
      'Lisää GNews API-avain (ilmainen tilaus osoitteessa gnews.io). Se tallennetaan salattuna ja sitä käytetään World News -laukaisimien pääotsikoiden kyselyyn.';

  @override
  String get gnewsApiKey => 'GNews API-avain';

  @override
  String get pasteReplacementGnewsApiKey => 'Liitä korvaava GNews API-avain';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Jätä avain tyhjäksi säilyttääksesi tallennetun avaimen.';

  @override
  String get gnewsApiKeyIsRequired => 'GNews API -avain vaaditaan.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'World News -asetusta ei voitu tallentaa.';

  @override
  String get disconnectWorldNews => 'Katkaise yhteys World Newsista';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Tämä poistaa tallennetun GNews-sovellusliittymäavaimen. World News -laukaisimet lopettavat käynnistymisen, kunnes lisäät avaimen uudelleen.';

  @override
  String get couldNotDisconnectWorldNews =>
      'World Newsin yhteyttä ei voitu katkaista.';

  @override
  String get systemOneModels => 'SystemOne mallit';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Valitsee parhaan saatavilla olevan SystemOne-mallin';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Chat-malli tekee nämä päätökset';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Päätösmallit, jotka soittavat kulissien takana sekunnin murto-osassa: ryhmäkeskusteluvuorot ja selaimen vaiheet. Chat-mallisi kirjoittaa edelleen jokaisen vastauksen.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'SystemOne-malli päättää, milloin puhutaan sen ollessa päällä. tämä malli on varavaihtoehto.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 pisteytti SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne pisteytti tämän viestin suoraan. Mitään kielimallia ei suoritettu.';

  @override
  String get systemOneUnavailable => 'SystemOne ei ole käytettävissä';

  @override
  String get systemOneAdminAvailability =>
      'Päätösmallit agentit voivat valita kohdasta Asetukset › Mallit. Tässä pois päältä kytketty malli jättää poimijan, ja sen valinnut agentit palaavat Automaattiseen käyttöön. Kun mikä tahansa malli on kytketty pois päältä, myös SystemOne-mallit, jotka toimittajat lisäävät myöhemmin, sammuvat.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Ei vielä SystemOne-malleja. Lisää TypeSafe- tai OpenRouter-avain Providers-kohtaan tai vedä päätösmalli, kuten nimble Ollama 0.35:ssä tai uudemmassa.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'SystemOne-mallia ei ole vielä saatavilla. Lisää TypeSafe- tai OpenRouter-avain kohtaan Asetukset › Mallit › Tuo oma avain tai vedä päätösmalli, kuten ketterä Ollamassa.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone system one Decision mallit jev typesafe openrouter ollama saatavuus salli pois käytöstä';

  @override
  String get chatModels => 'Chat-mallit';

  @override
  String get disabled => 'Ei käytössä';

  @override
  String get enableShown => 'Ota käyttöön näytetään';

  @override
  String get disableShown => 'Pois käytöstä näkyy';

  @override
  String get expandAll => 'Laajenna kaikki';

  @override
  String get collapseAll => 'Kutista kaikki';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 tallentamattomat muutokset';
  }

  @override
  String get settingsScopeAllAgents => 'Kaikki agentit';

  @override
  String get settingsScopeAgent => 'Tämä agentti';

  @override
  String get settingsScopeApp => 'Sovellus';

  @override
  String get settingsScopeAccountHint =>
      'Sama kaikkialla, missä kirjaudut sisään';

  @override
  String get settingsScopeAllAgentsHint => 'Kaikki edustajasi jakavat';

  @override
  String get settingsAppliesTo => 'Koskee';

  @override
  String get settingsSaving => 'Tallennetaan…';

  @override
  String get settingsSavedAutomatically =>
      'Muutokset tallentuvat automaattisesti';

  @override
  String get settingsSearchHint => 'Hae kaikista asetuksista';

  @override
  String get settingsPageProfile => 'Profiili';

  @override
  String get settingsPageSecurity => 'Sisäänkirjautuminen ja suojaus';

  @override
  String get settingsPageUsage => 'Käyttö';

  @override
  String get settingsPagePermissions => 'Käyttöoikeudet';

  @override
  String get settingsPageComputer => 'Tietokone & verkko';

  @override
  String get settingsPageBehavior => 'Käyttäytyminen';

  @override
  String get settingsPageSystem => 'Järjestelmä';

  @override
  String get settingsPagePlatforms => 'Alustat';

  @override
  String get settingsPageProfileDescription =>
      'Nimesi ja sähköpostiosoitteesi, kopio tiedoistasi ja uloskirjautuminen.';

  @override
  String get settingsPageSecurityDescription =>
      'Salasana, kaksivaiheinen todennus, suojausavaimet ja sisäänkirjautumispaikka.';

  @override
  String get settingsPageUsageDescription =>
      'Rajasi ja tunnuksesi, kaikki yhdessä paikassa.';

  @override
  String get settingsPageAgentsDescription =>
      'Luo agentit ja valitse kumpi vastaa oletuksena.';

  @override
  String get settingsPagePermissionsDescription =>
      'Mitä agenttisi voivat tehdä kysymättä sinulta ensin.';

  @override
  String get settingsPageComputerDescription =>
      'Tietokone, jolla agenttisi työskentelevät, ja sivustot, joita he voivat lukea sinuna.';

  @override
  String get settingsPageModelsDescription =>
      'Mitä malleja tämä agentti käyttää ja niistä maksavat API-avaimet.';

  @override
  String get settingsPageBehaviorDescription =>
      'Kuinka tämä agentti puhuu ja kuinka se lukee ryhmäkeskustelun.';

  @override
  String get settingsPageVoiceDescription =>
      'Suorat puhelut, sanelu ja puhevastaukset tälle agentille.';

  @override
  String get settingsPageMessagingDescription =>
      'Mistä ihmiset voivat tavoittaa tämän agentin ja miten se käyttäytyy chateissa.';

  @override
  String get settingsPageGeneralDescription =>
      'Ulkonäkö, kieli, aikavyöhyke ja mitä tämä sovellus tekee taustalla.';

  @override
  String get settingsPageSystemDescription =>
      'Tämän ikkunan käyttämä palvelin, tämän tietokoneen palvelin ja sovelluspäivitykset.';

  @override
  String get settingsYourAgents => 'Sinun agenttisi';

  @override
  String get settingsChatModel => 'Chat malli';

  @override
  String get settingsChatModelDescription => 'Vastaa viesteihin.';

  @override
  String get settingsSubAgentModel => 'Aliagenttimalli';

  @override
  String get settingsSubAgentModelDescription =>
      'Suorittaa tehtävän aikana luovutettuja töitä.';

  @override
  String get settingsDefaultModels => 'Oletusmallit';

  @override
  String get settingsDefaultModelsDescription =>
      'Käytetään aina, kun keskustelu tai tehtävä ei valitse omaa malliaan.';

  @override
  String get settingsModelPool => 'Malli allas';

  @override
  String get settingsApiKeysDescription =>
      'Käytä tälle agentille omia avaimia tai päätepistettä. Avaimet salataan, eikä niitä näytetä enää koskaan.';

  @override
  String get settingsPersona => 'Persoona';

  @override
  String get settingsFineTuning => 'Hienosäätö';

  @override
  String get settingsFineTuningDescription =>
      'Harvoin tarvitaan. Oletusasetukset sopivat useimpiin keskusteluihin.';

  @override
  String get settingsShow => 'Näytä';

  @override
  String get settingsHide => 'Piilota';

  @override
  String get settingsMinimumContribution => 'Maksun vähimmäisarvo';

  @override
  String get settingsBatchWindow => 'Huoneen eräikkuna';

  @override
  String get settingsBatchWindowDescription =>
      'Odottaa näin kauan, jotta nopeat viestit voidaan käsitellä yhtenä käännöksenä.';

  @override
  String get settingsHandsFree => 'Handsfree';

  @override
  String get settingsHandsFreeDescription =>
      'Puhu vapaasti ja keskeytä milloin tahansa.';

  @override
  String get settingsPushToTalkDescription =>
      'Pidä puhuaksesi, vapauta lähettääksesi.';

  @override
  String get settingsLiveVoice => 'Elävä ääni';

  @override
  String get settingsChannels => 'Kanavat';

  @override
  String get settingsGroupChats => 'Ryhmäkeskusteluissa';

  @override
  String get settingsGroupChatsDescription =>
      'Kuinka tämä agentti käyttäytyy ryhmissä jokaisella kanavalla.';

  @override
  String get settingsGroupChatsDisabled =>
      'Ota käyttäytymismoduulit käyttöön Behaviorissa muuttaaksesi niitä.';

  @override
  String get settingsParticipationAutomatic => 'Automaattinen';

  @override
  String get settingsParticipationMentionOnly => 'Mainitse vain';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Lukee huoneen ja liittyy siihen, kun sillä on jotain hyödyllistä lisättävää.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Vastaa vain, kun mainitaan tai vastataan.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Vastaa jokaiseen viestiin.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Jakaa pidemmät vastaukset lyhyiksi viesteiksi, kuten henkilö tekisi.';

  @override
  String get settingsDeliverySingleDescription =>
      'Lähettää jokaisen vastauksen yhtenä viestinä.';

  @override
  String get settingsComputerStatus => 'Tila';

  @override
  String get settingsTest => 'Testaa';

  @override
  String get settingsAppearance => 'Ulkonäkö';

  @override
  String get settingsTheme => 'Teema';

  @override
  String get settingsThemeSystem => 'Järjestelmä';

  @override
  String get settingsThemeLight => 'Vaalea';

  @override
  String get settingsThemeDark => 'Tumma';

  @override
  String get settingsCloseWindow => 'Kun suljet ikkunan';

  @override
  String get settingsCloseAsk => 'Kysy';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent toimii jatkuvasti taustalla ja on tavoitettavissa.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent sulkeutuu kokonaan.';

  @override
  String get settingsPhoneTriggers => 'Puhelimen laukaisimet';

  @override
  String get settingsPhoneTriggersDescription =>
      'Signaalit, jotka tämä puhelin lähettää agenteillesi, jotta tehtävät voivat reagoida niihin.';

  @override
  String get settingsLocationTriggers => 'Sijainti triggerit';

  @override
  String get settingsLocationTriggersDescription =>
      'Tarkistaa likimääräisen sijaintisi muutaman minuutin välein tehtäviesi katselemiin paikkoihin verrattuna.';

  @override
  String get settingsNotificationTriggers => 'Ilmoituslaukaisimet';

  @override
  String get settingsNotificationTriggersDescription =>
      'Välittää ilmoitukset muista tämän puhelimen sovelluksista agenteillesi.';

  @override
  String get settingsSetup => 'Asennus';

  @override
  String get settingsOnboarding => 'Käyttöönotto';

  @override
  String get settingsOnboardingDescription =>
      'Käy ensimmäisen kerran asetukset läpi. Mikään määrittämäsi ei ole menetetty.';

  @override
  String get settingsUsernameDescription =>
      'Käytettiin kirjautumiseen. Sitä ei voi muuttaa.';

  @override
  String get settingsExport => 'Vie';

  @override
  String get settingsLeave => 'Kirjaudu ulos ja poista';

  @override
  String get settingsSignOutDescription =>
      'Kirjaa sinut ulos vain tältä laitteelta.';

  @override
  String get settingsDeleteAccountDescription =>
      'Tyhjentää tilisi, agentit, muistisi ja asetukset. Tätä ei voi kumota.';

  @override
  String get settingsTokenUsage => 'Tokenin käyttö';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Mikään asetus ei vastaa \"$query\".';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osumaa',
      one: '$count osuma',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Mallin lisäasetukset';

  @override
  String get settingsAdvancedModelsDescription =>
      'Valinnainen. Kiinnitä malli yhteen työhön; se ottaa haltuunsa aina, kun agentti käyttää näitä työkaluja. Kaikki oletusarvoon jätetty seuraa chat-mallia.';

  @override
  String get settingsTaskModelDefault => 'Oletus';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Noudattaa chat-mallia';

  @override
  String get settingsTaskModelCoding => 'Koodaus';

  @override
  String get settingsTaskModelCodingDescription =>
      'Koodin kirjoittaminen, muokkaaminen ja virheenkorjaus.';

  @override
  String get settingsTaskModelComputerUse => 'Tietokoneen käyttö';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Selaimen ja työpöydän käyttö.';

  @override
  String get settingsTaskModelAndroidUse => 'Android käyttö';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Sovellusten käyttäminen Android-laitteella tai emulaattorilla.';

  @override
  String get settingsTaskModelResearch => 'Tutkimus';

  @override
  String get settingsTaskModelResearchDescription =>
      'Lähteiden etsiminen, lukeminen ja yhteenveto.';

  @override
  String get knowledgeGraphHint =>
      'Eniten mainitut entiteettisi klusterin mukaan väritettynä. Viivat yhdistävät entiteettejä, jotka esiintyvät samoissa muistoissa. Napauta yhtä nähdäksesi sen linkit ja muistot; vetämällä panoroidaksesi, nipistämällä tai Ctrl/⌘-vieritä zoomaaksesi.';

  @override
  String get linkedEntities => 'Linkitetyt entiteetit';

  @override
  String get noLinkedEntities => 'Ei vielä linkitetty muihin kokonaisuuksiin.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 mainitsee';
  }

  @override
  String get entityKindConcept => 'käsite';

  @override
  String get entityKindDomain => 'Verkkotunnus';

  @override
  String get entityKindEmail => 'Sähköposti';

  @override
  String get entityKindLink => 'Linkki';

  @override
  String get entityKindFile => 'Tiedosto';

  @override
  String get entityKindAcronym => 'Lyhenne';

  @override
  String get entityKindIdentifier => 'Tunniste';

  @override
  String get entityKindVersion => 'Versio';

  @override
  String get openFullscreen => 'Avaa koko näyttö';

  @override
  String get zoomIn => 'Lähennä';

  @override
  String get zoomOut => 'Loitonna';

  @override
  String get searchEntities => 'Etsi kokonaisuus';

  @override
  String get incomingCall => 'Saapuva puhelu';

  @override
  String get answerCall => 'Vastaa';

  @override
  String get callMeLater => 'Soita minulle myöhemmin';

  @override
  String get callingEllipsis => 'Soitetaan…';

  @override
  String get reconnectingCall => 'Yhdistetään uudelleen';

  @override
  String get agentWorking => 'Työskentely';

  @override
  String get micMuted => 'Mykistetty';

  @override
  String get speakerphone => 'Kaiutin';

  @override
  String get muteMic => 'Mykistä';

  @override
  String get unmuteMic => 'Poista mykistys';

  @override
  String get releaseToSend => 'Vapauta lähettääksesi';

  @override
  String get callEnded => 'Puhelu päättyi';

  @override
  String get openConversation => 'Avaa keskustelu';

  @override
  String get callBack => 'Soita takaisin';

  @override
  String get letCallsReachYou => 'Anna puheluiden tavoittaa sinut';

  @override
  String get callPermissionsIntro =>
      'Agenttisi voivat soittaa sinulle. Jos haluat soittaa kuin puhelu, kun NeoAgent on taustalla tai puhelimesi on lukittu, se tarvitsee nämä.';

  @override
  String get showOverOtherApps => 'Näytä muiden sovellusten päällä';

  @override
  String get showOverOtherAppsDetail => 'Tuo puhelunäytön esiin missä tahansa.';

  @override
  String get fullScreenCalls => 'Koko näytön puhelut';

  @override
  String get fullScreenCallsDetail => 'Soi lukitusnäytön päällä.';

  @override
  String get unrestrictedBattery => 'Rajoittamaton akku';

  @override
  String get unrestrictedBatteryDetail =>
      'Pitää NeoAgentin yhteydessä, jotta puhelut saapuvat.';

  @override
  String get permissionAllowed => 'Sallittu';

  @override
  String get triggerSectionCalendar => 'Kalenteri';

  @override
  String get triggerSectionFiles => 'Tiedostot ja asiakirjat';

  @override
  String get triggerSectionHome => 'Koti ja media';

  @override
  String get triggerSectionDevices => 'Laitteet ja paikat';

  @override
  String get triggerSectionTasks => 'Tehtävät';

  @override
  String get messagingMemberJoined => 'Jäsen liittyi';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Suorita, kun joku liittyy Discord-palvelimeen, Telegram- tai WhatsApp-ryhmään, Slack-kanavaan tai Matrix-huoneeseen.';

  @override
  String get messagingMemberLeft => 'Jäsen lähti';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Suorita, kun joku poistuu Discord-palvelimesta, Telegram- tai WhatsApp-ryhmästä, Slack-kanavasta tai Matrix-huoneesta.';

  @override
  String get messagingReactionAdded => 'Reaktio lisätty';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Juokse, kun sallittu henkilö reagoi viestiin yksityisessä chatissa.';

  @override
  String get messagingPlatformDisconnected => 'Viestit katkaistu';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Suorita, kun viestiyhteys katkeaa ja tarvitsee sinua, esimerkiksi uloskirjautumisen jälkeen.';

  @override
  String get googleCalendarEventStarting => 'Google-kalenterin tapahtuma alkaa';

  @override
  String get googleCalendarEventCreated => 'Google-kalenterin tapahtuma luotu';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Suorita, kun uusi tapahtuma tai kutsu tulee näkyviin.';

  @override
  String get outlookCalendarEventStarting =>
      'Outlook-kalenterin tapahtuma alkaa';

  @override
  String get nextcloudCalendarEventStarting =>
      'Nextcloud-kalenteritapahtuma alkaa';

  @override
  String get runMinutesBeforeEachEvent =>
      'Juokse tietty määrä minuutteja ennen jokaista tapahtumaa.';

  @override
  String get googleDriveFileAdded => 'Google Drive -tiedosto lisätty';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Suorita, kun tiedosto lisätään Driveen tai sen kansioon.';

  @override
  String get googleSheetsRowAdded => 'Google Sheets -rivi lisätty';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Suorita, kun taulukkoon tulee uusia rivejä.';

  @override
  String get onedriveFileAdded => 'OneDrive-tiedosto lisätty';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Suorita, kun tiedosto lisätään OneDrive-kansioon.';

  @override
  String get nextcloudFileAdded => 'Nextcloud-tiedosto lisätty';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Suorita, kun tiedosto lisätään Nextcloud-kansioon.';

  @override
  String get nextcloudShareReceived => 'Nextcloud-tiedosto jaettu kanssasi';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Suorita, kun joku jakaa tiedoston tai kansion kanssasi.';

  @override
  String get notionItemAdded => 'Käsitetietokantakohde lisätty';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Suorita, kun kohde lisätään Notion-tietokantaan.';

  @override
  String get notionItemUpdated => 'Käsitetietokannan kohde päivitetty';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Suorita, kun Notion-tietokannan alkio muuttuu.';

  @override
  String get trelloCardEnteredList => 'Trello-kortti lisätty luetteloon';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Suorita, kun kortti luodaan tai siirretään luetteloon.';

  @override
  String get figmaCommentAdded => 'Figman kommentti lisätty';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Suorita, kun joku kommentoi Figma-tiedostoa.';

  @override
  String get githubPrOpened => 'GitHubin vetopyyntö avattiin';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Suorita, kun uusi vetopyyntö avataan arkistossa.';

  @override
  String get githubWorkflowRunFailed => 'GitHub-työnkulku epäonnistui';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Suorita, kun GitHub Actions -ajo epäonnistuu.';

  @override
  String get githubCommitPushed => 'GitHub-sitoumus työnnetty';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Suorita, kun uudet sitoumukset saavuttavat haaran.';

  @override
  String get mcpServerFailed => 'MCP-palvelin epäonnistui';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Suorita, kun toimiva MCP-palvelin epäonnistuu tai vaatii sisäänkirjautumisen.';

  @override
  String get homeAssistantStateChanged => 'Home Assistantin tila muuttunut';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Suorita, kun entiteetti muuttuu, saavuttaa tilan tai ylittää arvon.';

  @override
  String get spotifyTrackChanged => 'Spotify-raita muutettu';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Suorita, kun eri raita alkaa toistaa.';

  @override
  String get neorecallDailySummaryReady =>
      'NeoRecall päivittäinen yhteenveto valmis';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Suorita, kun päivän yhteenveto on lopullinen.';

  @override
  String get neorecallConversationRecorded =>
      'NeoRecall-keskustelu tallennettu';

  @override
  String get runWhenARecordedConversationEnds =>
      'Suorita, kun tallennettu keskustelu päättyy.';

  @override
  String get geofenceTrigger => 'Sijainti geoaita';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Juokse, kun puhelimesi saapuu paikalle tai lähtee sieltä. Tarvitsee sijainnin seurannan puhelimessa.';

  @override
  String get healthMetricRecorded => 'Terveysmittari kirjattu';

  @override
  String get runWhenAHealthReadingArrives =>
      'Suorita, kun synkronoitu kuntolukema saapuu, valinnaisesti arvon ylä- tai alapuolella.';

  @override
  String get wearableConnectionChanged =>
      'Käytettävä kytkettynä tai irrotettuna';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Suorita, kun puettava laite kytkeytyy tai katkeaa.';

  @override
  String get taskRunFinished => 'Toinen tehtävä valmis';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Suorita toisen tehtävän valmistumisen, onnistumisen tai epäonnistumisen jälkeen.';

  @override
  String get appPackageOptional => 'Sovelluspaketti (valinnainen)';

  @override
  String get appPackageHelper => 'Esimerkiksi com.whatsapp';

  @override
  String get anyPlatform => 'Mikä tahansa alusta';

  @override
  String get spaceIdOptional =>
      'Palvelimen, ryhmän, kanavan tai huoneen tunnus (valinnainen)';

  @override
  String get spaceIdHelper => 'Tyhjät kellot, joissa botti on.';

  @override
  String get emojiOptional => 'Emoji (valinnainen)';

  @override
  String get chatIdOptional => 'Chat-tunnus (valinnainen)';

  @override
  String get platformOptional => 'Alusta (valinnainen)';

  @override
  String get platformOptionalHelper =>
      'Esimerkiksi whatsapp. Tyhjiä kellot kaikki.';

  @override
  String get minutesBefore => 'Minuuttia ennen';

  @override
  String get calendarIdOptional => 'Kalenteritunnus (valinnainen)';

  @override
  String get calendarIdHelper => 'Tyhjä käyttää ensisijaista kalenteriasi.';

  @override
  String get invitesOnly => 'Vain kutsut muilta';

  @override
  String get nextcloudCalendarPath => 'Kalenteri';

  @override
  String get nextcloudCalendarPathHelper =>
      'Sen nimi Nextcloud-kalenteriluettelossa, esimerkiksi henkilökohtainen';

  @override
  String get folderIdOptionalHelperDrive => 'Tyhjät kellot koko Drivesta.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Empty tarkkailee juurikansiota.';

  @override
  String get driveFolderIdOptional => 'Kansion tunnus (valinnainen)';

  @override
  String get spreadsheetId => 'Laskentataulukon tunnus';

  @override
  String get sheetRange => 'Alue';

  @override
  String get sheetRangeHelper => 'Taulukon sarakkeet, esimerkiksi Sheet1!A:E';

  @override
  String get folderPathOptional => 'Kansion polku (valinnainen)';

  @override
  String get folderPathHelper => 'Esimerkiksi asiakirjat';

  @override
  String get notionDatabaseId => 'Tietokannan tunnus';

  @override
  String get trelloListId => 'Luettelon tunnus';

  @override
  String get figmaFileKey => 'Tiedostoavain';

  @override
  String get figmaFileKeyHelper => 'Tiedostolinkistä: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Arkisto';

  @override
  String get workflowOptional => 'Työnkulku (valinnainen)';

  @override
  String get workflowHelper => 'Tiedostonimi, kuten ci.yml';

  @override
  String get branchOptional => 'Haara (valinnainen)';

  @override
  String get branchHelper => 'Tyhjä käyttää oletushaaraa.';

  @override
  String get mcpServerIdOptional => 'MCP-palvelimen tunnus (valinnainen)';

  @override
  String get entityId => 'Entiteetin tunnus';

  @override
  String get entityIdHelper => 'Esimerkiksi binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Kohdetila (valinnainen)';

  @override
  String get targetStateHelper => 'Esimerkiksi päällä';

  @override
  String get aboveOptional => 'Yllä (valinnainen)';

  @override
  String get belowOptional => 'Alla (valinnainen)';

  @override
  String get placeName => 'Paikan nimi';

  @override
  String get latitude => 'Leveysaste';

  @override
  String get longitude => 'Pituusaste';

  @override
  String get radiusMeters => 'Säde metreinä';

  @override
  String get geofenceTransition => 'Milloin';

  @override
  String get arriving => 'Saapumassa';

  @override
  String get leaving => 'Lähtemässä';

  @override
  String get healthMetric => 'Terveysmittari';

  @override
  String get healthMetricHelper => 'Esimerkiksi syke, askeleet, paino';

  @override
  String get wearableTransition => 'Kun puettavat';

  @override
  String get wearableConnects => 'Yhdistää';

  @override
  String get wearableDisconnects => 'Katkaisee yhteyden';

  @override
  String get sourceTask => 'Tehtävän jälkeen';

  @override
  String get taskOutcome => 'Tulos';

  @override
  String get anyOutcome => 'Mikä tahansa tulos';

  @override
  String get succeeded => 'Onnistui';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 puuttuu tai ei kelpaa.';
  }

  @override
  String get triggerSectionMessaging => 'Viestit';

  @override
  String get triggerSectionDeveloper => 'Kehittäjä';

  @override
  String get triggerSectionMemory => 'Muisti';

  @override
  String get triggerSectionNews => 'Uutiset';

  @override
  String get triggerSectionSystem => 'Järjestelmä';

  @override
  String get searchTriggersHint =>
      'Hae triggereitä, sovelluksia tai tapahtumia';

  @override
  String get noTriggersMatch => 'Mikään laukaisin ei vastaa hakuasi.';

  @override
  String get triggerAccountMissing => 'Ei vielä tiliä';

  @override
  String get pickTriggerKeyboardHint => 'Enter valitsee ensimmäisen tuloksen';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 liipaisimet';
  }

  @override
  String get addFromSkillsSh => 'Lisää osoitteesta skill.sh';

  @override
  String get skillsShHint =>
      'Hae ylhäältä löytääksesi taidot osoitteesta skill.sh tai liitä skill.sh-linkki tai \"npx skills add\" -komento.';

  @override
  String get noSkillsShMatches =>
      'Mikään skill.sh-taidot ei vastaa tätä hakua.';

  @override
  String get installingSkill => 'Asennetaan…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Asennettu $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return '$arg1 asentaa';
  }

  @override
  String get authVerify => 'Vahvista';

  @override
  String get authCreateAccount => 'Luo tili';

  @override
  String get authNewInviteLink => 'Uusi kutsulinkki';

  @override
  String get authShowPassword => 'Näytä salasana';

  @override
  String get authHidePassword => 'Piilota salasana';

  @override
  String get authPasswordWillBeRejected => 'liian heikko, hylätään';

  @override
  String get authUsernameTooShort =>
      'Käyttäjänimissä on oltava vähintään 3 merkkiä.';

  @override
  String get authUsernameTaken => 'Tämä käyttäjätunnus on jo varattu.';

  @override
  String get authSignupsClosed =>
      'Ilmoittautuminen on suljettu tällä palvelimella. Pyydä järjestelmänvalvojalta tili.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Tämä palvelin hyväksyy vain HTTPS-sisäänkirjautumiset. Avaa sen sijaan $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Tämä palvelin hyväksyy vain HTTPS-sisäänkirjautumiset. Yhdistä siihen https://-osoitteella.';

  @override
  String get authAccountNotFound => 'Sitä tiliä ei enää ole.';

  @override
  String get authQrRateLimited =>
      'Liian monta QR-kirjautumispyyntöä. Odota hetki ja päivitä sitten koodi.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Unohditko salasanasi? Pyydä palvelimen järjestelmänvalvojaa nollaamaan se kohdassa Järjestelmänvalvoja → Käyttäjät.';

  @override
  String get authChangeServer => 'Vaihda palvelinta';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Kirjautuminen sisään $arg1:ään';
  }

  @override
  String get authNotANeoagentServer =>
      'Tämä osoite ei vastaa kuin NeoAgent-palvelin. Tarkista URL-osoite ja yritä uudelleen.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Suojattua (HTTPS) yhteyttä $arg1:ään ei voitu avata.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return '$arg1 ei saanut yhteyttä HTTPS:n kautta, eikä tavallinen HTTP myöskään vastannut. Tarkista osoite ja portti.';
  }

  @override
  String get adminResetPassword => 'Palauta salasana';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Palauta salasana $arg1:lle';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Valitse uusi salasana $arg1:lle. He kirjataan ulos kaikilta laitteilta ja kirjautuvat uudelleen sisään tällä salasanalla.';
  }

  @override
  String get adminNewPassword => 'Uusi salasana';

  @override
  String get adminSetPassword => 'Aseta salasana';

  @override
  String get authMissingFields => 'Täytä kaikki vaaditut kentät.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 nollaa $arg2:n salasanan';
  }

  @override
  String get adminPasswordUpdated =>
      'Salasana päivitetty; käyttäjä kirjattiin ulos kaikkialta.';

  @override
  String get authSignInTitle => 'Kirjaudu sisään NeoAgentiin';

  @override
  String get authSignInSubtitle =>
      'Skannaa puhelimellasi tai käytä salasanaasi.';

  @override
  String get authOrUsePassword => 'tai käytä salasanaasi';

  @override
  String get qrLoginWaitingTitle => 'Hyväksy puhelimellasi';

  @override
  String get qrLoginWaitingBody =>
      'Puhelimesi skannasi koodin. Viimeistele kirjautuminen vahvistamalla sisäänkirjautuminen siellä.';

  @override
  String get qrLoginSigningInOn => 'Kirjautuminen sisään';

  @override
  String get qrLoginLocation => 'Sijainti';

  @override
  String get qrLoginWaitingForApproval => 'Odotetaan hyväksyntää';

  @override
  String get qrLoginCancelAndUsePassword => 'Peruuta ja käytä salasanaa';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Kirjautuminen hylättiin puhelimellasi. Skannaa uusi koodi ja yritä uudelleen.';

  @override
  String get signupKey => 'Rekisteröitymisavain';

  @override
  String get signupKeyStepSubtitle =>
      'Tämän palvelimen uudet tilit tarvitsevat rekisteröitymisavaimen. Anna ylläpitäjältä saamasi avain.';

  @override
  String get signupKeyChange => 'Vaihda';

  @override
  String get signupKeyRequiredError => 'Anna rekisteröitymisavaimesi.';

  @override
  String get signupKeyInvalidError =>
      'Rekisteröitymisavain ei kelpaa. Tarkista se ja yritä uudelleen.';

  @override
  String get signupKeyUsedError =>
      'Rekisteröitymisavain on jo käytetty. Pyydä ylläpitäjältä uusi.';

  @override
  String get adminRequireSignupKey => 'Vaadi rekisteröitymisavain';

  @override
  String get adminRequireSignupKeyHint =>
      'Uudet tilit tarvitsevat ylläpitäjältä kertakäyttöisen avaimen. Kun tämä on pois päältä, kuka tahansa palvelimen tavoittava voi rekisteröityä. Ensimmäinen tili ei koskaan tarvitse avainta.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Uudet tilit tarvitsevat nyt rekisteröitymisavaimen.';

  @override
  String get adminSignupOpenNotice => 'Kuka tahansa voi nyt rekisteröityä.';

  @override
  String get signupKeys => 'Rekisteröitymisavaimet';

  @override
  String get signupKeysDescription =>
      'Kertakäyttöiset avaimet rekisteröitymiseen, kun avain vaaditaan. Jokainen avain luo täsmälleen yhden tilin.';

  @override
  String get signupKeysNew => 'Uudet avaimet';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Käyttämättömät · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Käytetyt · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Peruutetut · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Kaikki · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Käyttämätön';

  @override
  String get signupKeyStatusUsed => 'Käytetty';

  @override
  String get signupKeyStatusRevoked => 'Peruutettu';

  @override
  String get signupKeysExport => 'Vie .txt-tiedostoon';

  @override
  String get signupKeysCopied => 'Avaimet kopioitu';

  @override
  String get signupKeyCopied => 'Avain kopioitu';

  @override
  String get signupKeysEmpty => 'Tässä luettelossa ei ole avaimia.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Luotu $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Käyttäjä $arg1 käytti $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Käytetty $arg1 tilillä, joka on sittemmin poistettu';
  }

  @override
  String get signupKeyRevokeTitle => 'Peruutetaanko tämä avain?';

  @override
  String get signupKeyRevokeMessage =>
      'Kukaan ei voi enää rekisteröityä sillä. Toimintoa ei voi kumota.';

  @override
  String get signupKeyRevoked => 'Avain peruutettu.';

  @override
  String signupKeysShowMore(int count) {
    return 'Näytä $count lisää';
  }

  @override
  String get signupKeysCreateTitle => 'Luo rekisteröitymisavaimia';

  @override
  String get signupKeysCount => 'Avainten määrä';

  @override
  String get signupKeysCountHelper => '1–500';

  @override
  String get signupKeysCountInvalid => 'Anna luku väliltä 1–500.';

  @override
  String get signupKeysLabel => 'Nimi (valinnainen)';

  @override
  String get signupKeysLabelHint => 'esim. Kevään beetatestaajat';

  @override
  String signupKeysCreateAction(int count) {
    return 'Luo ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Avaimet valmiina: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Anna kukin avain vain yhdelle henkilölle. Käyttämättömät avaimet pysyvät luettelossa, joten voit kopioida tai viedä ne myöhemmin uudelleen.';

  @override
  String get signupKeysSaveDialogTitle => 'Tallenna rekisteröitymisavaimet';

  @override
  String get signupKeysExported => 'Avaimet viety.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor loi rekisteröitymisavaimia ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor peruutti rekisteröitymisavaimen';
  }

  @override
  String get providerChooseUsername => 'Valitse käyttäjänimi';

  @override
  String get providerChooseUsernameBody =>
      'Valitse vapaa käyttäjänimi viimeistelläksesi tilisi luomisen.';

  @override
  String get dataSharingTitle => 'Jaa käyttötietoja';

  @override
  String get dataSharingDescription =>
      'Auta tämän palvelimen ylläpitäjiä parantamaan sitä. Jakaa sen, miten käytät NeoAgentia, ei koskaan sitä, mitä kirjoitat tai tallennat.';

  @override
  String dataSharingSince(String date) {
    return 'Jaettu $date alkaen.';
  }

  @override
  String get dataSharingWhatsShared => 'Mitä jaetaan';

  @override
  String get dataSharingIncluded => 'Jaetaan';

  @override
  String get dataSharingExcluded => 'Ei koskaan jaeta';

  @override
  String get dataSharingIncludedDevice => 'Laitetyyppi ja sovellusversio';

  @override
  String get dataSharingIncludedLocale =>
      'Sovelluksen kieli ja aikavyöhykkeen alue, esimerkiksi Eurooppa';

  @override
  String get dataSharingIncludedFeatures =>
      'Mitkä toiminnot olet ottanut käyttöön, kuten tehtävät, skillit ja integraatiot';

  @override
  String get dataSharingIncludedRuns =>
      'Mitä työkaluja ja malleja ajosi käyttävät, kestoineen ja token-määrineen';

  @override
  String get dataSharingIncludedActivity =>
      'Milloin käytät NeoAgentia, viikonpäivittäin ja tunneittain';

  @override
  String get dataSharingExcludedContent => 'Viestit, kehotteet ja vastaukset';

  @override
  String get dataSharingExcludedRuns =>
      'Ajojen otsikot, työkalujen syötteet ja tulokset';

  @override
  String get dataSharingExcludedFiles =>
      'Tiedostot, muistot ja kaikki muu, mitä tallennat';

  @override
  String get dataSharingExcludedIdentity =>
      'Nimesi, sähköpostisi, IP-osoitteesi ja sijaintisi';

  @override
  String get dataSharingExcludedAccounts =>
      'Tilit, joilla yhdistät integraatioita';

  @override
  String get dataSharingPooledNote =>
      'Ylläpitäjät näkevät vain kaikkien jakajien yhteissummat, eivät koskaan sinua erikseen. Voit poistaa sen käytöstä milloin tahansa, ja poistut summista heti.';

  @override
  String get dataSharingConfirmTitle => 'Jaetaanko käyttötiedot?';

  @override
  String get dataSharingConfirmAction => 'Jaa';

  @override
  String get sharedUsageTitle => 'Jaettu käyttö';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Käyttötietoja jakavat tilit: $sharing/$total. Vain summia, ei sisältöä.';
  }

  @override
  String get sharedUsageEmpty =>
      'Kukaan ei vielä jaa käyttötietoja. Sen voi ottaa käyttöön kohdassa Asetukset, Profiili, Tietosi.';

  @override
  String get sharedUsageRuns => 'Jaetut ajot';

  @override
  String get sharedUsageAvgDuration => 'Keskim. kesto';

  @override
  String get sharedUsageCompletedRuns => 'Valmiit ajot';

  @override
  String get sharedUsageStepsPerRun => 'Vaiheita per ajo';

  @override
  String get sharedUsageDevices => 'Laitteet';

  @override
  String get sharedUsageAppVersions => 'Sovellusversiot';

  @override
  String get sharedUsageLanguages => 'Kielet';

  @override
  String get sharedUsageRegions => 'Alueet';

  @override
  String get sharedUsageFeatures => 'Toimintojen käyttöönotto';

  @override
  String get sharedUsageFeaturesDescription =>
      'Osuus jakavista tileistä, jotka ovat ottaneet sen käyttöön.';

  @override
  String get sharedUsageTools => 'Työkalut';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Eniten kutsutut työkalut ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Kutsuja: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Epäonnistui: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integraatiot';

  @override
  String get sharedUsageMessaging => 'Viestikanavat';

  @override
  String get sharedUsageTriggers => 'Miten ajot alkavat';

  @override
  String get sharedUsageActivity => 'Milloin sitä käytetään';

  @override
  String get sharedUsageActivityDescription =>
      'Ajot viikonpäivän ja tunnin mukaan, UTC.';

  @override
  String get sharedUsageModels => 'Mallien suorituskyky';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'keskim. $latency · $cached % välimuistista · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Tilejä: $count';
  }

  @override
  String get sharedUsageNoData => 'Ei mitään tällä aikavälillä.';

  @override
  String get sharedUsageNotReported => 'Ei vielä ilmoitettu';

  @override
  String get sharedUsageFeatureAgents => 'Useampi kuin yksi agentti';

  @override
  String get sharedUsageFeatureTasks => 'Ajoitetut tehtävät';

  @override
  String get sharedUsageFeatureSkills => 'Skillit';

  @override
  String get sharedUsageFeatureMcp => 'MCP-palvelimet';

  @override
  String get sharedUsageFeatureIntegrations => 'Integraatiot';

  @override
  String get sharedUsageFeatureMessaging => 'Viestikanavat';

  @override
  String get sharedUsageFeatureMemory => 'Muisti';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in tietojen jakaminen telemetria laitteet toiminnot työkalut mallit aktiivisuus';

  @override
  String get yourOAuthApp => 'OAuth-sovelluksesi';

  @override
  String oauthAppSetupTitle(String provider) {
    return '$provider-OAuth-sovelluksesi';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Tällä palvelimella ei ole yleistä $provider-sovellusta, joten yhdistät itse rekisteröimälläsi OAuth-sovelluksella. Asiakassalaisuus tallennetaan salattuna eikä sitä näytetä enää koskaan.';
  }

  @override
  String get oauthAppStepCreate => '1. Luo sovellus';

  @override
  String get openDeveloperConsole => 'Avaa kehittäjäkonsoli';

  @override
  String get oauthAppStepCallback => '2. Rekisteröi tämä paluu-URL';

  @override
  String get callbackUrlCopied => 'Paluu-URL kopioitu';

  @override
  String get oauthAppScopes => 'Sallittavat scopet';

  @override
  String get scopesCopied => 'Scopet kopioitu';

  @override
  String get oauthAppStepCredentials => '3. Liitä sovelluksen tunnukset';

  @override
  String get couldNotSaveOAuthApp => 'OAuth-sovellusta ei voitu tallentaa.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Poistetaanko $provider-sovelluksesi?';
  }

  @override
  String get removeOAuthAppBody =>
      'Yhdistetyt tilit pysyvät listassa, mutta lakkaavat toimimasta, kunnes lisäät sovelluksen uudelleen.';

  @override
  String get globalIntegrationConfiguration =>
      'Integraatioiden yleiset asetukset';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Valinnaiset koko palvelimen OAuth-sovellukset. Kun integraatiolla on sellainen, jokainen tili käyttää sitä eikä voi lisätä omaansa. Jätä integraatio tyhjäksi, niin jokainen käyttäjä määrittää oman sovelluksensa. Salaisuudet ovat vain kirjoitettavia: jätä tyhjäksi säilyttääksesi tallennetun arvon.';

  @override
  String get globalStatus => 'Yleinen';

  @override
  String get perUserStatus => 'Käyttäjäkohtainen';

  @override
  String get phoneSyncGuidance =>
      'Jaa tämän puhelimen kalenterit ja yhteystiedot agentillesi. Toimii kaikkien puhelimessa jo olevien tilien kanssa.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Avaa NeoAgent puhelimessa ja ota jakaminen käyttöön siellä. Agenttisi näkee sitten kaikkien puhelimen tilien kalenterit ja yhteystiedot.';

  @override
  String get manageOnThisPhone => 'Hallitse tässä puhelimessa';

  @override
  String get setUpOnThisPhone => 'Määritä tässä puhelimessa';

  @override
  String get setUpOnPhone => 'Määritä puhelimessasi';

  @override
  String emailConnectedArg1(String email) {
    return '$email yhdistetty';
  }

  @override
  String get couldNotConnectEmail => 'Tiliä ei voitu yhdistää.';

  @override
  String get emailSetupTitle => 'Yhdistä sähköposti ja kalenteri';

  @override
  String get emailChecking => 'Tarkistetaan postilaatikkoa…';

  @override
  String get emailSetupIntro =>
      'Käytä sähköpostipalvelusi sovelluskohtaista salasanaa. Ei kehittäjäkonsolia, valmis muutamassa minuutissa.';

  @override
  String emailOpenArg1(String provider) {
    return 'Avaa $provider';
  }

  @override
  String get emailStepServers => '1. Anna palvelimet';

  @override
  String get emailStepPassword => '1. Luo sovelluskohtainen salasana';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Avaa $provider: sovelluskohtaiset salasanat';
  }

  @override
  String get emailStepSignIn => '2. Kirjaudu';

  @override
  String get appPassword => 'Sovelluskohtainen salasana';

  @override
  String get appPasswordHelper =>
      'Välilyönneillä ei ole väliä. NeoAgent tallentaa sen salattuna.';

  @override
  String get emailUsernameOptional =>
      'Käyttäjänimi, jos se ei ole sähköpostiosoitteesi';

  @override
  String get emailIncludeCalendar => 'Sisällytä kalenteri';

  @override
  String get emailIncludeContacts => 'Sisällytä yhteystiedot';

  @override
  String get imapServer => 'IMAP-palvelin';

  @override
  String get smtpServer => 'SMTP-palvelin';

  @override
  String get caldavUrlOptional => 'CalDAV-URL (valinnainen)';

  @override
  String get carddavUrlOptional => 'CardDAV-URL (valinnainen)';

  @override
  String get alternativeEmail =>
      'Yhdistä postilaatikko sovelluskohtaisella salasanalla tai kalenteri sen iCal-linkillä. Valmis muutamassa minuutissa.';

  @override
  String get alternativePhone =>
      'Jaa puhelimessa jo oleva kalenteri ja yhteystiedot NeoAgent-sovelluksella.';

  @override
  String get alternativePhoneElsewhere =>
      'Jaa puhelimessa jo oleva kalenteri ja yhteystiedot. Määritä se puhelimen NeoAgent-sovelluksessa.';

  @override
  String get skipTheDeveloperConsole => 'Ohita kehittäjäkonsoli';

  @override
  String get phoneSyncPromptTitle => 'Saako agenttisi nähdä kalenterisi?';

  @override
  String get phoneSyncPromptBody =>
      'Jaa tämän puhelimen kalenterit ja yhteystiedot, niin agenttisi voi suunnitella päiväsi mukaan. Voit muuttaa tätä milloin tahansa kohdassa Työkalut › Integraatiot.';

  @override
  String get phoneSyncTitle => 'Jaa tämän puhelimen kalenteri ja yhteystiedot';

  @override
  String get phoneSyncIntro =>
      'Agenttisi näkee kaikkien tämän puhelimen tilien kalenterit ja yhteystiedot. Ei kehittäjäkonsolia, ei lisäkirjautumista.';

  @override
  String get phoneSyncPointAccounts =>
      'Toimii tämän puhelimen Google-, Outlook-, iCloud- ja Exchange-tilien kanssa.';

  @override
  String get phoneSyncPointPrivate =>
      'Jaetaan vain NeoAgent-palvelimellesi, jossa se tallennetaan salattuna.';

  @override
  String get phoneSyncPointWrites =>
      'Agentin lisäämät tapahtumat luo tämä puhelin, ja ne synkronoituvat tavalliseen tapaan.';

  @override
  String get phoneSyncCalendarHint =>
      'Tapahtumat 30 päivää taaksepäin ja 90 päivää eteenpäin';

  @override
  String get phoneSyncContacts => 'Yhteystiedot';

  @override
  String get phoneSyncContactsHint =>
      'Nimet, sähköpostiosoitteet ja puhelinnumerot';

  @override
  String get phoneSyncOtherAgent =>
      'Tämä puhelin jakaa toiselle agentille. Jakaminen tässä siirtää sen tälle agentille.';

  @override
  String get phoneSyncDenied =>
      'NeoAgentilla ei ole vielä käyttöoikeutta. Salli se asetuksissa ja palaa takaisin.';

  @override
  String get openPhoneSettings => 'Avaa asetukset';

  @override
  String get phoneSyncShare => 'Jaa NeoAgentille';

  @override
  String get phoneSyncStop => 'Lopeta jakaminen';

  @override
  String get phoneSyncWaiting => 'Odotetaan ensimmäistä synkronointia…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Synkronoitu viimeksi $time';
  }

  @override
  String get calendarLink => 'Kalenterilinkki';

  @override
  String get calendarLinkHelper =>
      'Kalenterin iCal-osoite. Kuka tahansa osoitteen tunteva voi lukea kalenteria, joten pidä se yksityisenä.';

  @override
  String get calendarLinkName => 'Nimi (valinnainen)';

  @override
  String get calendarLinkAdded => 'Kalenteri lisätty';

  @override
  String get toolsApps => 'Sovellukset';

  @override
  String get reconnect => 'Yhdistä uudelleen';

  @override
  String get reconnectNeeded => 'Yhdistettävä uudelleen';

  @override
  String get mixedAccess => 'Sekalainen käyttöoikeus';

  @override
  String disconnectAccountTitle(String account) {
    return 'Katkaistaanko $account?';
  }

  @override
  String disconnectAccountBody(String apps) {
    return 'Agentti menettää tämän tilin kautta pääsyn kohteisiin $apps.';
  }

  @override
  String get neoRouterServerDescription =>
      'Yhdistä NeoRouter kerran, niin jokainen tämän palvelimen tili käyttää sitä alla päälle kytkettyihin tehtäviin.';

  @override
  String get neoRouterUserDescription =>
      'Käytä omaa NeoRouter-tiliäsi alla päälle kytkettyihin tehtäviin tämän palvelimen palveluntarjoajien sijaan.';

  @override
  String get neoRouterAddress => 'NeoRouterin osoite';

  @override
  String get neoRouterConnect => 'Yhdistä NeoRouter';

  @override
  String neoRouterWaitingArg1(Object? arg1) {
    return 'Hyväksy NeoAgent NeoRouterissa. Se näyttää koodin $arg1.';
  }

  @override
  String get neoRouterOpenAgain => 'Avaa uudelleen';

  @override
  String neoRouterConnectedArg1(Object? arg1) {
    return 'Yhdistetty: $arg1';
  }

  @override
  String get neoRouterUnreachable =>
      'NeoRouteriin ei saada juuri nyt yhteyttä.';

  @override
  String get neoRouterDisconnect => 'Katkaise yhteys';

  @override
  String get neoRouterDisconnectBody =>
      'NeoAgent lopettaa tämän NeoRouterin käytön. Peru myös avain NeoRouterin API-avaimista.';

  @override
  String neoRouterServerInUseArg1(Object? arg1) {
    return 'Tämä palvelin käyttää jo NeoRouteria osoitteessa $arg1. Yhdistä siellä oma tilisi omia malleja ja budjettia varten.';
  }

  @override
  String get neoRouterConnected => 'NeoRouter on yhdistetty.';

  @override
  String get neoRouterRoleChat => 'Keskustelu ja kuvantunnistus';

  @override
  String get neoRouterRoleSystemOne => 'System One -päätökset';

  @override
  String get neoRouterRoleTranscription => 'Puheesta tekstiksi';

  @override
  String get neoRouterRoleLive => 'Livepuhe';

  @override
  String get neoRouterRoleEmbeddings => 'Muistihaku';

  @override
  String get neoRouterRoleImages => 'Kuvien luonti';

  @override
  String get neoRouterRoleSearch => 'Verkkohaku';

  @override
  String neoRouterModelCountArg1(Object? arg1) {
    return 'NeoRouterissasi saatavilla: $arg1';
  }

  @override
  String get neoRouterNoModels => 'NeoRouterissasi ei ole vielä mitään.';

  @override
  String get neoRouterPicksModels =>
      'NeoRouter valitsee mallin jokaiseen pyyntöön, joten tätä valikoimaa ei käytetä.';
}
