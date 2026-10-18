// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppL10nPt extends AppL10n {
  AppL10nPt([String locale = 'pt']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Bem vindo';

  @override
  String get onboardingEyebrowCommunication => 'Comunicação';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligência';

  @override
  String get onboardingEyebrowComputer => 'Computador';

  @override
  String get onboardingEyebrowAutomation => 'Automação';

  @override
  String get onboardingNext => 'Próximo';

  @override
  String get onboardingIntroCouldNotLoad =>
      'Não foi possível carregar a introdução.';

  @override
  String get onboardingModelDescription =>
      'Escolha o modelo que o NeoAgent deve usar por padrão ou deixe-o escolher automaticamente.';

  @override
  String get onboardingLoadingModels => 'Carregando modelos…';

  @override
  String get noAiModelTitle => 'Nenhum modelo de IA está configurado ainda';

  @override
  String get noAiModelBody =>
      'Adicione uma chave de API de um provedor como OpenAI, Anthropic ou Google. O NeoAgent então mostra os modelos que você pode usar.';

  @override
  String get noAiModelChatBody =>
      'O NeoAgent precisa de um modelo de IA para responder. Adicione uma chave de API de um provedor como OpenAI, Anthropic ou Google.';

  @override
  String get noAiModelAdminHint =>
      'Como administrador, você também pode configurar provedores para todos em Admin → Provedores.';

  @override
  String get addApiKey => 'Adicionar chave de API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform está conectado.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Aguardando a conexão do $platform…';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'A configuração não pôde ser salva: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Pronto';

  @override
  String get onboardingStepRequired => 'Obrigatório';

  @override
  String get onboardingStepOptional => 'Opcional';

  @override
  String get onboardingStepCloudOrLocal => 'Nuvem ou local';

  @override
  String get onboardingStepComputer => 'Computador';

  @override
  String get onboardingStepRoutines => 'Rotinas';

  @override
  String get onboardingComputerChoiceTitle => 'Onde deveria\nfuncionar?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Você pode alternar por sessão.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Sandbox privado · sempre ativado';

  @override
  String get onboardingThisComputer => 'Este computador';

  @override
  String get onboardingThisComputerSubtitle =>
      'Seus arquivos, aplicativos e navegador';

  @override
  String get onboardingSearchApps => 'Pesquisar aplicativos…';

  @override
  String get onboardingRoutinesDescription =>
      'Os resultados chegam em seus chats.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Os resultados chegam como notificações.';

  @override
  String get onboardingNotifications => 'Notificações';

  @override
  String get onboardingReadyTitle => 'Está tudo\npronto.';

  @override
  String get onboardingReadyDescription => 'Envie sua primeira mensagem.';

  @override
  String get onboardingMessageNeoagent => 'Mensagem NeoAgent';

  @override
  String get onboardingAskAnything => 'Pergunte qualquer coisa…';

  @override
  String get onboardingOpenNeoagent => 'Abra o NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planeje uma viagem de fim de semana';

  @override
  String get onboardingStarterLanding => 'Construa uma página de destino';

  @override
  String onboardingQuickSteps(int count) {
    return 'Passos rápidos $count';
  }

  @override
  String get taskNeedsEmail => 'Conecte o e-mail primeiro';

  @override
  String get taskNeedsCalendar => 'Conecte um calendário primeiro';

  @override
  String get taskNeedsModel => 'Configure primeiro um modelo de IA';

  @override
  String get taskPromptDailyRecap =>
      'Recapitule meu dia: resuma as conversas, o trabalho concluído e as decisões de hoje e, em seguida, liste tudo o que devo acompanhar amanhã. Seja breve e envie para mim.';

  @override
  String get taskPromptInboxCheck =>
      'Verifique minha caixa de entrada de e-mail em busca de mensagens que chegaram desde a última verificação. Envie-me mensagens apenas sobre e-mails urgentes ou que precisam de resposta, com um resumo de uma linha cada. Se nada precisar da minha atenção, não envie nada.';

  @override
  String get taskPromptMorningBriefing =>
      'Prepare meu briefing matinal: o clima de hoje onde estou, os eventos em minha agenda e os itens em aberto mais importantes que conheço. Envie-o como uma mensagem curta e digitalizável.';

  @override
  String get taskPromptTomorrowPrep =>
      'Veja minha agenda para amanhã. Para cada reunião, diga-me do que se trata, quem está envolvido e tudo o que devo preparar. Se amanhã estiver vazio, não envie nada.';

  @override
  String get taskPromptNewsDigest =>
      'Pesquise na web as notícias mais importantes do dia sobre os tópicos que me interessam (use o que você lembra sobre meus interesses). Envie-me um resumo de até cinco itens com uma frase cada e um link.';

  @override
  String get taskPromptWeeklyReview =>
      'Reveja minha semana: o que foi feito, o que escorregou e o que ainda está em aberto. Sugira as três coisas mais importantes nas quais focar na próxima semana.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Vincule um número de telefone que pertença ao agente. Qualquer pessoa que você permitir pode conversar com ele, em chats diretos e grupos.';

  @override
  String get whatsappSelfChatDescription =>
      'Vincule seu próprio número e fale com o agente no chat “Envie uma mensagem para você mesmo”. Todos os outros bate-papos e grupos desta conta serão ignorados.';

  @override
  String get chatSendHintMac => '⌘↵ para enviar';

  @override
  String get chatSendHintOther => 'Ctrl+Enter para enviar';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Um URL base é necessário para este endpoint.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Um endereço de e-mail alterado é confirmado antes de ser usado.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Uma decisão mais acima na cadeia vence.';

  @override
  String get aDeletedAccount => 'uma conta excluída';

  @override
  String get aFridayLookBackAtThe =>
      'Uma retrospectiva da semana na sexta-feira e um plano para a próxima.';

  @override
  String get aKeyThatAsksForA =>
      'Uma chave que solicita um PIN ou impressão digital também substitui seu código de dois fatores.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Um modelo de linguagem julgou esta mensagem porque o SystemOne está desativado.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Um arquivo de metadados de configuração do NeoAgent excedeu seu limite de tamanho seguro.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Uma versão da web mais recente está disponível no servidor. Recarregue para buscar o pacote mais recente.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Um desktop privado com Chromium, arquivos, editor de texto, terminal e Python. Seu trabalho permanece salvo entre as sessões.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Um computador Linux privado ou um dispositivo Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'Não foi possível fazer download de um arquivo de configuração necessário do NeoAgent.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Um colega de equipe lhe envia um link de convite. Depois de aceitá-lo, eles ';

  @override
  String get aTeammateSentYouAnInvite =>
      'um colega de equipe enviou a você um link de convite, insira-o aqui para ingressar na equipe dele.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Um download temporário será limpo posteriormente.';

  @override
  String get aValueIsStored => 'Um valor é armazenado.';

  @override
  String get access => 'Acesso';

  @override
  String get accessActivity => 'Atividade de acesso';

  @override
  String accessArg1(Object? arg1) {
    return 'Acesso: $arg1';
  }

  @override
  String get accessMode => 'Modo de acesso';

  @override
  String get accessPermissions => 'Permissões de acesso';

  @override
  String get accessToken => 'token de acesso';

  @override
  String get accessToken2 => 'Token de acesso';

  @override
  String get account => 'Conta';

  @override
  String accountArg1(Object? arg1) {
    return 'Conta #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Alertas de alteração de conta';

  @override
  String get accountEmail => 'E-mail da conta';

  @override
  String get accountEmailIsOffUntilThese =>
      'O e-mail da conta fica desativado até que estes sejam definidos: ';

  @override
  String get accountLanguageDescription =>
      'O NeoAgent usa essa linguagem em todo o aplicativo. Na primeira vez que você faz login, ele segue este dispositivo. Depois disso, a escolha é salva na sua conta e usada em todos os dispositivos.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'Não foi possível alterar o idioma: $error';
  }

  @override
  String get accountLanguageTitle => 'Idioma';

  @override
  String get accountNumber => 'Número da conta';

  @override
  String get accountSettings => 'Configurações da conta';

  @override
  String get accounts => 'Contas';

  @override
  String get accountsByTokensUsedAllTime =>
      'Contas por tokens usados, o tempo todo.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'computadores em nuvem das contas. As alterações se aplicam após um servidor ';

  @override
  String get accountsOnThisServer => 'Contas neste servidor';

  @override
  String get active => 'Ativo';

  @override
  String get activeSessions => 'Sessões ativas';

  @override
  String get activeToday => 'Ativo hoje';

  @override
  String get add => 'Adicionar';

  @override
  String get addAProviderCredentialFirstIts =>
      'Adicione uma credencial de provedor primeiro. Seus modelos aparecem aqui uma vez ';

  @override
  String get addAgent => 'Adicionar agente';

  @override
  String get addAnotherSignInMethodBefore =>
      'Adicione outro método de login antes de remover este.';

  @override
  String get addBinding => 'Adicionar vinculação';

  @override
  String get addByNameOrId => 'Adicionar por nome ou ID';

  @override
  String get addByNameOrIdInstead => 'Adicione por nome ou ID';

  @override
  String get addCredentialBinding => 'Adicionar vinculação de credenciais';

  @override
  String get addEntry => 'Adicionar entrada';

  @override
  String get addKey => 'Adicionar chave';

  @override
  String get addMcpServer => 'Adicionar servidor MCP';

  @override
  String get addMemory => 'Adicionar memória';

  @override
  String get memoryReview => 'Rever';

  @override
  String get memoryReviewPrompt =>
      'Revê todas as minhas memórias e organiza-as: arquiva duplicados, factos desatualizados e tudo o que não tenha valor duradouro. Depois diz-me resumidamente o que alteraste.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Adicione mais comprimento ou outro tipo de caractere.';

  @override
  String get addPeopleOrGroups => 'Adicione pessoas ou grupos';

  @override
  String get addSecurityKey => 'Adicionar chave de segurança';

  @override
  String get addSomeoneOrAGroup => 'Adicione alguém ou um grupo';

  @override
  String get addTask => 'Adicionar tarefa';

  @override
  String get addTests => 'Adicionar testes';

  @override
  String get addTestsForThePartsOf =>
      'Adicione testes para as partes deste projeto que têm menos cobertura e execute-os.';

  @override
  String get addTheirOwnKeysInSettings =>
      'adicione suas próprias chaves em Configurações.';

  @override
  String get addToPrompt => 'Adicionar ao prompt';

  @override
  String get added => 'Adicionado';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Adicionado $arg1 · Último $arg2 usado';
  }

  @override
  String get addressWithTheProvider => 'endereço com o provedor.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Ajuste o volume do alto-falante, revise os padrões dos botões de hardware e gerencie esta sessão do iniciador.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Ajuste a pesquisa ou o filtro de status para ver mais canais de mensagens.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Ajuste o volume do alto-falante aqui.';

  @override
  String get admin => 'Administrador';

  @override
  String adminArg1(Object? arg1) {
    return 'Administrador › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Concessões de administrador, links de convite e alterações de gerenciamento aparecem aqui.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Agendamento manual avançado para casos especiais.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avançado: minuto hora dia mês dia da semana.';

  @override
  String get againRightAway => 'novamente imediatamente.';

  @override
  String get agent => 'Agente';

  @override
  String agentArg1(Object? arg1) {
    return 'Agente: $arg1';
  }

  @override
  String get agentCalls => 'Chamadas de agente';

  @override
  String get agentCommunication => 'Comunicação do agente';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Comunicação do agente: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'O modo agente edita o espaço de trabalho · ⌘↵ enviar · ⌘N nova sessão';

  @override
  String get agentPausesAndAsksYouBefore =>
      'O agente faz uma pausa e pede a sua autorização antes de iniciar a execução.';

  @override
  String get agentProfile => 'Perfil do agente';

  @override
  String get agentVisibleName => 'Nome visível do agente';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'O agente deseja usar $arg1. Toque para decidir.';
  }

  @override
  String get agents => 'Agentes';

  @override
  String get aiAnswerUnreadable => 'Resposta da IA ilegível';

  @override
  String get aiProviderKeys => 'Chaves do provedor de IA';

  @override
  String get aiUnavailable => 'IA indisponível';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'alertas e outros e-mails da conta.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Alerta quando uma conexão de mensagens precisa da atenção do usuário';

  @override
  String get all => 'Todos';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Todos os agentes ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Todos $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Todos os slots de computadores em nuvem estão atualmente em uso. Tente novamente em alguns instantes.';

  @override
  String get allComputerSlotsAreBusy =>
      'Todos os slots do computador estão ocupados';

  @override
  String get allTables => 'Todas as tabelas';

  @override
  String get allTime => 'Todo o tempo';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Todas as ferramentas são permitidas — o agente pode usar qualquer recurso sem perguntar. ';

  @override
  String get allow => 'Permitir';

  @override
  String get allowedRunsWithoutAsking => 'Permitido. Corre sem perguntar.';

  @override
  String get allowAll => 'Permitir tudo';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Permita \"Instalar aplicativos desconhecidos\" para NeoAgent e tente atualizar novamente.';

  @override
  String get allowOnce => 'Permitir uma vez';

  @override
  String get allowSender => 'Permitir remetente';

  @override
  String get allowSession => 'Permitir sessão';

  @override
  String get allowTheAgentToStartAn =>
      'Permita que o agente inicie uma chamada de voz no aplicativo com você.';

  @override
  String get allowedOrigins => 'Origens permitidas';

  @override
  String get allowedPathPrefix => 'Prefixo de caminho permitido';

  @override
  String get allowsYouCanChangeThatPer =>
      'permite. Você pode alterar isso por pessoa mais tarde. Links nunca concedem ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'já pertence a uma conta existente';

  @override
  String get alreadyLinkedToAnotherAccount => 'já vinculado a outra conta';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'já vinculado a outra conta neoagente';

  @override
  String get alreadyUsed => 'já usado';

  @override
  String get always => 'Sempre';

  @override
  String get alwaysAllow => 'Sempre permitir';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Sempre permitir\" salva a política permanentemente — você pode alterá-la em Configurações.';

  @override
  String get alwaysAsk => 'Sempre pergunte';

  @override
  String get alwaysEngage => 'Sempre se envolva';

  @override
  String get alwaysJoins => 'Sempre participa';

  @override
  String get anApiKeyIsRequired => 'É necessária uma chave de API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Um resumo noturno do que aconteceu e o que fazer para acompanhar.';

  @override
  String get anHttpOrHttpsUrlIs => 'É necessário um URL http ou https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'e análises. Os links da equipe ficam na página da equipe.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'A instalação do APK do Android não está disponível nesta plataforma.';

  @override
  String get androidApp => 'Aplicativo Android';

  @override
  String get androidControl => 'Controle Android';

  @override
  String get androidCouldNotStart => 'O Android não pôde ser iniciado';

  @override
  String get androidNotificationReceived => 'Notificação Android recebida';

  @override
  String get androidOnly => 'Somente Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'Não foi possível abrir o instalador do pacote Android.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Tela do Android – toque para tocar, arraste para deslizar';

  @override
  String get androidSdk => 'SDK do Android';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Responde a @menções sobre problemas e pull requests';

  @override
  String get anyone => 'Qualquer um';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Qualquer pessoa nesta plataforma pode enviar mensagens para $arg1';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Qualquer pessoa nesta plataforma pode enviar mensagens para $arg1 em $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Qualquer pessoa que conseguir acessar esta conta pode falar com $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Qualquer pessoa com o link pode aderir até que ele expire ou você o revogue.';

  @override
  String get apiHttpsOrigin => 'Origem HTTPS da API';

  @override
  String get apiKey => 'Chave de API';

  @override
  String get apiKey2 => 'chave de API';

  @override
  String get apiKey3 => 'Chave de API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'chave de API antrópico claude openai gpt xai grok google gemini minimax nvidia nim openrouter credenciais';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Chaves de API e endpoints para provedores de IA, pesquisa e voz. Eles ';

  @override
  String get apiRequest => 'Solicitação de API';

  @override
  String get apiYourOwnServerASelf =>
      'API – seu próprio servidor, um modelo auto-hospedado ou outro ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'O download do APK falhou com HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'O nome do aplicativo é obrigatório.';

  @override
  String get appUpdates => 'Atualizações de aplicativos';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'As atualizações de aplicativos não estão configuradas para esta compilação.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Aplicadas atualizações de direção na fila $arg1 à execução atual.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Aplicadas atualizações de direção $arg1.';
  }

  @override
  String get apply => 'Aplicar';

  @override
  String get applyBehaviorNotes => 'Aplicar notas de comportamento';

  @override
  String get applyCoreMemory => 'Aplicar memória principal';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Solicitações de aprovação para ferramentas de agente confidenciais';

  @override
  String get approvalRequired => 'Aprovação necessária';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'A aprovação permanece dentro da sua sessão móvel autenticada e cada código expira automaticamente após um curto período.';

  @override
  String get approveLogin => 'Aprovar login';

  @override
  String get approveQrLogin => 'Aprovar login QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Aprove isso apenas se você iniciou o login nesse dispositivo agora há pouco.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Login aprovado para $arg1.';
  }

  @override
  String get approvedOnly => 'Somente aprovado';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Emparelhamento aprovado para $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Pessoas e grupos aprovados';

  @override
  String get approvedPeopleOnly => 'Somente pessoas aprovadas';

  @override
  String get archive => 'Arquivo';

  @override
  String get archiveAgent => 'Agente de arquivo?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Arquivo ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Arquivar $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => 'Arquivar memórias selecionadas?';

  @override
  String get areSharedByEveryAccountOn =>
      'são compartilhados por todas as contas neste servidor; contas ainda podem ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / entrada de 1 milhão';
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
    return 'Acesso $arg1 necessário';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'Contas $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 ativo';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return '$arg1 adicionado. Edite-o a qualquer momento para alterar o ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '“$arg1” e seu histórico de execução serão excluídos permanentemente. Qualquer execução ativa será interrompida. Os arquivos na área de trabalho não são tocados.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Aprovação $arg1 necessária';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aplicativos $arg1 ativos';
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
    return '$arg1 (ferramentas ativas $arg2)';
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
    return '$arg1 $arg2 em $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 alterado';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return '$arg1 · Caracteres $arg2';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Criado $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [uri local: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 correspondente a “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return 'Espaço de trabalho $arg1${arg2}NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 novas contas';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 é executado · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return '$arg1 · Amostras $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · Direção $arg2 na fila';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nTokens $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Tokens $arg1/$arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 em $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '${arg1}B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 tornou-se administrador ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return 'Bytes $arg1';
  }

  @override
  String arg1Channel(Object? arg1) {
    return 'Canal $arg1';
  }

  @override
  String arg1Chars(Object? arg1) {
    return 'Caracteres $arg1';
  }

  @override
  String arg1Cleared(Object? arg1) {
    return '$arg1 limpo.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 configurado';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 conectado. Escolha repositórios e pessoas em Quem pode enviar mensagens.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Entradas principais $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 criou um link de convite';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Área de trabalho $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Eventos $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 falhou';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 falhou';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 falhando';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 para $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 GB';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Grupos $arg1 somente marcados';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return '${arg1}h atrás';
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
    return 'Ajudantes $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(Taxa de acerto $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 é administrador, então a conta não pode ser excluída ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 está bloqueado em $arg2. Atualize a lista de acesso para permitir respostas.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 está conectado e respondendo.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 não é mais administrador ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 não está disponível em $arg2 (falta permissão ou dependência de tempo de execução).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 juntou-se sob $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 julgado por LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Chave $arg1$arg2 configurada';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Chave $arg1 removida.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 esquerda';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 saiu de $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 vinculado';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return '${arg1}m atrás';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Certifique-se de que esteja em execução e tente novamente.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 gerencia esta conta';
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
    return '$arg1 min $arg2 seg';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Modelos $arg1 prontos';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 mais';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 mais etapas no histórico de execução';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 movido de $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 deve ser um número finito.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 deve ser um endereço http:// ou https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 precisa de atenção';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return 'Espaço de trabalho $arg1/NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 novas contas no último $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · novas mensagens orientam esta corrida';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 novas execuções';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 agora gerencia esta conta.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 de 4 permissões permitidas. Os arquivos estão limitados à pasta NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 de $arg2 habilitado';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 dos grupos $arg2 participam do bate-papo comum';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 dos modelos $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return '$arg1 dos modelos $arg2 prontos';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return '$arg1 do conjunto $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return '$arg1 de ferramentas $arg2 permitidas';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 no dia $arg2 em $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 responde apenas às pessoas que você adiciona abaixo.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 só responde quando marcado';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 fala apenas com pessoas e grupos que você aprova';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 pessoas ou grupos adicionados';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Planejamento $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Provedores $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 pronto';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Registros $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI de redirecionamento $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registrado';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 respondeu';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 revogou um link de convite';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 é executado';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 é executado · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 é executado no último $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 salvo.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 seg.';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 selecionado';
  }

  @override
  String arg1Shown(Object? arg1) {
    return '$arg1 mostrado';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 ficou quieto';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return 'Direção $arg1 $arg2 na fila';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return '$arg1 step$arg2 · toque em um nó para inspecionar';
  }

  @override
  String arg1Steps(Object? arg1) {
    return 'Etapas $arg1';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 parou de gerenciar $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Tokens $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Tokens $arg1 no último $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Ferramentas $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (substituição salva indisponível)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% usado · $arg2 restante';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 quer falar com você.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'Rede $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" será removido permanentemente.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 gerenciará esta conta';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 não responderá nesta plataforma';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 não responderá a $arg2.';
  }

  @override
  String get artifactStorageByUser => 'Armazenamento de artefatos por usuário';

  @override
  String get askAQuestionOrStartA =>
      'Faça uma pergunta ou inicie uma tarefa...';

  @override
  String get askBeforeClosingToBackground =>
      'Pergunte antes de fechar em segundo plano';

  @override
  String get askMe => 'Pergunte-me';

  @override
  String get assignedAgent => 'Agente atribuído';

  @override
  String get assignedAgent2 => 'Agente atribuído';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Agente atribuído: $arg1';
  }

  @override
  String get assigneeOptional => 'Cessionário (opcional)';

  @override
  String get assistant => 'Assistente';

  @override
  String get assistantKey131 => 'Chave assistente 131';

  @override
  String get atLeast1 => 'Pelo menos 1.';

  @override
  String get attachFiles => 'Anexar arquivos';

  @override
  String attentionArg1(Object? arg1) {
    return 'Atenção $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'registro de auditoria concessão do administrador revogar o histórico da equipe de convites';

  @override
  String get authMethod => 'Método de autenticação';

  @override
  String get authServerUrl => 'URL do servidor de autenticação';

  @override
  String get authentication => 'Autenticação';

  @override
  String get authenticationFailed => 'Falha na autenticação.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'A autenticação ainda está pendente. Conclua o fluxo do navegador e tente novamente.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'A autenticação ainda está pendente. Conclua o fluxo do navegador e atualize.';

  @override
  String get authenticationTimedOut => 'A autenticação expirou.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'A autenticação foi cancelada antes da conclusão.';

  @override
  String get authenticatorApp => 'Aplicativo autenticador';

  @override
  String get authenticatorCode => 'Código autenticador';

  @override
  String get authorOptional => 'Autor (opcional)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Automático (primeiro provedor com uma chave de API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Rota automática para o melhor modelo disponível';

  @override
  String get automaticFast => 'Automático (rápido)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automático lê a sala e normalmente retém. A menção apenas não toma nenhuma decisão até ser abordada diretamente.';

  @override
  String get automaticReserved => 'Automático, reservado';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'A reversão automática precisa de uma nova tentativa na tela de configuração.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automaticamente seleciona um modelo rápido através do catálogo de modelos normal.';

  @override
  String get automation => 'Automação';

  @override
  String get available => 'Disponível';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Disponível novamente em $arg1';
  }

  @override
  String get availableAgainShortly => 'Disponível novamente em breve';

  @override
  String get availableInTheDesktopAppFor =>
      'Disponível no aplicativo de desktop para macOS, Windows e Linux';

  @override
  String get availableToTheAgent => 'Disponível para o agente';

  @override
  String get averageAllTime => 'Média, todos os tempos';

  @override
  String get avgImp => 'Média imp.';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Média/execução: tokens $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Evite caracteres repetidos e sequências óbvias.';

  @override
  String get awaitingScan => 'Aguardando verificação';

  @override
  String get back => 'Voltar';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count em segundo plano';
  }

  @override
  String get backgroundTasks => 'Tarefas em segundo plano';

  @override
  String get backOn => 'de volta.';

  @override
  String get backToChat => 'Voltar ao bate-papo';

  @override
  String get backToFolder => 'Voltar para a pasta';

  @override
  String get backToSignIn => 'Voltar para fazer login';

  @override
  String get backendChannel => 'Canal de back-end';

  @override
  String get backendOnThisComputer => 'Back-end neste computador';

  @override
  String get backendSync => 'Sincronização de back-end';

  @override
  String get backgroundLocationNeeded => 'Localização de fundo necessária';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'A sincronização em segundo plano permanece agendada no Android';

  @override
  String get badState => 'Estado ruim: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Imagem base e tamanho das máquinas virtuais QEMU executadas ';

  @override
  String get baseUrlOptional => 'URL base (opcional)';

  @override
  String get baseUrlTokenLocal => 'token de URL base local';

  @override
  String get basicAuthentication => 'Autenticação básica';

  @override
  String get behaviorModules => 'Módulos de Comportamento';

  @override
  String get behaviorNotes => 'notas de comportamento';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Corretor de credenciais Bitwarden';

  @override
  String get bitwardenItem => 'Item Bitwarden';

  @override
  String get bitwardenServer => 'Servidor Bitwarden';

  @override
  String get blankUsesCommon => 'Em branco usa \"comum\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Em branco usa o retorno de chamada padrão';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Os valores em branco usam os padrões do provedor.';

  @override
  String get block => 'Bloquear';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Mensagem recebida bloqueada de $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Ponte compatível com BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL do servidor BlueBubbles';

  @override
  String get botToken => 'Token de bot';

  @override
  String get botTokenAndApprovedChats => 'Token de bot e chats aprovados';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token de bot e acesso ao servidor/canal';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token de bot, API de eventos e acesso ao canal';

  @override
  String get botUserId => 'ID do usuário do bot';

  @override
  String get botUsername => 'Nome de usuário do bot';

  @override
  String get brandName => 'Marca';

  @override
  String get braveSearch => 'Busca corajosa';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Conecte qualquer provedor que possa postar e receber cargas úteis de webhook.';

  @override
  String get bringYourOwnKey => 'traga sua própria chave';

  @override
  String get bringYourOwnKey2 => 'Traga sua própria chave';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'Navegador, desktop Linux, arquivos, terminal e Python compartilham um computador em nuvem persistente.';

  @override
  String get browserLogin => 'Login do navegador';

  @override
  String get browserScripting => 'Script do navegador';

  @override
  String get call => 'Ligar';

  @override
  String get callAgent => 'Chamar agente';

  @override
  String get callUser => 'Chamar usuário';

  @override
  String get calledByName => 'Chamado pelo nome';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Pode delegar tarefas a outros agentes';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Pode delegar para $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Pode receber tarefas delegadas';

  @override
  String get cancel => 'Cancelar';

  @override
  String get cancelTask => 'Cancelar tarefa';

  @override
  String get cannotPreview => 'Não é possível visualizar';

  @override
  String get cannotReceiveDelegatedTasks =>
      'não pode receber tarefas delegadas';

  @override
  String get cannotRunYet => 'ainda não pode ser executado.';

  @override
  String get capturedThePage => 'Capturou a página';

  @override
  String get category => 'Categoria';

  @override
  String chainArg1(Object? arg1) {
    return 'Corrente: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Alterar modo de configuração';

  @override
  String get channel => 'Canal';

  @override
  String get channelAccessToken => 'Token de acesso ao canal';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Canal: $arg1$arg2 | Versão de atualização: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Memória social com escopo de canal';

  @override
  String get channels => 'Canais';

  @override
  String get chat => 'Bate-papo';

  @override
  String get chatId => 'ID do bate-papo';

  @override
  String get chatMode => 'Modo de bate-papo';

  @override
  String get chatModel => 'Modelo de bate-papo';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Verifique automaticamente no lançamento';

  @override
  String get checkForMessagesEveryMs => 'Verifique se há mensagens a cada (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Verifique se há novas mensagens automaticamente';

  @override
  String get checkNow => 'Verifique agora';

  @override
  String get checkYourEmailToConfirmYour =>
      'Verifique seu e-mail para confirmar sua conta NeoAgent antes de fazer login.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Verificado $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Escolha uma categoria ou pesquise em todas as configurações.';

  @override
  String get chooseAPerson => 'Escolha uma pessoa';

  @override
  String get chooseAProjectFolder => 'Escolha uma pasta do projeto';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Escolha padrões para chat, agentes, comportamento substituto e roteamento inteligente.';

  @override
  String get chooseGroups => 'Escolha grupos';

  @override
  String get chooseHowMuchYouWantTo =>
      'Escolha quanto você deseja configurar agora. Ambas as opções podem ser alteradas posteriormente.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Escolha como esta tarefa deve começar. O manual é executado apenas em Executar agora. A programação é baseada no tempo. A integração desencadeia disparos de aplicativos oficiais conectados.';

  @override
  String get chooseOneToGetStartedNow =>
      'Escolha um para começar agora. Você pode adicionar mais posteriormente.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Escolha o modelo ao vivo e a voz em Configurações.';

  @override
  String get chooseTheirGroup => 'Escolha o grupo deles';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Escolha onde essa pessoa deve ter permissão para falar com $arg1. Você pode alterar isso mais tarde em Quem pode enviar mensagens.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Escolha quais grupos $arg1 deve ingressar mesmo quando ninguém o marca. Esta plataforma pode não diferenciar tags de mensagens normais.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Escolha quais modelos cada conta neste servidor pode escolher e ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Escolha com quem $arg1 fala e quando ele entra em bate-papos em grupo.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Escolha quem pode acessar $arg1 e salve suas alterações.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Escolha quem pode enviar mensagens ao agente com \"Quem pode enviar mensagens\" no cartão do WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Escolha seu\nmodelo padrão.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, arquivos, editor de texto e terminal estão disponíveis no desktop Linux.';

  @override
  String get claudeCode => 'Código Claude';

  @override
  String get clear => 'Limpar';

  @override
  String get clearAll => 'Limpar tudo';

  @override
  String clearArg1(Object? arg1) {
    return 'Limpar $arg1?';
  }

  @override
  String get clearFilter => 'Limpar filtro';

  @override
  String get clearFilters => 'Limpar filtros';

  @override
  String get clearSearch => 'Limpar pesquisa';

  @override
  String get clearView => 'Visão clara';

  @override
  String get cliSession => 'Sessão CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'click não é compatível com esta plataforma.';

  @override
  String get clickOnceToBeginCapturing =>
      'Clique uma vez para começar a capturar';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Clique, digite e interaja com aplicativos de desktop.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Clicado em ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Clicou no navegador';

  @override
  String get clientId => 'ID do cliente';

  @override
  String get clientSecret => 'Segredo do cliente';

  @override
  String get close => 'Fechar';

  @override
  String get closeJ => 'Fechar (⌘J)';

  @override
  String get closeTeachMode => 'Fechar modo de ensino';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Fechar a janela pode manter o NeoAgent em execução em segundo plano com acesso à bandeja ou encerrar completamente o tempo de execução da área de trabalho.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Instâncias em nuvem e auto-hospedadas são suportadas. URLs de redes locais e privadas funcionam quando o NeoAgent pode acessá-los.';

  @override
  String get cloudComputer => 'Computador em nuvem';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Computador em nuvem · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Configurações do computador em nuvem salvas. Reinicie o servidor para aplicá-los.';

  @override
  String get cloudComputerVm => 'Computador em nuvem (VM)';

  @override
  String get cloudComputers => 'Computadores em nuvem';

  @override
  String get codeHosting => 'Hospedagem de código';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Nomes de canais separados por vírgula, sem #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Separados por vírgula, por exemplo #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Vírgula separada. A questão deve ter todos eles.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Falha no comando ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'O comando é necessário.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'O acumulador de saída de comando não está ativo.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Falha no upload da saída do comando ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'O upload da saída do comando omitiu os metadados do artefato.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'A saída do comando já foi finalizada.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Comandos e aplicativos';

  @override
  String get commandsRunInTheSamePersistent =>
      'Os comandos são executados no mesmo computador persistente usado pela área de trabalho visível.';

  @override
  String get communityChatops => 'Comunidade e ChatOps';

  @override
  String get completeSetup => 'Configuração completa';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Conclua o fluxo de trabalho na área de trabalho.';

  @override
  String get completed => 'Concluído';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Completamente bloqueado — o agente não pode usar esta categoria.';

  @override
  String get computerShell => 'Concha de computador';

  @override
  String get computerUsedByThisSession => 'Computador usado por esta sessão';

  @override
  String get computerWorkspace => 'Espaço de trabalho do computador';

  @override
  String get configurablePersonalWebhookBridge =>
      'Ponte de webhook pessoal configurável';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Relé configurável ou ponte de webhook';

  @override
  String get configurableTalkWebhookBridge =>
      'Ponte de webhook do Talk configurável';

  @override
  String get configurableWebInboxBridge =>
      'Ponte de caixa de entrada da web configurável';

  @override
  String get configurableWebhookBridge => 'Ponte de webhook configurável';

  @override
  String get configurableWebhooks => 'Webhooks configuráveis';

  @override
  String get configurationOrInTheEnvFile => 'Configuração ou no arquivo .env.';

  @override
  String get configure => 'Configurar';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configure o comportamento do espaço de trabalho e os padrões do modelo.';

  @override
  String configuredArg1(Object? arg1) {
    return '$arg1 configurado';
  }

  @override
  String get confirmEmailChanges => 'Confirmar alterações de e-mail';

  @override
  String get confirmNewSignUps => 'Confirmar novas inscrições';

  @override
  String get confirmPassword => 'Confirmar senha';

  @override
  String get confirmPassword2 => 'Confirmar senha';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Confirme seu e-mail antes de entrar. Verifique a mensagem de e-mail de serviço do NeoAgent.';

  @override
  String get connect => 'Conectar';

  @override
  String get connectAMessagingPlatform =>
      'Conecte uma plataforma\nde mensagens.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Conecte um endpoint HTTPS Home Assistant público com um token de acesso de longa duração. Endereços de rede locais, de loopback e privados são bloqueados pelo servidor.';

  @override
  String get connectAccount => 'Conectar conta';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Conecte contas de aplicativos individualmente para que a IA possa usar a conta certa para cada integração oficial.';

  @override
  String connectArg1(Object? arg1) {
    return 'Conecte $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Conecte quantas contas desejar. Cada aplicativo pode usar uma conta diferente.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Conecte canais, escolha com quem $arg1 fala e assista às atividades recentes.';
  }

  @override
  String get connectInstance => 'Conectar instância';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Conecte esta integração primeiro para escolher uma conta.';

  @override
  String get connectToThisServer => 'Conecte-se a este servidor';

  @override
  String get connectWhatsapp => 'Conectar WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Conecte sua instância Nextcloud, incluindo servidores auto-hospedados. NeoAgent abre a própria página de login do Nextcloud para que você possa fazer login com senha, SSO ou 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Conecte seu servidor NeoRecall auto-hospedado. O NeoAgent recebe acesso somente leitura à pesquisa local, memórias e evidências de transcrição após você aprovar a tela do OAuth.';

  @override
  String get connected => 'Conectado';

  @override
  String get connectedAccount => 'Conta conectada';

  @override
  String connectedArg1(Object? arg1) {
    return 'Conectado $arg1';
  }

  @override
  String get connectedInstance => 'Instância conectada';

  @override
  String get connectedNeorecallUser => 'Usuário NeoRecall conectado';

  @override
  String get connectedNextcloudUser => 'Usuário Nextcloud conectado';

  @override
  String get connectedServer => 'Servidor conectado';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Conectando ao modelo de voz ao vivo...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Conexão #$arg1';
  }

  @override
  String get connectionId => 'ID de conexão';

  @override
  String get connectionLooksGood => 'A conexão parece boa.';

  @override
  String get connectionMethod => 'Método de conexão';

  @override
  String get containsTextOptional => 'Contém texto (opcional)';

  @override
  String get content => 'Conteúdo';

  @override
  String get contentSecurityPolicy => 'política de segurança de conteúdo';

  @override
  String get continue2 => 'Continuar';

  @override
  String get continueFullSetup => 'Continuar a configuração completa';

  @override
  String get continueRun => 'Continuar correndo';

  @override
  String get continueToSetup => 'Continuar a configuração';

  @override
  String get controlSurface => 'SUPERFÍCIE DE CONTROLE';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Controla o acesso às ferramentas $arg1.';
  }

  @override
  String get conversation => 'Conversa';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID da conversa usada quando este agente inicia um chat.';

  @override
  String get cookieSetup => 'Configuração de cookies';

  @override
  String get cookiesNotConfigured => 'Cookies não configurados';

  @override
  String get copiedAsCsv => 'Copiado como CSV';

  @override
  String get copiedDebugInfo => 'Informações de depuração copiadas';

  @override
  String get copiedExportForTheLast5 =>
      'Exportação copiada das últimas 5 mensagens';

  @override
  String get copiedFullPrompt => 'Prompt completo copiado';

  @override
  String get copiedLogs => 'Registros copiados';

  @override
  String get copiedRunId => 'ID de execução copiado';

  @override
  String get copy => 'Copiar';

  @override
  String get copyAll => 'Copiar tudo';

  @override
  String get copyCodes => 'Copiar códigos';

  @override
  String get copyCsv => 'Copiar CSV';

  @override
  String get copyDebugInfo => 'Copiar informações de depuração';

  @override
  String get copyLink => 'Copiar link';

  @override
  String get copyLogs => 'Copiar registros';

  @override
  String get copyPrompt => 'Copiar prompt';

  @override
  String get copyResponse => 'Copiar resposta';

  @override
  String get copyRunId => 'Copiar ID de execução';

  @override
  String get copyWebhookUrl => 'Copiar URL do webhook';

  @override
  String get core => 'Núcleo';

  @override
  String get coreMemory => 'memória central';

  @override
  String get coreServicesThisServerDependsOn =>
      'Serviços principais dos quais este servidor depende.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'cors domínio https origens do URL público';

  @override
  String get couldHelp => 'Poderia ajudar';

  @override
  String get couldNotApproveQrLogin =>
      'Não foi possível aprovar o login do QR.';

  @override
  String get couldNotApproveQrPairing =>
      'Não foi possível aprovar o emparelhamento QR.';

  @override
  String get couldNotConnect => 'Não foi possível conectar.';

  @override
  String get couldNotCreateBinding => 'Não foi possível criar a vinculação.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'Não foi possível excluir sua conta: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden =>
      'Não foi possível desconectar o Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'Não foi possível desconectar o Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall =>
      'Não foi possível desconectar o NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud =>
      'Não foi possível desconectar o Nextcloud.';

  @override
  String get couldNotDisconnectTrello =>
      'Não foi possível desconectar o Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'Não foi possível exportar seus dados: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'Não foi possível carregar as decisões';

  @override
  String get couldNotLoadUsageData =>
      'Não foi possível carregar os dados de uso.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'Não foi possível abrir as configurações do Linux automaticamente.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'Não foi possível abrir a página de link do provedor.';

  @override
  String get couldNotOpenTheProviderSign =>
      'Não foi possível abrir a página de login do provedor.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'Não foi possível abrir o recurso de lançamento.';

  @override
  String get couldNotOpenTrelloInYour =>
      'Não foi possível abrir o Trello no seu navegador.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'Não foi possível abrir o download do arquivo do espaço de trabalho.';

  @override
  String get couldNotReadTheAndroidApp =>
      'Não foi possível ler o pacote do aplicativo Android.';

  @override
  String get couldNotReadTheApk => 'Não foi possível ler o APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'Não foi possível remover a chave: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'Não foi possível salvar o agente.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'Não foi possível salvar a configuração do Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'Não foi possível salvar a configuração do Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'Não foi possível salvar a configuração do NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'Não foi possível salvar a configuração do Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'Não foi possível salvar a configuração do Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'não foi possível enviar e-mail de confirmação';

  @override
  String get couldNotStart => 'Não foi possível iniciar';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'Criar';

  @override
  String get createAPasswordFirstToChange =>
      'Crie uma senha primeiro para alterar o e-mail da sua conta.';

  @override
  String get createAPasswordOrLinkAnother =>
      'crie uma senha ou vincule outro provedor antes de remover este método de login';

  @override
  String get createATaskWhileThisAgent =>
      'Crie uma tarefa enquanto este agente estiver selecionado.';

  @override
  String get createLink => 'Criar link';

  @override
  String get createOrModifyFilesInYour =>
      'Crie ou modifique arquivos em seu espaço de trabalho.';

  @override
  String get createPassword => 'Criar senha';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Crie bots especializados com memória, configurações, ferramentas e atribuições de contas separadas.';

  @override
  String get createTheFirstAccount => 'Crie a primeira conta';

  @override
  String get createUpdateOrDeleteSkills =>
      'Crie, atualize ou exclua habilidades.';

  @override
  String get creatingYourSkill => 'Criando sua habilidade…';

  @override
  String get credentialBindings => 'Vinculações de credenciais';

  @override
  String get credentialUse => 'Uso de credenciais';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Execuções recorrentes baseadas em cron e execução única cronometrada.';

  @override
  String get cronExpression => 'Expressão Cron';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter executa a consulta.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Shift + Espaço';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'E-mail atual: $arg1';
  }

  @override
  String get currentPassword => 'Senha atual';

  @override
  String get currentPasswordIsIncorrect => 'a senha atual está incorreta';

  @override
  String get currentTwoStepLoginCode => 'Código de login atual em duas etapas';

  @override
  String get customAccess => 'Acesso personalizado';

  @override
  String get customCron => 'Cron personalizado';

  @override
  String get customCronMustHave5Fields =>
      'O Cron personalizado deve ter 5 campos.';

  @override
  String get customEndpoint => 'ponto de extremidade personalizado';

  @override
  String get customField => 'Campo personalizado';

  @override
  String get customHeader => 'Cabeçalho personalizado';

  @override
  String get customHeadersJson => 'Cabeçalhos personalizados (JSON)';

  @override
  String get customOpenaiCompatible => 'Compatível com OpenAI personalizado';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Endpoint personalizado compatível com OpenAI';

  @override
  String get customOutgoingUrl => 'URL de saída personalizado';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Diariamente';

  @override
  String get dailyRecap => 'Resumo diário';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'consulta de banco de dados selecionar modelos csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Dia $arg1';
  }

  @override
  String get dayOfMonth => 'Dia do mês';

  @override
  String get decideWhichToolsYourAgentMay =>
      'decida quais ferramentas seu agente pode usar. Eles veem seu nome e ';

  @override
  String get decisionHigherUpTheChainWins =>
      'a decisão mais acima na cadeia vence e mostra um bloqueio com o ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'As decisões aparecem aqui enquanto $arg1 indica grupos $arg2 aprovados. Apenas os últimos 30 são mantidos e são redefinidos quando o servidor é reiniciado.';
  }

  @override
  String get decline => 'Recusar';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'corrida profunda · etapa $arg1';
  }

  @override
  String get deepgramKey => 'Chave Deepgram';

  @override
  String get default2 => 'Padrão';

  @override
  String get default3 => 'PADRÃO';

  @override
  String defaultArg1(Object? arg1) {
    return 'Padrão ($arg1)';
  }

  @override
  String get defaultConversation => 'Conversa padrão';

  @override
  String get defaultForNewGroups => 'Padrão para novos grupos';

  @override
  String get defaultGroupParticipation => 'Participação de grupo padrão';

  @override
  String get defaultNeoagentWorkspace =>
      'Espaço de trabalho padrão do NeoAgent';

  @override
  String get defaultOpenai => 'Padrão (OpenAI)';

  @override
  String get defaultRateLimits => 'Limites de taxa padrão';

  @override
  String get defaultRateLimitsSaved => 'Limites de taxa padrão salvos.';

  @override
  String get defaultRecommended => 'Padrão (recomendado)';

  @override
  String get defaultRouting => 'Roteamento padrão';

  @override
  String get defaultSpace => 'Espaço padrão';

  @override
  String get delete => 'Excluir';

  @override
  String get deleteAccount => 'Excluir conta';

  @override
  String get deleteAccountPermanently => 'Excluir conta permanentemente?';

  @override
  String get deleteAnAccount => 'Excluir uma conta';

  @override
  String deleteArg1(Object? arg1) {
    return 'Excluir @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Excluir ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return 'Excluir $arg1 $arg2 permanentemente?';
  }

  @override
  String get deleteBinding => 'Excluir vinculação';

  @override
  String get deleteCoreMemoryEntry => 'Excluir entrada de memória principal?';

  @override
  String get deleteForever => 'Excluir definitivamente';

  @override
  String get deleteMcpServer => 'Excluir servidor MCP?';

  @override
  String get deleteMemory => 'Excluir memória?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Excluir apaga permanentemente uma conta e todos os seus dados ';

  @override
  String get deleteRun => 'Excluir execução?';

  @override
  String get deleteRun2 => 'Excluir execução';

  @override
  String get deleteSelectedMemories => 'Excluir memórias selecionadas?';

  @override
  String get deleteSession => 'Excluir sessão?';

  @override
  String get deleteSkill => 'Excluir habilidade?';

  @override
  String get deleteTask => 'Excluir tarefa?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Excluído \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Excluído @$arg1 e todos os seus dados.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'A exclusão remove todas as suas conversas, memórias, arquivos, tarefas e ';

  @override
  String get deliverableArtifactProduced => 'Artefato entregável produzido';

  @override
  String get deliverableCompleted => 'Entrega concluída';

  @override
  String get deliverableExecutionStarted =>
      'A execução da entrega foi iniciada';

  @override
  String get deliverableSelected => 'Entregável selecionado';

  @override
  String get deliverableValidationFailed => 'Falha na validação da entrega';

  @override
  String get deliverableValidationStarted => 'Validação de entrega iniciada';

  @override
  String get deny => 'Negar';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Descreva o resultado e demonstre-o na área de trabalho';

  @override
  String get describeWhatToBuildOrChange =>
      'Descreva o que construir ou mudar…';

  @override
  String get description => 'Descrição';

  @override
  String get desktopApp => 'Aplicativo de desktop';

  @override
  String get desktopAppControlsAvailable =>
      'Controles de aplicativos de desktop disponíveis';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'A captura de desktop não está disponível nesta plataforma.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Upload da saída do comando da área de trabalho cancelado.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'O comando complementar da área de trabalho foi cancelado.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'A conexão complementar da área de trabalho expirou.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'O handshake complementar da área de trabalho expirou.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'O complemento para desktop não está disponível aqui.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'O complemento da área de trabalho está pausado localmente.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Falha no tratamento de mensagens complementares da área de trabalho: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'As configurações de permissão do complemento para desktop não estão disponíveis na web.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'As configurações de permissão do complemento da área de trabalho não estão disponíveis nesta plataforma.';

  @override
  String get desktopCompanionRejected =>
      'Complemento de área de trabalho rejeitado.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Falha na resposta complementar da área de trabalho: $arg1';
  }

  @override
  String get desktopControl => 'Controle da área de trabalho';

  @override
  String get desktopFailedToStart => 'Falha ao iniciar a área de trabalho';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Falha na captura de fluxo da área de trabalho: $arg1';
  }

  @override
  String get destinationId => 'ID de destino';

  @override
  String get deviceAccess => 'Acesso ao dispositivo';

  @override
  String get deviceSettings => 'Configurações do dispositivo';

  @override
  String get devices => 'Dispositivos';

  @override
  String get diagnosticsSaved => 'Diagnóstico salvo.';

  @override
  String get directBluebubblesImessageBridge =>
      'Ponte direta BlueBubbles iMessage';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'As mensagens diretas permanecem responsivas. Os grupos permitidos usam o modo de participação abaixo.';

  @override
  String get directoryDoesNotExist => 'O diretório não existe.';

  @override
  String get disable2fa => 'Desativar 2FA';

  @override
  String get disableAll => 'Desativar tudo';

  @override
  String get discard => 'Descartar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get disconnectHomeAssistant => 'Desconectar o Home Assistant?';

  @override
  String get disconnectNeorecall => 'Desconectar o NeoRecall?';

  @override
  String get disconnectNextcloud => 'Desconectar Nextcloud?';

  @override
  String get disconnectPlatform => 'Desconectar plataforma';

  @override
  String get disconnectTrello => 'Desconectar o Trello?';

  @override
  String get discoveryFailed => 'Falha na descoberta';

  @override
  String get dismiss => 'Dispensar';

  @override
  String get displayIdIsRequired => 'O ID de exibição é obrigatório.';

  @override
  String get displayName => 'Nome de exibição';

  @override
  String get displayNameMustBe64Characters =>
      'O nome de exibição deve ter 64 caracteres ou menos.';

  @override
  String get displayNameSaved => 'Nome de exibição salvo.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'Não inclua seu nome de usuário ou e-mail.';

  @override
  String get done => 'Concluído';

  @override
  String get downloadACopyOfYourData =>
      'Baixe uma cópia dos seus dados. As contas de administrador não podem ser excluídas ';

  @override
  String get downloadACopyOfYourData2 =>
      'Baixe uma cópia dos seus dados ou exclua permanentemente sua conta. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Baixar $arg1';
  }

  @override
  String get downloadUpdate => 'Baixar atualização';

  @override
  String get downloadingTheNeoagentBackend => 'Baixando o back-end do NeoAgent';

  @override
  String get draft => 'Rascunho';

  @override
  String get dragIsNotSupportedOnThis =>
      'arrastar não é compatível com esta plataforma.';

  @override
  String get draggedOnTheScreen => 'Arrastado na tela';

  @override
  String get dropAnApkOrApkBundle =>
      'Solte um APK ou pacote de APK aqui para instalá-lo';

  @override
  String get dropApkOrApksHere => 'Solte APK ou .apks aqui';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Instruções duráveis para voz e estilo de interação. As regras de segurança e execução ainda têm prioridade.';

  @override
  String get eGAlexSLaptop => 'por exemplo O laptop de Alex';

  @override
  String get eGMyLocalServer => 'por exemplo Meu servidor local';

  @override
  String get edit => 'Editar';

  @override
  String get editAgent => 'Editar agente';

  @override
  String get editCoreMemoryEntry => 'Editar entrada de memória principal';

  @override
  String get editInstructions => 'Editar instruções';

  @override
  String get editMcpServer => 'Editar servidor MCP';

  @override
  String get editTask => 'Editar tarefa';

  @override
  String editedArg1(Object? arg1) {
    return 'Editado $arg1';
  }

  @override
  String get email => 'E-mail';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Proprietários de contas de e-mail sobre logins que parecem incomuns.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Enviar e-mail aos proprietários da conta quando os detalhes da conta mudarem.';

  @override
  String get emailCode => 'Código de e-mail';

  @override
  String get emailConfirmationRequired => 'confirmação por e-mail necessária';

  @override
  String get emailIsAlreadyInUse => 'e-mail já está em uso';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'E-mail salvo. Se a confirmação for necessária, verifique o novo endereço para obter um link de confirmação do NeoAgent.';

  @override
  String get emailSettingsSaved => 'Configurações de e-mail salvas.';

  @override
  String get emailUnverified => 'E-mail não verificado';

  @override
  String get empty => 'Vazio';

  @override
  String get emptyFile => 'Arquivo vazio';

  @override
  String get emptyFolder => 'Pasta vazia';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Vazio usa o padrão do servidor ($arg1).';
  }

  @override
  String get enable2fa => 'Habilitar 2FA';

  @override
  String get enableAll => 'Habilitar tudo';

  @override
  String get enableBehaviorModules => 'Habilitar módulos de comportamento';

  @override
  String get enableOrDisableModels => 'Habilitar ou desabilitar modelos';

  @override
  String get enabled => 'Habilitado';

  @override
  String get encryptedPrivateToYourAccount =>
      'Criptografado, privado para sua conta';

  @override
  String get end => 'Fim';

  @override
  String get endCall => 'Encerrar chamada';

  @override
  String get endVoiceCall => 'Encerrar chamada de voz?';

  @override
  String get endpoint => 'Ponto final';

  @override
  String get enterAPassword => 'Digite uma senha.';

  @override
  String get enterAUsername => 'Digite um nome de usuário.';

  @override
  String get enterAValidEmailAddress => 'Insira um endereço de e-mail válido.';

  @override
  String get enterAnAddressManually => 'Insira um endereço manualmente';

  @override
  String get enterAnApiKeyFirst => 'Insira uma chave de API primeiro.';

  @override
  String get enterInviteLink => 'Insira o link do convite';

  @override
  String get enterTheAddressOfANeoagent =>
      'Insira o endereço de um servidor NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Insira os detalhes que $arg1 forneceu para que $arg2 possa enviar e receber mensagens.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Digite seu 2FA ou código de recuperação.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Digite sua senha atual para alterá-la.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Digite sua senha atual para salvar as alterações no e-mail.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Insira os detalhes da sua conta NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Digite seu nome de usuário ou e-mail da conta. O NeoAgent enviará um link de redefinição se corresponder à conta.';

  @override
  String get enterYourUsernameOrEmail =>
      'Digite seu nome de usuário ou e-mail.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entidade: $arg1';
  }

  @override
  String get environment => 'Meio Ambiente';

  @override
  String get error => 'Erro';

  @override
  String errorArg1(Object? arg1) {
    return '\nerro: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Erros do log recente, agrupados por mensagem.';

  @override
  String get errorsProblemsFailures => 'erros problemas falhas';

  @override
  String get eventTypesCommaSeparated =>
      'Tipos de eventos (separados por vírgula)';

  @override
  String get every15Minutes => 'A cada 15 minutos';

  @override
  String get every30Minutes => 'A cada 30 minutos';

  @override
  String get everyAccountOnThisServerLoses =>
      'Cada conta neste servidor perde esta chave compartilhada. Contas ';

  @override
  String get everyAccountOnThisServerUses =>
      'Cada conta neste servidor usa este endereço para ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Cada sessão ativa desta conta termina. Eles podem fazer login ';

  @override
  String get everyDay0800 => 'Todos os dias · 08:00';

  @override
  String get everyDay2000 => 'Todos os dias · 20:00';

  @override
  String get everyHour => 'A cada hora';

  @override
  String get everyRunOnThisServerAll =>
      'Cada execução neste servidor, o tempo todo.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Toda ferramenta sensível requer aprovação, sempre.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Todas as ferramentas são executadas sem necessidade de solicitação, exceto aquelas que a pessoa ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Todos nesses grupos, canais ou salas podem conversar com $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Todos neste grupo';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Tudo o que $arg1 desativou para seu agente vem ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Todo o resto está desligado.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Tudo está disponível na área de trabalho.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Tudo o que o agente pode usar: integrações oficiais, servidores MCP e habilidades.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Tudo o que você desligou para $arg1 volta ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Origens exatas da web com permissão para fazer solicitações de origem cruzada, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Execute JavaScript dentro da sessão do seu navegador.';

  @override
  String get execution => 'Execução';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Os detalhes de execução não estão disponíveis para esta execução.';

  @override
  String get executionPlanCreated => 'Plano de execução criado.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Sessões de exercício $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[sair $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Expira $arg1';
  }

  @override
  String get explainThisProject => 'Explique este projeto';

  @override
  String exploredArg1(Object? arg1) {
    return 'Explorado $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Explorado $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Explorou o espaço de trabalho';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Falha na exportação: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exportar as últimas 5 mensagens';

  @override
  String get exportMyData => 'Exportar meus dados';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Falha na inicialização do navegador externo com código de saída $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'A inicialização externa do navegador não é suportada nesta plataforma.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'A inicialização do navegador externo expirou.';

  @override
  String get externalMcpTools => 'Ferramentas externas e MCP';

  @override
  String get extraButtons => 'Botões extras';

  @override
  String get extractingTheNeoagentRuntime =>
      'Extraindo o tempo de execução do NeoAgent';

  @override
  String get failed => 'Falha';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'Falha ao conectar: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'Falha ao conectar $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'Falha ao excluir \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'não foi possível buscar';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'Falha ao gerar prompt: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'Falha ao iniciar o navegador externo via url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'Falha ao iniciar o fluxo OAuth.';

  @override
  String get failedToLoadPolicies => 'Falha ao carregar políticas';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'Falha ao salvar: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'Falha ao salvar o servidor MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'Falha ao salvar seleção: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'Falha ao enviar notificação para back-end: $arg1';
  }

  @override
  String get fair => 'Justo';

  @override
  String get fasterReplies => 'Respostas mais rápidas';

  @override
  String get fewerModelCalls => 'Menos chamadas de modelo';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'campo vazio para restaurar o padrão integrado.';

  @override
  String get fileExceedsThe1MibEditor =>
      'O arquivo excede o limite do editor de 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'O arquivo excede o limite de tamanho suportado.';

  @override
  String get fileWrites => 'Gravações de arquivo';

  @override
  String get filename => 'Nome do arquivo';

  @override
  String get files => 'Arquivos';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Os arquivos que o NeoAgent grava ou edita nesta sessão aparecem aqui.';

  @override
  String get filesSavedByAllUsers => 'Arquivos salvos por todos os usuários';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Preencha logins aprovados ou autentique solicitações sem mostrar segredos à IA.';

  @override
  String get finalResponse => 'Resposta Final';

  @override
  String get findAPlatform => 'Encontre uma plataforma';

  @override
  String get findAndFixABug => 'Encontre e corrija um bug';

  @override
  String get findRecentChats => 'Encontre bate-papos recentes';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Encontrando o tempo de execução correto do NeoAgent';

  @override
  String get finish => 'Concluir';

  @override
  String get finishAtTheScheduledTime => 'Termine no horário programado';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Conclua o login no $arg1 em seu navegador e conecte-se novamente.';
  }

  @override
  String get flowGraph => 'Gráfico de fluxo';

  @override
  String get flutterApp => 'Aplicativo flutuante';

  @override
  String get focusedExecutionProfile => 'Perfil de execução focado';

  @override
  String get folderIdOptional => 'ID da pasta (opcional)';

  @override
  String get folderUnavailable => 'Pasta indisponível';

  @override
  String get forExampleHttpsMatrixOrg => 'Por exemplo https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Para configurações de rede hospedadas ou avançadas';

  @override
  String get forLinksInEmailsBlankUses =>
      'Para links em e-mails. Em branco usa a URL pública do servidor.';

  @override
  String get forgotPassword => 'Esqueceu sua senha?';

  @override
  String get frameUnavailable => 'Quadro indisponível';

  @override
  String freshnessArg1(Object? arg1) {
    return 'frescor: $arg1';
  }

  @override
  String get fridays1700 => 'Sextas-feiras · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Do BotFather depois de criar o bot.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'A partir de agora, $arg1 decide quais ferramentas seu agente pode usar. Eles ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'No Portal do Desenvolvedor Discord, em seu bot.';

  @override
  String get fromTheLineDevelopersConsole =>
      'No console de desenvolvedores do LINE.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Do cliente Matrix ou da conta do bot.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Em twitchapps.com/tmi ou em seu aplicativo de desenvolvedor Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Solicitação completa';

  @override
  String get fullSetup => 'Configuração completa';

  @override
  String get general => 'Geral';

  @override
  String get generalSettings => 'Configurações gerais';

  @override
  String get generalSettingsSaved => 'Configurações gerais salvas.';

  @override
  String get generateAPromptForAnotherAi =>
      'Gere um prompt para outra IA, cole a resposta aqui para importar memórias.';

  @override
  String get generatePrompt => 'Gerar prompt';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Erro de rastreamento de cerca geográfica: $arg1';
  }

  @override
  String get getInspired => 'Inspire-se';

  @override
  String get githubCopilot => 'Copiloto GitHub';

  @override
  String get githubCopilotAndOpenaiCodex => 'Copiloto GitHub e OpenAI Codex';

  @override
  String get githubIssueOpened => 'Problema do GitHub aberto';

  @override
  String get neorecallMemoryCreated => 'Memória NeoRecall criada';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'A verificação de versão do GitHub falhou com HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'A carga útil de lançamento do GitHub não era uma lista de lançamentos.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Nome de usuário do GitHub que abriu o problema';

  @override
  String get globalSecurityMode => 'Modo de segurança global';

  @override
  String get gmailMessageReceived => 'Mensagem do Gmail recebida';

  @override
  String get good => 'Bom';

  @override
  String get goodAfternoon => 'Boa tarde';

  @override
  String get goodEvening => 'Boa noite';

  @override
  String get goodMorning => 'Bom dia';

  @override
  String get goodPasswordALittleMoreLength =>
      'Boa senha. Um pouco mais de comprimento torna-o mais forte.';

  @override
  String get googleChat => 'Bate-papo do Google';

  @override
  String get googleWorkspace => 'Google Workspace';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live usa sua chave de API OpenAI, Gemini Live sua chave de IA do Google. As alterações se aplicam à próxima chamada.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Conceda permissões do Health Connect antes de sincronizar.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupo, canal ou sala';

  @override
  String get groupType => 'Tipo de grupo';

  @override
  String get groupsAndChannels => 'Grupos e canais';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupos: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Os grupos que $arg1 ainda não viu seguirão isso.';
  }

  @override
  String get handlesDirectTasksItself => 'Lida sozinho com tarefas diretas';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Viva-voz (fale livremente, interrompa a qualquer momento)';

  @override
  String get headerName => 'Nome do cabeçalho';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Manchetes sobre os tópicos de seu interesse, filtradas para sinalização.';

  @override
  String get health => 'Saúde';

  @override
  String get healthChecks => 'Verificações de saúde';

  @override
  String get healthConnect => 'conexão de saúde';

  @override
  String get healthConnectIsNotAvailableOn =>
      'O Health Connect não está disponível neste dispositivo.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Status de sincronização do Health Connect e métricas de back-end armazenadas.';

  @override
  String get healthStatusIsUnavailable =>
      'O estado de saúde não está disponível.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'A sincronização de saúde está disponível apenas no Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Registros do coração $arg1';
  }

  @override
  String get heldBack => 'Retido';

  @override
  String get helper => 'Ajudante';

  @override
  String helperArg1(Object? arg1) {
    return 'Ajudante: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'aqui. Revogue o administrador com `neoagent admin revoga $arg1` primeiro.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Valores mais altos tornam o NeoAgent mais seletivo em grupos.';

  @override
  String get highlyRecommended => 'Altamente recomendado';

  @override
  String get holdButton131ForTheAssistant =>
      'Segure o botão 131 para o assistente.';

  @override
  String get holdCtrlShiftSpaceToTalk => 'Segure Ctrl+Shift+Espaço para falar';

  @override
  String get holdToTalk => 'Espere para falar.';

  @override
  String get holdToTalk2 => 'Espere para falar';

  @override
  String get home => 'Página inicial';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'É necessário o token de acesso de longa duração do Home Assistant.';

  @override
  String get homeAssistantSetup => 'Configuração do assistente doméstico';

  @override
  String get homeAssistantUrl => 'URL do assistente doméstico';

  @override
  String get homeAssistantUrlIsRequired =>
      'O URL do Home Assistant é obrigatório.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token de servidor doméstico com pesquisa de sala';

  @override
  String get homeserverUrl => 'URL do servidor doméstico';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'serviço hospedado). Suas chaves são criptografadas e só podem ser usadas por ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Nome do host da rede IRC, por exemplo irc.libera.chat';

  @override
  String get hourly => 'De hora em hora';

  @override
  String get hourlyInboxCheck => 'Verificação da caixa de entrada por hora';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Por quanto tempo os links de confirmação permanecem válidos.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Com que frequência esse agente procura novas mensagens de sala.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Com que frequência este agente procura novas mensagens do Signal.';

  @override
  String get howTeamsWork => 'Como as equipes funcionam';

  @override
  String get howThisServerIsReachedPlus =>
      'Como esse servidor é alcançado, além de switches em todo o servidor.';

  @override
  String get httpsSessionCookie => 'cookie de sessão https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'Não consegui concluir essa solicitação agora. Por favor, tente novamente em alguns instantes.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'Inativo';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Se $arg1 solicitar um URL de webhook, cole-o para que as mensagens possam chegar a $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Se essa conta tiver um e-mail confirmado, o NeoAgent enviará um link de redefinição de senha.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Se o serviço exigir um token nas solicitações de saída.';

  @override
  String get ignoreGroups => 'Ignorar grupos';

  @override
  String get ignoreThisChat => 'Ignorar este bate-papo';

  @override
  String get ignoredChannels => 'Canais ignorados';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Mensagem complementar de área de trabalho malformada ignorada: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Imp $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implemente o plano acima.';

  @override
  String get implementThisPlan => 'Implementar este plano';

  @override
  String get implicitTls => 'TLS implícito';

  @override
  String get import => 'Importar';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Falha na importação: $arg1';
  }

  @override
  String get importFromComputer => 'Importar do computador';

  @override
  String get importMemoryTransfer => 'Importar transferência de memória?';

  @override
  String get importance => 'Importância';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Memórias $arg1 importadas, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'Na equipe de @$arg1';
  }

  @override
  String get inBackground => 'plano de fundo';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'As mensagens do canal recebidas e enviadas aparecerão aqui.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Chamadas de voz recebidas no aplicativo do NeoAgent';

  @override
  String get incomingMessages => 'Mensagens recebidas';

  @override
  String get incomingNeoagentCall => 'Chamada NeoAgent recebida';

  @override
  String get incomingNeoagentCall2 => 'CHAMADA DE NEOAGENTE RECEBIDA';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Suporte para webhook de entrada e retorno de chamada de saída';

  @override
  String get incorporatingSteering => 'Incorporando direção';

  @override
  String get input => 'Entrada';

  @override
  String get inputMode => 'Modo de entrada';

  @override
  String get insertATemplate => 'Insira um modelo';

  @override
  String get install => 'Instalar';

  @override
  String get installASignedSelfContainedRuntime =>
      'Instale um tempo de execução independente e assinado. Node.js, npm, Git e comandos de terminal não são necessários.';

  @override
  String get installApk => 'Instalar APK';

  @override
  String get installApkBundle => 'Instalar APK/pacote';

  @override
  String get installApkClickOrDropA =>
      'Instale o APK – clique ou solte um arquivo .apk';

  @override
  String get installNeoagent => 'Instale o NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Instale o NeoAgent neste computador sem um terminal ou conecte-se a um que já esteja em execução.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Instale novos lançamentos e escolha qual canal este servidor segue.';

  @override
  String get installTheBackend => 'Instale o back-end';

  @override
  String get installTheCoreWithExtraOptional =>
      'Instale o núcleo com configuração opcional extra. As chaves do provedor de IA são adicionadas posteriormente, da mesma forma que o Quickstart.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Instale o núcleo seguro e crie sua conta. Adicione chaves do provedor de IA posteriormente.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Instalado: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Instalado: $arg1 • Última verificação: $arg2';
  }

  @override
  String get instructions => 'Instruções';

  @override
  String get integration => 'Integração';

  @override
  String get integrationConnections => 'Conexões de integração';

  @override
  String get integrationSettingsSaved => 'Configurações de integração salvas.';

  @override
  String get integrations => 'Integrações';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integrações/oauth/callback e registre o mesmo ';

  @override
  String get interruptAi => 'Interromper IA';

  @override
  String get invalid2fa => '2fa inválido';

  @override
  String get invalidArgumentS => 'Argumentos inválidos: ';

  @override
  String get invalidCredentials => 'credenciais inválidas';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Manifesto de tempo de execução do NeoAgent inválido.';

  @override
  String get inviteLink => 'Link de convite';

  @override
  String get inviteLinkReady => 'Link de convite pronto';

  @override
  String get inviteLinks => 'Links de convite';

  @override
  String get iphoneApp => 'aplicativo para iPhone';

  @override
  String get issues => 'Problemas';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Os problemas aparecem quando o log é carregado.';

  @override
  String get itCanTBeUndone => 'Não pode ser desfeito.';

  @override
  String get itMayHaveBeenDeleted => 'Pode ter sido excluído.';

  @override
  String get javaRuntime => 'tempo de execução java';

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
    return 'Ingressou no $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Entrou nos últimos 7 dias';

  @override
  String get joiningATeam => 'Juntando-se a uma equipe';

  @override
  String get joiningIsOffHere => 'A adesão está desativada aqui';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Campo JSON que contém o texto da mensagem. Geralmente texto.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Campo JSON que identifica a quem se destina a mensagem.';

  @override
  String get jumpToLatest => 'Ir para o mais recente';

  @override
  String get justNow => 'agora mesmo';

  @override
  String get keepNeoagentRunning => 'Manter o NeoAgent funcionando?';

  @override
  String get keepRunning => 'Continue correndo';

  @override
  String get keepTaskRunning => 'Mantenha a tarefa em execução';

  @override
  String get keepTheVaultAvailable => 'Mantenha o cofre disponível';

  @override
  String get keepThisLauncherUpToDate => 'Mantenha este lançador atualizado.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Mantenha este painel aberto até que a plataforma confirme a conexão.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Manter o computador desta sessão visível';

  @override
  String get keepTrackOfYourAiUsage =>
      'Acompanhe seu uso de IA. Os limites são aplicados para garantir o uso justo em toda a plataforma.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Continue usando seus aplicativos normalmente. O NeoAgent funciona na mesma tela e pergunta sempre que precisa de novo acesso.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Mantendo este dispositivo conectado';

  @override
  String get key => 'Chave';

  @override
  String get keyIsRequired => 'A chave é obrigatória.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Pares de valores-chave que persistem nas conversas.';

  @override
  String get knowledgeGraph => 'Gráfico de conhecimento';

  @override
  String get knowledgeView => 'Visualização de conhecimento';

  @override
  String get labelOnlyYouSeeIt => 'Etiqueta (só você vê)';

  @override
  String get labelsOptional => 'Etiquetas (opcional)';

  @override
  String get last24Hours => 'Últimas 24 horas';

  @override
  String get last7Days => 'Últimos 7 dias';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Últimos 7 dias: tokens $arg1 em execuções $arg2';
  }

  @override
  String lastArg1(Object? arg1) {
    return 'Último $arg1';
  }

  @override
  String lastArg12(Object? arg1) {
    return 'Último: $arg1';
  }

  @override
  String lastNonEmptySyncArg1(Object? arg1) {
    return 'Última sincronização não vazia · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Última execução: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Visto pela última vez $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Último login $arg1';
  }

  @override
  String get lastSyncSummary => 'Resumo da última sincronização';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Último uso: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Última janela terminou $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'mais tarde, o início também está desligado.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Última execução · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'O lançamento de aplicativos de desktop não é compatível com esta plataforma.';

  @override
  String get learnRoomNorms => 'Aprenda as normas do quarto';

  @override
  String get leave => 'Sair';

  @override
  String get leaveARedirectUriBlankTo =>
      'Deixe um URI de redirecionamento em branco para usar <URL público>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return 'Sair da equipe de $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Deixe como padrão, a menos que você tenha personalizado o BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Deixe o token vazio para manter o token armazenado atualmente.';

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
    return 'Deixe $arg1 me gerenciar';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Deixe todos neste grupo falarem com $arg1.';
  }

  @override
  String get letItWorkWhileYouDon => 'Deixe funcionar\nenquanto você não faz.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Deixe o NeoAgent clicar, digitar e navegar pelos seus aplicativos.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Deixe o NeoAgent entender o que está visível na sua tela.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Deixe alguém com quem você trabalha decidir quais ferramentas seu agente pode ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Deixe esta pessoa enviar uma mensagem individual para $arg1.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Deixe esta pessoa falar com $arg1 aqui, mas não em chats privados ou outros grupos.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Deixe essa pessoa conversar com $arg1 em chats privados e em qualquer grupo que ela compartilhe.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Nível $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Ligação $arg1';
  }

  @override
  String get linkCopied => 'Link copiado';

  @override
  String get linkExpiresAfter => 'O link expira depois';

  @override
  String get linkLifetimeHours => 'Vida útil do link (horas)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'A vida útil do link deve ser de 1 a 8.760 horas.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Link válido até $arg1.';
  }

  @override
  String get linkedSignInProviders => 'Provedores de login vinculados';

  @override
  String get linuxApp => 'Aplicativo Linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Listado $arg1/';
  }

  @override
  String get listening => 'Ouvindo';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Histórico de execução ao vivo, etapas da ferramenta e respostas.';

  @override
  String get liveModel => 'Modelo ao vivo';

  @override
  String get liveModelProvider => 'Provedor de modelo ao vivo';

  @override
  String get liveRun => 'Corrida ao vivo';

  @override
  String get liveVoice => 'Voz ao vivo';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'A conexão de voz ao vivo não está disponível.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'A conexão de voz ao vivo foi encerrada.';

  @override
  String get liveVoiceDefaults => 'Padrões de voz ao vivo';

  @override
  String get liveVoiceFailed => 'A voz ao vivo falhou.';

  @override
  String get llmMemoryExportResponse => 'Resposta de exportação de memória LLM';

  @override
  String get loadFailed => 'falha no carregamento';

  @override
  String get loadingExecutionDetails => 'Carregando detalhes da execução...';

  @override
  String get loadingNeoagent => 'Carregando NeoAgent';

  @override
  String get loadingRunFlow => 'Carregando fluxo de execução…';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'URLs de redes locais e privadas são suportadas quando o servidor NeoAgent pode acessá-las. O áudio nunca é exposto ao NeoAgent.';

  @override
  String get localApp => 'aplicativo local';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'A instalação de back-end local não está disponível nesta plataforma.';

  @override
  String get localBaseImagePath => 'Caminho da imagem base local';

  @override
  String get localComputerControlIsAvailableIn =>
      'O controle local do computador está disponível no aplicativo de desktop NeoAgent no macOS, Windows e Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'O controle local do computador não está disponível aqui.';

  @override
  String get localModelsUrl => 'URL de modelos locais';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'A descoberta local do NeoAgent está temporariamente indisponível.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Preferências locais para o aplicativo NeoAgent. O controle do computador sempre é executado por meio do computador em nuvem unificado.';

  @override
  String get localSetup => 'CONFIGURAÇÃO LOCAL';

  @override
  String get locationCityOrPlace => 'Localização (cidade ou local)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'A localização é obrigatória para acionadores de eventos climáticos';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'Falha na inicialização do LocationService: $arg1';
  }

  @override
  String get logCopied => 'Registro copiado';

  @override
  String get loginPassword => 'Senha de login';

  @override
  String get logout => 'Sair';

  @override
  String get logs => 'Registros';

  @override
  String get logsCopied => 'Registros copiados.';

  @override
  String get logsOnThisComputer => 'Registros neste computador';

  @override
  String get longLivedAccessToken => 'Token de acesso de longa duração';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Recordação de longo prazo, fatos estruturados e gráfico de conhecimento.';

  @override
  String get lookedAtTheScreen => 'Olhou para a tela';

  @override
  String get lookingOnThisComputerAndYour =>
      'Olhando neste computador e na sua rede local…';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Antecipe as reuniões de amanhã para que nada o surpreenda.';

  @override
  String get loopExecution => 'Execução de loop';

  @override
  String get loopPaused => 'Loop pausado';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'A acessibilidade do macOS não é concedida ao NeoAgent. Permita em Configurações do sistema › Privacidade e segurança › Acessibilidade.';

  @override
  String get macosApp => 'aplicativo macOS';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'A gravação de tela do macOS não é concedida ao NeoAgent. Permita-o em Configurações do sistema › Privacidade e segurança › Gravação de tela e reabra o NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Os servidores de e-mail que precisam de uma senha se recusarão a enviar até que uma nova ';

  @override
  String get main => 'Principal';

  @override
  String get makeDefault => 'Tornar padrão';

  @override
  String get manage => 'Gerenciar';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Gerencie o e-mail da sua conta, autenticação de dois fatores e sessões ativas.';

  @override
  String get managedBy => 'Gerenciado por';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Os gerentes podem ter seus próprios gerentes (até quatro níveis). Um ';

  @override
  String get managing => 'Gerenciando';

  @override
  String get manualDestination => 'Destino manual';

  @override
  String get manualTrigger => 'Gatilho manual';

  @override
  String get masterPassword => 'Senha mestra';

  @override
  String get matchThisDevice => 'Corresponder a este dispositivo';

  @override
  String get matchedAgainstTitleAndBody => 'Comparado com título e corpo';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Corresponde ao antigo fluxo NeoAgent MCP: URL mais método de autenticação.';

  @override
  String get mcp => 'PCM';

  @override
  String get mcpServer => 'Servidor MCP';

  @override
  String get mcpServer2 => 'Servidor MCP';

  @override
  String get mcpServerUrl => 'URL do servidor MCP';

  @override
  String get mcpServers => 'Servidores MCP';

  @override
  String get meantForSomeoneElse => 'Destinado a outra pessoa';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Custo medido do modelo: $arg1';
  }

  @override
  String get memories => 'Memórias';

  @override
  String get memory => 'Memória';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memória: $arg1';
  }

  @override
  String get memoryInjected => 'Memória injetada';

  @override
  String get mentionOrReplyOnly => 'Mencione ou responda apenas';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Logs mesclados do servidor e do tempo de execução do Flutter para esta sessão do aplicativo.';

  @override
  String get messageBodyTemplateJson => 'Modelo de corpo de mensagem (JSON)';

  @override
  String get messageNeedsAccess => 'A mensagem precisa de acesso';

  @override
  String get messageTextField => 'Campo de texto da mensagem';

  @override
  String get messaging => 'Mensagens';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Eventos push e webhook da API de mensagens';

  @override
  String get messagingConnectionNeedsAttention =>
      'A conexão de mensagens precisa de atenção';

  @override
  String get messagingConnections => 'Conexões de mensagens';

  @override
  String get messagingDelivery => 'Entrega de mensagens';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Erro de mensagens. Por favor, tente novamente.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'A captura do microfone parou inesperadamente. Tente novamente.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Erro de microfone: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Microfone silenciado. Toque para ativar o som.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'A permissão do microfone é necessária para voz ao vivo.';

  @override
  String get microsoft365 => 'Microsoft 365';

  @override
  String get microsoftTeams => 'Equipes da Microsoft';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Valor mínimo de contribuição: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'Falha na configuração móvel.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'A configuração móvel falhou porque o Java não está disponível na máquina que executa o NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'A configuração móvel falhou porque o Java não está disponível na máquina que executa o NeoAgent. Instale um JDK e tente novamente.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'Falha na configuração móvel. Verifique se as ferramentas do Android estão instaladas corretamente e tente novamente.';

  @override
  String modeArg1(Object? arg1) {
    return 'modo: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'O modo é bloqueado enquanto uma execução está ativa.';

  @override
  String get model => 'Modelo';

  @override
  String modelArg1(Object? arg1) {
    return 'Modelo: $arg1';
  }

  @override
  String get modelAvailability => 'Disponibilidade do modelo';

  @override
  String get modelAvailabilitySaved => 'Disponibilidade do modelo salva.';

  @override
  String get modelForThisSession => 'Modelo para esta sessão';

  @override
  String get modelOverride => 'Substituição de modelo';

  @override
  String get modelPending => 'Modelo pendente';

  @override
  String get modelTurn => 'Virada do modelo';

  @override
  String get modelTurnCompleted => 'Viragem do modelo concluída';

  @override
  String get modelTurnStarted => 'A virada do modelo começou';

  @override
  String get modelVisibilityHideShowList =>
      'visibilidade do modelo ocultar mostrar lista';

  @override
  String get models => 'Modelos';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modelos, comportamento, voz e espaço de trabalho';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modelos, navegador, voz, diagnóstico...';

  @override
  String get modelsRouting => 'Modelos e roteamento';

  @override
  String get monthly => 'Mensalmente';

  @override
  String get moreActions => 'Mais ações';

  @override
  String get morningBriefing => 'Briefing matinal';

  @override
  String get mostUsedAgents => 'Agentes mais usados';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Modelos mais utilizados no último $arg1.';
  }

  @override
  String get mouseKeyboard => 'Rato e teclado';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove não é compatível com esta plataforma.';

  @override
  String get mustBeReachableOnThePublic =>
      'Deve ser acessível na Internet pública - local e ';

  @override
  String get n24Hours => '24 horas';

  @override
  String get n2faOrRecoveryCode => '2FA ou código de recuperação';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA requer que SESSION_SECRET seja configurado nesta implantação do NeoAgent.';

  @override
  String get n30Days => '30 dias';

  @override
  String get n365Days => '365 dias';

  @override
  String get n4HourLimitTokens => 'Limite de 4 horas (tokens)';

  @override
  String get n4HourUsage => 'Uso de 4 horas';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Limite de 4h $arg1';
  }

  @override
  String get n7DayUsage => 'Uso de 7 dias';

  @override
  String get n7Days => '7 dias';

  @override
  String get n90Days => '90 dias';

  @override
  String get name => 'Nome';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnome: Nova Habilidade\ndescription: Descreva o que esta habilidade faz\n---\nEscreva as instruções para esta habilidade aqui.\n';

  @override
  String get nameOfWhoeverMadeIt => 'nome de quem fez isso.';

  @override
  String get nameOptional => 'Nome (opcional)';

  @override
  String get nativeAndWebhookChannels => 'Canais nativos e webhook';

  @override
  String get naturalBubbles => 'Bolhas naturais';

  @override
  String get nearbyNeoagentServers => 'Servidores NeoAgent próximos';

  @override
  String get needANewAccountRegister =>
      'Precisa de uma nova conta? Cadastre-se';

  @override
  String get needAnIdea => 'Precisa de uma ideia?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Preciso responder · $arg1% para falar';
  }

  @override
  String get needsAttention => 'Precisa de atenção';

  @override
  String get needsInput => 'Precisa de informações';

  @override
  String get neoagentApp => 'Aplicativo NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgente, $arg1';
  }

  @override
  String get neoagentAssistant => 'Assistente NeoAgente';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'O NeoAgent não pôde verificar o tempo de execução de back-end disponível.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'O NeoAgent não conseguiu concluir a configuração local.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'O NeoAgent não conseguiu concluir a configuração local. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Informações de depuração do NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'Instalador do NeoAgent Desktop';

  @override
  String get neoagentFlutterUpdater => 'Atualizador NeoAgent Flutter';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent instala o $arg1 mais recente ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'O NeoAgent está instalado e em execução.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'O NeoAgent não está instalado neste computador.';

  @override
  String get neoagentIsReady => 'NeoAgent está pronto';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent ainda está trabalhando em uma tarefa. Encerre a ligação e obtenha o resultado no chat, ou cancele a tarefa também.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'O NeoAgent está transformando sua demonstração em um fluxo de trabalho adaptável.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'O NeoAgent está esperando enquanto você usa a área de trabalho.';

  @override
  String get neoagentIsWorking => 'NeoAgent está funcionando';

  @override
  String get neoagentLinuxComputer => 'Computador NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENTE PRECISA DE UMA DECISÃO';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgente <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Os downloads do tempo de execução do NeoAgent exigem um endereço seguro.';

  @override
  String get neoagentServerAddress => 'Endereço do servidor NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'O e-mail do serviço NeoAgent não está pronto. Peça ao operador do servidor para verificar as configurações do ambiente de e-mail.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'A configuração do NeoAgent não pôde ser concluída.';

  @override
  String get neoagentUser => 'Usuário NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'O NeoAgent usa este computador automaticamente e pergunta antes de usar sua tela, mouse, teclado, arquivos ou linha de comando.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'O NeoAgent usa sua localização aproximada de fundo para acionar lembretes de cerca geográfica (por exemplo, \"Lembre-me de comprar leite quando passar pelo supermercado\").\n\n';

  @override
  String get neoagentWorkspace => 'Espaço de trabalho do NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][pilha] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'URL de back-end do NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'O URL de back-end do NeoRecall é obrigatório.';

  @override
  String get neorecallSetup => 'Configuração do NeoRecall';

  @override
  String get networkRequestFailed => 'solicitação de rede falhou';

  @override
  String get networkWriteRequests => 'Solicitações de gravação de rede';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nunca é contabilizado nos limites de uso compartilhado.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Novas contas confirmam seus endereços de e-mail antes de fazer login.';

  @override
  String get newAccountsPerDay => 'Novas contas por dia';

  @override
  String get newChat => 'Novo bate-papo';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Novos grupos permanecem silenciosos, a menos que alguém marque $arg1, até que você os ative.';
  }

  @override
  String get newLink => 'Novo link';

  @override
  String get newPasswordsDoNotMatch => 'As novas senhas não coincidem.';

  @override
  String get newRecoveryCodes => 'Novos códigos de recuperação';

  @override
  String get newSession => 'Nova sessão';

  @override
  String get newSessionN => 'Nova sessão (⌘N)';

  @override
  String get newSessionWithSameSetup => 'Nova sessão com a mesma configuração';

  @override
  String get newSkill => 'Nova habilidade';

  @override
  String get newSkill2 => 'Nova habilidade';

  @override
  String get newThisWeek => 'Novidade esta semana';

  @override
  String get newsDigest => 'Resumo de notícias';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Próxima tentativa: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Fluxo de login do Nextcloud';

  @override
  String get nextcloudSetup => 'Configuração do Nextcloud';

  @override
  String get nextcloudTalk => 'Conversa sobre próxima nuvem';

  @override
  String get nextcloudUrl => 'URL da próxima nuvem';

  @override
  String get nextcloudUrlIsRequired => 'O URL Nextcloud é obrigatório.';

  @override
  String get nickname => 'Apelido';

  @override
  String get noAccountsConnectedYet => 'Nenhuma conta conectada ainda.';

  @override
  String get noAccountsFound => 'Nenhuma conta encontrada.';

  @override
  String get noActiveSessionsFound => 'Nenhuma sessão ativa encontrada.';

  @override
  String get noAgentsYet => 'Nenhum agente ainda';

  @override
  String get noAiProviderIsConfiguredSo =>
      'Nenhum provedor de IA está configurado, então bate-papo e mensagens ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Sem solicitações de aprovação — o agente funciona sem interrupção.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Nenhum ativo de lançamento $arg1 correspondeu a esta plataforma.';
  }

  @override
  String get noArguments => '(sem argumentos)';

  @override
  String get noAuth => 'Sem autorização';

  @override
  String get noBindingsYet => 'Nenhuma ligação ainda.';

  @override
  String get noChangesYet => 'Ainda não há alterações';

  @override
  String get noChannelsFound => 'Nenhum canal encontrado';

  @override
  String get noCloudComputerSlotIsFree =>
      'Nenhum slot de computador em nuvem é gratuito no momento. Tente novamente em alguns instantes.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Nenhuma entrada de memória principal ainda.';

  @override
  String get noDescription => 'Sem descrição';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Nenhum monitor de desktop está disponível no momento.';

  @override
  String get noDetailAvailable => 'Nenhum detalhe disponível';

  @override
  String get noDetailedSyncSummaryYet =>
      'Ainda não há resumo detalhado da sincronização.';

  @override
  String get noDetailsCaptured => 'Nenhum detalhe capturado.';

  @override
  String get noEmailLinked => 'Nenhum e-mail vinculado';

  @override
  String get noExternalSignInProvidersLinked =>
      'Nenhum provedor de login externo vinculado.';

  @override
  String get noGroupMessagesYet => 'Ainda não há mensagens de grupo';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Nenhuma pessoa específica do grupo foi adicionada ainda.';

  @override
  String get noGroupsAddedYet => 'Nenhum grupo adicionado ainda.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Nenhum grupo encontrado ainda. Depois que $arg1 vir uma mensagem de grupo, use Encontrar bate-papos recentes e eles aparecerão aqui.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Nenhum grupo encontrado ainda. Depois que $arg1 vir uma mensagem de grupo, use Encontrar bate-papos recentes.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'Nenhuma carga útil de dados de saúde foi retornada.';

  @override
  String get noHealthSamplesStoredYet =>
      'Nenhuma amostra de saúde armazenada ainda.';

  @override
  String get noHttpClientImplementationForThis =>
      'Nenhuma implementação de cliente HTTP para esta plataforma.';

  @override
  String get noInputOrOutputWasRecorded =>
      'Nenhuma entrada ou saída foi registrada para esta etapa.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'Nenhuma integração corresponde a esta pesquisa.';

  @override
  String get noLimit => 'Sem limite';

  @override
  String get noLocalPasswordIsSetYet =>
      'Nenhuma senha local foi definida ainda. Crie um para ativar o login com nome de usuário/senha.';

  @override
  String get noLogEntries => 'Nenhuma entrada de registro.';

  @override
  String get noMatchingSettings => 'Nenhuma configuração correspondente';

  @override
  String get noMcpServersMatchThisSearch =>
      'Nenhum servidor MCP corresponde a esta pesquisa.';

  @override
  String get noMemoryEntriesFound => 'Nenhuma entrada de memória encontrada.';

  @override
  String get noMemorySync => 'Sem sincronização de memória';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Lê uma única vez o correio importante e enviado dos últimos 12 meses, para que o agente conheça os seus contactos e projetos.';

  @override
  String get emailMemory => 'Memória de e-mail';

  @override
  String get importNow => 'Importar agora';

  @override
  String get importOnConnect => 'Importar correio anterior ao ligar uma conta';

  @override
  String get sweepStarting => 'A preparar…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'A ler e-mails · $done de $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'A ler e-mails · $count encontrados';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'A aprender com os e-mails · $done de $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Última importação: $emails e-mails · $memories memórias novas';
  }

  @override
  String get sweepNothingNew => 'Não há e-mails novos para importar';

  @override
  String sweepFailed(String error) {
    return 'A importação falhou: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Nenhum modelo corresponde a \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'Nenhuma solicitação de modelo foi registrada para esta execução.';

  @override
  String get noModelsDiscoveredYet => 'Nenhum modelo descoberto ainda';

  @override
  String get noModelsSelected => 'Nenhum modelo selecionado';

  @override
  String get noModelsYet => 'Ainda não há modelos';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'nenhuma conta de neoagente está vinculada a este provedor';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'Nenhum tempo de execução de back-end do NeoAgent está disponível para este computador.';

  @override
  String get noNetworkConnection => 'Sem conexão de rede';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Sem conexão de rede. Conecte-se para continuar usando o NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Sem conexão de rede. Reconecte para verificar se há atualizações.';

  @override
  String get noOne => 'Ninguém';

  @override
  String get noOneAddedYet => 'Ninguém adicionou ainda.';

  @override
  String get noOneCanMessage => 'Ninguém pode enviar mensagens';

  @override
  String get noOtherNeoagentServerWasFound =>
      'Nenhum outro servidor NeoAgent foi encontrado. Você pode pesquisar novamente ou inserir um endereço manualmente.';

  @override
  String get noPeopleAddedYet => 'Nenhuma pessoa adicionada ainda.';

  @override
  String get noPlatformsMatch => 'Nenhuma plataforma corresponde';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Nenhum provedor está disponível para configuração ainda.';

  @override
  String get noRecentChannelActivity => 'Nenhuma atividade recente no canal';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'Nenhum resultado para \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'Não há execuções nesta faixa.';

  @override
  String get noRunsMatchTheseFilters =>
      'Nenhuma execução corresponde a esses filtros';

  @override
  String get noRunsYet => 'Ainda não há corridas';

  @override
  String get noRunsYet2 => 'Ainda não há corridas.';

  @override
  String get noSecurityKeyWasProvided =>
      'Nenhuma chave de segurança foi fornecida.';

  @override
  String get noServerUrlSet => 'Nenhum URL do servidor definido';

  @override
  String get noSessionMatchesThatSearch =>
      'Nenhuma sessão corresponde a essa pesquisa.';

  @override
  String get noSessionsYet => 'Ainda não há sessões';

  @override
  String get noSkillsMatchTheseFilters =>
      'Nenhuma habilidade corresponde a esses filtros.';

  @override
  String get noStepsWereRecordedForThis =>
      'Nenhuma etapa foi registrada para esta execução.';

  @override
  String get noSummaryAvailable => 'Nenhum resumo disponível.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'Nenhuma tarefa para $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Nenhuma ferramenta corresponde a \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'Nenhuma atualização em execução';

  @override
  String get noUsageYet => 'Ainda não há uso.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Nenhum tempo de execução de back-end verificado do NeoAgent está disponível ainda.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Ninguém pode mais usá-lo. Pessoas que já aderiram ';

  @override
  String get none => 'Nenhum';

  @override
  String get notApprovedYet => 'ainda não aprovado';

  @override
  String get notAuthenticated => 'não autenticado';

  @override
  String get notCheckedYet => 'Ainda não verificado';

  @override
  String get notConfigured => 'Não configurado';

  @override
  String get notConnected => 'Não conectado';

  @override
  String get notConnected2 => 'Não conectado';

  @override
  String get notInstalled => 'Não instalado';

  @override
  String get notNeeded => 'Não é necessário';

  @override
  String get notNeededEnough => 'Não é necessário o suficiente';

  @override
  String get notNow => 'Agora não';

  @override
  String get notNow2 => 'Agora não';

  @override
  String get notSet => 'Não definido';

  @override
  String get notSetUp => 'Não configurado';

  @override
  String get notTheSameAsAdmin => 'Não é o mesmo que administrador';

  @override
  String get nothingFound => 'Nada encontrado';

  @override
  String get nothingHereYet => 'Nada aqui ainda.';

  @override
  String get nothingHereYet2 => 'Nada aqui ainda';

  @override
  String get nothingMatches => 'Nada corresponde';

  @override
  String get nothingStoredYet => 'Nada armazenado ainda.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Noção, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NVIDIA NIM';

  @override
  String get oauthClientId => 'ID do cliente OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'chave de API de redirecionamento secreto do ID do cliente oauth';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'ID do cliente oauth redirecionamento secreto unidade de calendário do Gmail';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'O lançamento do OAuth não é compatível com esta plataforma.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'segredo do ID do cliente do inquilino do Outlook oauth';

  @override
  String get oauthToken => 'Token OAuth';

  @override
  String get oauthWithPkce => 'OAuth com PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'de $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'próprio. Nunca mais é mostrado depois de salvar.';

  @override
  String get off => 'Desligado';

  @override
  String get officialIntegration => 'Integração oficial';

  @override
  String get officialIntegrationDidNotReturnA =>
      'A integração oficial não retornou uma URL de conexão.';

  @override
  String get on => 'Ligado';

  @override
  String get onASignedInAndroidDevice =>
      'Em um dispositivo Android conectado, abra Configurações › Login e segurança, leia este código e aprove o login.';

  @override
  String get onByDefaultForNewGroups => 'Ativado por padrão para novos grupos';

  @override
  String get onDemand => 'Sob demanda';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Ativado para grupos $arg1 de $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'ligado. Eles só poderão ingressar novamente com um novo link de convite.';

  @override
  String get onYourOwnTheDefault => 'Por conta própria (o padrão)';

  @override
  String get once => 'Uma vez';

  @override
  String get oneIsSavedOtherChangesIn =>
      'um é salvo. Outras alterações neste formulário também são salvas.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Uma ou mais contas expiraram. Reconecte a conta afetada para restaurar o acesso à ferramenta.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Um tempo de execução controla a personalidade, a alternância do grupo, a memória da sala, as normas, a Teoria da Mente e a entrega.';

  @override
  String get oneTimeRun => 'Corrida única';

  @override
  String get onlyApkOrApksFilesCan =>
      'Somente arquivos .apk ou .apks podem ser instalados.';

  @override
  String get onlyInThisGroup => 'Somente neste grupo';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Necessário apenas se o serviço solicitar cabeçalhos HTTP extras.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Necessário apenas se você quiser remodelar a carga útil de saída.';

  @override
  String get onlyTheyCanChangeIt => 'Só eles podem mudar isso.';

  @override
  String get open => 'Abrir';

  @override
  String get openAccountSettingsOnASigned =>
      'Abra Configurações › Login e segurança em um dispositivo Android conectado, leia este código e aprove o login.';

  @override
  String get openComputer => 'Abra o computador';

  @override
  String get openDashboard => 'Abrir painel';

  @override
  String get openFolder => 'Abrir pasta…';

  @override
  String get openInWorkbench => 'Abrir no ambiente de trabalho';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Abra o NeoAgent e reconecte o $arg1 para restaurar as mensagens.';
  }

  @override
  String get openTimeSettings => 'Configurações de horário de abertura';

  @override
  String get openToAnyone => 'Aberto a qualquer pessoa';

  @override
  String get openTrello => 'Abra o Trello';

  @override
  String get openVoiceAssistant => 'Abra o assistente de voz';

  @override
  String get openWiFiSettings => 'Abra as configurações de Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Abra com o aplicativo padrão';

  @override
  String get openaiCodex => 'Códice OpenAI';

  @override
  String get openaiCompatible => 'compatível com openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Endpoint compatível com OpenAI (seu próprio servidor ou outro ';

  @override
  String openedArg1(Object? arg1) {
    return '$arg1 aberto';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'A abertura de URLs de desktop não é compatível com esta plataforma.';

  @override
  String get openingYourSavedDesktop => 'Abrindo sua área de trabalho salva.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Abrindo sua área de trabalho salva. As partidas normais levam menos de 10 segundos.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Segredo extra opcional se você proteger o webhook de entrada.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Substituição opcional se o URL do webhook não for suficiente.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Segredo opcional para verificar eventos de bate-papo recebidos.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Segredo opcional para verificar eventos recebidos.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Segredo opcional para verificar eventos recebidos do iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Segredo opcional para verificar eventos LINE recebidos.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Segredo opcional para verificar eventos recebidos do Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Segredo opcional para verificar eventos de entrada do Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Opcional. O agente já tem personalidade própria. Qualquer coisa que você adicionar sobre o tom será colocada em camadas sobre ele, então você nunca precisará definir um.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Opcional. Quando definido, é usado em vez do URL.';

  @override
  String get orAnswerInYourOwnWords => 'Ou responda com suas próprias palavras';

  @override
  String get orBuildYourOwnTask => 'Ou crie sua própria tarefa';

  @override
  String get orContinueWith => 'ou continuar com';

  @override
  String get orFiles => 'ou arquivos.';

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
  String get originNotAllowed => 'origem não permitida';

  @override
  String get outgoingMessage => 'Mensagem de saída';

  @override
  String get outgoingWebhookUrl => 'URL de webhook de saída';

  @override
  String get outlookEmailReceived => 'E-mail do Outlook recebido';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Substitua as notas de comportamento da importação.';

  @override
  String get ownModel => 'modelo próprio';

  @override
  String get packageName => 'Nome do pacote';

  @override
  String get pairWithQrCode => 'Emparelhar com código QR';

  @override
  String get password => 'Senha';

  @override
  String get password2faAndActiveSessions => 'Senha, 2FA e sessões ativas';

  @override
  String get passwordCreated => 'Senha criada.';

  @override
  String get passwordIsTooWeak => 'a senha é muito fraca';

  @override
  String get passwordMin8 => 'senha mínimo 8';

  @override
  String get passwordOrApiKey => 'Senha ou chave API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Força da senha: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'As senhas não coincidem.';

  @override
  String get pasteAKey => 'Cole uma chave.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Cole uma nova chave para substituir $arg1';
  }

  @override
  String get pasteTheKey => 'Cole a chave';

  @override
  String get pasteYourAccountToken => 'Cole o token da sua conta';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Cole sua chave de API $arg1 abaixo. É ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'O caminho deve permanecer dentro do NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'O caminho deve ficar dentro da pasta do espaço de trabalho.';

  @override
  String get pauseLiveUpdates => 'Pausar atualizações ao vivo';

  @override
  String get pauseTaskLoop => 'Pausar ciclo de tarefa';

  @override
  String get paused => 'Pausado';

  @override
  String peakArg1(Object? arg1) {
    return 'pico $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Pessoas em bate-papos privados';

  @override
  String get perAccountRateLimits => 'Limites de taxa por conta';

  @override
  String get perCategoryPermissions => 'Permissões por categoria';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Políticas de permissão por ferramenta, portas de aprovação e isolamento de processos para execução de shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Permissão necessária: $arg1';
  }

  @override
  String get permissionsNeeded => 'Permissões necessárias';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Permissões. Ninguém mais pode mudar isso.';

  @override
  String get personOrChat => 'Pessoa ou chat';

  @override
  String get personaBehaviorNotes => 'Notas de comportamento da personalidade';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Token de acesso pessoal para o bot Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Canais pessoais e superfícies de apoio direto.';

  @override
  String get personalSelfChat => 'Bate-papo pessoal pessoal';

  @override
  String get phoneNumber => 'Número de telefone';

  @override
  String get pickARunFromTheList =>
      'Escolha uma execução na lista para ver suas etapas.';

  @override
  String get pickARunFromTheList2 =>
      'Escolha uma corrida na lista à esquerda para explorar seu fluxo.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Escolha um dos bate-papos $arg1 recentes ou adicione você mesmo uma pessoa ou grupo.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Escolha como $arg1 usa esta conta.';
  }

  @override
  String get pickOneToFillInThe =>
      'Escolha um para preencher a tarefa. Você pode ajustar tudo depois.';

  @override
  String get picksUpWhereYouLeftOff => 'Continua de onde você parou';

  @override
  String get plan => 'Plano';

  @override
  String get planning => 'Planejamento';

  @override
  String get platform => 'Plataforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Plataforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Por favor, escolha um horário.';

  @override
  String get pleaseEnterAFilename => 'Por favor insira um nome de arquivo.';

  @override
  String get pleaseEnterAKey => 'Por favor insira uma chave.';

  @override
  String get pleaseEnterAPrompt => 'Insira um prompt.';

  @override
  String get pleaseEnterATaskName => 'Insira um nome de tarefa.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Por favor insira o conteúdo da memória.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Insira quando a tarefa deve ser executada.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Selecione uma conta ou insira um ID de conexão válido.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Aponte o NeoAgent para qualquer conclusão de bate-papo compatível com OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Aponte a câmera para o código mostrado no dispositivo desconectado. A aprovação permanece neste telefone.';

  @override
  String get port => 'Porto';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'porta node_env URL público proxy confiável implantação de cookies seguros';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Automação premium com gatilhos de agendamento e integração.';

  @override
  String get prepareQrCode => 'Preparar código QR';

  @override
  String get preparingNeoagent => 'Preparando o NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Preparando o NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Pressione e segure para captura rápida';

  @override
  String get pressKeysIsNotSupportedOn =>
      'pressionar teclas não é compatível com esta plataforma.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Pressionado $arg1';
  }

  @override
  String get priceUnknown => 'Preço desconhecido';

  @override
  String get primaryDisplay => 'Tela principal';

  @override
  String get privateChat => 'Bate-papo privado';

  @override
  String get privateChats => 'Bate-papos privados';

  @override
  String get privateChats2 => 'bate-papos privados';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Bate-papos privados: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Bate-papos privados $arg1 · grupos $arg2';
  }

  @override
  String get privateChatsOnly => 'Somente bate-papos privados';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'endereços de rede privada não são permitidos.';

  @override
  String get profileEmailAndPersonalData => 'Perfil, e-mail e dados pessoais';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Avisar antes que o NeoAgent permaneça residente na bandeja do sistema.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Cache de prompt: tokens armazenados em cache $arg1 ';
  }

  @override
  String get promptCopied => 'Prompt copiado.';

  @override
  String get promptOrSchedule => 'solicitar ou agendar.';

  @override
  String get promptToPasteIntoAnotherAi => 'Solicitar colar em outra IA';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'A vinculação do provedor não pôde ser iniciada.';

  @override
  String get providerSignInCouldNotBe =>
      'Não foi possível iniciar o login do provedor.';

  @override
  String get providers => 'Provedores';

  @override
  String get providersEachAccountCanStillPick =>
      'Provedores; cada conta ainda pode escolher seu próprio modelo em Configurações. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Provedores, integrações, voz e recursos opcionais podem ser concluídos em Configurações a qualquer momento.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Tópicos de emissão pública e pull request, respondidos apenas por pessoas aprovadas.';

  @override
  String get publicUrl => 'URL público';

  @override
  String get publicUrlAndAllowedOrigins => 'URL público e origens permitidas';

  @override
  String get publicUrlOverride => 'Substituição de URL público';

  @override
  String get pullsTogetherTheDayAhead => 'Reúne o dia seguinte';

  @override
  String get pushToTalk => 'Aperte para falar';

  @override
  String get qrBasedPhoneLinking => 'Vinculação telefônica baseada em QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Login QR concluído, mas o NeoAgent não conseguiu manter a sessão. Por favor, tente novamente.';

  @override
  String get qrLoginCouldNotBeStarted => 'O login QR não pôde ser iniciado.';

  @override
  String get qrLoginRequestHasExpired => 'a solicitação de login qr expirou';

  @override
  String get qrLoginRequestWasNotFound =>
      'solicitação de login qr não foi encontrada';

  @override
  String get qrPairing => 'Emparelhamento QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'consultas são executadas; tudo o que escreve é ​​rejeitado.';

  @override
  String get queryFilter => 'Consulta/Filtro';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'Na fila como direção para a corrida atual: $arg1';
  }

  @override
  String get quickstart => 'Início rápido';

  @override
  String get quit => 'Sair';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'chuva_start, alerta_vento';

  @override
  String get ranAScriptInThePage => 'Executei um script na página';

  @override
  String ranArg1(Object? arg1) {
    return 'Executei $arg1';
  }

  @override
  String get rateLimits => 'Limites de taxa';

  @override
  String get readAnArtifact => 'Ler um artefato';

  @override
  String get readAndEditFilesInsideYour =>
      'Leia e edite arquivos dentro da pasta NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Leia $arg1';
  }

  @override
  String get readError => 'Erro de leitura';

  @override
  String get readFiles => 'Ler arquivos';

  @override
  String get readOnly => 'Somente leitura';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Leia a pasta e resuma a pilha, os pontos de entrada e como executá-la.';

  @override
  String get readThePage => 'Leia a página';

  @override
  String get readTheUiTree => 'Leia a árvore da IU';

  @override
  String get readWrite => 'Ler/Escrever';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Lê passos, frequência cardíaca, sono, exercício e peso.';

  @override
  String get ready => 'Pronto';

  @override
  String get readyForFirstTimeSetup => 'Pronto para configuração inicial';

  @override
  String get readyToConnect => 'Pronto para conectar';

  @override
  String get recentChannelActivity => 'Atividade recente do canal';

  @override
  String get recentChats => 'Bate-papos recentes';

  @override
  String get recentDecisions => 'Decisões recentes';

  @override
  String get recentFailedRuns => 'Execuções com falha recentes';

  @override
  String get recentGroupDecisions => 'Decisões recentes do grupo';

  @override
  String get recentRuns => 'Execuções recentes';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'As execuções recentes levam cerca de $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Saída recente do servidor, a mais recente primeiro.';

  @override
  String get recentUsage4Hours => 'Uso recente (4 horas)';

  @override
  String get recents => 'Recentes';

  @override
  String get recipientField => 'Campo destinatário';

  @override
  String get reconnectOrFinishSetup => 'Reconecte ou conclua a configuração';

  @override
  String get reconnectingThisDevice => 'Reconectando este dispositivo…';

  @override
  String get recurring => 'Recorrente';

  @override
  String get redirectUri => 'Redirecionar URI';

  @override
  String get redoOnboarding => 'Refazer integração';

  @override
  String get refresh => 'Atualizar';

  @override
  String get refreshCode => 'Atualizar código';

  @override
  String get refreshNow => 'Atualizar agora';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Atualize a tela do Android para tentar novamente.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Recuse-se a enviar, a menos que a conexão seja atualizada para TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'independentemente das configurações por categoria abaixo.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registre $arg1 para o fluxo de invocação do assistente.';
  }

  @override
  String get registrationIsClosed => 'inscrições estão encerradas';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registro registrar novas contas permitir inscrição';

  @override
  String get rejectInvalidTlsCertificates =>
      'Rejeitar certificados TLS inválidos';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'libera e reinicia. Os aplicativos conectados serão reconectados quando estiverem de volta.';

  @override
  String get releaseChannel => 'Canal de lançamento';

  @override
  String get releaseCommitBranchNode => 'liberar nó de ramificação de commit';

  @override
  String get releaseWhenYouAreDone => 'Solte quando terminar.';

  @override
  String get reloadNow => 'Recarregue agora';

  @override
  String get rememberThisChoice => 'Lembre-se desta escolha';

  @override
  String get remove => 'Remover';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return 'Remover \"$arg1\" e suas etapas registradas do histórico de execução?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Remova \"$arg1\" da memória principal.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return 'Remover chave $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'remover apagar usuário gdpr';

  @override
  String get removeSmtpPassword => 'Remover senha SMTP';

  @override
  String get removeTheSmtpPassword => 'Remover a senha SMTP?';

  @override
  String get rename => 'Renomear';

  @override
  String get renameSecurityKey => 'Renomear chave de segurança';

  @override
  String get renameSession => 'Renomear sessão';

  @override
  String get repairAndRetry => 'Reparar e tentar novamente';

  @override
  String get repairDesktop => 'Reparar área de trabalho';

  @override
  String get repeat => 'Repetir';

  @override
  String get repliesWhenTagged => 'Responde quando marcado';

  @override
  String get replyToAddress => 'Endereço para resposta';

  @override
  String replyToArg1(Object? arg1) {
    return 'Responder a $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'O repositório deve estar no formato proprietário/repo.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproduza o bug que descrevi, encontre a causa raiz e corrija-a com um teste de regressão.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'solicitação falhou com http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'Falha na solicitação com HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Solicitar permissões';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'A solicitação para $arg1 falhou antes que o back-end respondesse.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Solicitado $arg1';
  }

  @override
  String get requireStarttls => 'Exigir STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Obrigatório por trás de HTTPS ou proxy TLS. Aplica-se após um servidor ';

  @override
  String get requiredExampleBerlinDe => 'Obrigatório. Exemplo: Berlim, DE';

  @override
  String get requiredFormatOwnerRepo =>
      'Obrigatório. Formato: proprietário/repo';

  @override
  String get reserveAssistantHotkey =>
      'Tecla de atalho do assistente de reserva';

  @override
  String get reset => 'Redefinir';

  @override
  String get resetPassword => 'Redefinir senha';

  @override
  String get resetView => 'Redefinir visualização';

  @override
  String get responsibilities => 'Responsabilidades';

  @override
  String get restart => 'Reiniciar';

  @override
  String get restartToFinishTheUpdate =>
      ' Reinicie para finalizar a atualização.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Restaurando o tempo de execução anterior do NeoAgent';

  @override
  String get restrictDelegationTargets => 'Restringir metas de delegação';

  @override
  String get result => 'Resultado';

  @override
  String get resultDelivery => 'Entrega de resultados';

  @override
  String get resultOneClickAddsOneYou =>
      'resultado. Um clique adiciona um; você pode editá-lo mais tarde.';

  @override
  String get results => 'Resultados';

  @override
  String get retry => 'Tentar novamente';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Reutilizável · usado $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Revise as alterações não confirmadas';

  @override
  String get revoke => 'Revogar';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Revogar administrador com `neoagent admin revogar $arg1` primeiro';
  }

  @override
  String get revokeThisLink => 'Revogar este link?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Janela de lote de salas: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Gire para continuar';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'linhas. Adicione um LIMIT ou uma cláusula WHERE mais restrita para ver ';

  @override
  String get rule => 'Regra';

  @override
  String get run => 'Execução';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Execute comandos arbitrários em sua máquina ou VM.';

  @override
  String get runAt => 'Executar em';

  @override
  String get runCompleted => 'Execução concluída';

  @override
  String get runFailed => 'Falha na execução';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Execute git diff, revise as alterações não confirmadas em busca de bugs e problemas de estilo e resuma o que encontrar.';

  @override
  String get runNotFound => 'Execução não encontrada';

  @override
  String get runNow => 'Executar agora';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Execute mensagens pessoais recebidas do WhatsApp.';

  @override
  String get runQuery => 'Executar consulta';

  @override
  String get runShellCommandsOrInstallApps =>
      'Execute comandos shell ou instale aplicativos em seu dispositivo Android.';

  @override
  String get runStarted => 'Execução iniciada';

  @override
  String get runStatus => 'Status de execução';

  @override
  String get runStopped => 'Corrida parada';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Execute comandos de terminal e abra aplicativos ou páginas da web.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Execute este servidor: contas, atualizações, provedores, configuração ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Execute quando uma mensagem correspondente do Gmail chegar.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Execute quando um e-mail correspondente do Outlook chegar.';

  @override
  String get runWhenANewIssueMatching =>
      'Execute quando um novo problema correspondente aos seus filtros for aberto em um repositório.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Execute quando uma nova memória NeoRecall correspondente aos seus filtros for criada.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Execute quando uma notificação chegar no seu dispositivo.';

  @override
  String get runWhenASlackMessageMatches =>
      'Execute quando uma mensagem do Slack corresponder ao escopo selecionado.';

  @override
  String get runWhenATeamsChatMessage =>
      'Executar quando uma mensagem de chat do Teams corresponder ao escopo selecionado.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Executar quando eventos climáticos configurados forem previstos para um local.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'correr. Embora qualquer modelo esteja desativado, os modelos que os provedores adicionam ';

  @override
  String get running => 'Em execução';

  @override
  String runningArg1(Object? arg1) {
    return 'Executando $arg1';
  }

  @override
  String get runningTask => 'Tarefa em execução';

  @override
  String get runningTool => 'Ferramenta de corrida';

  @override
  String get runs => 'Execuções';

  @override
  String get runsEveryDayAtTheSelected =>
      'Funciona todos os dias no horário selecionado.';

  @override
  String get runsFourTimesPerHour => 'Funciona quatro vezes por hora.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— execuções, mensagens, memórias, integrações, arquivos e ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'execuções, mensagens, memórias, integrações, arquivos e sessões. ';

  @override
  String get runsMondayThroughFriday => 'Funciona de segunda a sexta.';

  @override
  String get runsOnSelectedWeekdays =>
      'Funciona em dias da semana selecionados.';

  @override
  String get runsOncePerHour => 'Funciona uma vez por hora.';

  @override
  String get runsOncePerMonthOnThe =>
      'É executado uma vez por mês no dia selecionado.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'É executado somente quando você pressiona Executar agora.';

  @override
  String get runsPerDay => 'Corridas por dia';

  @override
  String get runsPerDay30Days => 'Execuções por dia (30 dias)';

  @override
  String get runsThatCompleted => 'Execuções concluídas';

  @override
  String get runsThisWeek => 'Funciona esta semana';

  @override
  String get runsToday => 'Funciona hoje';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Execuções, ferramentas, memória, agendamento, habilidades e MCP estão disponíveis aqui.';

  @override
  String get runsTwicePerHour => 'Funciona duas vezes por hora.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'As execuções retornarão à chave do servidor compartilhado para $arg1, se houver uma configurada. Isso não pode ser desfeito.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Tempo de execução $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Tempo de execução: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Configurações de tempo de execução com as quais este servidor começou. Edite-os em ';

  @override
  String get runtimeSetupRequired =>
      'Configuração de tempo de execução necessária';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'A chave pública de assinatura em tempo de execução deve ter 32 bytes.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Salvar';

  @override
  String get saveATrelloApiKeyFor =>
      'Salve uma chave de API do Trello para este agente e conecte uma conta do Trello com segurança. O token da conta é armazenado no servidor e usado apenas para este agente.';

  @override
  String get saveAccount => 'Salvar conta';

  @override
  String get saveChanges => 'Salvar alterações';

  @override
  String get saveCloudComputerSettings =>
      'Salvar configurações do computador na nuvem';

  @override
  String get saveConnect => 'Salvar e conectar';

  @override
  String get saveDefaults => 'Salvar padrões';

  @override
  String get saveDiagnosticReport => 'Salvar relatório de diagnóstico';

  @override
  String get saveEmail => 'Salvar e-mail';

  @override
  String get saveEmailSettings => 'Salvar configurações de e-mail';

  @override
  String get saveGeneralSettings => 'Salvar configurações gerais';

  @override
  String get saveName => 'Salvar nome';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Salvar diagnósticos de configuração do NeoAgent';

  @override
  String get saveOnly => 'Salvar apenas';

  @override
  String get saveSetup => 'Salvar configuração';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Salve esses códigos de recuperação agora. Eles não serão mostrados novamente.';

  @override
  String get savedDeliveryDestination => 'Destino de entrega salvo';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Limites de taxa salvos para @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr => 'Digitalize um QR de login do NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Digitalize um QR de emparelhamento do NeoAgent de outro dispositivo e aprove-o nesta sessão do iniciador.';

  @override
  String get scanLoginQr => 'Digitalize o QR de login';

  @override
  String get scanPairingQr => 'Digitalizar QR de emparelhamento';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Digitalize solicitações de login QR de dispositivos desconectados e aprove-as nesta sessão móvel autenticada.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Digitalize para finalizar $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Digitalize com NeoAgent em seu telefone';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Verifica novos e-mails e só envia um ping quando algo é importante.';

  @override
  String get schedule => 'Cronograma';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'horário agendado. Depois que as corridas forem medidas, ela começará mais cedo.';

  @override
  String get screen => 'Tela';

  @override
  String get screenAction => 'ação na tela';

  @override
  String get scrollIsNotSupportedOnThis =>
      'scroll não é compatível com esta plataforma.';

  @override
  String get scrollToBottom => 'Role para baixo';

  @override
  String get search => 'Pesquisar';

  @override
  String get search2 => 'Pesquisar…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Pesquise configurações de administrador (por exemplo, SMTP, Ollama, logs)';

  @override
  String get searchAgain => 'Pesquise novamente';

  @override
  String get searchByUsernameOrEmail =>
      'Pesquise por nome de usuário ou e-mail';

  @override
  String get searchChannels => 'Pesquisar canais';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Pesquise canais de mensagens, contatos, grupos e conversas recentes descobertos.';

  @override
  String get searchGroups => 'Grupos de pesquisa';

  @override
  String get searchMemory => 'Memória de pesquisa';

  @override
  String get searchModelsOrProviders => 'Pesquisar modelos ou fornecedores';

  @override
  String get searchModelsOrProviders2 => 'Pesquise modelos ou fornecedores…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Pesquise pessoas e grupos recentes';

  @override
  String get searchSessions => 'Sessões de pesquisa';

  @override
  String get searchSettings => 'Configurações de pesquisa';

  @override
  String get searchTitleModelTriggerRunId =>
      'Título de pesquisa, modelo, gatilho, ID de execução';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Ferramentas de pesquisa, integrações e habilidades';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Código pesquisado para \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Arquivos pesquisados por \"$arg1\"';
  }

  @override
  String get secretField => 'Campo secreto';

  @override
  String get secureCookies => 'Cookies seguros';

  @override
  String get security => 'Segurança';

  @override
  String get securityKey => 'Chave de segurança';

  @override
  String get securityKeyPromptWasDismissed =>
      'A solicitação da chave de segurança foi ignorada.';

  @override
  String get securityKeySignInCompletedBut =>
      'O login da chave de segurança foi concluído, mas o NeoAgent não conseguiu manter a sessão do navegador. Faça login novamente.';

  @override
  String get securityKeySignInCouldNot =>
      'Não foi possível iniciar o login da chave de segurança.';

  @override
  String get securityKeys => 'Chaves de segurança';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'As chaves de segurança estão disponíveis apenas no aplicativo web NeoAgent.';

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Veja qual servidor NeoAgent esta janela usa e execute o backend neste computador.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'veja seu nome de usuário e essas configurações, nunca seus bate-papos, memórias ';

  @override
  String get selectARun => 'Selecione uma corrida';

  @override
  String get selectASessionToSeeIts =>
      'Selecione uma sessão para ver seu computador, arquivos e alterações.';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get selectAll2 => 'Selecionar tudo';

  @override
  String selectArg1(Object? arg1) {
    return 'Selecione $arg1';
  }

  @override
  String get selectTrigger => 'Selecione o gatilho';

  @override
  String get send => 'Enviar (⌘↵)';

  @override
  String get send2 => 'Enviar';

  @override
  String get sendATaskFromChatAnd =>
      'Envie uma tarefa pelo chat e seu histórico de execução aparecerá aqui.';

  @override
  String get sendItToATeammateWith =>
      'envie-o para um colega de equipe com uma conta neste servidor.';

  @override
  String get sendLink => 'Enviar link';

  @override
  String get sendPath => 'Enviar caminho';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Envie solicitações POST/PUT/DELETE para APIs externas.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Envie este link apenas para a pessoa a quem se destina. É mostrado uma vez; ';

  @override
  String get senderAddress => 'Endereço do remetente';

  @override
  String get senderFilterOptional => 'Filtro de remetente (opcional)';

  @override
  String get sentSharedAttachments => 'Enviou anexos compartilhados.';

  @override
  String get separateAccount => 'Conta separada';

  @override
  String get server => 'Servidor';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Padrão do servidor ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Padrões do servidor para chamadas de voz no aplicativo. As chamadas acontecem ao vivo ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'próprio servidor: contas, provedores e configuração.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Servidor, nick, canal e TLS opcional';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'cópia de erros de avisos do console de saída do servidor';

  @override
  String get serverProviderCredentials => 'Credenciais do provedor de servidor';

  @override
  String get serverUrl => 'URL do servidor';

  @override
  String get serverUsageLimitsDonTApply =>
      'Os limites de uso do servidor não se aplicam a modelos executados na sua própria chave.';

  @override
  String get serviceEmail => 'E-mail de serviço';

  @override
  String get serviceEmailIsNotConfigured =>
      'e-mail de serviço não está configurado';

  @override
  String get serviceEmailSmtp => 'E-mail de serviço (SMTP)';

  @override
  String get sessionActions => 'Ações de sessão';

  @override
  String get sessions => 'Sessões';

  @override
  String get sessions2 => 'SESSÕES';

  @override
  String get sessionsArePinnedToAFolder =>
      'As sessões são fixadas em uma pasta e em um computador. Comece a planejar, construir, testar e enviar a partir daqui.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sessões (RGPD Art. 17). As contas de administrador não podem ser excluídas ';

  @override
  String get sessionsLogoutRevokeForce => 'sessões logout revogar força';

  @override
  String get setBlockAskAllowPerTool =>
      'Defina bloquear/permitir/permitir por categoria de ferramenta ou escolha um modo global.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Configure o NeoAgent neste computador';

  @override
  String get setUpOrConnectNeoagent => 'Configure ou conecte o NeoAgent';

  @override
  String get setUrl => 'Definir URL';

  @override
  String get settings => 'Configurações';

  @override
  String get settingsAndCannotBeUndone =>
      'configurações e não pode ser desfeito.';

  @override
  String get settingsArea => 'Área de configurações';

  @override
  String get settingsAreas => 'Áreas de configurações';

  @override
  String get setup => 'Configuração';

  @override
  String get setupDetails => 'Detalhes de configuração';

  @override
  String get setupRequired => 'Configuração necessária';

  @override
  String get setupWasCancelled => 'A configuração foi cancelada.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Anexos compartilhados do cliente NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Compartilhado de outro aplicativo';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'As chaves de provedor compartilhadas são configuradas no servidor. Para usar sua própria chave de API ou um endpoint personalizado, vá para Avançado → Traga sua própria chave.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Compartilhado com o chat do NeoAgent e sua memória.';

  @override
  String get shellCommands => 'Comandos de shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Mostrar tudo $arg1';
  }

  @override
  String get showEarlier => 'Mostrar mais cedo';

  @override
  String get showEveryStep => 'Mostre cada passo';

  @override
  String get showTools => 'Mostrar ferramentas';

  @override
  String get showWorkbenchJ => 'Mostrar bancada (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Mostrando o primeiro $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Mostrado na barra lateral. Deixe em branco para usar seu nome de usuário.';

  @override
  String get signIn => 'Faça login';

  @override
  String get signInCompletedButNeoagentCould =>
      'O login foi concluído, mas o NeoAgent não conseguiu manter a sessão do navegador. Faça login novamente. Se isso continuar acontecendo, verifique as configurações de cookies da sessão de back-end.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'O login foi concluído, mas o NeoAgent não conseguiu manter a sessão do navegador. Faça login novamente. Se isso continuar acontecendo, o cookie da sessão de back-end provavelmente não será retido.';

  @override
  String get signInToThisNeoagentServer =>
      'Faça login neste servidor NeoAgent antes de escanear um código QR de emparelhamento.';

  @override
  String get signInWithAHardwareKey =>
      'Faça login com uma chave de hardware ou senha em vez de sua senha. ';

  @override
  String get signInWithASecurityKey => 'Faça login com uma chave de segurança';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Faça login com $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Aprove o NeoAgent em sua conta $arg1. Nenhuma chave para copiar.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Esperando por $arg1. Finalize no seu navegador.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Cole o código $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Depois que você aprovou o NeoAgent, $arg1 mostrou um código único. Cole aqui.';
  }

  @override
  String get signInCode => 'Código de login';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Conectado com $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Falha no login: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Faça login com o mesmo e-mail e senha mestra que você usa no Bitwarden. A senha mestra e o código de duas etapas são usados ​​apenas para login e nunca são armazenados ou enviados para a IA.';

  @override
  String get signOut => 'Sair';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return 'Sair de @$arg1 em todos os lugares?';
  }

  @override
  String get signOutEverywhere => 'Sair de todos os lugares';

  @override
  String get signalCliRestApiBridge => 'ponte API REST signal-cli';

  @override
  String get signalCliServerUrl => 'URL do servidor signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Assinou @$arg1 em todas as sessões.';
  }

  @override
  String get signedInDevices => 'Dispositivos conectados';

  @override
  String get signedInWithin24Hours => 'Login em até 24 horas';

  @override
  String get signingSecret => 'Segredo de assinatura';

  @override
  String sinceArg1(Object? arg1) {
    return 'Desde $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'desde $arg1';
  }

  @override
  String get singleMessage => 'Mensagem única';

  @override
  String get singleUse => 'Uso único';

  @override
  String get skill => 'Habilidade';

  @override
  String get skillChanges => 'Mudanças de habilidade';

  @override
  String get skillContent => 'Conteúdo de habilidade';

  @override
  String get skills => 'Habilidades';

  @override
  String get skip => 'Pular';

  @override
  String get skipForNow => 'Pular por enquanto';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Ignore esta tarefa antes de chamar o modelo.';

  @override
  String get slackMessageReceived => 'Mensagem do Slack recebida';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Sessões de suspensão $arg1';
  }

  @override
  String get smartSelector => 'seletor inteligente';

  @override
  String get smartSelector2 => 'Seletor Inteligente';

  @override
  String get smartSelectorPool => 'Conjunto de seletores inteligentes';

  @override
  String get smtpHost => 'Anfitrião SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'senha do remetente do e-mail smtp redefinição de notificações de confirmação tls';

  @override
  String get smtpPassword => 'Senha SMTP';

  @override
  String get smtpPort => 'Porta SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'A porta SMTP deve ser um número inteiro de 1 a 65535.';

  @override
  String get smtpUsername => 'Nome de usuário SMTP';

  @override
  String get soTheRunStartsThatMuch =>
      'então a corrida começa muito mais cedo.';

  @override
  String get socialBehaviorOff => 'Comportamento social desligado';

  @override
  String get socialIntelligence => 'inteligência social';

  @override
  String get socialIntelligence2 => 'Inteligência social';

  @override
  String get socialObservability => 'Observabilidade social';

  @override
  String get socialReach => 'alcance social';

  @override
  String get socialReach2 => 'Alcance social';

  @override
  String get socialReach3 => 'Alcance Social';

  @override
  String get socialReachUpdated => 'Alcance social atualizado.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Os agentes de fontes sociais podem ler diretamente, incluindo feeds, repositórios, Reddit, X, vídeos e dados de mercado baseados em cookies.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Algo deu errado. Por favor, tente novamente.';

  @override
  String get source => 'Fonte';

  @override
  String get spaceOrChatIdUsedWhen =>
      'ID do espaço ou chat usado quando este agente inicia uma conversa.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Suporte para webhook do espaço e retorno de chamada de aplicativo';

  @override
  String get speaking => 'Falando';

  @override
  String get speechToSpeechModelUsingThe =>
      'modelo de fala para fala usando a chave OpenAI ou Google em ';

  @override
  String get speechToText => 'Fala para texto';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'A conversão de fala em texto transcreve notas de voz e ditados. Auto usa OpenAI, Gemini ou Deepgram, o que tiver uma chave API. O modelo de resposta de voz é o modelo de chat que responde às notas de voz.';

  @override
  String get sqlConsole => 'Consola SQL';

  @override
  String get stable => 'Estável';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Stable instala a última versão de back-end publicada.';

  @override
  String get stackTrace => 'rastreamento de pilha';

  @override
  String get standard => 'Padrão';

  @override
  String get standardView => 'Visualização padrão';

  @override
  String get start => 'Começar';

  @override
  String get startASessionToPlanOr =>
      'Inicie uma sessão para planejar ou construir com o NeoAgent.';

  @override
  String get startAndroid => 'Inicie o Android';

  @override
  String get startComputer => 'Iniciar computador';

  @override
  String get startFullSetup => 'Iniciar a configuração completa';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Iniciar configuração';

  @override
  String get startTalking => 'Comece a falar';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Inicie o telefone Android primeiro e, em seguida, solte um arquivo .apk ou .apks aqui.';

  @override
  String get startTheServerLaterFromThe =>
      'Inicie o servidor mais tarde na lista, assim que a configuração for salva.';

  @override
  String get startWithARecommendedTask => 'Comece com uma tarefa recomendada';

  @override
  String get startingAndroid => 'Iniciando o Android';

  @override
  String get startingYourComputer => 'Iniciando seu computador';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Começa com xoxb-. Nas credenciais do seu aplicativo Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'Erro de startTelecomCallRouting: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'estatísticas executa tokens usuários gráficos taxa de sucesso';

  @override
  String get status => 'Estado';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'provedores de VM de tempo de execução de banco de dados de status';

  @override
  String get statusIsNotLoadedYet => 'O status ainda não foi carregado.';

  @override
  String get stayManagedByYou => 'permanecer gerenciado por você.';

  @override
  String get stayOnTheCall => 'Fique na chamada';

  @override
  String get stayedQuiet => 'Fiquei quieto';

  @override
  String get steering => 'DIREÇÃO';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'ETAPA $arg1 DE $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Etapas $arg1';
  }

  @override
  String get stop => 'Parar';

  @override
  String get stop2 => 'Pare (⌘.)';

  @override
  String get stopManaging => 'Pare de gerenciar';

  @override
  String stopManagingArg1(Object? arg1) {
    return 'Parar de gerenciar $arg1?';
  }

  @override
  String get stopRun => 'Pare de correr';

  @override
  String get stopSpeaking => 'Pare de falar';

  @override
  String get stoppedBeforeCompletion => 'Parado antes da conclusão';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'Erro stopTelecomCallRouting: $arg1';
  }

  @override
  String get storage => 'Armazenamento';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'armazenado criptografado e usado apenas para suas próprias execuções.';

  @override
  String get storedMetrics => 'Métricas Armazenadas';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Armazena apenas a chave de sessão Bitwarden criptografada neste servidor, para que as conexões sobrevivam às reinicializações. Você pode bloqueá-lo a qualquer momento.';

  @override
  String get strong => 'Forte';

  @override
  String get strongPassword => 'Senha forte.';

  @override
  String get subAgent => 'Subagente';

  @override
  String get subagentUpdate => 'Atualização do subagente';

  @override
  String get subagentUpdate2 => 'Atualização do subagente.';

  @override
  String get successRate => 'Taxa de sucesso';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Sugestões: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Resumir minha última corrida';

  @override
  String get supportUrl => 'URL de suporte';

  @override
  String get supportedRainStartSnowStartWind =>
      'Suportado: rain_start, snow_start, wind_alert, temperature_above, temperature_below';

  @override
  String get switchAgent => 'Trocar agente';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'Links simbólicos não são permitidos em caminhos do NeoAgent Workspace.';

  @override
  String get syncNow => 'Sincronize agora';

  @override
  String get synologyChat => 'Bate-papo Synology';

  @override
  String get systemPrivacySettings => 'Configurações de privacidade do sistema';

  @override
  String get tableInfoUsers => 'Informações da tabela (usuários)';

  @override
  String get tagsOnly => 'Somente tags';

  @override
  String get tasks => 'Tarefas';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'As tarefas são executadas por conta própria e enviam mensagens para você com o ';

  @override
  String get teach => 'Ensinar';

  @override
  String get teachingInProgress => 'Ensino em andamento';

  @override
  String get team => 'Equipe';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Os links de equipe nunca tornam ninguém um administrador de servidor. Os administradores executam o ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Espaços de equipe, salas, canais e comunidades ao vivo.';

  @override
  String get teamsMessageReceived => 'Mensagem das equipes recebida';

  @override
  String get templates => 'Modelos';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Os arquivos de configuração temporários serão limpos posteriormente.';

  @override
  String get tenantId => 'ID do locatário';

  @override
  String get testConnection => 'Conexão de teste';

  @override
  String get testConnection2 => 'Conexão de teste';

  @override
  String get textChat => 'Texto e bate-papo';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'que adicionaram sua própria chave continuam usando-a.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Esse e-mail já pertence a uma conta existente. Faça login primeiro e vincule o Google nas configurações da conta.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Esse e-mail já está vinculado a outra conta.';

  @override
  String get thatQrCodeIsNotA =>
      'Esse código QR não é uma solicitação de login do NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Esse código QR não é uma solicitação de emparelhamento do NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Essa chave de segurança já está registrada nesta conta.';

  @override
  String get theAddress => 'O endereço';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'O endereço do seu servidor BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'O endereço que as pessoas e os provedores de OAuth usam para entrar em contato ';

  @override
  String get theAgentReadsTimesYouMention =>
      'O agente lê os horários mencionados e executa tarefas agendadas neste fuso horário.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'O agente perguntará antes de cada ferramenta sensível, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'O agente irá ignorar esta habilidade.';

  @override
  String get theAppCouldNotReachThis =>
      'O aplicativo não conseguiu alcançar esta implantação do NeoAgent. Verifique sua conexão de rede ou confirme se o URL do serviço está correto.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'O navegador bloqueou uma solicitação para $arg1 devido à Política de Segurança de Conteúdo.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'O navegador bloqueou uma solicitação necessária devido à Política de Segurança de Conteúdo.';

  @override
  String get theCloudWorkspace => 'o espaço de trabalho na nuvem';

  @override
  String get theComputerCouldNotStart => 'O computador não pôde iniciar';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'O computador precisa de mais espaço livre em disco no host NeoAgent. Libere espaço e tente novamente.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'O tempo de execução do computador precisa de reparos. Execute o NeoAgent Doctor e tente novamente.';

  @override
  String get theConnectionTestFailed => 'O teste de conexão falhou.';

  @override
  String get theDesktopDidNotStart => 'A área de trabalho não iniciou';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'O NeoAgent descoberto retornou dados de identidade incompletos.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'O NeoAgent descoberto usa um protocolo de configuração não suportado.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'O serviço descoberto não é NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'O tempo de execução do NeoAgent baixado não passou na verificação.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'O webhook do espaço do Google Chat em que esse agente deve postar.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'O instalador não está mais disponível.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'O desktop Linux interativo está disponível no aplicativo web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'A introdução não está disponível neste dispositivo.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'As últimas são executadas em todas as contas.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'A última janela de sincronização terminou $arg1 e não encontrou nenhum novo registro do Health Connect. As métricas armazenadas abaixo vieram de sincronizações anteriores.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'A sessão gráfica do Linux não está em execução.';

  @override
  String get theLiveVoiceModelDidNot =>
      'O modelo de voz ao vivo não respondeu. Tente novamente.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'O comando NeoAgent local foi encerrado com o código $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'O comando local do NeoAgent expirou.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'O tempo de execução local do NeoAgent precisa de reparo.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'O tempo de execução local precisa de reparo ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'O diretório inicial do usuário local não está disponível.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'A conta de e-mail NeoAgent envia confirmações de inscrição, login ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'O agente principal é criado automaticamente quando necessário.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'O tempo de execução do NeoAgent correspondente está ausente nesta versão.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'O webhook de entrada do Mattermost no qual este agente deve postar.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Os modelos entre os quais o Seletor Inteligente é roteado automaticamente.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'O download do back-end do NeoAgent não corresponde ao seu manifesto.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'O download do back-end do NeoAgent estava incompleto.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'O back-end do NeoAgent neste computador não está respondendo na porta ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'Não foi possível fazer download do tempo de execução de back-end do NeoAgent.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'O back-end do NeoAgent demorou muito para responder ao $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'A implantação do NeoAgent respondeu com HTTP 402 em vez do 401 normal para credenciais inválidas. Verifique o proxy reverso, o gateway de autenticação ou as regras relacionadas a pagamentos nesse servidor.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'A implantação do NeoAgent respondeu com HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'A implantação do NeoAgent respondeu com HTTP 402. Verifique o proxy reverso, o gateway de autenticação ou as regras relacionadas a pagamento nesse servidor.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'A instância do NeoAgent à qual este aplicativo está conectado.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'O serviço de liberação do NeoAgent retornou dados inválidos.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Os metadados do artefato de tempo de execução do NeoAgent são inválidos.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'O manifesto de tempo de execução do NeoAgent não passou na verificação de assinatura.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'O manifesto de tempo de execução do NeoAgent não possui artefatos.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'A assinatura do manifesto do tempo de execução do NeoAgent é inválida.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'A senha que você definiu no BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'As pessoas que você gerencia ficam com você.';

  @override
  String get theProviderAnswers => 'o provedor responde.';

  @override
  String get theQueryReturnedNoRows => 'A consulta não retornou nenhuma linha.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'A exibição da área de trabalho solicitada não está disponível.';

  @override
  String get theRest => 'o resto.';

  @override
  String get theRestEndpointForYourSignal =>
      'O endpoint REST para sua instância signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'A execução é pausada até você responder.';

  @override
  String get theRunStartsAtTheScheduled =>
      'A corrida começa no horário agendado.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'O tempo de execução é um desktop Debian Linux leve com Chromium, PCManFM, Mousepad, LXTerminal, Python, Git e ferramentas de linha de comando padrão. Sua capacidade é gerenciada pelo host NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'O registro da chave de segurança não pôde ser iniciado.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'o servidor mantém apenas uma impressão digital dele.';

  @override
  String get theServerOnThisComputerIs =>
      'O servidor neste computador não está em execução';

  @override
  String get theServerReportedNoHealthChecks =>
      'O servidor não relatou nenhuma verificação de integridade.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'O número de telefone do Signal que este bot usa.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'O webhook de entrada do Teams no qual esse agente deve postar.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'O desafio de dois fatores expirou. Faça login novamente.';

  @override
  String get theTwoFactorCodeIsNot => 'O código de dois fatores não é válido.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'O pacote de tempo de execução verificado não pôde ser marcado como executável.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'O pacote de tempo de execução verificado não contém os arquivos necessários.';

  @override
  String get theWebAppCouldNotReach =>
      'O aplicativo da web não conseguiu acessar o back-end do NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'O aplicativo da web não conseguiu acessar o back-end do NeoAgent em $arg1. Verifique o console do navegador e a configuração do proxy reverso/rede.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'eles mesmos; o operador do servidor remove o administrador primeiro com ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Esses canais ficam em silêncio. Para ouvi-los novamente, adicione-os em Quem pode enviar mensagens para essa plataforma.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Essas listas são opcionais, a menos que uma seção acima esteja definida como somente aprovada.';

  @override
  String get thesePeopleAnywhere => 'Essas pessoas, em qualquer lugar';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Essas pessoas podem enviar mensagens para $arg1 em chats privados e em qualquer grupo que compartilhem.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Essas pessoas podem enviar mensagens para $arg1 individualmente. Isso não permite que falem em grupos.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Essas pessoas só podem enviar mensagens para $arg1 no grupo que você escolheu.';
  }

  @override
  String get thesePeopleInOneGroup => 'Essas pessoas, em um grupo';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'essas opções, nunca seus bate-papos, memórias ou arquivos.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Esta conta irá desbloquear o NeoAgent nesta máquina.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Este agente pode delegar a qualquer agente receptor elegível.';

  @override
  String get thisAgentIsUsingAServer =>
      'Este agente está usando uma chave de API do Trello gerenciada pelo servidor. Você só precisa autorizar um token de conta abaixo.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Esta compilação não tem permissão para se comunicar com esta implantação do NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Este código pertence a um servidor NeoAgent diferente: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Esta área de trabalho está conectada';

  @override
  String get thisDevice => 'Este dispositivo';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Este dispositivo: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Este dispositivo não pode registrar chaves de segurança. Abra o NeoAgent em um navegador via HTTPS para adicionar um.';

  @override
  String get thisDeviceUnavailable => 'Este dispositivo – indisponível';

  @override
  String get thisFileHasNoContent => 'Este arquivo não tem conteúdo.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Isso oculta \"$arg1\" do roteamento e da seleção.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Esta integração suporta atualmente uma conta conectada por agente. Reabra a configuração para substituí-lo.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Esta integração não está mais disponível.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Esta introdução foi projetada para reprodução de paisagem em tela cheia.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Esta é uma implantação gerenciada. Seu operador lança ';

  @override
  String get thisMayTakeAMoment => 'Isso pode demorar um pouco.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Este servidor MCP não está mais configurado.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Esta memória será removida permanentemente.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Esta compilação do NeoAgent não está configurada para verificar tempos de execução de back-end.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Isso apaga permanentemente todos os seus dados e não pode ser ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Isso apaga permanentemente a conta e tudo o que ela possui: ';

  @override
  String get thisPersonAnywhere => 'Essa pessoa, em qualquer lugar';

  @override
  String get thisPersonInOneGroup => 'Esta pessoa, em um grupo';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Esta solicitação de login QR expirou. Gere um novo código e tente novamente.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'esta solicitação de login qr expirou';

  @override
  String get thisQrLoginRequestIsStill =>
      'Esta solicitação de login QR ainda está aguardando aprovação.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Esta solicitação de login QR já foi usada.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Isso remove a configuração do Home Assistant e a instância conectada para este agente.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Isso remove o URL de back-end do NeoRecall e todas as contas do NeoRecall conectadas para este agente.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Isso remove o URL Nextcloud e todas as contas Nextcloud conectadas para este agente.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Isso remove a configuração do Trello e as contas conectadas para este agente.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Isto requer uma sessão autenticada no mesmo servidor NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Esta execução não produziu uma resposta voltada ao usuário.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Esta execução não possui dados de etapas registrados.';

  @override
  String get thisServer => 'este servidor.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Este servidor não relata configurações de provedor.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Esta habilidade não está mais instalada.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Esta tarefa ainda não foi concluída, então ela ainda começa no ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Esta tarefa só será executada quando você pressionar Executar agora.';

  @override
  String get thisWeek => 'Esta semana';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Isso importará a resposta para $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Isso removerá \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Isso removerá \"$arg1\" da lista de servidores.';
  }

  @override
  String get time => 'Hora';

  @override
  String get timeZone => 'fuso horário';

  @override
  String get timeZone2 => 'Fuso horário';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Tempo esgotado$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] Não foi possível listar os fusos horários: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] Não foi possível ler o fuso horário do dispositivo: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] Não foi possível salvar o fuso horário do dispositivo: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'para $arg1';
  }

  @override
  String get toUseTheServerDefault => 'para usar o padrão do servidor.';

  @override
  String get today => 'Hoje';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Orçamento de token para @$arg1. Deixe um campo vazio ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Orçamento de token para cada conta sem substituição própria. Deixe um ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'limite de orçamento de token usuário de cota semanal de 4 horas';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'limite de orçamento de token cota semanal global de 4 horas';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'Uso de token indisponível nesta versão do servidor.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokens que qualquer conta pode usar em 4 horas.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens que qualquer conta pode usar em 7 dias.';

  @override
  String get tokensPerDay => 'Tokens por dia';

  @override
  String get tokensPerRun => 'Tokens por execução';

  @override
  String get tokensToday => 'Tokens hoje';

  @override
  String get tokensUsed => ' tokens usados';

  @override
  String get tomorrowPrep => 'Preparação para amanhã';

  @override
  String get tooManyAttempts => 'muitas tentativas';

  @override
  String get tooManySignInAttemptsPlease =>
      'Muitas tentativas de login. Aguarde e tente novamente.';

  @override
  String get tool => 'Ferramenta';

  @override
  String get toolApproval => 'Aprovação de ferramenta';

  @override
  String get toolApprovalRequired => 'Aprovação da ferramenta necessária';

  @override
  String get toolCompleted => 'Ferramenta concluída';

  @override
  String get toolFailed => 'Falha na ferramenta';

  @override
  String get toolPermissions => 'Permissões de ferramentas';

  @override
  String get toolStarted => 'Ferramenta iniciada';

  @override
  String get tools => 'Ferramentas';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Ferramentas não integradas ao NeoAgent, incluindo servidores MCP conectados e provedores de ferramentas personalizadas.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Ferramentas oferecidas ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Ferramentas que a conta gerenciada pode usar';

  @override
  String get topUsers => 'Principais usuários';

  @override
  String get topUsersAndRecentRuns =>
      'Principais usuários e execuções recentes';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Total: tokens $arg1 em execuções $arg2';
  }

  @override
  String get totalRuns => 'Total de corridas';

  @override
  String get totalTokens => 'Totais de fichas';

  @override
  String get totalUsers => 'Total de usuários';

  @override
  String get transcript => 'Transcrição';

  @override
  String get transcript2 => 'TRANSCRIÇÃO';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Falha na transcrição: $arg1';
  }

  @override
  String get transfer => 'Transferência';

  @override
  String get trelloApiKey => 'Chave de API do Trello';

  @override
  String get trelloApiKeyIsRequired =>
      'A chave de API do Trello é obrigatória.';

  @override
  String get trelloSetup => 'Configuração do Trello';

  @override
  String get triggerType => 'Tipo de gatilho';

  @override
  String get tryABroaderSearchLikeModels =>
      'Experimente uma pesquisa mais ampla, como modelos, navegador ou voz.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Experimente um nome de provedor, “e-mail”, “limites”, “atualização” ou “logs”.';

  @override
  String get tryAgain => 'Tente novamente';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Tente novamente. Se isso continuar acontecendo, execute o NeoAgent Doctor para verificar o tempo de execução do computador.';

  @override
  String get tryAgainInAMoment => 'Tente novamente em alguns instantes.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Tente novamente ou execute o NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Tente outra pesquisa, conecte uma plataforma de mensagens ou insira um ID de destino manualmente.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Ative um grupo se $arg1 também ler mensagens que não o marcam.';
  }

  @override
  String get turnOffComputer => 'Desligue o computador';

  @override
  String get turnOffOnlyForAMail =>
      'Desative apenas para servidores de e-mail com certificado autoassinado.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Ative se o Signal continuar procurando por bate-papos recebidos.';

  @override
  String get turnTaking => 'turno tomando';

  @override
  String get turnTakingModel => 'Modelo de turno';

  @override
  String get turnTakingOff => 'Decolagem';

  @override
  String get turnThisOffToKeepThis =>
      'Desative esta opção para manter este agente totalmente separado de outros agentes.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Desativado por $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Desativado por $arg1, que gerencia esta conta. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Desativado para você por $arg1 – somente eles podem alterá-lo';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Desligado para você, então você não pode distribuí-lo';

  @override
  String get twitchChatOverIrc => 'Bate-papo Twitch via IRC';

  @override
  String get twoFactorAuthentication => 'Autenticação de dois fatores';

  @override
  String get twoFactorChallengeExpired => 'desafio de dois fatores expirou';

  @override
  String get twoFactorCode => 'código de dois fatores';

  @override
  String get twoFactorSignInCompletedBut =>
      'O login de dois fatores foi concluído, mas o NeoAgent não conseguiu manter a sessão do navegador. Faça login novamente.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Login em duas etapas (somente se habilitado)';

  @override
  String get type => 'Tipo';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Digite $arg1 para confirmar';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'o tipo de texto não é compatível com esta plataforma.';

  @override
  String get typedInTheBrowser => 'Digitado no navegador';

  @override
  String get typedText => 'Texto digitado';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'não foi possível localizar um tempo de execução java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'Não foi possível abrir as configurações de horário nesta compilação.';

  @override
  String get unableToOpenWiFiSettings =>
      'Não foi possível abrir as configurações de Wi-Fi nesta versão.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'Não é possível persistir a exibição da área de trabalho selecionada.';

  @override
  String get unclearWhoItWasFor => 'Não está claro para quem foi';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'desfeito. Digite seu nome de usuário para confirmar.';

  @override
  String get unknownAccount => 'Conta desconhecida';

  @override
  String get unknownAgent => 'Agente desconhecido';

  @override
  String get unknownBrowser => 'Navegador desconhecido';

  @override
  String get unknownDevice => 'Dispositivo desconhecido';

  @override
  String get unknownError => 'erro desconhecido';

  @override
  String get unknownLocalComputerPermission =>
      'Permissão de computador local desconhecida.';

  @override
  String get unknownLocation => 'Local desconhecido';

  @override
  String get unknownPublishTime => 'Horário de publicação desconhecido';

  @override
  String get unknownSize => 'Tamanho desconhecido';

  @override
  String get unlink => 'Desvincular';

  @override
  String get unreadOnly => 'Somente não lido';

  @override
  String get unsavedChanges => 'Alterações não salvas';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Comando complementar de desktop não suportado: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Método não suportado: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Alertas de login incomuns';

  @override
  String updateArg1(Object? arg1) {
    return 'Atualizar $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Atualize as entradas da memória principal da importação.';

  @override
  String get updateNow => 'Atualizar agora';

  @override
  String get updateReady => 'Atualização pronta';

  @override
  String get updateSetup => 'Atualizar configuração';

  @override
  String get updateTheAccessListToAllow =>
      'Atualize a lista de acesso para permitir respostas.';

  @override
  String get updateTheServer => 'Atualizar o servidor?';

  @override
  String get updateTheServer2 => 'Atualizar o servidor';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Atualize o fuso horário automaticamente no dispositivo que você está usando.';

  @override
  String updatedArg1(Object? arg1) {
    return '$arg1 atualizado';
  }

  @override
  String get updates => 'Atualizações';

  @override
  String get updatesAreNotConfiguredForThis =>
      'As atualizações não estão configuradas para esta compilação.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'atualizações, então a autoatualização e as mudanças de canal estão desativadas aqui.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'atualizar atualização agora lançar canal beta estável';

  @override
  String get usageAnalytics => 'Análise de uso';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Sinais de uso e integridade que ajudam a explicar o comportamento atual do tempo de execução sem primeiro examinar os logs.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'O uso é totalmente redefinido em $arg1';
  }

  @override
  String get usageLeaderboard => 'placar de uso';

  @override
  String get usageLimits => 'Uso e Limites';

  @override
  String get usageLimits2 => 'Uso e limites';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Use mais de 8 caracteres. Senhas mais longas funcionam bem.';

  @override
  String get useADateAndTimeFor =>
      'Use uma data e hora, por exemplo 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Use um nome, número de telefone ou ID de bate-papo.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Use uma URL NeoRecall que o servidor NeoAgent possa acessar. O PUBLIC_URL do NeoAgent também deve ser acessível a partir deste navegador para o retorno de chamada OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Use uma nova senha com pelo menos 8 caracteres.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Use uma URL Nextcloud que o servidor NeoAgent possa acessar, por exemplo https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Use uma senha com pelo menos 8 caracteres.';

  @override
  String get useASecureConnectionTls => 'Use uma conexão segura (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Use um aplicativo autenticador como Authy, 1Password ou Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Use pelo menos 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Memória máxima por computador (MB)';

  @override
  String get maxVcpusPerComputer => 'Máximo de vCPUs por computador';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Pelo menos $arg1. Os computadores ficam menos quando o host está ocupado.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'A memória máxima deve ser de pelo menos $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Use pelo menos 8 caracteres.';

  @override
  String get useDefault => 'Usar padrão';

  @override
  String get useDefaultChannel => 'Usar canal padrão';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Usar padrão (espaço de trabalho do NeoAgent)';

  @override
  String get useFor => 'Usar para';

  @override
  String get useManualDestination => 'Usar destino manual';

  @override
  String get useOrDoTheSameFor =>
      'use ou faça o mesmo com seus companheiros de equipe.';

  @override
  String get usePerCategorySettingsBelow =>
      'Use as configurações por categoria abaixo.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Usar configurações padrão ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer => 'Use o servidor neste computador';

  @override
  String get useTheseForContextIfA =>
      'Use-os para contextualizar. Se um URI local não estiver acessível diretamente no servidor, peça para fornecer o arquivo por meio de um espaço de trabalho acessível.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Use isso para agentes orquestradores. Deixe para os bots de trabalho isolados que devem finalizar as mensagens diretas sozinhos.';

  @override
  String get useTlsFromTheStartOf =>
      'Use TLS desde o início da conexão, geralmente na porta 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Use sua própria chave de API para um provedor ou conecte uma chave personalizada ';

  @override
  String get usedByEveryAccountOnThis =>
      'Usado por todas as contas neste servidor que não possuem chave ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Usado para verificar se os eventos recebidos do Slack são genuínos.';

  @override
  String get userSummary => 'Resumo do usuário';

  @override
  String get username => 'Nome de usuário';

  @override
  String get usernameOrEmail => 'Nome de usuário ou e-mail';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'usuários pessoas pesquisam email nome de usuário administrador crachá equipe gerenciada';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Usa o modelo de chat configurado em Configurações';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Usando o tempo de execução do NeoAgent instalado';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Geralmente se parece com @bot:matrix.org';

  @override
  String get validEmail => 'e-mail válido';

  @override
  String get value => 'Valor';

  @override
  String get vaultLocked => 'Cofre bloqueado';

  @override
  String get vaultOperationFailed => 'A operação do cofre falhou.';

  @override
  String get verification => 'Verificação';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verificação: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verificação: $arg1';
  }

  @override
  String get verificationCompleted => 'Verificação concluída.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Status de verificação: $arg1';
  }

  @override
  String get verifiedTheResult => 'Verificado o resultado';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Verificando o tempo de execução baixado';

  @override
  String get versionAndUptime => 'Versão e tempo de atividade';

  @override
  String versionArg1(Object? arg1) {
    return 'Versão $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'A versão $arg1 está instalada, mas $arg2 ainda está em execução.';
  }

  @override
  String get videoLinks => 'Links de vídeo';

  @override
  String get viewDesktop => 'Ver área de trabalho';

  @override
  String get viewLastRun => 'Ver última execução';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'memória de imagem vm cpu qemu tempo de execução';

  @override
  String get voice => 'Voz';

  @override
  String get voiceAssistant => 'Assistente de voz';

  @override
  String get voiceCall => 'CHAMADA DE VOZ';

  @override
  String get voiceCall2 => 'Chamada de voz';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'chamada de voz gpt-live gemini modelo ao vivo discurso em tempo real';

  @override
  String get voiceCallsRunOnALive =>
      'As chamadas de voz são executadas em um modelo de fala para fala ao vivo com a mesma personalidade, memória e histórico de bate-papo do NeoAgent. Ele responde imediatamente e entrega o trabalho real ao agente normal, que continua funcionando em segundo plano.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'chave de API de transcrição de fala de nota de voz';

  @override
  String get voiceNotesAndDictation => 'Notas de voz e ditado';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'A reprodução de voz não está disponível neste dispositivo.';

  @override
  String get voiceReplyModel => 'Modelo de resposta por voz';

  @override
  String get waitingForApproval => 'Aguardando aprovação: ';

  @override
  String get waitingForCode => 'Aguardando código';

  @override
  String get waitingForInput => 'Aguardando entrada';

  @override
  String get waitingForServerOrFlutterLog =>
      'Aguardando a saída do servidor ou do log do Flutter…';

  @override
  String get waitingForTaskEvents => 'Aguardando eventos de tarefa...';

  @override
  String get waitingForYou => 'esperando por você';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Queria uma resposta de $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Quer falar com você · ${arg1}s';
  }

  @override
  String get weak => 'Fraco';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Clima, calendário e prioridades antes do início do dia.';

  @override
  String get weatherEvent => 'Evento meteorológico';

  @override
  String get web => 'Rede';

  @override
  String get webBrowser => 'Navegador da Web';

  @override
  String get webSearchApiKey => 'chave de API de pesquisa na web';

  @override
  String get webhookOrRestChannelPosting => 'Postagem de webhook ou canal REST';

  @override
  String get webhookSecret => 'Segredo do webhook';

  @override
  String get webhookUrlCopied => 'URL do webhook copiado';

  @override
  String get weekdays => 'Dias da semana';

  @override
  String get weekdays0730 => 'Dias úteis · 07:30';

  @override
  String get weekdays1800 => 'Dias úteis · 18h';

  @override
  String get weekly => 'Semanalmente';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Limite semanal $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Limite semanal (tokens)';

  @override
  String get weeklyReview => 'Revisão semanal';

  @override
  String get weeklyUsage => 'Uso semanal';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Registros de peso $arg1';
  }

  @override
  String get welcomeToNeoagent => 'BEM VINDO AO NEOAGENTE';

  @override
  String get welcomeToNeoagent2 => 'Bem-vindo\nao NeoAgent';

  @override
  String get whatAreYouAdding => 'O que você está adicionando?';

  @override
  String get whatIsOnTomorrow => 'O que vai acontecer amanhã?';

  @override
  String get whatShouldNeoagentLearn => 'O que o NeoAgent deve aprender?';

  @override
  String get whatShouldWeBuild => 'O que devemos construir?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'O que você e o NeoAgent dizem aparece aqui e no chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Mensagem pessoal do WhatsApp recebida';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Ao escolher somente aprovados, adicione pessoas ou grupos abaixo.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Para onde este agente deve enviar respostas.';

  @override
  String get whoCanMessage => 'Quem pode enviar mensagem';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return 'Quem pode enviar mensagens no $arg1';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return 'Quem pode enviar uma mensagem individual para $arg1.';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Quem pode falar com $arg1 em grupo, canal ou sala.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'quem gerencia esta conta desativou: ';

  @override
  String get whoManagesWhom => 'Quem gerencia quem';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Quem aceita um link entra para sua equipe apenas com as ferramentas que ele possui ';

  @override
  String get wholeGroup => 'Grupo inteiro';

  @override
  String get wholeGroups => 'Grupos inteiros';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Por que $arg1 respondeu ou ficou quieto nos grupos $arg2.';
  }

  @override
  String get windowsApp => 'Aplicativo do Windows';

  @override
  String get windowsNt => 'janelas';

  @override
  String get workAccount => 'Conta de trabalho';

  @override
  String get workOnAProjectWithNeoagent =>
      'Trabalhe em um projeto com NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Fluxo de trabalho: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Trabalhando em $arg1 no computador em nuvem. O NeoAgent lê e edita arquivos lá e pode executar comandos e um navegador.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Trabalhando em segundo plano: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Configuração do espaço de trabalho e segurança da conta em um só lugar.';

  @override
  String get workspaceFiles => 'Arquivos do espaço de trabalho';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Espaço de trabalho, modelos e controles de diagnóstico.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'A substituição do espaço de trabalho deve ser um caminho absoluto.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Escreveu $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'erro xmlhttprequest';

  @override
  String get yesterday => 'Ontem';

  @override
  String get youAreInControl => 'Você está no controle';

  @override
  String get youCanFollowAlongOnThe =>
      'Você pode acompanhar na área de trabalho.';

  @override
  String get youCanLeaveATeamAt =>
      'Você pode sair de uma equipe a qualquer momento; suas próprias configurações serão aplicadas novamente.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Você pode sair a qualquer momento na página da equipe.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Você decide quais ferramentas seu agente pode usar em Configurações › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Você ainda não gerencia ninguém. Crie um link de convite abaixo e ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Você tem configurações não salvas. O que você gostaria de fazer?';

  @override
  String get youReOnYourOwnYou =>
      'Você está por conta própria: você decide quais ferramentas seu agente pode usar. Se ';

  @override
  String get yourAccountAndUsageOnA =>
      'sua conta – e uso em um modelo apoiado por sua própria chave ';

  @override
  String get yourAccountHasBeenDeleted => 'Sua conta foi excluída.';

  @override
  String get yourAgentWillBeAllowed => 'Seu agente terá permissão:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Seus aplicativos e arquivos são salvos.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Seus aplicativos e arquivos permanecem salvos.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Sua chave $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Sua camada assistente para captura, contexto e ação.';

  @override
  String get yourComputerIsAsleep => 'Seu computador está dormindo';

  @override
  String get yourComputerIsOff => 'Seu computador está desligado';

  @override
  String get yourComputerIsReady => 'Seu computador está pronto';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Sua senha atual está incorreta.';

  @override
  String get yourData => 'Seus dados';

  @override
  String get yourDataExportWasCopiedTo =>
      'Sua exportação de dados foi copiada para a área de transferência.';

  @override
  String get yourDesktopIsReady => 'Sua área de trabalho está pronta';

  @override
  String get yourLinuxComputer => 'Seu computador Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Sua localização nunca é rastreada continuamente ou armazenada em nossos servidores. Nós o usamos apenas localmente para verificar suas tarefas ativas.';

  @override
  String get yourManager => 'seu gerente';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'O URL do seu site Mattermost, se você usar a API REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Sua sessão expirou ou não foi retida pelo navegador. Faça login novamente.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Sua sessão expirou. Faça login novamente.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Seu nome de usuário ou senha está incorreto.';

  @override
  String get yubikeyMacbookTouchId => 'Yubikey, MacBook Touch ID,…';

  @override
  String get yubikeyOtp => 'YubiKey OTP';

  @override
  String get zaloPersonal => 'Zalo Pessoal';

  @override
  String get sectionOverview => 'Visão geral';

  @override
  String get sectionDiagnostics => 'Diagnóstico';

  @override
  String get sectionVolume => 'Volume';

  @override
  String get sectionSession => 'Sessão';

  @override
  String get sectionDeliverable => 'Entregável';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'O tempo de execução local ainda não gravou um arquivo de log.';

  @override
  String get thisComputer => 'Este computador';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta instala o mais novo back-end de pré-lançamento. Espere arestas ásperas.';

  @override
  String get copiedFinalResponse => 'Resposta final copiada';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'A resposta final aparece aqui quando a execução termina.';

  @override
  String get waitingForTheFirstStep => 'Aguardando o primeiro passo…';

  @override
  String get loadingPrompt => 'Carregando solicitação…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'Nenhuma resposta final foi capturada para esta execução.';

  @override
  String get readyToSignIn => 'Pronto para fazer login';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Mude para \"Padrão\" ou \"Sempre perguntar\" para reativar as verificações de aprovação.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Envie uma atualização de direção ou nota seguinte para a execução atual...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Sem conexão de rede. O NeoAgent se reconectará quando o dispositivo estiver online novamente.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Aplicou a atualização de direção mais recente à corrida atual.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Preparando a sessão de voz privada…';

  @override
  String get preparingYourComputer => 'Preparando seu computador';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent está baixando e preparando o sistema Linux seguro. Isso só acontece na primeira vez.';

  @override
  String get moreFreeSpaceIsNeeded => 'É necessário mais espaço livre';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Libere espaço em disco no host do NeoAgent e tente novamente. Os dados existentes do seu computador estão seguros.';

  @override
  String get androidReady => 'Pronto para Android';

  @override
  String get startingAndroid2 => 'Iniciando o Android…';

  @override
  String get androidStopped => 'Android parou';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'A primeira inicialização baixa o SDK do Android e a imagem do sistema, o que pode levar vários minutos.';

  @override
  String get androidIsStopped => 'Android está parado';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Inicie o ambiente Android gerenciado quando precisar.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Deixe o NeoAgent trabalhar neste computador';

  @override
  String get firstTimeSetupIsInProgress =>
      'A configuração inicial está em andamento.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent pode usar o acesso que você permitir.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Libere algum armazenamento do host e tente novamente.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Comece quando quiser que o NeoAgent ajude aqui.';

  @override
  String get systemPermissionMissing => 'Permissão do sistema ausente';

  @override
  String get connectingThisDevice => 'Conectando este dispositivo';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'A conexão local segura está sendo estabelecida.';

  @override
  String get recordingYourDemonstration => 'Gravando sua demonstração';

  @override
  String get noErrorsInTheRecentLog => 'Nenhum erro no log recente.';

  @override
  String get loadingAccounts => 'Carregando contas…';

  @override
  String get neverSignedIn => 'Nunca fiz login';

  @override
  String get emptyUsesTheServerDefault => 'Vazio usa o padrão do servidor.';

  @override
  String get followTheSelectedSession => 'Acompanhe a sessão selecionada';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'O modo de planejamento inspeciona apenas. Mude para o modo Agente para permitir que o NeoAgent edite arquivos.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Necessário para adicionar ou alterar o e-mail da sua conta.';

  @override
  String get confirmNewPassword => 'Confirme a nova senha';

  @override
  String get passwordChanged => 'Senha alterada.';

  @override
  String get thisRequestHasAlreadyBeenUsed => 'Esta solicitação já foi usada.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Esta solicitação expirou. Peça ao outro dispositivo para gerar um novo código.';

  @override
  String get startQuickstart => 'Iniciar o início rápido';

  @override
  String get createYourAccount => 'Crie sua conta';

  @override
  String get showWorkAsSummaries => 'Mostrar trabalhos como resumos';

  @override
  String get tokensUsedByTheLatestRun => 'Tokens usados pela última execução';

  @override
  String get listedTheWorkspaceRoot => 'Listou a raiz do espaço de trabalho';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Nenhuma integração oficial está disponível ainda.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Nenhum servidor MCP configurado ainda. Adicione um para expor suas ferramentas.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Adicione um servidor MCP ou instale uma habilidade para começar.';

  @override
  String get setUp => 'Configurar';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Deixe em branco para manter o valor armazenado';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Isso remove o endereço de todas as contas neste servidor.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Apenas fale. Você pode interromper a qualquer momento. Toque para silenciar.';

  @override
  String get tapAgainWhenYouAreDone => 'Toque novamente quando terminar.';

  @override
  String get workingOnATaskInTheBackground =>
      'Trabalhando em uma tarefa em segundo plano.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Fala para fala com a mesma memória, ferramentas e histórico de chat do NeoAgent.';

  @override
  String get checkLink => 'Verifique o link';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'Seu agente não terá permissão para nenhuma das ferramentas controladas.';

  @override
  String get notYoursToChange => 'Não é seu para mudar';

  @override
  String get setByYou => 'Definido por você';

  @override
  String get noTools => 'Sem ferramentas';

  @override
  String get untitledLink => 'Link sem título';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Para de funcionar depois que uma pessoa o resgata.';

  @override
  String get theOperator => 'O operador';

  @override
  String get smartSelectorOn => 'Seletor inteligente ativado';

  @override
  String get startASessionToBegin => 'Iniciar uma sessão para começar';

  @override
  String get steerTheActiveRun => 'Dirija a corrida ativa…';

  @override
  String get describeWhatToPlan => 'Descreva o que planejar…';

  @override
  String get stopDictation => 'Pare o ditado';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'As mensagens orientam a execução atual · ⌘↵ enviar · ⌘. pare';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'O modo de planejamento apenas inspeciona; nada muda até que você implemente · ⌘↵ enviar';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'O agente edita o espaço de trabalho. Planeje apenas inspecionar.';

  @override
  String get defaultModel => 'Modelo padrão';

  @override
  String get openingScanner => 'Abrindo scanner...';

  @override
  String get theAgentCanUseThisSkill => 'O agente pode usar essa habilidade.';

  @override
  String get allSelected => 'Todos selecionados';

  @override
  String get addCoreMemoryEntry => 'Adicionar entrada de memória principal';

  @override
  String get channelId => 'ID do canal';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'As tarefas criadas e não especificadas pela IA usam o padrão atual.';

  @override
  String get waitingForRunEvents => 'Aguardando eventos de execução...';

  @override
  String get hideSteps => 'Ocultar etapas';

  @override
  String get commitTheActiveLiveCapture => 'Confirme a captura ao vivo ativa';

  @override
  String get stopCaptureAndSubmit => 'Pare a captura e envie';

  @override
  String get clickTheMicToStartSpeaking =>
      'Clique no microfone para começar a falar';

  @override
  String get connectACustomEndpoint => 'Conecte um endpoint personalizado';

  @override
  String get hostedProvider => 'provedor hospedado.';

  @override
  String get muted => ' • silenciado';

  @override
  String get addWhoCanMessage => 'Adicione quem pode enviar mensagens';

  @override
  String get joinsGroupConversations => 'Participa de conversas em grupo';

  @override
  String get label1PersonOrGroupAdded => '1 pessoa ou grupo adicionado';

  @override
  String get inProgress => 'Em andamento';

  @override
  String get waitingForUpdateJobOutput =>
      'Aguardando saída do job de atualização…';

  @override
  String get taskTrigger => 'Gatilho de tarefa';

  @override
  String get bearerToken => 'Token do portador';

  @override
  String get bearerToken2 => 'Token do Portador';

  @override
  String get notRecorded => 'Não gravado';

  @override
  String get sessionCookie => 'Cookie de sessão';

  @override
  String get neverUsed => 'Nunca usado';

  @override
  String get linkedRecently => 'Vinculado recentemente';

  @override
  String get notUsedYet => 'Ainda não usado';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Uma ou mais contas expiraram. Reconecte para restaurar o acesso. Se isso continuar acontecendo, seu aplicativo Google Cloud OAuth pode estar no modo de teste. Publique-o em produção no Console do Google Cloud para obter tokens de longa duração.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Vault conectado e disponível após reinicialização';

  @override
  String get vaultConnectedForThisSession => 'Vault conectado para esta sessão';

  @override
  String get connectAnotherAccount => 'Conecte outra conta';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Colar o token de acesso de longa duração substituto';

  @override
  String get updateInstance => 'Atualizar instância';

  @override
  String get pasteAReplacementToken => 'Cole um token substituto';

  @override
  String get replaceAccount => 'Substituir conta';

  @override
  String get addAccount => 'Adicionar conta';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Pode delegar a qualquer agente receptor';

  @override
  String get canReceiveDelegatedTasks2 => 'pode receber tarefas delegadas';

  @override
  String get noSyncYet => 'Ainda não há sincronização';

  @override
  String get noNewData => 'Nenhum dado novo';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sincronize uma vez para propagar seu back-end.';

  @override
  String get lastWindowEndIsUnknown =>
      'O final da última janela é desconhecido.';

  @override
  String get lastNonEmptySync => 'Última sincronização não vazia';

  @override
  String get stopTranscribe => 'Pare e transcreva';

  @override
  String get steeringMode => 'Modo de direção';

  @override
  String get noMessageText => 'Nenhum texto de mensagem';

  @override
  String get reconnectingToServer => 'Reconectando ao servidor…';

  @override
  String get signingIn => 'Fazendo login...';

  @override
  String get noGroupsFoundYet => 'Nenhum grupo encontrado ainda';

  @override
  String get onForNewGroupsOnly => 'Ativado apenas para novos grupos';

  @override
  String get noGroupsInThisCategory => 'Nenhum grupo nesta categoria';

  @override
  String get groupOrChannel => 'Grupo ou canal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'As notas que você escreve para si mesmo iniciam uma execução e as respostas chegam ao mesmo bate-papo. A lista de permissões não se aplica aqui.';

  @override
  String get needToReply => 'Preciso responder';

  @override
  String get enter2faCode => 'Insira o código 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Abra seu aplicativo autenticador e insira o código NeoAgent atual.';

  @override
  String get alreadyHaveAnAccountSignIn => 'Já tem uma conta? Faça login';

  @override
  String get serverOnThisComputer => 'Servidor neste computador';

  @override
  String get showQrCode => 'Mostrar código QR';

  @override
  String get createAnotherNeoagentAccount => 'Crie outra conta NeoAgent.';

  @override
  String get canCoordinateDelegatedWork => 'Pode coordenar o trabalho delegado';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'O arquivo de tempo de execução do NeoAgent não pôde ser extraído.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'O arquivo de tempo de execução do NeoAgent não pôde ser lido.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'O arquivo de tempo de execução do NeoAgent contém um caminho inseguro.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'O arquivo de tempo de execução do NeoAgent contém um link inseguro.';

  @override
  String get installingAppPackageOnThePhone =>
      'Instalando pacote de aplicativos no telefone...';

  @override
  String get dragAndDropAApkOrApks =>
      'Arraste e solte um arquivo .apk ou .apks aqui ou clique para navegar.';

  @override
  String get releaseToInstallThisPackage => 'Solte para instalar este pacote';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'A chave de segurança não pôde ser usada.';

  @override
  String get connecting => 'Conectando…';

  @override
  String get changes => 'Mudanças';

  @override
  String get runtimeReady => 'Pronto para execução';

  @override
  String get saving => 'Salvando...';

  @override
  String get earlier => 'Anteriormente';

  @override
  String get monthJan => 'janeiro';

  @override
  String get monthFeb => 'fevereiro';

  @override
  String get monthMar => 'março';

  @override
  String get monthApr => 'abril';

  @override
  String get monthMay => 'maio';

  @override
  String get monthJun => 'junho';

  @override
  String get monthJul => 'julho';

  @override
  String get monthAug => 'agosto';

  @override
  String get monthSep => 'Setembro';

  @override
  String get monthOct => 'Outubro';

  @override
  String get monthNov => 'novembro';

  @override
  String get monthDec => 'dezembro';

  @override
  String get steeringWord => 'Direção';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Isso muda o backend do canal $arg1 para o canal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Cookies $arg1 importados';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return '${arg1}s atrás';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Direção na fila: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'O aplicativo da web não conseguiu acessar o back-end do NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'O navegador bloqueou uma solicitação necessária devido à Política de Segurança de Conteúdo.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 de 4 permitido';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Execute a tarefa normalmente.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Mudanças · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Este dispositivo · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Limite atingido$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Os códigos de recuperação $arg1 ainda estão disponíveis.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Chave de segurança $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Sessão atual';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nÚltimo uso: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Trabalhando em $arg1 neste dispositivo. O NeoAgent lê e edita a pasta diretamente e pode executar comandos, abrir aplicativos e usar a tela.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Trabalhou para $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Permitido por $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Os links de convite $arg1 de $arg2 foram revogados';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Adicione as pessoas e grupos com os quais $arg1 deve conversar';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Adicione as pessoas e grupos com os quais $arg1 pode conversar.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Onde $arg1 escuta';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 observa esses lugares em busca de menções. Qualquer pessoa pode postar aqui, então as pessoas ainda precisam de sua própria aprovação abaixo.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Essas pessoas podem perguntar $arg1 onde quer que o marquem. As funções contam apenas nos locais listados acima.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Somente quando $arg1 estiver marcado';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Ativado para todos os grupos $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 ainda ouve apenas pessoas e grupos que você já aprovou. Isso apenas permite que $arg1 participe do bate-papo comum, não apenas tags e respostas.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 ainda ouve apenas pessoas e grupos que você já aprovou. Isso apenas escolhe em qual desses grupos ele deve ingressar.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Se alguém marcar $arg1 ou responder, $arg1 sempre responde. Ative esta opção se $arg1 também quiser participar de um bate-papo em grupo comum.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Novos grupos permitirão que $arg1 participe de bate-papos comuns com pessoas aprovadas, até que você os desative.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Novos grupos permitirão que $arg1 participe do bate-papo normal até que você os desative.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Novos grupos permanecem silenciosos, a menos que uma pessoa aprovada marque $arg1, até que você os ative.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Somente quando uma pessoa aprovada marca $arg1, a menos que você ative um grupo';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Somente quando $arg1 estiver marcado, a menos que você ative um grupo';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 dos grupos $arg2 participam de bate-papo comum com pessoas aprovadas';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Isso não aprova novas pessoas. Tags e respostas de pessoas aprovadas sempre obtêm uma resposta. Ative um grupo se $arg1 também quiser entrar no bate-papo normal lá.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Isso não aprova novas pessoas. Ative um grupo se $arg1 quiser entrar no bate-papo normal com pessoas que você já aprovou.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Tags e respostas sempre obtêm uma resposta. Ative um grupo se $arg1 também quiser entrar no bate-papo normal lá.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 entra no bate-papo comum com pessoas aprovadas';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 pode entrar no chat normal';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 só responde quando uma pessoa aprovada o marca';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'Nada extra é necessário. Conecte-se para começar a usar $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Atualizações em ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Registre-se com $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'Nenhuma memória vinculada a \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (padrão)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Filial: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 só se junta aos grupos e canais que você adiciona abaixo.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return '$arg1 é necessário para localizar dados de tempo de execução do NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[visualização truncada, total de bytes $arg1]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefato limitado, total de bytes $arg1]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' em $arg1';
  }

  @override
  String get worldNews => 'Notícias do mundo';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Corra quando novas manchetes mundiais aparecerem. Seu prompt decide se deseja notificá-lo.';

  @override
  String get newsKeywordsOptional => 'Palavras-chave (opcional)';

  @override
  String get worldNewsSetup => 'Configuração de notícias mundiais';

  @override
  String get connectWorldNewsWithGnews =>
      'Adicione uma chave API GNews (plano gratuito disponível em gnews.io). Ele é armazenado criptografado e usado para pesquisar as principais manchetes dos gatilhos do World News.';

  @override
  String get gnewsApiKey => 'Chave API GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Colar a chave API GNews substituta';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Deixe a chave vazia para manter a chave armazenada atualmente.';

  @override
  String get gnewsApiKeyIsRequired => 'É necessária uma chave API GNews.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'Não foi possível salvar a configuração do World News.';

  @override
  String get disconnectWorldNews => 'Desconecte as notícias do mundo';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Isso remove a chave da API GNews armazenada. Os gatilhos do World News pararão de disparar até que você adicione uma chave novamente.';

  @override
  String get couldNotDisconnectWorldNews =>
      'Não foi possível desconectar o World News.';

  @override
  String get systemOneModels => 'Modelos SystemOne';

  @override
  String get systemOneAuto => 'Automático';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Escolhe o melhor modelo SystemOne disponível';

  @override
  String get systemOneOffTheChatModelDecides =>
      'O modelo de chat toma essas decisões';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modelos de decisão que fazem chamadas nos bastidores em uma fração de segundo: turnos de bate-papo em grupo e etapas do navegador. Seu modelo de chat ainda escreve todas as respostas.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'O modelo SystemOne decide quando falar enquanto está ligado; este modelo é o substituto.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 pontuado por SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne pontuou esta mensagem diretamente. Nenhum modelo de linguagem foi executado.';

  @override
  String get systemOneUnavailable => 'SystemOne indisponível';

  @override
  String get systemOneAdminAvailability =>
      'Os agentes de modelos de decisão podem escolher em Configurações › Modelos. Um modelo desativado aqui sai desse seletor e os agentes que o escolheram voltam para Automático. Embora qualquer modelo esteja desligado, os modelos SystemOne que os provedores adicionam posteriormente também são desligados.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Ainda não há modelos SystemOne. Adicione uma chave TypeSafe ou OpenRouter em Provedores ou obtenha um modelo de decisão como ágil no Ollama 0.35 ou posterior.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Nenhum modelo SystemOne está disponível ainda. Adicione uma chave TypeSafe ou OpenRouter em Configurações › Modelos › Traga sua própria chave ou obtenha um modelo de decisão como ágil no Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone sistema um modelos de decisão jev typesafe openrouter ollama disponibilidade habilitar desabilitar';

  @override
  String get chatModels => 'Modelos de bate-papo';

  @override
  String get disabled => 'Desativado';

  @override
  String get enableShown => 'Ativar mostrado';

  @override
  String get disableShown => 'Desativar mostrado';

  @override
  String get expandAll => 'Expandir tudo';

  @override
  String get collapseAll => 'Recolher tudo';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 alterações não salvas';
  }

  @override
  String get settingsScopeAllAgents => 'Todos os agentes';

  @override
  String get settingsScopeAgent => 'Este agente';

  @override
  String get settingsScopeApp => 'Aplicativo';

  @override
  String get settingsScopeAccountHint =>
      'O mesmo em todos os lugares onde você faz login';

  @override
  String get settingsScopeAllAgentsHint =>
      'Compartilhado por todos os seus agentes';

  @override
  String get settingsAppliesTo => 'Aplica-se a';

  @override
  String get settingsSaving => 'Salvando…';

  @override
  String get settingsSavedAutomatically =>
      'As alterações são salvas automaticamente';

  @override
  String get settingsSearchHint => 'Pesquisar todas as configurações';

  @override
  String get settingsPageProfile => 'Perfil';

  @override
  String get settingsPageSecurity => 'Login e segurança';

  @override
  String get settingsPageUsage => 'Uso';

  @override
  String get settingsPagePermissions => 'Permissões';

  @override
  String get settingsPageComputer => 'Computador e web';

  @override
  String get settingsPageBehavior => 'Comportamento';

  @override
  String get settingsPageSystem => 'Sistema';

  @override
  String get settingsPagePlatforms => 'Plataformas';

  @override
  String get settingsPageProfileDescription =>
      'Seu nome e e-mail, uma cópia dos seus dados e saída.';

  @override
  String get settingsPageSecurityDescription =>
      'Senha, autenticação de dois fatores, chaves de segurança e local de login.';

  @override
  String get settingsPageUsageDescription =>
      'Seus limites e gastos com tokens, tudo em um só lugar.';

  @override
  String get settingsPageAgentsDescription =>
      'Crie agentes e escolha qual deles atende por padrão.';

  @override
  String get settingsPagePermissionsDescription =>
      'O que seus agentes podem fazer sem perguntar primeiro.';

  @override
  String get settingsPageComputerDescription =>
      'O computador em que seus agentes trabalham e os sites que eles podem ler como você.';

  @override
  String get settingsPageModelsDescription =>
      'Quais modelos esse agente usa e as chaves de API que pagam por eles.';

  @override
  String get settingsPageBehaviorDescription =>
      'Como esse agente fala e como lê um chat em grupo.';

  @override
  String get settingsPageVoiceDescription =>
      'Chamadas ao vivo, ditado e respostas faladas para este agente.';

  @override
  String get settingsPageMessagingDescription =>
      'Onde as pessoas podem entrar em contato com esse agente e como ele se comporta nos chats.';

  @override
  String get settingsPageGeneralDescription =>
      'Aparência, idioma, fuso horário e o que este aplicativo faz em segundo plano.';

  @override
  String get settingsPageSystemDescription =>
      'O servidor que esta janela usa, aquele neste computador e atualizações de aplicativos.';

  @override
  String get settingsYourAgents => 'Seus agentes';

  @override
  String get settingsChatModel => 'Modelo de bate-papo';

  @override
  String get settingsChatModelDescription => 'Responde suas mensagens.';

  @override
  String get settingsSubAgentModel => 'Modelo de subagente';

  @override
  String get settingsSubAgentModelDescription =>
      'Executa o trabalho entregue durante uma tarefa.';

  @override
  String get settingsDefaultModels => 'Modelos padrão';

  @override
  String get settingsDefaultModelsDescription =>
      'Usado sempre que um chat ou tarefa não escolhe seu próprio modelo.';

  @override
  String get settingsModelPool => 'Conjunto de modelos';

  @override
  String get settingsApiKeysDescription =>
      'Use suas próprias chaves ou endpoint para este agente. As chaves são criptografadas e nunca mais mostradas.';

  @override
  String get settingsPersona => 'Pessoa';

  @override
  String get settingsFineTuning => 'Ajuste fino';

  @override
  String get settingsFineTuningDescription =>
      'Raramente necessário. Os padrões são adequados para a maioria dos chats.';

  @override
  String get settingsShow => 'Mostrar';

  @override
  String get settingsHide => 'Esconder';

  @override
  String get settingsMinimumContribution => 'Valor mínimo de contribuição';

  @override
  String get settingsBatchWindow => 'Janela de lote de salas';

  @override
  String get settingsBatchWindowDescription =>
      'Espera tanto tempo para tratar mensagens rápidas como um turno.';

  @override
  String get settingsHandsFree => 'Viva-voz';

  @override
  String get settingsHandsFreeDescription =>
      'Fale livremente e interrompa a qualquer momento.';

  @override
  String get settingsPushToTalkDescription =>
      'Segure para falar, solte para enviar.';

  @override
  String get settingsLiveVoice => 'Voz ao vivo';

  @override
  String get settingsChannels => 'Canais';

  @override
  String get settingsGroupChats => 'Em bate-papos em grupo';

  @override
  String get settingsGroupChatsDescription =>
      'Como este agente se comporta em grupos em cada canal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Ative os módulos de comportamento em Comportamento para alterá-los.';

  @override
  String get settingsParticipationAutomatic => 'Automático';

  @override
  String get settingsParticipationMentionOnly => 'Mencionar apenas';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Lê a sala e participa quando tem algo útil a acrescentar.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Responde apenas quando mencionado ou respondido.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Respostas a todas as mensagens.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Divide respostas mais longas em mensagens curtas, como uma pessoa faria.';

  @override
  String get settingsDeliverySingleDescription =>
      'Envia cada resposta como uma mensagem.';

  @override
  String get settingsComputerStatus => 'Estado';

  @override
  String get settingsTest => 'Teste';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsCloseWindow => 'Quando você fecha a janela';

  @override
  String get settingsCloseAsk => 'Pergunte';

  @override
  String get settingsCloseKeepRunningDescription =>
      'O NeoAgent continua funcionando em segundo plano e permanece acessível.';

  @override
  String get settingsCloseQuitDescription =>
      'O NeoAgent é encerrado completamente.';

  @override
  String get settingsPhoneTriggers => 'Gatilhos de telefone';

  @override
  String get settingsPhoneTriggersDescription =>
      'Sinais que este telefone envia aos seus agentes para que as tarefas possam reagir a eles.';

  @override
  String get settingsLocationTriggers => 'Gatilhos de localização';

  @override
  String get settingsLocationTriggersDescription =>
      'Verifica sua localização aproximada a cada poucos minutos em relação aos locais monitorados por suas tarefas.';

  @override
  String get settingsNotificationTriggers => 'Gatilhos de notificação';

  @override
  String get settingsNotificationTriggersDescription =>
      'Encaminha notificações de outros aplicativos deste telefone para seus agentes.';

  @override
  String get settingsSetup => 'Configuração';

  @override
  String get settingsOnboarding => 'Integração';

  @override
  String get settingsOnboardingDescription =>
      'Percorra a configuração inicial novamente. Nada do que você configura é perdido.';

  @override
  String get settingsUsernameDescription =>
      'Usado para fazer login. Não pode ser alterado.';

  @override
  String get settingsExport => 'Exportar';

  @override
  String get settingsLeave => 'Sair e excluir';

  @override
  String get settingsSignOutDescription =>
      'Desconecta você apenas neste dispositivo.';

  @override
  String get settingsDeleteAccountDescription =>
      'Apaga sua conta, agentes, memória e configurações. Isso não pode ser desfeito.';

  @override
  String get settingsTokenUsage => 'Uso de token';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Nenhuma configuração corresponde a “$query”.';
  }

  @override
  String settingsSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '$count resultado',
    );
    return '$_temp0';
  }

  @override
  String get settingsAdvancedModels => 'Configurações avançadas do modelo';

  @override
  String get settingsAdvancedModelsDescription =>
      'Opcional. Fixe um modelo em um tipo de trabalho; ele assume o controle sempre que o agente usa essas ferramentas. Qualquer coisa deixada no padrão segue o modelo de chat.';

  @override
  String get settingsTaskModelDefault => 'Padrão';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Segue o modelo de chat';

  @override
  String get settingsTaskModelCoding => 'Codificação';

  @override
  String get settingsTaskModelCodingDescription =>
      'Escrever, editar e depurar código.';

  @override
  String get settingsTaskModelComputerUse => 'Uso do computador';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Conduzindo o navegador e a área de trabalho.';

  @override
  String get settingsTaskModelAndroidUse => 'Uso do Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Operando aplicativos em um dispositivo Android ou emulador.';

  @override
  String get settingsTaskModelResearch => 'Pesquisa';

  @override
  String get settingsTaskModelResearchDescription =>
      'Pesquisando, lendo e resumindo fontes.';

  @override
  String get knowledgeGraphHint =>
      'Suas entidades mais mencionadas, coloridas por cluster. As linhas conectam entidades que aparecem nas mesmas memórias. Toque em um para ver seus links e memórias; arraste para deslocar, aperte ou Ctrl/⌘-scroll para ampliar.';

  @override
  String get linkedEntities => 'Entidades vinculadas';

  @override
  String get noLinkedEntities => 'Ainda não vinculado a outras entidades.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 menciona';
  }

  @override
  String get entityKindConcept => 'Conceito';

  @override
  String get entityKindDomain => 'Domínio';

  @override
  String get entityKindEmail => 'E-mail';

  @override
  String get entityKindLink => 'Ligação';

  @override
  String get entityKindFile => 'Arquivo';

  @override
  String get entityKindAcronym => 'Sigla';

  @override
  String get entityKindIdentifier => 'Identificador';

  @override
  String get entityKindVersion => 'Versão';

  @override
  String get openFullscreen => 'Abrir tela cheia';

  @override
  String get zoomIn => 'Ampliar';

  @override
  String get zoomOut => 'Diminuir zoom';

  @override
  String get searchEntities => 'Encontre uma entidade';

  @override
  String get incomingCall => 'Chamada recebida';

  @override
  String get answerCall => 'Resposta';

  @override
  String get callMeLater => 'Me ligue mais tarde';

  @override
  String get callingEllipsis => 'Chamando…';

  @override
  String get reconnectingCall => 'Reconectando';

  @override
  String get agentWorking => 'Trabalhando';

  @override
  String get micMuted => 'Silenciado';

  @override
  String get speakerphone => 'Palestrante';

  @override
  String get muteMic => 'Mudo';

  @override
  String get unmuteMic => 'Ativar som';

  @override
  String get releaseToSend => 'Liberar para enviar';

  @override
  String get callEnded => 'Chamada encerrada';

  @override
  String get openConversation => 'Conversa aberta';

  @override
  String get callBack => 'Ligue de volta';

  @override
  String get letCallsReachYou => 'Deixe as chamadas chegarem até você';

  @override
  String get callPermissionsIntro =>
      'Seus agentes podem ligar para você. Para tocar como uma chamada telefônica enquanto o NeoAgent está em segundo plano ou seu telefone está bloqueado, ele precisa deles.';

  @override
  String get showOverOtherApps => 'Mostrar sobre outros aplicativos';

  @override
  String get showOverOtherAppsDetail =>
      'Abre a tela de chamada onde quer que você esteja.';

  @override
  String get fullScreenCalls => 'Chamadas em tela cheia';

  @override
  String get fullScreenCallsDetail => 'Toca na tela de bloqueio.';

  @override
  String get unrestrictedBattery => 'Bateria irrestrita';

  @override
  String get unrestrictedBatteryDetail =>
      'Mantém o NeoAgent conectado para que as chamadas cheguem.';

  @override
  String get permissionAllowed => 'Permitido';

  @override
  String get triggerSectionCalendar => 'Calendário';

  @override
  String get triggerSectionFiles => 'Arquivos e documentos';

  @override
  String get triggerSectionHome => 'Casa e mídia';

  @override
  String get triggerSectionDevices => 'Dispositivos e lugares';

  @override
  String get triggerSectionTasks => 'Tarefas';

  @override
  String get messagingMemberJoined => 'Membro entrou';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Execute quando alguém entrar em um servidor Discord, grupo Telegram ou WhatsApp, canal Slack ou sala Matrix.';

  @override
  String get messagingMemberLeft => 'Membro saiu';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Execute quando alguém sair de um servidor Discord, grupo de Telegram ou WhatsApp, canal Slack ou sala Matrix.';

  @override
  String get messagingReactionAdded => 'Reação adicionada';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Executar quando uma pessoa autorizada reagir a uma mensagem em um chat privado.';

  @override
  String get messagingPlatformDisconnected => 'Mensagens desconectadas';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Execute quando uma conexão de mensagens parar e precisar de você, como após um logout.';

  @override
  String get googleCalendarEventStarting => 'Evento do Google Agenda começando';

  @override
  String get googleCalendarEventCreated => 'Evento do Google Agenda criado';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Execute quando um novo evento ou convite aparecer.';

  @override
  String get outlookCalendarEventStarting =>
      'Evento do calendário do Outlook começando';

  @override
  String get nextcloudCalendarEventStarting =>
      'Evento do calendário Nextcloud começando';

  @override
  String get runMinutesBeforeEachEvent =>
      'Execute um determinado número de minutos antes de cada evento.';

  @override
  String get googleDriveFileAdded => 'Arquivo do Google Drive adicionado';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Execute quando um arquivo for adicionado ao Drive ou a uma pasta nele.';

  @override
  String get googleSheetsRowAdded => 'Linha do Planilhas Google adicionada';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Execute quando novas linhas aparecerem em uma planilha.';

  @override
  String get onedriveFileAdded => 'Arquivo OneDrive adicionado';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Execute quando um arquivo for adicionado a uma pasta do OneDrive.';

  @override
  String get nextcloudFileAdded => 'Arquivo Nextcloud adicionado';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Execute quando um arquivo for adicionado a uma pasta Nextcloud.';

  @override
  String get nextcloudShareReceived =>
      'Arquivo Nextcloud compartilhado com você';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Execute quando alguém compartilhar um arquivo ou pasta com você.';

  @override
  String get notionItemAdded => 'Item de banco de dados de noção adicionado';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Executado quando um item é adicionado a um banco de dados do Notion.';

  @override
  String get notionItemUpdated => 'Item do banco de dados de noção atualizado';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Executar quando um item em um banco de dados Notion for alterado.';

  @override
  String get trelloCardEnteredList => 'Cartão Trello adicionado à lista';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Executado quando um cartão é criado ou movido para uma lista.';

  @override
  String get figmaCommentAdded => 'Comentário Figma adicionado';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Execute quando alguém comentar em um arquivo Figma.';

  @override
  String get githubPrOpened => 'Solicitação pull do GitHub aberta';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Execute quando uma nova solicitação pull for aberta em um repositório.';

  @override
  String get githubWorkflowRunFailed =>
      'Falha na execução do fluxo de trabalho do GitHub';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Execute quando uma execução do GitHub Actions falhar.';

  @override
  String get githubCommitPushed => 'Confirmação do GitHub enviada';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Execute quando novos commits chegarem a um branch.';

  @override
  String get mcpServerFailed => 'Falha no servidor MCP';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Execute quando um servidor MCP que estava funcionando falhar ou precisar de login.';

  @override
  String get homeAssistantStateChanged => 'Estado do Home Assistant alterado';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Executado quando uma entidade muda, atinge um estado ou ultrapassa um valor.';

  @override
  String get spotifyTrackChanged => 'Faixa do Spotify alterada';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Execute quando uma faixa diferente começar a tocar.';

  @override
  String get neorecallDailySummaryReady => 'Resumo diário do NeoRecall pronto';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Execute quando o resumo de um dia for final.';

  @override
  String get neorecallConversationRecorded => 'Conversa NeoRecall gravada';

  @override
  String get runWhenARecordedConversationEnds =>
      'Execute quando uma conversa gravada terminar.';

  @override
  String get geofenceTrigger => 'Cerca geográfica de localização';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Corra quando seu telefone chegar ou sair de um lugar. Precisa de rastreamento de localização no telefone.';

  @override
  String get healthMetricRecorded => 'Métrica de saúde registrada';

  @override
  String get runWhenAHealthReadingArrives =>
      'Execute quando chegar uma leitura de integridade sincronizada, opcionalmente acima ou abaixo de um valor.';

  @override
  String get wearableConnectionChanged => 'Vestível conectado ou desconectado';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Execute quando seu wearable se conectar ou desconectar.';

  @override
  String get taskRunFinished => 'Mais uma tarefa concluída';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Execute depois que outra tarefa for concluída, bem-sucedida ou falhar.';

  @override
  String get appPackageOptional => 'Pacote de aplicativos (opcional)';

  @override
  String get appPackageHelper => 'Por exemplo com.whatsapp';

  @override
  String get anyPlatform => 'Qualquer plataforma';

  @override
  String get spaceIdOptional =>
      'ID de servidor, grupo, canal ou sala (opcional)';

  @override
  String get spaceIdHelper => 'Vazio observa cada um em que o bot está.';

  @override
  String get emojiOptional => 'Emoji (opcional)';

  @override
  String get chatIdOptional => 'ID do bate-papo (opcional)';

  @override
  String get platformOptional => 'Plataforma (opcional)';

  @override
  String get platformOptionalHelper =>
      'Por exemplo watsapp. Relógios vazios todos.';

  @override
  String get minutesBefore => 'Minutos antes';

  @override
  String get calendarIdOptional => 'ID do calendário (opcional)';

  @override
  String get calendarIdHelper => 'Vazio usa seu calendário principal.';

  @override
  String get invitesOnly => 'Apenas convites de outras pessoas';

  @override
  String get nextcloudCalendarPath => 'Calendário';

  @override
  String get nextcloudCalendarPathHelper =>
      'Seu nome na lista de calendário Nextcloud, por exemplo pessoal';

  @override
  String get folderIdOptionalHelperDrive => 'Vazio assiste todo o Drive.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Vazio monitora a pasta raiz.';

  @override
  String get driveFolderIdOptional => 'ID da pasta (opcional)';

  @override
  String get spreadsheetId => 'ID da planilha';

  @override
  String get sheetRange => 'Alcance';

  @override
  String get sheetRangeHelper => 'As colunas da tabela, por exemplo Sheet1!A:E';

  @override
  String get folderPathOptional => 'Caminho da pasta (opcional)';

  @override
  String get folderPathHelper => 'Por exemplo Documentos';

  @override
  String get notionDatabaseId => 'ID do banco de dados';

  @override
  String get trelloListId => 'ID da lista';

  @override
  String get figmaFileKey => 'Chave do arquivo';

  @override
  String get figmaFileKeyHelper => 'No link do arquivo: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Repositório';

  @override
  String get workflowOptional => 'Fluxo de trabalho (opcional)';

  @override
  String get workflowHelper => 'Nome de arquivo como ci.yml';

  @override
  String get branchOptional => 'Filial (opcional)';

  @override
  String get branchHelper => 'Vazio usa o branch padrão.';

  @override
  String get mcpServerIdOptional => 'ID do servidor MCP (opcional)';

  @override
  String get entityId => 'ID da entidade';

  @override
  String get entityIdHelper => 'Por exemplo binário_sensor.front_door';

  @override
  String get targetStateOptional => 'Estado de destino (opcional)';

  @override
  String get targetStateHelper => 'Por exemplo em';

  @override
  String get aboveOptional => 'Acima (opcional)';

  @override
  String get belowOptional => 'Abaixo (opcional)';

  @override
  String get placeName => 'Nome do lugar';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get radiusMeters => 'Raio em metros';

  @override
  String get geofenceTransition => 'Quando';

  @override
  String get arriving => 'Chegando';

  @override
  String get leaving => 'Saindo';

  @override
  String get healthMetric => 'Métrica de saúde';

  @override
  String get healthMetricHelper =>
      'Por exemplo frequência cardíaca, passos, peso';

  @override
  String get wearableTransition => 'Quando o vestível';

  @override
  String get wearableConnects => 'Conecta';

  @override
  String get wearableDisconnects => 'Desconecta';

  @override
  String get sourceTask => 'Depois da tarefa';

  @override
  String get taskOutcome => 'Resultado';

  @override
  String get anyOutcome => 'Qualquer resultado';

  @override
  String get succeeded => 'Sucesso';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return '$arg1 está ausente ou não é válido.';
  }

  @override
  String get triggerSectionMessaging => 'Mensagens';

  @override
  String get triggerSectionDeveloper => 'Desenvolvedor';

  @override
  String get triggerSectionMemory => 'Memória';

  @override
  String get triggerSectionNews => 'Notícias';

  @override
  String get triggerSectionSystem => 'Sistema';

  @override
  String get searchTriggersHint =>
      'Gatilhos de pesquisa, aplicativos ou eventos';

  @override
  String get noTriggersMatch => 'Nenhum gatilho corresponde à sua pesquisa.';

  @override
  String get triggerAccountMissing => 'Nenhuma conta ainda';

  @override
  String get pickTriggerKeyboardHint => 'Enter escolhe o primeiro resultado';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return 'Gatilhos $arg1';
  }

  @override
  String get addFromSkillsSh => 'Adicionar de skills.sh';

  @override
  String get skillsShHint =>
      'Pesquise acima para encontrar habilidades em skills.sh ou cole um link skills.sh ou um comando `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Nenhuma habilidade skills.sh corresponde a esta pesquisa.';

  @override
  String get installingSkill => 'Instalando…';

  @override
  String installedSkillArg1(Object? arg1) {
    return '$arg1 instalado';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Instalações $arg1';
  }

  @override
  String get authVerify => 'Verifique';

  @override
  String get authCreateAccount => 'Criar conta';

  @override
  String get authNewInviteLink => 'Novo link de convite';

  @override
  String get authShowPassword => 'Mostrar senha';

  @override
  String get authHidePassword => 'Ocultar senha';

  @override
  String get authPasswordWillBeRejected => 'muito fraco, será rejeitado';

  @override
  String get authUsernameTooShort =>
      'Os nomes de usuário precisam de pelo menos 3 caracteres.';

  @override
  String get authUsernameTaken => 'Esse nome de usuário já está em uso.';

  @override
  String get authSignupsClosed =>
      'As inscrições estão encerradas neste servidor. Peça uma conta ao administrador.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Este servidor só aceita logins por HTTPS. Abra $arg1.';
  }

  @override
  String get authInsecureTransport =>
      'Este servidor só aceita logins por HTTPS. Conecte-se a ele com um endereço https://.';

  @override
  String get authAccountNotFound => 'Essa conta não existe mais.';

  @override
  String get authQrRateLimited =>
      'Muitas solicitações de login QR. Espere um momento e atualize o código.';

  @override
  String get authForgotPasswordAskAdmin =>
      'Esqueceu sua senha? Peça ao administrador do servidor para redefini-lo em Admin → Usuários.';

  @override
  String get authChangeServer => 'Alterar servidor';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Fazendo login em $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Este endereço não responde como um servidor NeoAgent. Verifique o URL e tente novamente.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'Não foi possível abrir uma conexão segura (HTTPS) com $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'Não foi possível acessar $arg1 por HTTPS e o HTTP simples também não respondeu. Verifique o endereço e a porta.';
  }

  @override
  String get adminResetPassword => 'Redefinir senha';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Redefinir senha para $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Escolha uma nova senha para $arg1. Eles serão desconectados de todos os dispositivos e farão login novamente com esta senha.';
  }

  @override
  String get adminNewPassword => 'Nova senha';

  @override
  String get adminSetPassword => 'Definir senha';

  @override
  String get authMissingFields => 'Preencha todos os campos obrigatórios.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 redefiniu a senha de $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Senha atualizada; o usuário foi desconectado em todos os lugares.';

  @override
  String get authSignInTitle => 'Faça login no NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Digitalize com seu telefone ou use sua senha.';

  @override
  String get authOrUsePassword => 'ou use sua senha';

  @override
  String get qrLoginWaitingTitle => 'Aprove no seu telefone';

  @override
  String get qrLoginWaitingBody =>
      'Seu telefone leu o código. Confirme o login para finalizar o login.';

  @override
  String get qrLoginSigningInOn => 'Fazendo login em';

  @override
  String get qrLoginLocation => 'Localização';

  @override
  String get qrLoginWaitingForApproval => 'Aguardando aprovação';

  @override
  String get qrLoginCancelAndUsePassword => 'Cancelar e usar uma senha';

  @override
  String get qrLoginDeclinedOnPhone =>
      'O login foi recusado no seu telefone. Digitalize o novo código para tentar novamente.';

  @override
  String get signupKey => 'Chave de registo';

  @override
  String get signupKeyStepSubtitle =>
      'As novas contas neste servidor precisam de uma chave de registo. Introduza a que recebeu de um administrador.';

  @override
  String get signupKeyChange => 'Alterar';

  @override
  String get signupKeyRequiredError => 'Introduza a sua chave de registo.';

  @override
  String get signupKeyInvalidError =>
      'Essa chave de registo não é válida. Verifique-a e tente novamente.';

  @override
  String get signupKeyUsedError =>
      'Essa chave de registo já foi utilizada. Peça uma nova a um administrador.';

  @override
  String get adminRequireSignupKey => 'Exigir uma chave de registo';

  @override
  String get adminRequireSignupKeyHint =>
      'As novas contas precisam de uma chave de utilização única de um administrador. Se estiver desativado, qualquer pessoa que aceda a este servidor pode registar-se. A primeira conta nunca precisa de chave.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'As novas contas passam a precisar de uma chave de registo.';

  @override
  String get adminSignupOpenNotice => 'Qualquer pessoa pode agora registar-se.';

  @override
  String get signupKeys => 'Chaves de registo';

  @override
  String get signupKeysDescription =>
      'Chaves de utilização única para registo enquanto for exigida uma chave. Cada chave cria exatamente uma conta.';

  @override
  String get signupKeysNew => 'Novas chaves';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Por usar · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Usadas · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Revogadas · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Todas · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Por usar';

  @override
  String get signupKeyStatusUsed => 'Usada';

  @override
  String get signupKeyStatusRevoked => 'Revogada';

  @override
  String get signupKeysExport => 'Exportar .txt';

  @override
  String get signupKeysCopied => 'Chaves copiadas';

  @override
  String get signupKeyCopied => 'Chave copiada';

  @override
  String get signupKeysEmpty => 'Não há chaves nesta lista.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Criada em $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Usada por $arg1 em $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Usada em $arg1 por uma conta entretanto eliminada';
  }

  @override
  String get signupKeyRevokeTitle => 'Revogar esta chave?';

  @override
  String get signupKeyRevokeMessage =>
      'Ninguém poderá registar-se com ela. Esta ação não pode ser anulada.';

  @override
  String get signupKeyRevoked => 'Chave revogada.';

  @override
  String signupKeysShowMore(int count) {
    return 'Mostrar mais $count';
  }

  @override
  String get signupKeysCreateTitle => 'Criar chaves de registo';

  @override
  String get signupKeysCount => 'Número de chaves';

  @override
  String get signupKeysCountHelper => 'De 1 a 500';

  @override
  String get signupKeysCountInvalid => 'Introduza um número de 1 a 500.';

  @override
  String get signupKeysLabel => 'Etiqueta (opcional)';

  @override
  String get signupKeysLabelHint => 'p. ex. Testadores beta da primavera';

  @override
  String signupKeysCreateAction(int count) {
    return 'Criar ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Chaves prontas: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Entregue cada chave a uma só pessoa. As chaves por usar ficam na lista, para que as possa copiar ou exportar mais tarde.';

  @override
  String get signupKeysSaveDialogTitle => 'Guardar chaves de registo';

  @override
  String get signupKeysExported => 'Chaves exportadas.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor criou chaves de registo ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor revogou uma chave de registo';
  }

  @override
  String get providerChooseUsername => 'Escolha seu nome de usuário';

  @override
  String get providerChooseUsernameBody =>
      'Escolha um nome de usuário disponível para concluir a criação da sua conta.';

  @override
  String get dataSharingTitle => 'Compartilhar dados de uso';

  @override
  String get dataSharingDescription =>
      'Ajude quem administra este servidor a melhorá-lo. Compartilha como você usa o NeoAgent, nunca o que você escreve ou armazena.';

  @override
  String dataSharingSince(String date) {
    return 'Compartilhando desde $date.';
  }

  @override
  String get dataSharingWhatsShared => 'O que é compartilhado';

  @override
  String get dataSharingIncluded => 'Compartilhado';

  @override
  String get dataSharingExcluded => 'Nunca compartilhado';

  @override
  String get dataSharingIncludedDevice => 'Tipo de dispositivo e versão do app';

  @override
  String get dataSharingIncludedLocale =>
      'Idioma do app e região do fuso horário, como Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Quais recursos você configurou, como tarefas, skills e integrações';

  @override
  String get dataSharingIncludedRuns =>
      'Quais ferramentas e modelos suas execuções usam, com tempos e contagem de tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Quando você usa o NeoAgent, por dia da semana e hora';

  @override
  String get dataSharingExcludedContent => 'Mensagens, prompts e respostas';

  @override
  String get dataSharingExcludedRuns =>
      'Títulos de execuções, entradas e resultados de ferramentas';

  @override
  String get dataSharingExcludedFiles =>
      'Arquivos, memórias e tudo o que você armazena';

  @override
  String get dataSharingExcludedIdentity =>
      'Seu nome, e-mail, endereço IP e localização';

  @override
  String get dataSharingExcludedAccounts =>
      'As contas com que você conecta integrações';

  @override
  String get dataSharingPooledNote =>
      'Os administradores só veem totais de todos que compartilham, nunca você individualmente. Desative a qualquer momento e você sai dos totais na hora.';

  @override
  String get dataSharingConfirmTitle => 'Compartilhar dados de uso?';

  @override
  String get dataSharingConfirmAction => 'Compartilhar';

  @override
  String get sharedUsageTitle => 'Uso compartilhado';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Contas que compartilham dados de uso: $sharing de $total. Apenas totais, sem conteúdo.';
  }

  @override
  String get sharedUsageEmpty =>
      'Ninguém compartilha dados de uso ainda. Dá para ativar em Configurações, Perfil, Seus dados.';

  @override
  String get sharedUsageRuns => 'Execuções compartilhadas';

  @override
  String get sharedUsageAvgDuration => 'Duração média';

  @override
  String get sharedUsageCompletedRuns => 'Execuções concluídas';

  @override
  String get sharedUsageStepsPerRun => 'Etapas por execução';

  @override
  String get sharedUsageDevices => 'Dispositivos';

  @override
  String get sharedUsageAppVersions => 'Versões do app';

  @override
  String get sharedUsageLanguages => 'Idiomas';

  @override
  String get sharedUsageRegions => 'Regiões';

  @override
  String get sharedUsageFeatures => 'Adoção de recursos';

  @override
  String get sharedUsageFeaturesDescription =>
      'Parcela das contas que compartilham e configuraram o recurso.';

  @override
  String get sharedUsageTools => 'Ferramentas';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Ferramentas mais chamadas ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Chamadas: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Falhas: $percent%';
  }

  @override
  String get sharedUsageIntegrations => 'Integrações';

  @override
  String get sharedUsageMessaging => 'Canais de mensagens';

  @override
  String get sharedUsageTriggers => 'Como as execuções começam';

  @override
  String get sharedUsageActivity => 'Quando é usado';

  @override
  String get sharedUsageActivityDescription =>
      'Execuções por dia da semana e hora, UTC.';

  @override
  String get sharedUsageModels => 'Desempenho dos modelos';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return '$latency em média · $cached% em cache · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Contas: $count';
  }

  @override
  String get sharedUsageNoData => 'Nada neste período.';

  @override
  String get sharedUsageNotReported => 'Ainda não informado';

  @override
  String get sharedUsageFeatureAgents => 'Mais de um agente';

  @override
  String get sharedUsageFeatureTasks => 'Tarefas agendadas';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'Servidores MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Integrações';

  @override
  String get sharedUsageFeatureMessaging => 'Canais de mensagens';

  @override
  String get sharedUsageFeatureMemory => 'Memória';

  @override
  String get sharedUsageSearchKeywords =>
      'compartilhamento de dados opt-in telemetria dispositivos recursos ferramentas modelos atividade';

  @override
  String get yourOAuthApp => 'A sua app OAuth';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'A sua app OAuth do $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Este servidor não tem uma app global do $provider, por isso liga-se com uma app OAuth registada por si. O segredo do cliente é guardado encriptado e nunca mais é mostrado.';
  }

  @override
  String get oauthAppStepCreate => '1. Criar a app';

  @override
  String get openDeveloperConsole => 'Abrir consola de programador';

  @override
  String get oauthAppStepCallback => '2. Registar este URL de callback';

  @override
  String get callbackUrlCopied => 'URL de callback copiado';

  @override
  String get oauthAppScopes => 'Scopes a permitir';

  @override
  String get scopesCopied => 'Scopes copiados';

  @override
  String get oauthAppStepCredentials => '3. Colar as credenciais da app';

  @override
  String get couldNotSaveOAuthApp => 'Não foi possível guardar a app OAuth.';

  @override
  String removeOAuthAppTitle(String provider) {
    return 'Remover a sua app do $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'As contas ligadas continuam listadas, mas deixam de funcionar até adicionar novamente uma app.';

  @override
  String get globalIntegrationConfiguration =>
      'Configuração global de integrações';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Apps OAuth opcionais para todo o servidor. Quando uma integração tem uma, todas as contas a usam e não podem adicionar a sua. Deixe uma integração por definir e cada utilizador configura a sua própria app. Os segredos são só de escrita: deixe em branco para manter o valor guardado.';

  @override
  String get globalStatus => 'Global';

  @override
  String get perUserStatus => 'Por utilizador';
}
