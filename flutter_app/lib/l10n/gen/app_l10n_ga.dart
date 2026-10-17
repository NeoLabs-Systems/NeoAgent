// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Irish (`ga`).
class AppL10nGa extends AppL10n {
  AppL10nGa([String locale = 'ga']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Fáilte';

  @override
  String get onboardingEyebrowCommunication => 'Cumarsáid';

  @override
  String get onboardingEyebrowIntelligence => 'Intleacht';

  @override
  String get onboardingEyebrowComputer => 'Ríomhaire';

  @override
  String get onboardingEyebrowAutomation => 'Uathoibriú';

  @override
  String get onboardingNext => 'Ar aghaidh';

  @override
  String get onboardingIntroCouldNotLoad =>
      'Níorbh fhéidir an t-iontráil a lódáil.';

  @override
  String get onboardingModelDescription =>
      'Roghnaigh an tsamhail ba cheart do NeoAgent a úsáid de réir réamhshocraithe, nó lig dó a roghnú go huathoibríoch.';

  @override
  String get onboardingLoadingModels => 'Múnlaí á lódáil…';

  @override
  String get noAiModelTitle => 'Níl aon mhúnla AI ar bun fós';

  @override
  String get noAiModelBody =>
      'Cuir eochair API leis ó sholáthraí ar nós OpenAI, Anthropic nó Google. Taispeánann NeoAgent ansin na samhlacha is féidir leat a úsáid.';

  @override
  String get noAiModelChatBody =>
      'Tá múnla AI ag teastáil ó NeoAgent le freagairt. Cuir eochair API leis ó sholáthraí ar nós OpenAI, Anthropic nó Google.';

  @override
  String get noAiModelAdminHint =>
      'Mar riarthóir is féidir leat soláthraithe a shocrú do gach duine faoi Riarachán → Soláthraithe.';

  @override
  String get addApiKey => 'Cuir eochair API leis';

  @override
  String onboardingMessagingConnected(String platform) {
    return 'Tá $platform ceangailte.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Ag fanacht le $platform chun nascadh…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'Níorbh fhéidir an tsuiteáil a shábháil: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Réidh';

  @override
  String get onboardingStepRequired => 'Ag teastáil';

  @override
  String get onboardingStepOptional => 'Roghnach';

  @override
  String get onboardingStepCloudOrLocal => 'Scamall nó áitiúil';

  @override
  String get onboardingStepComputer => 'Ríomhaire';

  @override
  String get onboardingStepRoutines => 'Gnáthaimh';

  @override
  String get onboardingComputerChoiceTitle => 'Cá háit ar cheart\ndó oibriú?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Is féidir leat athrú in aghaidh an tseisiúin.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Bosca gainimh príobháideach · ar siúl i gcónaí';

  @override
  String get onboardingThisComputer => 'An ríomhaire seo';

  @override
  String get onboardingThisComputerSubtitle =>
      'Do chomhaid, aipeanna agus brabhsálaí';

  @override
  String get onboardingSearchApps => 'Cuardaigh aipeanna…';

  @override
  String get onboardingRoutinesDescription => 'Tagann torthaí i do chomhráite.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Tagann na torthaí mar fhógraí.';

  @override
  String get onboardingNotifications => 'Fógraí';

  @override
  String get onboardingReadyTitle => 'Tá gach rud\nréidh.';

  @override
  String get onboardingReadyDescription => 'Seol do chéad teachtaireacht.';

  @override
  String get onboardingMessageNeoagent => 'Teachtaireacht NeoAgent';

  @override
  String get onboardingAskAnything => 'Fiafraigh rud ar bith…';

  @override
  String get onboardingOpenNeoagent => 'Oscail NeoAgent';

  @override
  String get onboardingStarterTrip =>
      'Déan turas deireadh seachtaine a phleanáil';

  @override
  String get onboardingStarterLanding => 'Tóg leathanach tuirlingthe';

  @override
  String onboardingQuickSteps(int count) {
    return '$count céimeanna tapa';
  }

  @override
  String get taskNeedsEmail => 'Ceangail ríomhphost ar dtús';

  @override
  String get taskNeedsCalendar => 'Ceangail féilire ar dtús';

  @override
  String get taskNeedsModel => 'Socraigh samhail AI ar dtús';

  @override
  String get taskPromptDailyRecap =>
      'Gabh siar mo lá: déan achoimre ar na comhráite, ar an obair chríochnaithe agus ar na cinntí ón lá atá inniu ann, ansin liostaigh aon rud ar cheart dom leanúint air amárach. Coinnigh gearr é agus seol chugam é.';

  @override
  String get taskPromptInboxCheck =>
      'Seiceáil mo bhosca isteach ríomhphoist le haghaidh teachtaireachtaí a tháinig ón tseiceáil dheireanach. Ná cuir teachtaireacht chugam ach faoi ríomhphoist atá práinneach nó a dteastaíonn freagra uathu, le hachoimre aon líne an ceann. Mura dteastaíonn m\'aird ar rud ar bith, ná seol rud ar bith.';

  @override
  String get taskPromptMorningBriefing =>
      'Ullmhaigh mo chruinniú faisnéise maidine: aimsir an lae inniu san áit a bhfuil mé, na himeachtaí ar mo fhéilire, agus na míreanna oscailte is tábhachtaí a bhfuil eolas agam orthu. Seol é mar theachtaireacht ghearr, inscanáilte.';

  @override
  String get taskPromptTomorrowPrep =>
      'Féach ar mo fhéilire don lá amárach. Do gach cruinniú, inis dom cad atá i gceist leis, cé atá i gceist agus aon rud ar cheart dom a ullmhú. Má bhíonn amárach folamh, ná seol rud ar bith.';

  @override
  String get taskPromptNewsDigest =>
      'Cuardaigh an gréasán le haghaidh an nuacht is tábhachtaí sa lá atá inniu ann ar na hábhair a bhfuil suim agam iontu (úsáid an rud is cuimhin leat faoi mo chuid spéise). Seol chugam achoimre suas le cúig mhír le habairt amháin an ceann agus nasc.';

  @override
  String get taskPromptWeeklyReview =>
      'Déan athbhreithniú ar mo sheachtain: cad a rinneadh, cad a shleamhnaigh agus cad atá fós oscailte. Mol na trí rud is tábhachtaí le díriú orthu an tseachtain seo chugainn.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Nasc uimhir theileafóin a bhaineann leis an ngníomhaire. Is féidir le haon duine a cheadaíonn tú comhrá a dhéanamh leis, i gcomhráite díreacha agus i ngrúpaí.';

  @override
  String get whatsappSelfChatDescription =>
      'Nasc d’uimhir féin agus labhair leis an ngníomhaire i do chomhrá “Teachtaireacht duit féin”. Déantar neamhaird de gach comhrá agus grúpa eile ar an gcuntas seo.';

  @override
  String get chatSendHintMac => '⌘↵ a sheoladh';

  @override
  String get chatSendHintOther => 'Ctrl+Iontráil le seoladh';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Tá bun URL ag teastáil don chríochphointe seo.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Deimhnítear seoladh ríomhphoist athraithe sula n-úsáidtear é.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Bhuaigh cinneadh níos airde suas an slabhra.';

  @override
  String get aDeletedAccount => 'cuntas scriosta';

  @override
  String get aFridayLookBackAtThe =>
      'Súil siar ar an tseachtain Dé hAoine agus plean don chéad cheann eile.';

  @override
  String get aKeyThatAsksForA =>
      'Gabhann eochair a iarrann PIN nó méarloirg ionad do chód dhá fhachtóir freisin.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Mheas múnla teanga an teachtaireacht seo toisc go bhfuil SystemOne múchta.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Sháraigh comhad meiteashonraí socraithe NeoAgent a theorainn shábháilte mhéide.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Tá tógáil gréasáin níos nuaí ar fáil ar an bhfreastalaí. Athlódáil chun an tsraith is déanaí a fháil.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Deasc príobháideach le Cróimiam, comhaid, eagarthóir téacs, teirminéal agus Python. Fanann do chuid oibre sábháilte idir seisiúin.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Ríomhaire Linux príobháideach nó feiste Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Níorbh fhéidir comhad socraithe NeoAgent riachtanach a íoslódáil.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Seolann comhghleacaí foirne nasc cuirí chugat. Nuair a ghlacann tú leis, siad ';

  @override
  String get aTeammateSentYouAnInvite =>
      'sheol comhghleacaí foirne nasc cuirí chugat, cuir isteach anseo é le bheith páirteach san fhoireann.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Déanfar íoslódáil sealadach a ghlanadh suas níos déanaí.';

  @override
  String get aValueIsStored => 'Stóráiltear luach.';

  @override
  String get access => 'Rochtain';

  @override
  String get accessActivity => 'Gníomhaíocht rochtana';

  @override
  String accessArg1(Object? arg1) {
    return 'Rochtain: $arg1';
  }

  @override
  String get accessMode => 'Modh rochtana';

  @override
  String get accessPermissions => 'Ceadanna rochtana';

  @override
  String get accessToken => 'comhartha rochtana';

  @override
  String get accessToken2 => 'Comhartha rochtana';

  @override
  String get account => 'Cuntas';

  @override
  String accountArg1(Object? arg1) {
    return 'Cuntas #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Foláirimh um athrú cuntais';

  @override
  String get accountEmail => 'Ríomhphost cuntais';

  @override
  String get accountEmailIsOffUntilThese =>
      'Tá ríomhphost an chuntais múchta go dtí go mbeidh siad socraithe: ';

  @override
  String get accountLanguageDescription =>
      'Úsáideann NeoAgent an teanga seo i ngach áit san aip. An chéad uair a shíníonn tú isteach, leanann sé an gléas seo. Tar éis sin, déantar an rogha a shábháil ar do chuntas agus a úsáid ar gach feiste.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Níorbh fhéidir an teanga a athrú: $error';
  }

  @override
  String get accountLanguageTitle => 'Teanga';

  @override
  String get accountNumber => 'Uimhir chuntais';

  @override
  String get accountSettings => 'Socruithe cuntais';

  @override
  String get accounts => 'Cuntais';

  @override
  String get accountsByTokensUsedAllTime =>
      'Cuntais le comharthaí a úsáidtear, an t-am ar fad.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'ríomhairí scamall cuntais. Athruithe i bhfeidhm tar éis freastalaí ';

  @override
  String get accountsOnThisServer => 'Cuntais ar an bhfreastalaí seo';

  @override
  String get active => 'Gníomhach';

  @override
  String get activeSessions => 'Seisiúin ghníomhacha';

  @override
  String get activeToday => 'Gníomhach inniu';

  @override
  String get add => 'Cuir';

  @override
  String get addAProviderCredentialFirstIts =>
      'Cuir ainm soláthraí leis ar dtús. Taispeánann a samhlacha suas anseo uair amháin ';

  @override
  String get addAgent => 'Cuir Gníomhaire leis';

  @override
  String get addAnotherSignInMethodBefore =>
      'Cuir modh síniú isteach eile leis sula mbainfidh tú an ceann seo.';

  @override
  String get addBinding => 'Cuir ceangailteach leis';

  @override
  String get addByNameOrId => 'Cuir leis de réir ainm nó aitheantais';

  @override
  String get addByNameOrIdInstead =>
      'Cuir leis de réir ainm nó ID ina ionad sin';

  @override
  String get addCredentialBinding => 'Cuir ceangailteach dintiúir leis';

  @override
  String get addEntry => 'Cuir Iontráil leis';

  @override
  String get addKey => 'Cuir eochair leis';

  @override
  String get addMcpServer => 'Cuir freastalaí MCP leis';

  @override
  String get addMemory => 'Cuir Cuimhne leis';

  @override
  String get memoryReview => 'Athbhreithnigh';

  @override
  String get memoryReviewPrompt =>
      'Athbhreithnigh mo chuimhní go léir agus glan iad: cuir dúblaigh, fíricí as dáta agus aon rud gan luach buan sa chartlann. Ansin inis dom go hachomair cad a d\'athraigh tú.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Cuir níos mó faid nó cineál carachtair eile leis.';

  @override
  String get addPeopleOrGroups => 'Cuir daoine nó grúpaí leis';

  @override
  String get addSecurityKey => 'Cuir eochair shlándála leis';

  @override
  String get addSomeoneOrAGroup => 'Cuir duine nó grúpa leis';

  @override
  String get addTask => 'Cuir Tasc leis';

  @override
  String get addTests => 'Cuir tástálacha leis';

  @override
  String get addTestsForThePartsOf =>
      'Cuir trialacha leis na codanna den tionscadal seo a bhfuil an clúdach is lú acu, ansin reáchtáil iad.';

  @override
  String get addTheirOwnKeysInSettings =>
      'cuir a gcuid eochracha féin leis sna Socruithe.';

  @override
  String get addToPrompt => 'Cuir leis an leid';

  @override
  String get added => 'Curtha leis';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Curtha leis $arg1 · $arg2 is déanaí a úsáideadh';
  }

  @override
  String get addressWithTheProvider => 'seoladh leis an soláthraí.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Coigeartaigh toirt an chainteora, athbhreithnigh mainneachtainí na gcnaipí crua-earraí, agus bainistigh an seisiún tosaitheoir seo.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Coigeartaigh an scagaire cuardaigh nó stádais chun tuilleadh cainéal teachtaireachtaí a fheiceáil.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Coigeartaigh toirt an chainteora anseo.';

  @override
  String get admin => 'Riarachán';

  @override
  String adminArg1(Object? arg1) {
    return 'Riarachán › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Taispeántar deontais riaracháin, naisc cuireadh agus athruithe bainistíochta anseo.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Ardsceideal láimhe le haghaidh cásanna speisialta.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Casta: nóiméad uair an chloig lá mí i rith na seachtaine.';

  @override
  String get againRightAway => 'arís ar an bpointe boise.';

  @override
  String get agent => 'Gníomhaire';

  @override
  String agentArg1(Object? arg1) {
    return 'Gníomhaire: $arg1';
  }

  @override
  String get agentCalls => 'Glaonna Gníomhaire';

  @override
  String get agentCommunication => 'Cumarsáid gníomhaire';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Cumarsáid gníomhaire: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'Déanann mód an ghníomhaire eagarthóireacht ar an spás oibre · ⌘↵ seol · ⌘N seisiún nua';

  @override
  String get agentPausesAndAsksYouBefore =>
      'Stadann an gníomhaire agus iarrann sé do chead sula ritheann sé an tasc.';

  @override
  String get agentProfile => 'Próifíl gníomhaire';

  @override
  String get agentVisibleName => 'Ainm gníomhaire-fheiceálach';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'Gníomhaire ag iarraidh a úsáid $arg1. Tapáil chun cinneadh a dhéanamh.';
  }

  @override
  String get agents => 'Gníomhairí';

  @override
  String get aiAnswerUnreadable => 'Freagra AI neamhléite';

  @override
  String get aiProviderKeys => 'Eochracha soláthraí AI';

  @override
  String get aiUnavailable => 'AI ar fáil';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'foláirimh agus ríomhphost cuntais eile ó.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Foláirimh nuair a theastaíonn aird an úsáideora ar nasc teachtaireachtaí';

  @override
  String get all => 'Gach';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Gach gníomhairí ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Gach $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Tá gach sliotán néalríomhaireachta in úsáid faoi láthair. Bain triail eile as i gceann nóiméad.';

  @override
  String get allComputerSlotsAreBusy => 'Tá gach sliotán ríomhaire gnóthach';

  @override
  String get allTables => 'Gach táblaí';

  @override
  String get allTime => 'An t-am ar fad';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Ceadaítear gach uirlis - is féidir leis an ngníomhaire aon chumas a úsáid gan ceist a chur. ';

  @override
  String get allow => 'Ceadaigh';

  @override
  String get allowedRunsWithoutAsking => 'Ceadaithe. Ritheann gan iarraidh.';

  @override
  String get allowAll => 'Ceadaigh go léir';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Ceadaigh \"Suiteáil apps anaithnid\" do NeoAgent, ansin bain triail eile as an nuashonrú.';

  @override
  String get allowOnce => 'Ceadaigh uair amháin';

  @override
  String get allowSender => 'Ceadaigh seoltóir';

  @override
  String get allowSession => 'Ceadaigh seisiún';

  @override
  String get allowTheAgentToStartAn =>
      'Lig don ghníomhaire glao gutha in-app a thosú leat.';

  @override
  String get allowedOrigins => 'Bunús ceadaithe';

  @override
  String get allowedPathPrefix => 'Réimír cosáin ceadaithe';

  @override
  String get allowsYouCanChangeThatPer =>
      'ceadaíonn. Is féidir leat é sin a athrú in aghaidh an duine ar ball. Ní dheonaíonn naisc riamh ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'is le cuntas atá ann cheana féin';

  @override
  String get alreadyLinkedToAnotherAccount =>
      'nasctha le cuntas eile cheana féin';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'nasctha cheana féin le cuntas nua-ghníomhaí eile';

  @override
  String get alreadyUsed => 'in úsáid cheana féin';

  @override
  String get always => 'I gcónaí';

  @override
  String get alwaysAllow => 'Ceadaigh i gcónaí';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      'Sábhálann \"Ceadaigh i gcónaí\" an polasaí go buan - is féidir leat é a athrú sna Socruithe.';

  @override
  String get alwaysAsk => 'Iarr i gcónaí';

  @override
  String get alwaysEngage => 'Bígí i gcónaí';

  @override
  String get alwaysJoins => 'I gcónaí théann';

  @override
  String get anApiKeyIsRequired => 'Tá eochair API ag teastáil.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Achoimre tráthnóna ar ar tharla agus ar cad ba cheart a leanúint.';

  @override
  String get anHttpOrHttpsUrlIs => 'Tá URL http nó https ag teastáil.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'agus anailísíocht. Naisc foirne beo ar an leathanach Foirne.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'Níl suiteáil Android APK ar fáil ar an ardán seo.';

  @override
  String get androidApp => 'app Android';

  @override
  String get androidControl => 'Rialú Android';

  @override
  String get androidCouldNotStart => 'Níorbh fhéidir tús a chur le Android';

  @override
  String get androidNotificationReceived => 'Fuarthas fógra Android';

  @override
  String get androidOnly => 'Android amháin';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Níorbh fhéidir suiteálaí pacáiste Android a oscailt.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Scáileán Android - tapáil chun teagmháil a dhéanamh, tarraing chun swipe';

  @override
  String get androidSdk => 'android sdk';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Freagraí @tráchtanna ar cheisteanna agus iarratais tarraingthe';

  @override
  String get anyone => 'Aon duine';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Is féidir le haon duine ar an ardán seo teachtaireacht a chur chuig $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Is féidir le haon duine ar an ardán seo teachtaireacht a chur chuig $arg1 in $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Is féidir le haon duine atá in ann teacht ar an gcuntas seo labhairt le $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Is féidir le haon duine a bhfuil an nasc aige páirt a ghlacadh go dtí go dtéann sé in éag nó go gcúlghairfidh tú é.';

  @override
  String get apiHttpsOrigin => 'Bunús API HTTPS';

  @override
  String get apiKey => 'Eochair API';

  @override
  String get apiKey2 => 'eochair api';

  @override
  String get apiKey3 => 'Eochair API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'eochair api claude antraipeach openai gpt xai grok google gemini minimax nvidia nim openrouter dintiúir';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Eochracha API agus críochphointí do sholáthraithe AI, cuardaigh agus gutha. siad ';

  @override
  String get apiRequest => 'Iarratas API';

  @override
  String get apiYourOwnServerASelf =>
      'API - do fhreastalaí féin, samhail féin-óstáilte, nó samhail eile ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'Theip ar íoslódáil APK le HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'Tá ainm app ag teastáil.';

  @override
  String get appUpdates => 'Nuashonruithe App';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Níl nuashonruithe aipeanna cumraithe don leagan seo.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Nuashonruithe stiúrtha ciúáilte $arg1 don rith reatha.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Nuashonruithe stiúrtha $arg1 curtha i bhfeidhm.';
  }

  @override
  String get apply => 'Cuir iarratas isteach';

  @override
  String get applyBehaviorNotes => 'Cuir nótaí iompair i bhfeidhm';

  @override
  String get applyCoreMemory => 'Cuir cuimhne croí i bhfeidhm';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Iarratais ar cheadú d\'uirlisí gníomhairí íogaire';

  @override
  String get approvalRequired => 'Faomhadh ag teastáil';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'Fanann faomhadh taobh istigh de do sheisiún soghluaiste fíordheimhnithe, agus téann gach cód in éag go huathoibríoch tar éis fuinneog ghearr.';

  @override
  String get approveLogin => 'Ceadaigh logáil isteach';

  @override
  String get approveQrLogin => 'Ceadaigh logáil isteach QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Ceadaigh é seo ach amháin má thosaigh tú ar an logáil isteach ar an ngléas sin díreach anois.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Logáil isteach ceadaithe le haghaidh $arg1.';
  }

  @override
  String get approvedOnly => 'Faofa amháin';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Péireáil ceadaithe le haghaidh $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Daoine agus grúpaí ceadaithe';

  @override
  String get approvedPeopleOnly => 'Daoine ceadaithe amháin';

  @override
  String get archive => 'Cartlann';

  @override
  String get archiveAgent => 'Gníomhaire cartlainne?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Cartlann ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Cartlann $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories =>
      'Cuimhní roghnaithe a chur sa chartlann?';

  @override
  String get areSharedByEveryAccountOn =>
      'roinnte ag gach cuntas ar an bhfreastalaí seo; is féidir cuntais fós ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return 'Ionchur \$$arg1 / 1M';
  }

  @override
  String arg12(Object? arg1) {
    return '$arg1 · ';
  }

  @override
  String arg13(Object? arg1) {
    return '\$$arg1';
  }

  @override
  String arg1AccessNeeded(Object? arg1) {
    return 'Tá rochtain $arg1 ag teastáil';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Cuntais $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 gníomhach';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 curtha leis. Cuir é in eagar am ar bith chun an ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return 'Scriosfar go buan “$arg1” agus a stair rite. Cuirfear stop le haon rith gníomhach. Ní dhéantar teagmháil le comhaid sa spás oibre.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Teastaíonn ceadú $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aipeanna $arg1 gníomhach';
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
    return '[$arg1]$arg2';
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
    return '$arg1 (uirlisí gníomhacha $arg2)';
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
    return '$arg1 $arg2 ag $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 athraithe';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 chars';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Cruthaithe $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [URA áitiúil: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 ag teacht le “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return 'Spás Oibre $arg1${arg2}NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 cuntais nua';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\nRitheann $arg2 · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · samplaí $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · $arg2 stiúrtha ciúáilte';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 comharthaí';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'comharthaí $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 ag $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return 'Rinneadh riarthóir de $arg1 ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 beart';
  }

  @override
  String arg1Channel(Object? arg1) {
    return '$arg1 cainéal';
  }

  @override
  String arg1Chars(Object? arg1) {
    return 'Carachtair $arg1';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 glanta.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 cumraithe';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 nasctha. Roghnaigh stórtha agus daoine faoi Cé is féidir teachtaireachtaí a sheoladh.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Iontrálacha lárnacha $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return 'Chruthaigh $arg1 nasc cuirí';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Deasc $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Imeachtaí $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · Theip ar $arg1';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return 'Theip ar $arg1';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 ag teip';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 le haghaidh $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Grúpaí $arg1 clibeáilte-amháin';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h ó shin';
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
    return 'Cúntóirí $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(cóimheas buailte $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return 'Is riarthóir é @$arg1, mar sin ní féidir an cuntas a scriosadh ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return 'Tá bac ar $arg1 ar $arg2. Nuashonraigh an liosta rochtana chun freagraí a cheadú.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return 'Tá $arg1 ceangailte agus ag freagairt.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return 'Ní riarthóir é $arg1 a thuilleadh ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return 'Níl $arg1 ar fáil ar $arg2 (cead ama rite nó spleáchas in easnamh).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 isteach faoi $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 breithiúnas ag LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return '$arg1 key$arg2 cumraithe';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Baineadh eochair $arg1.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 fágtha';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return 'D\'fhág $arg1 $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 nasctha';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m ó shin';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Cinntigh go bhfuil sé ag rith, ansin bain triail eile as.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 a bhainistíonn an cuntas seo';
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
    return '$arg1 min $arg2 soic';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Samhlacha $arg1 réidh';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 níos mó';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 tuilleadh céimeanna sa stair rith';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return 'Bhog $arg1 ó $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return 'Caithfidh $arg1 a bheith ina uimhir chríochnaithe.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return 'Caithfidh $arg1 a bheith ina sheoladh http:// nó https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return 'Ní mór aird a thabhairt ar $arg1';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Spás Oibre $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 cuntais nua sa $arg2 seo caite.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · stiúrann teachtaireachtaí nua an rith seo';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return 'Ritheann nua $arg1';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 a bhainistíonn an cuntas seo anois.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 de 4 chead ceadaithe. Tá comhaid teoranta do d\'fhillteán NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 de $arg2 cumasaithe';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return 'Téann grúpaí $arg1 ó $arg2 isteach sa ghnáthchomhrá';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 de mhúnlaí $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 de mhúnlaí $arg2 réidh';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 de $arg2 socraithe';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 na n-uirlisí $arg2 ceadaithe';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: Ceart go leor';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 ar an lá $arg2 ag $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return 'Ní fhreagraíonn $arg1 ach do na daoine a chuireann tú thíos leis.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return 'Ní fhreagraíonn $arg1 ach nuair a chlibítear é';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return 'Ní labhraíonn $arg1 ach le daoine agus grúpaí a cheadaíonn tú';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return 'daoine nó grúpaí $arg1 curtha leis';
  }

  @override
  String arg1Planning(Object? arg1) {
    return '$arg1 pleanála';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Soláthraithe $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 réidh';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Taifid $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return '$arg1 atreorú URI';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 cláraithe';
  }

  @override
  String arg1Replied(Object? arg1) {
    return 'D\'fhreagair $arg1';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return 'Rinne $arg1 nasc le cuireadh a chúlghairm';
  }

  @override
  String arg1Runs(Object? arg1) {
    return 'Ritheann $arg1';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return 'Ritheann $arg1 · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Ritheann $arg1 sa $arg2 seo caite.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 sábháilte.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 soic';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 roghnaithe';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 léirithe';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return 'D\'fhan $arg1 ciúin';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 stiúrtha $arg2 scuaine';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · Beartaíonn nód chun iniúchadh a dhéanamh';
  }

  @override
  String arg1Steps(Object? arg1) {
    return '$arg1 céimeanna';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return 'Stop $arg1 a bhainistiú $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'comharthaí $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Comharthaí $arg1 sa $arg2 seo caite.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Uirlisí $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (níl an sárú sábháilte ar fáil)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% a úsáidtear · $arg2 fágtha';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return 'Ba mhaith le $arg1 labhairt leat.';
  }

  @override
  String arg1Web(Object? arg1) {
    return '$arg1 gréasáin';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return 'Bainfear \"$arg1\" go buan.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return 'Déanfaidh $arg1 an cuntas seo a bhainistiú';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return 'Ní fhreagróidh $arg1 ar an ardán seo';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return 'Ní fhreagróidh $arg1 $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Stóráil déantán ag úsáideoir';

  @override
  String get askAQuestionOrStartA => 'Cuir ceist nó cuir tús le tasc...';

  @override
  String get askBeforeClosingToBackground =>
      'Fiafraigh sula ndúnann tú don chúlra';

  @override
  String get askMe => 'Fiafraigh díom';

  @override
  String get assignedAgent => 'Gníomhaire sannta';

  @override
  String get assignedAgent2 => 'Gníomhaire Sannta';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Gníomhaire sannta: $arg1';
  }

  @override
  String get assigneeOptional => 'Sannaí (roghnach)';

  @override
  String get assistant => 'Cúntóir';

  @override
  String get assistantKey131 => 'Eochair cúntóir 131 saor in aisce,';

  @override
  String get atLeast1 => '1 ar a laghad.';

  @override
  String get attachFiles => 'Ceangail comhaid';

  @override
  String attentionArg1(Object? arg1) {
    return 'Aird $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'loga iniúchta admin deontas stair na foirne a chúlghairm';

  @override
  String get authMethod => 'Modh an Údair';

  @override
  String get authServerUrl => 'URL Freastalaí Údar';

  @override
  String get authentication => 'Fíordheimhniú';

  @override
  String get authenticationFailed => 'Theip ar an bhfíordheimhniú.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'Tá fíordheimhniú fós ar feitheamh. Críochnaigh sreabhadh an bhrabhsálaí agus bain triail eile as.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'Tá fíordheimhniú fós ar feitheamh. Críochnaigh an sreabhadh brabhsálaí agus athnuachan.';

  @override
  String get authenticationTimedOut =>
      'Tháinig deireadh leis an bhfíordheimhniú.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'Cuireadh an fíordheimhniú ar ceal sular críochnaíodh é.';

  @override
  String get authenticatorApp => 'Aip fíordheimhnitheora';

  @override
  String get authenticatorCode => 'Cód fíordheimhnitheora';

  @override
  String get authorOptional => 'Údar (roghnach)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Uathoibríoch (an chéad soláthraí le heochair API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Uathbhealaí chuig an tsamhail is fearr atá ar fáil';

  @override
  String get automaticFast => 'Uathoibríoch (tapa)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Léann uathoibríoch an seomra agus coinníonn sé siar de ghnáth. Ní dhéantar aon ghlao cinnidh a luaitear ach amháin go dtí go ndírítear go díreach air.';

  @override
  String get automaticReserved => 'Uathoibríoch, in áirithe';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'Teastaíonn triail eile as rolladh siar uathoibríoch ón scáileán socraithe.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Roghnaíonn Uathoibríoch múnla tapa tríd an gcatalóg múnla gnáth.';

  @override
  String get automation => 'Uathoibriú';

  @override
  String get available => 'Ar fáil';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Ar fáil arís i $arg1';
  }

  @override
  String get availableAgainShortly => 'Ar fáil arís go luath';

  @override
  String get availableInTheDesktopAppFor =>
      'Ar fáil san aip deisce le haghaidh macOS, Windows agus Linux';

  @override
  String get availableToTheAgent => 'Ar fáil don ghníomhaire';

  @override
  String get averageAllTime => 'Meán, am ar fad';

  @override
  String get avgImp => 'Meánlíon imp.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Meánlíon/rith: comharthaí $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Seachain carachtair arís agus arís eile agus seichimh shoiléire.';

  @override
  String get awaitingScan => 'Ag feitheamh le scanadh';

  @override
  String get back => 'Ar ais';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count sa chúlra';
  }

  @override
  String get backgroundTasks => 'Tascanna cúlra';

  @override
  String get backOn => 'ar ais ar.';

  @override
  String get backToChat => 'Ar ais go dtí comhrá';

  @override
  String get backToFolder => 'Ar ais go fillteán';

  @override
  String get backToSignIn => 'Ar ais chun síniú isteach';

  @override
  String get backendChannel => 'Cainéal cúl';

  @override
  String get backendOnThisComputer => 'Inneall ar an ríomhaire seo';

  @override
  String get backendSync => 'Sioncronú inneall';

  @override
  String get backgroundLocationNeeded => 'Suíomh Cúlra ag Teastáil';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'Fanann sioncronú cúlra sceidealta ar Android';

  @override
  String get badState => 'Drochstaid: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Íomhá bonn agus méid na meaisíní fíorúla QEMU a ritheann ';

  @override
  String get baseUrlOptional => 'Bun-URL (roghnach)';

  @override
  String get baseUrlTokenLocal => 'bonn url chomhartha áitiúil';

  @override
  String get basicAuthentication => 'Fíordheimhniú bunúsach';

  @override
  String get behaviorModules => 'Modúil Iompraíochta';

  @override
  String get behaviorNotes => 'nótaí iompair';

  @override
  String get beta => 'Béite';

  @override
  String get bitwardenCredentialBroker => 'Bróicéir dintiúir Bitwarden';

  @override
  String get bitwardenItem => 'Mír Bitwarden';

  @override
  String get bitwardenServer => 'Freastalaí Bitwarden';

  @override
  String get blankUsesCommon => 'Úsáideann bán \"coitianta\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Úsáideann Blank an aisghlao réamhshocraithe';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Úsáideann luachanna bána réamhshocruithe an tsoláthraí.';

  @override
  String get block => 'Bloc';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Cuireadh bac ar theachtaireacht isteach ó $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge =>
      'Droichead BlueBubbles-comhoiriúnach';

  @override
  String get bluebubblesServerUrl => 'URL freastalaí BlueBubbles';

  @override
  String get botToken => 'Comhartha bot';

  @override
  String get botTokenAndApprovedChats =>
      'Comhartha bot agus comhráite ceadaithe';

  @override
  String get botTokenAndServerChannelAccess =>
      'Comhartha bot agus rochtain freastalaí / cainéal';

  @override
  String get botTokenEventsApiAndChannel =>
      'Comhartha bot, Imeachtaí API, agus rochtain cainéal';

  @override
  String get botUserId => 'Aitheantas úsáideora bot';

  @override
  String get botUsername => 'Ainm úsáideora bot';

  @override
  String get brandName => 'Ainm branda';

  @override
  String get braveSearch => 'Cuardach Cróga';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Droichead aon soláthraí atá in ann ualaí pálasta gréasáin a phostáil agus a fháil.';

  @override
  String get bringYourOwnKey => 'tabhair leat d\'eochair féin';

  @override
  String get bringYourOwnKey2 => 'Beir leat d\'eochair féin';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Roinneann brabhsálaí, deasc Linux, comhaid, críochfort, agus Python ríomhaire scamall leanúnach amháin.';

  @override
  String get browserLogin => 'Brabhsálaí logáil isteach';

  @override
  String get browserScripting => 'Script Brabhsálaí';

  @override
  String get call => 'Glaoigh';

  @override
  String get callAgent => 'Gníomhaire glaonna';

  @override
  String get callUser => 'Úsáideoir Glaoigh';

  @override
  String get calledByName => 'Glaoite de réir ainm';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Is féidir leis tascanna a tharmligean chuig gníomhairí eile';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Is féidir é a tharmligean chuig $arg1';
  }

  @override
  String get canReceiveDelegatedTasks =>
      'Is féidir tascanna tarmligthe a fháil';

  @override
  String get cancel => 'Cealaigh';

  @override
  String get cancelTask => 'Cealaigh tasc';

  @override
  String get cannotPreview => 'Ní féidir réamhamharc a dhéanamh';

  @override
  String get cannotReceiveDelegatedTasks =>
      'ní féidir tascanna tarmligthe a fháil';

  @override
  String get cannotRunYet => 'ní féidir rith go fóill.';

  @override
  String get capturedThePage => 'Ghlac an leathanach';

  @override
  String get category => 'Catagóir';

  @override
  String chainArg1(Object? arg1) {
    return 'Slabhra: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Athraigh mód socraithe';

  @override
  String get channel => 'Cainéal';

  @override
  String get channelAccessToken => 'Comhartha rochtana cainéal';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Cainéal: $arg1$arg2 | Leagan Nuashonraithe: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Cuimhne sóisialta scóip chainéil';

  @override
  String get channels => 'Cainéil';

  @override
  String get chat => 'Comhrá';

  @override
  String get chatId => 'Aitheantas Comhrá';

  @override
  String get chatMode => 'Mód comhrá';

  @override
  String get chatModel => 'Múnla Comhrá';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Seiceáil go huathoibríoch ar an seoladh';

  @override
  String get checkForMessagesEveryMs =>
      'Seiceáil le haghaidh teachtaireachtaí gach (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Seiceáil do theachtaireachtaí nua go huathoibríoch';

  @override
  String get checkNow => 'Seiceáil anois';

  @override
  String get checkYourEmailToConfirmYour =>
      'Seiceáil do ríomhphost chun do chuntas NeoAgent a dheimhniú sula síníonn tú isteach.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Seiceáilte $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Roghnaigh catagóir nó cuardaigh thar gach socrú.';

  @override
  String get chooseAPerson => 'Roghnaigh duine';

  @override
  String get chooseAProjectFolder => 'Roghnaigh fillteán tionscadail';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Roghnaigh mainneachtainí le haghaidh comhrá, gníomhairí, iompar cúltaca agus ródú cliste.';

  @override
  String get chooseGroups => 'Roghnaigh grúpaí';

  @override
  String get chooseHowMuchYouWantTo =>
      'Roghnaigh cé mhéad is mian leat a chumrú anois. Is féidir an dá rogha a athrú níos déanaí.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Roghnaigh conas ba cheart tús a chur leis an tasc seo. Ní ritheann láimhe ach ar Rith Anois. Tá an sceideal bunaithe ar am. Spreagann comhtháthú tine ó aipeanna oifigiúla ceangailte.';

  @override
  String get chooseOneToGetStartedNow =>
      'Roghnaigh ceann le tosú anois. Is féidir leat níos mó a chur leis níos déanaí.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Roghnaigh an tsamhail bheo agus an guth sna Socruithe.';

  @override
  String get chooseTheirGroup => 'Roghnaigh a ngrúpa';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Roghnaigh cá háit ar cheart cead a thabhairt don duine seo labhairt le $arg1. Is féidir leat é seo a athrú níos déanaí faoi Cé atá in ann teachtaireacht a sheoladh.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Roghnaigh na grúpaí ar cheart $arg1 a bheith páirteach iontu fiú nuair nach bhfuil aon duine ag clibeáil orthu. Seans nach n-insíonn an t-ardán seo clibeanna seachas teachtaireachtaí rialta.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Roghnaigh na múnlaí is féidir le gach cuntas ar an bhfreastalaí seo a roghnú agus ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Roghnaigh cé leis a mbeidh $arg1 ag caint, agus cathain a rachaidh sé isteach i gcomhráite grúpa.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Roghnaigh cé atá in ann $arg1 a bhaint amach, ansin sábháil do chuid athruithe.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Roghnaigh cé a fhéadfaidh teachtaireacht a chur chuig an ngníomhaire le \"Cé is féidir teachtaireacht\" ar an gcárta WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Roghnaigh do mhúnla\nréamhshocraithe.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Tá cróimiam, comhaid, an t-eagarthóir téacs agus teirminéal ar fáil ón deasc Linux.';

  @override
  String get claudeCode => 'Cód Claude';

  @override
  String get clear => 'Glan';

  @override
  String get clearAll => 'Glan go léir';

  @override
  String clearArg1(Object? arg1) {
    return 'Geal $arg1?';
  }

  @override
  String get clearFilter => 'Glan an scagaire';

  @override
  String get clearFilters => 'Glan na scagairí';

  @override
  String get clearSearch => 'Glan cuardach';

  @override
  String get clearView => 'Amharc soiléir';

  @override
  String get cliSession => 'seisiún CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'ní thacaítear le cliceáil ar an ardán seo.';

  @override
  String get clickOnceToBeginCapturing =>
      'Cliceáil uair amháin chun tús a ghabháil';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Cliceáil, clóscríobh, agus idirghníomhaigh le haipeanna deisce.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Cliceáil ar ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Cliceáil sa bhrabhsálaí';

  @override
  String get clientId => 'Aitheantas Cliant';

  @override
  String get clientSecret => 'Rún an chliaint';

  @override
  String get close => 'Dún';

  @override
  String get closeJ => 'Dún (⌘J)';

  @override
  String get closeTeachMode => 'Dún Mód Teach';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Má dhúnann tú an fhuinneog is féidir NeoAgent a choinneáil ag rith sa chúlra le rochtain ar thráidire, nó an t-am rite deisce a scor go hiomlán.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Tacaítear le cásanna scamall agus féin-óstáilte. Oibríonn URLanna líonra áitiúla agus príobháideacha nuair is féidir le NeoAgent iad a bhaint amach.';

  @override
  String get cloudComputer => 'Ríomhaire scamall';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Ríomhaire scamall · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Sábháil socruithe ríomhaire scamall. Atosaigh an freastalaí chun iad a chur i bhfeidhm.';

  @override
  String get cloudComputerVm => 'Ríomhaire scamall (VM)';

  @override
  String get cloudComputers => 'Ríomhairí scamall';

  @override
  String get codeHosting => 'Óstáil Cód';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Ainmneacha cainéal camóg-scartha, gan an #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Camóg-scartha, mar shampla #ginearálta, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Camóg scartha. Caithfidh go bhfuil gach ceann acu ar an gceist.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Theip ar an ordú ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Tá ordú ag teastáil.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'Níl an carnadóir aschuir ordú gníomhach.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Theip ar uaslódáil aschur ordaithe ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'Uaslódáil aschur ordú meiteashonraí déantán ar lár.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'Tugadh aschur na n-orduithe chun críche cheana féin.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Orduithe & aipeanna';

  @override
  String get commandsRunInTheSamePersistent =>
      'Ritheann orduithe sa ríomhaire leanúnach céanna a úsáideann an deasc infheicthe.';

  @override
  String get communityChatops => 'Pobal & ChatOps';

  @override
  String get completeSetup => 'Socrú Críochnaithe';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Críochnaigh an sreabhadh oibre ar an deasc.';

  @override
  String get completed => 'Críochnaithe';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Blocáilte go hiomlán - ní féidir leis an ngníomhaire an chatagóir seo a úsáid.';

  @override
  String get computerShell => 'Sliotán ríomhaire';

  @override
  String get computerUsedByThisSession =>
      'Ríomhaire a úsáideann an seisiún seo';

  @override
  String get computerWorkspace => 'Spás oibre ríomhaire';

  @override
  String get configurablePersonalWebhookBridge =>
      'Droichead gréasáin gréasáin pearsanta inchumraithe';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Droichead sealaíochta nó crúca gréasáin inchumraithe';

  @override
  String get configurableTalkWebhookBridge =>
      'Droichead gréasán Labhair Inchumraithe';

  @override
  String get configurableWebInboxBridge =>
      'Droichead bosca isteach gréasáin inchumraithe';

  @override
  String get configurableWebhookBridge =>
      'Droichead cuaille gréasáin inchumraithe';

  @override
  String get configurableWebhooks => 'Leabhair Ghréasáin Inchumraithe';

  @override
  String get configurationOrInTheEnvFile => 'Cumraíocht nó sa chomhad .env.';

  @override
  String get configure => 'Cumraigh';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Cumraigh iompar spás oibre agus mainneachtainí samhail.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Cumraithe $arg1';
  }

  @override
  String get confirmEmailChanges => 'Deimhnigh na hathruithe ríomhphoist';

  @override
  String get confirmNewSignUps => 'Deimhnigh clárúcháin nua';

  @override
  String get confirmPassword => 'Deimhnigh pasfhocal';

  @override
  String get confirmPassword2 => 'Deimhnigh Pasfhocal';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Deimhnigh do ríomhphost roimh síniú isteach. Seiceáil an teachtaireacht ríomhphoist seirbhíse ó NeoAgent.';

  @override
  String get connect => 'Ceangail';

  @override
  String get connectAMessagingPlatform => 'Ceangail ardán\nteachtaireachtaí.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Ceangail críochphointe poiblí Cúntóir Baile HTTPS le Comhartha Rochtana Fadsaoil. Cuireann an freastalaí bac ar sheoltaí líonra áitiúla, loopback agus príobháideacha.';

  @override
  String get connectAccount => 'Ceangail Cuntas';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Ceangail cuntais app ina n-aonar ionas gur féidir leis an AI an cuntas ceart a úsáid le haghaidh gach comhtháthú oifigiúil.';

  @override
  String connectArg1(Object? arg1) {
    return 'Ceangail $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Ceangail an oiread cuntas agus is mian leat. Is féidir le gach aip cuntas difriúil a úsáid.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Ceangail cainéil, roghnaigh cé leis a labhrann $arg1, agus féach ar ghníomhaíocht le déanaí.';
  }

  @override
  String get connectInstance => 'Ceangail Cás';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Ceangail an comhtháthú seo ar dtús chun cuntas a roghnú.';

  @override
  String get connectToThisServer => 'Ceangail leis an bhfreastalaí seo';

  @override
  String get connectWhatsapp => 'Ceangail WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Ceangail do shampla Nextcloud, lena n-áirítear freastalaithe féin-óstáilte. Osclaíonn NeoAgent leathanach logáil isteach Nextcloud féin ionas gur féidir leat síniú isteach le pasfhocal, SSO, nó 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Ceangail do fhreastalaí NeoRecall féin-óstach. Faigheann NeoAgent rochtain inléite amháin ar chuardach áitiúil, cuimhní cinn agus fianaise tras-scríbhinne tar éis duit an scáileán OAuth a cheadú.';

  @override
  String get connected => 'Ceangailte';

  @override
  String get connectedAccount => 'Cuntas Ceangailte';

  @override
  String connectedArg1(Object? arg1) {
    return 'Ceangailte $arg1';
  }

  @override
  String get connectedInstance => 'Cás Ceangailte';

  @override
  String get connectedNeorecallUser => 'Úsáideoir NeoRecall Ceangailte';

  @override
  String get connectedNextcloudUser => 'Úsáideoir Nextcloud Ceangailte';

  @override
  String get connectedServer => 'Freastalaí nasctha';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Ag nascadh leis an múnla gutha beo...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Ceangal #$arg1';
  }

  @override
  String get connectionId => 'ID ceangail';

  @override
  String get connectionLooksGood => 'Breathnaíonn nasc go maith.';

  @override
  String get connectionMethod => 'Modh Ceangail';

  @override
  String get containsTextOptional => 'Téacs atá ann (roghnach)';

  @override
  String get content => 'Ábhar';

  @override
  String get contentSecurityPolicy => 'polasaí slándála ábhair';

  @override
  String get continue2 => 'Lean ort';

  @override
  String get continueFullSetup => 'Lean ar aghaidh leis an socrú iomlán';

  @override
  String get continueRun => 'Lean ar aghaidh ag rith';

  @override
  String get continueToSetup => 'Lean ar aghaidh chuig an socrú';

  @override
  String get controlSurface => 'DROMCHLA RIALÚ';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Rialaíonn sé rochtain ar uirlisí $arg1.';
  }

  @override
  String get conversation => 'Comhrá';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'Aitheantas an chomhrá a úsáidtear nuair a thosaíonn an gníomhaire seo comhrá.';

  @override
  String get cookieSetup => 'Socrú fianán';

  @override
  String get cookiesNotConfigured => 'Fianáin nach bhfuil cumraithe';

  @override
  String get copiedAsCsv => 'Cóipeáladh mar CSV';

  @override
  String get copiedDebugInfo => 'Cóipeáladh faisnéis dífhabhtaithe';

  @override
  String get copiedExportForTheLast5 =>
      'Cóipeáladh easpórtáil do na 5 theachtaireacht dheireanacha';

  @override
  String get copiedFullPrompt => 'Cóipeáladh leid iomlán';

  @override
  String get copiedLogs => 'Logaí cóipeáilte';

  @override
  String get copiedRunId => 'Cóipeáladh an t-aitheantas reatha';

  @override
  String get copy => 'Cóip';

  @override
  String get copyAll => 'Cóipeáil go léir';

  @override
  String get copyCodes => 'Cóipeáil cóid';

  @override
  String get copyCsv => 'Cóipeáil CSV';

  @override
  String get copyDebugInfo => 'Cóipeáil faisnéis dífhabhtaithe';

  @override
  String get copyLink => 'Cóipeáil an nasc';

  @override
  String get copyLogs => 'Cóipeáil logs';

  @override
  String get copyPrompt => 'Cóipeáil Leid';

  @override
  String get copyResponse => 'Cóipeáil an freagra';

  @override
  String get copyRunId => 'Cóipeáil an t-aitheantas rith';

  @override
  String get copyWebhookUrl => 'Cóipeáil URL an chuaille gréasáin';

  @override
  String get core => 'Croílár';

  @override
  String get coreMemory => 'croí-chuimhne';

  @override
  String get coreServicesThisServerDependsOn =>
      'Seirbhísí lárnacha ag brath ar an bhfreastalaí seo.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domain https url poiblí bunús';

  @override
  String get couldHelp => 'D\'fhéadfadh cabhrú';

  @override
  String get couldNotApproveQrLogin =>
      'Níorbh fhéidir logáil isteach QR a cheadú.';

  @override
  String get couldNotApproveQrPairing => 'Níorbh fhéidir péireáil QR a cheadú.';

  @override
  String get couldNotConnect => 'Níorbh fhéidir ceangal.';

  @override
  String get couldNotCreateBinding => 'Níorbh fhéidir ceangal a chruthú.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Níorbh fhéidir do chuntas a scriosadh: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Níorbh fhéidir Bitwarden a dhícheangal.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Níorbh fhéidir Cúntóir Baile a dhícheangal.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Níorbh fhéidir NeoRecall a dhínascadh.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Níorbh fhéidir Nextcloud a dhícheangal.';

  @override
  String get couldNotDisconnectTrello => 'Níorbh fhéidir Trello a dhícheangal.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Níorbh fhéidir do shonraí a easpórtáil: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Níorbh fhéidir cinntí a lódáil';

  @override
  String get couldNotLoadUsageData => 'Níorbh fhéidir sonraí úsáide a lódáil.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Níorbh fhéidir socruithe Linux a oscailt go huathoibríoch.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Níorbh fhéidir leathanach nasctha an tsoláthraí a oscailt.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Níorbh fhéidir leathanach sínithe isteach an tsoláthraí a oscailt.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Níorbh fhéidir an tsócmhainn scaoilte a oscailt.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Níorbh fhéidir Trello a oscailt i do bhrabhsálaí.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Níorbh fhéidir íoslódáil an chomhaid spás oibre a oscailt.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Níorbh fhéidir an pacáiste aip Android a léamh.';

  @override
  String get couldNotReadTheApk => 'Níorbh fhéidir an APK a léamh.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Níorbh fhéidir an eochair a bhaint: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Níorbh fhéidir gníomhaire a shábháil.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Níorbh fhéidir socrú Bitwarden a shábháil.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Níorbh fhéidir socrú Cúntóir Baile a shábháil.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Níorbh fhéidir socrú NeoRecall a shábháil.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Níorbh fhéidir socrú Nextcloud a shábháil.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Níorbh fhéidir socrú Trello a shábháil.';

  @override
  String get couldNotSendConfirmationEmail =>
      'níorbh fhéidir an ríomhphost deimhnithe a sheoladh';

  @override
  String get couldNotStart => 'Níorbh fhéidir tosú';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Cruthaigh';

  @override
  String get createAPasswordFirstToChange =>
      'Cruthaigh pasfhocal ar dtús chun do chuntas ríomhphoist a athrú.';

  @override
  String get createAPasswordOrLinkAnother =>
      'cruthaigh pasfhocal nó nasc soláthraí eile roimh an modh sínithe isteach seo a bhaint';

  @override
  String get createATaskWhileThisAgent =>
      'Cruthaigh tasc agus an gníomhaire seo roghnaithe.';

  @override
  String get createLink => 'Cruthaigh nasc';

  @override
  String get createOrModifyFilesInYour =>
      'Cruthaigh nó modhnaigh comhaid i do spás oibre.';

  @override
  String get createPassword => 'Cruthaigh pasfhocal';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Cruthaigh róbónna speisialta le cuimhne ar leith, socruithe, uirlisí agus tascanna cuntais.';

  @override
  String get createTheFirstAccount => 'Cruthaigh an chéad chuntas';

  @override
  String get createUpdateOrDeleteSkills =>
      'Cruthaigh, nuashonraigh, nó scrios scileanna.';

  @override
  String get creatingYourSkill => 'Do scil á cruthú…';

  @override
  String get credentialBindings => 'Ceangaltáin dintiúir';

  @override
  String get credentialUse => 'Úsáid Creidiúnaithe';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Ritheann athfhillteacha bunaithe ar Cron agus cur i gcrích aonuaire uainithe.';

  @override
  String get cronExpression => 'Cron léiriú';

  @override
  String get ctrlEnterRunsTheQuery => 'Ritheann Ctrl/⌘ + Enter an cheist.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Spás';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Ríomhphost reatha: $arg1';
  }

  @override
  String get currentPassword => 'Focal faire reatha';

  @override
  String get currentPasswordIsIncorrect => 'tá an pasfhocal reatha mícheart';

  @override
  String get currentTwoStepLoginCode => 'Cód logáil isteach dhá chéim reatha';

  @override
  String get customAccess => 'Rochtain saincheaptha';

  @override
  String get customCron => 'Cron an Chustaim';

  @override
  String get customCronMustHave5Fields =>
      'Ní mór 5 réimse a bheith ag Cron an Chustaim.';

  @override
  String get customEndpoint => 'críochphointe saincheaptha';

  @override
  String get customField => 'Réimse saincheaptha';

  @override
  String get customHeader => 'Ceanntásc saincheaptha';

  @override
  String get customHeadersJson => 'Ceanntásca saincheaptha (JSON)';

  @override
  String get customOpenaiCompatible => 'Saincheaptha OpenAI-comhoiriúnach';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'críochphointe saincheaptha OpenAI-comhoiriúnach';

  @override
  String get customOutgoingUrl => 'URL saincheaptha amach';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'laethúil';

  @override
  String get dailyRecap => 'Achoimre laethúil';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'ceist bhunachar sonraí roghnaigh teimpléid csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Lá $arg1';
  }

  @override
  String get dayOfMonth => 'Lá na míosa';

  @override
  String get decideWhichToolsYourAgentMay =>
      'cinneadh a dhéanamh ar na huirlisí is féidir le do ghníomhaire a úsáid. Feiceann siad d’ainm agus ';

  @override
  String get decisionHigherUpTheChainWins =>
      'Bhuaigh cinneadh níos airde suas an slabhra agus léiríonn glas leis an ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Léiríonn cinntí anseo mar a léann $arg1 grúpaí ceadaithe $arg2. Ní choimeádtar ach na 30 cinn is déanaí, agus athshocraíonn siad nuair a atosóidh an freastalaí.';
  }

  @override
  String get decline => 'Meath';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'rith domhain · céim $arg1';
  }

  @override
  String get deepgramKey => 'Eochracha do deepgram';

  @override
  String get default2 => 'Réamhshocrú';

  @override
  String get default3 => 'ROINNT';

  @override
  String defaultArg1(Object? arg1) {
    return 'Réamhshocrú ($arg1)';
  }

  @override
  String get defaultConversation => 'Comhrá réamhshocraithe';

  @override
  String get defaultForNewGroups => 'Réamhshocrú do ghrúpaí nua';

  @override
  String get defaultGroupParticipation =>
      'Rannpháirtíocht ghrúpa réamhshocraithe';

  @override
  String get defaultNeoagentWorkspace => 'Réamhshocrú NeoAgent Spás Oibre';

  @override
  String get defaultOpenai => 'Réamhshocrú (OpenAI)';

  @override
  String get defaultRateLimits => 'Teorainneacha ráta réamhshocraithe';

  @override
  String get defaultRateLimitsSaved =>
      'Teorainneacha ráta réamhshocraithe sábháilte.';

  @override
  String get defaultRecommended => 'Réamhshocrú (molta)';

  @override
  String get defaultRouting => 'Ródú Réamhshocraithe';

  @override
  String get defaultSpace => 'Spás réamhshocraithe';

  @override
  String get delete => 'Scrios';

  @override
  String get deleteAccount => 'Scrios cuntas';

  @override
  String get deleteAccountPermanently =>
      'An bhfuil fonn ort an cuntas a scriosadh go buan?';

  @override
  String get deleteAnAccount => 'Scrios cuntas';

  @override
  String deleteArg1(Object? arg1) {
    return 'Scrios @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Scrios ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Scrios $arg1 $arg2 go buan?';
  }

  @override
  String get deleteBinding => 'Scrios ceangailteach';

  @override
  String get deleteCoreMemoryEntry => 'Scrios iontráil chroí-chuimhne?';

  @override
  String get deleteForever => 'Scrios go deo';

  @override
  String get deleteMcpServer =>
      'An bhfuil fonn ort freastalaí MCP a scriosadh?';

  @override
  String get deleteMemory => 'An bhfuil fonn ort cuimhne a scriosadh?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Scrios go buan erases cuntas agus a chuid sonraí go léir ';

  @override
  String get deleteRun => 'An bhfuil fonn ort an rith a scriosadh?';

  @override
  String get deleteRun2 => 'Scrios rith';

  @override
  String get deleteSelectedMemories =>
      'An bhfuil fonn ort na cuimhní roghnaithe a scriosadh?';

  @override
  String get deleteSession => 'An bhfuil fonn ort an seisiún a scriosadh?';

  @override
  String get deleteSkill => 'An bhfuil fonn ort scil a scriosadh?';

  @override
  String get deleteTask => 'An bhfuil fonn ort an tasc a scriosadh?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Scriosadh \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Scriosta @$arg1 agus a gcuid sonraí go léir.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'Scriostar do chuid comhráite, cuimhní cinn, comhaid, tascanna agus ';

  @override
  String get deliverableArtifactProduced => 'Déantán inseachadta a tháirgtear';

  @override
  String get deliverableCompleted => 'Inseachadta críochnaithe';

  @override
  String get deliverableExecutionStarted =>
      'Cuireadh tús le forghníomhú inseachadta';

  @override
  String get deliverableSelected => 'Inseachadta roghnaithe';

  @override
  String get deliverableValidationFailed => 'Theip ar bhailíochtú inseachadta';

  @override
  String get deliverableValidationStarted =>
      'Cuireadh tús le bailíochtú inseachadta';

  @override
  String get deny => 'shéanadh';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Déan cur síos ar an toradh, ansin é a thaispeáint ar an deasc';

  @override
  String get describeWhatToBuildOrChange =>
      'Déan cur síos ar cad atá le tógáil nó le hathrú…';

  @override
  String get description => 'Cur síos';

  @override
  String get desktopApp => 'Aip deisce';

  @override
  String get desktopAppControlsAvailable => 'Rialuithe app deisce ar fáil';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'Níl gabháil deisce ar fáil ar an ardán seo.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Cuireadh uaslódáil aschur ordaithe deisce ar ceal.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Cuireadh an t-ordú compánach deisce ar ceal.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Chuaigh nasc compánach deisce thar am.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Chuaigh croitheadh ​​láimhe le compánach deisce thar am.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'Níl compánach deisce ar fáil anseo.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'Cuirtear compánach deisce ar sos go háitiúil.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Theip ar láimhseáil teachtaireachta compánach deisce: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'Níl socruithe ceada compánach deisce ar fáil ar an ngréasán.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'Níl socruithe cead compánach deisce ar fáil ar an ardán seo.';

  @override
  String get desktopCompanionRejected => 'Diúltaíodh do chompánach deisce.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Theip ar fhreagra compánach deisce: $arg1';
  }

  @override
  String get desktopControl => 'Rialú Deisce';

  @override
  String get desktopFailedToStart => 'Theip ar an deasc a thosú';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Theip ar ghabháil sruth na deisce: $arg1';
  }

  @override
  String get destinationId => 'Aitheantas Ceann Scríbe';

  @override
  String get deviceAccess => 'Rochtain gléas';

  @override
  String get deviceSettings => 'Socruithe Gléas';

  @override
  String get devices => 'Gléasanna';

  @override
  String get diagnosticsSaved => 'Diagnóisic shábháil.';

  @override
  String get directBluebubblesImessageBridge =>
      'Droichead díreach BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Fanann teachtaireachtaí díreacha sofhreagrach. Úsáideann grúpaí ceadaithe an modh rannpháirtíochta thíos.';

  @override
  String get directoryDoesNotExist => 'Níl an t-eolaire ann.';

  @override
  String get disable2fa => 'Díchumasaigh 2FA';

  @override
  String get disableAll => 'Díchumasaigh go léir';

  @override
  String get discard => 'Caith amach';

  @override
  String get disconnect => 'Dícheangail';

  @override
  String get disconnectHomeAssistant =>
      'An bhfuil fonn ort an Cúntóir Baile a dhínascadh?';

  @override
  String get disconnectNeorecall => 'Dínasc NeoRecall?';

  @override
  String get disconnectNextcloud =>
      'An bhfuil fonn ort Nextcloud a dhícheangal?';

  @override
  String get disconnectPlatform => 'ardán a dhícheangal';

  @override
  String get disconnectTrello => 'Dínasc Trello?';

  @override
  String get discoveryFailed => 'Theip ar an bhfionnachtain';

  @override
  String get dismiss => 'Díbhe';

  @override
  String get displayIdIsRequired => 'Tá ID taispeána ag teastáil.';

  @override
  String get displayName => 'Ainm taispeána';

  @override
  String get displayNameMustBe64Characters =>
      'Caithfidh 64 carachtar nó níos lú a bheith san ainm taispeána.';

  @override
  String get displayNameSaved => 'Sábháladh an t-ainm taispeána.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Ná cuir d\'ainm úsáideora nó ríomhphost san áireamh.';

  @override
  String get done => 'Déanta';

  @override
  String get downloadACopyOfYourData =>
      'Íoslódáil cóip de do shonraí. Ní féidir cuntais riaracháin a scriosadh ';

  @override
  String get downloadACopyOfYourData2 =>
      'Íoslódáil cóip de do shonraí, nó scrios do chuntas go buan. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Íoslódáil $arg1';
  }

  @override
  String get downloadUpdate => 'Íoslódáil an nuashonrú';

  @override
  String get downloadingTheNeoagentBackend =>
      'Íosluchtaigh inneall do neoagent';

  @override
  String get draft => 'Dréacht';

  @override
  String get dragIsNotSupportedOnThis =>
      'ní thacaítear le tarraing ar an ardán seo.';

  @override
  String get draggedOnTheScreen => 'Dragáilte ar an scáileán';

  @override
  String get dropAnApkOrApkBundle =>
      'Buail beart APK nó APK anseo chun é a shuiteáil';

  @override
  String get dropApkOrApksHere => 'Buail APK nó .apks Anseo';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Treoracha buana le haghaidh stíl gutha agus idirghníomhaíochta. Tá tosaíocht fós ag rialacha sábháilteachta agus forghníomhaithe.';

  @override
  String get eGAlexSLaptop => 'e.g. ríomhaire glúine Alex';

  @override
  String get eGMyLocalServer => 'e.g. Mo freastalaí áitiúil';

  @override
  String get edit => 'Cuir in eagar';

  @override
  String get editAgent => 'Cuir Gníomhaire in Eagar';

  @override
  String get editCoreMemoryEntry => 'Cuir Iontráil Chroí-Chuimhne in Eagar';

  @override
  String get editInstructions => 'Cuir na treoracha in eagar';

  @override
  String get editMcpServer => 'Cuir Freastalaí MCP in eagar';

  @override
  String get editTask => 'Cuir Tasc in Eagar';

  @override
  String editedArg1(Object? arg1) {
    return 'Curtha in eagar $arg1';
  }

  @override
  String get email => 'Ríomhphost';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Ríomhphost chuig úinéirí cuntais maidir le síniú isteach a bhfuil cuma neamhghnách orthu.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Seol ríomhphost chuig úinéirí cuntais nuair a athraíonn a sonraí cuntais.';

  @override
  String get emailCode => 'Cód ríomhphoist';

  @override
  String get emailConfirmationRequired => 'deimhniú ríomhphoist ag teastáil';

  @override
  String get emailIsAlreadyInUse => 'tá ríomhphost in úsáid cheana féin';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Ríomhphost sábháilte. Má tá deimhniú ag teastáil, seiceáil an seoladh nua le haghaidh nasc dearbhaithe NeoAgent.';

  @override
  String get emailSettingsSaved => 'Socruithe ríomhphoist sábháilte.';

  @override
  String get emailUnverified => 'Ríomhphost neamhfhíoraithe';

  @override
  String get empty => 'Folamh';

  @override
  String get emptyFile => 'Comhad folamh';

  @override
  String get emptyFolder => 'Fillteán folamh';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Úsáideann Folamh réamhshocrú an fhreastalaí ($arg1).';
  }

  @override
  String get enable2fa => 'Cumasaigh 2FA';

  @override
  String get enableAll => 'Cumasaigh go léir';

  @override
  String get enableBehaviorModules => 'Cumasaigh modúil iompraíochta';

  @override
  String get enableOrDisableModels => 'Cumasaigh nó díchumasaigh samhlacha';

  @override
  String get enabled => 'Cumasaithe';

  @override
  String get encryptedPrivateToYourAccount =>
      'Criptithe, príobháideach do do chuntas';

  @override
  String get end => 'Deireadh';

  @override
  String get endCall => 'Cuir deireadh leis an nglao';

  @override
  String get endVoiceCall => 'Cuir deireadh le glao gutha?';

  @override
  String get endpoint => 'Críochphointe';

  @override
  String get enterAPassword => 'Cuir isteach pasfhocal.';

  @override
  String get enterAUsername => 'Cuir isteach ainm úsáideora.';

  @override
  String get enterAValidEmailAddress =>
      'Cuir isteach seoladh ríomhphoist bailí.';

  @override
  String get enterAnAddressManually => 'Cuir isteach seoladh de láimh';

  @override
  String get enterAnApiKeyFirst => 'Cuir isteach eochair API ar dtús.';

  @override
  String get enterInviteLink => 'Cuir isteach nasc cuireadh';

  @override
  String get enterTheAddressOfANeoagent =>
      'Cuir isteach seoladh freastalaí NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Cuir isteach na sonraí a thug $arg1 duit ionas gur féidir le $arg2 teachtaireachtaí a sheoladh agus a fháil.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Cuir isteach do 2FA nó cód aisghabhála.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Cuir isteach do phasfhocal reatha chun é a athrú.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Cuir isteach do phasfhocal reatha chun athruithe ríomhphoist a shábháil.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Cuir isteach do shonraí cuntais NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Cuir isteach d\'ainm úsáideora nó ríomhphost cuntais. Seolfaidh NeoAgent nasc athshocraithe más féidir leis an gcuntas a mheaitseáil.';

  @override
  String get enterYourUsernameOrEmail =>
      'Cuir isteach d\'ainm úsáideora nó ríomhphost.';

  @override
  String entityArg1(Object? arg1) {
    return 'Aonán: $arg1';
  }

  @override
  String get environment => 'Timpeallacht';

  @override
  String get error => 'Earráid';

  @override
  String errorArg1(Object? arg1) {
    return '\nearráid: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Earráidí ón loga le déanaí, grúpáilte de réir teachtaireachta.';

  @override
  String get errorsProblemsFailures => 'earráidí fadhbanna teipeanna';

  @override
  String get eventTypesCommaSeparated => 'Cineálacha Imeachtaí (camóg scartha)';

  @override
  String get every15Minutes => 'Gach 15 nóiméad';

  @override
  String get every30Minutes => 'Gach 30 nóiméad';

  @override
  String get everyAccountOnThisServerLoses =>
      'Cailleann gach cuntas ar an bhfreastalaí seo an eochair roinnte seo. Cuntais ';

  @override
  String get everyAccountOnThisServerSecrets =>
      'gach cuntas ar an bhfreastalaí seo. Tá rúin scríofa amháin: fág ';

  @override
  String get everyAccountOnThisServerUses =>
      'Úsáideann gach cuntas ar an bhfreastalaí seo an seoladh seo le haghaidh ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Críochnaíonn gach seisiún gníomhach don chuntas seo. Is féidir leo síniú isteach ';

  @override
  String get everyDay0800 => 'Gach lá · 08:00';

  @override
  String get everyDay2000 => 'Gach lá · 20:00';

  @override
  String get everyHour => 'Gach uair an chloig';

  @override
  String get everyRunOnThisServerAll =>
      'Gach rith ar an bhfreastalaí seo, an t-am ar fad.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Éilíonn gach uirlis íogair ceadú, gach uair.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Ritheann gach uirlis gan a iarraidh, ach amháin na cinn an duine ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Is féidir le gach duine sna grúpaí, cainéil nó seomraí seo labhairt le $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Gach duine sa ghrúpa seo';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Tagann gach rud $arg1 casta as do ghníomhaire ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Tá gach rud eile múchta.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Tá gach rud ar fáil ón deasc.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Gach rud is féidir leis an ngníomhaire a úsáid: comhtháthú oifigiúil, freastalaithe MCP, agus scileanna.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Tagann gach rud a chas tú as le haghaidh $arg1 ar ais ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Bunús cruinn gréasáin a cheadaítear chun iarratais tras-bhunaidh a dhéanamh, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Rith JavaScript taobh istigh de sheisiún do bhrabhsálaí.';

  @override
  String get execution => 'Forghníomhú';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Níl sonraí feidhmiúcháin ar fáil don rith seo.';

  @override
  String get executionPlanCreated => 'Cruthaíodh plean forghníomhaithe.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Seisiúin $arg1 a fheidhmiú';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[scoir $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Téann $arg1 in éag';
  }

  @override
  String get explainThisProject => 'Mínigh an tionscadal seo';

  @override
  String exploredArg1(Object? arg1) {
    return 'Taiscéaladh $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Taiscéaladh $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Rinneadh iniúchadh ar an spás oibre';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Theip ar an easpórtáil: $arg1';
  }

  @override
  String get exportLast5Messages =>
      'Easpórtáil na 5 theachtaireacht dheireanacha';

  @override
  String get exportMyData => 'Easpórtáil mo shonraí';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Theip ar sheoladh an bhrabhsálaí sheachtraigh le cód scoir $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'Ní thacaítear le seoladh brabhsálaí seachtrach ar an ardán seo.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Chuaigh an t-am istigh le seoladh an bhrabhsálaí sheachtraigh.';

  @override
  String get externalMcpTools => 'Uirlisí Seachtracha & MCP';

  @override
  String get extraButtons => 'Cnaipí Breise';

  @override
  String get extractingTheNeoagentRuntime => 'Baint an t-am rite NeoAgent';

  @override
  String get failed => 'Theip';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Theip ar nascadh: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Theip ar nascadh $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Níorbh fhéidir \"$arg1\" a scriosadh: $arg2';
  }

  @override
  String get failedToFetch => 'theip ar fháil';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Theip ar an leid a ghiniúint: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Theip ar bhrabhsálaí seachtrach a sheoladh trí url_launcher.';

  @override
  String get failedToLaunchOauthFlow =>
      'Theip ar an sreabhadh OAuth a sheoladh.';

  @override
  String get failedToLoadPolicies => 'Theip ar lódáil na mbeartas';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Theip ar shábháil: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Theip ar shábháil an fhreastalaí MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Theip ar an rogha a shábháil: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Theip ar fhógra a sheoladh chuig an inneall: $arg1';
  }

  @override
  String get fair => 'Cóir';

  @override
  String get fasterReplies => 'Freagraí níos tapúla';

  @override
  String get fewerModelCalls => 'Níos lú glaonna samhail';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'réimse folamh chun an réamhshocrú ionsuite a chur ar ais.';

  @override
  String get fileExceedsThe1MibEditor =>
      'Sáraíonn an comhad an teorainn eagarthóir 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'Sáraíonn an comhad an teorainn méide tacaithe.';

  @override
  String get fileWrites => 'Scríobhann Comhad';

  @override
  String get filename => 'Ainm comhaid';

  @override
  String get files => 'Comhaid';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Taispeántar anseo na comhaid a scríobhann nó a chuireann NeoAgent in eagar sa seisiún seo.';

  @override
  String get filesSavedByAllUsers => 'Comhaid arna sábháil ag gach úsáideoir';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Líon isteach logáil isteach ceadaithe nó fíordheimhnigh iarratais gan rúin a thaispeáint don AI.';

  @override
  String get finalResponse => 'Freagra Deiridh';

  @override
  String get findAPlatform => 'Aimsigh ardán';

  @override
  String get findAndFixABug => 'Aimsigh agus deisigh fabht';

  @override
  String get findRecentChats => 'Aimsigh comhráite le déanaí';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'An t-am rite NeoAgent ceart a aimsiú';

  @override
  String get finish => 'Críochnaigh';

  @override
  String get finishAtTheScheduledTime => 'Críochnaigh ag an am sceidealta';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Críochnaigh síniú isteach ar $arg1 i do bhrabhsálaí, ansin ceangail arís.';
  }

  @override
  String get flowGraph => 'Graf sreafa';

  @override
  String get flutterApp => 'App flutter';

  @override
  String get focusedExecutionProfile => 'Próifíl fhorghníomhaithe dhírithe';

  @override
  String get folderIdOptional => 'Aitheantas fillteáin (roghnach)';

  @override
  String get folderUnavailable => 'Níl an fillteán ar fáil';

  @override
  String get forExampleHttpsMatrixOrg => 'Mar shampla https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Le haghaidh socruithe líonra óstaithe nó ardchéime';

  @override
  String get forLinksInEmailsBlankUses =>
      'Le haghaidh naisc i ríomhphoist. Úsáideann Bán URL poiblí an fhreastalaí.';

  @override
  String get forgotPassword => 'Focal faire dearmadta?';

  @override
  String get frameUnavailable => 'Níl an fráma ar fáil';

  @override
  String freshnessArg1(Object? arg1) {
    return 'úire: $arg1';
  }

  @override
  String get fridays1700 => 'Dé hAoine · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Ó BotFather tar éis duit an bot a chruthú.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'As seo amach cinneann $arg1 cé na huirlisí is féidir le do ghníomhaire a úsáid. siad ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Ó Thairseach Fhorbróirí Discord, faoi do bot.';

  @override
  String get fromTheLineDevelopersConsole => 'Ó Chonsól Forbróirí LINE.';

  @override
  String get fromTheMatrixClientOrBot => 'Ón gcliant Matrix nó cuntas bot.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Ó twitchapps.com/tmi nó d’aip forbróra Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Leid iomlán';

  @override
  String get fullSetup => 'Socrú iomlán';

  @override
  String get general => 'Ginearálta';

  @override
  String get generalSettings => 'Socruithe ginearálta';

  @override
  String get generalSettingsSaved => 'Socruithe ginearálta sábháilte.';

  @override
  String get generateAPromptForAnotherAi =>
      'Gin leid le haghaidh AI eile, greamaigh an freagra anseo chun cuimhní cinn a allmhairiú.';

  @override
  String get generatePrompt => 'Gin Pras';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Earráid rianaithe geofence: $arg1';
  }

  @override
  String get getInspired => 'Faigh spreagtha';

  @override
  String get githubCopilot => 'Copilot GitHub';

  @override
  String get githubCopilotAndOpenaiCodex => 'GitHub Copilot agus OpenAI Codex';

  @override
  String get githubIssueOpened => 'Osclaíodh Eisiúint GitHub';

  @override
  String get neorecallMemoryCreated => 'Cuimhne NeoRecall Cruthaithe';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'Theip ar sheiceáil scaoileadh GitHub le HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'Ní raibh pálasta scaoileadh GitHub ina liosta scaoileadh.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Ainm úsáideora GitHub a d\'oscail an cheist';

  @override
  String get globalSecurityMode => 'Modh slándála domhanda';

  @override
  String get gmailMessageReceived => 'Fuarthas Teachtaireacht Gmail';

  @override
  String get good => 'Maith';

  @override
  String get goodAfternoon => 'Dea-tráthnóna';

  @override
  String get goodEvening => 'Dea-tráthnóna';

  @override
  String get goodMorning => 'Maidin mhaith';

  @override
  String get goodPasswordALittleMoreLength =>
      'Pasfhocal maith. Déanann fad beagán níos láidre é.';

  @override
  String get googleChat => 'Google Chat';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'Úsáideann GPT-Live d’eochair OpenAI API, Gemini Live d’eochair Google AI. Baineann athruithe leis an gcéad ghlao eile.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Deonaigh ceadanna Health Connect roimh shioncronú.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grúpa, cainéal, nó seomra';

  @override
  String get groupType => 'Cineál grúpa';

  @override
  String get groupsAndChannels => 'Grúpaí agus cainéil';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grúpaí: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Ní fhaca Grúpaí $arg1 fós é seo.';
  }

  @override
  String get handlesDirectTasksItself =>
      'Láimhseálann sé tascanna díreacha féin';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Saor ó lámha (labhairt faoi shaoirse, cuir isteach am ar bith)';

  @override
  String get headerName => 'Ainm ceanntásca';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Ceannlínte ar na hábhair is cúram duit, scagtha le haghaidh comhartha.';

  @override
  String get health => 'Sláinte';

  @override
  String get healthChecks => 'Seiceálacha sláinte';

  @override
  String get healthConnect => 'ceangal sláinte';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Níl Health Connect ar fáil ar an ngléas seo.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Stádas sioncronaithe Health Connect agus méadracht inneall stóráilte.';

  @override
  String get healthStatusIsUnavailable => 'Níl stádas sláinte ar fáil.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'Tá sioncronú sláinte ar fáil ar Android amháin.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Taifid Heart $arg1';
  }

  @override
  String get heldBack => 'Ar siúl ar ais';

  @override
  String get helper => 'Cúntóir';

  @override
  String helperArg1(Object? arg1) {
    return 'Cúntóir: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'anseo. Cúlghair admin le `neoagent admin a chúlghairm $arg1` ar dtús.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Déanann luachanna níos airde NeoAgent níos roghnaíoch i ngrúpaí.';

  @override
  String get highlyRecommended => 'Moltar go mór';

  @override
  String get holdButton131ForTheAssistant =>
      'Coinnigh cnaipe 131 don chúntóir.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Coinnigh Ctrl+Shift+Space le labhairt';

  @override
  String get holdToTalk => 'Coinnigh chun cainte.';

  @override
  String get holdToTalk2 => 'Coinnigh chun cainte';

  @override
  String get home => 'Baile';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Tá Comhartha Rochtana Fadsaoil an Chúntóra Baile ag teastáil.';

  @override
  String get homeAssistantSetup => 'Socrú Cúntóir Baile';

  @override
  String get homeAssistantUrl => 'URL an Chúntóra Baile';

  @override
  String get homeAssistantUrlIsRequired => 'Tá URL Cúntóir Baile ag teastáil.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Comhartha freastalaí tí le vótaíocht seomra';

  @override
  String get homeserverUrl => 'URL an fhreastalaí baile';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'seirbhís ósta). Tá d\'eochracha criptithe agus ní féidir iad a úsáid ach amháin ag ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Óstainm líonra an IRC, mar shampla irc.libera.chat';

  @override
  String get hourly => 'in aghaidh na huaire';

  @override
  String get hourlyInboxCheck => 'Seiceáil bosca isteach in aghaidh na huaire';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Cé chomh fada agus a fhanann naisc dheimhnithe bailí.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Cé chomh minic a lorgaíonn an gníomhaire seo teachtaireachtaí seomra nua.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Cé chomh minic a lorgaíonn an gníomhaire seo teachtaireachtaí Comhartha nua.';

  @override
  String get howTeamsWork => 'Conas a oibríonn foirne';

  @override
  String get howThisServerIsReachedPlus =>
      'Conas a shroichtear an freastalaí seo, chomh maith le lasca ar fud an fhreastalaí.';

  @override
  String get httpsSessionCookie => 'fianán seisiún https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Ní raibh mé in ann an t-iarratas sin a chomhlánú faoi láthair. Bain triail eile as i gceann nóiméad le do thoil.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Díomhaoin';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Má iarrann $arg1 URL cuaille gréasáin, greamaigh é seo ionas gur féidir le teachtaireachtaí $arg2 a shroicheadh.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Má tá ríomhphost deimhnithe ag an gcuntas sin, seolfaidh NeoAgent nasc athshocraithe pasfhocal.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Má tá comhartha ag teastáil ón tseirbhís ar iarratais amach.';

  @override
  String get ignoreGroups => 'Déan neamhaird de Ghrúpaí';

  @override
  String get ignoreThisChat => 'Déan neamhaird den chomhrá seo';

  @override
  String get ignoredChannels => 'Cainéil Neamhaird';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Neamhaird ar theachtaireacht chompánach deisce mhíchumtha: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Cuir an plean thuas i bhfeidhm.';

  @override
  String get implementThisPlan => 'Cuir an plean seo i bhfeidhm';

  @override
  String get implicitTls => 'TLS intuigthe';

  @override
  String get import => 'Iompórtáil';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Theip ar an iompórtáil: $arg1';
  }

  @override
  String get importFromComputer => 'Íosluchtaigh allmhairiú ó ríomhaire';

  @override
  String get importMemoryTransfer => 'Iompórtáil aistriú cuimhne?';

  @override
  String get importance => 'Tábhacht';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Cuimhní cinn $arg1 iompórtáilte, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'I bhfoireann @$arg1';
  }

  @override
  String get inBackground => 'chúlra';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Beidh teachtaireachtaí cainéil isteach agus amach le feiceáil anseo.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Glaonna gutha isteach in aip ó NeoAgent';

  @override
  String get incomingMessages => 'Teachtaireachtaí ag teacht isteach';

  @override
  String get incomingNeoagentCall => 'Glao ag teacht isteach NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'Glaoch NEOAGENT AG TEACHT';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Cúltaca gréasáin ag teacht isteach agus tacaíocht aisghlaoite amach';

  @override
  String get incorporatingSteering => 'Ionchorprú stiúrtha';

  @override
  String get input => 'Ionchur';

  @override
  String get inputMode => 'Mód ionchuir';

  @override
  String get insertATemplate => 'Cuir isteach teimpléad';

  @override
  String get install => 'Suiteáil';

  @override
  String get installASignedSelfContainedRuntime =>
      'Suiteáil am rite sínithe, féinchuimsitheach. Níl orduithe Node.js, npm, Git, agus teirminéil ag teastáil.';

  @override
  String get installApk => 'Suiteáil APK';

  @override
  String get installApkBundle => 'Suiteáil APK / Bundle';

  @override
  String get installApkClickOrDropA =>
      'Suiteáil APK - cliceáil nó scaoil comhad .apk';

  @override
  String get installNeoagent => 'Suiteáil NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Suiteáil NeoAgent ar an ríomhaire seo gan teirminéal, nó ceangail le ceann atá ag rith cheana féin.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Suiteáil eisiúintí nua agus roghnaigh cén cainéal a leanann an freastalaí seo.';

  @override
  String get installTheBackend => 'Suiteáil an t-inneall';

  @override
  String get installTheCoreWithExtraOptional =>
      'Suiteáil an croí le socrú breise roghnach. Cuirtear eochracha soláthraí AI leis ina dhiaidh sin, mar an gcéanna le Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Suiteáil an croí slán, ansin cruthaigh do chuntas. Cuir eochracha soláthraí AI leis ina dhiaidh sin.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Suiteáilte: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Suiteáilte: $arg1 • Seiceáilte go deireanach: $arg2';
  }

  @override
  String get instructions => 'Treoracha';

  @override
  String get integration => 'Comhtháthú';

  @override
  String get integrationApps => 'Aipeanna comhtháthú';

  @override
  String get integrationConnections => 'Naisc chomhtháthaithe';

  @override
  String get integrationSettingsSaved => 'Sábháladh socruithe comhtháthaithe.';

  @override
  String get integrations => 'Comhtháthaithe';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'comhtháthú/oauth/callback, agus é sin a chlárú ';

  @override
  String get interruptAi => 'Cur isteach ar AI';

  @override
  String get invalid2fa => 'neamhbhailí 2fa';

  @override
  String get invalidArgumentS => 'Argóintí neamhbhailí: ';

  @override
  String get invalidCredentials => 'dintiúir neamhbhailí';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Léiriú ama rite NeoAgent neamhbhailí.';

  @override
  String get inviteLink => 'Nasc cuireadh';

  @override
  String get inviteLinkReady => 'Nasc cuireadh réidh';

  @override
  String get inviteLinks => 'naisc cuireadh';

  @override
  String get iphoneApp => 'app iPhone';

  @override
  String get issues => 'Saincheisteanna';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Tagann ceisteanna nuair a bhíonn an logáil ualaí.';

  @override
  String get itCanTBeUndone => 'Ní féidir é a chealú.';

  @override
  String get itMayHaveBeenDeleted => 'Seans gur scriosadh é.';

  @override
  String get javaRuntime => 'Am rite java';

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
    return 'Chuaigh $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Glacadh leis le 7 lá anuas';

  @override
  String get joiningATeam => 'Ag dul isteach i bhfoireann';

  @override
  String get joiningIsOffHere => 'Níl aon dul isteach anseo';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Réimse JSON ina bhfuil téacs na teachtaireachta. De ghnáth téacs.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Réimse JSON a shainaithníonn cé dó a bhfuil an teachtaireacht.';

  @override
  String get jumpToLatest => 'Léim go dtí an ceann is déanaí';

  @override
  String get justNow => 'díreach anois';

  @override
  String get keepNeoagentRunning => 'Coinnigh NeoAgent ag rith?';

  @override
  String get keepRunning => 'Coinnigh ar siúl';

  @override
  String get keepTaskRunning => 'Coinnigh an tasc ar siúl';

  @override
  String get keepTheVaultAvailable => 'Coinnigh an cruinneachán ar fáil';

  @override
  String get keepThisLauncherUpToDate =>
      'Coinnigh an tosaitheoir seo cothrom le dáta.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Coinnigh an painéal seo ar oscailt go dtí go ndeimhníonn an t-ardán an nasc.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Coinnigh ríomhaire an tseisiúin seo le feiceáil';

  @override
  String get keepTrackOfYourAiUsage =>
      'Coinnigh súil ar d’úsáid AI. Cuirtear teorainneacha i bhfeidhm chun úsáid chothrom a chinntiú ar fud an ardáin.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Lean ort ag úsáid d\'aipeanna de ghnáth. Oibríonn NeoAgent ar an scáileán céanna agus fiafraíonn sé aon uair a theastaíonn rochtain nua uaidh.\n\n';

  @override
  String get keepingThisDeviceConnected => 'An gléas seo a choinneáil nasctha';

  @override
  String get key => 'eochair';

  @override
  String get keyIsRequired => 'Tá eochair ag teastáil.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Péirí eochairluacha a leanann trasna comhráite.';

  @override
  String get knowledgeGraph => 'Graf Eolais';

  @override
  String get knowledgeView => 'Radharc eolais';

  @override
  String get labelOnlyYouSeeIt => 'Lipéad (ní fheiceann tú é ach amháin)';

  @override
  String get labelsOptional => 'Lipéid (roghnach)';

  @override
  String get last24Hours => '24 uair an chloig caite';

  @override
  String get last7Days => '7 lá seo caite';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Na 7 lá seo caite: Ritheann comharthaí $arg1 i $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return '$arg1 is déanaí';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Last: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Sioncronú neamhfholamh is déanaí · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Rith dheireanach: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Le feiceáil go deireanach $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'An síniú isteach is déanaí $arg1';
  }

  @override
  String get lastSyncSummary => 'Achoimre Sioncronaithe Deiridh';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'An uair dheireanach a úsáideadh: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Chríochnaigh an fhuinneog dheireanach $arg1';
  }

  @override
  String get laterStartSwitchedOffToo => 'tús níos déanaí múchta freisin.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'An rith is déanaí · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Ní thacaítear le seoladh aipeanna deisce ar an ardán seo.';

  @override
  String get learnRoomNorms => 'Foghlaim noirm seomra';

  @override
  String get leave => 'Fág';

  @override
  String get leaveARedirectUriBlankTo =>
      'Fág URI Atreoraithe bán chun <URL poiblí>/api/ a úsáid';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Fág foireann $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Fág mar an réamhshocrú mura ndearna tú BlueBubbles saincheaptha.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Fág an comhartha folamh chun an comhartha atá stóráilte faoi láthair a choinneáil.';

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
    return 'Lig $arg1 mé a bhainistiú';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Lig do gach duine sa ghrúpa seo labhairt le $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Lig dó oibriú cé\nnach ndéanann tú.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Lig do NeoAgent cliceáil, clóscríobh agus bogadh trí do chuid apps.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Lig do NeoAgent a thuiscint cad atá le feiceáil ar do scáileán.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Lig do dhuine éigin lena n-oibríonn tú cinneadh a dhéanamh ar na huirlisí is féidir le do ghníomhaire ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Lig don duine seo $arg1 teachtaireacht duine le duine a sheoladh.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Lig don duine seo labhairt le $arg1 anseo, ach ní i gcomhráite príobháideacha ná i ngrúpaí eile.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Lig don duine seo labhairt le $arg1 i gcomhráite príobháideacha agus in aon ghrúpa a roinneann siad.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Leibhéal $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Nasc $arg1';
  }

  @override
  String get linkCopied => 'Cóipeáladh an nasc';

  @override
  String get linkExpiresAfter => 'Téann nasc in éag tar éis';

  @override
  String get linkLifetimeHours => 'Saolré naisc (uaireanta)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'Ní mór do shaolré an naisc a bheith ó 1 go 8760 uair an chloig.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Nasc bailí go dtí $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Soláthraithe logáil isteach nasctha';

  @override
  String get linuxApp => 'Clár Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Liostaithe $arg1/';
  }

  @override
  String get listening => 'Ag éisteacht';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Stair forghníomhaithe beo, céimeanna uirlisí, agus freagraí.';

  @override
  String get liveModel => 'Múnla beo';

  @override
  String get liveModelProvider => 'Soláthraí múnla beo';

  @override
  String get liveRun => 'Rith beo';

  @override
  String get liveVoice => 'Guth beo';

  @override
  String get liveVoiceConnectionIsNotAvailable => 'Níl nasc gutha beo ar fáil.';

  @override
  String get liveVoiceConnectionWasClosed => 'Dúnadh nasc gutha beo.';

  @override
  String get liveVoiceDefaults => 'Réamhshocruithe gutha beo';

  @override
  String get liveVoiceFailed => 'Theip ar an nguth beo.';

  @override
  String get llmMemoryExportResponse => 'Freagra easpórtála cuimhne LLM';

  @override
  String get loadFailed => 'theip ar an ualach';

  @override
  String get loadingExecutionDetails => 'Sonraí feidhmiúcháin á lódáil...';

  @override
  String get loadingNeoagent => 'NeoAgent á luchtú';

  @override
  String get loadingRunFlow => 'Sreabhadh rith á lódáil…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Tacaítear le URLanna líonra áitiúla agus príobháideacha nuair is féidir leis an bhfreastalaí NeoAgent iad a bhaint amach. Ní nochtar fuaime riamh do NeoAgent.';

  @override
  String get localApp => 'app áitiúil';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'Níl suiteáil inneall áitiúil ar fáil ar an ardán seo.';

  @override
  String get localBaseImagePath => 'Conair íomhá bonn áitiúil';

  @override
  String get localComputerControlIsAvailableIn =>
      'Tá rialú ríomhaire áitiúil ar fáil san aip deisce NeoAgent ar macOS, Windows agus Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'Níl rialú ríomhaire áitiúil ar fáil anseo.';

  @override
  String get localModelsUrl => 'múnlaí áitiúla url';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'Níl fionnachtain Áitiúil NeoAgent ar fáil go sealadach.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Roghanna áitiúla don fheidhmchlár NeoAgent. Ritheann rialú ríomhaire i gcónaí tríd an ríomhaire scamall aontaithe.';

  @override
  String get localSetup => 'Socrú ÁITIÚIL';

  @override
  String get locationCityOrPlace => 'Suíomh (cathair nó áit)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Tá suíomh ag teastáil le haghaidh truicear imeachtaí aimsire';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Theip ar thúsú LocationService: $arg1';
  }

  @override
  String get logCopied => 'Cóipeáladh an logáil';

  @override
  String get loginPassword => 'Pasfhocal logáil isteach';

  @override
  String get logout => 'Lógó amach';

  @override
  String get logs => 'Logs';

  @override
  String get logsCopied => 'Logchomhaid cóipeáilte.';

  @override
  String get logsOnThisComputer => 'Logs ar an ríomhaire seo';

  @override
  String get longLivedAccessToken => 'Comhartha Rochtana Fadsaoil';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Athghairm fhadtéarmach, fíricí struchtúrtha, agus graf eolais.';

  @override
  String get lookedAtTheScreen => 'D\'fhéach sé ar an scáileán';

  @override
  String get lookingOnThisComputerAndYour =>
      'Ag féachaint ar an ríomhaire seo agus ar do líonra áitiúil…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Féachann sé chun cinn ar chruinnithe an lae amárach ionas nach gcuirfidh aon rud iontas ort.';

  @override
  String get loopExecution => 'Feidhmiú lúb';

  @override
  String get loopPaused => 'Lúb ar sos';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'macOS Ní thugtar Inrochtaineacht do NeoAgent. Ceadaigh é i Socruithe an Chórais › Príobháideacht & Slándáil › Inrochtaineacht.';

  @override
  String get macosApp => 'app macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'ní dheonaítear Taifeadadh Scáileáin macOS do NeoAgent. Ceadaigh é i Socruithe an Chórais › Príobháideacht & Slándáil › Taifeadadh Scáileáin, ansin athoscail NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Diúltóidh freastalaithe ríomhphoist a dteastaíonn pasfhocal uathu a sheoladh go dtí ceann nua ';

  @override
  String get main => 'Príomh-';

  @override
  String get makeDefault => 'Déan réamhshocraithe';

  @override
  String get manage => 'Bainistigh';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Bainistigh do ríomhphost cuntais, fíordheimhniú dhá fhachtóir, agus seisiúin ghníomhacha.';

  @override
  String get managedBy => 'Á bhainistiú ag';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Féadfaidh bainisteoirí dá gcuid féin a bheith acu (suas le ceithre leibhéal). A ';

  @override
  String get managing => 'Bainistiú';

  @override
  String get manualDestination => 'Ceann scríbe láimhe';

  @override
  String get manualTrigger => 'Truicear Lámhleabhar';

  @override
  String get masterPassword => 'Máistir phasfhocal';

  @override
  String get matchThisDevice => 'Meaitseáil an gléas seo';

  @override
  String get matchedAgainstTitleAndBody =>
      'Meaitseáladh i gcoinne teidil agus coirp';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Meaitseálann sé an sean-sreabhadh MCP NeoAgent: URL móide modh an údair.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'MCP freastalaí';

  @override
  String get mcpServer2 => 'Freastalaí MCP';

  @override
  String get mcpServerUrl => 'URL Freastalaí MCP';

  @override
  String get mcpServers => 'Freastalaithe MCP';

  @override
  String get meantForSomeoneElse => 'I gceist do dhuine eile';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Costas múnla tomhaiste: $arg1';
  }

  @override
  String get memories => 'Cuimhní cinn';

  @override
  String get memory => 'Cuimhne';

  @override
  String memoryArg1(Object? arg1) {
    return 'Cuimhne: $arg1';
  }

  @override
  String get memoryInjected => 'Cuimhne ghann';

  @override
  String get mentionOrReplyOnly => 'Luaigh nó freagra amháin';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Logaí freastalaí cumaisc agus am rite Flutter don seisiún aipe seo.';

  @override
  String get messageBodyTemplateJson =>
      'Teimpléad corp na teachtaireachta (JSON)';

  @override
  String get messageNeedsAccess => 'Teastaíonn rochtain ar an teachtaireacht';

  @override
  String get messageTextField => 'Réimse téacs teachtaireachta';

  @override
  String get messaging => 'teachtaireachtaí';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Imeachtaí brú agus cuaille gréasáin API teachtaireachtaí';

  @override
  String get messagingConnectionNeedsAttention =>
      'Ní mór aird a thabhairt ar nasc teachtaireachtaí';

  @override
  String get messagingConnections => 'Naisc Teachtaireachtaí';

  @override
  String get messagingDelivery => 'Seachadadh teachtaireachtaí';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Earráid teachtaireachta. Bain triail eile as.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'Stopadh gabháil an mhicreafóin gan choinne. Bain triail eile as.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Earráid micreafón: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Micreafón balbhaithe. Tapáil chun díbhalbhú.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Teastaíonn cead micreafón le haghaidh guth beo.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftSlackAndTheOtherIntegrations =>
      'Microsoft, Slack agus na comhtháthú eile. Baineann siad le ';

  @override
  String get microsoftTeams => 'Foirne Microsoft';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Íosluach ranníocaíochta: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Theip ar shocrú móibíleach.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'Theip ar shocrú móibíleach toisc nach bhfuil Java ar fáil ar an meaisín a ritheann NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'Theip ar shocrú móibíleach toisc nach bhfuil Java ar fáil ar an meaisín a ritheann NeoAgent. Suiteáil JDK agus bain triail eile as.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Theip ar shocrú móibíleach. Seiceáil go bhfuil uirlisí Android suiteáilte i gceart agus bain triail eile as.';

  @override
  String modeArg1(Object? arg1) {
    return 'mód: $arg1';
  }

  @override
  String get modeLocksWhileARunIs => 'Glais mód agus rith gníomhach.';

  @override
  String get model => 'Múnla';

  @override
  String modelArg1(Object? arg1) {
    return 'Múnla: $arg1';
  }

  @override
  String get modelAvailability => 'Infhaighteacht múnla';

  @override
  String get modelAvailabilitySaved => 'Infhaighteacht mhúnla sábháilte.';

  @override
  String get modelForThisSession => 'Múnla don seisiún seo';

  @override
  String get modelOverride => 'Sárú Múnla';

  @override
  String get modelPending => 'Múnla ar feitheamh';

  @override
  String get modelTurn => 'Cas múnla';

  @override
  String get modelTurnCompleted => 'Casadh múnla críochnaithe';

  @override
  String get modelTurnStarted => 'Thosaigh cas samhail';

  @override
  String get modelVisibilityHideShowList => 'liosta taispeána folaithe samhail';

  @override
  String get models => 'Múnlaí';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Múnlaí, iompar, guth, agus spás oibre';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Múnlaí, brabhsálaí, guth, diagnóisic...';

  @override
  String get modelsRouting => 'Múnlaí & ródú';

  @override
  String get monthly => 'go míosúil';

  @override
  String get moreActions => 'Tuilleadh gníomhartha';

  @override
  String get morningBriefing => 'Seisiún faisnéise maidin';

  @override
  String get mostUsedAgents => 'Gníomhairí is mó a úsáidtear';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Samhlacha is mó a úsáidtear sa $arg1 seo caite.';
  }

  @override
  String get mouseKeyboard => 'Luch & méarchlár';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'Ní thacaítear le mouseMove ar an ardán seo.';

  @override
  String get mustBeReachableOnThePublic =>
      'Ní mór go mbeadh sé inrochtana ar an idirlíon poiblí -- áitiúil agus ';

  @override
  String get n24Hours => '24 uair an chloig';

  @override
  String get n2faOrRecoveryCode => '2FA nó cód aisghabhála';

  @override
  String get n2faRequiresSessionSecretToBe =>
      'Éilíonn 2FA go ndéanfaí SESSION_SECRET a chumrú ar an imscaradh NeoAgent seo.';

  @override
  String get n30Days => '30 lá';

  @override
  String get n365Days => '365 lá';

  @override
  String get n4HourLimitTokens => 'Teorainn 4 huaire (comharthaí)';

  @override
  String get n4HourUsage => 'Úsáid 4 uair an chloig';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Teorainn 4h $arg1';
  }

  @override
  String get n7DayUsage => 'Úsáid 7 lá';

  @override
  String get n7Days => '7 lá';

  @override
  String get n90Days => '90 lá';

  @override
  String get name => 'Ainm';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nainm: Scil Nua\nCur síos: Déan cur síos ar a ndéanann an scil seo\n---\nScríobh na treoracha don scil seo anseo.\n';

  @override
  String get nameOfWhoeverMadeIt => 'ainm an té a rinne é.';

  @override
  String get nameOptional => 'Ainm (roghnach)';

  @override
  String get nativeAndWebhookChannels =>
      'Cainéil dhúchasach agus sracfhéachaint';

  @override
  String get naturalBubbles => 'Boilgeoga nádúrtha';

  @override
  String get nearbyNeoagentServers => 'Freastalaithe NeoAgent in aice láimhe';

  @override
  String get needANewAccountRegister => 'Cuntas nua uait? Clár';

  @override
  String get needAnIdea => 'An dteastaíonn smaoineamh?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Gá le freagra · $arg1% a labhairt';
  }

  @override
  String get needsAttention => 'Teastaíonn aird';

  @override
  String get needsInput => 'Tá ionchur de dhíth';

  @override
  String get neoagentApp => 'Feidhmchlár NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgent, $arg1';
  }

  @override
  String get neoagentAssistant => 'Cúntóir NeoAgent';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'Níorbh fhéidir le NeoAgent an t-am rite inneall atá ar fáil a sheiceáil.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'Níorbh fhéidir le NeoAgent an socrú áitiúil a chríochnú.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'Níorbh fhéidir le NeoAgent an socrú áitiúil a chríochnú. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Faisnéis dífhabhtaithe NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'Suiteálaí Deisce NeoAgent';

  @override
  String get neoagentFlutterUpdater => 'Nuashonróir Flutter NeoAgent';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'Suiteáil NeoAgent an $arg1 is déanaí ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'Tá NeoAgent suiteáilte agus á reáchtáil.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'Níl NeoAgent suiteáilte ar an ríomhaire seo.';

  @override
  String get neoagentIsReady => 'Tá NeoAgent réidh';

  @override
  String get neoagentIsStillWorkingOnA =>
      'Tá NeoAgent fós ag obair ar thasc. Cuir deireadh leis an nglao agus faigh an toradh sa chomhrá, nó cuir an tasc ar ceal freisin.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'Tá NeoAgent ag déanamh do thaispeántas ina sreabhadh oibre inoiriúnaithe.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'Tá NeoAgent ag fanacht agus tú ag úsáid an deasc.';

  @override
  String get neoagentIsWorking => 'Tá NeoAgent ag obair';

  @override
  String get neoagentLinuxComputer => 'NeoAgent Linux do ríomhaire';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT GÁ CINNEADH';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgent <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Teastaíonn seoladh slán ó íoslódálacha NeoAgent am rite.';

  @override
  String get neoagentServerAddress => 'Seoladh freastalaí NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'Níl ríomhphost seirbhíse NeoAgent réidh. Iarr ar oibreoir an fhreastalaí na socruithe timpeallachta ríomhphoist a sheiceáil.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'Níorbh fhéidir socrú NeoAgent a chríochnú.';

  @override
  String get neoagentUser => 'Úsáideoir NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'Úsáideann NeoAgent an ríomhaire seo go huathoibríoch agus fiafraíonn sé sula n-úsáideann sé do scáileán, luch, méarchlár, comhaid nó líne ordaithe.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'Úsáideann NeoAgent do shuíomh cúlra gar chun meabhrúcháin geofence a spreagadh (m.sh. \"Cuir i gcuimhne dom bainne a cheannach agus mé ag siúl thar an ollmhargadh\").\n\n';

  @override
  String get neoagentWorkspace => 'Spás Oibre NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][cruach] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'URL Inneall NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Tá URL inneall NeoRecall ag teastáil.';

  @override
  String get neorecallSetup => 'Socrú NeoRecall';

  @override
  String get networkRequestFailed => 'Theip ar iarratas líonra';

  @override
  String get networkWriteRequests => 'Iarratais Scríobh Líonra';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'ní chuirtear san áireamh riamh na teorainneacha úsáide roinnte.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Deimhníonn cuntais nua a seoladh ríomhphoist sula síníonn siad isteach.';

  @override
  String get newAccountsPerDay => 'Cuntais nua in aghaidh an lae';

  @override
  String get newChat => 'Comhrá nua';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Fanann grúpaí nua ciúin mura gcuireann duine éigin clibeanna ar $arg1, go dtí go gcuirfidh tú ar siúl iad.';
  }

  @override
  String get newLink => 'Nasc nua';

  @override
  String get newPasswordsDoNotMatch => 'Ní hionann pasfhocail nua.';

  @override
  String get newRecoveryCodes => 'Cóid athshlánaithe nua';

  @override
  String get newSession => 'Seisiún nua';

  @override
  String get newSessionN => 'Seisiún nua (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Seisiún nua leis an socrú céanna';

  @override
  String get newSkill => 'Scil nua';

  @override
  String get newSkill2 => 'Scil Nua';

  @override
  String get newThisWeek => 'Nua an tseachtain seo';

  @override
  String get newsDigest => 'Achoimre nuachta';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'An chéad triail eile: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Sreabhadh Logáil Isteach Nextcloud';

  @override
  String get nextcloudSetup => 'Socrú Nextcloud';

  @override
  String get nextcloudTalk => 'Caint Nextcloud';

  @override
  String get nextcloudUrl => 'URL Nextcloud';

  @override
  String get nextcloudUrlIsRequired => 'Tá URL Nextcloud ag teastáil.';

  @override
  String get nickname => 'Leasainm';

  @override
  String get noAccountsConnectedYet => 'Níl aon chuntas ceangailte go fóill.';

  @override
  String get noAccountsFound => 'Níor aimsíodh aon chuntais.';

  @override
  String get noActiveSessionsFound => 'Níor aimsíodh aon seisiún gníomhach.';

  @override
  String get noAgentsYet => 'Níl gníomhairí fós';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Níl aon soláthraí AI cumraithe, mar sin comhrá agus teachtaireachtaí ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Gan aon leideanna formheasa - ritheann gníomhaire gan bhriseadh.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Níor mheaitseáil aon sócmhainn scaoilte $arg1 leis an ardán seo.';
  }

  @override
  String get noArguments => '(gan argóintí)';

  @override
  String get noAuth => 'Uimh údar';

  @override
  String get noBindingsYet => 'Níl aon cheangal fós.';

  @override
  String get noChangesYet => 'Níl aon athruithe fós';

  @override
  String get noChannelsFound => 'Níor aimsíodh aon chainéil';

  @override
  String get noCloudComputerSlotIsFree =>
      'Níl aon sliotán ríomhaire scamall saor in aisce faoi láthair. Bain triail eile as i gceann nóiméad.';

  @override
  String get noCoreMemoryEntriesYet => 'Níl aon iontrálacha croí-chuimhne fós.';

  @override
  String get noDescription => 'Gan tuairisc';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Níl aon taispeántais deisce ar fáil faoi láthair.';

  @override
  String get noDetailAvailable => 'Níl aon sonraí ar fáil';

  @override
  String get noDetailedSyncSummaryYet =>
      'Níl aon achoimre sioncronaithe mionsonraithe fós.';

  @override
  String get noDetailsCaptured => 'Níor gabhadh sonraí ar bith.';

  @override
  String get noEmailLinked => 'Níl aon ríomhphost nasctha';

  @override
  String get noExternalSignInProvidersLinked =>
      'Níl aon soláthraithe síniú isteach seachtracha nasctha.';

  @override
  String get noGroupMessagesYet => 'Níl aon teachtaireacht ghrúpa fós';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Níor cuireadh aon daoine grúpa-shonracha leis fós.';

  @override
  String get noGroupsAddedYet => 'Níor cuireadh aon ghrúpa leis fós.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Níor aimsíodh aon ghrúpa fós. Tar éis do $arg1 teachtaireacht ghrúpa a fheiceáil, bain úsáid as Aimsigh comhráite le déanaí agus taispeánfar iad anseo.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Níor aimsíodh aon ghrúpa fós. Tar éis do $arg1 teachtaireacht ghrúpa a fheiceáil, bain úsáid as Aimsigh comhráite le déanaí.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Níor cuireadh aon ualach pá sonraí sláinte ar ais.';

  @override
  String get noHealthSamplesStoredYet =>
      'Níl aon samplaí sláinte stóráilte fós.';

  @override
  String get noHttpClientImplementationForThis =>
      'Níl aon chur i bhfeidhm cliant HTTP don ardán seo.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Níor taifeadadh aon ionchur nó aschur don chéim seo.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Níl aon chomhtháthú ag teacht leis an gcuardach seo.';

  @override
  String get noLimit => 'Gan teorainn';

  @override
  String get noLocalPasswordIsSetYet =>
      'Níl aon phasfhocal áitiúil socraithe fós. Cruthaigh ceann chun síniú isteach ainm úsáideora/pasfhocal a chumasú.';

  @override
  String get noLogEntries => 'Uimh iontrálacha loga.';

  @override
  String get noMatchingSettings => 'Gan socruithe meaitseála';

  @override
  String get noMcpServersMatchThisSearch =>
      'Níl aon fhreastalaí MCP ag teacht leis an gcuardach seo.';

  @override
  String get noMemoryEntriesFound => 'Níor aimsíodh aon iontrálacha cuimhne.';

  @override
  String get noMemorySync => 'Gan sioncronú cuimhne';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Léann sé an post tábhachtach agus seolta ó na 12 mhí seo caite uair amháin, ionas go mbeidh aithne ag an ngníomhaire ar do theagmhálaithe agus do thionscadail.';

  @override
  String get emailMemory => 'Cuimhne ríomhphoist';

  @override
  String get importNow => 'Iompórtáil anois';

  @override
  String get importOnConnect => 'Iompórtáil seanphost nuair a nascar cuntas';

  @override
  String get sweepStarting => 'Á ullmhú…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Ríomhphoist á léamh · $done as $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Ríomhphoist á léamh · $count aimsithe';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Ag foghlaim ó ríomhphoist · $done as $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Iompórtáil dheireanach: $emails ríomhphost · $memories cuimhne nua';
  }

  @override
  String get sweepNothingNew => 'Níl aon ríomhphoist nua le hiompórtáil';

  @override
  String sweepFailed(String error) {
    return 'Theip ar an iompórtáil: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Níl aon mhúnla ag teacht le \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Níor taifeadadh aon iarratas samhail don rith seo.';

  @override
  String get noModelsDiscoveredYet => 'Níor aimsíodh samhlacha fós';

  @override
  String get noModelsSelected => 'Níor roghnaíodh aon mhúnlaí';

  @override
  String get noModelsYet => 'Gan samhlacha fós';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'níl aon chuntas nuaghníomhaire nasctha leis an soláthraí seo';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Níl aon am rite inneall NeoAgent ar fáil don ríomhaire seo.';

  @override
  String get noNetworkConnection => 'Gan nasc líonra';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Gan nasc líonra. Ceangail chun leanúint ar aghaidh ag baint úsáide as NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Gan nasc líonra. Athcheangail le seiceáil le haghaidh nuashonruithe.';

  @override
  String get noOne => 'Aon duine';

  @override
  String get noOneAddedYet => 'Níor chuir éinne leis fós.';

  @override
  String get noOneCanMessage => 'Ní féidir le duine ar bith teachtaireacht';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Níor aimsíodh aon fhreastalaí NeoAgent eile. Is féidir leat cuardach a dhéanamh arís nó seoladh a chur isteach de láimh.';

  @override
  String get noPeopleAddedYet => 'Níor cuireadh aon duine leis fós.';

  @override
  String get noPlatformsMatch => 'Ní mheaitseálann aon ardáin';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Níl aon soláthraí ar fáil le cumrú fós.';

  @override
  String get noRecentChannelActivity =>
      'Níl aon ghníomhaíocht cainéil le déanaí';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Níl torthaí ar \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Níl aon rith sa raon seo.';

  @override
  String get noRunsMatchTheseFilters =>
      'Níl aon rith ag teacht leis na scagairí seo';

  @override
  String get noRunsYet => 'Níl aon rith fós';

  @override
  String get noRunsYet2 => 'Níl aon rith fós.';

  @override
  String get noSecurityKeyWasProvided =>
      'Níor soláthraíodh eochair shlándála ar bith.';

  @override
  String get noServerUrlSet => 'Níl URL freastalaí socraithe';

  @override
  String get noSessionMatchesThatSearch =>
      'Ní mheaitseálann aon seisiún leis an gcuardach sin.';

  @override
  String get noSessionsYet => 'Níl seisiúin ar bith fós';

  @override
  String get noSkillsMatchTheseFilters =>
      'Níl aon scileanna ag teacht leis na scagairí seo.';

  @override
  String get noStepsWereRecordedForThis =>
      'Níor taifeadadh aon chéimeanna don rith seo.';

  @override
  String get noSummaryAvailable => 'Níl achoimre ar fáil.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Níl aon tascanna le haghaidh $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Ní thagann aon uirlis le \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Níl aon nuashonrú ar siúl';

  @override
  String get noUsageYet => 'Gan úsáid fós.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Níl aon am rite inneall fíoraithe NeoAgent ar fáil go fóill.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Ní féidir le duine ar bith é a úsáid níos mó. Daoine a chuaigh isteach cheana féin ';

  @override
  String get none => 'Dada';

  @override
  String get notApprovedYet => 'gan faomhadh fós';

  @override
  String get notAuthenticated => 'gan fíordheimhnithe';

  @override
  String get notCheckedYet => 'Gan seiceáil fós';

  @override
  String get notConfigured => 'Gan a bheith cumraithe';

  @override
  String get notConnected => 'Gan ceangal';

  @override
  String get notConnected2 => 'Gan Ceangailte';

  @override
  String get notInstalled => 'Gan suiteáilte';

  @override
  String get notNeeded => 'Ní gá';

  @override
  String get notNeededEnough => 'Ní gá go leor';

  @override
  String get notNow => 'Ní anois';

  @override
  String get notNow2 => 'Ní Anois';

  @override
  String get notSet => 'Gan socraithe';

  @override
  String get notSetUp => 'Gan a chur ar bun';

  @override
  String get notTheSameAsAdmin => 'Ní mar an gcéanna le admin';

  @override
  String get nothingFound => 'Ní bhfuarthas aon rud';

  @override
  String get nothingHereYet => 'Ní dhéanfaidh aon ní anseo go fóill.';

  @override
  String get nothingHereYet2 => 'Ní dhéanfaidh aon ní anseo go fóill';

  @override
  String get nothingMatches => 'Ní mheaitseálann tada';

  @override
  String get nothingStoredYet => 'Ní dhéanfaidh aon ní a stóráil go fóill.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Nóisean, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthAppCredentialsThatLetAccounts =>
      'Dintiúir aip OAuth a ligeann do chuntais Google a nascadh, ';

  @override
  String get oauthClientId => 'Aitheantas Cliant OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'oauth cliant id rún atreorú eochair api';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'oauth cliant id rúnda atreorú tiomáint féilire gmail';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'Ní thacaítear le seoladh OAuth ar an ardán seo.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'oauth outlook tenant id cliant rúnda';

  @override
  String get oauthToken => 'Comhartha OAuth';

  @override
  String get oauthWithPkce => 'OAuth le PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'de $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'dá chuid féin. Ní thaispeántar arís é tar éis coigilt.';

  @override
  String get off => 'Múchta';

  @override
  String get officialIntegration => 'Comhtháthú oifigiúil';

  @override
  String get officialIntegrationDidNotReturnA =>
      'Níor chuir comhtháthú oifigiúil URL ceangail ar ais.';

  @override
  String get on => 'Ar siúl';

  @override
  String get onASignedInAndroidDevice =>
      'Ar ghléas Android sínithe isteach, oscail Socruithe › Sínigh isteach & slándáil, scanadh an cód seo, agus ceadaigh an logáil isteach.';

  @override
  String get onByDefaultForNewGroups =>
      'Ar siúl de réir réamhshocraithe do ghrúpaí nua';

  @override
  String get onDemand => 'Ar Éileamh';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Ar siúl le haghaidh $arg1 de ghrúpaí $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'ar. Ní féidir leo páirt a ghlacadh arís ach le nasc cuirí nua.';

  @override
  String get onYourOwnTheDefault => 'Ar do shon féin (an réamhshocrú)';

  @override
  String get once => 'Uair amháin';

  @override
  String get oneBlankToKeepWhatIs =>
      'bán amháin chun an méid atá stóráilte a choinneáil.';

  @override
  String get oneIsSavedOtherChangesIn =>
      'tá ceann amháin shábháil. Déantar athruithe eile ar an bhfoirm seo a shábháil freisin.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Chuaigh cuntas amháin nó níos mó in éag. Athcheangail an cuntas lena mbaineann chun rochtain uirlisí a aischur.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Rialaíonn am rite amháin pearsana, sealaíocht ghrúpa, cuimhne an tseomra, noirm, Teoiric na hIntinne, agus seachadadh.';

  @override
  String get oneTimeRun => 'Rith aonuaire';

  @override
  String get onlyApkOrApksFilesCan =>
      'Ní féidir ach comhaid .apk nó .apks a shuiteáil.';

  @override
  String get onlyInThisGroup => 'Sa ghrúpa seo amháin';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Ní gá ach amháin má iarrann an tseirbhís ceanntásca HTTP breise.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Ní gá ach amháin más mian leat an pálasta atá ag dul as oifig a athmhúnlú.';

  @override
  String get onlyTheyCanChangeIt => 'Ní féidir leo ach é a athrú.';

  @override
  String get open => 'Oscail';

  @override
  String get openAccountSettingsOnASigned =>
      'Socruithe Oscailte › Sínigh isteach & slándáil ar ghléas Android sínithe isteach, scanadh an cód seo, agus ceadaigh an logáil isteach.';

  @override
  String get openComputer => 'Oscail ríomhaire';

  @override
  String get openDashboard => 'Oscail painéal';

  @override
  String get openFolder => 'Oscail fillteán…';

  @override
  String get openInWorkbench => 'Oscail sa bhinse oibre';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Oscail NeoAgent agus athcheangail $arg1 chun teachtaireachtaí a chur ar ais.';
  }

  @override
  String get openTimeSettings => 'Socruithe am oscailte';

  @override
  String get openToAnyone => 'Oscailte do dhuine ar bith';

  @override
  String get openTrello => 'Oscail Trello';

  @override
  String get openVoiceAssistant => 'Oscail cúntóir gutha';

  @override
  String get openWiFiSettings => 'Oscail socruithe Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Oscail leis an app réamhshocraithe';

  @override
  String get openaiCodex => 'Codex OpenAI';

  @override
  String get openaiCompatible => 'openai comhoiriúnach';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Críochphointe OpenAI-comhoiriúnach (do fhreastalaí féin, nó freastalaí eile ';

  @override
  String openedArg1(Object? arg1) {
    return 'Osclaíodh $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Ní thacaítear le URLanna deisce a oscailt ar an ardán seo.';

  @override
  String get openingYourSavedDesktop => 'Ag oscailt do dheasc sábháilte.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Ag oscailt do dheasc sábháilte. Tógann tosaithe gnáth níos lú ná 10 soicind.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Rún breise roghnach má chosnaíonn tú an gréasán isteach.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Sárú roghnach mura leor an URL cua gréasáin.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Rún roghnach chun imeachtaí Chat isteach a fhíorú.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Rún roghnach chun imeachtaí ag teacht isteach a fhíorú.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Rún roghnach chun imeachtaí iMessage isteach a fhíorú.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Rún roghnach chun imeachtaí LÍNE ag teacht isteach a fhíorú.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Rún roghnach chun imeachtaí Mattermost ag teacht isteach a fhíorú.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Rún roghnach chun imeachtaí Foirne isteach a fhíorú.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Roghnach. Tá a phearsantacht féin ag an ngníomhaire cheana féin. Tá aon rud a chuireann tú leis faoi ton cisealta ar a bharr, mar sin ní gá duit ceann a shainiú.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Roghnach. Nuair a bheidh sé socraithe, úsáidtear é in ionad an URL.';

  @override
  String get orAnswerInYourOwnWords => 'Nó freagair i d’fhocail féin';

  @override
  String get orBuildYourOwnTask => 'Nó tóg do thasc féin';

  @override
  String get orContinueWith => 'nó ar aghaidh le';

  @override
  String get orFiles => 'nó comhaid.';

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
  String get originNotAllowed => 'ní cheadaítear bunús';

  @override
  String get outgoingMessage => 'Teachtaireacht amach';

  @override
  String get outgoingWebhookUrl => 'URL cuaille gréasáin amach';

  @override
  String get outlookEmailReceived => 'Ríomhphost Outlook faighte';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Forscríobh nótaí iompair ón allmhairiú.';

  @override
  String get ownModel => 'samhail féin';

  @override
  String get packageName => 'Ainm pacáiste';

  @override
  String get pairWithQrCode => 'Péireáil le cód QR';

  @override
  String get password => 'Pasfhocal';

  @override
  String get password2faAndActiveSessions =>
      'Pasfhocal, 2FA, agus seisiúin ghníomhacha';

  @override
  String get passwordCreated => 'Pasfhocal cruthaithe.';

  @override
  String get passwordIsTooWeak => 'pasfhocal ró-lag';

  @override
  String get passwordMin8 => 'pasfhocal min 8';

  @override
  String get passwordOrApiKey => 'Pasfhocal nó eochair API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Neart pasfhocal: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Ní hionann pasfhocail.';

  @override
  String get pasteAKey => 'Greamaigh eochair.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Greamaigh eochair nua chun $arg1 a athsholáthar';
  }

  @override
  String get pasteTheKey => 'Greamaigh an eochair';

  @override
  String get pasteYourAccountToken => 'Greamaigh do chomhartha cuntais';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Greamaigh d\'eochair API $arg1 thíos. Tá sé ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'Caithfidh Conair fanacht taobh istigh de NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'Caithfidh an cosán fanacht taobh istigh den fhillteán spás oibre.';

  @override
  String get pauseLiveUpdates => 'Cuir nuashonruithe beo ar sos';

  @override
  String get pauseTaskLoop => 'Cuir lúb tascanna ar sos';

  @override
  String get paused => 'Sos';

  @override
  String peakArg1(Object? arg1) {
    return 'buaic $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Daoine i gcomhráite príobháideacha';

  @override
  String get perAccountRateLimits =>
      'Teorainneacha ráta in aghaidh an chuntais';

  @override
  String get perCategoryPermissions => 'Ceadanna de réir catagóire';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Beartais cheada in aghaidh an uirlis, geataí formheasa, agus leithlisiú próisis le haghaidh forghníomhú sliogáin.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Cead ag teastáil: $arg1';
  }

  @override
  String get permissionsNeeded => 'Ceadanna ag teastáil';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Ceadanna. Ní féidir le duine ar bith é sin a athrú.';

  @override
  String get personOrChat => 'Duine nó comhrá';

  @override
  String get personaBehaviorNotes =>
      'Nótaí ar iompar pearsantacht saor in aisce,';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Comhartha rochtana pearsanta don bot Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Bealaí pearsanta agus dromchlaí tacaíochta díreacha.';

  @override
  String get personalSelfChat => 'Féin-chomhrá pearsanta';

  @override
  String get phoneNumber => 'Uimhir theileafóin';

  @override
  String get pickARunFromTheList =>
      'Roghnaigh rith ón liosta chun a céimeanna a fheiceáil.';

  @override
  String get pickARunFromTheList2 =>
      'Roghnaigh rith ón liosta ar chlé chun a shreabhadh a iniúchadh.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Roghnaigh ó chomhráite $arg1 le déanaí, nó cuir duine nó grúpa leat féin.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Roghnaigh conas a úsáideann $arg1 an cuntas seo.';
  }

  @override
  String get pickOneToFillInThe =>
      'Roghnaigh ceann amháin chun an tasc a líonadh. Is féidir leat gach rud a tweak ina dhiaidh sin.';

  @override
  String get picksUpWhereYouLeftOff => 'Piocann suas an áit a d\'fhág tú';

  @override
  String get plan => 'Plean';

  @override
  String get planning => 'Pleanáil';

  @override
  String get platform => 'Ardán';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Ardán $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Roghnaigh sceideal le do thoil.';

  @override
  String get pleaseEnterAFilename => 'Cuir isteach ainm comhaid.';

  @override
  String get pleaseEnterAKey => 'Cuir isteach eochair.';

  @override
  String get pleaseEnterAPrompt => 'Cuir isteach leid.';

  @override
  String get pleaseEnterATaskName => 'Cuir isteach ainm taisc le do thoil.';

  @override
  String get pleaseEnterTheMemoryContent => 'Cuir isteach an t-ábhar cuimhne.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Cuir isteach cén uair ba cheart don tasc a bheith ar siúl.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Roghnaigh cuntas nó cuir isteach aitheantas ceangail bailí.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Pointe NeoAgent ag aon Chríochnú Comhrá OpenAI-comhoiriúnach ';

  @override
  String get pointTheCameraAtTheCode =>
      'Pointe an ceamara ag an gcód a thaispeántar ar an ngléas sínithe amach. Fanann faomhadh ar an bhfón seo.';

  @override
  String get port => 'Port';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'port node_env poiblí url muinín seachfhreastalaí imscaradh fianáin slán';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Uathoibriú préimhe le truicear sceidil agus comhtháthú.';

  @override
  String get prepareQrCode => 'Ullmhaigh cód QR';

  @override
  String get preparingNeoagent => 'NeoAgent á ullmhú…';

  @override
  String get preparingNeoagent2 => 'Ullmhú NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Brúigh agus coinnigh le haghaidh gabháil tapa';

  @override
  String get pressKeysIsNotSupportedOn =>
      'ní thacaítear leis na heochracha brúigh ar an ardán seo.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Brúite $arg1';
  }

  @override
  String get priceUnknown => 'Praghas anaithnid';

  @override
  String get primaryDisplay => 'Taispeáint Príomhúil';

  @override
  String get privateChat => 'Comhrá príobháideach';

  @override
  String get privateChats => 'Comhráite príobháideacha';

  @override
  String get privateChats2 => 'comhráite príobháideacha';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Comhráite príobháideacha: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Comhráite príobháideacha $arg1 · grúpaí $arg2';
  }

  @override
  String get privateChatsOnly => 'Comhráite príobháideacha amháin';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'ní cheadaítear seoltaí líonra príobháideacha.';

  @override
  String get profileEmailAndPersonalData =>
      'Próifíl, ríomhphost, agus sonraí pearsanta';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Leid sula bhfanann NeoAgent cónaitheach i dtráidire an chórais.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Taisce leid: comharthaí i dtaisce $arg1 ';
  }

  @override
  String get promptCopied => 'Pras a chóipeáil.';

  @override
  String get promptOrSchedule => 'leid nó sceideal.';

  @override
  String get promptToPasteIntoAnotherAi => 'Leid a ghreamú isteach AI eile';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'Níorbh fhéidir nascadh an tsoláthraí a thosú.';

  @override
  String get providerSignInCouldNotBe =>
      'Níorbh fhéidir síniú isteach an tsoláthraí a thosú.';

  @override
  String get providers => 'Soláthraithe';

  @override
  String get providersEachAccountCanStillPick =>
      'Soláthraithe; is féidir le gach cuntas a shamhail féin a phiocadh fós sna Socruithe. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Is féidir soláthraithe, comhtháthú, gutha, agus cumais roghnacha a chomhlánú ó Socruithe am ar bith.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Snáitheanna iarratais a eisiúint agus a tharraingt go poiblí, freagartha do dhaoine ceadaithe amháin.';

  @override
  String get publicUrl => 'URL poiblí';

  @override
  String get publicUrlAndAllowedOrigins => 'URL poiblí agus bunús ceadaithe';

  @override
  String get publicUrlOverride => 'Sárú URL poiblí';

  @override
  String get pullsTogetherTheDayAhead =>
      'Tarraingíonn sé le chéile an lá amach romhainn';

  @override
  String get pushToTalk => 'Brúigh chun cainte';

  @override
  String get qrBasedPhoneLinking => 'Nasc gutháin bunaithe ar QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Cuireadh logáil isteach QR i gcrích, ach níorbh fhéidir le NeoAgent an seisiún a choinneáil. Bain triail eile as.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'Níorbh fhéidir logáil isteach QR a thosú.';

  @override
  String get qrLoginRequestHasExpired =>
      'Tá iarratas logáil isteach qr imithe in éag';

  @override
  String get qrLoginRequestWasNotFound =>
      'Níor aimsíodh iarratas logáil isteach qr';

  @override
  String get qrPairing => 'Péireáil QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'ritheann ceisteanna; diúltaítear d’aon rud a scríobhann.';

  @override
  String get queryFilter => 'Iarratas / Scagaire';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Ciúáilte mar stiúrtha don rith reatha: $arg1';
  }

  @override
  String get quickstart => 'Mear-thosú';

  @override
  String get quit => 'Scoir';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'báisteach_tús, gaoth_alert';

  @override
  String get ranAScriptInThePage => 'Rith script sa leathanach';

  @override
  String ranArg1(Object? arg1) {
    return 'Rith $arg1';
  }

  @override
  String get rateLimits => 'Teorainneacha rátaí';

  @override
  String get readAnArtifact => 'Léigh déantán';

  @override
  String get readAndEditFilesInsideYour =>
      'Léigh agus cuir in eagar comhaid taobh istigh d\'fhillteán NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Léigh $arg1';
  }

  @override
  String get readError => 'Earráid léite';

  @override
  String get readFiles => 'Léigh comhaid';

  @override
  String get readOnly => 'Léigh Amháin';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Léigh an fillteán agus déan achoimre ar an gcruach, ar na pointí iontrála agus conas é a rith.';

  @override
  String get readThePage => 'Léigh an leathanach';

  @override
  String get readTheUiTree => 'Léigh an crann Chomhéadain';

  @override
  String get readWrite => 'Léigh / Scríobh';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Léann céimeanna, ráta croí, codlata, aclaíocht agus meáchan.';

  @override
  String get ready => 'Réidh';

  @override
  String get readyForFirstTimeSetup => 'Réidh le socrú don chéad uair';

  @override
  String get readyToConnect => 'Réidh le nascadh';

  @override
  String get recentChannelActivity => 'Gníomhaíocht Cainéal le Déanaí';

  @override
  String get recentChats => 'Comhráite le déanaí';

  @override
  String get recentDecisions => 'Cinntí le déanaí';

  @override
  String get recentFailedRuns => 'Ritheann teipthe le déanaí';

  @override
  String get recentGroupDecisions => 'Cinntí grúpa le déanaí';

  @override
  String get recentRuns => 'Ritheann le déanaí';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Tógann ritheanna le déanaí thart ar $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Aschur freastalaí le déanaí, is nua ar dtús.';

  @override
  String get recentUsage4Hours => 'Úsáid le Déanaí (4 huaire)';

  @override
  String get recents => 'Le déanaí';

  @override
  String get recipientField => 'Réimse faighteoir';

  @override
  String get reconnectOrFinishSetup => 'Athcheangail nó críochnaigh an socrú';

  @override
  String get reconnectingThisDevice => 'An gléas seo á athcheangal…';

  @override
  String get recurring => 'Athfhillteach';

  @override
  String get redirectUri => 'Atreorú URI';

  @override
  String get redoOnboarding => 'Athdhéan an bordáil';

  @override
  String get refresh => 'Athnuaigh';

  @override
  String get refreshCode => 'Cód a athnuachan';

  @override
  String get refreshNow => 'Athnuaigh anois';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Athnuaigh an scáileán Android chun triail eile a bhaint as.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Diúltaigh seoladh mura n-uasghrádaíonn an nasc go TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'beag beann ar na socruithe in aghaidh na catagóire thíos.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Cláraigh $arg1 le haghaidh sreabhadh an toghairm chúntóra.';
  }

  @override
  String get registrationIsClosed => 'tá an clárú dúnta';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'ceadaíonn cuntais nua a chlárú clárú';

  @override
  String get rejectInvalidTlsCertificates =>
      'Diúltaigh teastais TLS neamhbhailí';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'scaoileadh agus atosú. Athnascann aipeanna nasctha nuair a bhíonn sé ar ais.';

  @override
  String get releaseChannel => 'Cainéal scaoileadh';

  @override
  String get releaseCommitBranchNode => 'nód brainse tiomnaithe a scaoileadh';

  @override
  String get releaseWhenYouAreDone =>
      'Scaoileadh nuair a bhíonn tú críochnaithe.';

  @override
  String get reloadNow => 'Athlódáil anois';

  @override
  String get rememberThisChoice => 'Cuimhnigh an rogha seo';

  @override
  String get remove => 'Bain';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Bain \"$arg1\" agus a céimeanna taifeadta den stair rith?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Bain \"$arg1\" den chroí-chuimhne.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Bain eochair $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'bain úsáideoir gdpr scriosadh';

  @override
  String get removeSmtpPassword => 'Bain pasfhocal SMTP';

  @override
  String get removeTheSmtpPassword =>
      'An bhfuil fonn ort an pasfhocal SMTP a bhaint?';

  @override
  String get rename => 'Athainmnigh';

  @override
  String get renameSecurityKey => 'Athainmnigh an eochair shlándála';

  @override
  String get renameSession => 'Athainmnigh seisiún';

  @override
  String get repairAndRetry => 'Deisiúchán agus triail eile';

  @override
  String get repairDesktop => 'Deasc a dheisiú';

  @override
  String get repeat => 'Déan arís';

  @override
  String get repliesWhenTagged => 'Freagraí nuair a chlibtear é';

  @override
  String get replyToAddress => 'Seoladh Freagra-Chun';

  @override
  String replyToArg1(Object? arg1) {
    return 'Freagair $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'Ní mór don stór a bheith san fhormáid úinéir/stór.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Déan an fabht a bhfuil cur síos agam air a atáirgeadh, aimsigh an bhunchúis agus réitigh le tástáil aischéimnithí é.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'Theip ar an iarratas le http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Theip ar an iarratas le HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Iarr ceadanna';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'Theip ar an iarratas chuig $arg1 sular fhreagair an t-inneall.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Iarrtha $arg1';
  }

  @override
  String get requireStarttls => 'A cheangal ar STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Ag teastáil taobh thiar de HTTPS nó seachfhreastalaí TLS. Baineann sé tar éis freastalaí ';

  @override
  String get requiredExampleBerlinDe => 'Ag teastáil. Sampla: Beirlín, DE';

  @override
  String get requiredFormatOwnerRepo => 'Ag teastáil. Formáid: úinéir/repo';

  @override
  String get reserveAssistantHotkey => 'Hotkey cúntóir cúltaca';

  @override
  String get reset => 'Athshocraigh';

  @override
  String get resetPassword => 'Athshocraigh pasfhocal';

  @override
  String get resetView => 'Athshocraigh amharc';

  @override
  String get responsibilities => 'Freagrachtaí';

  @override
  String get restart => 'Atosaigh';

  @override
  String get restartToFinishTheUpdate =>
      ' Atosaigh chun an nuashonrú a chríochnú.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'An t-am rite NeoAgent roimhe seo a athchóiriú';

  @override
  String get restrictDelegationTargets =>
      'Srian a chur ar spriocanna tarmligin';

  @override
  String get result => 'Toradh';

  @override
  String get resultDelivery => 'Seachadadh Torthaí';

  @override
  String get resultOneClickAddsOneYou =>
      'toradh. Cuireann cliceáil amháin leis; is féidir leat é a chur in eagar níos déanaí.';

  @override
  String get results => 'Torthaí';

  @override
  String get retry => 'Bain triail eile as';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'In-athúsáidte · úsáidte $arg1×';
  }

  @override
  String get reviewUncommittedChanges =>
      'Athbhreithnigh athruithe neamhthiomanta';

  @override
  String get revoke => 'chúlghairm';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Cúlghair admin le `neoagent admin a chúlghairm $arg1` ar dtús';
  }

  @override
  String get revokeThisLink => 'An bhfuil fonn ort an nasc seo a chúlghairm?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Fuinneog bhaisc an tseomra: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Rothlaigh chun leanúint ar aghaidh';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'sraitheanna. Cuir teorainn leis nó clásal WHERE níos caol le feiceáil ';

  @override
  String get rule => 'Riail';

  @override
  String get run => 'Rith';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Rith orduithe treallach ar do mheaisín nó ar VM.';

  @override
  String get runAt => 'Rith Ag';

  @override
  String get runCompleted => 'Rith críochnaithe';

  @override
  String get runFailed => 'Theip ar an rith';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Rith git diff, athbhreithnigh na hathruithe neamhthiomanta maidir le fabhtanna agus saincheisteanna stíle, agus déan achoimre ar a bhfuil aimsithe agat.';

  @override
  String get runNotFound => 'Rith gan aimsiú';

  @override
  String get runNow => 'Rith anois';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Rith ar theachtaireachtaí pearsanta WhatsApp isteach.';

  @override
  String get runQuery => 'Rith ceist';

  @override
  String get runShellCommandsOrInstallApps =>
      'Rith orduithe bhlaosc nó suiteáil apps ar do ghléas Android.';

  @override
  String get runStarted => 'Thosaigh rith';

  @override
  String get runStatus => 'Stádas rith';

  @override
  String get runStopped => 'Stopadh an rith';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Rith orduithe teirminéil agus oscail aipeanna nó leathanaigh ghréasáin.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Rith an freastalaí seo: cuntais, nuashonruithe, soláthraithe, cumraíocht ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Rith nuair a thagann teachtaireacht Gmail atá ag teacht leis.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Rith nuair a thagann ríomhphost Outlook meaitseála.';

  @override
  String get runWhenANewIssueMatching =>
      'Rith nuair a osclaítear ceist nua a mheaitseálann do scagairí i stór.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Rith nuair a chruthaítear cuimhne nua NeoRecall a thagann le do chuid scagairí.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Rith nuair a thagann fógra chuig do ghléas.';

  @override
  String get runWhenASlackMessageMatches =>
      'Rith nuair a mheaitseálann teachtaireacht Slack an raon feidhme roghnaithe.';

  @override
  String get runWhenATeamsChatMessage =>
      'Rith nuair a mheaitseálann teachtaireacht chomhrá Foirne an scóip roghnaithe.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Rith nuair a thuartar imeachtaí aimsire cumraithe do shuíomh.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'rith. Cé go bhfuil aon mhúnla múchta, samhlacha a chuireann soláthraithe leis ';

  @override
  String get running => 'Ar siúl';

  @override
  String runningArg1(Object? arg1) {
    return 'Rith $arg1';
  }

  @override
  String get runningTask => 'Tasc rith';

  @override
  String get runningTool => 'Uirlis rith';

  @override
  String get runs => 'Ritheanna';

  @override
  String get runsEveryDayAtTheSelected =>
      'Ritheann sé gach lá ag an am roghnaithe.';

  @override
  String get runsFourTimesPerHour =>
      'Ritheann ceithre huaire in aghaidh na huaire.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— ritheann, teachtaireachtaí, cuimhní cinn, comhtháthú, comhaid agus ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'ritheann, teachtaireachtaí, cuimhní cinn, comhtháthú, comhaid agus seisiúin. ';

  @override
  String get runsMondayThroughFriday => 'Ritheann Luan go hAoine.';

  @override
  String get runsOnSelectedWeekdays =>
      'Ritheann sé ar laethanta seachtaine roghnaithe.';

  @override
  String get runsOncePerHour => 'Ritheann uair amháin in aghaidh na huaire.';

  @override
  String get runsOncePerMonthOnThe =>
      'Ritheann sé uair sa mhí ar an lá roghnaithe.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Ritheann sé ach amháin nuair a bhrúnn tú Rith Anois.';

  @override
  String get runsPerDay => 'Ritheann in aghaidh an lae';

  @override
  String get runsPerDay30Days => 'Ritheann sé in aghaidh an lae (30 lá)';

  @override
  String get runsThatCompleted => 'Ritheann a chríochnaigh';

  @override
  String get runsThisWeek => 'Ritheann an tseachtain seo';

  @override
  String get runsToday => 'Ritheann inniu';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Tá ritheanna, uirlisí, cuimhne, sceidealú, scileanna agus MCP ar fáil anseo.';

  @override
  String get runsTwicePerHour => 'Ritheann dhá uair in aghaidh na huaire.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Titfidh ritheanna ar ais go dtí an eochair fhreastalaí roinnte do $arg1, má tá ceann cumraithe. Ní féidir é seo a chealú.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Am rite $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Am rite: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Socruithe ama rite a thosaigh an freastalaí seo. Cuir in eagar iad faoi ';

  @override
  String get runtimeSetupRequired => 'Tá socrú ama rite riachtanach';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'Ní mór gur 32 beart é an eochair phoiblí sínithe ama rite.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Sábháil';

  @override
  String get saveATrelloApiKeyFor =>
      'Sábháil eochair Trello API don ghníomhaire seo, ansin ceangail cuntas Trello amháin go slán. Stóráiltear an comhartha cuntais ar an bhfreastalaí agus úsáidtear é don ghníomhaire seo amháin.';

  @override
  String get saveAccount => 'Sábháil cuntas';

  @override
  String get saveChanges => 'Sábháil athruithe';

  @override
  String get saveCloudComputerSettings => 'Sábháil socruithe ríomhaire scamall';

  @override
  String get saveConnect => 'Sábháil & Ceangail';

  @override
  String get saveDefaults => 'Sábháil réamhshocruithe';

  @override
  String get saveDiagnosticReport => 'Sábháil an tuairisc dhiagnóiseach';

  @override
  String get saveEmail => 'Sábháil ríomhphost';

  @override
  String get saveEmailSettings => 'Sábháil socruithe ríomhphoist';

  @override
  String get saveGeneralSettings => 'Sábháil socruithe ginearálta';

  @override
  String get saveName => 'Sábháil ainm';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Sábháil diagnóisic socraithe NeoAgent';

  @override
  String get saveOnly => 'Sábháil Amháin';

  @override
  String get saveSetup => 'Sábháil Socrú';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Sábháil na cóid athshlánaithe seo anois. Ní thaispeánfar arís iad.';

  @override
  String get savedDeliveryDestination => 'Ceann scríbe seachadta sábháilte';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Teorainneacha ráta sábháilte do @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Scan logáil isteach NeoAgent QR';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Scan QR atá á phéireáil le NeoAgent ó ghléas eile agus ceadaigh é ón seisiún tosaitheoir seo.';

  @override
  String get scanLoginQr => 'Scan logáil isteach QR';

  @override
  String get scanPairingQr => 'Scan an péireáil QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Scan iarratais logáil isteach QR ó ghléasanna sínithe amach agus ceadaigh iad ón seisiún soghluaiste fíordheimhnithe seo.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Scan chun $arg1 a chríochnú';
  }

  @override
  String get scanWithNeoagentOnYourPhone => 'Scan le NeoAgent ar do ghuthán';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Scanann sé ríomhphost nua agus ní chuireann sé pingin ort ach nuair a bhíonn tábhacht le rud éigin.';

  @override
  String get schedule => 'Sceideal';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'am sceidealta. Nuair a thomhaistear na ritheanna cuirfear tús leis níos luaithe.';

  @override
  String get screen => 'Scáileán';

  @override
  String get screenAction => 'gníomh scáileáin';

  @override
  String get scrollIsNotSupportedOnThis =>
      'ní thacaítear le scrollbharra ar an ardán seo.';

  @override
  String get scrollToBottom => 'Scrollaigh go bun';

  @override
  String get search => 'Cuardach';

  @override
  String get search2 => 'Cuardaigh…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Cuardaigh socruithe riaracháin (m.sh. SMTP, Olama, logaí)';

  @override
  String get searchAgain => 'Cuardaigh arís';

  @override
  String get searchByUsernameOrEmail =>
      'Cuardaigh de réir ainm úsáideora nó ríomhphost';

  @override
  String get searchChannels => 'Cuardaigh cainéil';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Cuardaigh cainéil teachtaireachtaí a aimsíodh, teagmhálaithe, grúpaí agus comhráite le déanaí.';

  @override
  String get searchGroups => 'Cuardaigh grúpaí';

  @override
  String get searchMemory => 'Cuardach cuimhne';

  @override
  String get searchModelsOrProviders => 'Cuardaigh samhlacha nó soláthraithe';

  @override
  String get searchModelsOrProviders2 => 'Cuardaigh samhlacha nó soláthraithe…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Cuardaigh daoine agus grúpaí le déanaí';

  @override
  String get searchSessions => 'Seisiúin chuardaigh';

  @override
  String get searchSettings => 'Socruithe cuardaigh';

  @override
  String get searchTitleModelTriggerRunId =>
      'Teideal cuardaigh, múnla, truicear, ID rith';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Uirlisí cuardaigh, comhtháthú, agus scileanna';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Cuardaíodh cód le haghaidh \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Cuardaíodh comhaid le haghaidh \"$arg1\"';
  }

  @override
  String get secretField => 'Réimse rúnda';

  @override
  String get secureCookies => 'Fianáin slán';

  @override
  String get security => 'Slándáil';

  @override
  String get securityKey => 'Eochair shlándála';

  @override
  String get securityKeyPromptWasDismissed =>
      'Briseadh leid na heochrach slándála.';

  @override
  String get securityKeySignInCompletedBut =>
      'Críochnaíodh síniú isteach na heochrach slándála, ach níorbh fhéidir le NeoAgent seisiún an bhrabhsálaí a choinneáil. Sínigh isteach arís le do thoil.';

  @override
  String get securityKeySignInCouldNot =>
      'Níorbh fhéidir síniú isteach na heochrach slándála a thosú.';

  @override
  String get securityKeys => 'Eochracha slándála';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Níl eochracha slándála ar fáil ach san aip gréasáin NeoAgent.';

  @override
  String get seeAll => 'Féach ar fad';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Féach cén freastalaí NeoAgent a úsáideann an fhuinneog seo, agus rith an t-inneall ar an ríomhaire seo.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'féach ar d\'ainm úsáideora agus na socruithe seo, ná do chomhráite, cuimhní cinn riamh ';

  @override
  String get selectARun => 'Roghnaigh rith';

  @override
  String get selectASessionToSeeIts =>
      'Roghnaigh seisiún chun a ríomhaire, comhaid agus athruithe a fheiceáil.';

  @override
  String get selectAll => 'Roghnaigh go léir';

  @override
  String get selectAll2 => 'Roghnaigh Uile';

  @override
  String selectArg1(Object? arg1) {
    return 'Roghnaigh $arg1';
  }

  @override
  String get selectTrigger => 'Roghnaigh Truicear';

  @override
  String get send => 'Seol (⌘↵)';

  @override
  String get send2 => 'Seol';

  @override
  String get sendATaskFromChatAnd =>
      'Seol tasc ón gcomhrá agus taispeánfar a stair fhorghníomhaithe anseo.';

  @override
  String get sendItToATeammateWith =>
      'seol chuig comhghleacaí le cuntas ar an bhfreastalaí seo é.';

  @override
  String get sendLink => 'Seol nasc';

  @override
  String get sendPath => 'Seol cosán';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Seol iarratais POST / PUT / DELETE chuig APInna seachtracha.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Seol an nasc seo chuig an duine amháin a bhfuil sé i gceist dó. Taispeántar uair amháin é; ';

  @override
  String get senderAddress => 'Seoladh an tseoltóra';

  @override
  String get senderFilterOptional => 'Scagaire Seoltóra (roghnach)';

  @override
  String get sentSharedAttachments => 'Ceangaltáin roinnte seolta.';

  @override
  String get separateAccount => 'Cuntas ar leith';

  @override
  String get server => 'Freastalaí';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Réamhshocrú an fhreastalaí ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Réamhshocruithe an fhreastalaí le haghaidh glaonna gutha in-app. Ritheann glaonna ar chlár beo ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'freastalaí féin: cuntais, soláthraithe agus cumraíocht.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Freastalaí, leasainm, cainéal, agus TLS roghnach';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'Cóipeáil earráidí rabhaidh consól aschur freastalaí';

  @override
  String get serverProviderCredentials => 'Dintiúir soláthraí freastalaí';

  @override
  String get serverUrl => 'URL an fhreastalaí';

  @override
  String get serverUsageLimitsDonTApply =>
      'Ní bhaineann teorainneacha úsáide freastalaí le samhlacha a ritheann ar d\'eochair féin.';

  @override
  String get serviceEmail => 'Ríomhphost seirbhíse';

  @override
  String get serviceEmailIsNotConfigured =>
      'níl ríomhphost seirbhíse cumraithe';

  @override
  String get serviceEmailSmtp => 'Ríomhphost seirbhíse (SMTP)';

  @override
  String get sessionActions => 'Gníomhartha seisiúin';

  @override
  String get sessions => 'Seisiúin';

  @override
  String get sessions2 => 'SEISIN';

  @override
  String get sessionsArePinnedToAFolder =>
      'Pionnáiltear na seisiúin ar fhillteán agus ar ríomhaire. Tosaigh ceann le pleanáil, tógáil, tástáil agus seoladh as seo.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'seisiúin (GDPR Art. 17). Ní féidir cuntais riaracháin a scriosadh ';

  @override
  String get sessionsLogoutRevokeForce =>
      'déanann seisiúin logáil amach fórsa a chúlghairm';

  @override
  String get setBlockAskAllowPerTool =>
      'Socraigh bloc / iarr / cead de réir catagóire uirlisí, nó roghnaigh modh domhanda.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Cumraigh NeoAgent ar an ríomhaire seo';

  @override
  String get setUpOrConnectNeoagent => 'Socrú nó ceangal NeoAgent';

  @override
  String get setUrl => 'Socraigh URL';

  @override
  String get settings => 'Socruithe';

  @override
  String get settingsAndCannotBeUndone =>
      'socruithe agus ní féidir iad a chealú.';

  @override
  String get settingsArea => 'Réimse socruithe';

  @override
  String get settingsAreas => 'Réimsí socruithe';

  @override
  String get setup => 'Socrú';

  @override
  String get setupDetails => 'Sonraí socraithe';

  @override
  String get setupRequired => 'Socrú ag teastáil';

  @override
  String get setupWasCancelled => 'Cuireadh an socrú ar ceal.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Ceangaltáin roinnte ón gcliant NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Roinnte ó aip eile';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Tá eochracha soláthraithe comhroinnte cumraithe ar an bhfreastalaí. Chun d\'eochair API féin nó críochphointe saincheaptha a úsáid ina ionad sin, téigh go dtí Advanced → Beir leat d\'eochair féin.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Roinnte le comhrá NeoAgent agus a chuimhne.';

  @override
  String get shellCommands => 'Orduithe Shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Taispeáin gach $arg1';
  }

  @override
  String get showEarlier => 'Taispeáin níos luaithe';

  @override
  String get showEveryStep => 'Taispeáin gach céim';

  @override
  String get showTools => 'Taispeáin uirlisí';

  @override
  String get showWorkbenchJ => 'Taispeáin binse oibre (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Ag taispeáint an chéad $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Taispeántar sa bharra taoibh. Fág bán chun d\'ainm úsáideora a úsáid.';

  @override
  String get signIn => 'Sínigh isteach';

  @override
  String get signInCompletedButNeoagentCould =>
      'Síniú isteach críochnaithe, ach níorbh fhéidir le NeoAgent seisiún an bhrabhsálaí a choinneáil. Sínigh isteach arís le do thoil. Má leanann sé seo ar aghaidh, seiceáil socruithe fianán an tseisiúin backend.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'Síniú isteach críochnaithe, ach níorbh fhéidir le NeoAgent seisiún an bhrabhsálaí a choinneáil. Sínigh isteach arís le do thoil. Má leanann sé seo ar aghaidh, is dócha nach gcoimeádtar fianán an tseisiúin backend.';

  @override
  String get signInToThisNeoagentServer =>
      'Sínigh isteach ar an bhfreastalaí NeoAgent seo sula scanadh tú cód QR péireála.';

  @override
  String get signInWithAHardwareKey =>
      'Sínigh isteach le heochair chrua-earraí nó pasfhocal in ionad do phasfhocal. ';

  @override
  String get signInWithASecurityKey => 'Sínigh isteach le eochair shlándála';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Sínigh isteach le $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Ceadaigh NeoAgent i do chuntas $arg1. Níl eochair le cóipeáil.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Ag fanacht le $arg1. Críochnaigh i do bhrabhsálaí.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Greamaigh an cód $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Tar éis duit NeoAgent a cheadú, léirigh $arg1 cód aon-uaire. Greamaigh anseo é.';
  }

  @override
  String get signInCode => 'Cód síniú isteach';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Sínithe isteach le $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Theip ar an síniú isteach: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Sínigh isteach leis an ríomhphost céanna agus an máistirfhocal faire céanna a úsáideann tú in Bitwarden. Ní úsáidtear an máistirfhocal faire agus an cód dhá chéim ach amháin le haghaidh síniú isteach agus ní dhéantar iad a stóráil ná a sheoladh chuig an AI.';

  @override
  String get signOut => 'Sínigh amach';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Sínigh amach @$arg1 i ngach áit?';
  }

  @override
  String get signOutEverywhere => 'Sínigh amach i ngach áit';

  @override
  String get signalCliRestApiBridge => 'droichead comhartha-cli REST API';

  @override
  String get signalCliServerUrl => 'URL freastalaí comhartha-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Sínithe @$arg1 as gach seisiún.';
  }

  @override
  String get signedInDevices => 'Gléasanna sínithe isteach';

  @override
  String get signedInWithin24Hours =>
      'Sínithe isteach laistigh de 24 uair an chloig';

  @override
  String get signingSecret => 'Rún sínithe';

  @override
  String sinceArg1(Object? arg1) {
    return 'Ós rud é $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'ó $arg1';
  }

  @override
  String get singleMessage => 'Teachtaireacht amháin';

  @override
  String get singleUse => 'Úsáid aonair';

  @override
  String get skill => 'Scil';

  @override
  String get skillChanges => 'Athruithe Scil';

  @override
  String get skillContent => 'Ábhar Scil';

  @override
  String get skills => 'Scileanna';

  @override
  String get skip => 'Scipeáil';

  @override
  String get skipForNow => 'Scipeáil go fóill';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Léim an tasc seo sula dtugann sé glaoch ar an tsamhail.';

  @override
  String get slackMessageReceived => 'Fuarthas Teachtaireacht Dhílis';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Codladh seisiúin $arg1';
  }

  @override
  String get smartSelector => 'roghnóir cliste';

  @override
  String get smartSelector2 => 'Roghnóir Cliste';

  @override
  String get smartSelectorPool => 'Snámha Roghnóir Cliste';

  @override
  String get smtpHost => 'óstach SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'pasfhocal seoltóir ríomhphoist smtp tls athshocrú fógraí dearbhaithe';

  @override
  String get smtpPassword => 'Pasfhocal SMTP';

  @override
  String get smtpPort => 'Port SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'Caithfidh an calafort SMTP a bheith ina shlánuimhir ó 1 go 65535.';

  @override
  String get smtpUsername => 'Ainm úsáideora SMTP';

  @override
  String get soTheRunStartsThatMuch =>
      'mar sin tosaíonn an rith sin i bhfad níos luaithe.';

  @override
  String get socialBehaviorOff => 'Iompar sóisialta as';

  @override
  String get socialIntelligence => 'éirim shóisialta';

  @override
  String get socialIntelligence2 => 'Intleacht shóisialta';

  @override
  String get socialObservability => 'Breathnú sóisialta';

  @override
  String get socialReach => 'teacht sóisialta';

  @override
  String get socialReach2 => 'Teacht sóisialta';

  @override
  String get socialReach3 => 'Teacht Sóisialta';

  @override
  String get socialReachUpdated => 'Social Reach nuashonraithe.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Is féidir le gníomhairí foinsí sóisialta léamh go díreach, lena n-áirítear fothaí, stórtha, Reddit, X, físeáin, agus sonraí margaidh le tacaíocht fianán.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Chuaigh rud éigin mícheart. Bain triail eile as.';

  @override
  String get source => 'Foinse';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Aitheantas spáis nó comhrá a úsáidtear nuair a thosaíonn an gníomhaire seo comhrá.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Tacaíocht chuaille gréasáin spáis agus aisghlao aip';

  @override
  String get speaking => 'Ag labhairt';

  @override
  String get speechToSpeechModelUsingThe =>
      'múnla cainte-go-hurlabhra ag baint úsáide as an eochair OpenAI nó Google faoi ';

  @override
  String get speechToText => 'Óráid go téacs';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'Trascríobhann urlabhra go téacs nótaí gutha agus deachtú. Úsáideann Auto OpenAI, Gemini nó Deepgram, cibé acu a bhfuil eochair API aige. Is é an tsamhail freagra gutha an tsamhail comhrá a fhreagraíonn nótaí gutha.';

  @override
  String get sqlConsole => 'Consól SQL';

  @override
  String get stable => 'Cobhsaí';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Insealbhaíonn Cobhsaí an t-eisiúint inneall is déanaí foilsithe.';

  @override
  String get stackTrace => 'rian cruachta';

  @override
  String get standard => 'Caighdeán';

  @override
  String get standardView => 'Amharc caighdeánach';

  @override
  String get start => 'Tosaigh';

  @override
  String get startASessionToPlanOr =>
      'Cuir tús le seisiún a phleanáil nó a thógáil le NeoAgent.';

  @override
  String get startAndroid => 'Tosaigh Android';

  @override
  String get startComputer => 'Tosaigh ríomhaire';

  @override
  String get startFullSetup => 'Tosaigh socrú iomlán';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Tosaigh socrú';

  @override
  String get startTalking => 'Tosaigh ag caint';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Tosaigh an fón Android ar dtús, ansin titim comhad .apk nó .apks anseo.';

  @override
  String get startTheServerLaterFromThe =>
      'Tosaigh an freastalaí níos déanaí ón liosta a luaithe a shábhálfar an cumraíocht.';

  @override
  String get startWithARecommendedTask => 'Tosaigh le tasc molta';

  @override
  String get startingAndroid => 'Tosaigh Android';

  @override
  String get startingYourComputer => 'Tosaigh do ríomhaire';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Tosaíonn le xoxb-. Ó do dhintiúir app Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'startTelecomCallRouting Earráid: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'Ritheann stats comharthaí úsáideoirí cairteacha ráta ratha';

  @override
  String get status => 'Stádas';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'bunachar sonraí stádais soláthraithe vm runtime';

  @override
  String get statusIsNotLoadedYet => 'Níl an stádas luchtaithe fós.';

  @override
  String get stayManagedByYou => 'fanacht á bhainistiú agat.';

  @override
  String get stayOnTheCall => 'Fan ar an nglao';

  @override
  String get stayedQuiet => 'D\'fhan ciúin';

  @override
  String get steering => 'STIÚRADH';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'CÉIM $arg1 OF $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Céimeanna $arg1';
  }

  @override
  String get stop => 'Stop';

  @override
  String get stop2 => 'Stop (⌘.)';

  @override
  String get stopManaging => 'Stop a bhainistiú';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'An bhfuil fonn ort éirí as bainistiú $arg1?';
  }

  @override
  String get stopRun => 'Stop rith';

  @override
  String get stopSpeaking => 'Stop ag labhairt';

  @override
  String get stoppedBeforeCompletion => 'Stoptha roimh chríochnú';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'stopTelecomCallRouting Earráid: $arg1';
  }

  @override
  String get storage => 'Stóráil';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'stóráilte criptithe agus gan úsáid ach amháin le haghaidh do ritheann féin.';

  @override
  String get storedMetrics => 'Méadracht Stóráilte';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Ní stórálann sé ach an eochair sheisiúin Bitwarden atá criptithe ar an bhfreastalaí seo, mar sin mairfidh naisc ó atosuithe. Is féidir leat é a ghlasáil ag am ar bith.';

  @override
  String get strong => 'Láidir';

  @override
  String get strongPassword => 'Pasfhocal láidir.';

  @override
  String get subAgent => 'Fo-ghníomhaire';

  @override
  String get subagentUpdate => 'Nuashonrú subagent';

  @override
  String get subagentUpdate2 => 'Nuashonrú subagent.';

  @override
  String get successRate => 'Ráta ratha';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Moltaí: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Déan achoimre ar mo rith dheireanach';

  @override
  String get supportUrl => 'Tacaíocht URL';

  @override
  String get supportedRainStartSnowStartWind =>
      'Tacaithe: rain_start, snow_start, wind_alert, teocht_thuas, teocht_below';

  @override
  String get switchAgent => 'Athraigh gníomhaire';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Ní cheadaítear naisc siombalacha i gcosáin NeoAgent Workspace.';

  @override
  String get syncNow => 'Sioncrónaigh anois';

  @override
  String get synologyChat => 'Comhrá Synology';

  @override
  String get systemPrivacySettings => 'Socruithe príobháideachta córais';

  @override
  String get tableInfoUsers => 'Faisnéis tábla (úsáideoirí)';

  @override
  String get tagsOnly => 'Clibeanna amháin';

  @override
  String get tasks => 'Tascanna';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Ritheann tascanna leo féin agus cuireann siad teachtaireacht chugat leis an ';

  @override
  String get teach => 'Múin';

  @override
  String get teachingInProgress => 'Teagasc ar siúl';

  @override
  String get team => 'Foireann';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Ní dhéanfaidh naisc foirne riarthóir freastalaí aon duine riamh. Ritheann riarthóirí an ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Spásanna foirne, seomraí, cainéil, agus pobail bheo.';

  @override
  String get teamsMessageReceived => 'Fuarthas Teachtaireacht Foirne';

  @override
  String get templates => 'Teimpléid';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Glanfar comhaid socraithe shealadacha níos déanaí.';

  @override
  String get tenantId => 'ID an Tionónta';

  @override
  String get testConnection => 'Ceangal tástála';

  @override
  String get testConnection2 => 'Ceangal Tástála';

  @override
  String get textChat => 'Téacs & Comhrá';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'gur cuireadh a n-eochair féin in úsáid agat.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Is le cuntas atá ann cheana féin an ríomhphost sin. Sínigh isteach ar dtús, ansin nasc Google ó shocruithe cuntais.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Tá an ríomhphost sin nasctha le cuntas eile cheana féin.';

  @override
  String get thatQrCodeIsNotA =>
      'Ní iarratas logáil isteach NeoAgent é an cód QR sin.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Ní iarratas péireála NeoAgent é an cód QR sin.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Tá an eochair shlándála sin cláraithe ar an gcuntas seo cheana.';

  @override
  String get theAddress => 'An seoladh';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'Seoladh do fhreastalaí BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'Na seoltaí a úsáideann daoine agus soláthraithe OAuth a bhaint amach ';

  @override
  String get theAgentReadsTimesYouMention =>
      'Léann an gníomhaire amanna a luann tú, agus reáchtálann sé tascanna sceidealaithe, sa chrios ama seo.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'Iarrfaidh an gníomhaire roimh gach uirlis íogair, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'Déanfaidh an gníomhaire neamhaird ar an scil seo.';

  @override
  String get theAppCouldNotReachThis =>
      'Níorbh fhéidir leis an app an t-imscaradh NeoAgent seo a bhaint amach. Seiceáil do cheangal líonra nó deimhnigh go bhfuil URL na seirbhíse ceart.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'Chuir an brabhsálaí bac ar iarratas chuig $arg1 mar gheall ar Pholasaí Slándála Inneachair.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'Chuir an brabhsálaí bac ar iarratas riachtanach mar gheall ar Bheartas Slándála Inneachair.';

  @override
  String get theCloudWorkspace => 'an spás oibre scamall';

  @override
  String get theComputerCouldNotStart => 'Níorbh fhéidir an ríomhaire a thosú';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'Tá níos mó spáis diosca saor in aisce ag teastáil ón ríomhaire ar an óstach NeoAgent. Saor roinnt spáis, ansin bain triail eile as.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'Tá gá le ham rite an ríomhaire a dheisiú. Rith NeoAgent Doctor, ansin bain triail eile as.';

  @override
  String get theConnectionTestFailed => 'Theip ar an tástáil ceangail.';

  @override
  String get theDesktopDidNotStart => 'Níor thosaigh an deasc';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'Thug an NeoAgent amach sonraí aitheantais neamhiomlán.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'Úsáideann an NeoAgent aimsithe prótacal socraithe gan tacaíocht.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'Ní NeoAgent an tseirbhís aimsithe.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'Níor sháraigh an t-am rite NeoAgent íosluchtaithe an fíorú.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'An cuaille gréasáin spáis Google Chat ar cheart don ghníomhaire seo postáil chuige.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'Níl an suiteálaí ar fáil a thuilleadh.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'Tá an deasc Linux idirghníomhach ar fáil san aip gréasáin NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'Níl an intro ar fáil ar an ngléas seo.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Ritheann an ceann is déanaí thar gach cuntas.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'Tháinig deireadh le $arg1 leis an bhfuinneog sioncronaithe is déanaí agus níor aimsíodh aon taifead nua Health Connect. Tháinig an mhéadracht stóráilte thíos ó shioncronuithe níos luaithe.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'Níl an seisiún grafach Linux ar siúl.';

  @override
  String get theLiveVoiceModelDidNot =>
      'Níor fhreagair an tsamhail ghutha beo. Bain triail eile as.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'D\'fhág an t-ordú áitiúil NeoAgent le cód $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Tháinig deireadh leis an ordú áitiúil NeoAgent.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'Ní mór an t-am rite NeoAgent áitiúil a dheisiú.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'Teastaíonn deisiú an ama rite áitiúil ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'Níl an t-eolaire baile úsáideora áitiúil ar fáil.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'Seolann an cuntas ríomhphoist NeoAgent dearbhuithe sínithe, síniú isteach ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'Cruthaítear an príomhghníomhaire go huathoibríoch nuair is gá.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'Tá an t-am rite NeoAgent meaitseála ar iarraidh ón scaoileadh seo.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'An cuaille gréasáin is tábhachtaí ar cheart don ghníomhaire seo postáil chuige.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Déanann na múnlaí bealach an Roghnóir Cliste eatarthu go huathoibríoch.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'Ní raibh an íoslódáil inneall NeoAgent ag teacht lena léiriú.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'Bhí íoslódáil inneall NeoAgent neamhiomlán.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'Níl inneall NeoAgent ar an ríomhaire seo ag freagairt ar phort ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Níorbh fhéidir am rite inneall NeoAgent a íoslódáil.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'Ghlac inneall NeoAgent ró-fhada chun freagairt do $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'D\'fhreagair imscaradh NeoAgent le HTTP 402 in ionad an ghnáth-401 le haghaidh dintiúir neamhbhailí. Seiceáil seachfhreastalaí droim ar ais, geata an údair, nó rialacha a bhaineann le híocaíocht ar an bhfreastalaí sin.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'D\'fhreagair imscaradh NeoAgent le HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'D\'fhreagair imscaradh NeoAgent le HTTP 402. Seiceáil seachfhreastalaí droim ar ais, geata údar, nó rialacha a bhaineann le híocaíocht ar an bhfreastalaí sin.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'Mar shampla NeoAgent a bhfuil an aip seo ceangailte leis.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'Chuir an tseirbhís scaoileadh NeoAgent sonraí neamhbhailí ar ais.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Tá meiteashonraí déantán ama rite NeoAgent neamhbhailí.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'Níor éirigh le léiriú am rite NeoAgent fíorú sínithe.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'Níl aon déantáin ag léiriú ama rite NeoAgent.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'Tá síniú forléirithe ama rite NeoAgent neamhbhailí.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'An pasfhocal a shocraigh tú in BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Fanann na daoine a bhainistíonn tú leat.';

  @override
  String get theProviderAnswers => 'freagraíonn an soláthraí.';

  @override
  String get theQueryReturnedNoRows =>
      'Níor tháinig aon sraitheanna ar ais don cheist.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'Níl an taispeáint deisce iarrtha ar fáil.';

  @override
  String get theRest => 'an chuid eile.';

  @override
  String get theRestEndpointForYourSignal =>
      'An críochphointe REST do do shampla comhartha-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'Cuirtear an rith ar sos go dtí go bhfreagraíonn tú.';

  @override
  String get theRunStartsAtTheScheduled =>
      'Tosaíonn an rith ag an am sceidealta.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'Is deasc éadrom Debian Linux é an t-am rite le Cróimiam, PCManFM, Mousepad, LXTerminal, Python, Git, agus uirlisí caighdeánacha ordú-líne. Tá a chumas á bhainistiú ag an óstach NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'Níorbh fhéidir clárú na heochrach slándála a thosú.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'ní choimeádann an freastalaí ach méarlorg de.';

  @override
  String get theServerOnThisComputerIs =>
      'Níl an freastalaí ar an ríomhaire seo ag rith';

  @override
  String get theServerReportedNoHealthChecks =>
      'Níor thuairiscigh an freastalaí aon seiceáil sláinte.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'An uimhir theileafóin Signal a úsáideann an bot seo.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'Ba cheart do na Foirne atá ag teacht isteach an gníomhaire seo a phostáil chuig.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'Chuaigh an dúshlán dhá fhachtóir in éag. Sínigh isteach arís.';

  @override
  String get theTwoFactorCodeIsNot => 'Níl an cód dhá fhachtóir bailí.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'Níorbh fhéidir an pacáiste ama rite fíoraithe a mharcáil inrite.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Tá na comhaid riachtanacha in easnamh sa phacáiste ama rite fíoraithe.';

  @override
  String get theWebAppCouldNotReach =>
      'Níorbh fhéidir leis an aip gréasáin inneall NeoAgent a bhaint amach.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'Níorbh fhéidir leis an app gréasáin inneall NeoAgent a bhaint amach ag $arg1. Seiceáil consól an bhrabhsálaí agus cumraíocht droim ar ais seachfhreastalaí/líonra.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'iad féin; Baineann oibreoir an fhreastalaí an riarthóir ar dtús le ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Fanann na cainéil seo ina dtost. Le cloisteáil uathu arís, cuir leis iad faoi Who can message for that platform.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Tá na liostaí seo roghnach ach amháin má tá an chuid thuas formheasta amháin.';

  @override
  String get thesePeopleAnywhere => 'Na daoine seo, áit ar bith';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Is féidir leis na daoine seo teachtaireacht a chur chuig $arg1 i gcomhráite príobháideacha agus in aon ghrúpa a roinneann siad.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Is féidir leis na daoine seo teachtaireacht a chur chuig $arg1 duine le duine. Ní ligeann sé seo dóibh labhairt i ngrúpaí.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Ní féidir leis na daoine seo ach teachtaireacht a chur chuig $arg1 sa ghrúpa a roghnaigh tú.';
  }

  @override
  String get thesePeopleInOneGroup => 'Na daoine seo, in aon ghrúpa';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'na lasca seo, ná do chuid comhráite, cuimhní cinn nó comhaid riamh.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Díghlasálfaidh an cuntas seo NeoAgent ar an meaisín seo.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Is féidir leis an ngníomhaire seo a tharmligean chuig aon ghníomhaire fála incháilithe.';

  @override
  String get thisAgentIsUsingAServer =>
      'Tá eochair Trello API atá á bainistiú ag an bhfreastalaí seo á úsáid ag an ngníomhaire seo. Ní gá duit ach chomhartha cuntais a údarú thíos.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Níl cead ag an tógáil seo labhairt leis an imscaradh NeoAgent seo.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Baineann an cód seo le freastalaí eile NeoAgent: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Tá an deasc seo ceangailte';

  @override
  String get thisDevice => 'An gléas seo';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'An gléas seo: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Ní féidir leis an ngléas seo eochracha slándála a chlárú. Oscail NeoAgent i mbrabhsálaí thar HTTPS chun ceann a chur leis.';

  @override
  String get thisDeviceUnavailable => 'An gléas - ar fáil';

  @override
  String get thisFileHasNoContent => 'Níl aon ábhar sa chomhad seo.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Cuireann sé seo \"$arg1\" i bhfolach ó ródú agus roghnú.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Tacaíonn an comhtháthú seo le cuntas nasctha amháin in aghaidh an ghníomhaire faoi láthair. Athoscail an socrú chun é a athsholáthar.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Níl an comhtháthú seo ar fáil a thuilleadh.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Tá an intro seo deartha le haghaidh athsheinm tírdhreacha lánscáileáin.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Imscaradh bainistithe é seo. Rollaíonn a oibreoir amach ';

  @override
  String get thisMayTakeAMoment => 'Féadfaidh sé seo nóiméad a ghlacadh.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Níl an freastalaí MCP seo cumraithe a thuilleadh.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Bainfear an chuimhne seo go buan.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Níl an tógáil NeoAgent seo cumraithe chun amanna rite inneall a fhíorú.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Scriosann sé seo do shonraí go léir go buan agus ní féidir ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Scriosann sé seo an cuntas agus gach rud atá ar úinéireacht aige go buan: ';

  @override
  String get thisPersonAnywhere => 'An duine seo, áit ar bith';

  @override
  String get thisPersonInOneGroup => 'An duine seo, i ngrúpa amháin';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Chuaigh an t-iarratas logáil isteach QR seo in éag. Gin cód nua agus bain triail eile as.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'tá an t-iarratas logáil isteach qr seo imithe in éag';

  @override
  String get thisQrLoginRequestIsStill =>
      'Tá an t-iarratas logáil isteach QR seo fós ag fanacht lena cheadú.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Baineadh úsáid as an iarratas logáil isteach QR seo cheana féin.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Baineann sé seo an socrú Cúntóir Baile agus an cás nasctha don ghníomhaire seo.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Baineann sé seo an URL inneall NeoRecall agus gach cuntas NeoRecall nasctha don ghníomhaire seo.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Baineann sé seo an URL Nextcloud agus gach cuntas Nextcloud ceangailte don ghníomhaire seo.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Baineann sé seo le socrú Trello agus na cuntais nasctha don ghníomhaire seo.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Éilíonn sé seo seisiún fíordheimhnithe ar an bhfreastalaí NeoAgent céanna.';

  @override
  String get thisRunDidNotProduceA =>
      'Níor tháirg an rith seo freagra úsáideora.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Níl aon sonraí céime taifeadta ag an rith seo.';

  @override
  String get thisServer => 'an freastalaí seo.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Tuairiscíonn an freastalaí seo nach bhfuil aon socruithe soláthraí ann.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Níl an scil seo suiteáilte a thuilleadh.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Níl aon rith críochnaithe fós ag an tasc seo, mar sin tosaíonn sé fós ag an ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Ní bheidh an tasc seo ar siúl ach amháin nuair a bhrúnn tú Rith Anois.';

  @override
  String get thisWeek => 'an tseachtain seo';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Iompórtálfaidh sé seo an freagra isteach i $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Bainfidh sé seo \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Bainfidh sé seo \"$arg1\" den liosta freastalaí.';
  }

  @override
  String get time => 'Am';

  @override
  String get timeZone => 'crios ama';

  @override
  String get timeZone2 => 'Crios ama';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Teorainn ama amach$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Níorbh fhéidir criosanna ama a liostú: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Níorbh fhéidir crios ama an ghléis a léamh: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Níorbh fhéidir crios ama an ghléis a shábháil: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'go $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'úsáid a bhaint as réamhshocraithe an fhreastalaí.';

  @override
  String get today => 'Inniu';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Buiséad comhartha do @$arg1. Fág páirc folamh ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Buiséad comhartha do gach cuntas gan a shárú féin. Fág a ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'teorainn buiséid chomhartha úsáideoir cuóta 4 uair sa tseachtain';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'teorainn buiséid chomhartha cuóta domhanda 4 uair an chloig in aghaidh na seachtaine';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Níl úsáid comhartha ar fáil ar an leagan freastalaí seo.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Comharthaí a fhéadfaidh cuntas ar bith a úsáid i gceann 4 huaire.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Comharthaí a fhéadfaidh cuntas ar bith a úsáid i gceann 7 lá.';

  @override
  String get tokensPerDay => 'Comharthaí in aghaidh an lae';

  @override
  String get tokensPerRun => 'Comharthaí in aghaidh an rith';

  @override
  String get tokensToday => 'Comharthaí inniu';

  @override
  String get tokensUsed => ' comharthaí a úsáidtear';

  @override
  String get tomorrowPrep => 'ullmhú amárach';

  @override
  String get tooManyAttempts => 'an iomarca iarrachtaí';

  @override
  String get tooManySignInAttemptsPlease =>
      'An iomarca iarrachtaí síniú isteach. Fan agus bain triail eile as.';

  @override
  String get tool => 'Uirlis';

  @override
  String get toolApproval => 'Faomhadh Uirlis';

  @override
  String get toolApprovalRequired => 'Teastaíonn ceadú na huirlise';

  @override
  String get toolCompleted => 'Uirlis críochnaithe';

  @override
  String get toolFailed => 'Theip ar an uirlis';

  @override
  String get toolPermissions => 'Ceadanna Uirlisí';

  @override
  String get toolStarted => 'Thosaigh an uirlis';

  @override
  String get tools => 'Uirlisí';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Uirlisí nach bhfuil ionsuite i NeoAgent, lena n-áirítear freastalaithe MCP nasctha agus soláthraithe uirlisí saincheaptha.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Uirlisí tairgthe ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Uirlisí a fhéadfaidh an cuntas bainistithe a úsáid';

  @override
  String get topUsers => 'Úsáideoirí is fearr';

  @override
  String get topUsersAndRecentRuns =>
      'Úsáideoirí is fearr agus ritheanna le déanaí';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Iomlán: comharthaí $arg1 ar fud ritheann $arg2';
  }

  @override
  String get totalRuns => 'Ritheann iomlán';

  @override
  String get totalTokens => 'Comharthaí iomlána';

  @override
  String get totalUsers => 'Úsáideoirí iomlána';

  @override
  String get transcript => 'Athscríbhinn';

  @override
  String get transcript2 => 'TRANSCRIPT';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Theip ar an trascríobh: $arg1';
  }

  @override
  String get transfer => 'Aistriú';

  @override
  String get trelloApiKey => 'Eochair Trello API';

  @override
  String get trelloApiKeyIsRequired => 'Tá Eochair Trello API ag teastáil.';

  @override
  String get trelloSetup => 'Socrú Trello';

  @override
  String get triggerType => 'Cineál Truicear';

  @override
  String get tryABroaderSearchLikeModels =>
      'Bain triail as cuardach níos leithne cosúil le samhlacha, brabhsálaí, nó guth.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Bain triail as ainm soláthraí, \"ríomhphost\", \"teorainneacha\", \"nuashonraigh\" nó \"logs\".';

  @override
  String get tryAgain => 'Bain triail eile as';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Bain triail eile as. Má leanann sé seo ag tarlú, reáchtáil NeoAgent Doctor chun am rite an ríomhaire a sheiceáil.';

  @override
  String get tryAgainInAMoment => 'Bain triail eile as i gceann nóiméad.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Bain triail eile as nó rith NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Bain triail as cuardach eile, ceangail ardán teachtaireachtaí, nó cuir isteach aitheantas sprice de láimh.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Cuir grúpa ar siúl ar cheart do $arg1 teachtaireachtaí nach bhfuil clib orthu a léamh freisin.';
  }

  @override
  String get turnOffComputer => 'Múch an ríomhaire';

  @override
  String get turnOffOnlyForAMail =>
      'Múch do fhreastalaí ríomhphoist amháin a bhfuil teastas féin-shínithe aige.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Cuir ar siúl ar cheart do Signal leanúint ar aghaidh ag lorg comhráite isteach.';

  @override
  String get turnTaking => 'seal a ghlacadh';

  @override
  String get turnTakingModel => 'Múnla sealaíochta';

  @override
  String get turnTakingOff => 'Múchadh';

  @override
  String get turnThisOffToKeepThis =>
      'Múch é seo chun an gníomhaire seo a choinneáil go hiomlán scartha ó ghníomhairí eile.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Múchta ag $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Múchta ag $arg1, a bhainistíonn an cuntas seo. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Múchta duit ag $arg1 — ní féidir ach leosan é a athrú';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Múchadh duit, mar sin ní féidir leat é a thabhairt amach';

  @override
  String get twitchChatOverIrc => 'Twitch comhrá thar IRC';

  @override
  String get twoFactorAuthentication => 'Fíordheimhniú dhá fhachtóir';

  @override
  String get twoFactorChallengeExpired => 'dúshlán dhá fhachtóir imithe in éag';

  @override
  String get twoFactorCode => 'cód dhá fhachtóir';

  @override
  String get twoFactorSignInCompletedBut =>
      'Síniú isteach dhá-fhachtóir críochnaithe, ach níorbh fhéidir le NeoAgent an seisiún brabhsálaí a choinneáil. Sínigh isteach arís le do thoil.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Logáil isteach dhá chéim (má tá sé cumasaithe amháin)';

  @override
  String get type => 'Cineál';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Clóscríobh $arg1 le deimhniú';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'ní thacaítear le cineál-téacs ar an ardán seo.';

  @override
  String get typedInTheBrowser => 'Clóscríofa sa bhrabhsálaí';

  @override
  String get typedText => 'Téacs clóscríofa';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime => 'ní féidir am rite java a aimsiú';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Ní féidir socruithe ama a oscailt ar an leagan seo.';

  @override
  String get unableToOpenWiFiSettings =>
      'Ní féidir socruithe Wi-Fi a oscailt ar an leagan seo.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Ní féidir an taispeáint deisce roghnaithe a leanúint.';

  @override
  String get unclearWhoItWasFor => 'Ní fios cé dó a bhí sé';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'gan déanamh. Clóscríobh d\'ainm úsáideora lena dheimhniú.';

  @override
  String get unknownAccount => 'Cuntas anaithnid';

  @override
  String get unknownAgent => 'Gníomhaire anaithnid';

  @override
  String get unknownBrowser => 'Brabhsálaí anaithnid';

  @override
  String get unknownDevice => 'Gléas anaithnid';

  @override
  String get unknownError => 'earráid anaithnid';

  @override
  String get unknownLocalComputerPermission =>
      'Cead ríomhaire áitiúil anaithnid.';

  @override
  String get unknownLocation => 'Suíomh anaithnid';

  @override
  String get unknownPublishTime => 'Am foilsithe anaithnid';

  @override
  String get unknownSize => 'Méid anaithnid';

  @override
  String get unlink => 'Dínascadh';

  @override
  String get unreadOnly => 'Neamhléite Amháin';

  @override
  String get unsavedChanges => 'Athruithe gan sábháil';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Ordú compánach deisce gan tacaíocht: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Modh nach dtacaítear leis: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Foláirimh síniú isteach neamhghnách';

  @override
  String updateArg1(Object? arg1) {
    return 'Nuashonraigh $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Nuashonraigh croí-iontrálacha cuimhne ón iompórtáil.';

  @override
  String get updateNow => 'Nuashonraigh anois';

  @override
  String get updateReady => 'Nuashonrú réidh';

  @override
  String get updateSetup => 'Socrú Nuashonraigh';

  @override
  String get updateTheAccessListToAllow =>
      'Nuashonraigh an liosta rochtana chun freagraí a cheadú.';

  @override
  String get updateTheServer => 'Nuashonraigh an freastalaí?';

  @override
  String get updateTheServer2 => 'Nuashonraigh an freastalaí';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Nuashonraigh an crios ama go huathoibríoch ón bhfeiste atá in úsáid agat.';

  @override
  String updatedArg1(Object? arg1) {
    return 'nuashonraithe $arg1';
  }

  @override
  String get updates => 'Nuashonruithe';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Níl nuashonruithe cumraithe don leagan seo.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'nuashonruithe, mar sin tá féin-nuashonrú agus athruithe cainéal múchta anseo.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'nuashonrú uasghrádaithe anois scaoileadh cainéal cobhsaí beta';

  @override
  String get usageAnalytics => 'Anailísíocht úsáide';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Comharthaí úsáide agus sláinte a chuidíonn le hiompraíocht reatha ama rite a mhíniú gan tochailt trí logaí ar dtús.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'Athshocraíonn úsáid go hiomlán i $arg1';
  }

  @override
  String get usageLeaderboard => 'clár ceannaire úsáide';

  @override
  String get usageLimits => 'Úsáid & Teorainneacha';

  @override
  String get usageLimits2 => 'Úsáid & teorainneacha';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Úsáid 8+ carachtar. Oibríonn frásaí níos faide go maith.';

  @override
  String get useADateAndTimeFor =>
      'Bain úsáid as dáta agus am, mar shampla 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Úsáid ainm, uimhir theileafóin nó ID comhrá.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Úsáid URL NeoRecall is féidir leis an bhfreastalaí NeoAgent a bhaint amach. Ní mór go mbeadh PUBLIC_URL NeoAgent insroichte ón mbrabhsálaí seo don aisghlao OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Úsáid pasfhocal nua le 8 gcarachtar ar a laghad.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Úsáid URL Nextcloud is féidir leis an bhfreastalaí NeoAgent a bhaint amach, mar shampla https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Úsáid pasfhocal le 8 gcarachtar ar a laghad.';

  @override
  String get useASecureConnectionTls => 'Úsáid nasc slán (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Bain úsáid as aip fíordheimhnitheora ar nós Authy, 1Password, nó Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Úsáid ar a laghad 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb =>
      'Cuimhne uasta in aghaidh an ríomhaire (MB)';

  @override
  String get maxVcpusPerComputer => 'Uasmhéid vCPUs do ríomhaire';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return '$arg1 ar a laghad. Faigheann ríomhairí níos lú nuair a bhíonn an t-óstach gnóthach.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'Caithfidh an chuimhne uasta a bheith $arg1 MB ar a laghad.';
  }

  @override
  String get useAtLeast8Characters => 'Úsáid ar a laghad 8 gcarachtar.';

  @override
  String get useDefault => 'Úsáid réamhshocraithe';

  @override
  String get useDefaultChannel => 'Úsáid cainéal réamhshocraithe';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Úsáid réamhshocraithe (NeoAgent Workspace)';

  @override
  String get useFor => 'Úsáid le haghaidh';

  @override
  String get useManualDestination => 'Bain úsáid as ceann scríbe láimhe';

  @override
  String get useOrDoTheSameFor =>
      'bain úsáid as, nó déan an rud céanna do do chomhpháirtithe.';

  @override
  String get usePerCategorySettingsBelow =>
      'Úsáid socruithe in aghaidh na catagóire thíos.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Úsáid réamhshocraithe Socruithe ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Úsáid an freastalaí ar an ríomhaire seo';

  @override
  String get useTheseForContextIfA =>
      'Úsáid iad seo mar chomhthéacs. Mura bhfuil rochtain dhíreach ar URI áitiúil ón bhfreastalaí, iarr orm an comhad a sholáthar trí spás oibre inrochtana.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Bain úsáid as seo le haghaidh gníomhairí ceolfhoirneora. Fág as do róbónna oibre scoite ar cheart dóibh teachtaireachtaí díreacha a chríochnú iad féin.';

  @override
  String get useTlsFromTheStartOf =>
      'Úsáid TLS ó thús an naisc, de ghnáth ar phort 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Bain úsáid as d\'eochair API féin le haghaidh soláthraí, nó ceangail saincheaptha ';

  @override
  String get usedByEveryAccountOnThis =>
      'In úsáid ag gach cuntas ar an bhfreastalaí seo nach bhfuil eochair aige ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Úsáidtear é chun a fhíorú go bhfuil imeachtaí Slack ag teacht isteach fíor.';

  @override
  String get userSummary => 'Achoimre úsáideora';

  @override
  String get username => 'Ainm úsáideora';

  @override
  String get usernameOrEmail => 'Ainm úsáideora nó ríomhphost';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'úsáideoirí daoine cuardach ríomhphoist ainm úsáideora fhoireann bainistithe suaitheantas riaracháin';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Úsáideann sé an tsamhail chomhrá atá cumraithe sna Socruithe';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Ag baint úsáide as an am rite NeoAgent suiteáilte';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'De ghnáth is cosúil le @bot:matrix.org';

  @override
  String get validEmail => 'ríomhphost bailí';

  @override
  String get value => 'Luach';

  @override
  String get vaultLocked => 'Cruinneachán faoi ghlas';

  @override
  String get vaultOperationFailed => 'Theip ar oibríocht cruinneachán.';

  @override
  String get verification => 'Fíorú';

  @override
  String verificationArg1(Object? arg1) {
    return 'Fíorú: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'fíorú: $arg1';
  }

  @override
  String get verificationCompleted => 'Fíorú críochnaithe.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Stádas fíoraithe: $arg1';
  }

  @override
  String get verifiedTheResult => 'Fíoraíodh an toradh';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Ag fíorú an ama rite íosluchtaithe';

  @override
  String get versionAndUptime => 'Leagan agus uptime';

  @override
  String versionArg1(Object? arg1) {
    return 'Leagan $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'Tá leagan $arg1 suiteáilte, ach tá $arg2 fós ag rith.';
  }

  @override
  String get videoLinks => 'Naisc físe';

  @override
  String get viewDesktop => 'Amharc ar an deasc';

  @override
  String get viewLastRun => 'Féach ar an rith dheireanach';

  @override
  String get viewLogs => 'Féach ar logaí';

  @override
  String get vmImageMemoryCpuQemuRuntime => 'cuimhne íomhá vm cpu qemu am rite';

  @override
  String get voice => 'Guth';

  @override
  String get voiceAssistant => 'Cúntóir gutha';

  @override
  String get voiceCall => 'GUTHghlao';

  @override
  String get voiceCall2 => 'Glao gutha';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'glao gutha gpt-live gemini beo samhla cainte fíor-ama';

  @override
  String get voiceCallsRunOnALive =>
      'Ritheann glaonna gutha ar mhúnla beo cainte-go-hurlabhra leis an stair phearsanta, cuimhne agus comhrá céanna le NeoAgent. Freagraíonn sé ar an bpointe boise agus tugann sé fíor-obair don ghnáthghníomhaire, a choinníonn ag rith sa chúlra.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'nóta gutha eochair api trascríobh cainte';

  @override
  String get voiceNotesAndDictation => 'Nótaí gutha agus deachtú';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'Níl athsheinm gutha ar fáil ar an ngléas seo.';

  @override
  String get voiceReplyModel => 'Múnla freagra gutha';

  @override
  String get waitingForApproval => 'Ag feitheamh le ceadú: ';

  @override
  String get waitingForCode => 'Ag fanacht le cód';

  @override
  String get waitingForInput => 'Ag fanacht le hionchur';

  @override
  String get waitingForServerOrFlutterLog =>
      'Ag fanacht le haschur loga freastalaí nó Flutter…';

  @override
  String get waitingForTaskEvents => 'Ag fanacht le taisc-imeachtaí...';

  @override
  String get waitingForYou => 'ag fanacht leat';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Ag iarraidh freagra ó $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Ag iarraidh labhairt leat · ${arg1}s';
  }

  @override
  String get weak => 'Lag';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Aimsir, féilire agus tosaíochtaí sula dtosaíonn do lá.';

  @override
  String get weatherEvent => 'Imeacht Aimsire';

  @override
  String get web => 'Gréasán';

  @override
  String get webBrowser => 'Brabhsálaí gréasáin';

  @override
  String get webSearchApiKey => 'Eochracha cuardaigh gréasáin api';

  @override
  String get webhookOrRestChannelPosting => 'Postáil cainéil gréasáin nó REST';

  @override
  String get webhookSecret => 'An rún gréasáin';

  @override
  String get webhookUrlCopied => 'URL cuaille gréasáin cóipeáilte';

  @override
  String get weekdays => 'Laethanta na seachtaine';

  @override
  String get weekdays0730 => 'Laethanta na seachtaine · 07:30';

  @override
  String get weekdays1800 => 'Laethanta na seachtaine · 18:00';

  @override
  String get weekly => 'Seachtainiúil';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Teorainn sheachtainiúil $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Teorainn sheachtainiúil (tokens)';

  @override
  String get weeklyReview => 'Léirmheas seachtainiúil';

  @override
  String get weeklyUsage => 'Úsáid Sheachtainiúil';

  @override
  String weightArg1Records(Object? arg1) {
    return 'taifid meáchain $arg1';
  }

  @override
  String get welcomeToNeoagent => 'FÁILTE CHUIG NEOAGENT';

  @override
  String get welcomeToNeoagent2 => 'Fáilte go\ndtí NeoAgent';

  @override
  String get whatAreYouAdding => 'Cad atá tú ag cur leis?';

  @override
  String get whatIsOnTomorrow => 'Cad atá ar siúl amárach?';

  @override
  String get whatShouldNeoagentLearn =>
      'Cad ba cheart do NeoAgent a fhoghlaim?';

  @override
  String get whatShouldWeBuild => 'Cad ba cheart dúinn a thógáil?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Tá an méid a deir tú féin agus NeoAgent le feiceáil anseo agus sa chomhrá.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Fuarthas Teachtaireacht Phearsanta WhatsApp';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Nuair a roghnaíonn tú ceadaithe amháin, cuir daoine nó grúpaí thíos leis.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'An áit ar cheart don ghníomhaire seo freagraí a sheoladh.';

  @override
  String get whoCanMessage => 'Cé atá in ann teachtaireacht';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Cé na daoine ar féidir leo teachtaireacht a sheoladh ar $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Cé atá in ann teachtaireacht duine le duine a sheoladh chuig $arg1.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Cé atá in ann labhairt le $arg1 i ngrúpa, cainéal nó seomra.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'cé a bhainistíonn an cuntas seo múchta: ';

  @override
  String get whoManagesWhom => 'Cé a bhainistíonn cé';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'An té a ghlacann le nasc, téann sé isteach i d\'fhoireann gan ach na huirlisí atá aige ';

  @override
  String get wholeGroup => 'Grúpa iomlán';

  @override
  String get wholeGroups => 'Grúpaí iomlána';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Cén fáth ar fhreagair $arg1 nó ar fhan sé ciúin i ngrúpaí $arg2.';
  }

  @override
  String get windowsApp => 'feidhmchlár Windows';

  @override
  String get windowsNt => 'fuinneoga nt';

  @override
  String get workAccount => 'Cuntas oibre';

  @override
  String get workOnAProjectWithNeoagent => 'Oibriú ar thionscadal le NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Sreabhadh Oibre: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Ag obair i $arg1 ar an ríomhaire scamall. Léann agus cuireann NeoAgent comhaid in eagar ansin agus is féidir leis orduithe agus brabhsálaí a rith.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Ag obair sa chúlra: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Cumraíocht spás oibre agus slándáil chuntais in aon áit amháin.';

  @override
  String get workspaceFiles => 'Comhaid spás oibre';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Spás oibre, samhlacha, agus rialuithe diagnóisic.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'Ní mór gur cosán iomlán é sárú spás oibre.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Scríobh $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'Earráid iarratais xmlhttp';

  @override
  String get yesterday => 'Inné';

  @override
  String get youAreInControl => 'Tá tú i gceannas';

  @override
  String get youCanFollowAlongOnThe =>
      'Is féidir leat leanúint ar aghaidh ar an deasc.';

  @override
  String get youCanLeaveATeamAt =>
      'Is féidir leat foireann a fhágáil ag am ar bith; tá do shocruithe féin i bhfeidhm arís.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Is féidir leat imeacht ag am ar bith ó leathanach na Foirne.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Socraíonn tú cé na huirlisí is féidir le do ghníomhaire a úsáid, faoi Socruithe › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Ní bhainistíonn tú aon duine go fóill. Cruthaigh nasc cuirí thíos agus ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Tá socruithe gan sábháil agat. Cad ba mhaith leat a dhéanamh?';

  @override
  String get youReOnYourOwnYou =>
      'Tá tú leat féin: socraíonn tú cé na huirlisí is féidir le do ghníomhaire a úsáid. Más rud é ';

  @override
  String get yourAccountAndUsageOnA =>
      'do chuntas -- agus úsáid ar mhúnla le tacaíocht d\'eochair féin ';

  @override
  String get yourAccountHasBeenDeleted => 'Scriosadh do chuntas.';

  @override
  String get yourAgentWillBeAllowed => 'Ceadófar do ghníomhaire:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Sábháiltear d\'aipeanna agus comhaid.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Tá d\'aipeanna agus comhaid fós sábháilte.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'D\'eochair $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Do shraith chúntóra le haghaidh gabhála, comhthéacs agus gníomhaíochta.';

  @override
  String get yourComputerIsAsleep => 'Tá do ríomhaire ina chodladh';

  @override
  String get yourComputerIsOff => 'Tá do ríomhaire múchta';

  @override
  String get yourComputerIsReady => 'Tá do ríomhaire réidh';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Tá do phasfhocal reatha mícheart.';

  @override
  String get yourData => 'Do shonraí';

  @override
  String get yourDataExportWasCopiedTo =>
      'Cóipeáladh d\'easpórtáil sonraí chuig an ngearrthaisce.';

  @override
  String get yourDesktopIsReady => 'Tá do dheasc réidh';

  @override
  String get yourLinuxComputer => 'Linux do ríomhaire';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Ní dhéantar do shuíomh a rianú go leanúnach nó a stóráil ar ár bhfreastalaithe. Ní úsáidimid é ach go háitiúil chun seiceáil i gcoinne do thascanna gníomhacha.';

  @override
  String get yourManager => 'do bhainisteoir';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'URL do shuímh Mattermost, má úsáideann tú an REST API.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Chuaigh do sheisiún in éag nó níor choinnigh an brabhsálaí é. Sínigh isteach arís le do thoil.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Chuaigh do sheisiún in éag. Sínigh isteach arís le do thoil.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Tá d\'ainm úsáideora nó pasfhocal mícheart.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Pearsanta';

  @override
  String get sectionOverview => 'Forbhreathnú';

  @override
  String get sectionDiagnostics => 'Diagnóisic';

  @override
  String get sectionVolume => 'Toirt';

  @override
  String get sectionSession => 'Seisiún';

  @override
  String get sectionDeliverable => 'Inseachadta';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'Níl logchomhad scríofa ag an am rite áitiúil fós.';

  @override
  String get thisComputer => 'An ríomhaire seo';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Suiteálann Beta an t-inneall réamheisiúna is nuaí. Bí ag súil le imill garbh.';

  @override
  String get copiedFinalResponse => 'Cóipeáil an freagra deiridh';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'Léirítear an freagra deiridh anseo nuair a chríochnaíonn an rith.';

  @override
  String get waitingForTheFirstStep => 'Ag fanacht leis an gcéad chéim…';

  @override
  String get loadingPrompt => 'Leid á lódáil…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Níor aimsíodh aon fhreagra deiridh don rith seo.';

  @override
  String get readyToSignIn => 'Réidh le síniú isteach';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Athraigh go \"Réamhshocrú\" nó \"Iarr i gcónaí\" chun seiceálacha formheasa a athchumasú.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Seol nuashonrú stiúrtha nó nóta don chéad chéim eile don rith reatha...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Gan nasc líonra. Déanfaidh NeoAgent athcheangal nuair a bheidh an gléas ar ais ar líne.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Cuireadh an nuashonrú stiúrtha is déanaí i bhfeidhm ar an rith reatha.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Seisiún príobháideach gutha á ullmhú…';

  @override
  String get preparingYourComputer => 'Ag ullmhú do ríomhaire';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'Tá NeoAgent ag íoslódáil agus ag ullmhú an chórais Linux slán. Ní tharlaíonn sé seo ach an chéad uair.';

  @override
  String get moreFreeSpaceIsNeeded => 'Tá gá le níos mó spáis saor in aisce';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Saor roinnt spás diosca ar an ósta NeoAgent, ansin bain triail eile as. Tá do shonraí ríomhaire atá ann cheana sábháilte.';

  @override
  String get androidReady => 'Android réidh';

  @override
  String get startingAndroid2 => 'Android á thosú…';

  @override
  String get androidStopped => 'Stopadh Android';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'Íoslódálann an chéad tús an SDK Android agus íomhá an chórais, a fhéadfaidh roinnt nóiméad a ghlacadh.';

  @override
  String get androidIsStopped => 'Tá Android stoptha';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Tosaigh an timpeallacht Android bainistithe nuair is gá duit é.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Lig do NeoAgent oibriú ar an ríomhaire seo';

  @override
  String get firstTimeSetupIsInProgress => 'Tá socrú céaduaire ar siúl.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'Is féidir le NeoAgent an rochtain a cheadaíonn tú a úsáid.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Saor roinnt stóras óstaigh agus bain triail eile as.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Tosaigh nuair is mian leat NeoAgent chun cabhrú anseo.';

  @override
  String get systemPermissionMissing => 'Cead córais in easnamh';

  @override
  String get connectingThisDevice => 'An gléas seo a nascadh';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Tá nasc slán áitiúil á bhunú.';

  @override
  String get recordingYourDemonstration => 'Do thaispeántas a thaifeadadh';

  @override
  String get noErrorsInTheRecentLog => 'Níl aon earráidí sa loga le déanaí.';

  @override
  String get loadingAccounts => 'Cuntais á lódáil…';

  @override
  String get neverSignedIn => 'Níor shínigh isteach riamh';

  @override
  String get emptyUsesTheServerDefault =>
      'Úsáideann Folamh réamhshocrú an fhreastalaí.';

  @override
  String get followTheSelectedSession => 'Lean an seisiún roghnaithe';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'Ní dhéantar iniúchadh ach ar mhodh an phlean. Athraigh go mód Gníomhaire chun ligean do NeoAgent comhaid a chur in eagar.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Teastaíonn uait ríomhphost chun do chuntas a chur leis nó a athrú.';

  @override
  String get confirmNewPassword => 'Deimhnigh pasfhocal nua';

  @override
  String get passwordChanged => 'Athraíodh an pasfhocal.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Baineadh úsáid as an iarratas seo cheana féin.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Tá an t-iarratas seo imithe in éag. Iarr ar an ngléas eile cód nua a ghiniúint.';

  @override
  String get startQuickstart => 'Tosaigh Mearthosú';

  @override
  String get createYourAccount => 'Cruthaigh do chuntas';

  @override
  String get showWorkAsSummaries => 'Taispeáin an obair mar achoimrí';

  @override
  String get tokensUsedByTheLatestRun =>
      'Comharthaí a úsáideann an rith is déanaí';

  @override
  String get listedTheWorkspaceRoot => 'Liostaítear an fhréamh spás oibre';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Níl aon chomhtháthú oifigiúil ar fáil go fóill.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Níl aon fhreastalaí MCP cumraithe fós. Cuir ceann amháin leis chun a chuid uirlisí a nochtadh.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Cuir freastalaí MCP leis nó suiteáil scil le tosú.';

  @override
  String get setUp => 'Socraigh suas';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Fág bán chun an luach stóráilte a choinneáil';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Baineann sé seo an seoladh do gach cuntas ar an bhfreastalaí seo.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Just a labhairt. Is féidir leat cur isteach ag am ar bith. Tapáil chun balbhú.';

  @override
  String get tapAgainWhenYouAreDone =>
      'Tapáil arís nuair a bheidh tú críochnaithe.';

  @override
  String get workingOnATaskInTheBackground => 'Ag obair ar thasc sa chúlra.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Caint-go-hurlabhra leis an gcuimhne chéanna, uirlisí agus stair comhrá mar NeoAgent.';

  @override
  String get checkLink => 'Seiceáil an nasc';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Ní cheadófar do ghníomhaire aon cheann de na huirlisí rialaithe.';

  @override
  String get notYoursToChange => 'Ní mise a athrú';

  @override
  String get setByYou => 'Socraigh ag tú';

  @override
  String get noTools => 'Uimh uirlisí';

  @override
  String get untitledLink => 'Nasc gan teideal';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Stopann sé ag obair tar éis do dhuine amháin é a fhuascailt.';

  @override
  String get theOperator => 'An t-oibreoir';

  @override
  String get smartSelectorOn => 'Roghnóir cliste ar siúl';

  @override
  String get startASessionToBegin => 'Cuir tús le seisiún le tosú';

  @override
  String get steerTheActiveRun => 'Stiúraigh an rith gníomhach…';

  @override
  String get describeWhatToPlan => 'Déan cur síos ar a bhfuil le pleanáil…';

  @override
  String get stopDictation => 'Stop deachtú';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Stiúrann teachtaireachtaí an rith reatha · ⌘↵ seol · ⌘. stad';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'Iniúchtaí modh plean amháin; ní athraítear aon rud go dtí go gcuirfidh tú i bhfeidhm · ⌘↵ seol';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'Déanann an gníomhaire eagarthóireacht ar an spás oibre. Plean iniúchtaí amháin.';

  @override
  String get defaultModel => 'Múnla réamhshocraithe';

  @override
  String get openingScanner => 'Scanóir á oscailt...';

  @override
  String get theAgentCanUseThisSkill =>
      'Is féidir leis an ngníomhaire an scil seo a úsáid.';

  @override
  String get allSelected => 'Gach Roghnaithe';

  @override
  String get addCoreMemoryEntry => 'Cuir Iontráil Chroí-Chuimhne leis';

  @override
  String get channelId => 'ID cainéal';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Úsáideann tascanna AI-chruthaithe agus neamhshonraithe an réamhshocrú reatha.';

  @override
  String get waitingForRunEvents => 'Ag fanacht le himeachtaí a rith...';

  @override
  String get hideSteps => 'Folaigh céimeanna';

  @override
  String get commitTheActiveLiveCapture =>
      'Tiomantas an ghabháil beo gníomhach';

  @override
  String get stopCaptureAndSubmit => 'Stop a ghabháil agus a chur isteach';

  @override
  String get clickTheMicToStartSpeaking =>
      'Cliceáil ar an micreafón chun tosú ag labhairt';

  @override
  String get connectACustomEndpoint => 'Ceangail críochphointe saincheaptha';

  @override
  String get hostedProvider => 'soláthraí óstáilte.';

  @override
  String get muted => ' • balbhaithe';

  @override
  String get addWhoCanMessage => 'Cuir leis cé atá in ann teachtaireacht';

  @override
  String get joinsGroupConversations => 'Glacann sé páirt i gcomhráite grúpa';

  @override
  String get label1PersonOrGroupAdded => 'Cuireadh 1 duine nó grúpa leis';

  @override
  String get inProgress => 'Ar siúl';

  @override
  String get waitingForUpdateJobOutput =>
      'Ag fanacht le haschur poist nuashonraithe…';

  @override
  String get taskTrigger => 'Truicear tasc';

  @override
  String get bearerToken => 'Comhartha iompróra';

  @override
  String get bearerToken2 => 'Comhartha Iompróir';

  @override
  String get notRecorded => 'Gan taifeadadh';

  @override
  String get sessionCookie => 'Fianán seisiúin';

  @override
  String get neverUsed => 'Ná húsáideadh';

  @override
  String get linkedRecently => 'Nasctha le déanaí';

  @override
  String get notUsedYet => 'Gan úsáid fós';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Chuaigh cuntas amháin nó níos mó in éag. Athcheangail chun rochtain a athbhunú. Má leanann sé seo ar aghaidh, seans go bhfuil d’aip Google Cloud OAuth i mód Tástála - foilsigh é chuig Táirgeadh i Google Cloud Console chun comharthaí fadtéarmacha a fháil.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Cruinneachán ceangailte agus ar fáil tar éis atosú';

  @override
  String get vaultConnectedForThisSession =>
      'cruinneachán nasctha don seisiún seo';

  @override
  String get connectAnotherAccount => 'Ceangail Cuntas Eile';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Greamaigh Comhartha Rochtana Fadsaoil athsholáthair';

  @override
  String get updateInstance => 'Nuashonrú Cás';

  @override
  String get pasteAReplacementToken => 'Greamaigh comhartha athsholáthair';

  @override
  String get replaceAccount => 'Ionadaigh Cuntas';

  @override
  String get addAccount => 'Cuir Cuntas leis';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Is féidir leis a tharmligean chuig aon ghníomhaire fála';

  @override
  String get canReceiveDelegatedTasks2 => 'in ann tascanna tarmligthe a fháil';

  @override
  String get noSyncYet => 'Níl sioncronú ann fós';

  @override
  String get noNewData => 'Gan sonraí nua';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sioncronaigh uair amháin chun do inneall a shíolrú.';

  @override
  String get lastWindowEndIsUnknown =>
      'Ní fios foirceann na fuinneoige deiridh.';

  @override
  String get lastNonEmptySync => 'Sioncronú neamhfholamh is déanaí';

  @override
  String get stopTranscribe => 'Stop & tras-scríobh';

  @override
  String get steeringMode => 'Modh stiúrtha';

  @override
  String get noMessageText => 'Gan téacs teachtaireachta';

  @override
  String get reconnectingToServer => 'Ag athcheangal leis an bhfreastalaí…';

  @override
  String get signingIn => 'Ag síniú isteach...';

  @override
  String get noGroupsFoundYet => 'Níor aimsíodh aon ghrúpa fós';

  @override
  String get onForNewGroupsOnly => 'Ar siúl do ghrúpaí nua amháin';

  @override
  String get noGroupsInThisCategory => 'Níl aon ghrúpa sa chatagóir seo';

  @override
  String get groupOrChannel => 'Grúpa nó cainéal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Tosaíonn nótaí a scríobhann tú chugat féin ar rith, agus tagann na freagraí i dtír sa chomhrá céanna. Níl feidhm ag an liosta ceadaithe anseo.';

  @override
  String get needToReply => 'Is gá freagra a thabhairt';

  @override
  String get enter2faCode => 'Íosluchtaigh cód 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Oscail d\'aip fíordheimhnitheora agus cuir isteach an cód NeoAgent reatha.';

  @override
  String get alreadyHaveAnAccountSignIn =>
      'An bhfuil cuntas agat cheana féin? Sínigh isteach';

  @override
  String get serverOnThisComputer => 'Freastalaí ar an ríomhaire seo';

  @override
  String get showQrCode => 'Taispeáin cód QR';

  @override
  String get createAnotherNeoagentAccount => 'Cruthaigh cuntas NeoAgent eile.';

  @override
  String get canCoordinateDelegatedWork =>
      'Is féidir leis an obair tharmligthe a chomhordú';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'Níorbh fhéidir cartlann ama rite NeoAgent a bhaint as.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'Níorbh fhéidir cartlann ama rite NeoAgent a léamh.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'Tá cosán neamhshábháilte i gcartlann ama rite NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'Tá nasc neamhshábháilte i gcartlann ama rite NeoAgent.';

  @override
  String get installingAppPackageOnThePhone =>
      'Suiteáil an pacáiste app ar an teileafón ...';

  @override
  String get dragAndDropAApkOrApks =>
      'Tarraing agus scaoil comhad .apk nó .apks anseo, nó cliceáil chun brabhsáil.';

  @override
  String get releaseToInstallThisPackage =>
      'Scaoileadh chun an pacáiste seo a shuiteáil';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'Níorbh fhéidir an eochair shlándála a úsáid.';

  @override
  String get connecting => 'Ag nascadh…';

  @override
  String get changes => 'Athruithe';

  @override
  String get runtimeReady => 'Am rite réidh';

  @override
  String get saving => 'Ag sábháil...';

  @override
  String get earlier => 'Níos luaithe';

  @override
  String get monthJan => 'Ean';

  @override
  String get monthFeb => 'Feabh';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Aibreán';

  @override
  String get monthMay => 'Bealtaine';

  @override
  String get monthJun => 'Meitheamh';

  @override
  String get monthJul => 'Iúil';

  @override
  String get monthAug => 'Lúnasa';

  @override
  String get monthSep => 'Meán Fómhair';

  @override
  String get monthOct => 'Deireadh Fómhair';

  @override
  String get monthNov => 'Samhain';

  @override
  String get monthDec => 'Dec';

  @override
  String get steeringWord => 'Stiúradh';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Aistríonn sé seo an t-inneall ón gcainéal $arg1 go dtí an cainéal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Fianán $arg1 allmhairithe';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s ó shin';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Stiúradh scuaine: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'Níorbh fhéidir leis an aip gréasáin inneall NeoAgent a bhaint amach.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'Chuir an brabhsálaí bac ar iarratas riachtanach mar gheall ar Bheartas Slándála Inneachair.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 de 4 ceadaithe';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Oibrigh tríd an tasc mar a dhéanfá de ghnáth.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Athruithe · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'An gléas seo · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Shroich an teorainn $arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Tá cóid aisghabhála $arg1 fós ar fáil.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Eochair shlándála $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Seisiún reatha';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nAn uair dheireanach a úsáideadh: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Ag obair i $arg1 ar an ngléas seo. Léann NeoAgent an fillteán go díreach agus cuireann sé in eagar é agus féadann sé orduithe a rith, apps a oscailt agus an scáileán a úsáid.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Ag obair do $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Ceadaithe ag $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Cúlghaireadh naisc cuireadh $arg1 ó $arg2';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Cuir leis na daoine agus na grúpaí ar cheart do $arg1 labhairt leo';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Cuir leis na daoine agus na grúpaí a bhfuil cead ag $arg1 labhairt leo.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Nuair a éisteann $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 uaireadóirí na háiteanna seo le haghaidh tagairtí. Is féidir le duine ar bith postáil anseo, mar sin tá a gceadú féin ag teastáil ó dhaoine fós thíos.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Is féidir leis na daoine seo iarraidh ar $arg1 cibé áit a chlibeann siad é. Ní áirítear róil ach sna háiteanna a liostaítear thuas.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Ach amháin nuair a chlibtear $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Ar siúl do gach grúpa $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return 'Ní éisteann $arg1 ach le daoine agus grúpaí atá ceadaithe agat cheana féin. Ligeann sé seo do $arg1 dul isteach sa ghnáthchomhrá ansin, ní hamháin clibeanna agus freagraí.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return 'Ní éisteann $arg1 ach le daoine agus grúpaí atá ceadaithe agat cheana féin. Ní roghnaíonn sé seo ach cé acu de na grúpaí sin ar cheart dó a bheith páirteach ann.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Má chlibeann duine éigin $arg1 nó má fhreagraíonn sé, freagraíonn $arg1 i gcónaí. Cuir é seo ar siúl más ceart do $arg1 clingeadh isteach ar chomhrá gnáthghrúpa freisin.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Ligfidh grúpaí nua do $arg1 dul isteach i ngnáthchomhrá le daoine ceadaithe, go dtí go gcuirfidh tú as iad.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Ligfidh grúpaí nua do $arg1 páirt a ghlacadh sa ghnáthchomhrá go dtí go gcuirfidh tú as iad.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Fanann grúpaí nua ciúin mura ndéanann duine ceadaithe clibeáil $arg1, go dtí go gcuirfidh tú ar siúl iad.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Go dtí go ndéanann duine ceadaithe clibeáil $arg1, ach amháin má chuireann tú grúpa ar siúl';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Nuair a bhíonn $arg1 clibáilte amháin, mura gcuireann tú grúpa ar siúl';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return 'Téann grúpaí $arg1 ó $arg2 i dteagmháil le gnáthchomhrá le daoine ceadaithe';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Ní cheadaíonn sé seo daoine nua. Faigheann clibeanna agus freagraí ó dhaoine faofa freagra i gcónaí. Cuir grúpa ar siúl ar cheart do $arg1 dul isteach sa ghnáthchomhrá ansin freisin.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Ní cheadaíonn sé seo daoine nua. Cuir grúpa ar siúl ar cheart do $arg1 dul isteach sa ghnáthchomhrá le daoine a d\'fhormheas tú cheana.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Faigheann clibeanna agus freagraí freagra i gcónaí. Cuir grúpa ar siúl ar cheart do $arg1 dul isteach sa ghnáthchomhrá ansin freisin.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return 'Téann $arg1 i dteagmháil le gnáthchomhrá le daoine ceadaithe';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return 'Is féidir le $arg1 páirt a ghlacadh i ngnáthchomhrá';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return 'Ní fhreagraíonn $arg1 ach amháin nuair a chlibeann duine ceadaithe é';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Níl aon rud breise ag teastáil. Ceangail chun tús a chur le $arg1 a úsáid.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Athnuachan i ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Cláraigh le $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Níl aon chuimhní nasctha le \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (réamhshocraithe)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Brainse: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return 'Ní cheanglaíonn $arg1 ach na grúpaí agus na cainéil a chuireann tú leis thíos.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return 'Tá gá le $arg1 chun sonraí ama rite NeoAgent a aimsiú.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[réamhamharc teasctha, beart iomlán $arg1]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[déantán teorantach, bearta iomlán $arg1]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' i $arg1';
  }

  @override
  String get worldNews => 'Nuacht an Domhain';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Rith nuair a thagann ceannlínte domhanda nua le feiceáil. Socraíonn do leid cibé an dtabharfar fógra duit.';

  @override
  String get newsKeywordsOptional => 'Eochairfhocail (roghnach)';

  @override
  String get worldNewsSetup => 'Socrú Nuacht an Domhain';

  @override
  String get connectWorldNewsWithGnews =>
      'Cuir eochair API GNews leis (plean saor in aisce ar fáil ag gnews.io). Déantar é a stóráil criptithe agus úsáidtear é chun príomh-cheannlínte a vótaíocht maidir le truicearairí World News.';

  @override
  String get gnewsApiKey => 'Eochair GNews API';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Greamaigh eochair API athsholáthair GNews';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Fág an eochair folamh chun an eochair atá stóráilte faoi láthair a choinneáil.';

  @override
  String get gnewsApiKeyIsRequired => 'Tá eochair API GNews ag teastáil.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Níorbh fhéidir socrú World News a shábháil.';

  @override
  String get disconnectWorldNews => 'Dícheangail World News';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Baineann sé seo an eochair GNews API atá stóráilte. Stopfaidh truicearairí World News ag lámhaigh go dtí go gcuirfidh tú eochair leis arís.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Níorbh fhéidir World News a dhícheangal.';

  @override
  String get systemOneModels => 'Samhlacha SystemOne';

  @override
  String get systemOneAuto => 'Auto';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Roghnaíonn sé an tsamhail SystemOne is fearr atá ar fáil';

  @override
  String get systemOneOffTheChatModelDecides =>
      'Déanann an tsamhail comhrá na cinntí seo';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Samhlacha cinnteoireachta a dhéanann na glaonna ar chúl an radhairc i gcodán de shoicind: dul i mbun comhráite grúpa agus céimeanna brabhsálaí. Scríobhann do mhúnla comhrá gach freagra fós.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'Socraíonn samhail SystemOne cathain is ceart labhairt agus é ar siúl; is é an tsamhail seo an t-aischur.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 scóráilte ag SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'Scóráil SystemOne an teachtaireacht seo go díreach. Níor rith aon mhúnla teanga.';

  @override
  String get systemOneUnavailable => 'Níl SystemOne ar fáil';

  @override
  String get systemOneAdminAvailability =>
      'Samhlacha cinnteoireachta is féidir le gníomhairí roghnú faoi Socruithe › Múnlaí. Fágann samhail atá múchta anseo an roghnóir sin, agus titeann gníomhairí a roghnaigh é ar ais go Auto. Cé go bhfuil aon mhúnla múchta, múchtar samhlacha SystemOne a chuireann soláthraithe isteach níos déanaí freisin.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Níl samhlacha SystemOne ann fós. Cuir eochair TypeSafe nó OpenRouter leis faoi Soláthraithe, nó tarraing samhail cinnidh mar nimble in Ollama 0.35 nó níos déanaí.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Níl aon mhúnla SystemOne ar fáil fós. Cuir eochair TypeSafe nó OpenRouter leis faoi Socruithe › Múnlaí › Beir leat d’eochair féin, nó tarraing múnla cinnidh mar nimble in Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone córas amháin samhlacha cinneadh jev typesafe openrouter ollama infhaighteacht chumas dhíchumasú';

  @override
  String get chatModels => 'Samhlacha comhrá';

  @override
  String get disabled => 'Díchumasaithe';

  @override
  String get enableShown => 'Cumasaigh léirithe';

  @override
  String get disableShown => 'Taispeántar díchumasaigh';

  @override
  String get expandAll => 'Leathnaigh go léir';

  @override
  String get collapseAll => 'Laghdaigh go léir';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 athruithe gan sábháil';
  }

  @override
  String get settingsScopeAllAgents => 'Gach gníomhairí';

  @override
  String get settingsScopeAgent => 'An gníomhaire seo';

  @override
  String get settingsScopeApp => 'App';

  @override
  String get settingsScopeAccountHint =>
      'Mar an gcéanna i ngach áit a shíníonn tú isteach';

  @override
  String get settingsScopeAllAgentsHint => 'Roinnte ag do ghníomhairí go léir';

  @override
  String get settingsAppliesTo => 'Baineann le';

  @override
  String get settingsSaving => 'Ag sábháil…';

  @override
  String get settingsSavedAutomatically =>
      'Sábhálann athruithe go huathoibríoch';

  @override
  String get settingsSearchHint => 'Cuardaigh gach socrú';

  @override
  String get settingsPageProfile => 'Próifíl';

  @override
  String get settingsPageSecurity => 'Síniú isteach & slándáil';

  @override
  String get settingsPageUsage => 'Úsáid';

  @override
  String get settingsPagePermissions => 'Ceadanna';

  @override
  String get settingsPageComputer => 'Ríomhaire & Gréasán';

  @override
  String get settingsPageBehavior => 'Iompar';

  @override
  String get settingsPageSystem => 'Córas';

  @override
  String get settingsPagePlatforms => 'Ardáin';

  @override
  String get settingsPageProfileDescription =>
      'D’ainm agus do ríomhphost, cóip de do shonraí, agus síniú amach.';

  @override
  String get settingsPageSecurityDescription =>
      'Pasfhocal, fíordheimhniú dhá fhachtóir, eochracha slándála agus an áit a bhfuil tú sínithe isteach.';

  @override
  String get settingsPageUsageDescription =>
      'Do theorainneacha agus do chaiteachas comharthaí, ar fad in aon áit amháin.';

  @override
  String get settingsPageAgentsDescription =>
      'Cruthaigh gníomhairí agus roghnaigh cé acu ceann a fhreagraíonn de réir réamhshocraithe.';

  @override
  String get settingsPagePermissionsDescription =>
      'Cad is féidir le do ghníomhairí a dhéanamh gan iarraidh ort ar dtús.';

  @override
  String get settingsPageComputerDescription =>
      'An ríomhaire a n-oibríonn do ghníomhairí air agus na suíomhanna ar féidir leo léamh mar tú féin.';

  @override
  String get settingsPageModelsDescription =>
      'Cé na múnlaí a úsáideann an gníomhaire seo, agus na heochracha API a íocann astu.';

  @override
  String get settingsPageBehaviorDescription =>
      'Conas a labhraíonn an gníomhaire seo agus conas a léann sé comhrá grúpa.';

  @override
  String get settingsPageVoiceDescription =>
      'Glaonna beo, deachtú agus freagraí ó bhéal don ghníomhaire seo.';

  @override
  String get settingsPageMessagingDescription =>
      'Cén áit ar féidir le daoine teacht ar an ngníomhaire seo agus conas a iompraíonn sé i gcomhráite.';

  @override
  String get settingsPageGeneralDescription =>
      'Cuma, teanga, crios ama agus cad a dhéanann an aip seo sa chúlra.';

  @override
  String get settingsPageSystemDescription =>
      'An freastalaí a úsáideann an fhuinneog seo, an ceann ar an ríomhaire seo, agus nuashonruithe aipeanna.';

  @override
  String get settingsYourAgents => 'Do ghníomhairí';

  @override
  String get settingsChatModel => 'Múnla comhrá';

  @override
  String get settingsChatModelDescription =>
      'Freagraíonn do theachtaireachtaí.';

  @override
  String get settingsSubAgentModel => 'Múnla fo-ghníomhaire';

  @override
  String get settingsSubAgentModelDescription =>
      'Ritheann sé obair a thugtar amach le linn taisc.';

  @override
  String get settingsDefaultModels => 'Samhlacha réamhshocraithe';

  @override
  String get settingsDefaultModelsDescription =>
      'Úsáidtear é nuair nach roghnaíonn comhrá nó tasc a mhúnla féin.';

  @override
  String get settingsModelPool => 'Samhail linn snámha';

  @override
  String get settingsApiKeysDescription =>
      'Bain úsáid as d\'eochracha nó críochphointe féin don ghníomhaire seo. Tá eochracha criptithe agus ní thaispeántar iad arís.';

  @override
  String get settingsPersona => 'Pearsa';

  @override
  String get settingsFineTuning => 'Mionchoigeartú';

  @override
  String get settingsFineTuningDescription =>
      'Is annamh a theastaíonn. Oireann na réamhshocruithe don chuid is mó de na comhráite.';

  @override
  String get settingsShow => 'Taispeáin';

  @override
  String get settingsHide => 'Folaigh';

  @override
  String get settingsMinimumContribution => 'Íosluach ranníocaíochta';

  @override
  String get settingsBatchWindow => 'Fuinneog bhaisc seomra';

  @override
  String get settingsBatchWindowDescription =>
      'Fanann sé seo le fada chun déileáil le teachtaireachtaí gasta mar aon seal amháin.';

  @override
  String get settingsHandsFree => 'Lámha-saor in aisce';

  @override
  String get settingsHandsFreeDescription =>
      'Labhair faoi shaoirse agus idirbhriseadh ag am ar bith.';

  @override
  String get settingsPushToTalkDescription =>
      'Coinnigh chun labhairt, scaoileadh a sheoladh.';

  @override
  String get settingsLiveVoice => 'Guth beo';

  @override
  String get settingsChannels => 'Cainéil';

  @override
  String get settingsGroupChats => 'I gcomhráite grúpa';

  @override
  String get settingsGroupChatsDescription =>
      'Conas a iompraíonn an gníomhaire seo i ngrúpaí ar gach cainéal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Cuir modúil iompraíochta ar siúl in Iompar chun iad seo a athrú.';

  @override
  String get settingsParticipationAutomatic => 'Uathoibríoch';

  @override
  String get settingsParticipationMentionOnly => 'Luaigh amháin';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Léann sé an seomra agus glacann sé isteach nuair a bhíonn rud úsáideach le cur leis.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Freagraí nuair a luaitear nó nuair a thugtar freagra orthu.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Freagraí ar gach teachtaireacht.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Roinntear freagraí níos faide ina dteachtaireachtaí gearra, mar a dhéanfadh duine.';

  @override
  String get settingsDeliverySingleDescription =>
      'Seoltar gach freagra mar aon teachtaireacht amháin.';

  @override
  String get settingsComputerStatus => 'Stádas';

  @override
  String get settingsTest => 'Tástáil';

  @override
  String get settingsAppearance => 'Dealramh';

  @override
  String get settingsTheme => 'Téama';

  @override
  String get settingsThemeSystem => 'Córas';

  @override
  String get settingsThemeLight => 'Geal';

  @override
  String get settingsThemeDark => 'Dorcha';

  @override
  String get settingsCloseWindow => 'Nuair a dhúnann tú an fhuinneog';

  @override
  String get settingsCloseAsk => 'Iarr';

  @override
  String get settingsCloseKeepRunningDescription =>
      'Coinníonn NeoAgent ag rith sa chúlra agus fanann sé inrochtana.';

  @override
  String get settingsCloseQuitDescription => 'Scoirfidh NeoAgent go hiomlán.';

  @override
  String get settingsPhoneTriggers => 'Trucailí fón';

  @override
  String get settingsPhoneTriggersDescription =>
      'Comharthaí a sheolann an guthán seo chuig do ghníomhairí ionas gur féidir le tascanna freagairt dóibh.';

  @override
  String get settingsLocationTriggers => 'Truicear suímh';

  @override
  String get settingsLocationTriggersDescription =>
      'Seiceálann sé do shuíomh timpeall gach cúpla nóiméad i gcoinne na n-áiteanna a bhféachann do thascanna orthu.';

  @override
  String get settingsNotificationTriggers => 'Spreagann fógra';

  @override
  String get settingsNotificationTriggersDescription =>
      'Cuir fógraí ó aipeanna eile ar an nguthán seo ar aghaidh chuig do ghníomhairí.';

  @override
  String get settingsSetup => 'Socrú';

  @override
  String get settingsOnboarding => 'Ar bordáil';

  @override
  String get settingsOnboardingDescription =>
      'Siúil tríd an socrú chéad-reáchtáil arís. Níl aon rud a bhunaigh tú caillte.';

  @override
  String get settingsUsernameDescription =>
      'Úsáidte chun síniú isteach. Ní féidir é a athrú.';

  @override
  String get settingsExport => 'Easpórtáil';

  @override
  String get settingsLeave => 'Sínigh amach agus scrios';

  @override
  String get settingsSignOutDescription =>
      'Síníonn sé amach tú ar an ngléas seo amháin.';

  @override
  String get settingsDeleteAccountDescription =>
      'Scriosann sé do chuntas, gníomhairí, cuimhne agus socruithe. Ní féidir é seo a chealú.';

  @override
  String get settingsTokenUsage => 'Úsáid comhartha';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Níl aon socrú ag teacht le “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count toradh',
      many: '$count dtoradh',
      few: '$count thoradh',
      two: '$count thoradh',
      one: '$count toradh',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Ardsocruithe múnla';

  @override
  String get settingsAdvancedModelsDescription =>
      'Roghnach. Pin samhail le haon chineál oibre; glacann sé ar láimh aon uair a úsáideann an gníomhaire na huirlisí sin. Leanann aon rud a fhágtar de réir réamhshocraithe an tsamhail chomhrá.';

  @override
  String get settingsTaskModelDefault => 'Réamhshocrú';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Leanann an múnla comhrá';

  @override
  String get settingsTaskModelCoding => 'Códú';

  @override
  String get settingsTaskModelCodingDescription =>
      'Scríobh, eagarthóireacht agus cód dífhabhtaithe.';

  @override
  String get settingsTaskModelComputerUse => 'Úsáid ríomhaire';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Tiomáint an bhrabhsálaí agus an deasc.';

  @override
  String get settingsTaskModelAndroidUse => 'Úsáid Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Feidhmchláir ar ghléas Android nó aithriseoir.';

  @override
  String get settingsTaskModelResearch => 'Taighde';

  @override
  String get settingsTaskModelResearchDescription =>
      'Foinsí a chuardach, a léamh agus a achoimriú.';

  @override
  String get knowledgeGraphHint =>
      'Na heintitis is mó a luaitear, daite de réir braisle. Ceanglaíonn línte aonáin atá le feiceáil sna cuimhní cinn céanna. Tapáil ceann amháin chun a naisc agus a chuimhní cinn a fheiceáil; tarraing go pan, pinch nó Ctrl/⌘-scrollaigh chun zúmáil.';

  @override
  String get linkedEntities => 'Aonáin nasctha';

  @override
  String get noLinkedEntities => 'Níl sé nasctha le haonáin eile fós.';

  @override
  String mentionsArg1(int arg1) {
    return 'Luann $arg1';
  }

  @override
  String get entityKindConcept => 'Coincheap';

  @override
  String get entityKindDomain => 'Fearann';

  @override
  String get entityKindEmail => 'Ríomhphost';

  @override
  String get entityKindLink => 'Nasc';

  @override
  String get entityKindFile => 'Comhad';

  @override
  String get entityKindAcronym => 'Acrainm';

  @override
  String get entityKindIdentifier => 'Aitheantóir';

  @override
  String get entityKindVersion => 'Leagan';

  @override
  String get openFullscreen => 'Oscail scáileán iomlán';

  @override
  String get zoomIn => 'Súmáil isteach';

  @override
  String get zoomOut => 'Súmáil amach';

  @override
  String get searchEntities => 'Faigh eintiteas';

  @override
  String get incomingCall => 'Glao isteach';

  @override
  String get answerCall => 'Freagra';

  @override
  String get callMeLater => 'Glaoigh orm níos déanaí';

  @override
  String get callingEllipsis => 'Ag glaoch…';

  @override
  String get reconnectingCall => 'Ag athcheangal';

  @override
  String get agentWorking => 'Ag obair';

  @override
  String get micMuted => 'Balbhaithe';

  @override
  String get speakerphone => 'Cainteoir';

  @override
  String get muteMic => 'Balbhaigh';

  @override
  String get unmuteMic => 'Díbhalbhaigh';

  @override
  String get releaseToSend => 'Scaoileadh le seoladh';

  @override
  String get callEnded => 'Cuireadh deireadh leis an nglao';

  @override
  String get openConversation => 'Oscail comhrá';

  @override
  String get callBack => 'Glaoigh ar ais';

  @override
  String get letCallsReachYou => 'Lig glaonna a shroicheadh tú';

  @override
  String get callPermissionsIntro =>
      'Is féidir le do ghníomhairí glaoch ort. Chun glaoch ar nós glao gutháin agus NeoAgent sa chúlra nó go bhfuil do ghuthán glasáilte, teastaíonn iad seo uaidh.';

  @override
  String get showOverOtherApps => 'Taispeáin thar aipeanna eile';

  @override
  String get showOverOtherAppsDetail =>
      'Tugann sé an scáileán glaonna suas cibé áit a bhfuil tú.';

  @override
  String get fullScreenCalls => 'Glaonna lánscáileáin';

  @override
  String get fullScreenCallsDetail => 'Fáinní thar an scáileán glas.';

  @override
  String get unrestrictedBattery => 'Ceallraí gan srian';

  @override
  String get unrestrictedBatteryDetail =>
      'Coinníonn NeoAgent ceangailte ionas go dtagann glaonna.';

  @override
  String get permissionAllowed => 'Ceadaithe';

  @override
  String get triggerSectionCalendar => 'Féilire';

  @override
  String get triggerSectionFiles => 'Comhaid agus doiciméid';

  @override
  String get triggerSectionHome => 'Baile agus na meáin';

  @override
  String get triggerSectionDevices => 'Gléasanna agus áiteanna';

  @override
  String get triggerSectionTasks => 'Tascanna';

  @override
  String get messagingMemberJoined => 'Chuaigh ball isteach';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Rith nuair a théann duine éigin isteach i bhfreastalaí Discord, grúpa Telegram nó WhatsApp, cainéal Slack, nó seomra Maitrís.';

  @override
  String get messagingMemberLeft => 'D\'imigh ball';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Rith nuair a fhágann duine éigin freastalaí Discord, grúpa Telegram nó WhatsApp, cainéal Slack, nó seomra Maitrís.';

  @override
  String get messagingReactionAdded => 'Frithghníomh curtha leis';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Rith nuair a imoibríonn duine ceadaithe do theachtaireacht i gcomhrá príobháideach.';

  @override
  String get messagingPlatformDisconnected => 'Teachtaireachtaí dícheangailte';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Rith nuair a stopann nasc teachtaireachtaí agus nuair a bhíonn tú ag teastáil uait, mar shampla tar éis logáil amach.';

  @override
  String get googleCalendarEventStarting => 'Imeacht Google Calendar ag tosú';

  @override
  String get googleCalendarEventCreated => 'Imeacht Google Calendar cruthaithe';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Rith nuair a thagann imeacht nó cuireadh nua le feiceáil.';

  @override
  String get outlookCalendarEventStarting => 'Imeacht Féilire Outlook ag tosú';

  @override
  String get nextcloudCalendarEventStarting =>
      'Imeacht Féilire Nextcloud ag tosú';

  @override
  String get runMinutesBeforeEachEvent =>
      'Rith líon socraithe nóiméad roimh gach imeacht.';

  @override
  String get googleDriveFileAdded => 'Cuireadh comhad Google Drive leis';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Rith nuair a chuirtear comhad le Drive nó fillteán ann.';

  @override
  String get googleSheetsRowAdded => 'Sraith Google Sheets curtha leis';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Rith nuair a bhíonn sraitheanna nua le feiceáil ar bhileog.';

  @override
  String get onedriveFileAdded => 'comhad OneDrive curtha leis';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Rith nuair a chuirtear comhad le fillteán OneDrive.';

  @override
  String get nextcloudFileAdded => 'Cuireadh comhad Nextcloud leis';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Rith nuair a chuirtear comhad le fillteán Nextcloud.';

  @override
  String get nextcloudShareReceived => 'Comhad Nextcloud roinnte leat';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Rith nuair a roinneann duine comhad nó fillteán leat.';

  @override
  String get notionItemAdded => 'Cuireadh mír bhunachar sonraí notion leis';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Rith nuair a chuirtear mír le bunachar sonraí Notion.';

  @override
  String get notionItemUpdated => 'Nuashonraíodh mír bhunachar sonraí notion';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Rith nuair a athraíonn mír i mbunachar sonraí Notion.';

  @override
  String get trelloCardEnteredList => 'Cárta Trello curtha leis an liosta';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Rith nuair a chruthaítear cárta nó nuair a bhogtar isteach i liosta é.';

  @override
  String get figmaCommentAdded => 'Nóta tráchta Figma curtha leis';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Rith nuair a dhéanann duine trácht ar chomhad Figma.';

  @override
  String get githubPrOpened => 'Osclaíodh iarratas tarraingt GitHub';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Rith nuair a osclaítear iarratas tarraingthe nua i stór.';

  @override
  String get githubWorkflowRunFailed => 'Theip ar rith sreabhadh oibre GitHub';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Rith nuair a theipeann ar rith Gníomhartha GitHub.';

  @override
  String get githubCommitPushed => 'GitHub tiomantas bhrú';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Rith nuair a shroicheann gealltanais nua brainse.';

  @override
  String get mcpServerFailed => 'Theip ar fhreastalaí MCP';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Rith nuair a theipeann ar fhreastalaí MCP a bhí ag obair nó nuair a theastaíonn síniú isteach.';

  @override
  String get homeAssistantStateChanged => 'Athraíodh staid Cúntóir Baile';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Rith nuair a athraíonn aonán, nuair a shroicheann sé stát, nó nuair a thrasnaíonn sé luach.';

  @override
  String get spotifyTrackChanged => 'D\'athraigh rian Spotify';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Rith nuair a thosaíonn rian eile ag imirt.';

  @override
  String get neorecallDailySummaryReady => 'NeoRecall achoimre laethúil réidh';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Rith nuair a bhíonn an achoimre ar lá deiridh.';

  @override
  String get neorecallConversationRecorded => 'Taifeadadh comhrá NeoRecall';

  @override
  String get runWhenARecordedConversationEnds =>
      'Rith nuair a chríochnaíonn comhrá taifeadta.';

  @override
  String get geofenceTrigger => 'Geofence suíomh';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Rith nuair a shroicheann do ghuthán áit nó nuair a fhágann sé áit. Riachtanais suíomh a rianú ar an teileafón.';

  @override
  String get healthMetricRecorded => 'Taifeadadh méadrach sláinte';

  @override
  String get runWhenAHealthReadingArrives =>
      'Rith nuair a thagann léamh sláinte sioncronaithe, go roghnach os cionn luach nó faoi bhun luacha.';

  @override
  String get wearableConnectionChanged =>
      'Inchaite ceangailte nó dícheangailte';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Rith nuair a nascann nó nuair a dhícheanglaíonn do ghléas inchaite.';

  @override
  String get taskRunFinished => 'Chríochnaigh tasc eile';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Rith tar éis tasc eile a chríochnú, a éiríonn, nó go mainneoidh sé.';

  @override
  String get appPackageOptional => 'Pacáiste aip (roghnach)';

  @override
  String get appPackageHelper => 'Mar shampla com.whatsapp';

  @override
  String get anyPlatform => 'Aon ardán';

  @override
  String get spaceIdOptional =>
      'Aitheantas an fhreastalaí, an ghrúpa, an chainéil nó an tseomra (roghnach)';

  @override
  String get spaceIdHelper =>
      'Uaireadóirí folamh gach ceann ina bhfuil an bot.';

  @override
  String get emojiOptional => 'Emoji (roghnach)';

  @override
  String get chatIdOptional => 'ID Comhrá (roghnach)';

  @override
  String get platformOptional => 'Ardán (roghnach)';

  @override
  String get platformOptionalHelper =>
      'Mar shampla whatsapp. Uaireadóirí folamh ar fad.';

  @override
  String get minutesBefore => 'Nóiméad roimh';

  @override
  String get calendarIdOptional => 'Aitheantas Féilire (roghnach)';

  @override
  String get calendarIdHelper => 'Úsáideann Folamh do phríomhfhéilire.';

  @override
  String get invitesOnly => 'Cuirí ó dhaoine eile amháin';

  @override
  String get nextcloudCalendarPath => 'Féilire';

  @override
  String get nextcloudCalendarPathHelper =>
      'A ainm i liosta féilire Nextcloud, pearsanta mar shampla';

  @override
  String get folderIdOptionalHelperDrive => 'Folamh uaireadóirí Drive ar fad.';

  @override
  String get folderIdOptionalHelperOnedrive =>
      'Folamh uaireadóirí an fillteán fhréamh.';

  @override
  String get driveFolderIdOptional => 'Aitheantas fillteáin (roghnach)';

  @override
  String get spreadsheetId => 'ID Scarbhileog';

  @override
  String get sheetRange => 'Raon';

  @override
  String get sheetRangeHelper => 'Colúin an tábla, mar shampla Bileog 1!A:E';

  @override
  String get folderPathOptional => 'Conair fillteáin (roghnach)';

  @override
  String get folderPathHelper => 'Doiciméid mar shampla';

  @override
  String get notionDatabaseId => 'ID bunachar sonraí';

  @override
  String get trelloListId => 'Aitheantas an liosta';

  @override
  String get figmaFileKey => 'Eochair comhaid';

  @override
  String get figmaFileKeyHelper => 'Ón nasc comhaid: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Stór';

  @override
  String get workflowOptional => 'Sreabhadh oibre (roghnach)';

  @override
  String get workflowHelper => 'Ainm comhaid ar nós ci.yml';

  @override
  String get branchOptional => 'Brainse (roghnach)';

  @override
  String get branchHelper => 'Úsáideann Folamh an brainse réamhshocraithe.';

  @override
  String get mcpServerIdOptional => 'Aitheantas an fhreastalaí MCP (roghnach)';

  @override
  String get entityId => 'Aitheantas aonáin';

  @override
  String get entityIdHelper => 'Mar shampla binary_sensor.front_door';

  @override
  String get targetStateOptional => 'Staid sprice (roghnach)';

  @override
  String get targetStateHelper => 'Mar shampla ar';

  @override
  String get aboveOptional => 'thuas (roghnach)';

  @override
  String get belowOptional => 'Thíos (roghnach)';

  @override
  String get placeName => 'Ainm áite';

  @override
  String get latitude => 'Domhanleithead';

  @override
  String get longitude => 'Domhanfhad';

  @override
  String get radiusMeters => 'Ga i méadair';

  @override
  String get geofenceTransition => 'Cathain';

  @override
  String get arriving => 'Ag teacht';

  @override
  String get leaving => 'Ag fágáil';

  @override
  String get healthMetric => 'Méadrach sláinte';

  @override
  String get healthMetricHelper => 'Mar shampla heart_rate, céimeanna, meáchan';

  @override
  String get wearableTransition => 'Nuair a bheidh an wearable';

  @override
  String get wearableConnects => 'Nascann';

  @override
  String get wearableDisconnects => 'Dínascann';

  @override
  String get sourceTask => 'Tar éis tasc';

  @override
  String get taskOutcome => 'Toradh';

  @override
  String get anyOutcome => 'Toradh ar bith';

  @override
  String get succeeded => 'D\'éirigh';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return 'Tá $arg1 in easnamh nó níl sé bailí.';
  }

  @override
  String get triggerSectionMessaging => 'teachtaireachtaí';

  @override
  String get triggerSectionDeveloper => 'Forbróir';

  @override
  String get triggerSectionMemory => 'Cuimhne';

  @override
  String get triggerSectionNews => 'Nuacht';

  @override
  String get triggerSectionSystem => 'Córas';

  @override
  String get searchTriggersHint => 'Cuardach truicear, aipeanna nó imeachtaí';

  @override
  String get noTriggersMatch => 'Ní mheaitseálann aon truicear do chuardach.';

  @override
  String get triggerAccountMissing => 'Níl aon chuntas fós';

  @override
  String get pickTriggerKeyboardHint => 'Cuir isteach picks an chéad toradh';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return '$arg1 triggers';
  }

  @override
  String get addFromSkillsSh => 'Cuir ó scileanna.sh';

  @override
  String get skillsShHint =>
      'Cuardaigh thuas chun scileanna a fháil ar skills.sh, nó greamaigh nasc skills.sh nó ordú `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Níl aon scileanna scileanna.sh ag teacht leis an gcuardach seo.';

  @override
  String get installingSkill => 'Ag suiteáil…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Suiteáilte $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Suiteáil $arg1';
  }

  @override
  String get authVerify => 'Fíoraigh';

  @override
  String get authCreateAccount => 'Cruthaigh cuntas';

  @override
  String get authNewInviteLink => 'Nasc cuireadh nua';

  @override
  String get authShowPassword => 'Taispeáin pasfhocal';

  @override
  String get authHidePassword => 'Folaigh pasfhocal';

  @override
  String get authPasswordWillBeRejected => 'ró-lag a bheidh, a dhiúltú';

  @override
  String get authUsernameTooShort =>
      'Tá 3 charachtar ar a laghad ag teastáil ó ainmneacha úsáideoirí.';

  @override
  String get authUsernameTaken =>
      'Tá an t-ainm úsáideora sin glactha cheana féin.';

  @override
  String get authSignupsClosed =>
      'Tá clárúcháin dúnta ar an bhfreastalaí seo. Iarr cuntas ar an riarthóir.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Ní ghlacann an freastalaí seo ach le síniú isteach thar HTTPS. Oscail $arg1 ina ionad sin.';
  }

  @override
  String get authInsecureTransport =>
      'Ní ghlacann an freastalaí seo ach le síniú isteach thar HTTPS. Ceangail leis le seoladh https://.';

  @override
  String get authAccountNotFound => 'Níl an cuntas sin ann a thuilleadh.';

  @override
  String get authQrRateLimited =>
      'An iomarca iarratas síniú isteach QR. Fan nóiméad, ansin athnuachan an cód.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Dearmad déanta agat ar do phasfhocal? Iarr ar riarthóir do fhreastalaí é a athshocrú i Riarachán → Úsáideoirí.';

  @override
  String get authChangeServer => 'Athraigh freastalaí';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Ag síniú isteach ar $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Ní fhreagraíonn an seoladh seo mar fhreastalaí NeoAgent. Seiceáil an URL agus bain triail eile as.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Níorbh fhéidir nasc slán (HTTPS) le $arg1 a oscailt.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Níorbh fhéidir $arg1 a bhaint amach thar HTTPS, agus níor fhreagair HTTP simplí ach an oiread. Seiceáil an seoladh agus an port.';
  }

  @override
  String get adminResetPassword => 'Athshocraigh pasfhocal';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Athshocraigh pasfhocal le haghaidh $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Roghnaigh pasfhocal nua le haghaidh $arg1. Déanfar iad a shíniú amach ar gach gléas agus síniú isteach arís leis an bpasfhocal seo.';
  }

  @override
  String get adminNewPassword => 'Pasfhocal nua';

  @override
  String get adminSetPassword => 'Socraigh pasfhocal';

  @override
  String get authMissingFields => 'Líon isteach gach réimse riachtanach.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 athshocrú an focal faire de $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Pasfhocal nuashonraithe; síníodh an t-úsáideoir amach i ngach áit.';

  @override
  String get authSignInTitle => 'Sínigh isteach chuig NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Scan le do ghuthán, nó úsáid do phasfhocal.';

  @override
  String get authOrUsePassword => 'nó bain úsáid as do phasfhocal';

  @override
  String get qrLoginWaitingTitle => 'Ceadaigh ar do ghuthán';

  @override
  String get qrLoginWaitingBody =>
      'Scanadh do ghuthán an cód. Deimhnigh an logáil isteach ansin chun síniú isteach a chríochnú.';

  @override
  String get qrLoginSigningInOn => 'Ag síniú isteach ar';

  @override
  String get qrLoginLocation => 'Suíomh';

  @override
  String get qrLoginWaitingForApproval => 'Ag fanacht le ceadú';

  @override
  String get qrLoginCancelAndUsePassword =>
      'Cealaigh agus bain úsáid as pasfhocal';

  @override
  String get qrLoginDeclinedOnPhone =>
      'Diúltaíodh don logáil isteach ar do ghuthán. Scan an cód nua chun triail eile a bhaint as.';

  @override
  String get signupKey => 'Eochair chlárúcháin';

  @override
  String get signupKeyStepSubtitle =>
      'Teastaíonn eochair chlárúcháin ó chuntais nua ar an bhfreastalaí seo. Cuir isteach an eochair a fuair tú ó riarthóir.';

  @override
  String get signupKeyChange => 'Athraigh';

  @override
  String get signupKeyRequiredError => 'Cuir isteach d’eochair chlárúcháin.';

  @override
  String get signupKeyInvalidError =>
      'Níl an eochair chlárúcháin sin bailí. Seiceáil í agus bain triail eile as.';

  @override
  String get signupKeyUsedError =>
      'Úsáideadh an eochair chlárúcháin sin cheana. Iarr ceann nua ar riarthóir.';

  @override
  String get adminRequireSignupKey => 'Éiligh eochair chlárúcháin';

  @override
  String get adminRequireSignupKeyHint =>
      'Teastaíonn eochair aonuaire ó riarthóir do chuntais nua. Nuair atá sé múchta, is féidir le duine ar bith a shroicheann an freastalaí seo clárú. Ní theastaíonn eochair riamh ón gcéad chuntas.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Teastaíonn eochair chlárúcháin ó chuntais nua anois.';

  @override
  String get adminSignupOpenNotice => 'Is féidir le duine ar bith clárú anois.';

  @override
  String get signupKeys => 'Eochracha clárúcháin';

  @override
  String get signupKeysDescription =>
      'Eochracha aonuaire le clárú fad is atá eochair ag teastáil. Cruthaíonn gach eochair cuntas amháin go díreach.';

  @override
  String get signupKeysNew => 'Eochracha nua';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Gan úsáid · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Úsáidte · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Cúlghairthe · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Gach ceann · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Gan úsáid';

  @override
  String get signupKeyStatusUsed => 'Úsáidte';

  @override
  String get signupKeyStatusRevoked => 'Cúlghairthe';

  @override
  String get signupKeysExport => 'Easpórtáil .txt';

  @override
  String get signupKeysCopied => 'Cóipeáladh na heochracha';

  @override
  String get signupKeyCopied => 'Cóipeáladh an eochair';

  @override
  String get signupKeysEmpty => 'Níl aon eochracha sa liosta seo.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Cruthaithe $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Úsáidte ag $arg1 ar $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Úsáidte ar $arg1 ag cuntas a scriosadh ó shin';
  }

  @override
  String get signupKeyRevokeTitle => 'An gcúlghairfear an eochair seo?';

  @override
  String get signupKeyRevokeMessage =>
      'Ní bheidh aon duine in ann clárú léi. Ní féidir é seo a chealú.';

  @override
  String get signupKeyRevoked => 'Cúlghaireadh an eochair.';

  @override
  String signupKeysShowMore(int count) {
    return 'Taispeáin $count eile';
  }

  @override
  String get signupKeysCreateTitle => 'Cruthaigh eochracha clárúcháin';

  @override
  String get signupKeysCount => 'Líon na n-eochracha';

  @override
  String get signupKeysCountHelper => '1 go 500';

  @override
  String get signupKeysCountInvalid => 'Cuir isteach uimhir ó 1 go 500.';

  @override
  String get signupKeysLabel => 'Lipéad (roghnach)';

  @override
  String get signupKeysLabelHint => 'm.sh. Tástálaithe béite an earraigh';

  @override
  String signupKeysCreateAction(int count) {
    return 'Cruthaigh ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Eochracha réidh: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Tabhair gach eochair do dhuine amháin. Fanann eochracha gan úsáid sa liosta, ionas gur féidir leat iad a chóipeáil nó a easpórtáil arís níos déanaí.';

  @override
  String get signupKeysSaveDialogTitle => 'Sábháil eochracha clárúcháin';

  @override
  String get signupKeysExported => 'Easpórtáladh na heochracha.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return 'Chruthaigh $actor eochracha clárúcháin ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return 'Chúlghair $actor eochair chlárúcháin';
  }

  @override
  String get providerChooseUsername => 'Roghnaigh d\'ainm úsáideora';

  @override
  String get providerChooseUsernameBody =>
      'Roghnaigh ainm úsáideora atá ar fáil chun do chuntas a chríochnú.';

  @override
  String get dataSharingTitle => 'Comhroinn sonraí úsáide';

  @override
  String get dataSharingDescription =>
      'Cabhraigh leo siúd a ritheann an freastalaí seo é a fheabhsú. Roinntear conas a úsáideann tú NeoAgent, ach ní roinntear riamh a scríobhann nó a stórálann tú.';

  @override
  String dataSharingSince(String date) {
    return 'Á chomhroinnt ó $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Cad a roinntear';

  @override
  String get dataSharingIncluded => 'Roinntear';

  @override
  String get dataSharingExcluded => 'Ní roinntear riamh';

  @override
  String get dataSharingIncludedDevice => 'Cineál gléis agus leagan na haipe';

  @override
  String get dataSharingIncludedLocale =>
      'Teanga na haipe agus réigiún an chriosa ama, mar shampla an Eoraip';

  @override
  String get dataSharingIncludedFeatures =>
      'Na gnéithe atá socraithe agat, mar thascanna, scileanna agus comhtháthuithe';

  @override
  String get dataSharingIncludedRuns =>
      'Na huirlisí agus na samhlacha a úsáideann do rití, le hamanna agus líon comharthaí';

  @override
  String get dataSharingIncludedActivity =>
      'Cathain a úsáideann tú NeoAgent, de réir lá na seachtaine agus uaire';

  @override
  String get dataSharingExcludedContent =>
      'Teachtaireachtaí, leideanna agus freagraí';

  @override
  String get dataSharingExcludedRuns =>
      'Teidil rití, ionchuir agus torthaí uirlisí';

  @override
  String get dataSharingExcludedFiles =>
      'Comhaid, cuimhní agus aon rud eile a stórálann tú';

  @override
  String get dataSharingExcludedIdentity =>
      'D\'ainm, do ríomhphost, do sheoladh IP agus do shuíomh';

  @override
  String get dataSharingExcludedAccounts =>
      'Na cuntais lena nascann tú comhtháthuithe';

  @override
  String get dataSharingPooledNote =>
      'Ní fheiceann riarthóirí ach iomláin do gach duine a roinneann, riamh tusa leat féin. Múch é am ar bith agus fágann tú na hiomláin láithreach.';

  @override
  String get dataSharingConfirmTitle => 'Sonraí úsáide a chomhroinnt?';

  @override
  String get dataSharingConfirmAction => 'Comhroinn';

  @override
  String get sharedUsageTitle => 'Úsáid chomhroinnte';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Cuntais a roinneann sonraí úsáide: $sharing as $total. Iomláin amháin, gan ábhar.';
  }

  @override
  String get sharedUsageEmpty =>
      'Níl aon duine ag comhroinnt sonraí úsáide fós. Is féidir é a chur ar siúl faoi Socruithe, Próifíl, Do shonraí.';

  @override
  String get sharedUsageRuns => 'Rití comhroinnte';

  @override
  String get sharedUsageAvgDuration => 'Meánfhad';

  @override
  String get sharedUsageCompletedRuns => 'Rití críochnaithe';

  @override
  String get sharedUsageStepsPerRun => 'Céimeanna in aghaidh an rith';

  @override
  String get sharedUsageDevices => 'Gléasanna';

  @override
  String get sharedUsageAppVersions => 'Leaganacha aipe';

  @override
  String get sharedUsageLanguages => 'Teangacha';

  @override
  String get sharedUsageRegions => 'Réigiúin';

  @override
  String get sharedUsageFeatures => 'Glacadh le gnéithe';

  @override
  String get sharedUsageFeaturesDescription =>
      'Sciar de na cuntais chomhroinnte a bhfuil sé socraithe acu.';

  @override
  String get sharedUsageTools => 'Uirlisí';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Na huirlisí is mó a nglaotar orthu ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Glaonna: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Theip: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Comhtháthuithe';

  @override
  String get sharedUsageMessaging => 'Cainéil teachtaireachtaí';

  @override
  String get sharedUsageTriggers => 'Conas a thosaíonn rití';

  @override
  String get sharedUsageActivity => 'Cathain a úsáidtear é';

  @override
  String get sharedUsageActivityDescription =>
      'Rití de réir lá na seachtaine agus uaire, UTC.';

  @override
  String get sharedUsageModels => 'Feidhmíocht samhlacha';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return 'meán $latency · $cached% ón taisce · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Cuntais: $count';
  }

  @override
  String get sharedUsageNoData => 'Faic sa tréimhse seo.';

  @override
  String get sharedUsageNotReported => 'Gan tuairisc fós';

  @override
  String get sharedUsageFeatureAgents => 'Níos mó ná gníomhaire amháin';

  @override
  String get sharedUsageFeatureTasks => 'Tascanna sceidealaithe';

  @override
  String get sharedUsageFeatureSkills => 'Scileanna';

  @override
  String get sharedUsageFeatureMcp => 'Freastalaithe MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Comhtháthuithe';

  @override
  String get sharedUsageFeatureMessaging => 'Cainéil teachtaireachtaí';

  @override
  String get sharedUsageFeatureMemory => 'Cuimhne';

  @override
  String get sharedUsageSearchKeywords =>
      'opt-in comhroinnt sonraí teiliméadracht gléasanna gnéithe uirlisí samhlacha gníomhaíocht';
}
