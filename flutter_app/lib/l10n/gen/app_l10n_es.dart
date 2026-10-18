// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get onboardingEyebrowWelcome => 'Bienvenido';

  @override
  String get onboardingEyebrowCommunication => 'Comunicación';

  @override
  String get onboardingEyebrowIntelligence => 'Inteligencia';

  @override
  String get onboardingEyebrowComputer => 'Ordenador';

  @override
  String get onboardingEyebrowAutomation => 'Automatización';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingIntroCouldNotLoad =>
      'No se pudo cargar la introducción.';

  @override
  String get onboardingModelDescription =>
      'Elige el modelo que NeoAgent debe usar de forma predeterminada o deja que lo elija automáticamente.';

  @override
  String get onboardingLoadingModels => 'Cargando modelos…';

  @override
  String get noAiModelTitle => 'Aún no se ha configurado ningún modelo de IA';

  @override
  String get noAiModelBody =>
      'Añade una clave API de un proveedor como OpenAI, Anthropic o Google. NeoAgent mostrará los modelos que puedes usar.';

  @override
  String get noAiModelChatBody =>
      'NeoAgent necesita un modelo de IA para responder. Agregue una clave API de un proveedor como OpenAI, Anthropic o Google.';

  @override
  String get noAiModelAdminHint =>
      'Como administrador, también puede configurar proveedores para todos en Administrador → Proveedores.';

  @override
  String get addApiKey => 'Añadir clave API';

  @override
  String onboardingMessagingConnected(String platform) {
    return '$platform está conectado.';
  }

  @override
  String onboardingMessagingWaiting(String platform) {
    return 'Esperando a que $platform se conecte...';
  }

  @override
  String onboardingFinishFailed(String error) {
    return 'No se pudo guardar la configuración: $error';
  }

  @override
  String get onboardingEyebrowReady => 'Listo';

  @override
  String get onboardingStepRequired => 'Requerido';

  @override
  String get onboardingStepOptional => 'Opcional';

  @override
  String get onboardingStepCloudOrLocal => 'Nube o local';

  @override
  String get onboardingStepComputer => 'Ordenador';

  @override
  String get onboardingStepRoutines => 'Rutinas';

  @override
  String get onboardingComputerChoiceTitle => '¿Dónde debe\ntrabajar?';

  @override
  String get onboardingComputerChoiceDescription =>
      'Puedes cambiar de ordenador en cada sesión.';

  @override
  String get onboardingCloudComputerSubtitle =>
      'Zona de pruebas privada · siempre activa';

  @override
  String get onboardingThisComputer => 'Este ordenador';

  @override
  String get onboardingThisComputerSubtitle =>
      'Tus archivos, aplicaciones y navegador';

  @override
  String get onboardingSearchApps => 'Buscar aplicaciones…';

  @override
  String get onboardingRoutinesDescription =>
      'Los resultados llegan a tus chats.';

  @override
  String get onboardingRoutinesDescriptionPhone =>
      'Los resultados llegan como notificaciones.';

  @override
  String get onboardingNotifications => 'Notificaciones';

  @override
  String get onboardingReadyTitle => 'Todo está\nlisto.';

  @override
  String get onboardingReadyDescription => 'Envía tu primer mensaje.';

  @override
  String get onboardingMessageNeoagent => 'Enviar un mensaje a NeoAgent';

  @override
  String get onboardingAskAnything => 'Pregunta cualquier cosa...';

  @override
  String get onboardingOpenNeoagent => 'Abrir NeoAgent';

  @override
  String get onboardingStarterTrip => 'Planifica un viaje de fin de semana';

  @override
  String get onboardingStarterLanding => 'Crear una página de destino';

  @override
  String onboardingQuickSteps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pasos rápidos',
      one: '$count paso rápido',
    );
    return '$_temp0';
  }

  @override
  String get taskNeedsEmail => 'Conecte el correo electrónico primero';

  @override
  String get taskNeedsCalendar => 'Conecte un calendario primero';

  @override
  String get taskNeedsModel => 'Primero configure un modelo de IA';

  @override
  String get taskPromptDailyRecap =>
      'Resuma mi día: resuma las conversaciones, el trabajo terminado y las decisiones de hoy, luego enumere todo lo que debo seguir mañana. Sea breve y envíemelo.';

  @override
  String get taskPromptInboxCheck =>
      'Revisar la bandeja de entrada de mi correo electrónico para ver los mensajes que llegaron desde la última verificación. Envíame mensajes únicamente sobre correos electrónicos que sean urgentes o que necesiten respuesta, con un resumen de una línea cada uno. Si nada necesita mi atención, no envíes nada.';

  @override
  String get taskPromptMorningBriefing =>
      'Prepare mi sesión informativa matutina: el clima de hoy en el lugar donde me encuentro, los eventos en mi calendario y los temas abiertos más importantes que conozco. Envíelo como un mensaje breve y escaneable.';

  @override
  String get taskPromptTomorrowPrep =>
      'Mira mi calendario para mañana. Para cada reunión, dime de qué se trata, quiénes participan y todo lo que debo preparar. Si mañana está vacío, no envíes nada.';

  @override
  String get taskPromptNewsDigest =>
      'Busque en la web las noticias más importantes del día sobre los temas que me interesan (use lo que recuerde sobre mis intereses). Envíame un resumen de hasta cinco elementos con una oración cada uno y un enlace.';

  @override
  String get taskPromptWeeklyReview =>
      'Revisa mi semana: lo que se hizo, lo que falló y lo que aún está abierto. Sugiera las tres cosas más importantes en las que concentrarse la próxima semana.';

  @override
  String get whatsappSeparateAccountDescription =>
      'Vincula un número de teléfono que pertenece al agente. Cualquiera que usted permita puede chatear con él, en chats directos y grupos.';

  @override
  String get whatsappSelfChatDescription =>
      'Vincula tu propio número y habla con el agente en tu chat \"Envía mensajes\". Se ignoran todos los demás chats y grupos de esta cuenta.';

  @override
  String get chatSendHintMac => '⌘↵ para enviar';

  @override
  String get chatSendHintOther => 'Ctrl+Entrar para enviar';

  @override
  String get aBaseUrlIsRequiredFor =>
      'Se requiere una URL base para este punto final.';

  @override
  String get aChangedEmailAddressIsConfirmed =>
      'Una dirección de correo electrónico modificada se confirma antes de utilizarla.';

  @override
  String get aDecisionHigherUpTheChain =>
      'Una decisión más arriba en la cadena gana.';

  @override
  String get aDeletedAccount => 'una cuenta eliminada';

  @override
  String get aFridayLookBackAtThe =>
      'Un viernes repaso de la semana y un plan para la próxima.';

  @override
  String get aKeyThatAsksForA =>
      'Una clave que solicita un PIN o una huella digital también reemplaza su código de dos factores.';

  @override
  String get aLanguageModelJudgedThisMessage =>
      'Un modelo de lenguaje juzgó este mensaje porque SystemOne está apagado.';

  @override
  String get aNeoagentSetupMetadataFileExceeded =>
      'Un archivo de metadatos de instalación de NeoAgent superó su límite de tamaño seguro.';

  @override
  String get aNewerWebBuildIsAvailable =>
      'Hay una versión web más nueva disponible en el servidor. Vuelva a cargar para obtener el paquete más reciente.';

  @override
  String get aPrivateDesktopWithChromiumFiles =>
      'Un escritorio privado con Chromium, archivos, editor de texto, terminal y Python. Su trabajo permanece guardado entre sesiones.';

  @override
  String get aPrivateLinuxComputerOrAn =>
      'Una computadora Linux privada o un dispositivo Android.';

  @override
  String get aRequiredNeoagentSetupFileCould =>
      'No se pudo descargar un archivo de instalación de NeoAgent requerido.';

  @override
  String get aTeammateSendsYouAnInvite =>
      'Un compañero de equipo te envía un enlace de invitación. Una vez que lo aceptes, ellos ';

  @override
  String get aTeammateSentYouAnInvite =>
      'Un compañero de equipo te envió un enlace de invitación, ingrésalo aquí para unirte a su equipo.';

  @override
  String get aTemporaryDownloadWillBeCleaned =>
      'Una descarga temporal se limpiará más tarde.';

  @override
  String get aValueIsStored => 'Se almacena un valor.';

  @override
  String get access => 'Acceso';

  @override
  String get accessActivity => 'Actividad de acceso';

  @override
  String accessArg1(Object? arg1) {
    return 'Acceso: $arg1';
  }

  @override
  String get accessMode => 'Modo de acceso';

  @override
  String get accessPermissions => 'Permisos de acceso';

  @override
  String get accessToken => 'token de acceso';

  @override
  String get accessToken2 => 'token de acceso';

  @override
  String get account => 'Cuenta';

  @override
  String accountArg1(Object? arg1) {
    return 'Cuenta #$arg1';
  }

  @override
  String get accountChangeAlerts => 'Alertas de cambio de cuenta';

  @override
  String get accountEmail => 'Correo electrónico de la cuenta';

  @override
  String get accountEmailIsOffUntilThese =>
      'El correo electrónico de la cuenta está desactivado hasta que se establezcan estos: ';

  @override
  String get accountLanguageDescription =>
      'NeoAgent usa este idioma en toda la aplicación. La primera vez que inicias sesión, usa el idioma de este dispositivo. Después, tu elección se guarda en tu cuenta y se aplica en todos tus dispositivos.';

  @override
  String accountLanguageFailed(Object? error) {
    return 'No se pudo cambiar el idioma: $error';
  }

  @override
  String get accountLanguageTitle => 'Idioma';

  @override
  String get accountNumber => 'Número de cuenta';

  @override
  String get accountSettings => 'Configuración de la cuenta';

  @override
  String get accounts => 'Cuentas';

  @override
  String get accountsByTokensUsedAllTime =>
      'Cuentas por tokens utilizados, todo el tiempo.';

  @override
  String get accountsCloudComputersChangesApplyAfter =>
      'computadoras en la nube de sus cuentas. Los cambios se aplican después de un servidor. ';

  @override
  String get accountsOnThisServer => 'Cuentas en este servidor';

  @override
  String get active => 'Activo';

  @override
  String get activeSessions => 'Sesiones activas';

  @override
  String get activeToday => 'Activo hoy';

  @override
  String get add => 'Añadir';

  @override
  String get addAProviderCredentialFirstIts =>
      'Primero agregue una credencial de proveedor. Sus modelos aparecen aquí una vez. ';

  @override
  String get addAgent => 'Agregar agente';

  @override
  String get addAnotherSignInMethodBefore =>
      'Agregue otro método de inicio de sesión antes de eliminar este.';

  @override
  String get addBinding => 'Agregar enlace';

  @override
  String get addByNameOrId => 'Agregar por nombre o ID';

  @override
  String get addByNameOrIdInstead => 'En su lugar, agregue por nombre o ID';

  @override
  String get addCredentialBinding => 'Agregar enlace de credenciales';

  @override
  String get addEntry => 'Agregar entrada';

  @override
  String get addKey => 'Agregar clave';

  @override
  String get addMcpServer => 'Agregar servidor MCP';

  @override
  String get addMemory => 'Agregar memoria';

  @override
  String get memoryReview => 'Revisar';

  @override
  String get memoryReviewPrompt =>
      'Revisa todos mis recuerdos y límpialos: archiva los duplicados, los datos desactualizados y todo lo que no tenga valor duradero. Luego dime brevemente qué cambiaste.';

  @override
  String get addMoreLengthOrAnotherCharacter =>
      'Agregue más longitud u otro tipo de carácter.';

  @override
  String get addPeopleOrGroups => 'Agregar personas o grupos';

  @override
  String get addSecurityKey => 'Agregar clave de seguridad';

  @override
  String get addSomeoneOrAGroup => 'Agregar a alguien o un grupo';

  @override
  String get addTask => 'Agregar tarea';

  @override
  String get addTests => 'Agregar pruebas';

  @override
  String get addTestsForThePartsOf =>
      'Agregue pruebas para las partes de este proyecto que tengan la menor cobertura y luego ejecútelas.';

  @override
  String get addTheirOwnKeysInSettings =>
      'agregue sus propias claves en Configuración.';

  @override
  String get addToPrompt => 'Agregar al mensaje';

  @override
  String get added => 'Añadido';

  @override
  String addedArg1LastUsedArg2(Object? arg1, Object? arg2) {
    return 'Añadido $arg1 · Último usado $arg2';
  }

  @override
  String get addressWithTheProvider => 'dirección con el proveedor.';

  @override
  String get adjustSpeakerVolumeReviewHardwareButton =>
      'Ajuste el volumen del altavoz, revise los valores predeterminados de los botones del hardware y administre esta sesión de inicio.';

  @override
  String get adjustTheSearchOrStatusFilter =>
      'Ajuste el filtro de búsqueda o estado para ver más canales de mensajería.';

  @override
  String get adjustTheSpeakerVolumeHere =>
      'Ajuste el volumen del altavoz aquí.';

  @override
  String get admin => 'Administrador';

  @override
  String adminArg1(Object? arg1) {
    return 'Administrador › $arg1';
  }

  @override
  String get adminGrantsInviteLinksAndManagement =>
      'Aquí se muestran las subvenciones de administrador, los enlaces de invitación y los cambios de gestión.';

  @override
  String get advancedManualScheduleForSpecialCases =>
      'Horario manual avanzado para casos especiales.';

  @override
  String get advancedMinuteHourDayMonthWeekday =>
      'Avanzado: minuto hora día mes día laborable.';

  @override
  String get againRightAway => 'nuevamente de inmediato.';

  @override
  String get agent => 'Agente';

  @override
  String agentArg1(Object? arg1) {
    return 'Agente: $arg1';
  }

  @override
  String get agentCalls => 'Llamadas de agentes';

  @override
  String get agentCommunication => 'Comunicación del agente';

  @override
  String agentCommunicationArg1(Object? arg1) {
    return 'Comunicación del agente: $arg1.';
  }

  @override
  String get agentModeEditsTheWorkspaceSend =>
      'El modo agente edita el espacio de trabajo · ⌘↵ enviar · ⌘N nueva sesión';

  @override
  String get agentPausesAndAsksYouBefore =>
      'El agente se detiene y te pide permiso antes de iniciar la ejecución.';

  @override
  String get agentProfile => 'Perfil del agente';

  @override
  String get agentVisibleName => 'Nombre visible para el agente';

  @override
  String agentWantsToUseArg1Tap(Object? arg1) {
    return 'El agente quiere usar $arg1. Toca para decidir.';
  }

  @override
  String get agents => 'Agentes';

  @override
  String get aiAnswerUnreadable => 'Respuesta de IA ilegible';

  @override
  String get aiProviderKeys => 'Claves del proveedor de IA';

  @override
  String get aiUnavailable => 'IA no disponible';

  @override
  String get alertsAndOtherAccountEmailFrom =>
      'alertas y otras cuentas de correo electrónico de.';

  @override
  String get alertsWhenAMessagingConnectionNeeds =>
      'Alertas cuando una conexión de mensajería necesita la atención del usuario';

  @override
  String get all => 'Todos';

  @override
  String allAgentsArg1(Object? arg1) {
    return 'Todos los agentes ($arg1)';
  }

  @override
  String allArg1(Object? arg1) {
    return 'Todo $arg1';
  }

  @override
  String get allCloudComputerSlotsAreCurrently =>
      'Todas las ranuras para computadoras en la nube están actualmente en uso. Inténtalo de nuevo en un momento.';

  @override
  String get allComputerSlotsAreBusy =>
      'Todas las ranuras de la computadora están ocupadas.';

  @override
  String get allTables => 'Todas las mesas';

  @override
  String get allTime => 'Todo el tiempo';

  @override
  String get allToolsAreAllowedTheAgent =>
      'Todas las herramientas están permitidas: el agente puede utilizar cualquier capacidad sin preguntar. ';

  @override
  String get allow => 'Permitir';

  @override
  String get allowedRunsWithoutAsking => 'Permitido. Corre sin preguntar.';

  @override
  String get allowAll => 'Permitir todo';

  @override
  String get allowInstallUnknownAppsForNeoagent =>
      'Permita \"Instalar aplicaciones desconocidas\" para NeoAgent y luego vuelva a intentar la actualización.';

  @override
  String get allowOnce => 'permitir una vez';

  @override
  String get allowSender => 'Permitir remitente';

  @override
  String get allowSession => 'Permitir sesión';

  @override
  String get allowTheAgentToStartAn =>
      'Permita que el agente inicie una llamada de voz dentro de la aplicación con usted.';

  @override
  String get allowedOrigins => 'Orígenes permitidos';

  @override
  String get allowedPathPrefix => 'Prefijo de ruta permitido';

  @override
  String get allowsYouCanChangeThatPer =>
      'lo permite. Puedes cambiar eso por persona más tarde. Los enlaces nunca otorgan ';

  @override
  String get alreadyBelongsToAnExistingAccount =>
      'ya pertenece a una cuenta existente';

  @override
  String get alreadyLinkedToAnotherAccount => 'ya vinculado a otra cuenta';

  @override
  String get alreadyLinkedToAnotherNeoagentAccount =>
      'ya vinculado a otra cuenta neoagent';

  @override
  String get alreadyUsed => 'ya usado';

  @override
  String get always => 'siempre';

  @override
  String get alwaysAllow => 'Permitir siempre';

  @override
  String get alwaysAllowSavesThePolicyPermanently =>
      '\"Permitir siempre\" guarda la política de forma permanente; puede cambiarla en Configuración.';

  @override
  String get alwaysAsk => 'siempre pregunta';

  @override
  String get alwaysEngage => 'Siempre participa';

  @override
  String get alwaysJoins => 'Siempre se une';

  @override
  String get anApiKeyIsRequired => 'Se requiere una clave API.';

  @override
  String get anEveningSummaryOfWhatHappened =>
      'Un resumen vespertino de lo sucedido y de qué seguir.';

  @override
  String get anHttpOrHttpsUrlIs => 'Se requiere una URL http o https.';

  @override
  String get andAnalyticsTeamLinksLiveOn =>
      'y análisis. Los enlaces del equipo se encuentran en la página del equipo.';

  @override
  String get andSExpiresAtDatetimeNow =>
      '  AND s.expires_at > datetime(\'\'now\'\')\n';

  @override
  String get androidApkInstallIsUnavailableOn =>
      'La instalación de APK de Android no está disponible en esta plataforma.';

  @override
  String get androidApp => 'aplicación de Android';

  @override
  String get androidControl => 'Control Android';

  @override
  String get androidCouldNotStart => 'Android no pudo iniciar';

  @override
  String get androidNotificationReceived => 'Notificación de Android recibida';

  @override
  String get androidOnly => 'Sólo Android';

  @override
  String get androidPackageInstallerCouldNotBe =>
      'No se pudo abrir el instalador del paquete de Android.';

  @override
  String get androidScreenTapToTouchDrag =>
      'Pantalla de Android: toque para tocar, arrastre para deslizar';

  @override
  String get androidSdk => 'SDK de Android';

  @override
  String get answersMentionsOnIssuesAndPull =>
      'Responde @menciones sobre problemas y solicitudes de extracción.';

  @override
  String get anyone => 'cualquiera';

  @override
  String anyoneOnThisPlatformCanMessage(Object? arg1) {
    return 'Cualquiera en esta plataforma puede enviar mensajes a $arg1.';
  }

  @override
  String anyoneOnThisPlatformCanMessage2(Object? arg1, Object? arg2) {
    return 'Cualquiera en esta plataforma puede enviar mensajes a $arg1 en $arg2.';
  }

  @override
  String anyoneWhoCanReachThisAccount(Object? arg1) {
    return 'Cualquiera que pueda comunicarse con esta cuenta puede hablar con $arg1.';
  }

  @override
  String get anyoneWithTheLinkCanJoin =>
      'Cualquiera que tenga el enlace puede unirse hasta que caduque o usted lo revoque.';

  @override
  String get apiHttpsOrigin => 'Origen API HTTPS';

  @override
  String get apiKey => 'clave API';

  @override
  String get apiKey2 => 'clave API';

  @override
  String get apiKey3 => 'Clave API';

  @override
  String get apiKeyAnthropicClaudeOpenaiGpt =>
      'clave api claude antrópico openai gpt xai grok google gemini minimax nvidia nim credenciales de openrouter';

  @override
  String get apiKeysAndEndpointsForAi =>
      'Claves API y puntos finales para proveedores de inteligencia artificial, búsqueda y voz. ellos ';

  @override
  String get apiRequest => 'Solicitud de API';

  @override
  String get apiYourOwnServerASelf =>
      'API: su propio servidor, un modelo autohospedado u otro ';

  @override
  String apkDownloadFailedWithHttpArg1(Object? arg1) {
    return 'La descarga de APK falló con HTTP $arg1.';
  }

  @override
  String get appNameIsRequired => 'El nombre de la aplicación es obligatorio.';

  @override
  String get appUpdates => 'Actualizaciones de aplicaciones';

  @override
  String get appUpdatesAreNotConfiguredFor =>
      'Las actualizaciones de la aplicación no están configuradas para esta compilación.';

  @override
  String appliedArg1QueuedSteeringUpdatesTo(Object? arg1) {
    return 'Se aplicaron actualizaciones de dirección en cola $arg1 a la ejecución actual.';
  }

  @override
  String appliedArg1SteeringUpdateS(Object? arg1) {
    return 'Actualizaciones de dirección $arg1 aplicadas.';
  }

  @override
  String get apply => 'Aplicar';

  @override
  String get applyBehaviorNotes => 'Aplicar notas de comportamiento';

  @override
  String get applyCoreMemory => 'Aplicar memoria central';

  @override
  String get approvalRequestsForSensitiveAgentTools =>
      'Solicitudes de aprobación para herramientas de agentes confidenciales';

  @override
  String get approvalRequired => 'Se requiere aprobación';

  @override
  String get approvalStaysInsideYourAuthenticatedMobile =>
      'La aprobación permanece dentro de su sesión móvil autenticada y cada código caduca automáticamente después de un breve período.';

  @override
  String get approveLogin => 'Aprobar inicio de sesión';

  @override
  String get approveQrLogin => 'Aprobar inicio de sesión QR';

  @override
  String get approveThisOnlyIfYouStarted =>
      'Apruebe esto solo si inició el inicio de sesión en ese dispositivo hace un momento.';

  @override
  String approvedLoginForArg1(Object? arg1) {
    return 'Inicio de sesión aprobado para $arg1.';
  }

  @override
  String get approvedOnly => 'Sólo aprobado';

  @override
  String approvedPairingForArg1(Object? arg1) {
    return 'Emparejamiento aprobado para $arg1.';
  }

  @override
  String get approvedPeopleAndGroups => 'Personas y grupos aprobados';

  @override
  String get approvedPeopleOnly => 'Solo personas aprobadas';

  @override
  String get archive => 'Archivo';

  @override
  String get archiveAgent => '¿Agente de archivo?';

  @override
  String archiveArg1(Object? arg1) {
    return 'Archivo ($arg1)';
  }

  @override
  String archiveArg1Arg2(Object? arg1, Object? arg2) {
    return 'Archivo $arg1 $arg2?';
  }

  @override
  String get archiveSelectedMemories => '¿Archivar recuerdos seleccionados?';

  @override
  String get areSharedByEveryAccountOn =>
      'son compartidos por todas las cuentas de este servidor; las cuentas todavía pueden ';

  @override
  String arg1(Object? arg1) {
    return '=== $arg1 ===\n';
  }

  @override
  String arg11mInput(Object? arg1) {
    return '\$$arg1 / 1M de entrada';
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
    return 'Acceso $arg1 necesario';
  }

  @override
  String arg1Accounts(Object? arg1) {
    return 'cuentas $arg1';
  }

  @override
  String arg1Active(Object? arg1) {
    return '$arg1 activo';
  }

  @override
  String arg1AddedEditItAnyTime(Object? arg1) {
    return 'Se agregó $arg1. Edítalo en cualquier momento para cambiar el ';
  }

  @override
  String arg1AndItsRunHistoryWill(Object? arg1) {
    return '“$arg1” y su historial de ejecución se eliminarán permanentemente. Se detendrá cualquier ejecución activa. Los archivos en el espacio de trabajo no se tocan.';
  }

  @override
  String arg1ApprovalNeeded(Object? arg1) {
    return 'Se necesita aprobación $arg1';
  }

  @override
  String arg1AppsActive(Object? arg1) {
    return 'Aplicaciones $arg1 activas';
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
    return '$arg1 (herramientas activas $arg2)';
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
    return '$arg1 $arg2 y $arg3';
  }

  @override
  String arg1Arg2Changed(Object? arg1, Object? arg2) {
    return '$arg1 $arg2 cambiado';
  }

  @override
  String arg1Arg2Chars(Object? arg1, Object? arg2) {
    return 'Caracteres $arg1 · $arg2';
  }

  @override
  String arg1Arg2CreatedArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 · $arg2 · Creado $arg3';
  }

  @override
  String arg1Arg2LocalUriArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '- $arg1 ($arg2) [uri local: $arg3]';
  }

  @override
  String arg1Arg2MatchingArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 $arg2 que coincide con “$arg3”';
  }

  @override
  String arg1Arg2NeoagentWorkspace(Object? arg1, Object? arg2) {
    return '$arg1${arg2}Espacio de trabajo de NeoAgent';
  }

  @override
  String arg1Arg2NewAccounts(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 nuevas cuentas';
  }

  @override
  String arg1Arg2Runs(Object? arg1, Object? arg2) {
    return '$arg1\n$arg2 corre · ';
  }

  @override
  String arg1Arg2S(Object? arg1, Object? arg2) {
    return '$arg1 (${arg2}s)';
  }

  @override
  String arg1Arg2Samples(Object? arg1, Object? arg2) {
    return 'Muestras $arg1 · $arg2';
  }

  @override
  String arg1Arg2SteeringQueued(Object? arg1, Object? arg2) {
    return '$arg1 · Dirección $arg2 en cola';
  }

  @override
  String arg1Arg2Tokens(Object? arg1, Object? arg2) {
    return '$arg1\nFichas $arg2';
  }

  @override
  String arg1Arg2Tokens3(Object? arg1, Object? arg2) {
    return 'Fichas $arg1 / $arg2';
  }

  @override
  String arg1AtArg2(Object? arg1, Object? arg2) {
    return '$arg1 y $arg2';
  }

  @override
  String arg1B(Object? arg1) {
    return '$arg1 B';
  }

  @override
  String arg1BecameAnAdminArg2(Object? arg1, Object? arg2) {
    return '$arg1 se convirtió en administrador ($arg2)';
  }

  @override
  String arg1Bytes(Object? arg1) {
    return '$arg1 bytes';
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
    return '$arg1 borrado.';
  }

  @override
  String arg1Configured(Object? arg1) {
    return '$arg1 configurado';
  }

  @override
  String arg1ConnectedChooseRepositoriesAndPeople(Object? arg1) {
    return '$arg1 conectado. Elija repositorios y personas en Quién puede enviar mensajes.';
  }

  @override
  String arg1CoreEntries(Object? arg1) {
    return 'Entradas principales $arg1.';
  }

  @override
  String arg1CreatedAnInviteLink(Object? arg1) {
    return '$arg1 creó un enlace de invitación';
  }

  @override
  String arg1Desktop(Object? arg1) {
    return 'Escritorio $arg1';
  }

  @override
  String arg1Events(Object? arg1) {
    return 'Eventos $arg1';
  }

  @override
  String arg1Failed(Object? arg1) {
    return ' · $arg1 falló';
  }

  @override
  String arg1Failed2(Object? arg1) {
    return '$arg1 falló';
  }

  @override
  String arg1Failing(Object? arg1) {
    return '$arg1 fallando';
  }

  @override
  String arg1ForArg2(Object? arg1, Object? arg2) {
    return '$arg1 para $arg2';
  }

  @override
  String arg1Gb(Object? arg1) {
    return '$arg1 ES';
  }

  @override
  String arg1GroupsTaggedOnly(Object? arg1) {
    return 'Grupos $arg1 solo etiquetados';
  }

  @override
  String arg1HAgo(Object? arg1) {
    return 'Hace ${arg1}h';
  }

  @override
  String arg1HArg2M(Object? arg1, Object? arg2) {
    return '${arg1}h ${arg2}m';
  }

  @override
  String arg1HArg2Min(Object? arg1, Object? arg2) {
    return '$arg1 h $arg2 mín.';
  }

  @override
  String arg1Helpers(Object? arg1) {
    return 'Ayudantes de $arg1';
  }

  @override
  String arg1HitRatio(Object? arg1) {
    return '(proporción de aciertos $arg1)';
  }

  @override
  String arg1IsAnAdminSoThe(Object? arg1) {
    return '@$arg1 es administrador, por lo que la cuenta no se puede eliminar ';
  }

  @override
  String arg1IsBlockedOnArg2Update(Object? arg1, Object? arg2) {
    return '$arg1 está bloqueado en $arg2. Actualice la lista de acceso para permitir respuestas.';
  }

  @override
  String arg1IsConnectedAndResponding(Object? arg1) {
    return '$arg1 está conectado y respondiendo.';
  }

  @override
  String arg1IsNoLongerAnAdmin(Object? arg1, Object? arg2) {
    return '$arg1 ya no es administrador ($arg2)';
  }

  @override
  String arg1IsNotAvailableOnArg2(Object? arg1, Object? arg2) {
    return '$arg1 no está disponible en $arg2 (falta permiso o dependencia de tiempo de ejecución).';
  }

  @override
  String arg1JoinedUnderArg2(Object? arg1, Object? arg2) {
    return '$arg1 se unió bajo $arg2';
  }

  @override
  String arg1JudgedByLlm(Object? arg1) {
    return '$arg1 juzgado por LLM';
  }

  @override
  String arg1Kb(Object? arg1) {
    return '$arg1 KB';
  }

  @override
  String arg1KeyArg2Configured(Object? arg1, Object? arg2) {
    return 'Clave $arg1$arg2 configurada';
  }

  @override
  String arg1KeyRemoved(Object? arg1) {
    return 'Se eliminó la clave $arg1.';
  }

  @override
  String arg1Left(Object? arg1) {
    return '$arg1 izquierda';
  }

  @override
  String arg1LeftArg2(Object? arg1, Object? arg2) {
    return '$arg1 izquierda $arg2';
  }

  @override
  String arg1Linked(Object? arg1) {
    return '$arg1 vinculado';
  }

  @override
  String arg1MAgo(Object? arg1) {
    return 'Hace ${arg1}m';
  }

  @override
  String arg1MArg2S(Object? arg1, Object? arg2) {
    return '${arg1}m ${arg2}s';
  }

  @override
  String arg1MakeSureItIsRunning(Object? arg1) {
    return '$arg1. Asegúrese de que se esté ejecutando y vuelva a intentarlo.';
  }

  @override
  String arg1ManagesThisAccount(Object? arg1) {
    return '$arg1 administra esta cuenta';
  }

  @override
  String arg1Mb(Object? arg1) {
    return '$arg1 MB';
  }

  @override
  String arg1Min(Object? arg1) {
    return '$arg1 mín.';
  }

  @override
  String arg1MinArg2Sec(Object? arg1, Object? arg2) {
    return '$arg1 min $arg2 seg';
  }

  @override
  String arg1ModelsReady(Object? arg1) {
    return 'Modelos $arg1 listos';
  }

  @override
  String arg1More(Object? arg1) {
    return '+$arg1 más';
  }

  @override
  String arg1MoreStepsInRunHistory(Object? arg1) {
    return '$arg1 más pasos en el historial de ejecución';
  }

  @override
  String arg1MovedFromArg2(Object? arg1, Object? arg2) {
    return '$arg1 movido desde $arg2 ';
  }

  @override
  String arg1Ms(Object? arg1) {
    return '$arg1 ms';
  }

  @override
  String arg1MustBeAFiniteNumber(Object? arg1) {
    return '$arg1 debe ser un número finito.';
  }

  @override
  String arg1MustBeAnHttpOr(Object? arg1) {
    return '$arg1 debe ser una dirección http:// o https://.';
  }

  @override
  String arg1NeedsAttention(Object? arg1) {
    return '$arg1 necesita atención';
  }

  @override
  String arg1NeoagentWorkspace(Object? arg1) {
    return '$arg1/Espacio de trabajo NeoAgent';
  }

  @override
  String arg1NewAccountsInTheLast(Object? arg1, Object? arg2) {
    return '$arg1 nuevas cuentas en el último $arg2.';
  }

  @override
  String arg1NewMessagesSteerThisRun(Object? arg1) {
    return '$arg1 · nuevos mensajes dirigen esta carrera';
  }

  @override
  String arg1NewRuns(Object? arg1) {
    return '$arg1 nuevas ejecuciones';
  }

  @override
  String arg1NowManagesThisAccount(Object? arg1) {
    return '$arg1 ahora administra esta cuenta.';
  }

  @override
  String arg1Of4PermissionsAllowedFiles(Object? arg1) {
    return '$arg1 de 4 permisos permitidos. Los archivos están limitados a su carpeta NeoAgent Workspace.';
  }

  @override
  String arg1OfArg2Enabled(Object? arg1, Object? arg2) {
    return '$arg1 de $arg2 habilitado';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinary(Object? arg1, Object? arg2) {
    return '$arg1 de los grupos $arg2 se unen al chat ordinario';
  }

  @override
  String arg1OfArg2Models(Object? arg1, Object? arg2) {
    return '$arg1 de los modelos $arg2';
  }

  @override
  String arg1OfArg2ModelsReady(Object? arg1, Object? arg2) {
    return 'Modelos $arg1 de $arg2 listos';
  }

  @override
  String arg1OfArg2Set(Object? arg1, Object? arg2) {
    return 'Conjunto $arg1 del conjunto $arg2';
  }

  @override
  String arg1OfArg2ToolsAllowed(Object? arg1, Object? arg2) {
    return 'Herramientas $arg1 de $arg2 permitidas';
  }

  @override
  String arg1Ok(Object? arg1) {
    return '$arg1: OK';
  }

  @override
  String arg1OnDayArg2AtArg3(Object? arg1, Object? arg2, Object? arg3) {
    return '$arg1 el día $arg2 en $arg3';
  }

  @override
  String arg1OnlyRepliesToThePeople(Object? arg1) {
    return '$arg1 solo responde a las personas que agregas a continuación.';
  }

  @override
  String arg1OnlyRepliesWhenTagged(Object? arg1) {
    return '$arg1 solo responde cuando lo etiquetan';
  }

  @override
  String arg1OnlyTalksToPeopleAnd(Object? arg1) {
    return '$arg1 solo habla con personas y grupos que apruebes';
  }

  @override
  String arg1PeopleOrGroupsAdded(Object? arg1) {
    return '$arg1 personas o grupos agregados';
  }

  @override
  String arg1Planning(Object? arg1) {
    return 'Planificación $arg1';
  }

  @override
  String arg1Providers(Object? arg1) {
    return 'Proveedores de $arg1';
  }

  @override
  String arg1Ready(Object? arg1) {
    return '$arg1 listo';
  }

  @override
  String arg1Records(Object? arg1) {
    return 'Registros $arg1';
  }

  @override
  String arg1RedirectUri(Object? arg1) {
    return 'URI de redireccionamiento $arg1';
  }

  @override
  String arg1Registered(Object? arg1) {
    return '$arg1 registrado';
  }

  @override
  String arg1Replied(Object? arg1) {
    return '$arg1 respondió';
  }

  @override
  String arg1RevokedAnInviteLink(Object? arg1) {
    return '$arg1 revocó un enlace de invitación';
  }

  @override
  String arg1Runs(Object? arg1) {
    return '$arg1 se ejecuta';
  }

  @override
  String arg1RunsArg2(Object? arg1, Object? arg2) {
    return '$arg1 se ejecuta · $arg2';
  }

  @override
  String arg1RunsInTheLastArg2(Object? arg1, Object? arg2) {
    return '$arg1 se ejecuta en el último $arg2.';
  }

  @override
  String arg1Saved(Object? arg1) {
    return '$arg1 guardado.';
  }

  @override
  String arg1Sec(Object? arg1) {
    return '$arg1 segundo';
  }

  @override
  String arg1Selected(Object? arg1) {
    return '$arg1 seleccionado';
  }

  @override
  String arg1Shown(Object? arg1) {
    return 'Se muestra $arg1';
  }

  @override
  String arg1StayedQuiet(Object? arg1) {
    return '$arg1 se quedó callado';
  }

  @override
  String arg1SteeringArg2Queued(Object? arg1, Object? arg2) {
    return '$arg1 dirección $arg2 en cola';
  }

  @override
  String arg1StepArg2TapANode(Object? arg1, Object? arg2) {
    return 'Paso $arg1$arg2 · toque un nodo para inspeccionar';
  }

  @override
  String arg1Steps(Object? arg1) {
    return 'Pasos $arg1';
  }

  @override
  String arg1StoppedManagingArg2(Object? arg1, Object? arg2) {
    return '$arg1 dejó de administrar $arg2';
  }

  @override
  String arg1Tokens(Object? arg1) {
    return 'Fichas $arg1';
  }

  @override
  String arg1TokensInTheLastArg2(Object? arg1, Object? arg2) {
    return 'Tokens $arg1 en el último $arg2.';
  }

  @override
  String arg1Tools(Object? arg1) {
    return 'Herramientas $arg1';
  }

  @override
  String arg1UnavailableSavedOverride(Object? arg1) {
    return '$arg1 (anulación guardada no disponible)';
  }

  @override
  String arg1UsedArg2Remaining(Object? arg1, Object? arg2) {
    return '$arg1% usado · $arg2 restante';
  }

  @override
  String arg1WantsToTalkWithYou(Object? arg1) {
    return '$arg1 quiere hablar contigo.';
  }

  @override
  String arg1Web(Object? arg1) {
    return 'web $arg1';
  }

  @override
  String arg1WillBeRemovedPermanently(Object? arg1) {
    return '\"$arg1\" se eliminará permanentemente.';
  }

  @override
  String arg1WillManageThisAccount(Object? arg1) {
    return '$arg1 administrará esta cuenta';
  }

  @override
  String arg1WillNotReplyOnThis(Object? arg1) {
    return '$arg1 no responderá en esta plataforma';
  }

  @override
  String arg1WillNotReplyToArg2(Object? arg1, Object? arg2) {
    return '$arg1 no responderá a $arg2.';
  }

  @override
  String get artifactStorageByUser =>
      'Almacenamiento de artefactos por usuario';

  @override
  String get askAQuestionOrStartA =>
      'Haga una pregunta o comience una tarea...';

  @override
  String get askBeforeClosingToBackground =>
      'Preguntar antes de cerrar al fondo';

  @override
  String get askMe => 'Pregúntame';

  @override
  String get assignedAgent => 'Agente asignado';

  @override
  String get assignedAgent2 => 'Agente asignado';

  @override
  String assignedAgentArg1(Object? arg1) {
    return 'Agente asignado: $arg1';
  }

  @override
  String get assigneeOptional => 'Cesionario (opcional)';

  @override
  String get assistant => 'asistente';

  @override
  String get assistantKey131 => 'Tecla asistente 131';

  @override
  String get atLeast1 => 'Al menos 1.';

  @override
  String get attachFiles => 'Adjuntar archivos';

  @override
  String attentionArg1(Object? arg1) {
    return 'Atención $arg1';
  }

  @override
  String get auditLogAdminGrantRevokeInvite =>
      'registro de auditoría concesión de administrador revocar invitación historial del equipo';

  @override
  String get authMethod => 'Método de autenticación';

  @override
  String get authServerUrl => 'URL del servidor de autenticación';

  @override
  String get authentication => 'Autenticación';

  @override
  String get authenticationFailed => 'La autenticación falló.';

  @override
  String get authenticationIsStillPendingFinishThe =>
      'La autenticación sigue pendiente. Completa el proceso en el navegador y vuelve a intentarlo.';

  @override
  String get authenticationIsStillPendingFinishThe2 =>
      'La autenticación sigue pendiente. Completa el proceso en el navegador y actualiza.';

  @override
  String get authenticationTimedOut => 'Se agotó el tiempo de autenticación.';

  @override
  String get authenticationWasCanceledBeforeCompletion =>
      'La autenticación se canceló antes de completarse.';

  @override
  String get authenticatorApp => 'Aplicación de autenticación';

  @override
  String get authenticatorCode => 'Código de autenticación';

  @override
  String get authorOptional => 'Autor (opcional)';

  @override
  String get autoFirstProviderWithAnApi =>
      'Auto (primer proveedor con una clave API)';

  @override
  String get autoRoutesToTheBestAvailable =>
      'Rutas automáticas al mejor modelo disponible';

  @override
  String get automaticFast => 'Automático (rápido)';

  @override
  String get automaticReadsTheRoomAndNormally =>
      'Automático lee la habitación y normalmente se detiene. La mención únicamente no toma ninguna decisión hasta que se aborda directamente.';

  @override
  String get automaticReserved => 'Automático, reservado';

  @override
  String get automaticRollbackNeedsARetryFrom =>
      'La reversión automática necesita un nuevo intento desde la pantalla de configuración.';

  @override
  String get automaticSelectsAFastModelThrough =>
      'Automático selecciona un modelo rápido a través del catálogo de modelos normal.';

  @override
  String get automation => 'Automatización';

  @override
  String get available => 'Disponible';

  @override
  String availableAgainInArg1(Object? arg1) {
    return 'Disponible nuevamente en $arg1';
  }

  @override
  String get availableAgainShortly => 'Disponible nuevamente en breve';

  @override
  String get availableInTheDesktopAppFor =>
      'Disponible en la aplicación de escritorio para macOS, Windows y Linux';

  @override
  String get availableToTheAgent => 'Disponible para el agente';

  @override
  String get averageAllTime => 'Promedio, todos los tiempos';

  @override
  String get avgImp => 'Imp. promedio';

  @override
  String avgRunArg1Tokens(Object? arg1) {
    return 'Promedio/ejecución: tokens $arg1';
  }

  @override
  String get avoidRepeatedCharactersAndObviousSequences =>
      'Evite personajes repetidos y secuencias obvias.';

  @override
  String get awaitingScan => 'En espera de escaneo';

  @override
  String get back => 'Atrás';

  @override
  String backgroundTaskCount(Object? count) {
    return '$count en el fondo';
  }

  @override
  String get backgroundTasks => 'Tareas en segundo plano';

  @override
  String get backOn => 'de nuevo.';

  @override
  String get backToChat => 'Volver al chat';

  @override
  String get backToFolder => 'Volver a la carpeta';

  @override
  String get backToSignIn => 'Volver para iniciar sesión';

  @override
  String get backendChannel => 'Canal de fondo';

  @override
  String get backendOnThisComputer => 'Backend en esta computadora';

  @override
  String get backendSync => 'Sincronización de fondo';

  @override
  String get backgroundLocationNeeded => 'Ubicación de fondo necesaria';

  @override
  String get backgroundSyncStaysScheduledOnAndroid =>
      'La sincronización en segundo plano permanece programada en Android';

  @override
  String get badState => 'Mal estado: ';

  @override
  String get baseImageAndSizeOfThe =>
      'Imagen base y tamaño de las máquinas virtuales QEMU que se ejecutan ';

  @override
  String get baseUrlOptional => 'URL base (opcional)';

  @override
  String get baseUrlTokenLocal => 'token de URL base local';

  @override
  String get basicAuthentication => 'Autenticación básica';

  @override
  String get behaviorModules => 'Módulos de comportamiento';

  @override
  String get behaviorNotes => 'notas de comportamiento';

  @override
  String get beta => 'Beta';

  @override
  String get bitwardenCredentialBroker => 'Corredor de credenciales Bitwarden';

  @override
  String get bitwardenItem => 'Artículo de Bitwarden';

  @override
  String get bitwardenServer => 'servidor bitwarden';

  @override
  String get blankUsesCommon => 'En blanco se utiliza \"común\"';

  @override
  String get blankUsesTheDefaultCallback =>
      'Blank usa la devolución de llamada predeterminada';

  @override
  String get blankValuesUseTheProviderDefaults =>
      'Los valores en blanco utilizan los valores predeterminados del proveedor.';

  @override
  String get block => 'Bloquear';

  @override
  String blockedIncomingMessageFromArg1(Object? arg1) {
    return 'Mensaje entrante bloqueado de $arg1.';
  }

  @override
  String get bluebubblesCompatibleBridge => 'Puente compatible con BlueBubbles';

  @override
  String get bluebubblesServerUrl => 'URL del servidor BlueBubbles';

  @override
  String get botToken => 'ficha de robot';

  @override
  String get botTokenAndApprovedChats => 'Token de bot y chats aprobados';

  @override
  String get botTokenAndServerChannelAccess =>
      'Token de bot y acceso al servidor/canal';

  @override
  String get botTokenEventsApiAndChannel =>
      'Token de bot, API de eventos y acceso al canal';

  @override
  String get botUserId => 'ID de usuario del robot';

  @override
  String get botUsername => 'Nombre de usuario del robot';

  @override
  String get brandName => 'Nombre de marca';

  @override
  String get braveSearch => 'Búsqueda valiente';

  @override
  String get bridgeAnyProviderThatCanPost =>
      'Conecte cualquier proveedor que pueda publicar y recibir cargas útiles de webhooks.';

  @override
  String get bringYourOwnKey => 'trae tu propia llave';

  @override
  String get bringYourOwnKey2 => 'Trae tu propia llave';

  @override
  String get browserLinuxDesktopFilesTerminalAnd =>
      'El navegador, el escritorio Linux, los archivos, la terminal y Python comparten una computadora persistente en la nube.';

  @override
  String get browserLogin => 'Iniciar sesión en el navegador';

  @override
  String get browserScripting => 'Secuencias de comandos del navegador';

  @override
  String get call => 'llamar';

  @override
  String get callAgent => 'llame al agente';

  @override
  String get callUser => 'Llamar al usuario';

  @override
  String get calledByName => 'Llamado por su nombre';

  @override
  String get canDelegateTasksToOtherAgents =>
      'Puede delegar tareas a otros agentes.';

  @override
  String canDelegateToArg1(Object? arg1) {
    return 'Puede delegar a $arg1';
  }

  @override
  String get canReceiveDelegatedTasks => 'Puede recibir tareas delegadas';

  @override
  String get cancel => 'Cancelar';

  @override
  String get cancelTask => 'Cancelar tarea';

  @override
  String get cannotPreview => 'No se puede obtener una vista previa';

  @override
  String get cannotReceiveDelegatedTasks => 'no puede recibir tareas delegadas';

  @override
  String get cannotRunYet => 'No puedo correr todavía.';

  @override
  String get capturedThePage => 'Capturó la página';

  @override
  String get category => 'categoría';

  @override
  String chainArg1(Object? arg1) {
    return 'Cadena: $arg1. ';
  }

  @override
  String get changeSetupMode => 'Cambiar el modo de configuración';

  @override
  String get channel => 'canal';

  @override
  String get channelAccessToken => 'token de acceso al canal';

  @override
  String channelArg1Arg2UpdateVersionArg3(
    Object? arg1,
    Object? arg2,
    Object? arg3,
    Object? arg4,
    Object? arg5,
  ) {
    return 'Canal: $arg1$arg2 | Versión de actualización: $arg3$arg4$arg5';
  }

  @override
  String get channelScopedSocialMemory => 'Memoria social centrada en el canal';

  @override
  String get channels => 'Canales';

  @override
  String get chat => 'Chat';

  @override
  String get chatId => 'ID de chat';

  @override
  String get chatMode => 'modo chat';

  @override
  String get chatModel => 'Modelo de chat';

  @override
  String get checkAutomaticallyOnLaunch =>
      'Verificar automáticamente al iniciar';

  @override
  String get checkForMessagesEveryMs => 'Comprobar mensajes cada (ms)';

  @override
  String get checkForNewMessagesAutomatically =>
      'Buscar mensajes nuevos automáticamente';

  @override
  String get checkNow => 'Compruébalo ahora';

  @override
  String get checkYourEmailToConfirmYour =>
      'Revise su correo electrónico para confirmar su cuenta NeoAgent antes de iniciar sesión.';

  @override
  String checkedArg1(Object? arg1) {
    return 'Comprobado $arg1';
  }

  @override
  String get chooseACategoryOrSearchAcross =>
      'Elija una categoría o busque en todas las configuraciones.';

  @override
  String get chooseAPerson => 'Elige una persona';

  @override
  String get chooseAProjectFolder => 'Elija una carpeta de proyecto';

  @override
  String get chooseDefaultsForChatAgentsFallback =>
      'Elija los valores predeterminados para chat, agentes, comportamiento alternativo y enrutamiento inteligente.';

  @override
  String get chooseGroups => 'Elige grupos';

  @override
  String get chooseHowMuchYouWantTo =>
      'Elige cuánto quieres configurar ahora. Ambas opciones se pueden cambiar más adelante.';

  @override
  String get chooseHowThisTaskShouldStart =>
      'Elija cómo debe comenzar esta tarea. El manual se ejecuta solo en Ejecutar ahora. El horario se basa en el tiempo. La integración provoca disparos desde aplicaciones oficiales conectadas.';

  @override
  String get chooseOneToGetStartedNow =>
      'Elija uno para comenzar ahora. Puedes agregar más más tarde.';

  @override
  String get chooseTheLiveModelAndVoice =>
      'Elija el modelo en vivo y la voz en Configuración.';

  @override
  String get chooseTheirGroup => 'Elige su grupo';

  @override
  String chooseWhereThisPersonShouldBe(Object? arg1) {
    return 'Elija dónde se le debe permitir a esta persona hablar con $arg1. Puedes cambiar esto más adelante en Quién puede enviar mensajes.';
  }

  @override
  String chooseWhichGroupsArg1ShouldJoin(Object? arg1) {
    return 'Elige a qué grupos debe unirse $arg1 incluso cuando nadie lo etiquete. Es posible que esta plataforma no distinga las etiquetas de los mensajes normales.';
  }

  @override
  String get chooseWhichModelsEveryAccountOn =>
      'Elija qué modelos puede elegir cada cuenta en este servidor y ';

  @override
  String chooseWhoArg1TalksToAnd(Object? arg1) {
    return 'Elige con quién habla $arg1 y cuándo se une a los chats grupales.';
  }

  @override
  String chooseWhoCanReachArg1Then(Object? arg1) {
    return 'Elija quién puede comunicarse con $arg1 y luego guarde los cambios.';
  }

  @override
  String get chooseWhoMayMessageTheAgent =>
      'Elija quién puede enviar mensajes al agente con \"Quién puede enviar mensajes\" en la tarjeta de WhatsApp.';

  @override
  String get chooseYourDefaultModel => 'Elija su modelo\npredeterminado.';

  @override
  String get chromiumFilesTheTextEditorAnd =>
      'Chromium, archivos, el editor de texto y la terminal están disponibles desde el escritorio de Linux.';

  @override
  String get claudeCode => 'Código Claude';

  @override
  String get clear => 'Borrar';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String clearArg1(Object? arg1) {
    return '¿Borrar $arg1?';
  }

  @override
  String get clearFilter => 'Limpiar filtro';

  @override
  String get clearFilters => 'Limpiar filtros';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get clearView => 'Vista clara';

  @override
  String get cliSession => 'Sesión CLI';

  @override
  String get clickIsNotSupportedOnThis =>
      'El clic no es compatible con esta plataforma.';

  @override
  String get clickOnceToBeginCapturing =>
      'Haga clic una vez para comenzar a capturar';

  @override
  String get clickTypeAndInteractWithDesktop =>
      'Haga clic, escriba e interactúe con aplicaciones de escritorio.';

  @override
  String clickedAtArg1Arg2(Object? arg1, Object? arg2) {
    return 'Se hizo clic en ($arg1, $arg2)';
  }

  @override
  String get clickedInTheBrowser => 'Haga clic en el navegador';

  @override
  String get clientId => 'ID de cliente';

  @override
  String get clientSecret => 'secreto del cliente';

  @override
  String get close => 'Cerrar';

  @override
  String get closeJ => 'Cerrar (⌘J)';

  @override
  String get closeTeachMode => 'Cerrar el modo de enseñanza';

  @override
  String get closingTheWindowCanEitherKeep =>
      'Cerrar la ventana puede mantener NeoAgent ejecutándose en segundo plano con acceso a la bandeja o salir completamente del tiempo de ejecución del escritorio.';

  @override
  String get cloudAndSelfHostedInstancesAre =>
      'Se admiten instancias autohospedadas y en la nube. Las URL de redes locales y privadas funcionan cuando NeoAgent puede acceder a ellas.';

  @override
  String get cloudComputer => 'Ordenador en la nube';

  @override
  String cloudComputerArg1(Object? arg1) {
    return 'Computadora en la nube · $arg1';
  }

  @override
  String get cloudComputerSettingsSavedRestartThe =>
      'Se guardó la configuración de la computadora en la nube. Reinicie el servidor para aplicarlos.';

  @override
  String get cloudComputerVm => 'Computadora en la nube (VM)';

  @override
  String get cloudComputers => 'Computadoras en la nube';

  @override
  String get codeHosting => 'Alojamiento de código';

  @override
  String get commaSeparatedChannelNamesWithoutThe =>
      'Nombres de canales separados por comas, sin el #.';

  @override
  String get commaSeparatedForExampleGeneralHelp =>
      'Separados por comas, por ejemplo #general, #help';

  @override
  String get commaSeparatedTheIssueMustHave =>
      'Separados por comas. La edición debe tenerlos todos.';

  @override
  String commandFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'El comando falló ($arg1): $arg2';
  }

  @override
  String get commandIsRequired => 'Se requiere comando.';

  @override
  String get commandOutputAccumulatorIsNotActive =>
      'El acumulador de salida de comando no está activo.';

  @override
  String commandOutputUploadFailedArg1Arg2(Object? arg1, Object? arg2) {
    return 'Error al cargar la salida del comando ($arg1): $arg2';
  }

  @override
  String get commandOutputUploadOmittedArtifactMetadata =>
      'La carga de salida del comando omitió los metadatos del artefacto.';

  @override
  String get commandOutputWasAlreadyFinalized =>
      'La salida del comando ya estaba finalizada.';

  @override
  String get commandVXdotoolDevNull2 => 'command -v xdotool >/dev/null 2>&1';

  @override
  String get commandsApps => 'Comandos y aplicaciones';

  @override
  String get commandsRunInTheSamePersistent =>
      'Los comandos se ejecutan en la misma computadora persistente utilizada por el escritorio visible.';

  @override
  String get communityChatops => 'Comunidad y ChatOps';

  @override
  String get completeSetup => 'Configuración completa';

  @override
  String get completeTheWorkflowOnTheDesktop =>
      'Complete el flujo de trabajo en el escritorio.';

  @override
  String get completed => 'Completado';

  @override
  String get completelyBlockedTheAgentCannotUse =>
      'Completamente bloqueado: el agente no puede utilizar esta categoría.';

  @override
  String get computerShell => 'Carcasa de computadora';

  @override
  String get computerUsedByThisSession =>
      'Computadora utilizada en esta sesión';

  @override
  String get computerWorkspace => 'Espacio de trabajo informático';

  @override
  String get configurablePersonalWebhookBridge =>
      'Puente de webhook personal configurable';

  @override
  String get configurableRelayOrWebhookBridge =>
      'Puente de relé o webhook configurable';

  @override
  String get configurableTalkWebhookBridge =>
      'Puente de webhook de Talk configurable';

  @override
  String get configurableWebInboxBridge =>
      'Puente de bandeja de entrada web configurable';

  @override
  String get configurableWebhookBridge => 'Puente de webhook configurable';

  @override
  String get configurableWebhooks => 'Webhooks configurables';

  @override
  String get configurationOrInTheEnvFile =>
      'Configuración o en el archivo .env.';

  @override
  String get configure => 'Configurar';

  @override
  String get configureWorkspaceBehaviorAndModelDefaults =>
      'Configure el comportamiento del espacio de trabajo y los valores predeterminados del modelo.';

  @override
  String configuredArg1(Object? arg1) {
    return 'Configurado $arg1';
  }

  @override
  String get confirmEmailChanges => 'Confirmar cambios de correo electrónico';

  @override
  String get confirmNewSignUps => 'Confirmar nuevos registros';

  @override
  String get confirmPassword => 'Confirmar contraseña';

  @override
  String get confirmPassword2 => 'Confirmar contraseña';

  @override
  String get confirmYourEmailBeforeSigningIn =>
      'Confirme su correo electrónico antes de iniciar sesión. Consulte el mensaje de correo electrónico del servicio de NeoAgent.';

  @override
  String get connect => 'Conectar';

  @override
  String get connectAMessagingPlatform =>
      'Conecta una plataforma\nde mensajería.';

  @override
  String get connectAPublicHttpsHomeAssistant =>
      'Conecte un punto final público HTTPS Home Assistant con un token de acceso de larga duración. El servidor bloquea las direcciones de red locales, de bucle invertido y privadas.';

  @override
  String get connectAccount => 'Conectar cuenta';

  @override
  String get connectAppAccountsIndividuallySoThe =>
      'Conecte las cuentas de la aplicación individualmente para que la IA pueda usar la cuenta correcta para cada integración oficial.';

  @override
  String connectArg1(Object? arg1) {
    return 'Conectar $arg1';
  }

  @override
  String get connectAsManyAccountsAsYou =>
      'Conecta tantas cuentas como quieras. Cada aplicación puede utilizar una cuenta diferente.';

  @override
  String connectChannelsChooseWhoArg1Talks(Object? arg1) {
    return 'Conecte canales, elija con quién habla $arg1 y observe la actividad reciente.';
  }

  @override
  String get connectInstance => 'Conectar instancia';

  @override
  String get connectThisIntegrationFirstToPick =>
      'Conecte esta integración primero para elegir una cuenta.';

  @override
  String get connectToThisServer => 'Conéctese a este servidor';

  @override
  String get connectWhatsapp => 'Conecta WhatsApp';

  @override
  String get connectYourNextcloudInstanceIncludingSelf =>
      'Conecte su instancia de Nextcloud, incluidos los servidores autohospedados. NeoAgent abre la página de inicio de sesión de Nextcloud para que pueda iniciar sesión con contraseña, SSO o 2FA.';

  @override
  String get connectYourSelfHostedNeorecallServer =>
      'Conecte su servidor NeoRecall autohospedado. NeoAgent recibe acceso de solo lectura a búsquedas locales, recuerdos y evidencia de transcripción después de aprobar la pantalla OAuth.';

  @override
  String get connected => 'Conectado';

  @override
  String get connectedAccount => 'Cuenta conectada';

  @override
  String connectedArg1(Object? arg1) {
    return 'Conectado $arg1';
  }

  @override
  String get connectedInstance => 'Instancia conectada';

  @override
  String get connectedNeorecallUser => 'Usuario NeoRecall conectado';

  @override
  String get connectedNextcloudUser => 'Usuario conectado de Nextcloud';

  @override
  String get connectedServer => 'Servidor conectado';

  @override
  String get connectingToTheLiveVoiceModel =>
      'Conectándose al modelo de voz en vivo...';

  @override
  String connectionArg1(Object? arg1) {
    return 'Conexión #$arg1';
  }

  @override
  String get connectionId => 'ID de conexión';

  @override
  String get connectionLooksGood => 'La conexión parece buena.';

  @override
  String get connectionMethod => 'Método de conexión';

  @override
  String get containsTextOptional => 'Contiene texto (opcional)';

  @override
  String get content => 'Contenido';

  @override
  String get contentSecurityPolicy => 'política de seguridad de contenidos';

  @override
  String get continue2 => 'Continuar';

  @override
  String get continueFullSetup => 'Continuar con la configuración completa';

  @override
  String get continueRun => 'Continuar ejecutando';

  @override
  String get continueToSetup => 'Continuar con la configuración';

  @override
  String get controlSurface => 'SUPERFICIE DE CONTROL';

  @override
  String controlsAccessToArg1Tools(Object? arg1) {
    return 'Controla el acceso a las herramientas $arg1.';
  }

  @override
  String get conversation => 'Conversación';

  @override
  String get conversationIdUsedWhenThisAgent =>
      'ID de conversación utilizado cuando este agente inicia un chat.';

  @override
  String get cookieSetup => 'Configuración de cookies';

  @override
  String get cookiesNotConfigured => 'Cookies no configuradas';

  @override
  String get copiedAsCsv => 'Copiado como CSV';

  @override
  String get copiedDebugInfo => 'Información de depuración copiada';

  @override
  String get copiedExportForTheLast5 =>
      'Exportación copiada de los últimos 5 mensajes.';

  @override
  String get copiedFullPrompt => 'Mensaje completo copiado';

  @override
  String get copiedLogs => 'Registros copiados';

  @override
  String get copiedRunId => 'ID de ejecución copiada';

  @override
  String get copy => 'Copiar';

  @override
  String get copyAll => 'Copiar todo';

  @override
  String get copyCodes => 'Copiar códigos';

  @override
  String get copyCsv => 'Copiar CSV';

  @override
  String get copyDebugInfo => 'Copiar información de depuración';

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get copyLogs => 'Copiar registros';

  @override
  String get copyPrompt => 'Copiar mensaje';

  @override
  String get copyResponse => 'Copiar respuesta';

  @override
  String get copyRunId => 'Copiar ID de ejecución';

  @override
  String get copyWebhookUrl => 'Copiar la URL del webhook';

  @override
  String get core => 'Núcleo';

  @override
  String get coreMemory => 'memoria central';

  @override
  String get coreServicesThisServerDependsOn =>
      'Servicios principales de los que depende este servidor.';

  @override
  String get corsDomainHttpsPublicUrlOrigins =>
      'dominio cors https orígenes de URL públicas';

  @override
  String get couldHelp => 'podría ayudar';

  @override
  String get couldNotApproveQrLogin =>
      'No se pudo aprobar el inicio de sesión QR.';

  @override
  String get couldNotApproveQrPairing =>
      'No se pudo aprobar el emparejamiento QR.';

  @override
  String get couldNotConnect => 'No se pudo conectar.';

  @override
  String get couldNotCreateBinding => 'No se pudo crear el enlace.';

  @override
  String couldNotDeleteYourAccountArg1(Object? arg1) {
    return 'No se pudo eliminar tu cuenta: $arg1';
  }

  @override
  String get couldNotDisconnectBitwarden => 'No se pudo desconectar Bitwarden.';

  @override
  String get couldNotDisconnectHomeAssistant =>
      'No se pudo desconectar Home Assistant.';

  @override
  String get couldNotDisconnectNeorecall => 'No se pudo desconectar NeoRecall.';

  @override
  String get couldNotDisconnectNextcloud => 'No se pudo desconectar Nextcloud.';

  @override
  String get couldNotDisconnectTrello => 'No se pudo desconectar Trello.';

  @override
  String couldNotExportYourDataArg1(Object? arg1) {
    return 'No se pudieron exportar sus datos: $arg1';
  }

  @override
  String get couldNotLoadDecisions => 'No se pudieron cargar decisiones';

  @override
  String get couldNotLoadUsageData => 'No se pudieron cargar los datos de uso.';

  @override
  String couldNotOpenLinuxSettingsAutomatically(Object? arg1) {
    return 'No se pudo abrir la configuración de Linux automáticamente.$arg1';
  }

  @override
  String get couldNotOpenTheProviderLinking =>
      'No se pudo abrir la página de enlace del proveedor.';

  @override
  String get couldNotOpenTheProviderSign =>
      'No se pudo abrir la página de inicio de sesión del proveedor.';

  @override
  String get couldNotOpenTheReleaseAsset =>
      'No se pudo abrir el recurso de lanzamiento.';

  @override
  String get couldNotOpenTrelloInYour =>
      'No se pudo abrir Trello en su navegador.';

  @override
  String get couldNotOpenWorkspaceFileDownload =>
      'No se pudo abrir la descarga del archivo del espacio de trabajo.';

  @override
  String get couldNotReadTheAndroidApp =>
      'No se pudo leer el paquete de la aplicación de Android.';

  @override
  String get couldNotReadTheApk => 'No se pudo leer el APK.';

  @override
  String couldNotRemoveKeyArg1(Object? arg1) {
    return 'No se pudo eliminar la clave: $arg1';
  }

  @override
  String get couldNotSaveAgent => 'No se pudo guardar al agente.';

  @override
  String get couldNotSaveBitwardenSetup =>
      'No se pudo guardar la configuración de Bitwarden.';

  @override
  String get couldNotSaveHomeAssistantSetup =>
      'No se pudo guardar la configuración de Home Assistant.';

  @override
  String get couldNotSaveNeorecallSetup =>
      'No se pudo guardar la configuración de NeoRecall.';

  @override
  String get couldNotSaveNextcloudSetup =>
      'No se pudo guardar la configuración de Nextcloud.';

  @override
  String get couldNotSaveTrelloSetup =>
      'No se pudo guardar la configuración de Trello.';

  @override
  String get couldNotSendConfirmationEmail =>
      'no se pudo enviar el correo electrónico de confirmación';

  @override
  String get couldNotStart => 'No se pudo iniciar';

  @override
  String get countAIdAsFiles => '       COUNT(a.id) AS files,\n';

  @override
  String get countAsRuns => '       COUNT(*) AS runs,\n';

  @override
  String get countDistinctRIdAsRuns => '       COUNT(DISTINCT r.id) AS runs,\n';

  @override
  String get countRIdAsRuns => '       COUNT(r.id) AS runs\n';

  @override
  String get create => 'crear';

  @override
  String get createAPasswordFirstToChange =>
      'Primero cree una contraseña para cambiar el correo electrónico de su cuenta.';

  @override
  String get createAPasswordOrLinkAnother =>
      'cree una contraseña o vincule otro proveedor antes de eliminar este método de inicio de sesión';

  @override
  String get createATaskWhileThisAgent =>
      'Cree una tarea mientras este agente está seleccionado.';

  @override
  String get createLink => 'Crear enlace';

  @override
  String get createOrModifyFilesInYour =>
      'Cree o modifique archivos en su espacio de trabajo.';

  @override
  String get createPassword => 'Crear contraseña';

  @override
  String get createSpecialistBotsWithSeparateMemory =>
      'Cree bots especializados con memoria, configuraciones, herramientas y asignaciones de cuentas independientes.';

  @override
  String get createTheFirstAccount => 'Crea la primera cuenta';

  @override
  String get createUpdateOrDeleteSkills =>
      'Crear, actualizar o eliminar habilidades.';

  @override
  String get creatingYourSkill => 'Creando tu habilidad...';

  @override
  String get credentialBindings => 'Enlaces de credenciales';

  @override
  String get credentialUse => 'Uso de credenciales';

  @override
  String get cronBasedRecurringRunsAndOne =>
      'Ejecuciones recurrentes basadas en cron y ejecución temporizada única.';

  @override
  String get cronExpression => 'expresión cron';

  @override
  String get ctrlEnterRunsTheQuery => 'Ctrl/⌘ + Enter ejecuta la consulta.';

  @override
  String get ctrlShiftSpace => 'Ctrl + Mayús + Espacio';

  @override
  String currentEmailArg1(Object? arg1) {
    return 'Correo electrónico actual: $arg1';
  }

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get currentPasswordIsIncorrect => 'la contraseña actual es incorrecta';

  @override
  String get currentTwoStepLoginCode =>
      'Código de inicio de sesión actual de dos pasos';

  @override
  String get customAccess => 'Acceso personalizado';

  @override
  String get customCron => 'Cron personalizado';

  @override
  String get customCronMustHave5Fields =>
      'El cron personalizado debe tener 5 campos.';

  @override
  String get customEndpoint => 'punto final personalizado';

  @override
  String get customField => 'Campo personalizado';

  @override
  String get customHeader => 'Encabezado personalizado';

  @override
  String get customHeadersJson => 'Encabezados personalizados (JSON)';

  @override
  String get customOpenaiCompatible => 'Compatible con OpenAI personalizado';

  @override
  String get customOpenaiCompatibleEndpoint =>
      'Punto final personalizado compatible con OpenAI';

  @override
  String get customOutgoingUrl => 'URL saliente personalizada';

  @override
  String get dAllowedPermissionsJsonAsAllowed =>
      '       d.allowed_permissions_json AS allowed,\n';

  @override
  String get dCreatedAtAsSince => '       d.created_at AS since\n';

  @override
  String get daily => 'Diariamente';

  @override
  String get dailyRecap => 'Resumen diario';

  @override
  String get databaseQuerySelectCsvTemplates =>
      'consulta de base de datos seleccione plantillas csv';

  @override
  String dayArg1(Object? arg1) {
    return 'Día $arg1';
  }

  @override
  String get dayOfMonth => 'Día del mes';

  @override
  String get decideWhichToolsYourAgentMay =>
      'Decida qué herramientas puede utilizar su agente. Ven tu nombre y ';

  @override
  String get decisionHigherUpTheChainWins =>
      'La decisión más arriba en la cadena gana y muestra un candado con el ';

  @override
  String decisionsShowUpHereAsArg1(Object? arg1, Object? arg2) {
    return 'Las decisiones aparecen aquí cuando $arg1 lee grupos $arg2 aprobados. Sólo se conservan los últimos 30 y se restablecen cuando se reinicia el servidor.';
  }

  @override
  String get decline => 'Rechazar';

  @override
  String deepRunStepArg1(Object? arg1) {
    return 'carrera profunda · paso $arg1';
  }

  @override
  String get deepgramKey => 'Clave de Deepgram';

  @override
  String get default2 => 'Predeterminado';

  @override
  String get default3 => 'PREDETERMINADO';

  @override
  String defaultArg1(Object? arg1) {
    return 'Predeterminado ($arg1)';
  }

  @override
  String get defaultConversation => 'Conversación predeterminada';

  @override
  String get defaultForNewGroups => 'Predeterminado para nuevos grupos';

  @override
  String get defaultGroupParticipation =>
      'Participación en grupo predeterminada';

  @override
  String get defaultNeoagentWorkspace =>
      'Espacio de trabajo predeterminado de NeoAgent';

  @override
  String get defaultOpenai => 'Predeterminado (OpenAI)';

  @override
  String get defaultRateLimits => 'Límites de tasa predeterminados';

  @override
  String get defaultRateLimitsSaved =>
      'Límites de tarifa predeterminados guardados.';

  @override
  String get defaultRecommended => 'Predeterminado (recomendado)';

  @override
  String get defaultRouting => 'Ruta predeterminada';

  @override
  String get defaultSpace => 'Espacio predeterminado';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get deleteAccountPermanently => '¿Eliminar cuenta permanentemente?';

  @override
  String get deleteAnAccount => 'Eliminar una cuenta';

  @override
  String deleteArg1(Object? arg1) {
    return '¿Eliminar @$arg1?';
  }

  @override
  String deleteArg12(Object? arg1) {
    return 'Eliminar ($arg1)';
  }

  @override
  String deleteArg1Arg2Permanently(Object? arg1, Object? arg2) {
    return '¿Eliminar $arg1 $arg2 permanentemente?';
  }

  @override
  String get deleteBinding => 'Eliminar enlace';

  @override
  String get deleteCoreMemoryEntry =>
      '¿Eliminar la entrada de la memoria central?';

  @override
  String get deleteForever => 'Eliminar para siempre';

  @override
  String get deleteMcpServer => '¿Eliminar el servidor MCP?';

  @override
  String get deleteMemory => '¿Eliminar memoria?';

  @override
  String get deletePermanentlyErasesAnAccountAnd =>
      'Eliminar borra permanentemente una cuenta y todos sus datos ';

  @override
  String get deleteRun => '¿Eliminar ejecutar?';

  @override
  String get deleteRun2 => 'Eliminar ejecución';

  @override
  String get deleteSelectedMemories => '¿Eliminar recuerdos seleccionados?';

  @override
  String get deleteSession => '¿Eliminar sesión?';

  @override
  String get deleteSkill => '¿Eliminar habilidad?';

  @override
  String get deleteTask => '¿Eliminar tarea?';

  @override
  String deletedArg1(Object? arg1) {
    return 'Eliminado \"$arg1\".';
  }

  @override
  String deletedArg1AndAllOfTheir(Object? arg1) {
    return 'Se eliminó @$arg1 y todos sus datos.';
  }

  @override
  String get deletionRemovesAllYourConversationsMemories =>
      'La eliminación elimina todas sus conversaciones, recuerdos, archivos, tareas y ';

  @override
  String get deliverableArtifactProduced => 'Artefacto entregable producido';

  @override
  String get deliverableCompleted => 'Entregable completado';

  @override
  String get deliverableExecutionStarted =>
      'Se inició la ejecución del entregable';

  @override
  String get deliverableSelected => 'Entregable seleccionado';

  @override
  String get deliverableValidationFailed =>
      'La validación del entregable falló';

  @override
  String get deliverableValidationStarted => 'Validación de entrega iniciada';

  @override
  String get deny => 'Negar';

  @override
  String get describeTheOutcomeThenDemonstrateIt =>
      'Describe el resultado y luego muéstralo en el escritorio.';

  @override
  String get describeWhatToBuildOrChange =>
      'Describe qué construir o cambiar...';

  @override
  String get description => 'Descripción';

  @override
  String get desktopApp => 'aplicación de escritorio';

  @override
  String get desktopAppControlsAvailable =>
      'Controles de aplicaciones de escritorio disponibles';

  @override
  String get desktopCaptureIsNotAvailableOn =>
      'La captura de escritorio no está disponible en esta plataforma.';

  @override
  String get desktopCommandOutputUploadCancelled =>
      'Carga de salida de comando de escritorio cancelada.';

  @override
  String get desktopCompanionCommandWasCancelled =>
      'Se canceló el comando complementario de escritorio.';

  @override
  String get desktopCompanionConnectionTimedOut =>
      'Se agotó el tiempo de espera de la conexión complementaria de escritorio.';

  @override
  String get desktopCompanionHandshakeTimedOut =>
      'Se agotó el tiempo de espera del protocolo de enlace del complemento de escritorio.';

  @override
  String get desktopCompanionIsNotAvailableHere =>
      'El complemento de escritorio no está disponible aquí.';

  @override
  String get desktopCompanionIsPausedLocally =>
      'El complemento de escritorio está en pausa localmente.';

  @override
  String desktopCompanionMessageHandlingFailedArg1(Object? arg1) {
    return 'Error en el manejo de mensajes complementarios de escritorio: $arg1';
  }

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable =>
      'La configuración de permisos complementarios de escritorio no está disponible en la web.';

  @override
  String get desktopCompanionPermissionSettingsAreUnavailable2 =>
      'La configuración de permisos complementarios de escritorio no está disponible en esta plataforma.';

  @override
  String get desktopCompanionRejected => 'Compañero de escritorio rechazado.';

  @override
  String desktopCompanionResponseFailedArg1(Object? arg1) {
    return 'Error en la respuesta del complemento de escritorio: $arg1';
  }

  @override
  String get desktopControl => 'Control de escritorio';

  @override
  String get desktopFailedToStart => 'El escritorio no pudo iniciarse';

  @override
  String desktopStreamCaptureFailedArg1(Object? arg1) {
    return 'Error en la captura de flujo de escritorio: $arg1';
  }

  @override
  String get destinationId => 'ID de destino';

  @override
  String get deviceAccess => 'Acceso al dispositivo';

  @override
  String get deviceSettings => 'Configuración del dispositivo';

  @override
  String get devices => 'Dispositivos';

  @override
  String get diagnosticsSaved => 'Diagnóstico guardado.';

  @override
  String get directBluebubblesImessageBridge =>
      'Puente directo de iMessage de BlueBubbles';

  @override
  String get directMessagesRemainResponsiveAllowlistedGroups =>
      'Los mensajes directos siguen siendo receptivos. Los grupos incluidos en la lista permitida utilizan el modo de participación a continuación.';

  @override
  String get directoryDoesNotExist => 'El directorio no existe.';

  @override
  String get disable2fa => 'Deshabilitar 2FA';

  @override
  String get disableAll => 'Desactivar todo';

  @override
  String get discard => 'Descartar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get disconnectHomeAssistant => '¿Desconectar Home Assistant?';

  @override
  String get disconnectNeorecall => '¿Desconectar NeoRecall?';

  @override
  String get disconnectNextcloud => '¿Desconectar Nextcloud?';

  @override
  String get disconnectPlatform => 'Desconectar plataforma';

  @override
  String get disconnectTrello => '¿Desconectar Trello?';

  @override
  String get discoveryFailed => 'El descubrimiento falló';

  @override
  String get dismiss => 'Descartar';

  @override
  String get displayIdIsRequired => 'Se requiere identificación de pantalla.';

  @override
  String get displayName => 'Nombre para mostrar';

  @override
  String get displayNameMustBe64Characters =>
      'El nombre para mostrar debe tener 64 caracteres o menos.';

  @override
  String get displayNameSaved => 'Nombre para mostrar guardado.';

  @override
  String get doNotIncludeYourUsernameOr =>
      'No incluya su nombre de usuario o correo electrónico.';

  @override
  String get done => 'hecho';

  @override
  String get downloadACopyOfYourData =>
      'Descargue una copia de sus datos. Las cuentas de administrador no se pueden eliminar ';

  @override
  String get downloadACopyOfYourData2 =>
      'Descargue una copia de sus datos o elimine permanentemente su cuenta. ';

  @override
  String downloadArg1(Object? arg1) {
    return 'Descargar $arg1';
  }

  @override
  String get downloadUpdate => 'Descargar actualización';

  @override
  String get downloadingTheNeoagentBackend =>
      'Descargando el backend de NeoAgent';

  @override
  String get draft => 'Borrador';

  @override
  String get dragIsNotSupportedOnThis =>
      'El arrastre no es compatible con esta plataforma.';

  @override
  String get draggedOnTheScreen => 'Arrastrado en la pantalla';

  @override
  String get dropAnApkOrApkBundle =>
      'Coloque un APK o un paquete de APK aquí para instalarlo';

  @override
  String get dropApkOrApksHere => 'Suelte APK o .apks aquí';

  @override
  String get durableInstructionsForVoiceAndInteraction =>
      'Instrucciones duraderas para estilo de voz e interacción. Las normas de seguridad y ejecución siguen teniendo prioridad.';

  @override
  String get eGAlexSLaptop => 'p.ej. La computadora portátil de Alex.';

  @override
  String get eGMyLocalServer => 'por ej. mi servidor local';

  @override
  String get edit => 'Editar';

  @override
  String get editAgent => 'Editar agente';

  @override
  String get editCoreMemoryEntry => 'Editar entrada de memoria central';

  @override
  String get editInstructions => 'Editar instrucciones';

  @override
  String get editMcpServer => 'Editar servidor MCP';

  @override
  String get editTask => 'Editar tarea';

  @override
  String editedArg1(Object? arg1) {
    return 'Editado $arg1';
  }

  @override
  String get email => 'Correo electrónico';

  @override
  String get emailAccountOwnersAboutSignIns =>
      'Los propietarios de cuentas de correo electrónico acerca de inicios de sesión que parecen inusuales.';

  @override
  String get emailAccountOwnersWhenTheirAccount =>
      'Envíe un correo electrónico a los propietarios de cuentas cuando cambien los detalles de su cuenta.';

  @override
  String get emailCode => 'código de correo electrónico';

  @override
  String get emailConfirmationRequired =>
      'se requiere confirmación por correo electrónico';

  @override
  String get emailIsAlreadyInUse => 'el correo electrónico ya está en uso';

  @override
  String get emailSavedIfConfirmationIsRequired =>
      'Correo electrónico guardado. Si se requiere confirmación, verifique la nueva dirección para obtener un enlace de confirmación de NeoAgent.';

  @override
  String get emailSettingsSaved =>
      'Configuración de correo electrónico guardada.';

  @override
  String get emailUnverified => 'Correo electrónico no verificado';

  @override
  String get empty => 'vacio';

  @override
  String get emptyFile => 'archivo vacio';

  @override
  String get emptyFolder => 'carpeta vacia';

  @override
  String emptyUsesTheServerDefaultArg1(Object? arg1) {
    return 'Vacío utiliza el valor predeterminado del servidor ($arg1).';
  }

  @override
  String get enable2fa => 'Habilitar 2FA';

  @override
  String get enableAll => 'Habilitar todo';

  @override
  String get enableBehaviorModules => 'Habilitar módulos de comportamiento';

  @override
  String get enableOrDisableModels => 'Activar o desactivar modelos';

  @override
  String get enabled => 'Habilitado';

  @override
  String get encryptedPrivateToYourAccount => 'Cifrado, privado para su cuenta';

  @override
  String get end => 'Fin';

  @override
  String get endCall => 'finalizar llamada';

  @override
  String get endVoiceCall => '¿Finalizar llamada de voz?';

  @override
  String get endpoint => 'Punto final';

  @override
  String get enterAPassword => 'Introduzca una contraseña.';

  @override
  String get enterAUsername => 'Introduzca un nombre de usuario.';

  @override
  String get enterAValidEmailAddress =>
      'Ingrese una dirección de correo electrónico válida.';

  @override
  String get enterAnAddressManually => 'Introduzca una dirección manualmente';

  @override
  String get enterAnApiKeyFirst => 'Primero ingrese una clave API.';

  @override
  String get enterInviteLink => 'Ingrese el enlace de invitación';

  @override
  String get enterTheAddressOfANeoagent =>
      'Ingrese la dirección de un servidor NeoAgent.';

  @override
  String enterTheDetailsArg1GaveYou(Object? arg1, Object? arg2) {
    return 'Ingrese los detalles que $arg1 le proporcionó para que $arg2 pueda enviar y recibir mensajes.';
  }

  @override
  String get enterYour2faOrRecoveryCode =>
      'Ingrese su 2FA o código de recuperación.';

  @override
  String get enterYourCurrentPasswordToChange =>
      'Ingrese su contraseña actual para cambiarla.';

  @override
  String get enterYourCurrentPasswordToSave =>
      'Ingrese su contraseña actual para guardar los cambios del correo electrónico.';

  @override
  String get enterYourNeoagentAccountDetails =>
      'Ingrese los detalles de su cuenta NeoAgent.';

  @override
  String get enterYourUsernameOrAccountEmail =>
      'Ingrese su nombre de usuario o correo electrónico de cuenta. NeoAgent enviará un enlace de reinicio si puede coincidir con la cuenta.';

  @override
  String get enterYourUsernameOrEmail =>
      'Ingrese su nombre de usuario o correo electrónico.';

  @override
  String entityArg1(Object? arg1) {
    return 'Entidad: $arg1';
  }

  @override
  String get environment => 'Medio ambiente';

  @override
  String get error => 'error';

  @override
  String errorArg1(Object? arg1) {
    return '\nerror: $arg1';
  }

  @override
  String get errorsFromTheRecentLogGrouped =>
      'Errores del registro reciente, agrupados por mensaje.';

  @override
  String get errorsProblemsFailures => 'errores problemas fallas';

  @override
  String get eventTypesCommaSeparated =>
      'Tipos de eventos (separados por comas)';

  @override
  String get every15Minutes => 'Cada 15 minutos';

  @override
  String get every30Minutes => 'Cada 30 minutos';

  @override
  String get everyAccountOnThisServerLoses =>
      'Cada cuenta en este servidor pierde esta clave compartida. Cuentas ';

  @override
  String get everyAccountOnThisServerUses =>
      'Cada cuenta en este servidor usa esta dirección para ';

  @override
  String get everyActiveSessionForThisAccount =>
      'Cada sesión activa para esta cuenta finaliza. Pueden iniciar sesión ';

  @override
  String get everyDay0800 => 'Todos los días · 08:00';

  @override
  String get everyDay2000 => 'Todos los días · 20:00';

  @override
  String get everyHour => 'cada hora';

  @override
  String get everyRunOnThisServerAll =>
      'Cada ejecución en este servidor, todo el tiempo.';

  @override
  String get everySensitiveToolRequiresApprovalEvery =>
      'Cada herramienta sensible requiere aprobación, siempre.';

  @override
  String get everyToolRunsWithoutAskingExcept =>
      'Todas las herramientas se ejecutan sin preguntar, excepto las que la persona ';

  @override
  String everyoneInTheseGroupsChannelsOr(Object? arg1) {
    return 'Todos los miembros de estos grupos, canales o salas pueden hablar con $arg1.';
  }

  @override
  String get everyoneInThisGroup => 'Todos en este grupo';

  @override
  String everythingArg1TurnedOffForYour(Object? arg1) {
    return 'Todo lo que $arg1 desactivó para tu agente viene ';
  }

  @override
  String get everythingElseIsTurnedOff => 'Todo lo demás está apagado.';

  @override
  String get everythingIsAvailableFromTheDesktop =>
      'Todo está disponible desde el escritorio.';

  @override
  String get everythingTheAgentCanUseOfficial =>
      'Todo lo que el agente puede utilizar: integraciones oficiales, servidores MCP y habilidades.';

  @override
  String everythingYouTurnedOffForArg1(Object? arg1) {
    return 'Todo lo que apagaste para $arg1 vuelve ';
  }

  @override
  String get exactWebOriginsAllowedToMake =>
      'Orígenes web exactos permitidos para realizar solicitudes de origen cruzado, ';

  @override
  String get executeJavascriptInsideYourBrowserSession =>
      'Ejecute JavaScript dentro de la sesión de su navegador.';

  @override
  String get execution => 'Ejecución';

  @override
  String get executionDetailsAreUnavailableForThis =>
      'Los detalles de ejecución no están disponibles para esta ejecución.';

  @override
  String get executionPlanCreated => 'Plan de ejecución creado.';

  @override
  String exerciseArg1Sessions(Object? arg1) {
    return 'Sesiones de ejercicio $arg1';
  }

  @override
  String exitArg1(Object? arg1) {
    return '[salir de $arg1]';
  }

  @override
  String expiresArg1(Object? arg1) {
    return 'Vence $arg1';
  }

  @override
  String get explainThisProject => 'Explica este proyecto';

  @override
  String exploredArg1(Object? arg1) {
    return 'Explorado $arg1';
  }

  @override
  String exploredArg1Arg2(Object? arg1, Object? arg2) {
    return 'Explorado $arg1$arg2';
  }

  @override
  String get exploredTheWorkspace => 'Explorado el espacio de trabajo';

  @override
  String exportFailedArg1(Object? arg1) {
    return 'Exportación fallida: $arg1';
  }

  @override
  String get exportLast5Messages => 'Exportar los últimos 5 mensajes';

  @override
  String get exportMyData => 'exportar mis datos';

  @override
  String externalBrowserLaunchFailedWithExit(Object? arg1) {
    return 'Error al iniciar el navegador externo con el código de salida $arg1.';
  }

  @override
  String get externalBrowserLaunchIsNotSupported =>
      'El inicio del navegador externo no es compatible con esta plataforma.';

  @override
  String get externalBrowserLaunchTimedOut =>
      'Se agotó el tiempo de inicio del navegador externo.';

  @override
  String get externalMcpTools => 'Herramientas externas y MCP';

  @override
  String get extraButtons => 'Botones adicionales';

  @override
  String get extractingTheNeoagentRuntime =>
      'Extrayendo el tiempo de ejecución de NeoAgent';

  @override
  String get failed => 'Fallido';

  @override
  String failedToConnectArg1(Object? arg1) {
    return 'No se pudo conectar: $arg1';
  }

  @override
  String failedToConnectArg1Arg2(Object? arg1, Object? arg2) {
    return 'No se pudo conectar $arg1: $arg2';
  }

  @override
  String failedToDeleteArg1Arg2(Object? arg1, Object? arg2) {
    return 'No se pudo eliminar \"$arg1\": $arg2';
  }

  @override
  String get failedToFetch => 'no se pudo recuperar';

  @override
  String failedToGeneratePromptArg1(Object? arg1) {
    return 'No se pudo generar el mensaje: $arg1';
  }

  @override
  String get failedToLaunchExternalBrowserVia =>
      'No se pudo iniciar el navegador externo a través de url_launcher.';

  @override
  String get failedToLaunchOauthFlow => 'No se pudo iniciar el flujo de OAuth.';

  @override
  String get failedToLoadPolicies => 'No se pudieron cargar las políticas';

  @override
  String failedToSaveArg1(Object? arg1) {
    return 'No se pudo guardar: $arg1';
  }

  @override
  String get failedToSaveMcpServer => 'No se pudo guardar el servidor MCP.';

  @override
  String failedToSaveSelectionArg1(Object? arg1) {
    return 'No se pudo guardar la selección: $arg1';
  }

  @override
  String failedToSendNotificationToBackend(Object? arg1) {
    return 'No se pudo enviar la notificación al backend: $arg1';
  }

  @override
  String get fair => 'Feria';

  @override
  String get fasterReplies => 'Respuestas más rápidas';

  @override
  String get fewerModelCalls => 'Menos llamadas de modelos';

  @override
  String get fieldEmptyToRestoreTheBuilt =>
      'campo vacío para restaurar el valor predeterminado incorporado.';

  @override
  String get fileExceedsThe1MibEditor =>
      'El archivo excede el límite del editor de 1 MiB.';

  @override
  String get fileExceedsTheSupportedSizeLimit =>
      'El archivo excede el límite de tamaño admitido.';

  @override
  String get fileWrites => 'Escrituras de archivos';

  @override
  String get filename => 'Nombre de archivo';

  @override
  String get files => 'Archivos';

  @override
  String get filesNeoagentWritesOrEditsIn =>
      'Los archivos que NeoAgent escribe o edita en esta sesión se muestran aquí.';

  @override
  String get filesSavedByAllUsers =>
      'Archivos guardados por todos los usuarios.';

  @override
  String get fillApprovedLoginsOrAuthenticateRequests =>
      'Complete los inicios de sesión aprobados o autentique solicitudes sin mostrar secretos a la IA.';

  @override
  String get finalResponse => 'Respuesta final';

  @override
  String get findAPlatform => 'Encuentra una plataforma';

  @override
  String get findAndFixABug => 'Encontrar y corregir un error';

  @override
  String get findRecentChats => 'Encuentra chats recientes';

  @override
  String get findingTheCorrectNeoagentRuntime =>
      'Encontrar el tiempo de ejecución correcto de NeoAgent';

  @override
  String get finish => 'terminar';

  @override
  String get finishAtTheScheduledTime => 'Terminar a la hora prevista';

  @override
  String finishSigningInToArg1In(Object? arg1) {
    return 'Termine de iniciar sesión en $arg1 en su navegador y luego conéctese nuevamente.';
  }

  @override
  String get flowGraph => 'Gráfico de flujo';

  @override
  String get flutterApp => 'aplicación de aleteo';

  @override
  String get focusedExecutionProfile => 'Perfil de ejecución enfocado';

  @override
  String get folderIdOptional => 'ID de carpeta (opcional)';

  @override
  String get folderUnavailable => 'Carpeta no disponible';

  @override
  String get forExampleHttpsMatrixOrg => 'Por ejemplo https://matrix.org';

  @override
  String get forHostedOrAdvancedNetworkSetups =>
      'Para configuraciones de red alojadas o avanzadas';

  @override
  String get forLinksInEmailsBlankUses =>
      'Para enlaces en correos electrónicos. Blank utiliza la URL pública del servidor.';

  @override
  String get forgotPassword => '¿Has olvidado tu contraseña?';

  @override
  String get frameUnavailable => 'Marco no disponible';

  @override
  String freshnessArg1(Object? arg1) {
    return 'frescura: $arg1';
  }

  @override
  String get fridays1700 => 'Viernes · 17:00';

  @override
  String get fromAgentRuns => 'FROM agent_runs\n';

  @override
  String get fromAgentRunsR => 'FROM agent_runs r\n';

  @override
  String get fromAgentsA => 'FROM agents a\n';

  @override
  String get fromBotfatherAfterYouCreateThe =>
      'Desde BotFather después de crear el bot.';

  @override
  String get fromIntegrationConnectionsIc =>
      'FROM integration_connections ic\n';

  @override
  String fromNowOnArg1DecidesWhich(Object? arg1) {
    return 'De ahora en adelante, $arg1 decide qué herramientas puede utilizar su agente. ellos ';
  }

  @override
  String get fromTheDiscordDeveloperPortalUnder =>
      'Desde el Portal para desarrolladores de Discord, debajo de tu bot.';

  @override
  String get fromTheLineDevelopersConsole =>
      'Desde la consola de desarrolladores de LINE.';

  @override
  String get fromTheMatrixClientOrBot =>
      'Desde la cuenta del cliente o bot de Matrix.';

  @override
  String get fromTwitchappsComTmiOrYour =>
      'Desde twitchapps.com/tmi o tu aplicación para desarrolladores de Twitch.';

  @override
  String get fromUserDelegationsD => 'FROM user_delegations d\n';

  @override
  String get fromUserSessionsS => 'FROM user_sessions s\n';

  @override
  String get fromUsersU => 'FROM users u\n';

  @override
  String get fullPrompt => 'Aviso completo';

  @override
  String get fullSetup => 'Configuración completa';

  @override
  String get general => 'generales';

  @override
  String get generalSettings => 'Configuraciones generales';

  @override
  String get generalSettingsSaved => 'Configuración general guardada.';

  @override
  String get generateAPromptForAnotherAi =>
      'Genere un mensaje para otra IA, pegue la respuesta aquí para importar recuerdos.';

  @override
  String get generatePrompt => 'Generar mensaje';

  @override
  String geofenceTrackingErrorArg1(Object? arg1) {
    return 'Error de seguimiento de geovalla: $arg1';
  }

  @override
  String get getInspired => 'Inspírate';

  @override
  String get githubCopilot => 'Copiloto de GitHub';

  @override
  String get githubCopilotAndOpenaiCodex =>
      'Copiloto de GitHub y códice OpenAI';

  @override
  String get githubIssueOpened => 'Problema de GitHub abierto';

  @override
  String get neorecallMemoryCreated => 'Memoria NeoRecall creada';

  @override
  String githubReleaseCheckFailedWithHttp(Object? arg1) {
    return 'La verificación de la versión de GitHub falló con HTTP $arg1.';
  }

  @override
  String get githubReleasePayloadWasNotA =>
      'La carga útil de lanzamiento de GitHub no era una lista de lanzamientos.';

  @override
  String get githubUsernameThatOpenedTheIssue =>
      'Nombre de usuario de GitHub que abrió el problema';

  @override
  String get globalSecurityMode => 'Modo de seguridad global';

  @override
  String get gmailMessageReceived => 'Mensaje de Gmail recibido';

  @override
  String get good => 'bueno';

  @override
  String get goodAfternoon => 'Buenas tardes';

  @override
  String get goodEvening => 'Buenas noches';

  @override
  String get goodMorning => 'Buenos dias';

  @override
  String get goodPasswordALittleMoreLength =>
      'Buena contraseña. Un poco más de longitud lo hace más fuerte.';

  @override
  String get googleChat => 'Chat de Google';

  @override
  String get googleWorkspace => 'Espacio de trabajo de Google';

  @override
  String get gptLiveUsesYourOpenaiApi =>
      'GPT-Live usa su clave API OpenAI, Gemini Live su clave AI de Google. Los cambios aplican para la próxima convocatoria.';

  @override
  String get grantHealthConnectPermissionsBeforeSyncing =>
      'Conceda permisos de Health Connect antes de sincronizar.';

  @override
  String get groupByAId => 'GROUP BY a.id\n';

  @override
  String get groupByDay => 'GROUP BY day\n';

  @override
  String get groupByUId => 'GROUP BY u.id\n';

  @override
  String get groupChannelOrRoom => 'Grupo, canal o sala';

  @override
  String get groupType => 'Tipo de grupo';

  @override
  String get groupsAndChannels => 'Grupos y canales';

  @override
  String groupsArg1(Object? arg1) {
    return 'Grupos: $arg1';
  }

  @override
  String groupsArg1HasNotSeenYet(Object? arg1) {
    return 'Los grupos que $arg1 no ha visto todavía seguirán esto.';
  }

  @override
  String get handlesDirectTasksItself => 'Maneja tareas directas por sí mismo.';

  @override
  String get handsFreeTalkFreelyInterruptAnytime =>
      'Manos libres (habla libremente, interrumpe en cualquier momento)';

  @override
  String get headerName => 'Nombre del encabezado';

  @override
  String get headlinesOnTheTopicsYouCare =>
      'Titulares sobre los temas que le interesan, filtrados por señal.';

  @override
  String get health => 'Salud';

  @override
  String get healthChecks => 'Controles de salud';

  @override
  String get healthConnect => 'conexión de salud';

  @override
  String get healthConnectIsNotAvailableOn =>
      'Health Connect no está disponible en este dispositivo.';

  @override
  String get healthConnectSyncStatusAndStored =>
      'Estado de sincronización de Health Connect y métricas de backend almacenadas.';

  @override
  String get healthStatusIsUnavailable =>
      'El estado de salud no está disponible.';

  @override
  String get healthSyncIsAvailableOnAndroid =>
      'La sincronización de salud solo está disponible en Android.';

  @override
  String heartArg1Records(Object? arg1) {
    return 'Registros del corazón $arg1';
  }

  @override
  String get heldBack => 'retenido';

  @override
  String get helper => 'ayudante';

  @override
  String helperArg1(Object? arg1) {
    return 'Ayudante: $arg1';
  }

  @override
  String hereRevokeAdminWithNeoagentAdmin(Object? arg1) {
    return 'aquí. Primero revoque el administrador con `neoagent admin revoque $arg1`.';
  }

  @override
  String get higherValuesMakeNeoagentMoreSelective =>
      'Los valores más altos hacen que NeoAgent sea más selectivo en los grupos.';

  @override
  String get highlyRecommended => 'Altamente recomendado';

  @override
  String get holdButton131ForTheAssistant =>
      'Mantenga pulsado el botón 131 del asistente.';

  @override
  String get holdCtrlShiftSpaceToTalk =>
      'Mantenga Ctrl+Shift+Espacio para hablar';

  @override
  String get holdToTalk => 'Espera para hablar.';

  @override
  String get holdToTalk2 => 'Espera para hablar';

  @override
  String get home => 'Inicio';

  @override
  String get homeAssistantLongLivedAccessToken =>
      'Se requiere el token de acceso de larga duración de Home Assistant.';

  @override
  String get homeAssistantSetup => 'Configuración del asistente doméstico';

  @override
  String get homeAssistantUrl => 'URL del asistente de inicio';

  @override
  String get homeAssistantUrlIsRequired =>
      'Se requiere la URL del Asistente de inicio.';

  @override
  String get homeserverTokenWithRoomPolling =>
      'Token de servidor doméstico con sondeo de sala';

  @override
  String get homeserverUrl => 'URL del servidor doméstico';

  @override
  String get hostedServiceYourKeysAreEncrypted =>
      'servicio alojado). Sus claves están cifradas y solo pueden ser utilizadas por ';

  @override
  String get hostnameOfTheIrcNetworkFor =>
      'Nombre de host de la red IRC, por ejemplo irc.libera.chat';

  @override
  String get hourly => 'Por hora';

  @override
  String get hourlyInboxCheck =>
      'Verificación de la bandeja de entrada cada hora';

  @override
  String get howLongConfirmationLinksStayValid =>
      'Cuánto tiempo permanecen válidos los enlaces de confirmación.';

  @override
  String get howOftenThisAgentLooksFor =>
      'Con qué frecuencia este agente busca nuevos mensajes de sala.';

  @override
  String get howOftenThisAgentLooksFor2 =>
      'Con qué frecuencia este agente busca nuevos mensajes de Signal.';

  @override
  String get howTeamsWork => 'Cómo funcionan los equipos';

  @override
  String get howThisServerIsReachedPlus =>
      'Cómo se llega a este servidor, además de conmutadores en todo el servidor.';

  @override
  String get httpsSessionCookie => 'cookie de sesión https';

  @override
  String get iCouldNotCompleteThatRequest =>
      'No pude completar esa solicitud en este momento. Inténtelo de nuevo en un momento.';

  @override
  String get icStatusIcAccountEmailIc =>
      '       ic.status, ic.account_email, ic.last_connected_at\n';

  @override
  String get idle => 'inactivo';

  @override
  String ifArg1AsksForAWebhook(Object? arg1, Object? arg2) {
    return 'Si $arg1 solicita una URL de webhook, péguela para que los mensajes puedan llegar a $arg2.';
  }

  @override
  String get ifThatAccountHasAConfirmed =>
      'Si esa cuenta tiene un correo electrónico confirmado, NeoAgent enviará un enlace para restablecer la contraseña.';

  @override
  String get ifTheServiceRequiresAToken =>
      'Si el servicio requiere un token en las solicitudes salientes.';

  @override
  String get ignoreGroups => 'Ignorar grupos';

  @override
  String get ignoreThisChat => 'ignorar este chat';

  @override
  String get ignoredChannels => 'Canales ignorados';

  @override
  String ignoredMalformedDesktopCompanionMessageArg1(Object? arg1) {
    return 'Mensaje complementario del escritorio con formato incorrecto ignorado: $arg1';
  }

  @override
  String impArg1(Object? arg1) {
    return 'Diablillo $arg1';
  }

  @override
  String get implementThePlanAbove => 'Implemente el plan anterior.';

  @override
  String get implementThisPlan => 'Implementar este plan';

  @override
  String get implicitTls => 'TLS implícito';

  @override
  String get import => 'Importar';

  @override
  String importFailedArg1(Object? arg1) {
    return 'Error de importación: $arg1';
  }

  @override
  String get importFromComputer => 'Importar desde computadora';

  @override
  String get importMemoryTransfer => '¿Importar transferencia de memoria?';

  @override
  String get importance => 'Importancia';

  @override
  String importedArg1Memories(Object? arg1) {
    return 'Memorias $arg1 importadas, ';
  }

  @override
  String inArg1STeam(Object? arg1) {
    return 'En el equipo de @$arg1';
  }

  @override
  String get inBackground => 'fondo';

  @override
  String get incomingAndOutgoingChannelMessagesWill =>
      'Los mensajes entrantes y salientes del canal aparecerán aquí.';

  @override
  String get incomingInAppVoiceCallsFrom =>
      'Llamadas de voz entrantes desde la aplicación desde NeoAgent';

  @override
  String get incomingMessages => 'Mensajes entrantes';

  @override
  String get incomingNeoagentCall => 'Llamada entrante de NeoAgent';

  @override
  String get incomingNeoagentCall2 => 'LLAMADA ENTRANTE DE NEOAGENTE';

  @override
  String get incomingWebhookAndOutgoingCallbackSupport =>
      'Webhook entrante y soporte de devolución de llamada saliente';

  @override
  String get incorporatingSteering => 'Incorporando dirección';

  @override
  String get input => 'Entrada';

  @override
  String get inputMode => 'Modo de entrada';

  @override
  String get insertATemplate => 'Insertar una plantilla';

  @override
  String get install => 'Instalar';

  @override
  String get installASignedSelfContainedRuntime =>
      'Instale un entorno de ejecución autónomo y firmado. No se requieren comandos de Node.js, npm, Git y terminal.';

  @override
  String get installApk => 'Instalar APK';

  @override
  String get installApkBundle => 'Instalar APK/paquete';

  @override
  String get installApkClickOrDropA =>
      'Instalar APK: haga clic o suelte un archivo .apk';

  @override
  String get installNeoagent => 'Instalar NeoAgent';

  @override
  String get installNeoagentOnThisComputerWithout =>
      'Instale NeoAgent en esta computadora sin una terminal o conéctese a una que ya esté ejecutándose.';

  @override
  String get installNewReleasesAndChooseWhich =>
      'Instale nuevas versiones y elija qué canal sigue este servidor.';

  @override
  String get installTheBackend => 'Instalar el servidor';

  @override
  String get installTheCoreWithExtraOptional =>
      'Instale el núcleo con una configuración opcional adicional. Las claves del proveedor de IA se agregan después, al igual que el inicio rápido.';

  @override
  String get installTheSecureCoreThenCreate =>
      'Instale el núcleo seguro y luego cree su cuenta. Agregue las claves del proveedor de IA después.';

  @override
  String installedArg1(Object? arg1) {
    return ' | Instalado: $arg1';
  }

  @override
  String installedArg1LastCheckedArg2(Object? arg1, Object? arg2) {
    return 'Instalado: $arg1 • Última comprobación: $arg2';
  }

  @override
  String get instructions => 'Instrucciones';

  @override
  String get integration => 'Integración';

  @override
  String get integrationConnections => 'Conexiones de integración';

  @override
  String get integrationSettingsSaved =>
      'Configuración de integración guardada.';

  @override
  String get integrations => 'Integraciones';

  @override
  String get integrationsOauthCallbackAndRegisterThat =>
      'integraciones/oauth/callback, y registre ese mismo ';

  @override
  String get interruptAi => 'Interrumpir la IA';

  @override
  String get invalid2fa => '2fa inválido';

  @override
  String get invalidArgumentS => 'Argumentos no válidos: ';

  @override
  String get invalidCredentials => 'credenciales no válidas';

  @override
  String get invalidNeoagentRuntimeManifest =>
      'Manifiesto de tiempo de ejecución de NeoAgent no válido.';

  @override
  String get inviteLink => 'Enlace de invitación';

  @override
  String get inviteLinkReady => 'Enlace de invitación listo';

  @override
  String get inviteLinks => 'Enlaces de invitación';

  @override
  String get iphoneApp => 'aplicación para iPhone';

  @override
  String get issues => 'Problemas';

  @override
  String get issuesAppearOnceTheLogLoads =>
      'Los problemas aparecen una vez que se carga el registro.';

  @override
  String get itCanTBeUndone => 'No se puede deshacer.';

  @override
  String get itMayHaveBeenDeleted => 'Es posible que haya sido eliminado.';

  @override
  String get javaRuntime => 'tiempo de ejecución de java';

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
    return 'Se unió a $arg1';
  }

  @override
  String get joinedInTheLast7Days => 'Se unió en los últimos 7 días';

  @override
  String get joiningATeam => 'Unirse a un equipo';

  @override
  String get joiningIsOffHere => 'Unirse está cancelado aquí';

  @override
  String get jsonFieldThatContainsTheMessage =>
      'Campo JSON que contiene el texto del mensaje. Generalmente texto.';

  @override
  String get jsonFieldThatIdentifiesWhoThe =>
      'Campo JSON que identifica para quién es el mensaje.';

  @override
  String get jumpToLatest => 'Saltar a lo último';

  @override
  String get justNow => 'justo ahora';

  @override
  String get keepNeoagentRunning => '¿Mantener NeoAgent en funcionamiento?';

  @override
  String get keepRunning => 'sigue corriendo';

  @override
  String get keepTaskRunning => 'Mantener la tarea en ejecución';

  @override
  String get keepTheVaultAvailable => 'Mantenga la bóveda disponible';

  @override
  String get keepThisLauncherUpToDate => 'Mantenga este lanzador actualizado.';

  @override
  String get keepThisPanelOpenUntilThe =>
      'Mantén este panel abierto hasta que la plataforma confirme la conexión.';

  @override
  String get keepThisSessionSComputerVisible =>
      'Mantener visible la computadora de esta sesión';

  @override
  String get keepTrackOfYourAiUsage =>
      'Realice un seguimiento de su uso de IA. Se aplican límites para garantizar un uso justo en toda la plataforma.';

  @override
  String get keepUsingYourAppsNormallyNeoagent =>
      'Sigue usando tus aplicaciones normalmente. NeoAgent funciona en la misma pantalla y pregunta cada vez que necesita un nuevo acceso.\n\n';

  @override
  String get keepingThisDeviceConnected =>
      'Mantener este dispositivo conectado';

  @override
  String get key => 'clave';

  @override
  String get keyIsRequired => 'Se requiere clave.';

  @override
  String get keyValuePairsThatPersistAcross =>
      'Pares clave-valor que persisten en las conversaciones.';

  @override
  String get knowledgeGraph => 'Gráfico de conocimiento';

  @override
  String get knowledgeView => 'Vista de conocimiento';

  @override
  String get labelOnlyYouSeeIt => 'Etiqueta (sólo tú la ves)';

  @override
  String get labelsOptional => 'Etiquetas (opcional)';

  @override
  String get last24Hours => 'Últimas 24 horas';

  @override
  String get last7Days => 'últimos 7 días';

  @override
  String last7DaysArg1TokensIn(Object? arg1, Object? arg2) {
    return 'Últimos 7 días: tokens $arg1 en ejecuciones $arg2';
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
    return 'Última sincronización no vacía · $arg1';
  }

  @override
  String lastRunArg1(Object? arg1) {
    return 'Última ejecución: $arg1';
  }

  @override
  String lastSeenArg1(Object? arg1) {
    return 'Visto por última vez $arg1';
  }

  @override
  String lastSignInArg1(Object? arg1) {
    return 'Último inicio de sesión $arg1';
  }

  @override
  String get lastSyncSummary => 'Resumen de la última sincronización';

  @override
  String lastUsedArg1(Object? arg1) {
    return 'Último uso: $arg1';
  }

  @override
  String lastWindowEndedArg1(Object? arg1) {
    return 'Última ventana finalizada $arg1';
  }

  @override
  String get laterStartSwitchedOffToo =>
      'Después también se apaga el arranque.';

  @override
  String latestRunArg1(Object? arg1) {
    return 'Última ejecución · $arg1';
  }

  @override
  String get launchingDesktopAppsIsNotSupported =>
      'Esta plataforma no admite el inicio de aplicaciones de escritorio.';

  @override
  String get learnRoomNorms => 'Aprende las normas de la habitación';

  @override
  String get leave => 'salir';

  @override
  String get leaveARedirectUriBlankTo =>
      'Deje un URI de redireccionamiento en blanco para usar <URL pública>/api/';

  @override
  String leaveArg1STeam(Object? arg1) {
    return '¿Dejar el equipo de $arg1?';
  }

  @override
  String get leaveAsTheDefaultUnlessYou =>
      'Déjelo como predeterminado a menos que haya personalizado BlueBubbles.';

  @override
  String get leaveTheTokenEmptyToKeep =>
      'Deje el token vacío para conservar el token almacenado actualmente.';

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
    return 'Deja que $arg1 me administre';
  }

  @override
  String letEveryoneInThisGroupTalk(Object? arg1) {
    return 'Deje que todos los miembros de este grupo hablen con $arg1.';
  }

  @override
  String get letItWorkWhileYouDon =>
      'Déjalo funcionar\nmientras tú no lo hagas.';

  @override
  String get letNeoagentClickTypeAndMove =>
      'Deje que NeoAgent haga clic, escriba y se mueva por sus aplicaciones.';

  @override
  String get letNeoagentUnderstandWhatIsVisible =>
      'Deje que NeoAgent comprenda lo que se ve en su pantalla.';

  @override
  String get letSomeoneYouWorkWithDecide =>
      'Deje que alguien con quien trabaje decida qué herramientas puede utilizar su agente. ';

  @override
  String letThisPersonSendArg1A(Object? arg1) {
    return 'Deje que esta persona envíe a $arg1 un mensaje individual.';
  }

  @override
  String letThisPersonTalkToArg1(Object? arg1) {
    return 'Deja que esta persona hable con $arg1 aquí, pero no en chats privados ni en otros grupos.';
  }

  @override
  String letThisPersonTalkToArg12(Object? arg1) {
    return 'Deja que esta persona hable con $arg1 en chats privados y en cualquier grupo que comparta.';
  }

  @override
  String levelArg1Arg2Arg3(Object? arg1, Object? arg2, Object? arg3) {
    return 'Nivel $arg1/$arg2$arg3';
  }

  @override
  String get limit20 => 'LIMIT 20';

  @override
  String get limit50 => 'LIMIT 50';

  @override
  String linkArg1(Object? arg1) {
    return 'Enlace $arg1';
  }

  @override
  String get linkCopied => 'Enlace copiado';

  @override
  String get linkExpiresAfter => 'El enlace caduca después';

  @override
  String get linkLifetimeHours => 'Vida útil del enlace (horas)';

  @override
  String get linkLifetimeMustBeFrom1 =>
      'La vida útil del enlace debe ser de 1 a 8760 horas.';

  @override
  String linkValidUntilArg1(Object? arg1) {
    return 'Enlace válido hasta $arg1.';
  }

  @override
  String get linkedSignInProviders =>
      'Proveedores de inicio de sesión vinculados';

  @override
  String get linuxApp => 'aplicación de linux';

  @override
  String listedArg1(Object? arg1) {
    return 'Listado $arg1/';
  }

  @override
  String get listening => 'escuchando';

  @override
  String get liveExecutionHistoryToolStepsAnd =>
      'Historial de ejecución en vivo, pasos de herramientas y respuestas.';

  @override
  String get liveModel => 'modelo en vivo';

  @override
  String get liveModelProvider => 'Proveedor de modelos en vivo';

  @override
  String get liveRun => 'carrera en vivo';

  @override
  String get liveVoice => 'voz en vivo';

  @override
  String get liveVoiceConnectionIsNotAvailable =>
      'La conexión de voz en vivo no está disponible.';

  @override
  String get liveVoiceConnectionWasClosed =>
      'Se cerró la conexión de voz en vivo.';

  @override
  String get liveVoiceDefaults => 'Valores predeterminados de voz en vivo';

  @override
  String get liveVoiceFailed => 'La voz en vivo falló.';

  @override
  String get llmMemoryExportResponse =>
      'Respuesta de exportación de memoria LLM';

  @override
  String get loadFailed => 'la carga falló';

  @override
  String get loadingExecutionDetails => 'Cargando detalles de ejecución...';

  @override
  String get loadingNeoagent => 'Cargando NeoAgent';

  @override
  String get loadingRunFlow => 'Cargando flujo de ejecución...';

  @override
  String get localAndPrivateNetworkUrlsAre =>
      'Se admiten URL de red local y privada cuando el servidor NeoAgent puede acceder a ellas. El audio nunca está expuesto a NeoAgent.';

  @override
  String get localApp => 'aplicación local';

  @override
  String get localBackendInstallationIsNotAvailable =>
      'La instalación de backend local no está disponible en esta plataforma.';

  @override
  String get localBaseImagePath => 'Ruta de la imagen base local';

  @override
  String get localComputerControlIsAvailableIn =>
      'El control de la computadora local está disponible en la aplicación de escritorio NeoAgent en macOS, Windows y Linux.';

  @override
  String get localComputerControlIsNotAvailable =>
      'El control por computadora local no está disponible aquí.';

  @override
  String get localModelsUrl => 'URL de modelos locales';

  @override
  String get localNeoagentDiscoveryIsTemporarilyUnavailable =>
      'El descubrimiento local de NeoAgent no está disponible temporalmente.';

  @override
  String get localPreferencesForTheNeoagentApplication =>
      'Preferencias locales para la aplicación NeoAgent. El control informático siempre se ejecuta a través de la computadora en la nube unificada.';

  @override
  String get localSetup => 'CONFIGURACIÓN LOCAL';

  @override
  String get locationCityOrPlace => 'Ubicación (ciudad o lugar)';

  @override
  String get locationIsRequiredForWeatherEvent =>
      'Se requiere ubicación para desencadenantes de eventos climáticos';

  @override
  String locationserviceInitializationFailedArg1(Object? arg1) {
    return 'La inicialización de LocationService falló: $arg1';
  }

  @override
  String get logCopied => 'Registro copiado';

  @override
  String get loginPassword => 'Contraseña de inicio de sesión';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get logs => 'Registros';

  @override
  String get logsCopied => 'Registros copiados.';

  @override
  String get logsOnThisComputer => 'Inicia sesión en esta computadora';

  @override
  String get longLivedAccessToken => 'Token de acceso de larga duración';

  @override
  String get longTermRecallStructuredFactsAnd =>
      'Recuerdo a largo plazo, hechos estructurados y gráfico de conocimiento.';

  @override
  String get lookedAtTheScreen => 'Miró la pantalla';

  @override
  String get lookingOnThisComputerAndYour =>
      'Mirando esta computadora y su red local...';

  @override
  String get looksAheadAtTomorrowSMeetings =>
      'Mira hacia adelante a las reuniones de mañana para que nada te sorprenda.';

  @override
  String get loopExecution => 'Ejecución de bucle';

  @override
  String get loopPaused => 'Bucle en pausa';

  @override
  String get macOsX => 'mac os x';

  @override
  String get macosAccessibilityIsNotGrantedTo =>
      'La accesibilidad de macOS no se otorga a NeoAgent. Permitirlo en Configuración del sistema> Privacidad y seguridad> Accesibilidad.';

  @override
  String get macosApp => 'aplicación macos';

  @override
  String get macosScreenRecordingIsNotGranted =>
      'La grabación de pantalla de macOS no se otorga a NeoAgent. Permítalo en Configuración del sistema> Privacidad y seguridad> Grabación de pantalla, luego vuelva a abrir NeoAgent.';

  @override
  String get mailServersThatNeedAPassword =>
      'Los servidores de correo que necesitan una contraseña se negarán a enviar hasta una nueva ';

  @override
  String get main => 'principal';

  @override
  String get makeDefault => 'Hacer predeterminado';

  @override
  String get manage => 'Administrar';

  @override
  String get manageYourAccountEmailTwoFactor =>
      'Administre el correo electrónico de su cuenta, la autenticación de dos factores y las sesiones activas.';

  @override
  String get managedBy => 'Gestionado por';

  @override
  String get managerUsernameAsManagedBy =>
      '       manager.username AS managed_by,\n';

  @override
  String get managersCanHaveManagersOfTheir =>
      'Los gerentes pueden tener gerentes propios (hasta cuatro niveles). un ';

  @override
  String get managing => 'Gestionando';

  @override
  String get manualDestination => 'Destino manual';

  @override
  String get manualTrigger => 'Disparador manual';

  @override
  String get masterPassword => 'Contraseña maestra';

  @override
  String get matchThisDevice => 'Coincidir con este dispositivo';

  @override
  String get matchedAgainstTitleAndBody =>
      'Comparado con el título y el cuerpo';

  @override
  String get matchesTheOldNeoagentMcpFlow =>
      'Coincide con el antiguo flujo de NeoAgent MCP: URL más método de autenticación.';

  @override
  String get mcp => 'MCP';

  @override
  String get mcpServer => 'servidor MCP';

  @override
  String get mcpServer2 => 'Servidor MCP';

  @override
  String get mcpServerUrl => 'URL del servidor MCP';

  @override
  String get mcpServers => 'Servidores MCP';

  @override
  String get meantForSomeoneElse => 'destinado a otra persona';

  @override
  String measuredModelCostArg1(Object? arg1) {
    return 'Costo del modelo medido: $arg1';
  }

  @override
  String get memories => 'Recuerdos';

  @override
  String get memory => 'Memoria';

  @override
  String memoryArg1(Object? arg1) {
    return 'Memoria: $arg1';
  }

  @override
  String get memoryInjected => 'Memoria inyectada';

  @override
  String get mentionOrReplyOnly => 'Mencionar o responder solo';

  @override
  String get mergedServerAndFlutterRuntimeLogs =>
      'Registros combinados del servidor y del tiempo de ejecución de Flutter para esta sesión de aplicación.';

  @override
  String get messageBodyTemplateJson =>
      'Plantilla de cuerpo del mensaje (JSON)';

  @override
  String get messageNeedsAccess => 'El mensaje necesita acceso';

  @override
  String get messageTextField => 'Campo de texto del mensaje';

  @override
  String get messaging => 'Mensajería';

  @override
  String get messagingApiPushAndWebhookEvents =>
      'Eventos de webhook y push de API de mensajería';

  @override
  String get messagingConnectionNeedsAttention =>
      'La conexión de mensajería necesita atención';

  @override
  String get messagingConnections => 'Conexiones de mensajería';

  @override
  String get messagingDelivery => 'Entrega de mensajes';

  @override
  String get messagingErrorPleaseTryAgain =>
      'Error de mensajería. Por favor inténtalo de nuevo.';

  @override
  String get microphoneCaptureStoppedUnexpectedlyTryAgain =>
      'La captura del micrófono se detuvo inesperadamente. Intentar otra vez.';

  @override
  String microphoneErrorArg1(Object? arg1) {
    return 'Error de micrófono: $arg1';
  }

  @override
  String get microphoneMutedTapToUnmute =>
      'Micrófono silenciado. Toca para activar el sonido.';

  @override
  String get microphonePermissionIsRequiredForLive =>
      'Se requiere permiso del micrófono para voz en vivo.';

  @override
  String get microsoft365 => 'microsoft 365';

  @override
  String get microsoftTeams => 'Equipos de Microsoft';

  @override
  String minimumContributionValueArg1(Object? arg1) {
    return 'Valor mínimo de contribución: $arg1';
  }

  @override
  String mobileSetupFailedArg1(Object? arg1) {
    return 'La configuración móvil falló.\n\n$arg1';
  }

  @override
  String mobileSetupFailedBecauseJavaIs(Object? arg1) {
    return 'La configuración móvil falló porque Java no está disponible en la máquina que ejecuta NeoAgent.\n\n$arg1';
  }

  @override
  String get mobileSetupFailedBecauseJavaIs2 =>
      'La configuración móvil falló porque Java no está disponible en la máquina que ejecuta NeoAgent. Instale un JDK y vuelva a intentarlo.';

  @override
  String get mobileSetupFailedCheckThatAndroid =>
      'La configuración móvil falló. Verifique que las herramientas de Android estén instaladas correctamente y vuelva a intentarlo.';

  @override
  String modeArg1(Object? arg1) {
    return 'modo: $arg1';
  }

  @override
  String get modeLocksWhileARunIs =>
      'El modo se bloquea mientras una ejecución está activa.';

  @override
  String get model => 'modelo';

  @override
  String modelArg1(Object? arg1) {
    return 'Modelo: $arg1';
  }

  @override
  String get modelAvailability => 'Disponibilidad del modelo';

  @override
  String get modelAvailabilitySaved => 'Disponibilidad del modelo guardada.';

  @override
  String get modelForThisSession => 'Modelo para esta sesión';

  @override
  String get modelOverride => 'Anulación de modelo';

  @override
  String get modelPending => 'Modelo pendiente';

  @override
  String get modelTurn => 'Giro de modelo';

  @override
  String get modelTurnCompleted => 'Turno de modelo completado';

  @override
  String get modelTurnStarted => 'Turno de modelo iniciado';

  @override
  String get modelVisibilityHideShowList =>
      'visibilidad del modelo ocultar mostrar lista';

  @override
  String get models => 'Modelos';

  @override
  String get modelsBehaviorVoiceAndWorkspace =>
      'Modelos, comportamiento, voz y espacio de trabajo.';

  @override
  String get modelsBrowserVoiceDiagnostics =>
      'Modelos, navegador, voz, diagnóstico...';

  @override
  String get modelsRouting => 'Modelos y rutas';

  @override
  String get monthly => 'Mensual';

  @override
  String get moreActions => 'Más acciones';

  @override
  String get morningBriefing => 'Sesión informativa matutina';

  @override
  String get mostUsedAgents => 'Agentes más utilizados';

  @override
  String mostUsedModelsInTheLast(Object? arg1) {
    return 'Modelos más utilizados en la última $arg1.';
  }

  @override
  String get mouseKeyboard => 'Ratón y teclado';

  @override
  String get mousemoveIsNotSupportedOnThis =>
      'mouseMove no es compatible con esta plataforma.';

  @override
  String get mustBeReachableOnThePublic =>
      'Debe ser accesible a través de la Internet pública (local y ';

  @override
  String get n24Hours => '24 horas';

  @override
  String get n2faOrRecoveryCode => '2FA o código de recuperación';

  @override
  String get n2faRequiresSessionSecretToBe =>
      '2FA requiere que SESSION_SECRET esté configurado en esta implementación de NeoAgent.';

  @override
  String get n30Days => '30 dias';

  @override
  String get n365Days => '365 días';

  @override
  String get n4HourLimitTokens => 'Límite de 4 horas (tokens)';

  @override
  String get n4HourUsage => 'uso de 4 horas';

  @override
  String n4hLimitArg1(Object? arg1) {
    return 'Límite de 4 horas $arg1';
  }

  @override
  String get n7DayUsage => 'uso de 7 días';

  @override
  String get n7Days => '7 dias';

  @override
  String get n90Days => '90 dias';

  @override
  String get name => 'Nombre';

  @override
  String get nameNewSkillDescriptionDescribeWhat =>
      '---\nnombre: Nueva habilidad\ndescripción: Describe lo que hace esta habilidad\n---\nEscribe las instrucciones para esta habilidad aquí.\n';

  @override
  String get nameOfWhoeverMadeIt => 'nombre de quien lo hizo.';

  @override
  String get nameOptional => 'Nombre (opcional)';

  @override
  String get nativeAndWebhookChannels => 'Canales nativos y webhooks';

  @override
  String get naturalBubbles => 'Burbujas naturales';

  @override
  String get nearbyNeoagentServers => 'Servidores NeoAgent cercanos';

  @override
  String get needANewAccountRegister =>
      '¿Necesita una nueva cuenta? Regístrate';

  @override
  String get needAnIdea => '¿Necesitas una idea?';

  @override
  String needToReplyArg1ToSpeak(Object? arg1) {
    return 'Necesito responder · $arg1% para hablar';
  }

  @override
  String get needsAttention => 'necesita atencion';

  @override
  String get needsInput => 'Necesita información';

  @override
  String get neoagentApp => 'Aplicación NeoAgent';

  @override
  String neoagentArg1(Object? arg1) {
    return 'NeoAgente, $arg1';
  }

  @override
  String get neoagentAssistant => 'Asistente NeoAgente';

  @override
  String get neoagentCouldNotCheckTheAvailable =>
      'NeoAgent no pudo comprobar el tiempo de ejecución del backend disponible.';

  @override
  String get neoagentCouldNotFinishTheLocal =>
      'NeoAgent no pudo finalizar la configuración local.';

  @override
  String neoagentCouldNotFinishTheLocal2(Object? arg1) {
    return 'NeoAgent no pudo finalizar la configuración local. $arg1';
  }

  @override
  String get neoagentDebugInfo => 'Información de depuración de NeoAgent';

  @override
  String get neoagentDesktopInstaller => 'Instalador de escritorio NeoAgent';

  @override
  String get neoagentFlutterUpdater => 'Actualizador de aleteo de NeoAgent';

  @override
  String neoagentInstallsTheLatestArg1(Object? arg1) {
    return 'NeoAgent instala el último $arg1 ';
  }

  @override
  String get neoagentIsInstalledAndRunning =>
      'NeoAgent está instalado y ejecutándose.';

  @override
  String get neoagentIsNotInstalledOnThis =>
      'NeoAgent no está instalado en esta computadora.';

  @override
  String get neoagentIsReady => 'NeoAgent está listo';

  @override
  String get neoagentIsStillWorkingOnA =>
      'NeoAgent todavía está trabajando en una tarea. Finaliza la llamada y obtén el resultado en el chat, o cancela la tarea también.';

  @override
  String get neoagentIsTurningYourDemonstrationInto =>
      'NeoAgent está convirtiendo su demostración en un flujo de trabajo adaptable.';

  @override
  String get neoagentIsWaitingWhileYouUse =>
      'NeoAgent está esperando mientras usas el escritorio.';

  @override
  String get neoagentIsWorking => 'NeoAgent está funcionando';

  @override
  String get neoagentLinuxComputer => 'Computadora NeoAgent Linux';

  @override
  String get neoagentNeedsADecision => 'NEOAGENT NECESITA UNA DECISIÓN';

  @override
  String get neoagentNoReplyExampleCom => 'NeoAgente <no-reply@example.com>';

  @override
  String get neoagentRuntimeDownloadsRequireASecure =>
      'Las descargas del tiempo de ejecución de NeoAgent requieren una dirección segura.';

  @override
  String get neoagentServerAddress => 'Dirección del servidor NeoAgent';

  @override
  String get neoagentServiceEmailIsNotReady =>
      'El correo electrónico del servicio NeoAgent no está listo. Pídale al operador del servidor que verifique la configuración del entorno de correo electrónico.';

  @override
  String get neoagentSetupCouldNotFinish =>
      'La configuración de NeoAgent no pudo finalizar.';

  @override
  String get neoagentUser => 'Usuario NeoAgent';

  @override
  String get neoagentUsesThisComputerAutomaticallyAnd =>
      'NeoAgent usa esta computadora automáticamente y pregunta antes de usar su pantalla, mouse, teclado, archivos o línea de comando.';

  @override
  String get neoagentUsesYourApproximateBackgroundLocation =>
      'NeoAgent utiliza su ubicación de fondo aproximada para activar recordatorios de geocerca (por ejemplo, \"Recuérdame comprar leche cuando pase por el supermercado\").\n\n';

  @override
  String get neoagentWorkspace => 'Espacio de trabajo de NeoAgent';

  @override
  String neodiagArg1Arg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1] $arg2';
  }

  @override
  String neodiagArg1StackArg2(Object? arg1, Object? arg2) {
    return '[NeoDiag][$arg1][pila] $arg2';
  }

  @override
  String get neorecallBackendUrl => 'URL de fondo de NeoRecall';

  @override
  String get neorecallBackendUrlIsRequired =>
      'Se requiere la URL del backend de NeoRecall.';

  @override
  String get neorecallSetup => 'Configuración de NeoRecall';

  @override
  String get networkRequestFailed => 'solicitud de red fallida';

  @override
  String get networkWriteRequests => 'Solicitudes de escritura de red';

  @override
  String get neverCountsAgainstTheSharedUsage =>
      'nunca cuenta contra los límites de uso compartido.';

  @override
  String get newAccountsConfirmTheirEmailAddress =>
      'Las cuentas nuevas confirman su dirección de correo electrónico antes de iniciar sesión.';

  @override
  String get newAccountsPerDay => 'Nuevas cuentas por día';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String newGroupsStayQuietUnlessSomeone(Object? arg1) {
    return 'Los grupos nuevos permanecen en silencio a menos que alguien etiquete a $arg1, hasta que los actives.';
  }

  @override
  String get newLink => 'Nuevo enlace';

  @override
  String get newPasswordsDoNotMatch => 'Las nuevas contraseñas no coinciden.';

  @override
  String get newRecoveryCodes => 'Nuevos códigos de recuperación';

  @override
  String get newSession => 'Nueva sesión';

  @override
  String get newSessionN => 'Nueva sesión (⌘N)';

  @override
  String get newSessionWithSameSetup =>
      'Nueva sesión con la misma configuración';

  @override
  String get newSkill => 'Nueva habilidad';

  @override
  String get newSkill2 => 'Nueva habilidad';

  @override
  String get newThisWeek => 'Nuevo esta semana';

  @override
  String get newsDigest => 'Resumen de noticias';

  @override
  String nextRetryArg1(Object? arg1) {
    return 'Siguiente reintento: $arg1';
  }

  @override
  String get nextcloudLoginFlow => 'Flujo de inicio de sesión de Nextcloud';

  @override
  String get nextcloudSetup => 'Configuración de NextCloud';

  @override
  String get nextcloudTalk => 'Charla sobre NextCloud';

  @override
  String get nextcloudUrl => 'URL de la nube siguiente';

  @override
  String get nextcloudUrlIsRequired => 'Se requiere la URL de Nextcloud.';

  @override
  String get nickname => 'Apodo';

  @override
  String get noAccountsConnectedYet => 'Aún no hay cuentas conectadas.';

  @override
  String get noAccountsFound => 'No se encontraron cuentas.';

  @override
  String get noActiveSessionsFound => 'No se encontraron sesiones activas.';

  @override
  String get noAgentsYet => 'Aún no hay agentes';

  @override
  String get noAiProviderIsConfiguredSo =>
      'No hay ningún proveedor de IA configurado, por lo que el chat y la mensajería ';

  @override
  String get noApprovalPromptsAgentRunsWithout =>
      'Sin solicitudes de aprobación: el agente se ejecuta sin interrupciones.';

  @override
  String noArg1ReleaseAssetMatchedThis(Object? arg1) {
    return 'Ningún recurso de versión $arg1 coincidió con esta plataforma.';
  }

  @override
  String get noArguments => '(sin argumentos)';

  @override
  String get noAuth => 'Sin autenticación';

  @override
  String get noBindingsYet => 'Aún no hay ataduras.';

  @override
  String get noChangesYet => 'Aún no hay cambios';

  @override
  String get noChannelsFound => 'No se encontraron canales';

  @override
  String get noCloudComputerSlotIsFree =>
      'Ninguna ranura para computadora en la nube está gratuita en este momento. Inténtalo de nuevo en un momento.';

  @override
  String get noCoreMemoryEntriesYet =>
      'Aún no hay entradas de memoria central.';

  @override
  String get noDescription => 'Sin descripción';

  @override
  String get noDesktopDisplaysAreCurrentlyAvailable =>
      'Actualmente no hay pantallas de escritorio disponibles.';

  @override
  String get noDetailAvailable => 'No hay detalles disponibles';

  @override
  String get noDetailedSyncSummaryYet =>
      'Aún no hay un resumen detallado de la sincronización.';

  @override
  String get noDetailsCaptured => 'No se capturaron detalles.';

  @override
  String get noEmailLinked => 'No hay ningún correo electrónico vinculado';

  @override
  String get noExternalSignInProvidersLinked =>
      'No hay proveedores de inicio de sesión externos vinculados.';

  @override
  String get noGroupMessagesYet => 'Aún no hay mensajes grupales';

  @override
  String get noGroupSpecificPeopleAddedYet =>
      'Aún no se han agregado personas específicas del grupo.';

  @override
  String get noGroupsAddedYet => 'Aún no se han agregado grupos.';

  @override
  String noGroupsFoundYetAfterArg1(Object? arg1) {
    return 'Aún no se han encontrado grupos. Después de que $arg1 vea un mensaje grupal, use Buscar chats recientes y aparecerán aquí.';
  }

  @override
  String noGroupsFoundYetAfterArg12(Object? arg1) {
    return 'Aún no se han encontrado grupos. Después de que $arg1 vea un mensaje grupal, use Buscar chats recientes.';
  }

  @override
  String get noHealthDataPayloadReturned =>
      'No se devolvió ninguna carga útil de datos de salud.';

  @override
  String get noHealthSamplesStoredYet =>
      'Aún no se han almacenado muestras de salud.';

  @override
  String get noHttpClientImplementationForThis =>
      'No hay implementación de cliente HTTP para esta plataforma.';

  @override
  String get noInputOrOutputWasRecorded =>
      'No se registró ninguna entrada o salida para este paso.';

  @override
  String get noIntegrationsMatchThisSearch =>
      'No hay integraciones que coincidan con esta búsqueda.';

  @override
  String get noLimit => 'Sin límite';

  @override
  String get noLocalPasswordIsSetYet =>
      'Aún no se ha establecido ninguna contraseña local. Cree uno para habilitar el inicio de sesión con nombre de usuario/contraseña.';

  @override
  String get noLogEntries => 'Sin entradas de registro.';

  @override
  String get noMatchingSettings => 'No hay configuraciones coincidentes';

  @override
  String get noMcpServersMatchThisSearch =>
      'Ningún servidor MCP coincide con esta búsqueda.';

  @override
  String get noMemoryEntriesFound => 'No se encontraron entradas de memoria.';

  @override
  String get noMemorySync => 'Sin sincronización de memoria';

  @override
  String get importPastEmailsIntoMemoryHint =>
      'Lee una vez el correo importante y enviado de los últimos 12 meses para que el agente conozca tus contactos y proyectos.';

  @override
  String get emailMemory => 'Memoria de correo';

  @override
  String get importNow => 'Importar ahora';

  @override
  String get importOnConnect =>
      'Importar correo anterior al conectar una cuenta';

  @override
  String get sweepStarting => 'Preparando…';

  @override
  String sweepReadingProgress(int done, int total) {
    return 'Leyendo correos · $done de $total';
  }

  @override
  String sweepReadingFound(int count) {
    return 'Leyendo correos · $count encontrados';
  }

  @override
  String sweepLearningProgress(int done, int total) {
    return 'Aprendiendo de los correos · $done de $total';
  }

  @override
  String sweepLastImport(int emails, int memories) {
    return 'Última importación: $emails correos · $memories recuerdos nuevos';
  }

  @override
  String get sweepNothingNew => 'No hay correos nuevos para importar';

  @override
  String sweepFailed(String error) {
    return 'La importación falló: $error';
  }

  @override
  String noModelMatchesArg1(Object? arg1) {
    return 'Ningún modelo coincide con \"$arg1\".';
  }

  @override
  String get noModelRequestWasRecordedFor =>
      'No se registró ninguna solicitud de modelo para esta ejecución.';

  @override
  String get noModelsDiscoveredYet => 'Aún no se han descubierto modelos';

  @override
  String get noModelsSelected => 'No hay modelos seleccionados';

  @override
  String get noModelsYet => 'Aún no hay modelos';

  @override
  String get noNeoagentAccountIsLinkedTo =>
      'no hay ninguna cuenta de neoagent vinculada a este proveedor';

  @override
  String get noNeoagentBackendRuntimeIsAvailable =>
      'No hay ningún tiempo de ejecución de backend de NeoAgent disponible para esta computadora.';

  @override
  String get noNetworkConnection => 'Sin conexión de red';

  @override
  String get noNetworkConnectionConnectToKeep =>
      'Sin conexión de red. Conéctese para seguir usando NeoAgent.';

  @override
  String get noNetworkConnectionReconnectToCheck =>
      'Sin conexión de red. Vuelva a conectarse para buscar actualizaciones.';

  @override
  String get noOne => 'nadie';

  @override
  String get noOneAddedYet => 'Nadie agregó todavía.';

  @override
  String get noOneCanMessage => 'nadie puede enviar mensajes';

  @override
  String get noOtherNeoagentServerWasFound =>
      'No se encontró ningún otro servidor NeoAgent. Puede buscar nuevamente o ingresar una dirección manualmente.';

  @override
  String get noPeopleAddedYet => 'Aún no se ha añadido gente.';

  @override
  String get noPlatformsMatch => 'Ninguna plataforma coincide';

  @override
  String get noProvidersAreAvailableToConfigure =>
      'Aún no hay proveedores disponibles para configurar.';

  @override
  String get noRecentChannelActivity => 'No hay actividad reciente en el canal';

  @override
  String noResultsForArg1(Object? arg1) {
    return 'No hay resultados para \"$arg1\"';
  }

  @override
  String get noRunsInThisRange => 'No hay carreras en este rango.';

  @override
  String get noRunsMatchTheseFilters =>
      'Ninguna carrera coincide con estos filtros';

  @override
  String get noRunsYet => 'Aún no hay carreras';

  @override
  String get noRunsYet2 => 'Aún no hay carreras.';

  @override
  String get noSecurityKeyWasProvided =>
      'No se proporcionó ninguna clave de seguridad.';

  @override
  String get noServerUrlSet => 'No se ha establecido ninguna URL del servidor';

  @override
  String get noSessionMatchesThatSearch =>
      'Ninguna sesión coincide con esa búsqueda.';

  @override
  String get noSessionsYet => 'Aún no hay sesiones';

  @override
  String get noSkillsMatchTheseFilters =>
      'Ninguna habilidad coincide con estos filtros.';

  @override
  String get noStepsWereRecordedForThis =>
      'No se registraron pasos para esta ejecución.';

  @override
  String get noSummaryAvailable => 'No hay resumen disponible.';

  @override
  String noTasksForArg1(Object? arg1) {
    return 'No hay tareas para $arg1';
  }

  @override
  String noToolMatchesArg1(Object? arg1) {
    return 'Ninguna herramienta coincide con \"$arg1\".';
  }

  @override
  String get noUpdateRunning => 'No se está ejecutando ninguna actualización';

  @override
  String get noUsageYet => 'Aún no se ha usado.';

  @override
  String get noVerifiedNeoagentBackendRuntimeIs =>
      'Aún no hay disponible ningún tiempo de ejecución de backend de NeoAgent verificado.';

  @override
  String get nobodyCanUseItAnyMore =>
      'Ya nadie puede usarlo. Personas que ya se unieron ';

  @override
  String get none => 'Ninguno';

  @override
  String get notApprovedYet => 'aún no aprobado';

  @override
  String get notAuthenticated => 'no autenticado';

  @override
  String get notCheckedYet => 'Aún no comprobado';

  @override
  String get notConfigured => 'No configurado';

  @override
  String get notConnected => 'No conectado';

  @override
  String get notConnected2 => 'No conectado';

  @override
  String get notInstalled => 'No instalado';

  @override
  String get notNeeded => 'No es necesario';

  @override
  String get notNeededEnough => 'No es lo suficientemente necesario';

  @override
  String get notNow => 'Ahora no';

  @override
  String get notNow2 => 'Ahora no';

  @override
  String get notSet => 'No establecido';

  @override
  String get notSetUp => 'No configurado';

  @override
  String get notTheSameAsAdmin => 'No es lo mismo que administrador';

  @override
  String get nothingFound => 'No se encontró nada';

  @override
  String get nothingHereYet => 'Nada aquí todavía.';

  @override
  String get nothingHereYet2 => 'Nada aquí todavía';

  @override
  String get nothingMatches => 'Nada coincide';

  @override
  String get nothingStoredYet => 'No hay nada almacenado todavía.';

  @override
  String get notionSlackFigmaGithubSpotifyTrello =>
      'Noción, Slack, Figma, GitHub, Spotify, Trello';

  @override
  String get nvidiaNim => 'NIM de NVIDIA';

  @override
  String get oauthClientId => 'ID de cliente de OAuth';

  @override
  String get oauthClientIdSecretRedirectApi =>
      'clave de API de redirección secreta de identificación de cliente de oauth';

  @override
  String get oauthClientIdSecretRedirectGmail =>
      'ID de cliente oauth redirección secreta unidad de calendario de Gmail';

  @override
  String get oauthLaunchIsNotSupportedOn =>
      'El lanzamiento de OAuth no es compatible con esta plataforma.';

  @override
  String get oauthOutlookTenantClientIdSecret =>
      'Secreto de identificación del cliente del inquilino de Outlook de OAuth';

  @override
  String get oauthToken => 'token de OAuth';

  @override
  String get oauthWithPkce => 'OAuth con PKCE';

  @override
  String ofArg1(Object? arg1) {
    return 'de $arg1';
  }

  @override
  String get ofItsOwnItIsNever =>
      'propio. Nunca se vuelve a mostrar después de guardar.';

  @override
  String get off => 'Desactivado';

  @override
  String get officialIntegration => 'Integración oficial';

  @override
  String get officialIntegrationDidNotReturnA =>
      'La integración oficial no devolvió una URL de conexión.';

  @override
  String get on => 'Activado';

  @override
  String get onASignedInAndroidDevice =>
      'En un dispositivo Android en el que haya iniciado sesión, abra Configuración › Inicio de sesión y seguridad, escanee este código y apruebe el inicio de sesión.';

  @override
  String get onByDefaultForNewGroups =>
      'Activado de forma predeterminada para grupos nuevos';

  @override
  String get onDemand => 'Bajo demanda';

  @override
  String onForArg1OfArg2Groups(Object? arg1, Object? arg2) {
    return 'Activado para $arg1 de grupos $arg2';
  }

  @override
  String get onTheyCanJoinAgainOnly =>
      'encendido. Pueden volver a unirse solo con un nuevo enlace de invitación.';

  @override
  String get onYourOwnTheDefault => 'Por tu cuenta (el valor predeterminado)';

  @override
  String get once => 'una vez';

  @override
  String get oneIsSavedOtherChangesIn =>
      'uno se salva. Otros cambios en este formulario también se guardan.';

  @override
  String get oneOrMoreAccountsExpiredReconnect =>
      'Una o más cuentas expiraron. Vuelva a conectar la cuenta afectada para restaurar el acceso a la herramienta.';

  @override
  String get oneRuntimeControlsPersonaGroupTurn =>
      'Un tiempo de ejecución controla la personalidad, los turnos de grupo, la memoria de la sala, las normas, la teoría de la mente y la entrega.';

  @override
  String get oneTimeRun => 'Ejecución única';

  @override
  String get onlyApkOrApksFilesCan =>
      'Sólo se pueden instalar archivos .apk o .apks.';

  @override
  String get onlyInThisGroup => 'Sólo en este grupo';

  @override
  String get onlyNeededIfTheServiceAsks =>
      'Solo es necesario si el servicio solicita encabezados HTTP adicionales.';

  @override
  String get onlyNeededIfYouWantTo =>
      'Solo es necesario si desea remodelar la carga útil saliente.';

  @override
  String get onlyTheyCanChangeIt => 'Sólo ellos pueden cambiarlo.';

  @override
  String get open => 'Abrir';

  @override
  String get openAccountSettingsOnASigned =>
      'Abra Configuración › Inicio de sesión y seguridad en un dispositivo Android en el que haya iniciado sesión, escanee este código y apruebe el inicio de sesión.';

  @override
  String get openComputer => 'Abrir computadora';

  @override
  String get openDashboard => 'Abrir panel';

  @override
  String get openFolder => 'Abrir carpeta…';

  @override
  String get openInWorkbench => 'Abrir en el banco de trabajo';

  @override
  String openNeoagentAndReconnectArg1To(Object? arg1) {
    return 'Abra NeoAgent y vuelva a conectar $arg1 para restaurar la mensajería.';
  }

  @override
  String get openTimeSettings => 'Configuración de tiempo abierto';

  @override
  String get openToAnyone => 'Abierto a cualquiera';

  @override
  String get openTrello => 'Abrir Trello';

  @override
  String get openVoiceAssistant => 'Asistente de voz abierto';

  @override
  String get openWiFiSettings => 'Abrir configuración de Wi-Fi';

  @override
  String get openWithTheDefaultApp => 'Abrir con la aplicación predeterminada';

  @override
  String get openaiCodex => 'Códice OpenAI';

  @override
  String get openaiCompatible => 'compatible con openai';

  @override
  String get openaiCompatibleEndpointYourOwnServer =>
      'Punto final compatible con OpenAI (su propio servidor u otro ';

  @override
  String openedArg1(Object? arg1) {
    return 'Abierto $arg1';
  }

  @override
  String get openingDesktopUrlsIsNotSupported =>
      'Esta plataforma no admite la apertura de URL de escritorio.';

  @override
  String get openingYourSavedDesktop => 'Abriendo su escritorio guardado.';

  @override
  String get openingYourSavedDesktopNormalStarts =>
      'Abriendo su escritorio guardado. Los arranques normales tardan menos de 10 segundos.';

  @override
  String get optionalExtraSecretIfYouProtect =>
      'Secreto adicional opcional si protege el webhook entrante.';

  @override
  String get optionalOverrideIfTheWebhookUrl =>
      'Anulación opcional si la URL del webhook no es suficiente.';

  @override
  String get optionalSecretToVerifyIncomingChat =>
      'Secreto opcional para verificar eventos de Chat entrantes.';

  @override
  String get optionalSecretToVerifyIncomingEvents =>
      'Secreto opcional para verificar eventos entrantes.';

  @override
  String get optionalSecretToVerifyIncomingImessage =>
      'Secreto opcional para verificar los eventos entrantes de iMessage.';

  @override
  String get optionalSecretToVerifyIncomingLine =>
      'Secreto opcional para verificar eventos LINE entrantes.';

  @override
  String get optionalSecretToVerifyIncomingMattermost =>
      'Secreto opcional para verificar los eventos entrantes de Mattermost.';

  @override
  String get optionalSecretToVerifyIncomingTeams =>
      'Secreto opcional para verificar eventos entrantes de Teams.';

  @override
  String get optionalTheAgentAlreadyHasIts =>
      'Opcional. El agente ya tiene personalidad propia. Todo lo que agregues sobre el tono se superpondrá, por lo que nunca tendrás que definir uno.';

  @override
  String get optionalWhenSetItIsUsed =>
      'Opcional. Cuando se establece, se utiliza en lugar de la URL.';

  @override
  String get orAnswerInYourOwnWords => 'O responde con tus propias palabras';

  @override
  String get orBuildYourOwnTask => 'O construye tu propia tarea';

  @override
  String get orContinueWith => 'o continuar con';

  @override
  String get orFiles => 'o archivos.';

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
  String get originNotAllowed => 'origen no permitido';

  @override
  String get outgoingMessage => 'mensaje saliente';

  @override
  String get outgoingWebhookUrl => 'URL de webhook saliente';

  @override
  String get outlookEmailReceived => 'Correo electrónico de Outlook recibido';

  @override
  String get overwriteBehaviorNotesFromTheImport =>
      'Sobrescribe las notas de comportamiento de la importación.';

  @override
  String get ownModel => 'propio modelo';

  @override
  String get packageName => 'Nombre del paquete';

  @override
  String get pairWithQrCode => 'Emparejar con código QR';

  @override
  String get password => 'Contraseña';

  @override
  String get password2faAndActiveSessions =>
      'Contraseña, 2FA y sesiones activas';

  @override
  String get passwordCreated => 'Contraseña creada.';

  @override
  String get passwordIsTooWeak => 'la contraseña es demasiado débil';

  @override
  String get passwordMin8 => 'contraseña min 8';

  @override
  String get passwordOrApiKey => 'Contraseña o clave API';

  @override
  String passwordStrengthArg1(Object? arg1) {
    return 'Seguridad de la contraseña: $arg1';
  }

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden.';

  @override
  String get pasteAKey => 'Pega una clave.';

  @override
  String pasteANewKeyToReplace(Object? arg1) {
    return 'Pegue una nueva clave para reemplazar $arg1';
  }

  @override
  String get pasteTheKey => 'Pega la clave';

  @override
  String get pasteYourAccountToken => 'Pega el token de tu cuenta';

  @override
  String pasteYourArg1ApiKeyBelow(Object? arg1) {
    return 'Pegue su clave API $arg1 a continuación. es ';
  }

  @override
  String get pathMustStayInsideNeoagentWorkspace =>
      'La ruta debe permanecer dentro de NeoAgent Workspace.';

  @override
  String get pathMustStayInsideTheWorkspace =>
      'La ruta debe permanecer dentro de la carpeta del espacio de trabajo.';

  @override
  String get pauseLiveUpdates => 'Pausar actualizaciones en vivo';

  @override
  String get pauseTaskLoop => 'Pausar el ciclo de tareas';

  @override
  String get paused => 'En pausa';

  @override
  String peakArg1(Object? arg1) {
    return 'pico $arg1';
  }

  @override
  String get peopleInPrivateChats => 'Personas en chats privados';

  @override
  String get perAccountRateLimits => 'Límites de tasas por cuenta';

  @override
  String get perCategoryPermissions => 'Permisos por categoría';

  @override
  String get perToolPermissionPoliciesApprovalGates =>
      'Políticas de permisos por herramienta, puertas de aprobación y aislamiento de procesos para la ejecución del shell.';

  @override
  String permissionRequiredArg1(Object? arg1) {
    return 'Permiso requerido: $arg1';
  }

  @override
  String get permissionsNeeded => 'Permisos necesarios';

  @override
  String get permissionsToolPermissionsNobodyElseCan =>
      'Permisos. Nadie más puede cambiar eso.';

  @override
  String get personOrChat => 'Persona o chat';

  @override
  String get personaBehaviorNotes => 'Notas de comportamiento de la persona';

  @override
  String get personalAccessTokenForTheMattermost =>
      'Token de acceso personal para el bot Mattermost.';

  @override
  String get personalChannelsAndDirectSupportSurfaces =>
      'Canales personales y superficies de apoyo directo.';

  @override
  String get personalSelfChat => 'Autochat personal';

  @override
  String get phoneNumber => 'Número de teléfono';

  @override
  String get pickARunFromTheList =>
      'Elija una carrera de la lista para ver sus pasos.';

  @override
  String get pickARunFromTheList2 =>
      'Elija una ejecución de la lista de la izquierda para explorar su flujo.';

  @override
  String pickFromRecentArg1ChatsOr(Object? arg1) {
    return 'Elija entre los chats recientes de $arg1 o agregue una persona o grupo usted mismo.';
  }

  @override
  String pickHowArg1UsesThisAccount(Object? arg1) {
    return 'Elija cómo $arg1 usa esta cuenta.';
  }

  @override
  String get pickOneToFillInThe =>
      'Elija uno para completar la tarea. Puedes modificar todo después.';

  @override
  String get picksUpWhereYouLeftOff => 'Continúa donde lo dejaste';

  @override
  String get plan => 'Planificar';

  @override
  String get planning => 'Planificación';

  @override
  String get platform => 'Plataforma';

  @override
  String platformArg1Arg2(Object? arg1, Object? arg2) {
    return 'Plataforma $arg1$arg2';
  }

  @override
  String get pleaseChooseASchedule => 'Por favor elige un horario.';

  @override
  String get pleaseEnterAFilename => 'Por favor ingrese un nombre de archivo.';

  @override
  String get pleaseEnterAKey => 'Por favor ingrese una clave.';

  @override
  String get pleaseEnterAPrompt => 'Por favor ingrese un mensaje.';

  @override
  String get pleaseEnterATaskName => 'Por favor ingrese un nombre de tarea.';

  @override
  String get pleaseEnterTheMemoryContent =>
      'Por favor ingrese el contenido de la memoria.';

  @override
  String get pleaseEnterWhenTheTaskShould =>
      'Ingrese cuándo debe ejecutarse la tarea.';

  @override
  String get pleaseSelectAnAccountOrEnter =>
      'Seleccione una cuenta o ingrese una ID de conexión válida.';

  @override
  String get pointNeoagentAtAnyOpenaiCompatible =>
      'Señale NeoAgent en cualquier finalización de chat compatible con OpenAI ';

  @override
  String get pointTheCameraAtTheCode =>
      'Apunte la cámara al código que se muestra en el dispositivo cerrado. La aprobación permanece en este teléfono.';

  @override
  String get port => 'Puerto';

  @override
  String get portNodeEnvPublicUrlTrust =>
      'puerto node_env URL pública proxy de confianza implementación de cookies seguras';

  @override
  String get premiumAutomationWithScheduleAndIntegration =>
      'Automatización premium con activadores de programación y integración.';

  @override
  String get prepareQrCode => 'Preparar código QR';

  @override
  String get preparingNeoagent => 'Preparando NeoAgent…';

  @override
  String get preparingNeoagent2 => 'Preparando NeoAgent';

  @override
  String get pressAndHoldForQuickCapture =>
      'Mantenga presionado para una captura rápida';

  @override
  String get pressKeysIsNotSupportedOn =>
      'Pulsar teclas no es compatible con esta plataforma.';

  @override
  String pressedArg1(Object? arg1) {
    return 'Presionado $arg1';
  }

  @override
  String get priceUnknown => 'Precio desconocido';

  @override
  String get primaryDisplay => 'Pantalla principal';

  @override
  String get privateChat => 'charla privada';

  @override
  String get privateChats => 'charlas privadas';

  @override
  String get privateChats2 => 'chats privados';

  @override
  String privateChatsArg1(Object? arg1) {
    return 'Chats privados: $arg1';
  }

  @override
  String privateChatsArg1GroupsArg2(Object? arg1, Object? arg2) {
    return 'Chats privados $arg1 · grupos $arg2';
  }

  @override
  String get privateChatsOnly => 'Solo chats privados';

  @override
  String get privateNetworkAddressesArenTAllowed =>
      'No se permiten direcciones de redes privadas.';

  @override
  String get profileEmailAndPersonalData =>
      'Perfil, correo electrónico y datos personales';

  @override
  String get promptBeforeNeoagentStaysResidentIn =>
      'Preguntar antes de que NeoAgent permanezca residente en la bandeja del sistema.';

  @override
  String promptCacheArg1CachedTokens(Object? arg1) {
    return 'Caché de aviso: tokens almacenados en caché $arg1 ';
  }

  @override
  String get promptCopied => 'Mensaje copiado.';

  @override
  String get promptOrSchedule => 'puntualidad o programación.';

  @override
  String get promptToPasteIntoAnotherAi => 'Solicitar pegar en otra IA';

  @override
  String get providerLinkingCouldNotBeStarted =>
      'No se pudo iniciar la vinculación del proveedor.';

  @override
  String get providerSignInCouldNotBe =>
      'No se pudo iniciar el inicio de sesión del proveedor.';

  @override
  String get providers => 'Proveedores';

  @override
  String get providersEachAccountCanStillPick =>
      'Proveedores; Cada cuenta aún puede elegir su propio modelo en Configuración. ';

  @override
  String get providersIntegrationsVoiceAndOptionalCapabilities =>
      'Los proveedores, las integraciones, la voz y las capacidades opcionales se pueden completar desde Configuración en cualquier momento.';

  @override
  String get publicIssueAndPullRequestThreads =>
      'Hilos de temas públicos y solicitudes de extracción, respondidos solo por personas aprobadas.';

  @override
  String get publicUrl => 'URL pública';

  @override
  String get publicUrlAndAllowedOrigins => 'URL pública y orígenes permitidos';

  @override
  String get publicUrlOverride => 'Anulación de URL pública';

  @override
  String get pullsTogetherTheDayAhead => 'Se reúne el día por delante';

  @override
  String get pushToTalk => 'Pulsar para hablar';

  @override
  String get qrBasedPhoneLinking => 'Vinculación telefónica basada en QR';

  @override
  String get qrLoginCompletedButNeoagentCould =>
      'Se completó el inicio de sesión QR, pero NeoAgent no pudo mantener la sesión. Por favor inténtalo de nuevo.';

  @override
  String get qrLoginCouldNotBeStarted =>
      'No se pudo iniciar el inicio de sesión QR.';

  @override
  String get qrLoginRequestHasExpired =>
      'La solicitud de inicio de sesión qr ha caducado';

  @override
  String get qrLoginRequestWasNotFound =>
      'No se encontró la solicitud de inicio de sesión qr';

  @override
  String get qrPairing => 'Emparejamiento QR';

  @override
  String get queriesRunAnythingThatWritesIs =>
      'se ejecutan consultas; todo lo que escribe es rechazado.';

  @override
  String get queryFilter => 'Consulta/Filtro';

  @override
  String queuedAsSteeringForTheCurrent(Object? arg1) {
    return 'En cola como dirección para la ejecución actual: $arg1';
  }

  @override
  String get quickstart => 'Inicio rápido';

  @override
  String get quit => 'dejar de fumar';

  @override
  String get rErrorRCreatedAt => '       r.error, r.created_at\n';

  @override
  String get rainStartWindAlert => 'inicio_lluvia, alerta_viento';

  @override
  String get ranAScriptInThePage => 'Ejecuté un script en la página.';

  @override
  String ranArg1(Object? arg1) {
    return 'Corrió $arg1';
  }

  @override
  String get rateLimits => 'Límites de tarifas';

  @override
  String get readAnArtifact => 'leer un artefacto';

  @override
  String get readAndEditFilesInsideYour =>
      'Lea y edite archivos dentro de su carpeta NeoAgent Workspace.';

  @override
  String readArg1(Object? arg1) {
    return 'Leer $arg1';
  }

  @override
  String get readError => 'error de lectura';

  @override
  String get readFiles => 'leer archivos';

  @override
  String get readOnly => 'Sólo lectura';

  @override
  String get readTheFolderAndSummarizeThe =>
      'Lea la carpeta y resuma la pila, los puntos de entrada y cómo ejecutarla.';

  @override
  String get readThePage => 'leer la pagina';

  @override
  String get readTheUiTree => 'Leer el árbol de la interfaz de usuario';

  @override
  String get readWrite => 'Leer/Escribir';

  @override
  String get readsStepsHeartRateSleepExercise =>
      'Lee pasos, frecuencia cardíaca, sueño, ejercicio y peso.';

  @override
  String get ready => 'Listo';

  @override
  String get readyForFirstTimeSetup =>
      'Listo para la configuración por primera vez';

  @override
  String get readyToConnect => 'Listo para conectarse';

  @override
  String get recentChannelActivity => 'Actividad reciente del canal';

  @override
  String get recentChats => 'Chats recientes';

  @override
  String get recentDecisions => 'Decisiones recientes';

  @override
  String get recentFailedRuns => 'Ejecuciones fallidas recientes';

  @override
  String get recentGroupDecisions => 'Decisiones grupales recientes';

  @override
  String get recentRuns => 'Ejecuciones recientes';

  @override
  String recentRunsTakeAboutArg1(Object? arg1) {
    return 'Las ejecuciones recientes toman aproximadamente $arg1, ';
  }

  @override
  String get recentServerOutputNewestFirst =>
      'Salida reciente del servidor, la más nueva primero.';

  @override
  String get recentUsage4Hours => 'Uso reciente (4 horas)';

  @override
  String get recents => 'Recientes';

  @override
  String get recipientField => 'Campo destinatario';

  @override
  String get reconnectOrFinishSetup =>
      'Vuelva a conectarse o finalice la configuración';

  @override
  String get reconnectingThisDevice => 'Reconectando este dispositivo...';

  @override
  String get recurring => 'recurrente';

  @override
  String get redirectUri => 'URI de redireccionamiento';

  @override
  String get redoOnboarding => 'Rehacer la incorporación';

  @override
  String get refresh => 'Actualizar';

  @override
  String get refreshCode => 'Actualizar código';

  @override
  String get refreshNow => 'Actualizar ahora';

  @override
  String get refreshTheAndroidScreenToTry =>
      'Actualiza la pantalla de Android para volver a intentarlo.';

  @override
  String get refuseToSendUnlessTheConnection =>
      'Negarse a enviar a menos que la conexión se actualice a TLS.';

  @override
  String get regardlessOfPerCategorySettingsBelow =>
      'independientemente de la configuración por categoría a continuación.';

  @override
  String registerArg1ForTheAssistantSummon(Object? arg1) {
    return 'Registre $arg1 para el flujo de convocatoria de asistente.';
  }

  @override
  String get registrationIsClosed => 'la inscripción está cerrada';

  @override
  String get registrationRegisterNewAccountsAllowSignup =>
      'registro registrarse nuevas cuentas permitir registro';

  @override
  String get rejectInvalidTlsCertificates =>
      'Rechazar certificados TLS no válidos';

  @override
  String get releaseAndRestartsConnectedAppsReconnect =>
      'suelta y reinicia. Las aplicaciones conectadas se vuelven a conectar una vez que regresan.';

  @override
  String get releaseChannel => 'Canal de lanzamiento';

  @override
  String get releaseCommitBranchNode =>
      'liberar el nodo de rama de confirmación';

  @override
  String get releaseWhenYouAreDone => 'Suelte cuando haya terminado.';

  @override
  String get reloadNow => 'Recargar ahora';

  @override
  String get rememberThisChoice => 'Recuerda esta elección';

  @override
  String get remove => 'Quitar';

  @override
  String removeArg1AndItsRecordedSteps(Object? arg1) {
    return '¿Eliminar \"$arg1\" y sus pasos registrados del historial de ejecución?';
  }

  @override
  String removeArg1FromCoreMemory(Object? arg1) {
    return 'Elimine \"$arg1\" de la memoria central.';
  }

  @override
  String removeArg1Key(Object? arg1) {
    return '¿Quitar la clave $arg1?';
  }

  @override
  String get removeEraseGdprUser => 'eliminar borrar usuario gdpr';

  @override
  String get removeSmtpPassword => 'Eliminar contraseña SMTP';

  @override
  String get removeTheSmtpPassword => '¿Eliminar la contraseña SMTP?';

  @override
  String get rename => 'Cambiar nombre';

  @override
  String get renameSecurityKey => 'Cambiar el nombre de la clave de seguridad';

  @override
  String get renameSession => 'Cambiar nombre de sesión';

  @override
  String get repairAndRetry => 'Reparar y volver a intentar';

  @override
  String get repairDesktop => 'Reparar escritorio';

  @override
  String get repeat => 'repetir';

  @override
  String get repliesWhenTagged => 'Responde cuando lo etiquetan';

  @override
  String get replyToAddress => 'Dirección de respuesta';

  @override
  String replyToArg1(Object? arg1) {
    return 'Responder a $arg1';
  }

  @override
  String get repositoryMustBeInTheFormat =>
      'El repositorio debe tener el formato propietario/repositorio.';

  @override
  String get reproduceTheBugIDescribeFind =>
      'Reproduzca el error que describo, encuentre la causa raíz y corríjalo con una prueba de regresión.';

  @override
  String requestFailedWithHttpArg1(Object? arg1) {
    return 'la solicitud falló con http $arg1';
  }

  @override
  String requestFailedWithHttpArg12(Object? arg1) {
    return 'La solicitud falló con HTTP $arg1';
  }

  @override
  String get requestPermissions => 'Solicitar permisos';

  @override
  String requestToArg1FailedBeforeThe(Object? arg1) {
    return 'La solicitud a $arg1 falló antes de que respondiera el servidor.';
  }

  @override
  String requestedArg1(Object? arg1) {
    return 'Solicitado $arg1';
  }

  @override
  String get requireStarttls => 'Requerir STARTTLS';

  @override
  String get requiredBehindHttpsOrATls =>
      'Requerido detrás de HTTPS o un proxy TLS. Se aplica después de un servidor. ';

  @override
  String get requiredExampleBerlinDe => 'Requerido. Ejemplo: Berlín, DE';

  @override
  String get requiredFormatOwnerRepo =>
      'Requerido. Formato: propietario/repositorio';

  @override
  String get reserveAssistantHotkey =>
      'Reservar tecla de acceso rápido al asistente';

  @override
  String get reset => 'Reiniciar';

  @override
  String get resetPassword => 'Restablecer contraseña';

  @override
  String get resetView => 'Restablecer vista';

  @override
  String get responsibilities => 'Responsabilidades';

  @override
  String get restart => 'Reiniciar';

  @override
  String get restartToFinishTheUpdate =>
      ' Reinicie para finalizar la actualización.';

  @override
  String get restoringThePreviousNeoagentRuntime =>
      'Restaurar el tiempo de ejecución anterior de NeoAgent';

  @override
  String get restrictDelegationTargets => 'Restringir objetivos de delegación';

  @override
  String get result => 'Resultado';

  @override
  String get resultDelivery => 'Entrega de resultados';

  @override
  String get resultOneClickAddsOneYou =>
      'resultado. Un clic agrega uno; puedes editarlo más tarde.';

  @override
  String get results => 'Resultados';

  @override
  String get retry => 'Reintentar';

  @override
  String reusableUsedArg1(Object? arg1) {
    return 'Reutilizable · usado $arg1×';
  }

  @override
  String get reviewUncommittedChanges => 'Revisar cambios no confirmados';

  @override
  String get revoke => 'Revocar';

  @override
  String revokeAdminWithNeoagentAdminRevoke(Object? arg1) {
    return 'Revocar el administrador con `neoagent admin revocar $arg1` primero';
  }

  @override
  String get revokeThisLink => '¿Revocar este enlace?';

  @override
  String roomBatchWindowArg1Ms(Object? arg1) {
    return 'Ventana de lote de habitación: $arg1 ms';
  }

  @override
  String get rotateToContinue => 'Girar para continuar';

  @override
  String get roundSumAByteSize1048576 =>
      '       ROUND(SUM(a.byte_size) / 1048576.0, 2) AS mb\n';

  @override
  String get rowsAddALimitOrA =>
      'filas. Agregue una cláusula LIMIT o WHERE más estrecha para ver ';

  @override
  String get rule => 'regla';

  @override
  String get run => 'Ejecución';

  @override
  String get runArbitraryCommandsOnYourMachine =>
      'Ejecute comandos arbitrarios en su máquina o VM.';

  @override
  String get runAt => 'correr en';

  @override
  String get runCompleted => 'Ejecución completada';

  @override
  String get runFailed => 'La ejecución falló';

  @override
  String get runGitDiffReviewTheUncommitted =>
      'Ejecute git diff, revise los cambios no confirmados en busca de errores y problemas de estilo, y resuma lo que encuentre.';

  @override
  String get runNotFound => 'Ejecutar no encontrado';

  @override
  String get runNow => 'Ejecutar ahora';

  @override
  String get runOnInboundPersonalWhatsappMessages =>
      'Ejecutar mensajes personales entrantes de WhatsApp.';

  @override
  String get runQuery => 'Ejecutar consulta';

  @override
  String get runShellCommandsOrInstallApps =>
      'Ejecute comandos de shell o instale aplicaciones en su dispositivo Android.';

  @override
  String get runStarted => 'Ejecución iniciada';

  @override
  String get runStatus => 'Estado de ejecución';

  @override
  String get runStopped => 'Ejecución detenida';

  @override
  String get runTerminalCommandsAndOpenApps =>
      'Ejecute comandos de terminal y abra aplicaciones o páginas web.';

  @override
  String get runThisServerAccountsUpdatesProviders =>
      'Ejecute este servidor: cuentas, actualizaciones, proveedores, configuración ';

  @override
  String get runWhenAMatchingGmailMessage =>
      'Ejecutarlo cuando llegue un mensaje de Gmail coincidente.';

  @override
  String get runWhenAMatchingOutlookEmail =>
      'Ejecútelo cuando llegue un correo electrónico de Outlook coincidente.';

  @override
  String get runWhenANewIssueMatching =>
      'Ejecútelo cuando se abra en un repositorio un nuevo problema que coincida con sus filtros.';

  @override
  String get runWhenANewNeorecallMemoryMatches =>
      'Ejecútelo cuando se cree una nueva memoria NeoRecall que coincida con sus filtros.';

  @override
  String get runWhenANotificationArrivesOn =>
      'Ejecútelo cuando llegue una notificación a su dispositivo.';

  @override
  String get runWhenASlackMessageMatches =>
      'Se ejecuta cuando un mensaje de Slack coincide con el alcance seleccionado.';

  @override
  String get runWhenATeamsChatMessage =>
      'Ejecutar cuando un mensaje de chat de Teams coincida con el alcance seleccionado.';

  @override
  String get runWhenConfiguredWeatherEventsAre =>
      'Se ejecuta cuando se pronostican eventos climáticos configurados para una ubicación.';

  @override
  String get runWhileAnyModelIsSwitched =>
      'correr. Mientras cualquier modelo está apagado, los modelos que agregan los proveedores ';

  @override
  String get running => 'En curso';

  @override
  String runningArg1(Object? arg1) {
    return 'Ejecutando $arg1';
  }

  @override
  String get runningTask => 'Tarea en ejecución';

  @override
  String get runningTool => 'herramienta para correr';

  @override
  String get runs => 'Ejecuciones';

  @override
  String get runsEveryDayAtTheSelected =>
      'Se ejecuta todos los días a la hora seleccionada.';

  @override
  String get runsFourTimesPerHour => 'Funciona cuatro veces por hora.';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd =>
      '— ejecuciones, mensajes, memorias, integraciones, archivos y ';

  @override
  String get runsMessagesMemoriesIntegrationsFilesAnd2 =>
      'ejecuciones, mensajes, memorias, integraciones, archivos y sesiones. ';

  @override
  String get runsMondayThroughFriday => 'Funciona de lunes a viernes.';

  @override
  String get runsOnSelectedWeekdays =>
      'Funciona en días laborables seleccionados.';

  @override
  String get runsOncePerHour => 'Se ejecuta una vez por hora.';

  @override
  String get runsOncePerMonthOnThe =>
      'Se ejecuta una vez al mes en el día seleccionado.';

  @override
  String get runsOnlyWhenYouPressRun =>
      'Se ejecuta solo cuando presiona Ejecutar ahora.';

  @override
  String get runsPerDay => 'Corre por día';

  @override
  String get runsPerDay30Days => 'Ejecuciones por día (30 días)';

  @override
  String get runsThatCompleted => 'Carreras que se completaron';

  @override
  String get runsThisWeek => 'Se ejecuta esta semana';

  @override
  String get runsToday => 'Corre hoy';

  @override
  String get runsToolsMemorySchedulingSkillsAnd =>
      'Ejecuciones, herramientas, memoria, programación, habilidades y MCP están disponibles aquí.';

  @override
  String get runsTwicePerHour => 'Funciona dos veces por hora.';

  @override
  String runsWillFallBackToThe(Object? arg1) {
    return 'Las ejecuciones recurrirán a la clave del servidor compartido para $arg1, si hay alguna configurada. Esto no se puede deshacer.';
  }

  @override
  String runtimeArg1(Object? arg1) {
    return 'Tiempo de ejecución $arg1';
  }

  @override
  String runtimeArg12(Object? arg1) {
    return ' | Tiempo de ejecución: $arg1';
  }

  @override
  String get runtimeSettingsThisServerStartedWith =>
      'Configuración de tiempo de ejecución con la que comenzó este servidor. Edítalos en ';

  @override
  String get runtimeSetupRequired =>
      'Se requiere configuración de tiempo de ejecución';

  @override
  String get runtimeSigningPublicKeyMustBe =>
      'La clave pública de firma en tiempo de ejecución debe tener 32 bytes.';

  @override
  String get sUserAgentSCreatedAt =>
      '       s.user_agent, s.created_at, s.last_seen_at\n';

  @override
  String get save => 'Guardar';

  @override
  String get saveATrelloApiKeyFor =>
      'Guarde una clave API de Trello para este agente y luego conecte una cuenta de Trello de forma segura. El token de la cuenta se almacena en el servidor y se utiliza únicamente para este agente.';

  @override
  String get saveAccount => 'guardar cuenta';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get saveCloudComputerSettings =>
      'Guardar la configuración de la computadora en la nube';

  @override
  String get saveConnect => 'Guardar y conectar';

  @override
  String get saveDefaults => 'Guardar valores predeterminados';

  @override
  String get saveDiagnosticReport => 'Guardar informe de diagnóstico';

  @override
  String get saveEmail => 'Guardar correo electrónico';

  @override
  String get saveEmailSettings => 'Guardar configuración de correo electrónico';

  @override
  String get saveGeneralSettings => 'Guardar configuración general';

  @override
  String get saveName => 'Guardar nombre';

  @override
  String get saveNeoagentSetupDiagnostics =>
      'Guarde el diagnóstico de configuración de NeoAgent';

  @override
  String get saveOnly => 'Guardar sólo';

  @override
  String get saveSetup => 'Guardar configuración';

  @override
  String get saveTheseRecoveryCodesNowThey =>
      'Guarde estos códigos de recuperación ahora. No se volverán a mostrar.';

  @override
  String get savedDeliveryDestination => 'Destino de entrega guardado';

  @override
  String savedRateLimitsForArg1(Object? arg1) {
    return 'Límites de tarifas guardados para @$arg1.';
  }

  @override
  String get scanANeoagentLoginQr =>
      'Escanear un QR de inicio de sesión de NeoAgent';

  @override
  String get scanANeoagentPairingQrFrom =>
      'Escanee un QR de emparejamiento de NeoAgent desde otro dispositivo y apruebe desde esta sesión de inicio.';

  @override
  String get scanLoginQr => 'Escanear el QR de inicio de sesión';

  @override
  String get scanPairingQr => 'Escanear emparejamiento QR';

  @override
  String get scanQrLoginRequestsFromSigned =>
      'Escanee solicitudes de inicio de sesión QR desde dispositivos cerrados y apruebelas desde esta sesión móvil autenticada.';

  @override
  String scanToFinishArg1(Object? arg1) {
    return 'Escanear para finalizar $arg1';
  }

  @override
  String get scanWithNeoagentOnYourPhone =>
      'Escanea con NeoAgent en tu teléfono';

  @override
  String get scansNewEmailAndOnlyPings =>
      'Escanea nuevos correos electrónicos y solo te envía un ping cuando algo importa.';

  @override
  String get schedule => 'Horario';

  @override
  String get scheduledTimeOnceRunsAreMeasured =>
      'hora prevista. Una vez que se midan las carreras, comenzará antes.';

  @override
  String get screen => 'Pantalla';

  @override
  String get screenAction => 'acción de pantalla';

  @override
  String get scrollIsNotSupportedOnThis =>
      'El desplazamiento no es compatible con esta plataforma.';

  @override
  String get scrollToBottom => 'Desplazarse hacia abajo';

  @override
  String get search => 'Buscar';

  @override
  String get search2 => 'Buscar…';

  @override
  String get searchAdminSettingsEGSmtp =>
      'Buscar configuraciones de administrador (por ejemplo, SMTP, Ollama, registros)';

  @override
  String get searchAgain => 'Buscar de nuevo';

  @override
  String get searchByUsernameOrEmail =>
      'Buscar por nombre de usuario o correo electrónico';

  @override
  String get searchChannels => 'Buscar canales';

  @override
  String get searchDiscoveredMessagingChannelsContactsGroups =>
      'Busque canales de mensajería, contactos, grupos y conversaciones recientes descubiertos.';

  @override
  String get searchGroups => 'Grupos de búsqueda';

  @override
  String get searchMemory => 'memoria de búsqueda';

  @override
  String get searchModelsOrProviders => 'Buscar modelos o proveedores';

  @override
  String get searchModelsOrProviders2 => 'Buscar modelos o proveedores…';

  @override
  String get searchRecentPeopleAndGroups =>
      'Buscar personas y grupos recientes';

  @override
  String get searchSessions => 'Sesiones de búsqueda';

  @override
  String get searchSettings => 'Configuración de búsqueda';

  @override
  String get searchTitleModelTriggerRunId =>
      'Título de búsqueda, modelo, activador, ID de ejecución';

  @override
  String get searchToolsIntegrationsAndSkills =>
      'Herramientas de búsqueda, integraciones y habilidades';

  @override
  String searchedCodeForArg1(Object? arg1) {
    return 'Código buscado para \"$arg1\"';
  }

  @override
  String searchedFilesForArg1(Object? arg1) {
    return 'Archivos buscados para \"$arg1\"';
  }

  @override
  String get secretField => 'campo secreto';

  @override
  String get secureCookies => 'Cookies seguras';

  @override
  String get security => 'Seguridad';

  @override
  String get securityKey => 'Llave de seguridad';

  @override
  String get securityKeyPromptWasDismissed =>
      'Se descartó el mensaje de clave de seguridad.';

  @override
  String get securityKeySignInCompletedBut =>
      'Se completó el inicio de sesión con la clave de seguridad, pero NeoAgent no pudo mantener la sesión del navegador. Por favor inicia sesión nuevamente.';

  @override
  String get securityKeySignInCouldNot =>
      'No se pudo iniciar el inicio de sesión con la clave de seguridad.';

  @override
  String get securityKeys => 'Claves de seguridad';

  @override
  String get securityKeysAreOnlyAvailableIn =>
      'Las claves de seguridad solo están disponibles en la aplicación web NeoAgent.';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get seeWhichNeoagentServerThisWindow =>
      'Vea qué servidor NeoAgent utiliza esta ventana y ejecute el backend en esta computadora.';

  @override
  String get seeYourUsernameAndTheseSettings =>
      'ver tu nombre de usuario y estas configuraciones, nunca tus chats, recuerdos ';

  @override
  String get selectARun => 'Selecciona una carrera';

  @override
  String get selectASessionToSeeIts =>
      'Seleccione una sesión para ver su computadora, archivos y cambios.';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectAll2 => 'Seleccionar todo';

  @override
  String selectArg1(Object? arg1) {
    return 'Seleccione $arg1';
  }

  @override
  String get selectTrigger => 'Seleccionar disparador';

  @override
  String get send => 'Enviar (⌘↵)';

  @override
  String get send2 => 'enviar';

  @override
  String get sendATaskFromChatAnd =>
      'Envía una tarea desde el chat y su historial de ejecución se mostrará aquí.';

  @override
  String get sendItToATeammateWith =>
      'envíalo a un compañero de equipo con una cuenta en este servidor.';

  @override
  String get sendLink => 'Enviar enlace';

  @override
  String get sendPath => 'Enviar ruta';

  @override
  String get sendPostPutDeleteRequestsTo =>
      'Envíe solicitudes POST / PUT / DELETE a API externas.';

  @override
  String get sendThisLinkOnlyToThe =>
      'Envíe este enlace únicamente a la persona a la que está destinado. Se muestra una vez; ';

  @override
  String get senderAddress => 'Dirección del remitente';

  @override
  String get senderFilterOptional => 'Filtro de remitente (opcional)';

  @override
  String get sentSharedAttachments => 'Envió archivos adjuntos compartidos.';

  @override
  String get separateAccount => 'cuenta separada';

  @override
  String get server => 'Servidor';

  @override
  String serverDefaultArg1(Object? arg1) {
    return 'Valor predeterminado del servidor ($arg1)';
  }

  @override
  String get serverDefaultsForInAppVoice =>
      'Valores predeterminados del servidor para llamadas de voz dentro de la aplicación. Las llamadas se ejecutan en vivo. ';

  @override
  String get serverItselfAccountsProvidersAndConfiguration =>
      'servidor en sí: cuentas, proveedores y configuración.';

  @override
  String get serverNickChannelAndOptionalTls =>
      'Servidor, nick, canal y TLS opcional';

  @override
  String get serverOutputConsoleWarningsErrorsCopy =>
      'salida del servidor consola advertencias errores copia';

  @override
  String get serverProviderCredentials =>
      'Credenciales del proveedor del servidor';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get serverUsageLimitsDonTApply =>
      'Los límites de uso del servidor no se aplican a los modelos que se ejecutan con su propia clave.';

  @override
  String get serviceEmail => 'Correo electrónico de servicio';

  @override
  String get serviceEmailIsNotConfigured =>
      'El correo electrónico de servicio no está configurado.';

  @override
  String get serviceEmailSmtp => 'Correo electrónico de servicio (SMTP)';

  @override
  String get sessionActions => 'Acciones de sesión';

  @override
  String get sessions => 'Sesiones';

  @override
  String get sessions2 => 'SESIONES';

  @override
  String get sessionsArePinnedToAFolder =>
      'Las sesiones están ancladas a una carpeta y a una computadora. Inicie uno para planificar, construir, probar y enviar desde aquí.';

  @override
  String get sessionsGdprArt17AdminAccounts =>
      'sesiones (RGPD Art. 17). Las cuentas de administrador no se pueden eliminar ';

  @override
  String get sessionsLogoutRevokeForce =>
      'sesiones cerrar sesión revocar forzar';

  @override
  String get setBlockAskAllowPerTool =>
      'Establezca bloquear/preguntar/permitir por categoría de herramienta o elija un modo global.';

  @override
  String get setUpNeoagentOnThisComputer =>
      'Configure NeoAgent en esta computadora';

  @override
  String get setUpOrConnectNeoagent => 'Configurar o conectar NeoAgent';

  @override
  String get setUrl => 'Establecer URL';

  @override
  String get settings => 'Configuración';

  @override
  String get settingsAndCannotBeUndone =>
      'configuración y no se puede deshacer.';

  @override
  String get settingsArea => 'Área de configuración';

  @override
  String get settingsAreas => 'Áreas de configuración';

  @override
  String get setup => 'Configuración';

  @override
  String get setupDetails => 'Detalles de configuración';

  @override
  String get setupRequired => 'Configuración requerida';

  @override
  String get setupWasCancelled => 'La configuración fue cancelada.';

  @override
  String get sharedAttachmentsFromTheNeoagentClient =>
      'Archivos adjuntos compartidos del cliente NeoAgent:';

  @override
  String get sharedFromAnotherApp => 'Compartido desde otra aplicación';

  @override
  String get sharedProviderKeysAreConfiguredOn =>
      'Las claves de proveedor compartidas se configuran en el servidor. Para utilizar su propia clave API o un punto final personalizado, vaya a Avanzado → Traiga su propia clave.';

  @override
  String get sharedWithTheNeoagentChatAnd =>
      'Compartido con el chat de NeoAgent y su memoria.';

  @override
  String get shellCommands => 'Comandos de shell';

  @override
  String showAllArg1(Object? arg1) {
    return 'Mostrar todo $arg1';
  }

  @override
  String get showEarlier => 'Mostrar antes';

  @override
  String get showEveryStep => 'Mostrar cada paso';

  @override
  String get showTools => 'Mostrar herramientas';

  @override
  String get showWorkbenchJ => 'Mostrar banco de trabajo (⌘J)';

  @override
  String showingTheFirstArg1(Object? arg1) {
    return 'Mostrando el primer $arg1 ';
  }

  @override
  String get shownInTheSidebarLeaveBlank =>
      'Se muestra en la barra lateral. Déjelo en blanco para usar su nombre de usuario.';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInCompletedButNeoagentCould =>
      'El inicio de sesión se completó, pero NeoAgent no pudo mantener la sesión del navegador. Por favor inicia sesión nuevamente. Si esto continúa sucediendo, verifique la configuración de cookies de la sesión de backend.';

  @override
  String get signInCompletedButNeoagentCould2 =>
      'El inicio de sesión se completó, pero NeoAgent no pudo mantener la sesión del navegador. Por favor inicia sesión nuevamente. Si esto continúa sucediendo, es probable que la cookie de la sesión de backend no se conserve.';

  @override
  String get signInToThisNeoagentServer =>
      'Inicie sesión en este servidor NeoAgent antes de escanear un código QR de emparejamiento.';

  @override
  String get signInWithAHardwareKey =>
      'Inicie sesión con una clave de hardware o una clave de acceso en lugar de su contraseña. ';

  @override
  String get signInWithASecurityKey =>
      'Iniciar sesión con una clave de seguridad';

  @override
  String signInWithArg1(Object? arg1) {
    return 'Iniciar sesión con $arg1';
  }

  @override
  String approveNeoagentInYourArg1Account(Object? arg1) {
    return 'Apruebe NeoAgent en su cuenta $arg1. No hay clave para copiar.';
  }

  @override
  String waitingForArg1FinishInYourBrowser(Object? arg1) {
    return 'Esperando a $arg1. Finaliza en tu navegador.';
  }

  @override
  String pasteTheArg1Code(Object? arg1) {
    return 'Pegue el código $arg1';
  }

  @override
  String arg1ShowedAOneTimeCode(Object? arg1) {
    return 'Después de aprobar NeoAgent, $arg1 mostró un código de un solo uso. Pégalo aquí.';
  }

  @override
  String get signInCode => 'Código de inicio de sesión';

  @override
  String signedInWithArg1(Object? arg1) {
    return 'Inicia sesión con $arg1.';
  }

  @override
  String signInFailedArg1(Object? arg1) {
    return 'Error al iniciar sesión: $arg1';
  }

  @override
  String get signInWithTheSameEmail =>
      'Inicie sesión con el mismo correo electrónico y contraseña maestra que utiliza en Bitwarden. La contraseña maestra y el código de dos pasos se utilizan únicamente para iniciar sesión y nunca se almacenan ni se envían a la IA.';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String signOutArg1Everywhere(Object? arg1) {
    return '¿Cerrar sesión en @$arg1 en todas partes?';
  }

  @override
  String get signOutEverywhere => 'Cerrar sesión en todas partes';

  @override
  String get signalCliRestApiBridge => 'puente API REST signal-cli';

  @override
  String get signalCliServerUrl => 'URL del servidor signal-cli';

  @override
  String signedArg1OutOfEverySession(Object? arg1) {
    return 'Firmé @$arg1 en cada sesión.';
  }

  @override
  String get signedInDevices => 'Dispositivos registrados';

  @override
  String get signedInWithin24Hours => 'Iniciaste sesión dentro de las 24 horas';

  @override
  String get signingSecret => 'Secreto de firma';

  @override
  String sinceArg1(Object? arg1) {
    return 'Desde $arg1';
  }

  @override
  String sinceArg12(Object? arg1) {
    return 'desde $arg1';
  }

  @override
  String get singleMessage => 'Mensaje único';

  @override
  String get singleUse => 'De un solo uso';

  @override
  String get skill => 'Habilidad';

  @override
  String get skillChanges => 'Cambios de habilidades';

  @override
  String get skillContent => 'Contenido de habilidades';

  @override
  String get skills => 'Habilidades';

  @override
  String get skip => 'Saltar';

  @override
  String get skipForNow => 'Saltar por ahora';

  @override
  String get skipThisTaskBeforeItCalls =>
      'Omita esta tarea antes de que llame al modelo.';

  @override
  String get slackMessageReceived => 'Mensaje flojo recibido';

  @override
  String sleepArg1Sessions(Object? arg1) {
    return 'Dormir sesiones $arg1';
  }

  @override
  String get smartSelector => 'selector inteligente';

  @override
  String get smartSelector2 => 'Selector inteligente';

  @override
  String get smartSelectorPool => 'Grupo de selectores inteligentes';

  @override
  String get smtpHost => 'servidor SMTP';

  @override
  String get smtpMailSenderPasswordTlsConfirmation =>
      'Restablecer notificaciones de confirmación tls de contraseña del remitente de correo smtp';

  @override
  String get smtpPassword => 'contraseña SMTP';

  @override
  String get smtpPort => 'Puerto SMTP';

  @override
  String get smtpPortMustBeAWhole =>
      'El puerto SMTP debe ser un número entero del 1 al 65535.';

  @override
  String get smtpUsername => 'nombre de usuario SMTP';

  @override
  String get soTheRunStartsThatMuch =>
      'entonces la carrera comienza mucho antes.';

  @override
  String get socialBehaviorOff => 'Comportamiento social desactivado';

  @override
  String get socialIntelligence => 'inteligencia social';

  @override
  String get socialIntelligence2 => 'Inteligencia social';

  @override
  String get socialObservability => 'Observabilidad social';

  @override
  String get socialReach => 'alcance social';

  @override
  String get socialReach2 => 'Alcance social';

  @override
  String get socialReach3 => 'Alcance social';

  @override
  String get socialReachUpdated => 'Alcance social actualizado.';

  @override
  String get socialSourcesAgentsCanReadDirectly =>
      'Los agentes de fuentes sociales pueden leer directamente, incluidos feeds, repositorios, Reddit, X, vídeos y datos de mercado respaldados por cookies.';

  @override
  String get somethingWentWrongPleaseTryAgain =>
      'Algo salió mal. Por favor inténtalo de nuevo.';

  @override
  String get source => 'Fuente';

  @override
  String get spaceOrChatIdUsedWhen =>
      'Espacio o ID de chat utilizado cuando este agente inicia una conversación.';

  @override
  String get spaceWebhookAndAppCallbackSupport =>
      'Soporte de devolución de llamadas de aplicaciones y webhooks espaciales';

  @override
  String get speaking => 'hablando';

  @override
  String get speechToSpeechModelUsingThe =>
      'modelo de voz a voz utilizando la clave OpenAI o Google en ';

  @override
  String get speechToText => 'Voz a texto';

  @override
  String get speechToTextTranscribesVoiceNotes =>
      'La conversión de voz a texto transcribe notas de voz y dictados. Auto usa OpenAI, Gemini o Deepgram, cualquiera que tenga una clave API. El modelo de respuesta de voz es el modelo de chat que responde notas de voz.';

  @override
  String get sqlConsole => 'consola SQL';

  @override
  String get stable => 'Estable';

  @override
  String get stableInstallsTheLatestPublishedBackend =>
      'Estable instala la última versión de backend publicada.';

  @override
  String get stackTrace => 'seguimiento de pila';

  @override
  String get standard => 'Estándar';

  @override
  String get standardView => 'Vista estándar';

  @override
  String get start => 'Empezar';

  @override
  String get startASessionToPlanOr =>
      'Inicie una sesión para planificar o construir con NeoAgent.';

  @override
  String get startAndroid => 'Iniciar Android';

  @override
  String get startComputer => 'Iniciar computadora';

  @override
  String get startFullSetup => 'Iniciar la configuración completa';

  @override
  String startProcessFilepathArg1(Object? arg1) {
    return 'Start-Process -FilePath $arg1';
  }

  @override
  String get startSetup => 'Iniciar configuración';

  @override
  String get startTalking => 'empezar a hablar';

  @override
  String get startTheAndroidPhoneFirstThen =>
      'Primero inicie el teléfono Android y luego coloque un archivo .apk o .apks aquí.';

  @override
  String get startTheServerLaterFromThe =>
      'Inicie el servidor más tarde desde la lista una vez que se guarde la configuración.';

  @override
  String get startWithARecommendedTask => 'Comience con una tarea recomendada';

  @override
  String get startingAndroid => 'Iniciando Android';

  @override
  String get startingYourComputer => 'Iniciando tu computadora';

  @override
  String get startsWithXoxbFromYourSlack =>
      'Comienza con xoxb-. Desde las credenciales de tu aplicación Slack.';

  @override
  String starttelecomcallroutingErrorArg1(Object? arg1) {
    return 'Error de startTelecomCallRouting: $arg1';
  }

  @override
  String get statsRunsTokensUsersChartsSuccess =>
      'estadísticas ejecuta tokens usuarios gráficos tasa de éxito';

  @override
  String get status => 'Estado';

  @override
  String get statusDatabaseRuntimeVmProviders =>
      'proveedores de vm en tiempo de ejecución de la base de datos de estado';

  @override
  String get statusIsNotLoadedYet => 'El estado aún no está cargado.';

  @override
  String get stayManagedByYou => 'manténgase administrado por usted.';

  @override
  String get stayOnTheCall => 'Manténgase en la llamada';

  @override
  String get stayedQuiet => 'se mantuvo en silencio';

  @override
  String get steering => 'DIRECCIÓN';

  @override
  String stepArg1OfArg2(Object? arg1, Object? arg2) {
    return 'PASO $arg1 DE $arg2';
  }

  @override
  String stepsArg1(Object? arg1) {
    return 'Pasos $arg1';
  }

  @override
  String get stop => 'Detener';

  @override
  String get stop2 => 'Detener (⌘.)';

  @override
  String get stopManaging => 'dejar de gestionar';

  @override
  String stopManagingArg1(Object? arg1) {
    return '¿Dejar de gestionar $arg1?';
  }

  @override
  String get stopRun => 'dejar de ejecutar';

  @override
  String get stopSpeaking => 'deja de hablar';

  @override
  String get stoppedBeforeCompletion => 'Detenido antes de finalizar';

  @override
  String stoptelecomcallroutingErrorArg1(Object? arg1) {
    return 'Error de stopTelecomCallRouting: $arg1';
  }

  @override
  String get storage => 'Almacenamiento';

  @override
  String get storedEncryptedAndOnlyUsedFor =>
      'almacenado encriptado y utilizado solo para sus propias ejecuciones.';

  @override
  String get storedMetrics => 'Métricas almacenadas';

  @override
  String get storesOnlyTheBitwardenSessionKey =>
      'Almacena solo la clave de sesión de Bitwarden cifrada en este servidor, por lo que las conexiones sobreviven a los reinicios. Puedes bloquearlo en cualquier momento.';

  @override
  String get strong => 'fuerte';

  @override
  String get strongPassword => 'Contraseña segura.';

  @override
  String get subAgent => 'Subagente';

  @override
  String get subagentUpdate => 'Actualización de subagente';

  @override
  String get subagentUpdate2 => 'Actualización de subagente.';

  @override
  String get successRate => 'Tasa de éxito';

  @override
  String suggestionsArg1(Object? arg1) {
    return 'Sugerencias: $arg1';
  }

  @override
  String get sumAByteSizeAsBytes => '       SUM(a.byte_size) AS bytes,\n';

  @override
  String get summariseMyLastRun => 'Resumir mi última carrera';

  @override
  String get supportUrl => 'URL de soporte';

  @override
  String get supportedRainStartSnowStartWind =>
      'Soportado: rain_start, snow_start, wind_alert, temperatura_arriba, temperatura_abajo';

  @override
  String get switchAgent => 'Cambiar de agente';

  @override
  String get symbolicLinksAreNotAllowedIn =>
      'No se permiten enlaces simbólicos en las rutas de NeoAgent Workspace.';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get synologyChat => 'Chat de Synología';

  @override
  String get systemPrivacySettings => 'Configuración de privacidad del sistema';

  @override
  String get tableInfoUsers => 'Información de la tabla (usuarios)';

  @override
  String get tagsOnly => 'Sólo etiquetas';

  @override
  String get tasks => 'Tareas';

  @override
  String get tasksRunOnTheirOwnAnd =>
      'Las tareas se ejecutan solas y le envían mensajes con el ';

  @override
  String get teach => 'enseñar';

  @override
  String get teachingInProgress => 'Enseñanza en progreso';

  @override
  String get team => 'equipo';

  @override
  String get teamLinksNeverMakeAnyoneA =>
      'Los enlaces de equipo nunca convierten a nadie en administrador del servidor. Los administradores ejecutan el ';

  @override
  String get teamSpacesRoomsChannelsAndLive =>
      'Espacios de equipo, salas, canales y comunidades en vivo.';

  @override
  String get teamsMessageReceived => 'Mensaje de equipos recibido';

  @override
  String get templates => 'Plantillas';

  @override
  String get temporarySetupFilesWillBeCleaned =>
      'Los archivos de configuración temporales se limpiarán más tarde.';

  @override
  String get tenantId => 'ID de inquilino';

  @override
  String get testConnection => 'Conexión de prueba';

  @override
  String get testConnection2 => 'Conexión de prueba';

  @override
  String get textChat => 'Texto y chat';

  @override
  String get thatAddedTheirOwnKeyKeep =>
      'que agregaron su propia clave siguen usándola.';

  @override
  String get thatEmailAlreadyBelongsToAn =>
      'Ese correo electrónico ya pertenece a una cuenta existente. Primero inicie sesión, luego vincule Google desde la configuración de la cuenta.';

  @override
  String get thatEmailIsAlreadyLinkedTo =>
      'Ese correo electrónico ya está vinculado a otra cuenta.';

  @override
  String get thatQrCodeIsNotA =>
      'Ese código QR no es una solicitud de inicio de sesión de NeoAgent.';

  @override
  String get thatQrCodeIsNotA2 =>
      'Ese código QR no es una solicitud de emparejamiento de NeoAgent.';

  @override
  String get thatSecurityKeyIsAlreadyRegistered =>
      'Esa clave de seguridad ya está registrada en esta cuenta.';

  @override
  String get theAddress => 'la dirección';

  @override
  String get theAddressOfYourBluebubblesServer =>
      'La dirección de su servidor BlueBubbles.';

  @override
  String get theAddressPeopleAndOauthProviders =>
      'La dirección que utilizan las personas y los proveedores de OAuth para comunicarse ';

  @override
  String get theAgentReadsTimesYouMention =>
      'El agente lee las horas que usted menciona y ejecuta tareas programadas en esta zona horaria.';

  @override
  String get theAgentWillAskBeforeEvery =>
      'El agente preguntará antes de cada herramienta sensible, ';

  @override
  String get theAgentWillIgnoreThisSkill =>
      'El agente ignorará esta habilidad.';

  @override
  String get theAppCouldNotReachThis =>
      'La aplicación no pudo alcanzar esta implementación de NeoAgent. Verifique su conexión de red o confirme que la URL del servicio sea correcta.';

  @override
  String theBrowserBlockedARequestTo(Object? arg1) {
    return 'El navegador bloqueó una solicitud a $arg1 debido a la Política de seguridad de contenido.';
  }

  @override
  String get theBrowserBlockedARequiredRequest =>
      'El navegador bloqueó una solicitud requerida debido a la Política de seguridad de contenido.';

  @override
  String get theCloudWorkspace => 'el espacio de trabajo en la nube';

  @override
  String get theComputerCouldNotStart => 'La computadora no pudo iniciar';

  @override
  String get theComputerNeedsMoreFreeDisk =>
      'La computadora necesita más espacio libre en el disco del host NeoAgent. Libera algo de espacio y vuelve a intentarlo.';

  @override
  String get theComputerRuntimeNeedsRepairRun =>
      'El tiempo de ejecución de la computadora necesita reparación. Ejecute NeoAgent Doctor y vuelva a intentarlo.';

  @override
  String get theConnectionTestFailed => 'La prueba de conexión falló.';

  @override
  String get theDesktopDidNotStart => 'El escritorio no se inició';

  @override
  String get theDiscoveredNeoagentReturnedIncompleteIdentity =>
      'El NeoAgent descubierto arrojó datos de identidad incompletos.';

  @override
  String get theDiscoveredNeoagentUsesAnUnsupported =>
      'El NeoAgent descubierto utiliza un protocolo de configuración no compatible.';

  @override
  String get theDiscoveredServiceIsNotNeoagent =>
      'El servicio descubierto no es NeoAgent.';

  @override
  String get theDownloadedNeoagentRuntimeDidNot =>
      'El tiempo de ejecución de NeoAgent descargado no pasó la verificación.';

  @override
  String get theGoogleChatSpaceWebhookThis =>
      'El webhook del espacio de Google Chat en el que este agente debe publicar.';

  @override
  String get theInstallerIsNoLongerAvailable =>
      'El instalador ya no está disponible.';

  @override
  String get theInteractiveLinuxDesktopIsAvailable =>
      'El escritorio interactivo de Linux está disponible en la aplicación web NeoAgent.';

  @override
  String get theIntroIsNotAvailableOn =>
      'La introducción no está disponible en este dispositivo.';

  @override
  String get theLatestRunsAcrossEveryAccount =>
      'Lo último se ejecuta en todas las cuentas.';

  @override
  String theLatestSyncWindowEndedArg1(Object? arg1) {
    return 'La última ventana de sincronización finalizó $arg1 y no encontró ningún registro nuevo de Health Connect. Las métricas almacenadas a continuación provienen de sincronizaciones anteriores.';
  }

  @override
  String get theLinuxGraphicalSessionIsNot =>
      'La sesión gráfica de Linux no se está ejecutando.';

  @override
  String get theLiveVoiceModelDidNot =>
      'La modelo de voz en vivo no respondió. Intentar otra vez.';

  @override
  String theLocalNeoagentCommandExitedWith(Object? arg1) {
    return 'El comando local NeoAgent salió con el código $arg1.';
  }

  @override
  String get theLocalNeoagentCommandTimedOut =>
      'Se agotó el tiempo de espera del comando NeoAgent local.';

  @override
  String get theLocalNeoagentRuntimeNeedsRepair =>
      'El tiempo de ejecución local de NeoAgent necesita reparación.';

  @override
  String theLocalRuntimeNeedsRepairArg1(Object? arg1) {
    return 'El tiempo de ejecución local necesita reparación ($arg1).';
  }

  @override
  String get theLocalUserHomeDirectoryIs =>
      'El directorio de inicio del usuario local no está disponible.';

  @override
  String get theMailAccountNeoagentSendsSign =>
      'La cuenta de correo NeoAgent envía confirmaciones de registro, inicio de sesión ';

  @override
  String get theMainAgentIsCreatedAutomatically =>
      'El agente principal se crea automáticamente cuando es necesario.';

  @override
  String get theMatchingNeoagentRuntimeIsMissing =>
      'En esta versión falta el tiempo de ejecución de NeoAgent correspondiente.';

  @override
  String get theMattermostIncomingWebhookThisAgent =>
      'El webhook entrante de Mattermost en el que este agente debe publicar.';

  @override
  String get theModelsTheSmartSelectorRoutes =>
      'Los modelos entre los que el Selector inteligente se dirige automáticamente.';

  @override
  String get theNeoagentBackendDownloadDidNot =>
      'La descarga del backend de NeoAgent no coincidía con su manifiesto.';

  @override
  String get theNeoagentBackendDownloadWasIncomplete =>
      'La descarga del backend de NeoAgent estaba incompleta.';

  @override
  String get theNeoagentBackendOnThisComputer =>
      'El backend de NeoAgent en esta computadora no responde en el puerto ';

  @override
  String get theNeoagentBackendRuntimeCouldNot =>
      'No se pudo descargar el tiempo de ejecución del backend de NeoAgent.';

  @override
  String theNeoagentBackendTookTooLong(Object? arg1) {
    return 'El backend de NeoAgent tardó demasiado en responder a $arg1.';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp =>
      'La implementación de NeoAgent respondió con HTTP 402 en lugar del 401 normal para credenciales no válidas. Verifique el proxy inverso, la puerta de enlace de autenticación o las reglas relacionadas con el pago en ese servidor.';

  @override
  String theNeoagentDeploymentRespondedWithHttp2(Object? arg1) {
    return 'La implementación de NeoAgent respondió con HTTP 402.\n\n$arg1';
  }

  @override
  String get theNeoagentDeploymentRespondedWithHttp3 =>
      'La implementación de NeoAgent respondió con HTTP 402. Verifique el proxy inverso, la puerta de enlace de autenticación o las reglas relacionadas con el pago en ese servidor.';

  @override
  String get theNeoagentInstanceThisAppIs =>
      'La instancia de NeoAgent a la que está conectada esta aplicación.';

  @override
  String get theNeoagentReleaseServiceReturnedInvalid =>
      'El servicio de lanzamiento de NeoAgent devolvió datos no válidos.';

  @override
  String get theNeoagentRuntimeArtifactMetadataIs =>
      'Los metadatos del artefacto de tiempo de ejecución de NeoAgent no son válidos.';

  @override
  String get theNeoagentRuntimeManifestDidNot =>
      'El manifiesto de tiempo de ejecución de NeoAgent no pasó la verificación de firma.';

  @override
  String get theNeoagentRuntimeManifestHasNo =>
      'El manifiesto de tiempo de ejecución de NeoAgent no tiene artefactos.';

  @override
  String get theNeoagentRuntimeManifestSignatureIs =>
      'La firma del manifiesto de tiempo de ejecución de NeoAgent no es válida.';

  @override
  String get thePasswordYouSetInBluebubbles =>
      'La contraseña que estableciste en BlueBubbles.';

  @override
  String get thePeopleYouManageStayWith =>
      'Las personas que diriges se quedan contigo.';

  @override
  String get theProviderAnswers => 'responde el proveedor.';

  @override
  String get theQueryReturnedNoRows => 'La consulta no arrojó filas.';

  @override
  String get theRequestedDesktopDisplayIsNot =>
      'La pantalla de escritorio solicitada no está disponible.';

  @override
  String get theRest => 'el resto.';

  @override
  String get theRestEndpointForYourSignal =>
      'El punto final REST para su instancia de signal-cli.';

  @override
  String get theRunIsPausedUntilYou =>
      'La carrera se detiene hasta que respondas.';

  @override
  String get theRunStartsAtTheScheduled =>
      'La carrera comienza a la hora prevista.';

  @override
  String get theRuntimeIsALightweightDebian =>
      'El tiempo de ejecución es un escritorio ligero Debian Linux con Chromium, PCManFM, Mousepad, LXTerminal, Python, Git y herramientas de línea de comandos estándar. Su capacidad es gestionada por el host NeoAgent.';

  @override
  String get theSecurityKeyRegistrationCouldNot =>
      'No se pudo iniciar el registro de la clave de seguridad.';

  @override
  String get theServerKeepsOnlyAFingerprint =>
      'el servidor guarda sólo una huella digital del mismo.';

  @override
  String get theServerOnThisComputerIs =>
      'El servidor de esta computadora no se está ejecutando';

  @override
  String get theServerReportedNoHealthChecks =>
      'El servidor no informó ningún control de estado.';

  @override
  String get theSignalPhoneNumberThisBot =>
      'El número de teléfono de Signal que utiliza este bot.';

  @override
  String get theTeamsIncomingWebhookThisAgent =>
      'El webhook entrante de Teams en el que este agente debe publicar.';

  @override
  String get theTwoFactorChallengeExpiredSign =>
      'El desafío de dos factores expiró. Inicia sesión nuevamente.';

  @override
  String get theTwoFactorCodeIsNot => 'El código de dos factores no es válido.';

  @override
  String get theVerifiedRuntimePackageCouldNot =>
      'El paquete de tiempo de ejecución verificado no se pudo marcar como ejecutable.';

  @override
  String get theVerifiedRuntimePackageIsMissing =>
      'Al paquete de tiempo de ejecución verificado le faltan los archivos necesarios.';

  @override
  String get theWebAppCouldNotReach =>
      'La aplicación web no pudo acceder al backend de NeoAgent.';

  @override
  String theWebAppCouldNotReach2(Object? arg1) {
    return 'La aplicación web no pudo acceder al backend de NeoAgent en $arg1. Verifique la consola del navegador y la configuración de red/proxy inverso.';
  }

  @override
  String get themselvesTheServerOperatorRemovesAdmin =>
      'ellos mismos; el operador del servidor elimina al administrador primero con ';

  @override
  String get theseChannelsStaySilentToHear =>
      'Estos canales permanecen en silencio. Para volver a saber de ellos, agréguelos en Quién puede enviar mensajes para esa plataforma.';

  @override
  String get theseListsAreOptionalUnlessA =>
      'Estas listas son opcionales a menos que una sección anterior esté configurada como aprobada únicamente.';

  @override
  String get thesePeopleAnywhere => 'Estas personas, en cualquier lugar';

  @override
  String thesePeopleCanMessageArg1In(Object? arg1) {
    return 'Estas personas pueden enviar mensajes a $arg1 en chats privados y en cualquier grupo que compartan.';
  }

  @override
  String thesePeopleCanMessageArg1One(Object? arg1) {
    return 'Estas personas pueden enviar mensajes a $arg1 uno a uno. Esto no les permite hablar en grupo.';
  }

  @override
  String thesePeopleCanOnlyMessageArg1(Object? arg1) {
    return 'Estas personas solo pueden enviar mensajes a $arg1 en el grupo que hayas elegido.';
  }

  @override
  String get thesePeopleInOneGroup => 'Estas personas, en un grupo';

  @override
  String get theseSwitchesNeverYourChatsMemories =>
      'estos interruptores, nunca tus chats, recuerdos o archivos.';

  @override
  String get thisAccountWillUnlockNeoagentOn =>
      'Esta cuenta desbloqueará NeoAgent en esta máquina.';

  @override
  String get thisAgentCanDelegateToAny =>
      'Este agente puede delegar en cualquier agente receptor elegible.';

  @override
  String get thisAgentIsUsingAServer =>
      'Este agente utiliza una clave API de Trello administrada por el servidor. Solo necesita autorizar un token de cuenta a continuación.';

  @override
  String get thisBuildIsNotAllowedTo =>
      'Esta compilación no puede comunicarse con esta implementación de NeoAgent.';

  @override
  String thisCodeBelongsToADifferent(Object? arg1) {
    return 'Este código pertenece a un servidor NeoAgent diferente: $arg1';
  }

  @override
  String get thisDesktopIsConnected => 'Este escritorio está conectado';

  @override
  String get thisDevice => 'este dispositivo';

  @override
  String thisDeviceArg1(Object? arg1) {
    return 'Este dispositivo: $arg1';
  }

  @override
  String get thisDeviceCannotRegisterSecurityKeys =>
      'Este dispositivo no puede registrar claves de seguridad. Abra NeoAgent en un navegador a través de HTTPS para agregar uno.';

  @override
  String get thisDeviceUnavailable => 'Este dispositivo: no disponible';

  @override
  String get thisFileHasNoContent => 'Este archivo no tiene contenido.';

  @override
  String thisHidesArg1FromRoutingAnd(Object? arg1) {
    return 'Esto oculta \"$arg1\" del enrutamiento y la selección.';
  }

  @override
  String get thisIntegrationCurrentlySupportsOneConnected =>
      'Esta integración actualmente admite una cuenta conectada por agente. Vuelva a abrir la configuración para reemplazarla.';

  @override
  String get thisIntegrationIsNoLongerAvailable =>
      'Esta integración ya no está disponible.';

  @override
  String get thisIntroIsDesignedForFull =>
      'Esta introducción está diseñada para reproducción horizontal en pantalla completa.';

  @override
  String get thisIsAManagedDeploymentIts =>
      'Esta es una implementación administrada. Su operador se despliega ';

  @override
  String get thisMayTakeAMoment => 'Esto puede tardar un momento.';

  @override
  String get thisMcpServerIsNoLonger =>
      'Este servidor MCP ya no está configurado.';

  @override
  String get thisMemoryWillBeRemovedPermanently =>
      'Esta memoria se eliminará permanentemente.';

  @override
  String get thisNeoagentBuildIsNotConfigured =>
      'Esta compilación de NeoAgent no está configurada para verificar los tiempos de ejecución del backend.';

  @override
  String get thisPermanentlyErasesAllOfYour =>
      'Esto borra permanentemente todos sus datos y no se puede ';

  @override
  String get thisPermanentlyErasesTheAccountAnd =>
      'Esto borra permanentemente la cuenta y todo lo que posee: ';

  @override
  String get thisPersonAnywhere => 'Esta persona, en cualquier lugar';

  @override
  String get thisPersonInOneGroup => 'Esta persona, en un grupo.';

  @override
  String get thisQrLoginRequestExpiredGenerate =>
      'Esta solicitud de inicio de sesión QR expiró. Genera un nuevo código e inténtalo de nuevo.';

  @override
  String get thisQrLoginRequestHasExpired =>
      'esta solicitud de inicio de sesión qr ha caducado';

  @override
  String get thisQrLoginRequestIsStill =>
      'Esta solicitud de inicio de sesión QR todavía está esperando aprobación.';

  @override
  String get thisQrLoginRequestWasAlready =>
      'Esta solicitud de inicio de sesión QR ya se utilizó.';

  @override
  String get thisRemovesTheHomeAssistantSetup =>
      'Esto elimina la configuración de Home Assistant y la instancia conectada para este agente.';

  @override
  String get thisRemovesTheNeorecallBackendUrl =>
      'Esto elimina la URL de backend de NeoRecall y todas las cuentas de NeoRecall conectadas para este agente.';

  @override
  String get thisRemovesTheNextcloudUrlAnd =>
      'Esto elimina la URL de Nextcloud y todas las cuentas de Nextcloud conectadas para este agente.';

  @override
  String get thisRemovesTheTrelloSetupAnd =>
      'Esto elimina la configuración de Trello y las cuentas conectadas para este agente.';

  @override
  String get thisRequiresAnAuthenticatedSessionOn =>
      'Esto requiere una sesión autenticada en el mismo servidor NeoAgent.';

  @override
  String get thisRunDidNotProduceA =>
      'Esta ejecución no produjo una respuesta del usuario.';

  @override
  String get thisRunHasNoRecordedStep =>
      'Esta ejecución no tiene datos de pasos registrados.';

  @override
  String get thisServer => 'este servidor.';

  @override
  String get thisServerReportsNoProviderSettings =>
      'Este servidor no informa ninguna configuración de proveedor.';

  @override
  String get thisSkillIsNoLongerInstalled =>
      'Esta habilidad ya no está instalada.';

  @override
  String get thisTaskHasNoCompletedRun =>
      'Esta tarea aún no se ha completado, por lo que aún comienza en el ';

  @override
  String get thisTaskWillOnlyRunWhen =>
      'Esta tarea solo se ejecutará cuando presione Ejecutar ahora.';

  @override
  String get thisWeek => 'esta semana';

  @override
  String thisWillImportTheResponseInto(Object? arg1) {
    return 'Esto importará la respuesta a $arg1.';
  }

  @override
  String thisWillRemoveArg1(Object? arg1) {
    return 'Esto eliminará \"$arg1\".';
  }

  @override
  String thisWillRemoveArg1FromThe(Object? arg1) {
    return 'Esto eliminará \"$arg1\" de la lista de servidores.';
  }

  @override
  String get time => 'tiempo';

  @override
  String get timeZone => 'zona horaria';

  @override
  String get timeZone2 => 'Zona horaria';

  @override
  String timedOutArg1(Object? arg1) {
    return 'Tiempo de espera agotado$arg1';
  }

  @override
  String timezoneCouldNotListTimeZones(Object? arg1) {
    return '[TimeZone] No se pudieron enumerar las zonas horarias: $arg1';
  }

  @override
  String timezoneCouldNotReadTheDevice(Object? arg1) {
    return '[TimeZone] No se pudo leer la zona horaria del dispositivo: $arg1';
  }

  @override
  String timezoneCouldNotSaveTheDevice(Object? arg1) {
    return '[TimeZone] No se pudo guardar la zona horaria del dispositivo: $arg1';
  }

  @override
  String toArg1(Object? arg1) {
    return 'a $arg1';
  }

  @override
  String get toUseTheServerDefault =>
      'para utilizar el servidor predeterminado.';

  @override
  String get today => 'hoy';

  @override
  String tokenBudgetForArg1LeaveA(Object? arg1) {
    return 'Presupuesto simbólico para @$arg1. Dejar un campo vacío ';
  }

  @override
  String get tokenBudgetForEveryAccountWithout =>
      'Presupuesto de tokens para cada cuenta sin su propia anulación. dejar un ';

  @override
  String get tokenBudgetLimit4HourWeekly =>
      'límite de presupuesto de token usuario de cuota semanal de 4 horas';

  @override
  String get tokenBudgetLimit4HourWeekly2 =>
      'Límite de presupuesto simbólico Cuota semanal de 4 horas global';

  @override
  String get tokenUsageUnavailableOnThisServer =>
      'El uso de token no está disponible en esta versión del servidor.';

  @override
  String get tokensAnyAccountMayUseIn =>
      'Tokens que cualquier cuenta puede usar en 4 horas.';

  @override
  String get tokensAnyAccountMayUseIn2 =>
      'Tokens que cualquier cuenta puede usar en 7 días.';

  @override
  String get tokensPerDay => 'Fichas por día';

  @override
  String get tokensPerRun => 'Fichas por carrera';

  @override
  String get tokensToday => 'Fichas hoy';

  @override
  String get tokensUsed => ' fichas utilizadas';

  @override
  String get tomorrowPrep => 'mañana preparación';

  @override
  String get tooManyAttempts => 'demasiados intentos';

  @override
  String get tooManySignInAttemptsPlease =>
      'Demasiados intentos de inicio de sesión. Espere e inténtelo de nuevo.';

  @override
  String get tool => 'Herramienta';

  @override
  String get toolApproval => 'Aprobación de herramientas';

  @override
  String get toolApprovalRequired => 'Se requiere aprobación de herramienta';

  @override
  String get toolCompleted => 'Herramienta completada';

  @override
  String get toolFailed => 'Herramienta fallida';

  @override
  String get toolPermissions => 'Permisos de herramientas';

  @override
  String get toolStarted => 'Herramienta iniciada';

  @override
  String get tools => 'Herramientas';

  @override
  String get toolsNotBuiltIntoNeoagentIncluding =>
      'Herramientas no integradas en NeoAgent, incluidos servidores MCP conectados y proveedores de herramientas personalizadas.';

  @override
  String toolsOfferedArg1(Object? arg1) {
    return 'Herramientas ofrecidas ($arg1)';
  }

  @override
  String get toolsTheManagedAccountMayUse =>
      'Herramientas que la cuenta administrada puede usar';

  @override
  String get topUsers => 'Usuarios principales';

  @override
  String get topUsersAndRecentRuns =>
      'Usuarios principales y ejecuciones recientes';

  @override
  String totalArg1TokensAcrossArg2Runs(Object? arg1, Object? arg2) {
    return 'Total: tokens $arg1 en ejecuciones de $arg2';
  }

  @override
  String get totalRuns => 'Carreras totales';

  @override
  String get totalTokens => 'fichas totales';

  @override
  String get totalUsers => 'Usuarios totales';

  @override
  String get transcript => 'Transcripción';

  @override
  String get transcript2 => 'TRANSCRIPCIÓN';

  @override
  String transcriptionFailedArg1(Object? arg1) {
    return 'Error de transcripción: $arg1';
  }

  @override
  String get transfer => 'Transferir';

  @override
  String get trelloApiKey => 'Clave API de Trello';

  @override
  String get trelloApiKeyIsRequired => 'Se requiere la clave API de Trello.';

  @override
  String get trelloSetup => 'Configuración de Trello';

  @override
  String get triggerType => 'Tipo de disparador';

  @override
  String get tryABroaderSearchLikeModels =>
      'Pruebe una búsqueda más amplia, como modelos, navegador o voz.';

  @override
  String get tryAProviderNameEmailLimits =>
      'Pruebe con el nombre de un proveedor, \"correo electrónico\", \"límites\", \"actualización\" o \"registros\".';

  @override
  String get tryAgain => 'Inténtalo de nuevo';

  @override
  String get tryAgainIfThisKeepsHappening =>
      'Inténtalo de nuevo. Si esto continúa sucediendo, ejecute NeoAgent Doctor para verificar el tiempo de ejecución de la computadora.';

  @override
  String get tryAgainInAMoment => 'Inténtalo de nuevo en un momento.';

  @override
  String get tryAgainOrRunNeoagentDoctor =>
      'Inténtelo de nuevo o ejecute NeoAgent Doctor.';

  @override
  String get tryAnotherSearchConnectAMessaging =>
      'Intente otra búsqueda, conecte una plataforma de mensajería o ingrese una ID de destino manualmente.';

  @override
  String turnAGroupOnIfArg1(Object? arg1) {
    return 'Active un grupo si $arg1 también debe leer mensajes que no lo etiquetan.';
  }

  @override
  String get turnOffComputer => 'Apagar la computadora';

  @override
  String get turnOffOnlyForAMail =>
      'Desactívelo solo para un servidor de correo con un certificado autofirmado.';

  @override
  String get turnOnIfSignalShouldKeep =>
      'Actívalo si Signal debe seguir buscando chats entrantes.';

  @override
  String get turnTaking => 'tomar turnos';

  @override
  String get turnTakingModel => 'Modelo de turnos';

  @override
  String get turnTakingOff => 'Desvío';

  @override
  String get turnThisOffToKeepThis =>
      'Desactívelo para mantener este agente completamente separado de otros agentes.';

  @override
  String turnedOffByArg1(Object? arg1) {
    return 'Apagado por $arg1';
  }

  @override
  String turnedOffByArg1WhoManages(Object? arg1) {
    return 'Desactivado por $arg1, quien administra esta cuenta. ';
  }

  @override
  String turnedOffForYouByArg1(Object? arg1) {
    return 'Desactivado para usted por $arg1: solo ellos pueden cambiarlo';
  }

  @override
  String get turnedOffForYouSoYou =>
      'Apagado para ti, por lo que no puedes repartirlo.';

  @override
  String get twitchChatOverIrc => 'Chat de Twitch a través de IRC';

  @override
  String get twoFactorAuthentication => 'Autenticación de dos factores';

  @override
  String get twoFactorChallengeExpired => 'El desafío de dos factores expiró.';

  @override
  String get twoFactorCode => 'código de dos factores';

  @override
  String get twoFactorSignInCompletedBut =>
      'Se completó el inicio de sesión de dos factores, pero NeoAgent no pudo mantener la sesión del navegador. Por favor inicia sesión nuevamente.';

  @override
  String get twoStepLoginOnlyIfEnabled =>
      'Inicio de sesión en dos pasos (solo si está habilitado)';

  @override
  String get type => 'Tipo';

  @override
  String typeArg1ToConfirm(Object? arg1) {
    return 'Escriba $arg1 para confirmar';
  }

  @override
  String get typeTextIsNotSupportedOn =>
      'escribir texto no es compatible con esta plataforma.';

  @override
  String get typedInTheBrowser => 'Escrito en el navegador';

  @override
  String get typedText => 'Texto escrito';

  @override
  String get uCreatedAtULastLogin => '       u.created_at, u.last_login,\n';

  @override
  String get unableToLocateAJavaRuntime =>
      'no se puede localizar un tiempo de ejecución de Java';

  @override
  String get unableToOpenTimeSettingsOn =>
      'No se pueden abrir las configuraciones de tiempo en esta compilación.';

  @override
  String get unableToOpenWiFiSettings =>
      'No se puede abrir la configuración de Wi-Fi en esta compilación.';

  @override
  String get unableToPersistTheSelectedDesktop =>
      'No se puede conservar la visualización del escritorio seleccionado.';

  @override
  String get unclearWhoItWasFor => 'No está claro para quién era';

  @override
  String get undoneTypeYourUsernameToConfirm =>
      'deshecho. Escriba su nombre de usuario para confirmar.';

  @override
  String get unknownAccount => 'Cuenta desconocida';

  @override
  String get unknownAgent => 'Agente desconocido';

  @override
  String get unknownBrowser => 'Navegador desconocido';

  @override
  String get unknownDevice => 'Dispositivo desconocido';

  @override
  String get unknownError => 'error desconocido';

  @override
  String get unknownLocalComputerPermission =>
      'Permiso de computadora local desconocido.';

  @override
  String get unknownLocation => 'Ubicación desconocida';

  @override
  String get unknownPublishTime => 'Hora de publicación desconocida';

  @override
  String get unknownSize => 'Tamaño desconocido';

  @override
  String get unlink => 'Desvincular';

  @override
  String get unreadOnly => 'Sólo sin leer';

  @override
  String get unsavedChanges => 'Cambios no guardados';

  @override
  String unsupportedDesktopCompanionCommandArg1(Object? arg1) {
    return 'Comando complementario de escritorio no compatible: $arg1';
  }

  @override
  String unsupportedMethodArg1(Object? arg1) {
    return 'Método no compatible: $arg1';
  }

  @override
  String get unusualSignInAlerts => 'Alertas de inicio de sesión inusuales';

  @override
  String updateArg1(Object? arg1) {
    return 'Actualización $arg1';
  }

  @override
  String get updateCoreMemoryEntriesFromThe =>
      'Actualice las entradas de la memoria central desde la importación.';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updateReady => 'Actualización lista';

  @override
  String get updateSetup => 'Configuración de actualización';

  @override
  String get updateTheAccessListToAllow =>
      'Actualice la lista de acceso para permitir respuestas.';

  @override
  String get updateTheServer => '¿Actualizar el servidor?';

  @override
  String get updateTheServer2 => 'Actualizar el servidor';

  @override
  String get updateTheTimeZoneAutomaticallyFrom =>
      'Actualiza la zona horaria automáticamente desde el dispositivo que estés utilizando.';

  @override
  String updatedArg1(Object? arg1) {
    return 'actualizado $arg1';
  }

  @override
  String get updates => 'Actualizaciones';

  @override
  String get updatesAreNotConfiguredForThis =>
      'Las actualizaciones no están configuradas para esta compilación.';

  @override
  String get updatesSoSelfUpdateAndChannel =>
      'actualizaciones, por lo que la actualización automática y los cambios de canal están desactivados aquí.';

  @override
  String get upgradeUpdateNowReleaseChannelStable =>
      'actualizar actualizar ahora lanzar canal beta estable';

  @override
  String get usageAnalytics => 'Análisis de uso';

  @override
  String get usageAndHealthSignalsThatHelp =>
      'Señales de uso y estado que ayudan a explicar el comportamiento actual en tiempo de ejecución sin tener que buscar primero en los registros.';

  @override
  String usageFullyResetsInArg1(Object? arg1) {
    return 'El uso se restablece completamente en $arg1';
  }

  @override
  String get usageLeaderboard => 'tabla de clasificación de uso';

  @override
  String get usageLimits => 'Uso y límites';

  @override
  String get usageLimits2 => 'Uso y límites';

  @override
  String get use8CharactersLongerPassphrasesWork =>
      'Utilice más de 8 caracteres. Las frases de contraseña más largas funcionan bien.';

  @override
  String get useADateAndTimeFor =>
      'Utilice una fecha y hora, por ejemplo 2026-07-03T09:00:00.';

  @override
  String get useANamePhoneNumberOr =>
      'Utilice un nombre, número de teléfono o ID de chat.';

  @override
  String get useANeorecallUrlTheNeoagent =>
      'Utilice una URL de NeoRecall a la que pueda acceder el servidor NeoAgent. También se debe poder acceder a PUBLIC_URL de NeoAgent desde este navegador para la devolución de llamada de OAuth.';

  @override
  String get useANewPasswordWithAt =>
      'Utilice una nueva contraseña con al menos 8 caracteres.';

  @override
  String get useANextcloudUrlTheNeoagent =>
      'Utilice una URL de Nextcloud a la que pueda acceder el servidor NeoAgent, por ejemplo https://cloud.example.com.';

  @override
  String get useAPasswordWithAtLeast =>
      'Utilice una contraseña con al menos 8 caracteres.';

  @override
  String get useASecureConnectionTls => 'Utilice una conexión segura (TLS)';

  @override
  String get useAnAuthenticatorAppSuchAs =>
      'Utilice una aplicación de autenticación como Authy, 1Password o Google Authenticator.';

  @override
  String get useAtLeast1Vcpu => 'Utilice al menos 1 vCPU.';

  @override
  String get maxMemoryPerComputerMb => 'Memoria máxima por computadora (MB)';

  @override
  String get maxVcpusPerComputer => 'Máximo de vCPU por computadora';

  @override
  String atLeastArg1ComputersGetLess(Object? arg1) {
    return 'Al menos $arg1. Las computadoras obtienen menos energía cuando el host está ocupado.';
  }

  @override
  String maxMemoryMustBeAtLeastArg1Mb(Object? arg1) {
    return 'La memoria máxima debe ser de al menos $arg1 MB.';
  }

  @override
  String get useAtLeast8Characters => 'Utilice al menos 8 caracteres.';

  @override
  String get useDefault => 'Usar predeterminado';

  @override
  String get useDefaultChannel => 'Usar canal predeterminado';

  @override
  String get useDefaultNeoagentWorkspace =>
      'Usar valor predeterminado (NeoAgent Workspace)';

  @override
  String get useFor => 'Usar para';

  @override
  String get useManualDestination => 'Usar destino manual';

  @override
  String get useOrDoTheSameFor =>
      'usa, o haz lo mismo con tus compañeros de equipo.';

  @override
  String get usePerCategorySettingsBelow =>
      'Utilice la configuración por categoría a continuación.';

  @override
  String useSettingsDefaultArg1(Object? arg1) {
    return 'Usar configuración predeterminada ($arg1)';
  }

  @override
  String get useTheServerOnThisComputer =>
      'Utilice el servidor en esta computadora';

  @override
  String get useTheseForContextIfA =>
      'Úselos para el contexto. Si no se puede acceder directamente a un URI local desde el servidor, pídame que proporcione el archivo a través de un espacio de trabajo accesible.';

  @override
  String get useThisForOrchestratorAgentsLeave =>
      'Utilice esto para agentes orquestadores. Déjelo para los robots de trabajo aislados que deberían finalizar ellos mismos los mensajes directos.';

  @override
  String get useTlsFromTheStartOf =>
      'Utilice TLS desde el inicio de la conexión, normalmente en el puerto 465.';

  @override
  String get useYourOwnApiKeyFor =>
      'Utilice su propia clave API para un proveedor o conecte una personalizada ';

  @override
  String get usedByEveryAccountOnThis =>
      'Utilizado por todas las cuentas en este servidor que no tienen clave ';

  @override
  String get usedToVerifyThatIncomingSlack =>
      'Se utiliza para verificar que los eventos entrantes de Slack sean genuinos.';

  @override
  String get userSummary => 'Resumen de usuario';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get usernameOrEmail => 'Nombre de usuario o correo electrónico';

  @override
  String get usersPeopleSearchEmailUsernameAdmin =>
      'usuarios personas buscar correo electrónico nombre de usuario insignia de administrador equipo administrado';

  @override
  String get usesTheChatModelConfiguredIn =>
      'Utiliza el modelo de chat configurado en Configuración';

  @override
  String get usingTheInstalledNeoagentRuntime =>
      'Usando el tiempo de ejecución de NeoAgent instalado';

  @override
  String get usuallyLooksLikeBotMatrixOrg =>
      'Generalmente se parece a @bot:matrix.org';

  @override
  String get validEmail => 'correo electrónico válido';

  @override
  String get value => 'Valor';

  @override
  String get vaultLocked => 'Bóveda bloqueada';

  @override
  String get vaultOperationFailed => 'La operación de la bóveda falló.';

  @override
  String get verification => 'Verificación';

  @override
  String verificationArg1(Object? arg1) {
    return 'Verificación: $arg1';
  }

  @override
  String verificationArg12(Object? arg1) {
    return 'verificación: $arg1';
  }

  @override
  String get verificationCompleted => 'Verificación completada.';

  @override
  String verificationStatusArg1(Object? arg1) {
    return 'Estado de verificación: $arg1';
  }

  @override
  String get verifiedTheResult => 'Verificado el resultado';

  @override
  String get verifyingTheDownloadedRuntime =>
      'Verificando el tiempo de ejecución descargado';

  @override
  String get versionAndUptime => 'Versión y tiempo de actividad';

  @override
  String versionArg1(Object? arg1) {
    return 'Versión $arg1';
  }

  @override
  String versionArg1IsInstalledButArg2(Object? arg1, Object? arg2) {
    return 'La versión $arg1 está instalada, pero $arg2 aún se está ejecutando.';
  }

  @override
  String get videoLinks => 'Enlaces de vídeo';

  @override
  String get viewDesktop => 'Ver escritorio';

  @override
  String get viewLastRun => 'Ver la última ejecución';

  @override
  String get viewLogs => 'Ver registros';

  @override
  String get vmImageMemoryCpuQemuRuntime =>
      'vm imagen memoria cpu qemu tiempo de ejecución';

  @override
  String get voice => 'Voz';

  @override
  String get voiceAssistant => 'asistente de voz';

  @override
  String get voiceCall => 'LLAMADA DE VOZ';

  @override
  String get voiceCall2 => 'llamada de voz';

  @override
  String get voiceCallGptLiveGeminiLive =>
      'llamada de voz gpt-live gemini modelo en vivo discurso en tiempo real';

  @override
  String get voiceCallsRunOnALive =>
      'Las llamadas de voz se ejecutan en un modelo de voz a voz en vivo con la misma persona, memoria e historial de chat que NeoAgent. Responde de inmediato y entrega el trabajo real al agente normal, que sigue ejecutándose en segundo plano.';

  @override
  String get voiceNoteSpeechTranscriptionApiKey =>
      'clave de API de transcripción de voz y notas de voz';

  @override
  String get voiceNotesAndDictation => 'Notas de voz y dictado.';

  @override
  String get voicePlaybackIsUnavailableOnThis =>
      'La reproducción de voz no está disponible en este dispositivo.';

  @override
  String get voiceReplyModel => 'Modelo de respuesta de voz';

  @override
  String get waitingForApproval => 'Esperando aprobación: ';

  @override
  String get waitingForCode => 'esperando codigo';

  @override
  String get waitingForInput => 'Esperando entrada';

  @override
  String get waitingForServerOrFlutterLog =>
      'Esperando la salida del registro del servidor o de Flutter...';

  @override
  String get waitingForTaskEvents => 'Esperando eventos de tareas...';

  @override
  String get waitingForYou => 'esperando por ti';

  @override
  String wantedAReplyFromArg1(Object? arg1) {
    return 'Quería una respuesta de $arg1';
  }

  @override
  String wantsToTalkWithYouArg1(Object? arg1) {
    return 'Quiere hablar contigo · ${arg1}s';
  }

  @override
  String get weak => 'Débil';

  @override
  String get weatherCalendarAndPrioritiesBeforeYour =>
      'Clima, calendario y prioridades antes de que comience el día.';

  @override
  String get weatherEvent => 'Evento meteorológico';

  @override
  String get web => 'Web';

  @override
  String get webBrowser => 'navegador web';

  @override
  String get webSearchApiKey => 'clave API de búsqueda web';

  @override
  String get webhookOrRestChannelPosting =>
      'Publicación de webhook o canal REST';

  @override
  String get webhookSecret => 'secreto del webhook';

  @override
  String get webhookUrlCopied => 'URL del webhook copiada';

  @override
  String get weekdays => 'Días laborables';

  @override
  String get weekdays0730 => 'Laborables · 07:30';

  @override
  String get weekdays1800 => 'Laborables · 18:00';

  @override
  String get weekly => 'Semanal';

  @override
  String weeklyLimitArg1(Object? arg1) {
    return 'Límite semanal $arg1';
  }

  @override
  String get weeklyLimitTokens => 'Límite semanal (tokens)';

  @override
  String get weeklyReview => 'revisión semanal';

  @override
  String get weeklyUsage => 'Uso semanal';

  @override
  String weightArg1Records(Object? arg1) {
    return 'Registros de peso $arg1';
  }

  @override
  String get welcomeToNeoagent => 'BIENVENIDO A NEOAGENTE';

  @override
  String get welcomeToNeoagent2 => 'Bienvenido\na NeoAgent';

  @override
  String get whatAreYouAdding => '¿Qué estás agregando?';

  @override
  String get whatIsOnTomorrow => '¿Qué hay mañana?';

  @override
  String get whatShouldNeoagentLearn => '¿Qué debería aprender NeoAgent?';

  @override
  String get whatShouldWeBuild => '¿Qué deberíamos construir?';

  @override
  String get whatYouAndNeoagentSayAppears =>
      'Lo que tú y NeoAgent dicen aparece aquí y en el chat.';

  @override
  String get whatsappPersonalMessageReceived =>
      'Mensaje personal de WhatsApp recibido';

  @override
  String get whenYouChooseApprovedOnlyAdd =>
      'Cuando elijas solo aprobado, agrega personas o grupos a continuación.';

  @override
  String get whereCreatedAtDatetimeNow30 =>
      'WHERE created_at >= datetime(\'\'now\'\', \'\'-30 days\'\')\n';

  @override
  String get whereRStatusFailed => 'WHERE r.status = \'\'failed\'\'\n';

  @override
  String get whereSRevokedAtIsNull => 'WHERE s.revoked_at IS NULL\n';

  @override
  String get whereThisAgentShouldSendReplies =>
      'Dónde este agente debe enviar respuestas.';

  @override
  String get whoCanMessage => '¿Quién puede enviar mensajes?';

  @override
  String whoCanMessageOnArg1(Object? arg1) {
    return '¿Quién puede enviar mensajes en $arg1?';
  }

  @override
  String whoCanSendArg1AOne(Object? arg1) {
    return '¿Quién puede enviar a $arg1 un mensaje individual?';
  }

  @override
  String whoCanTalkToArg1In(Object? arg1) {
    return 'Quién puede hablar con $arg1 en un grupo, canal o sala.';
  }

  @override
  String get whoManagesThisAccountTurnedOff =>
      'quién administra esta cuenta desactivada: ';

  @override
  String get whoManagesWhom => 'quien maneja a quien';

  @override
  String get whoeverAcceptsALinkJoinsYour =>
      'Quien acepte un enlace se une a tu equipo sólo con las herramientas que ';

  @override
  String get wholeGroup => 'Todo el grupo';

  @override
  String get wholeGroups => 'Grupos enteros';

  @override
  String whyArg1RepliedOrStayedQuiet(Object? arg1, Object? arg2) {
    return 'Por qué $arg1 respondió o se quedó callado en los grupos de $arg2.';
  }

  @override
  String get windowsApp => 'aplicación de Windows';

  @override
  String get windowsNt => 'windows nt';

  @override
  String get workAccount => 'cuenta de trabajo';

  @override
  String get workOnAProjectWithNeoagent =>
      'Trabajar en un proyecto con NeoAgent';

  @override
  String workflowArg1(Object? arg1) {
    return 'Flujo de trabajo: $arg1';
  }

  @override
  String workingInArg1OnTheCloud(Object? arg1) {
    return 'Trabajando en $arg1 en la computadora en la nube. NeoAgent lee y edita archivos allí y puede ejecutar comandos y un navegador.';
  }

  @override
  String workingInTheBackgroundArg1(Object? arg1) {
    return 'Trabajando en segundo plano: $arg1';
  }

  @override
  String get workspaceConfigurationAndAccountSecurityIn =>
      'Configuración del espacio de trabajo y seguridad de la cuenta en un solo lugar.';

  @override
  String get workspaceFiles => 'Archivos de espacio de trabajo';

  @override
  String get workspaceModelsAndDiagnosticsControls =>
      'Controles de espacio de trabajo, modelos y diagnóstico.';

  @override
  String get workspaceOverrideMustBeAnAbsolute =>
      'La anulación del espacio de trabajo debe ser una ruta absoluta.';

  @override
  String wroteArg1(Object? arg1) {
    return 'Escribió $arg1';
  }

  @override
  String get xaiOauth => 'xAI (OAuth)';

  @override
  String get xmlhttprequestError => 'error de solicitud xmlhttp';

  @override
  String get yesterday => 'ayer';

  @override
  String get youAreInControl => 'tu estas en control';

  @override
  String get youCanFollowAlongOnThe => 'Puedes seguirlo en el escritorio.';

  @override
  String get youCanLeaveATeamAt =>
      'Puedes abandonar un equipo en cualquier momento; sus propios ajustes se aplican nuevamente.';

  @override
  String get youCanLeaveAtAnyTime =>
      'Puedes salir en cualquier momento desde la página del Equipo.';

  @override
  String get youDecideWhichToolsYourAgent =>
      'Usted decide qué herramientas puede usar su agente, en Configuración › ';

  @override
  String get youDonTManageAnyoneYet =>
      'Aún no diriges a nadie. Cree un enlace de invitación a continuación y ';

  @override
  String get youHaveUnsavedSettingsWhatWould =>
      'Tienes configuraciones no guardadas. ¿Qué te gustaría hacer?';

  @override
  String get youReOnYourOwnYou =>
      'Usted está solo: usted decide qué herramientas puede utilizar su agente. si ';

  @override
  String get yourAccountAndUsageOnA =>
      'su cuenta y uso en un modelo respaldado por su propia clave ';

  @override
  String get yourAccountHasBeenDeleted => 'Tu cuenta ha sido eliminada.';

  @override
  String get yourAgentWillBeAllowed => 'Su agente podrá:';

  @override
  String get yourAppsAndFilesAreSaved =>
      'Tus aplicaciones y archivos se guardan.';

  @override
  String get yourAppsAndFilesRemainSaved =>
      'Tus aplicaciones y archivos permanecen guardados.';

  @override
  String yourArg1Key(Object? arg1) {
    return 'Tu clave $arg1';
  }

  @override
  String get yourAssistantLayerForCaptureContext =>
      'Su capa asistente para captura, contexto y acción.';

  @override
  String get yourComputerIsAsleep => 'Tu computadora está dormida';

  @override
  String get yourComputerIsOff => 'Tu computadora esta apagada';

  @override
  String get yourComputerIsReady => 'Tu computadora está lista';

  @override
  String get yourCurrentPasswordIsIncorrect =>
      'Su contraseña actual es incorrecta.';

  @override
  String get yourData => 'Tus datos';

  @override
  String get yourDataExportWasCopiedTo =>
      'Su exportación de datos se copió al portapapeles.';

  @override
  String get yourDesktopIsReady => 'Tu escritorio está listo';

  @override
  String get yourLinuxComputer => 'Tu computadora Linux';

  @override
  String get yourLocationIsNeverTrackedContinuously =>
      'Su ubicación nunca se rastrea continuamente ni se almacena en nuestros servidores. Solo lo usamos localmente para comparar sus tareas activas.';

  @override
  String get yourManager => 'tu gerente';

  @override
  String get yourMattermostSiteUrlIfYou =>
      'La URL de su sitio Mattermost, si utiliza la API REST.';

  @override
  String get yourSessionExpiredOrWasNot =>
      'Su sesión expiró o el navegador no la retuvo. Por favor inicia sesión nuevamente.';

  @override
  String get yourSessionExpiredPleaseSignIn =>
      'Tu sesión expiró. Por favor inicia sesión nuevamente.';

  @override
  String get yourUsernameOrPasswordIsIncorrect =>
      'Su nombre de usuario o contraseña es incorrecto.';

  @override
  String get yubikeyMacbookTouchId => 'YubiKey, ID táctil de MacBook,…';

  @override
  String get yubikeyOtp => 'OTP de YubiKey';

  @override
  String get zaloPersonal => 'Zalo Personal';

  @override
  String get sectionOverview => 'Descripción general';

  @override
  String get sectionDiagnostics => 'Diagnóstico';

  @override
  String get sectionVolume => 'Volumen';

  @override
  String get sectionSession => 'Sesión';

  @override
  String get sectionDeliverable => 'Entregable';

  @override
  String get theLocalRuntimeHasNotWrittenA =>
      'El tiempo de ejecución local aún no ha escrito un archivo de registro.';

  @override
  String get thisComputer => 'esta computadora';

  @override
  String get betaInstallsTheNewestPrereleaseBackendExpect =>
      'Beta instala el backend preliminar más reciente. Espere asperezas.';

  @override
  String get copiedFinalResponse => 'Respuesta final copiada';

  @override
  String get theFinalResponseAppearsHereWhenThe =>
      'La respuesta final aparece aquí cuando finaliza la ejecución.';

  @override
  String get waitingForTheFirstStep => 'Esperando el primer paso...';

  @override
  String get loadingPrompt => 'Cargando aviso…';

  @override
  String get noFinalResponseWasCapturedForThis =>
      'No se obtuvo ninguna respuesta final para esta ejecución.';

  @override
  String get readyToSignIn => 'Listo para iniciar sesión';

  @override
  String get switchToDefaultOrAlwaysAskTo =>
      'Cambie a \"Predeterminado\" o \"Preguntar siempre\" para volver a habilitar las comprobaciones de aprobación.';

  @override
  String get sendASteeringUpdateOrNextUp =>
      'Enviar una actualización de dirección o una nota siguiente para la ejecución actual...';

  @override
  String get noNetworkConnectionNeoagentWillReconnectWhen =>
      'Sin conexión de red. NeoAgent se volverá a conectar cuando el dispositivo vuelva a estar en línea.';

  @override
  String get appliedTheLatestSteeringUpdateToThe =>
      'Se aplicó la última actualización de dirección a la ejecución actual.';

  @override
  String get preparingThePrivateVoiceSession =>
      'Preparando la sesión de voz privada…';

  @override
  String get preparingYourComputer => 'Preparando tu computadora';

  @override
  String get neoagentIsDownloadingAndPreparingTheSecure =>
      'NeoAgent está descargando y preparando el sistema Linux seguro. Esto sólo sucede la primera vez.';

  @override
  String get moreFreeSpaceIsNeeded => 'Se necesita más espacio libre';

  @override
  String get freeSomeDiskSpaceOnTheNeoagent =>
      'Libere algo de espacio en disco en el host de NeoAgent y vuelva a intentarlo. Los datos de su computadora existente están seguros.';

  @override
  String get androidReady => 'Android listo';

  @override
  String get startingAndroid2 => 'Iniciando Android…';

  @override
  String get androidStopped => 'Android se detuvo';

  @override
  String get theFirstStartDownloadsTheAndroidSdk =>
      'El primer inicio descarga el SDK de Android y la imagen del sistema, lo que puede tardar varios minutos.';

  @override
  String get androidIsStopped => 'Android está detenido';

  @override
  String get startTheManagedAndroidEnvironmentWhenYou =>
      'Inicie el entorno Android administrado cuando lo necesite.';

  @override
  String get letNeoagentWorkOnThisComputer =>
      'Deje que NeoAgent funcione en esta computadora';

  @override
  String get firstTimeSetupIsInProgress =>
      'La configuración por primera vez está en progreso.';

  @override
  String get neoagentCanUseTheAccessYouAllow =>
      'NeoAgent puede utilizar el acceso que usted permita.';

  @override
  String get freeSomeHostStorageAndTryAgain =>
      'Libere algo de almacenamiento del host y vuelva a intentarlo.';

  @override
  String get startWhenYouWantNeoagentToHelp =>
      'Comience cuando quiera que NeoAgent le ayude aquí.';

  @override
  String get systemPermissionMissing => 'Falta el permiso del sistema';

  @override
  String get connectingThisDevice => 'Conectando este dispositivo';

  @override
  String get theSecureLocalConnectionIsBeingEstablished =>
      'Se está estableciendo la conexión local segura.';

  @override
  String get recordingYourDemonstration => 'Grabando su demostración';

  @override
  String get noErrorsInTheRecentLog =>
      'No hay errores en el registro reciente.';

  @override
  String get loadingAccounts => 'Cargando cuentas…';

  @override
  String get neverSignedIn => 'Nunca inicie sesión';

  @override
  String get emptyUsesTheServerDefault =>
      'Vacío utiliza el valor predeterminado del servidor.';

  @override
  String get followTheSelectedSession => 'Sigue la sesión seleccionada';

  @override
  String get planModeInspectsOnlySwitchToAgent =>
      'El modo de planificación sólo inspecciona. Cambie al modo Agente para permitir que NeoAgent edite archivos.';

  @override
  String get requiredToAddOrChangeYourAccount =>
      'Requerido para agregar o cambiar el correo electrónico de su cuenta.';

  @override
  String get confirmNewPassword => 'Confirmar nueva contraseña';

  @override
  String get passwordChanged => 'Contraseña cambiada.';

  @override
  String get thisRequestHasAlreadyBeenUsed =>
      'Esta solicitud ya ha sido utilizada.';

  @override
  String get thisRequestHasExpiredAskTheOther =>
      'Esta solicitud ha caducado. Pídale al otro dispositivo que genere un nuevo código.';

  @override
  String get startQuickstart => 'Iniciar inicio rápido';

  @override
  String get createYourAccount => 'Crea tu cuenta';

  @override
  String get showWorkAsSummaries => 'Mostrar trabajos como resúmenes';

  @override
  String get tokensUsedByTheLatestRun =>
      'Tokens utilizados por la última ejecución';

  @override
  String get listedTheWorkspaceRoot => 'Enumeró la raíz del espacio de trabajo';

  @override
  String get noOfficialIntegrationsAreAvailableYet =>
      'Aún no hay integraciones oficiales disponibles.';

  @override
  String get noMcpServersConfiguredYetAddOne =>
      'Aún no hay servidores MCP configurados. Agregue uno para exponer sus herramientas.';

  @override
  String get addAnMcpServerOrInstallA =>
      'Agregue un servidor MCP o instale una habilidad para comenzar.';

  @override
  String get setUp => 'configurar';

  @override
  String get leaveBlankToKeepTheStoredValue =>
      'Déjelo en blanco para mantener el valor almacenado.';

  @override
  String get thisRemovesTheAddressForEveryAccount =>
      'Esto elimina la dirección de cada cuenta en este servidor.';

  @override
  String get justTalkYouCanInterruptAtAny =>
      'Sólo habla. Puedes interrumpir en cualquier momento. Toque para silenciar.';

  @override
  String get tapAgainWhenYouAreDone =>
      'Toque nuevamente cuando haya terminado.';

  @override
  String get workingOnATaskInTheBackground =>
      'Trabajando en una tarea en segundo plano.';

  @override
  String get speechToSpeechWithTheSameMemory =>
      'Habla a voz con la misma memoria, herramientas e historial de chat que NeoAgent.';

  @override
  String get checkLink => 'Ver enlace';

  @override
  String get yourAgentWillNotBeAllowedAny =>
      'A su agente no se le permitirá ninguna de las herramientas controladas.';

  @override
  String get notYoursToChange => 'No es tuyo para cambiar';

  @override
  String get setByYou => 'establecido por ti';

  @override
  String get noTools => 'Sin herramientas';

  @override
  String get untitledLink => 'Enlace sin título';

  @override
  String get stopsWorkingAfterOnePersonRedeemsIt =>
      'Deja de funcionar después de que una persona lo canjea.';

  @override
  String get theOperator => 'el operador';

  @override
  String get smartSelectorOn => 'Selector inteligente activado';

  @override
  String get startASessionToBegin => 'Iniciar una sesión para comenzar';

  @override
  String get steerTheActiveRun => 'Dirige la carrera activa...';

  @override
  String get describeWhatToPlan => 'Describe qué planear...';

  @override
  String get stopDictation => 'detener el dictado';

  @override
  String get messagesSteerTheCurrentRunSendStop =>
      'Los mensajes dirigen la ejecución actual · ⌘↵ enviar · ⌘. detenerse';

  @override
  String get planModeInspectsOnlyNothingIsChanged =>
      'El modo de planificación sólo inspecciona; nada cambia hasta que implementes · ⌘↵ enviar';

  @override
  String get agentEditsTheWorkspacePlanOnlyInspects =>
      'El agente edita el espacio de trabajo. El plan solo inspecciona.';

  @override
  String get defaultModel => 'Modelo predeterminado';

  @override
  String get openingScanner => 'Abriendo escáner...';

  @override
  String get theAgentCanUseThisSkill =>
      'El agente puede utilizar esta habilidad.';

  @override
  String get allSelected => 'Todos los seleccionados';

  @override
  String get addCoreMemoryEntry => 'Agregar entrada de memoria central';

  @override
  String get channelId => 'ID de canal';

  @override
  String get aiCreatedAndUnspecifiedTasksUseThe =>
      'Las tareas creadas por IA y las no especificadas utilizan el valor predeterminado actual.';

  @override
  String get waitingForRunEvents => 'Esperando eventos de ejecución...';

  @override
  String get hideSteps => 'Ocultar pasos';

  @override
  String get commitTheActiveLiveCapture =>
      'Confirmar la captura en vivo activa';

  @override
  String get stopCaptureAndSubmit => 'Detener captura y enviar';

  @override
  String get clickTheMicToStartSpeaking =>
      'Haz clic en el micrófono para empezar a hablar.';

  @override
  String get connectACustomEndpoint => 'Conecte un punto final personalizado';

  @override
  String get hostedProvider => 'proveedor alojado.';

  @override
  String get muted => ' • silenciado';

  @override
  String get addWhoCanMessage => 'Agregar quién puede enviar mensajes';

  @override
  String get joinsGroupConversations => 'Se une a conversaciones grupales';

  @override
  String get label1PersonOrGroupAdded => '1 persona o grupo agregado';

  @override
  String get inProgress => 'En progreso';

  @override
  String get waitingForUpdateJobOutput =>
      'Esperando el resultado del trabajo de actualización...';

  @override
  String get taskTrigger => 'Activador de tarea';

  @override
  String get bearerToken => 'ficha al portador';

  @override
  String get bearerToken2 => 'Ficha al portador';

  @override
  String get notRecorded => 'No grabado';

  @override
  String get sessionCookie => 'cookie de sesión';

  @override
  String get neverUsed => 'Nunca usado';

  @override
  String get linkedRecently => 'Vinculado recientemente';

  @override
  String get notUsedYet => 'Aún no usado';

  @override
  String get oneOrMoreAccountsExpiredReconnectTo =>
      'Una o más cuentas expiraron. Vuelva a conectarse para restaurar el acceso. Si esto continúa sucediendo, es posible que su aplicación Google Cloud OAuth esté en modo de prueba; publíquela en Producción en Google Cloud Console para obtener tokens de larga duración.';

  @override
  String get vaultConnectedAndAvailableAfterRestart =>
      'Bóveda conectada y disponible después del reinicio';

  @override
  String get vaultConnectedForThisSession => 'Vault conectado para esta sesión';

  @override
  String get connectAnotherAccount => 'Conectar otra cuenta';

  @override
  String get pasteReplacementLongLivedAccessToken =>
      'Pegar el token de acceso de larga duración de reemplazo';

  @override
  String get updateInstance => 'Instancia de actualización';

  @override
  String get pasteAReplacementToken => 'Pega un token de reemplazo';

  @override
  String get replaceAccount => 'Reemplazar cuenta';

  @override
  String get addAccount => 'Agregar cuenta';

  @override
  String get canDelegateToAnyReceivingAgent =>
      'Puede delegar a cualquier agente receptor';

  @override
  String get canReceiveDelegatedTasks2 => 'puede recibir tareas delegadas';

  @override
  String get noSyncYet => 'Aún no hay sincronización';

  @override
  String get noNewData => 'No hay datos nuevos';

  @override
  String get syncOnceToSeedYourBackend =>
      'Sincroniza una vez para inicializar tu backend.';

  @override
  String get lastWindowEndIsUnknown =>
      'Se desconoce el final de la última ventana.';

  @override
  String get lastNonEmptySync => 'Última sincronización no vacía';

  @override
  String get stopTranscribe => 'Detener y transcribir';

  @override
  String get steeringMode => 'Modo de dirección';

  @override
  String get noMessageText => 'Sin texto de mensaje';

  @override
  String get reconnectingToServer => 'Reconectándose al servidor…';

  @override
  String get signingIn => 'Iniciando sesión...';

  @override
  String get noGroupsFoundYet => 'Aún no se han encontrado grupos';

  @override
  String get onForNewGroupsOnly => 'Activado solo para grupos nuevos';

  @override
  String get noGroupsInThisCategory => 'No hay grupos en esta categoría.';

  @override
  String get groupOrChannel => 'Grupo o canal';

  @override
  String get notesYouWriteToYourselfStartA =>
      'Las notas que te escribes a ti mismo inician una carrera y las respuestas llegan al mismo chat. La lista de permitidos no se aplica aquí.';

  @override
  String get needToReply => 'necesito responder';

  @override
  String get enter2faCode => 'Ingrese el código 2FA';

  @override
  String get openYourAuthenticatorAppAndEnterThe =>
      'Abra su aplicación de autenticación e ingrese el código NeoAgent actual.';

  @override
  String get alreadyHaveAnAccountSignIn =>
      '¿Ya tienes una cuenta? Iniciar sesión';

  @override
  String get serverOnThisComputer => 'Servidor en esta computadora';

  @override
  String get showQrCode => 'Mostrar código QR';

  @override
  String get createAnotherNeoagentAccount => 'Crea otra cuenta de NeoAgent.';

  @override
  String get canCoordinateDelegatedWork =>
      'Puede coordinar el trabajo delegado.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe =>
      'No se pudo extraer el archivo de tiempo de ejecución de NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveCouldNotBe2 =>
      'No se pudo leer el archivo de tiempo de ejecución de NeoAgent.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe =>
      'El archivo de tiempo de ejecución de NeoAgent contiene una ruta insegura.';

  @override
  String get theNeoagentRuntimeArchiveContainsAnUnsafe2 =>
      'El archivo de tiempo de ejecución de NeoAgent contiene un enlace inseguro.';

  @override
  String get installingAppPackageOnThePhone =>
      'Instalando el paquete de aplicaciones en el teléfono...';

  @override
  String get dragAndDropAApkOrApks =>
      'Arrastre y suelte un archivo .apk o .apks aquí, o haga clic para explorar.';

  @override
  String get releaseToInstallThisPackage =>
      'Lanzamiento para instalar este paquete';

  @override
  String get theSecurityKeyCouldNotBeUsed =>
      'No se pudo utilizar la clave de seguridad.';

  @override
  String get connecting => 'Conectando…';

  @override
  String get changes => 'Cambios';

  @override
  String get runtimeReady => 'Tiempo de ejecución listo';

  @override
  String get saving => 'Guardando...';

  @override
  String get earlier => 'Antes';

  @override
  String get monthJan => 'enero';

  @override
  String get monthFeb => 'febrero';

  @override
  String get monthMar => 'mar';

  @override
  String get monthApr => 'abril';

  @override
  String get monthMay => 'mayo';

  @override
  String get monthJun => 'junio';

  @override
  String get monthJul => 'julio';

  @override
  String get monthAug => 'agosto';

  @override
  String get monthSep => 'septiembre';

  @override
  String get monthOct => 'octubre';

  @override
  String get monthNov => 'noviembre';

  @override
  String get monthDec => 'diciembre';

  @override
  String get steeringWord => 'dirección';

  @override
  String thisSwitchesTheBackendFromTheArg1(Object? arg1, Object? arg2) {
    return 'Esto cambia el backend del canal $arg1 al canal $arg2.';
  }

  @override
  String arg1CookiesImported(Object? arg1) {
    return 'Cookies $arg1 importadas';
  }

  @override
  String arg1SAgo(Object? arg1) {
    return 'Hace ${arg1}s';
  }

  @override
  String queuedSteeringArg1(Object? arg1) {
    return 'Dirección en cola: $arg1';
  }

  @override
  String theWebAppCouldNotReachThe(Object? arg1) {
    return 'La aplicación web no pudo acceder al backend de NeoAgent.\n\n$arg1';
  }

  @override
  String theBrowserBlockedARequiredRequestBecause(Object? arg1) {
    return 'El navegador bloqueó una solicitud requerida debido a la Política de seguridad de contenido.\n\n$arg1';
  }

  @override
  String arg1Of4Allowed(Object? arg1) {
    return '$arg1 de 4 permitidos';
  }

  @override
  String arg1WorkThroughTheTaskAsYou(Object? arg1) {
    return '$arg1 · Realice la tarea como lo haría normalmente.';
  }

  @override
  String changesArg1(Object? arg1) {
    return 'Cambios · $arg1';
  }

  @override
  String thisDeviceArg12(Object? arg1) {
    return 'Este dispositivo · $arg1';
  }

  @override
  String limitReachedArg1(Object? arg1) {
    return 'Límite alcanzado$arg1';
  }

  @override
  String arg1RecoveryCodesAreStillAvailable(Object? arg1) {
    return 'Los códigos de recuperación $arg1 todavía están disponibles.';
  }

  @override
  String securityKeyArg1(Object? arg1) {
    return 'Clave de seguridad $arg1';
  }

  @override
  String arg1CurrentSession(Object? arg1) {
    return '$arg1 · Sesión actual';
  }

  @override
  String arg1LastUsedArg2(Object? arg1, Object? arg2) {
    return '$arg1\nÚltimo uso: $arg2';
  }

  @override
  String workingInArg1OnThisDeviceNeoagent(Object? arg1) {
    return 'Trabajando en $arg1 en este dispositivo. NeoAgent lee y edita la carpeta directamente y puede ejecutar comandos, abrir aplicaciones y usar la pantalla.';
  }

  @override
  String workedForArg1(Object? arg1) {
    return 'Trabajó para $arg1';
  }

  @override
  String allowedByArg1(Object? arg1) {
    return 'Permitido por $arg1';
  }

  @override
  String arg1InviteLinksFromArg2WereRevoked(Object? arg1, Object? arg2) {
    return 'Los enlaces de invitación $arg1 de $arg2 fueron revocados';
  }

  @override
  String addThePeopleAndGroupsArg1Should(Object? arg1) {
    return 'Añade las personas y grupos con los que $arg1 debería hablar';
  }

  @override
  String addThePeopleAndGroupsArg1Is(Object? arg1) {
    return 'Agregue las personas y grupos con los que $arg1 puede hablar.';
  }

  @override
  String whereArg1Listens(Object? arg1) {
    return 'Donde escucha $arg1';
  }

  @override
  String arg1WatchesThesePlacesForMentionsAnyone(Object? arg1) {
    return '$arg1 observa estos lugares en busca de menciones. Cualquiera puede publicar aquí, por lo que las personas aún necesitan su propia aprobación a continuación.';
  }

  @override
  String thesePeopleCanAskArg1WhereverThey(Object? arg1) {
    return 'Estas personas pueden preguntar $arg1 dondequiera que lo etiqueten. Los roles cuentan sólo en los lugares enumerados anteriormente.';
  }

  @override
  String onlyWhenArg1IsTagged(Object? arg1) {
    return 'Sólo cuando se etiqueta $arg1';
  }

  @override
  String onForAllArg1Groups(Object? arg1) {
    return 'Activado para todos los grupos $arg1';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups(Object? arg1) {
    return '$arg1 todavía escucha solo a las personas y grupos que ya aprobó. Esto simplemente permite que $arg1 se una al chat normal allí, no solo a etiquetas y respuestas.';
  }

  @override
  String arg1StillOnlyHearsPeopleAndGroups2(Object? arg1) {
    return '$arg1 todavía escucha solo a las personas y grupos que ya aprobó. Esto simplemente elige a cuál de esos grupos debe unirse.';
  }

  @override
  String ifSomeoneTagsArg1OrRepliesArg1(Object? arg1) {
    return 'Si alguien etiqueta a $arg1 o responde, $arg1 siempre responde. Active esta opción si $arg1 también quiere participar en un chat grupal normal.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary(Object? arg1) {
    return 'Los nuevos grupos permitirán que $arg1 se una al chat normal con personas aprobadas, hasta que las desactives.';
  }

  @override
  String newGroupsWillLetArg1JoinOrdinary2(Object? arg1) {
    return 'Los nuevos grupos permitirán que $arg1 se una al chat normal hasta que los desactives.';
  }

  @override
  String newGroupsStayQuietUnlessAnApproved(Object? arg1) {
    return 'Los grupos nuevos permanecen en silencio a menos que una persona aprobada etiquete a $arg1, hasta que los active.';
  }

  @override
  String onlyWhenAnApprovedPersonTagsArg1(Object? arg1) {
    return 'Solo cuando una persona aprobada etiqueta a $arg1, a menos que actives un grupo';
  }

  @override
  String onlyWhenArg1IsTaggedUnlessYou(Object? arg1) {
    return 'Solo cuando se etiqueta $arg1, a menos que actives un grupo';
  }

  @override
  String arg1OfArg2GroupsJoinOrdinaryChat(Object? arg1, Object? arg2) {
    return '$arg1 de los grupos $arg2 se unen al chat ordinario con personas aprobadas';
  }

  @override
  String thisDoesNotApproveNewPeopleTags(Object? arg1) {
    return 'Esto no aprueba a la gente nueva. Las etiquetas y respuestas de personas aprobadas siempre obtienen una respuesta. Active un grupo si $arg1 también debe unirse al chat normal allí.';
  }

  @override
  String thisDoesNotApproveNewPeopleTurn(Object? arg1) {
    return 'Esto no aprueba a la gente nueva. Active un grupo si $arg1 debe unirse al chat normal con personas que ya aprobó.';
  }

  @override
  String tagsAndRepliesAlwaysGetAResponse(Object? arg1) {
    return 'Las etiquetas y las respuestas siempre obtienen una respuesta. Active un grupo si $arg1 también debe unirse al chat normal allí.';
  }

  @override
  String arg1JoinsOrdinaryChatWithApprovedPeople(Object? arg1) {
    return '$arg1 se une al chat ordinario con personas aprobadas';
  }

  @override
  String arg1CanJoinOrdinaryChat(Object? arg1) {
    return '$arg1 puede unirse al chat normal';
  }

  @override
  String arg1OnlyRepliesWhenAnApprovedPerson(Object? arg1) {
    return '$arg1 solo responde cuando una persona aprobada lo etiqueta';
  }

  @override
  String nothingExtraIsNeededConnectToStart(Object? arg1) {
    return 'No se necesita nada adicional. Conéctese para comenzar a usar $arg1.';
  }

  @override
  String refreshesInArg1S(Object? arg1) {
    return 'Actualizaciones en ${arg1}s';
  }

  @override
  String registerWithArg1(Object? arg1) {
    return 'Regístrese con $arg1';
  }

  @override
  String noMemoriesLinkedToArg1(Object? arg1) {
    return 'No hay recuerdos vinculados a \"$arg1\".';
  }

  @override
  String arg1Default2(Object? arg1) {
    return '$arg1 (predeterminado)';
  }

  @override
  String branchArg1(Object? arg1) {
    return ' | Sucursal: $arg1';
  }

  @override
  String arg1OnlyJoinsTheGroupsAndChannels(Object? arg1) {
    return '$arg1 solo se une a los grupos y canales que agregas a continuación.';
  }

  @override
  String arg1IsRequiredToLocateNeoagentRuntime(Object? arg1) {
    return 'Se requiere $arg1 para localizar los datos del tiempo de ejecución de NeoAgent.';
  }

  @override
  String truncatedPreviewArg1BytesTotal(Object? arg1) {
    return '...[vista previa truncada, total de bytes $arg1]';
  }

  @override
  String artifactBoundedArg1BytesTotal(Object? arg1) {
    return '\n...[artefacto delimitado, total de bytes $arg1]...\n';
  }

  @override
  String inArg1(Object? arg1) {
    return ' en $arg1';
  }

  @override
  String get worldNews => 'Noticias del mundo';

  @override
  String get runWhenNewWorldHeadlinesAppear =>
      'Corre cuando aparezcan nuevos titulares mundiales. Su mensaje decide si debe notificarle.';

  @override
  String get newsKeywordsOptional => 'Palabras clave (opcional)';

  @override
  String get worldNewsSetup => 'Configuración de noticias mundiales';

  @override
  String get connectWorldNewsWithGnews =>
      'Agregue una clave API de GNews (plan gratuito disponible en gnews.io). Se almacena encriptado y se utiliza para sondear los principales titulares en busca de factores desencadenantes de World News.';

  @override
  String get gnewsApiKey => 'Clave API de GNews';

  @override
  String get pasteReplacementGnewsApiKey =>
      'Pegar la clave API de GNews de reemplazo';

  @override
  String get leaveTheApiKeyEmptyToKeep =>
      'Deje la clave vacía para conservar la clave almacenada actualmente.';

  @override
  String get gnewsApiKeyIsRequired => 'Se requiere una clave API de GNews.';

  @override
  String get couldNotSaveWorldNewsSetup =>
      'No se pudo guardar la configuración de World News.';

  @override
  String get disconnectWorldNews => 'Desconectar Noticias del Mundo';

  @override
  String get thisRemovesTheGnewsApiKey =>
      'Esto elimina la clave API de GNews almacenada. Los activadores de World News dejarán de activarse hasta que vuelvas a agregar una clave.';

  @override
  String get couldNotDisconnectWorldNews =>
      'No se pudo desconectar Noticias Mundiales.';

  @override
  String get systemOneModels => 'Modelos SystemOne';

  @override
  String get systemOneAuto => 'Automático';

  @override
  String get systemOneAutoPicksTheBestAvailable =>
      'Elige el mejor modelo SystemOne disponible';

  @override
  String get systemOneOffTheChatModelDecides =>
      'El modelo de chat toma estas decisiones.';

  @override
  String get systemOneModelsMakeTheBehindTheScenes =>
      'Modelos de decisión que realizan llamadas entre bastidores en una fracción de segundo: turnos de chat grupal y pasos del navegador. Su modelo de chat aún escribe cada respuesta.';

  @override
  String get systemOneDecidesWhenToSpeakWhileIt =>
      'El modelo SystemOne decide cuándo hablar mientras está encendido; este modelo es el alternativo.';

  @override
  String arg1ScoredBySystemOne(Object? arg1) {
    return '$arg1 puntuado por SystemOne';
  }

  @override
  String get systemOneScoredThisMessageDirectlyNo =>
      'SystemOne calificó este mensaje directamente. No se ejecutó ningún modelo de lenguaje.';

  @override
  String get systemOneUnavailable => 'SystemOne no disponible';

  @override
  String get systemOneAdminAvailability =>
      'Los agentes de modelos de decisión pueden elegir en Configuración > Modelos. Un modelo desactivado aquí deja ese selector y los agentes que lo eligieron vuelven a Auto. Mientras cualquier modelo está apagado, los modelos SystemOne que los proveedores agregan más tarde también comienzan a apagarse.';

  @override
  String get addATypesafeOrOpenrouterKey =>
      'Aún no hay modelos de SystemOne. Agregue una clave TypeSafe u OpenRouter en Proveedores, o utilice un modelo de decisión como ágil en Ollama 0.35 o posterior.';

  @override
  String get noSystemOneModelIsAvailableYet =>
      'Ningún modelo SystemOne está disponible todavía. Agregue una clave TypeSafe u OpenRouter en Configuración > Modelos > Traiga su propia clave o utilice un modelo de decisión como ágil en Ollama.';

  @override
  String get systemoneDecisionModelsTypesafeOpenrouterOllama =>
      'systemone modelos de decisión de system one jev typesafe openrouter ollama disponibilidad habilitar deshabilitar';

  @override
  String get chatModels => 'Modelos de chat';

  @override
  String get disabled => 'Deshabilitado';

  @override
  String get enableShown => 'Habilitar mostrado';

  @override
  String get disableShown => 'Desactivar mostrado';

  @override
  String get expandAll => 'Expandir todo';

  @override
  String get collapseAll => 'Contraer todo';

  @override
  String arg1UnsavedChanges(Object? arg1) {
    return '$arg1 cambios no guardados';
  }

  @override
  String get settingsScopeAllAgents => 'Todos los agentes';

  @override
  String get settingsScopeAgent => 'este agente';

  @override
  String get settingsScopeApp => 'Aplicación';

  @override
  String get settingsScopeAccountHint =>
      'Lo mismo en cualquier lugar donde inicies sesión';

  @override
  String get settingsScopeAllAgentsHint => 'Compartido por todos tus agentes';

  @override
  String get settingsAppliesTo => 'Se aplica a';

  @override
  String get settingsSaving => 'Guardando…';

  @override
  String get settingsSavedAutomatically =>
      'Los cambios se guardan automáticamente';

  @override
  String get settingsSearchHint => 'Buscar todas las configuraciones';

  @override
  String get settingsPageProfile => 'Perfil';

  @override
  String get settingsPageSecurity => 'Inicio de sesión y seguridad';

  @override
  String get settingsPageUsage => 'Uso';

  @override
  String get settingsPagePermissions => 'Permisos';

  @override
  String get settingsPageComputer => 'Computadora y web';

  @override
  String get settingsPageBehavior => 'Comportamiento';

  @override
  String get settingsPageSystem => 'Sistema';

  @override
  String get settingsPagePlatforms => 'Plataformas';

  @override
  String get settingsPageProfileDescription =>
      'Tu nombre y correo electrónico, una copia de tus datos y cerrar sesión.';

  @override
  String get settingsPageSecurityDescription =>
      'Contraseña, autenticación de dos factores, claves de seguridad y dónde inició sesión.';

  @override
  String get settingsPageUsageDescription =>
      'Tus límites y tu gasto de tokens, todo en un solo lugar.';

  @override
  String get settingsPageAgentsDescription =>
      'Crea agentes y elige cuál responde por defecto.';

  @override
  String get settingsPagePermissionsDescription =>
      'Qué pueden hacer sus agentes sin preguntarle primero.';

  @override
  String get settingsPageComputerDescription =>
      'La computadora en la que trabajan sus agentes y los sitios que pueden leer como usted.';

  @override
  String get settingsPageModelsDescription =>
      'Qué modelos utiliza este agente y las claves API que pagan por ellos.';

  @override
  String get settingsPageBehaviorDescription =>
      'Cómo habla este agente y cómo lee un chat grupal.';

  @override
  String get settingsPageVoiceDescription =>
      'Llamadas en vivo, dictados y respuestas habladas para este agente.';

  @override
  String get settingsPageMessagingDescription =>
      'Dónde las personas pueden comunicarse con este agente y cómo se comporta en los chats.';

  @override
  String get settingsPageGeneralDescription =>
      'Apariencia, idioma, zona horaria y lo que hace esta aplicación en segundo plano.';

  @override
  String get settingsPageSystemDescription =>
      'El servidor que usa esta ventana, el de esta computadora y las actualizaciones de la aplicación.';

  @override
  String get settingsYourAgents => 'Tus agentes';

  @override
  String get settingsChatModel => 'modelo de chat';

  @override
  String get settingsChatModelDescription => 'Responde a tus mensajes.';

  @override
  String get settingsSubAgentModel => 'Modelo de subagente';

  @override
  String get settingsSubAgentModelDescription =>
      'Ejecuta el trabajo entregado durante una tarea.';

  @override
  String get settingsDefaultModels => 'Modelos predeterminados';

  @override
  String get settingsDefaultModelsDescription =>
      'Se utiliza siempre que un chat o una tarea no elige su propio modelo.';

  @override
  String get settingsModelPool => 'grupo modelo';

  @override
  String get settingsApiKeysDescription =>
      'Utilice sus propias claves o punto final para este agente. Las claves se cifran y nunca se vuelven a mostrar.';

  @override
  String get settingsPersona => 'persona';

  @override
  String get settingsFineTuning => 'Ajuste fino';

  @override
  String get settingsFineTuningDescription =>
      'Rara vez es necesario. Los valores predeterminados se adaptan a la mayoría de los chats.';

  @override
  String get settingsShow => 'Mostrar';

  @override
  String get settingsHide => 'Ocultar';

  @override
  String get settingsMinimumContribution => 'Valor mínimo de contribución';

  @override
  String get settingsBatchWindow => 'Ventana de lote de habitación';

  @override
  String get settingsBatchWindowDescription =>
      'Espera tanto tiempo para tratar los mensajes rápidos como un solo turno.';

  @override
  String get settingsHandsFree => 'manos libres';

  @override
  String get settingsHandsFreeDescription =>
      'Habla libremente e interrumpe en cualquier momento.';

  @override
  String get settingsPushToTalkDescription =>
      'Mantenga presionado para hablar, suelte para enviar.';

  @override
  String get settingsLiveVoice => 'voz en vivo';

  @override
  String get settingsChannels => 'Canales';

  @override
  String get settingsGroupChats => 'En chats grupales';

  @override
  String get settingsGroupChatsDescription =>
      'Cómo se comporta este agente en grupos en cada canal.';

  @override
  String get settingsGroupChatsDisabled =>
      'Active los módulos de comportamiento en Comportamiento para cambiarlos.';

  @override
  String get settingsParticipationAutomatic => 'Automático';

  @override
  String get settingsParticipationMentionOnly => 'Solo mencionar';

  @override
  String get settingsParticipationAutomaticDescription =>
      'Lee la sala y participa cuando tiene algo útil que agregar.';

  @override
  String get settingsParticipationMentionOnlyDescription =>
      'Responde sólo cuando se menciona o se responde.';

  @override
  String get settingsParticipationAlwaysDescription =>
      'Responde a cada mensaje.';

  @override
  String get settingsDeliveryNaturalDescription =>
      'Divide las respuestas más largas en mensajes cortos, como lo haría una persona.';

  @override
  String get settingsDeliverySingleDescription =>
      'Envía cada respuesta como un mensaje.';

  @override
  String get settingsComputerStatus => 'Estado';

  @override
  String get settingsTest => 'prueba';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsCloseWindow => 'Cuando cierras la ventana';

  @override
  String get settingsCloseAsk => 'preguntar';

  @override
  String get settingsCloseKeepRunningDescription =>
      'NeoAgent sigue ejecutándose en segundo plano y permanece accesible.';

  @override
  String get settingsCloseQuitDescription => 'NeoAgent se cierra por completo.';

  @override
  String get settingsPhoneTriggers => 'Disparadores del teléfono';

  @override
  String get settingsPhoneTriggersDescription =>
      'Señales que este teléfono envía a sus agentes para que las tareas puedan reaccionar ante ellas.';

  @override
  String get settingsLocationTriggers => 'Desencadenantes de ubicación';

  @override
  String get settingsLocationTriggersDescription =>
      'Comprueba su ubicación aproximada cada pocos minutos con los lugares que vigilan sus tareas.';

  @override
  String get settingsNotificationTriggers => 'Activadores de notificación';

  @override
  String get settingsNotificationTriggersDescription =>
      'Reenvía notificaciones de otras aplicaciones en este teléfono a sus agentes.';

  @override
  String get settingsSetup => 'Configuración';

  @override
  String get settingsOnboarding => 'Incorporación';

  @override
  String get settingsOnboardingDescription =>
      'Vuelva a realizar la configuración de primera ejecución. Nada de lo que configures se pierde.';

  @override
  String get settingsUsernameDescription =>
      'Se utiliza para iniciar sesión. No se puede cambiar.';

  @override
  String get settingsExport => 'Exportar';

  @override
  String get settingsLeave => 'Cerrar sesión y eliminar';

  @override
  String get settingsSignOutDescription =>
      'Cierra tu sesión únicamente en este dispositivo.';

  @override
  String get settingsDeleteAccountDescription =>
      'Borra su cuenta, agentes, memoria y configuración. Esto no se puede deshacer.';

  @override
  String get settingsTokenUsage => 'Uso de tokens';

  @override
  String settingsSearchNoMatch(String query) {
    return 'Ninguna configuración coincide con “$query”.';
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
  String get settingsAdvancedModels => 'Configuración avanzada del modelo';

  @override
  String get settingsAdvancedModelsDescription =>
      'Opcional. Fijar un modelo a un tipo de trabajo; asume el control cada vez que el agente utiliza esas herramientas. Todo lo que se deja por defecto sigue el modelo de chat.';

  @override
  String get settingsTaskModelDefault => 'Predeterminado';

  @override
  String get settingsTaskModelDefaultSubtitle => 'Sigue el modelo de chat.';

  @override
  String get settingsTaskModelCoding => 'Codificación';

  @override
  String get settingsTaskModelCodingDescription =>
      'Escritura, edición y depuración de código.';

  @override
  String get settingsTaskModelComputerUse => 'Uso de la computadora';

  @override
  String get settingsTaskModelComputerUseDescription =>
      'Conduciendo el navegador y el escritorio.';

  @override
  String get settingsTaskModelAndroidUse => 'uso de Android';

  @override
  String get settingsTaskModelAndroidUseDescription =>
      'Operar aplicaciones en un dispositivo o emulador Android.';

  @override
  String get settingsTaskModelResearch => 'Investigación';

  @override
  String get settingsTaskModelResearchDescription =>
      'Buscar, leer y resumir fuentes.';

  @override
  String get knowledgeGraphHint =>
      'Tus entidades más mencionadas, coloreadas por grupo. Las líneas conectan entidades que aparecen en los mismos recuerdos. Toque uno para ver sus enlaces y recuerdos; arrastre para desplazarse, pellizque o presione Ctrl/⌘ y desplácese para hacer zoom.';

  @override
  String get linkedEntities => 'Entidades vinculadas';

  @override
  String get noLinkedEntities => 'Aún no vinculado a otras entidades.';

  @override
  String mentionsArg1(int arg1) {
    return '$arg1 menciona';
  }

  @override
  String get entityKindConcept => 'Concepto';

  @override
  String get entityKindDomain => 'Dominio';

  @override
  String get entityKindEmail => 'Correo electrónico';

  @override
  String get entityKindLink => 'Enlace';

  @override
  String get entityKindFile => 'Archivo';

  @override
  String get entityKindAcronym => 'Acrónimo';

  @override
  String get entityKindIdentifier => 'Identificador';

  @override
  String get entityKindVersion => 'Versión';

  @override
  String get openFullscreen => 'Abrir pantalla completa';

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'alejar';

  @override
  String get searchEntities => 'Encuentra una entidad';

  @override
  String get incomingCall => 'llamada entrante';

  @override
  String get answerCall => 'respuesta';

  @override
  String get callMeLater => 'Llámame más tarde';

  @override
  String get callingEllipsis => 'Llamando…';

  @override
  String get reconnectingCall => 'Reconectando';

  @override
  String get agentWorking => 'trabajando';

  @override
  String get micMuted => 'silenciado';

  @override
  String get speakerphone => 'altavoz';

  @override
  String get muteMic => 'Silenciar';

  @override
  String get unmuteMic => 'Dejar de silenciar';

  @override
  String get releaseToSend => 'Liberar para enviar';

  @override
  String get callEnded => 'llamada finalizada';

  @override
  String get openConversation => 'Conversacion abierta';

  @override
  String get callBack => 'volver a llamar';

  @override
  String get letCallsReachYou => 'Deja que las llamadas te lleguen';

  @override
  String get callPermissionsIntro =>
      'Tus agentes pueden llamarte. Para que suene como una llamada telefónica mientras NeoAgent está en segundo plano o su teléfono está bloqueado, los necesita.';

  @override
  String get showOverOtherApps => 'Mostrar sobre otras aplicaciones';

  @override
  String get showOverOtherAppsDetail =>
      'Muestra la pantalla de llamadas dondequiera que estés.';

  @override
  String get fullScreenCalls => 'Llamadas en pantalla completa';

  @override
  String get fullScreenCallsDetail => 'Suena sobre la pantalla de bloqueo.';

  @override
  String get unrestrictedBattery => 'Batería sin restricciones';

  @override
  String get unrestrictedBatteryDetail =>
      'Mantiene NeoAgent conectado para que lleguen las llamadas.';

  @override
  String get permissionAllowed => 'Permitido';

  @override
  String get triggerSectionCalendar => 'Calendario';

  @override
  String get triggerSectionFiles => 'Archivos y documentos';

  @override
  String get triggerSectionHome => 'Hogar y medios';

  @override
  String get triggerSectionDevices => 'Dispositivos y lugares';

  @override
  String get triggerSectionTasks => 'Tareas';

  @override
  String get messagingMemberJoined => 'Miembro unido';

  @override
  String get runWhenSomeoneJoinsAServerOrGroup =>
      'Se ejecuta cuando alguien se une a un servidor de Discord, un grupo de Telegram o WhatsApp, un canal de Slack o una sala Matrix.';

  @override
  String get messagingMemberLeft => 'Miembro izquierdo';

  @override
  String get runWhenSomeoneLeavesAServerOrGroup =>
      'Se ejecuta cuando alguien abandona un servidor de Discord, un grupo de Telegram o WhatsApp, un canal de Slack o una sala de Matrix.';

  @override
  String get messagingReactionAdded => 'Reacción agregada';

  @override
  String get runWhenSomeoneReactsInAPrivateChat =>
      'Ejecutar cuando una persona permitida reacciona a un mensaje en un chat privado.';

  @override
  String get messagingPlatformDisconnected => 'Mensajería desconectada';

  @override
  String get runWhenAMessagingConnectionNeedsYou =>
      'Ejecútelo cuando una conexión de mensajería se detenga y lo necesite, como después de cerrar sesión.';

  @override
  String get googleCalendarEventStarting =>
      'Inicio del evento de Google Calendar';

  @override
  String get googleCalendarEventCreated => 'Evento de Google Calendar creado';

  @override
  String get runWhenANewGoogleCalendarEventAppears =>
      'Ejecutar cuando aparezca un nuevo evento o invitación.';

  @override
  String get outlookCalendarEventStarting =>
      'Inicio del evento del calendario de Outlook';

  @override
  String get nextcloudCalendarEventStarting =>
      'Inicio del evento del calendario de Nextcloud';

  @override
  String get runMinutesBeforeEachEvent =>
      'Ejecute una cantidad determinada de minutos antes de cada evento.';

  @override
  String get googleDriveFileAdded => 'Archivo de Google Drive agregado';

  @override
  String get runWhenAFileIsAddedToDrive =>
      'Ejecutar cuando se agrega un archivo a Drive o una carpeta en él.';

  @override
  String get googleSheetsRowAdded =>
      'Se agregó una fila de Hojas de cálculo de Google';

  @override
  String get runWhenRowsAreAddedToASheet =>
      'Ejecutar cuando aparecen nuevas filas en una hoja.';

  @override
  String get onedriveFileAdded => 'Archivo OneDrive agregado';

  @override
  String get runWhenAFileIsAddedToOnedrive =>
      'Ejecutar cuando se agrega un archivo a una carpeta de OneDrive.';

  @override
  String get nextcloudFileAdded => 'Archivo Nextcloud agregado';

  @override
  String get runWhenAFileIsAddedToNextcloud =>
      'Ejecutar cuando se agrega un archivo a una carpeta de Nextcloud.';

  @override
  String get nextcloudShareReceived =>
      'Archivo de Nextcloud compartido contigo';

  @override
  String get runWhenSomeoneSharesWithYouOnNextcloud =>
      'Ejecútelo cuando alguien comparta un archivo o carpeta con usted.';

  @override
  String get notionItemAdded => 'Elemento de base de datos de Notion agregado';

  @override
  String get runWhenAnItemIsAddedToANotionDatabase =>
      'Se ejecuta cuando se agrega un elemento a una base de datos de Notion.';

  @override
  String get notionItemUpdated =>
      'Elemento de base de datos de Notion actualizado';

  @override
  String get runWhenANotionDatabaseItemChanges =>
      'Se ejecuta cuando cambia un elemento en una base de datos de Notion.';

  @override
  String get trelloCardEnteredList => 'Tarjeta Trello agregada a la lista';

  @override
  String get runWhenACardIsCreatedInOrMovedIntoAList =>
      'Se ejecuta cuando se crea una tarjeta o se mueve a una lista.';

  @override
  String get figmaCommentAdded => 'Se agregó el comentario de Figma.';

  @override
  String get runWhenSomeoneCommentsOnAFigmaFile =>
      'Se ejecuta cuando alguien comenta sobre un archivo Figma.';

  @override
  String get githubPrOpened => 'Solicitud de extracción de GitHub abierta';

  @override
  String get runWhenANewPullRequestIsOpened =>
      'Se ejecuta cuando se abre una nueva solicitud de extracción en un repositorio.';

  @override
  String get githubWorkflowRunFailed =>
      'Error al ejecutar el flujo de trabajo de GitHub';

  @override
  String get runWhenAGithubActionsRunFails =>
      'Ejecutar cuando falla la ejecución de GitHub Actions.';

  @override
  String get githubCommitPushed => 'Confirmación de GitHub empujada';

  @override
  String get runWhenNewCommitsReachABranch =>
      'Ejecutar cuando nuevas confirmaciones lleguen a una rama.';

  @override
  String get mcpServerFailed => 'El servidor MCP falló';

  @override
  String get runWhenAWorkingMcpServerFails =>
      'Ejecutarlo cuando un servidor MCP que estaba funcionando falla o necesita iniciar sesión.';

  @override
  String get homeAssistantStateChanged =>
      'El estado del Asistente de inicio cambió';

  @override
  String get runWhenAHomeAssistantEntityChanges =>
      'Se ejecuta cuando una entidad cambia, alcanza un estado o cruza un valor.';

  @override
  String get spotifyTrackChanged => 'Pista de Spotify cambiada';

  @override
  String get runWhenADifferentTrackStartsPlaying =>
      'Ejecutar cuando comience a reproducirse una pista diferente.';

  @override
  String get neorecallDailySummaryReady => 'Resumen diario de NeoRecall listo';

  @override
  String get runWhenADaysSummaryIsFinal =>
      'Ejecutar cuando el resumen de un día sea definitivo.';

  @override
  String get neorecallConversationRecorded =>
      'Conversación de NeoRecall grabada';

  @override
  String get runWhenARecordedConversationEnds =>
      'Ejecutar cuando finaliza una conversación grabada.';

  @override
  String get geofenceTrigger => 'Geocerca de ubicación';

  @override
  String get runWhenYourPhoneArrivesOrLeaves =>
      'Ejecuta cuando tu teléfono llega o sale de un lugar. Necesita seguimiento de ubicación en el teléfono.';

  @override
  String get healthMetricRecorded => 'Métrica de salud registrada';

  @override
  String get runWhenAHealthReadingArrives =>
      'Se ejecuta cuando llega una lectura de estado sincronizada, opcionalmente por encima o por debajo de un valor.';

  @override
  String get wearableConnectionChanged => 'Wearable conectado o desconectado';

  @override
  String get runWhenYourWearableConnectsOrDisconnects =>
      'Ejecútalo cuando tu dispositivo portátil se conecte o desconecte.';

  @override
  String get taskRunFinished => 'Otra tarea terminada';

  @override
  String get runWhenAnotherTaskFinishes =>
      'Ejecutar después de que otra tarea finalice, tenga éxito o falle.';

  @override
  String get appPackageOptional => 'Paquete de aplicaciones (opcional)';

  @override
  String get appPackageHelper => 'Por ejemplo com.whatsapp';

  @override
  String get anyPlatform => 'Cualquier plataforma';

  @override
  String get spaceIdOptional =>
      'ID de servidor, grupo, canal o sala (opcional)';

  @override
  String get spaceIdHelper =>
      'Relojes vacíos en cada uno de los cuales se encuentra el robot.';

  @override
  String get emojiOptional => 'Emoji (opcional)';

  @override
  String get chatIdOptional => 'ID de chat (opcional)';

  @override
  String get platformOptional => 'Plataforma (opcional)';

  @override
  String get platformOptionalHelper =>
      'Por ejemplo whatsapp. Relojes vacíos todos.';

  @override
  String get minutesBefore => 'Minutos antes';

  @override
  String get calendarIdOptional => 'ID de calendario (opcional)';

  @override
  String get calendarIdHelper => 'Vacío usa tu calendario principal.';

  @override
  String get invitesOnly => 'Sólo invitaciones de otros.';

  @override
  String get nextcloudCalendarPath => 'Calendario';

  @override
  String get nextcloudCalendarPathHelper =>
      'Su nombre en la lista de calendario de Nextcloud, por ejemplo personal';

  @override
  String get folderIdOptionalHelperDrive => 'Vacío observa todo Drive.';

  @override
  String get folderIdOptionalHelperOnedrive => 'Vaciar vigila la carpeta raíz.';

  @override
  String get driveFolderIdOptional => 'ID de carpeta (opcional)';

  @override
  String get spreadsheetId => 'ID de hoja de cálculo';

  @override
  String get sheetRange => 'Rango';

  @override
  String get sheetRangeHelper =>
      'Las columnas de la tabla, por ejemplo Hoja1!A:E';

  @override
  String get folderPathOptional => 'Ruta de la carpeta (opcional)';

  @override
  String get folderPathHelper => 'Por ejemplo documentos';

  @override
  String get notionDatabaseId => 'ID de base de datos';

  @override
  String get trelloListId => 'ID de lista';

  @override
  String get figmaFileKey => 'Clave de archivo';

  @override
  String get figmaFileKeyHelper =>
      'Desde el enlace del archivo: figma.com/file/<key>/…';

  @override
  String get githubRepository => 'Repositorio';

  @override
  String get workflowOptional => 'Flujo de trabajo (opcional)';

  @override
  String get workflowHelper => 'Nombre de archivo como ci.yml';

  @override
  String get branchOptional => 'Sucursal (opcional)';

  @override
  String get branchHelper => 'Vacío usa la rama predeterminada.';

  @override
  String get mcpServerIdOptional => 'ID del servidor MCP (opcional)';

  @override
  String get entityId => 'ID de entidad';

  @override
  String get entityIdHelper => 'Por ejemplo binario_sensor.front_door';

  @override
  String get targetStateOptional => 'Estado objetivo (opcional)';

  @override
  String get targetStateHelper => 'Por ejemplo en';

  @override
  String get aboveOptional => 'Arriba (opcional)';

  @override
  String get belowOptional => 'Abajo (opcional)';

  @override
  String get placeName => 'Nombre del lugar';

  @override
  String get latitude => 'Latitud';

  @override
  String get longitude => 'longitud';

  @override
  String get radiusMeters => 'Radio en metros';

  @override
  String get geofenceTransition => 'cuando';

  @override
  String get arriving => 'Llegando';

  @override
  String get leaving => 'Dejando';

  @override
  String get healthMetric => 'Métrica de salud';

  @override
  String get healthMetricHelper =>
      'Por ejemplo frecuencia cardíaca, pasos, peso.';

  @override
  String get wearableTransition => 'cuando el usable';

  @override
  String get wearableConnects => 'conecta';

  @override
  String get wearableDisconnects => 'Se desconecta';

  @override
  String get sourceTask => 'Después de la tarea';

  @override
  String get taskOutcome => 'Resultado';

  @override
  String get anyOutcome => 'Cualquier resultado';

  @override
  String get succeeded => 'Tuvo éxito';

  @override
  String fieldMissingOrInvalidArg1(Object? arg1) {
    return 'Falta $arg1 o no es válido.';
  }

  @override
  String get triggerSectionMessaging => 'Mensajería';

  @override
  String get triggerSectionDeveloper => 'Desarrollador';

  @override
  String get triggerSectionMemory => 'Memoria';

  @override
  String get triggerSectionNews => 'Noticias';

  @override
  String get triggerSectionSystem => 'Sistema';

  @override
  String get searchTriggersHint => 'Buscar activadores, aplicaciones o eventos';

  @override
  String get noTriggersMatch => 'Ningún activador coincide con su búsqueda.';

  @override
  String get triggerAccountMissing => 'Aún no hay cuenta';

  @override
  String get pickTriggerKeyboardHint => 'Enter elige el primer resultado';

  @override
  String triggerResultCountArg1(Object? arg1) {
    return 'Disparadores $arg1';
  }

  @override
  String get addFromSkillsSh => 'Agregar desde skills.sh';

  @override
  String get skillsShHint =>
      'Busque arriba para encontrar habilidades en skills.sh, o pegue un enlace de skills.sh o un comando `npx skills add`.';

  @override
  String get noSkillsShMatches =>
      'Ninguna habilidad de skills.sh coincide con esta búsqueda.';

  @override
  String get installingSkill => 'Instalando…';

  @override
  String installedSkillArg1(Object? arg1) {
    return 'Instalado $arg1';
  }

  @override
  String skillsShInstallsArg1(Object? arg1) {
    return 'Instalaciones $arg1';
  }

  @override
  String get authVerify => 'Verificar';

  @override
  String get authCreateAccount => 'Crear cuenta';

  @override
  String get authNewInviteLink => 'Nuevo enlace de invitación';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authPasswordWillBeRejected => 'demasiado débil, será rechazado';

  @override
  String get authUsernameTooShort =>
      'Los nombres de usuario necesitan al menos 3 caracteres.';

  @override
  String get authUsernameTaken => 'Ese nombre de usuario ya está en uso.';

  @override
  String get authSignupsClosed =>
      'El registro está cerrado en este servidor. Pide una cuenta al administrador.';

  @override
  String authInsecureTransportArg1(Object? arg1) {
    return 'Este servidor solo permite iniciar sesión mediante HTTPS. Abre $arg1 en su lugar.';
  }

  @override
  String get authInsecureTransport =>
      'Este servidor solo permite iniciar sesión mediante HTTPS. Conéctate con una dirección https://.';

  @override
  String get authAccountNotFound => 'Esa cuenta ya no existe.';

  @override
  String get authQrRateLimited =>
      'Demasiadas solicitudes de inicio de sesión QR. Espere un momento y luego actualice el código.';

  @override
  String get authForgotPasswordAskAdmin =>
      '¿Has olvidado tu contraseña? Pide al administrador del servidor que la restablezca en Administrador → Usuarios.';

  @override
  String get authChangeServer => 'Cambiar servidor';

  @override
  String authSigningInToArg1(Object? arg1) {
    return 'Iniciar sesión en $arg1';
  }

  @override
  String get authNotANeoagentServer =>
      'Esta dirección no responde como un servidor NeoAgent. Verifique la URL e inténtelo nuevamente.';

  @override
  String authSecureConnectionFailedArg1(Object? arg1) {
    return 'No se pudo abrir una conexión segura (HTTPS) con $arg1.';
  }

  @override
  String authNoHttpsOrHttpArg1(Object? arg1) {
    return 'No se pudo comunicar con $arg1 a través de HTTPS y HTTP simple tampoco respondió. Verifique la dirección y el puerto.';
  }

  @override
  String get adminResetPassword => 'Restablecer contraseña';

  @override
  String adminResetPasswordForArg1(Object? arg1) {
    return 'Restablecer contraseña para $arg1';
  }

  @override
  String adminResetPasswordBodyArg1(Object? arg1) {
    return 'Elija una nueva contraseña para $arg1. Se cerrará su sesión en todos los dispositivos y se iniciará sesión nuevamente con esta contraseña.';
  }

  @override
  String get adminNewPassword => 'Nueva contraseña';

  @override
  String get adminSetPassword => 'Establecer contraseña';

  @override
  String get authMissingFields => 'Complete todos los campos obligatorios.';

  @override
  String adminAuditPasswordResetArg1Arg2(Object? arg1, Object? arg2) {
    return '$arg1 restablecer la contraseña de $arg2';
  }

  @override
  String get adminPasswordUpdated =>
      'Contraseña actualizada; el usuario cerró sesión en todas partes.';

  @override
  String get authSignInTitle => 'Iniciar sesión en NeoAgent';

  @override
  String get authSignInSubtitle =>
      'Escanee con su teléfono o use su contraseña.';

  @override
  String get authOrUsePassword => 'o usa tu contraseña';

  @override
  String get qrLoginWaitingTitle => 'Aprobar en tu teléfono';

  @override
  String get qrLoginWaitingBody =>
      'Tu teléfono escaneó el código. Confirme el inicio de sesión allí para finalizar el inicio de sesión.';

  @override
  String get qrLoginSigningInOn => 'Iniciar sesión en';

  @override
  String get qrLoginLocation => 'Ubicación';

  @override
  String get qrLoginWaitingForApproval => 'Esperando aprobación';

  @override
  String get qrLoginCancelAndUsePassword => 'Cancelar y usar una contraseña';

  @override
  String get qrLoginDeclinedOnPhone =>
      'El inicio de sesión fue rechazado en su teléfono. Escanea el nuevo código para volver a intentarlo.';

  @override
  String get signupKey => 'Clave de registro';

  @override
  String get signupKeyStepSubtitle =>
      'Las cuentas nuevas en este servidor necesitan una clave de registro. Introduzca la que le dio un administrador.';

  @override
  String get signupKeyChange => 'Cambiar';

  @override
  String get signupKeyRequiredError => 'Introduzca su clave de registro.';

  @override
  String get signupKeyInvalidError =>
      'Esa clave de registro no es válida. Revísela e inténtelo de nuevo.';

  @override
  String get signupKeyUsedError =>
      'Esa clave de registro ya se ha usado. Pida una nueva a un administrador.';

  @override
  String get adminRequireSignupKey => 'Exigir una clave de registro';

  @override
  String get adminRequireSignupKeyHint =>
      'Las cuentas nuevas necesitan una clave de un solo uso de un administrador. Si está desactivado, cualquiera que pueda acceder a este servidor puede registrarse. La primera cuenta nunca necesita clave.';

  @override
  String get adminSignupKeyRequiredNotice =>
      'Las cuentas nuevas ahora necesitan una clave de registro.';

  @override
  String get adminSignupOpenNotice => 'Ahora cualquiera puede registrarse.';

  @override
  String get signupKeys => 'Claves de registro';

  @override
  String get signupKeysDescription =>
      'Claves de un solo uso para registrarse mientras se exija una clave. Cada clave crea exactamente una cuenta.';

  @override
  String get signupKeysNew => 'Nuevas claves';

  @override
  String signupKeysFilterUnused(int count) {
    return 'Sin usar · $count';
  }

  @override
  String signupKeysFilterUsed(int count) {
    return 'Usadas · $count';
  }

  @override
  String signupKeysFilterRevoked(int count) {
    return 'Revocadas · $count';
  }

  @override
  String signupKeysFilterAll(int count) {
    return 'Todas · $count';
  }

  @override
  String get signupKeyStatusUnused => 'Sin usar';

  @override
  String get signupKeyStatusUsed => 'Usada';

  @override
  String get signupKeyStatusRevoked => 'Revocada';

  @override
  String get signupKeysExport => 'Exportar .txt';

  @override
  String get signupKeysCopied => 'Claves copiadas';

  @override
  String get signupKeyCopied => 'Clave copiada';

  @override
  String get signupKeysEmpty => 'No hay claves en esta lista.';

  @override
  String signupKeyCreatedArg1(String arg1) {
    return 'Creada el $arg1';
  }

  @override
  String signupKeyUsedByArg1Arg2(String arg1, String arg2) {
    return 'Usada por $arg1 el $arg2';
  }

  @override
  String signupKeyUsedByDeletedArg1(String arg1) {
    return 'Usada el $arg1 por una cuenta que ya se ha eliminado';
  }

  @override
  String get signupKeyRevokeTitle => '¿Revocar esta clave?';

  @override
  String get signupKeyRevokeMessage =>
      'Nadie podrá registrarse con ella. Esta acción no se puede deshacer.';

  @override
  String get signupKeyRevoked => 'Clave revocada.';

  @override
  String signupKeysShowMore(int count) {
    return 'Mostrar $count más';
  }

  @override
  String get signupKeysCreateTitle => 'Crear claves de registro';

  @override
  String get signupKeysCount => 'Número de claves';

  @override
  String get signupKeysCountHelper => 'De 1 a 500';

  @override
  String get signupKeysCountInvalid => 'Introduzca un número del 1 al 500.';

  @override
  String get signupKeysLabel => 'Etiqueta (opcional)';

  @override
  String get signupKeysLabelHint => 'p. ej., probadores beta de primavera';

  @override
  String signupKeysCreateAction(int count) {
    return 'Crear ($count)';
  }

  @override
  String signupKeysReady(int count) {
    return 'Claves listas: $count';
  }

  @override
  String get signupKeysReadyHint =>
      'Entregue cada clave a una sola persona. Las claves sin usar permanecen en la lista para que pueda copiarlas o exportarlas más tarde.';

  @override
  String get signupKeysSaveDialogTitle => 'Guardar claves de registro';

  @override
  String get signupKeysExported => 'Claves exportadas.';

  @override
  String auditSignupKeysCreated(String actor, int count) {
    return '$actor creó claves de registro ($count)';
  }

  @override
  String auditSignupKeyRevoked(String actor) {
    return '$actor revocó una clave de registro';
  }

  @override
  String get providerChooseUsername => 'Elige tu nombre de usuario';

  @override
  String get providerChooseUsernameBody =>
      'Elige un nombre de usuario disponible para terminar de crear tu cuenta.';

  @override
  String get dataSharingTitle => 'Compartir datos de uso';

  @override
  String get dataSharingDescription =>
      'Ayuda a quienes gestionan este servidor a mejorarlo. Comparte cómo usas NeoAgent, nunca lo que escribes o guardas.';

  @override
  String dataSharingSince(String date) {
    return 'Compartiendo desde el $date.';
  }

  @override
  String get dataSharingWhatsShared => 'Qué se comparte';

  @override
  String get dataSharingIncluded => 'Se comparte';

  @override
  String get dataSharingExcluded => 'Nunca se comparte';

  @override
  String get dataSharingIncludedDevice =>
      'Tipo de dispositivo y versión de la app';

  @override
  String get dataSharingIncludedLocale =>
      'Idioma de la app y región de la zona horaria, por ejemplo Europa';

  @override
  String get dataSharingIncludedFeatures =>
      'Qué funciones has configurado, como tareas, skills e integraciones';

  @override
  String get dataSharingIncludedRuns =>
      'Qué herramientas y modelos usan tus ejecuciones, con tiempos y número de tokens';

  @override
  String get dataSharingIncludedActivity =>
      'Cuándo usas NeoAgent, por día de la semana y hora';

  @override
  String get dataSharingExcludedContent => 'Mensajes, prompts y respuestas';

  @override
  String get dataSharingExcludedRuns =>
      'Títulos de ejecuciones, entradas y resultados de herramientas';

  @override
  String get dataSharingExcludedFiles =>
      'Archivos, recuerdos y todo lo que guardas';

  @override
  String get dataSharingExcludedIdentity =>
      'Tu nombre, correo, dirección IP y ubicación';

  @override
  String get dataSharingExcludedAccounts =>
      'Las cuentas con las que conectas integraciones';

  @override
  String get dataSharingPooledNote =>
      'Los administradores solo ven totales de todas las personas que comparten, nunca a ti por separado. Puedes desactivarlo cuando quieras y sales de los totales al instante.';

  @override
  String get dataSharingConfirmTitle => '¿Compartir datos de uso?';

  @override
  String get dataSharingConfirmAction => 'Compartir';

  @override
  String get sharedUsageTitle => 'Uso compartido';

  @override
  String sharedUsageParticipants(int sharing, int total) {
    return 'Cuentas que comparten datos de uso: $sharing de $total. Solo totales, sin contenido.';
  }

  @override
  String get sharedUsageEmpty =>
      'Todavía nadie comparte datos de uso. Se puede activar en Configuración, Perfil, Tus datos.';

  @override
  String get sharedUsageRuns => 'Ejecuciones compartidas';

  @override
  String get sharedUsageAvgDuration => 'Duración media';

  @override
  String get sharedUsageCompletedRuns => 'Ejecuciones completadas';

  @override
  String get sharedUsageStepsPerRun => 'Pasos por ejecución';

  @override
  String get sharedUsageDevices => 'Dispositivos';

  @override
  String get sharedUsageAppVersions => 'Versiones de la app';

  @override
  String get sharedUsageLanguages => 'Idiomas';

  @override
  String get sharedUsageRegions => 'Regiones';

  @override
  String get sharedUsageFeatures => 'Adopción de funciones';

  @override
  String get sharedUsageFeaturesDescription =>
      'Proporción de cuentas que comparten y la han configurado.';

  @override
  String get sharedUsageTools => 'Herramientas';

  @override
  String sharedUsageToolsDescription(String range) {
    return 'Herramientas más llamadas ($range).';
  }

  @override
  String sharedUsageToolCalls(String calls) {
    return 'Llamadas: $calls';
  }

  @override
  String sharedUsageToolFailures(int percent) {
    return 'Fallos: $percent %';
  }

  @override
  String get sharedUsageIntegrations => 'Integraciones';

  @override
  String get sharedUsageMessaging => 'Canales de mensajería';

  @override
  String get sharedUsageTriggers => 'Cómo empiezan las ejecuciones';

  @override
  String get sharedUsageActivity => 'Cuándo se usa';

  @override
  String get sharedUsageActivityDescription =>
      'Ejecuciones por día de la semana y hora, UTC.';

  @override
  String get sharedUsageModels => 'Rendimiento de modelos';

  @override
  String sharedUsageModelDetail(String latency, int cached, String cost) {
    return '$latency de media · $cached % en caché · $cost';
  }

  @override
  String sharedUsageAccounts(int count) {
    return 'Cuentas: $count';
  }

  @override
  String get sharedUsageNoData => 'Nada en este periodo.';

  @override
  String get sharedUsageNotReported => 'Aún sin datos';

  @override
  String get sharedUsageFeatureAgents => 'Más de un agente';

  @override
  String get sharedUsageFeatureTasks => 'Tareas programadas';

  @override
  String get sharedUsageFeatureSkills => 'Skills';

  @override
  String get sharedUsageFeatureMcp => 'Servidores MCP';

  @override
  String get sharedUsageFeatureIntegrations => 'Integraciones';

  @override
  String get sharedUsageFeatureMessaging => 'Canales de mensajería';

  @override
  String get sharedUsageFeatureMemory => 'Memoria';

  @override
  String get sharedUsageSearchKeywords =>
      'compartir datos opt-in telemetría dispositivos funciones herramientas modelos actividad';

  @override
  String get yourOAuthApp => 'Tu app OAuth';

  @override
  String oauthAppSetupTitle(String provider) {
    return 'Tu app OAuth de $provider';
  }

  @override
  String oauthAppSetupIntro(String provider) {
    return 'Este servidor no tiene una app global de $provider, así que te conectas con una app OAuth que registras tú mismo. El secreto de cliente se guarda cifrado y no se vuelve a mostrar.';
  }

  @override
  String get oauthAppStepCreate => '1. Crea la app';

  @override
  String get openDeveloperConsole => 'Abrir consola de desarrollador';

  @override
  String get oauthAppStepCallback => '2. Registra esta URL de callback';

  @override
  String get callbackUrlCopied => 'URL de callback copiada';

  @override
  String get oauthAppScopes => 'Scopes que permitir';

  @override
  String get scopesCopied => 'Scopes copiados';

  @override
  String get oauthAppStepCredentials => '3. Pega las credenciales de la app';

  @override
  String get couldNotSaveOAuthApp => 'No se pudo guardar la app OAuth.';

  @override
  String removeOAuthAppTitle(String provider) {
    return '¿Quitar tu app de $provider?';
  }

  @override
  String get removeOAuthAppBody =>
      'Las cuentas conectadas siguen en la lista, pero dejan de funcionar hasta que vuelvas a añadir una app.';

  @override
  String get globalIntegrationConfiguration =>
      'Configuración global de integraciones';

  @override
  String get globalIntegrationConfigurationDescription =>
      'Apps OAuth opcionales para todo el servidor. Si una integración tiene una, todas las cuentas la usan y no pueden añadir la suya. Deja una integración sin configurar y cada usuario configurará su propia app. Los secretos son de solo escritura: déjalo en blanco para conservar el valor guardado.';

  @override
  String get globalStatus => 'Global';

  @override
  String get perUserStatus => 'Por usuario';

  @override
  String get phoneSyncGuidance =>
      'Comparte los calendarios y contactos de este teléfono con tu agente. Funciona con todas las cuentas que ya tiene el teléfono.';

  @override
  String get phoneSyncElsewhereGuidance =>
      'Abre NeoAgent en tu teléfono y activa allí el uso compartido. Tu agente verá los calendarios y contactos de todas las cuentas de ese teléfono.';

  @override
  String get manageOnThisPhone => 'Gestionar en este teléfono';

  @override
  String get setUpOnThisPhone => 'Configurar en este teléfono';

  @override
  String get setUpOnPhone => 'Configurar en tu teléfono';

  @override
  String emailConnectedArg1(String email) {
    return '$email conectado';
  }

  @override
  String get couldNotConnectEmail => 'No se pudo conectar esta cuenta.';

  @override
  String get emailSetupTitle => 'Conectar correo y calendario';

  @override
  String get emailChecking => 'Comprobando tu buzón…';

  @override
  String get emailSetupIntro =>
      'Usa una contraseña de aplicación de tu proveedor de correo. Sin consola de desarrollador, listo en un par de minutos.';

  @override
  String emailOpenArg1(String provider) {
    return 'Abrir $provider';
  }

  @override
  String get emailStepServers => '1. Introduce tus servidores';

  @override
  String get emailStepPassword => '1. Crea una contraseña de aplicación';

  @override
  String emailOpenPasswordPageArg1(String provider) {
    return 'Abrir contraseñas de aplicación de $provider';
  }

  @override
  String get emailStepSignIn => '2. Inicia sesión';

  @override
  String get appPassword => 'Contraseña de aplicación';

  @override
  String get appPasswordHelper =>
      'Los espacios no importan. NeoAgent la guarda cifrada.';

  @override
  String get emailUsernameOptional => 'Usuario, si no es tu correo';

  @override
  String get emailIncludeCalendar => 'Incluir calendario';

  @override
  String get emailIncludeContacts => 'Incluir contactos';

  @override
  String get imapServer => 'Servidor IMAP';

  @override
  String get smtpServer => 'Servidor SMTP';

  @override
  String get caldavUrlOptional => 'URL de CalDAV (opcional)';

  @override
  String get carddavUrlOptional => 'URL de CardDAV (opcional)';

  @override
  String get alternativeEmail =>
      'Conecta tu buzón con una contraseña de aplicación, o tu calendario con su enlace iCal. Listo en un par de minutos.';

  @override
  String get alternativePhone =>
      'Comparte el calendario y los contactos que ya tienes en el teléfono con la app NeoAgent.';

  @override
  String get alternativePhoneElsewhere =>
      'Comparte el calendario y los contactos que ya tienes en el teléfono. Configúralo en la app NeoAgent del teléfono.';

  @override
  String get skipTheDeveloperConsole => 'Sin consola de desarrollador';

  @override
  String get phoneSyncPromptTitle => '¿Dejas que tu agente vea tu calendario?';

  @override
  String get phoneSyncPromptBody =>
      'Comparte los calendarios y contactos de este teléfono para que tu agente planifique tu día. Puedes cambiarlo cuando quieras en Herramientas › Integraciones.';

  @override
  String get phoneSyncTitle =>
      'Compartir calendario y contactos de este teléfono';

  @override
  String get phoneSyncIntro =>
      'Tu agente ve los calendarios y contactos de todas las cuentas de este teléfono. Sin consola de desarrollador ni inicio de sesión extra.';

  @override
  String get phoneSyncPointAccounts =>
      'Funciona con las cuentas de Google, Outlook, iCloud y Exchange de este teléfono.';

  @override
  String get phoneSyncPointPrivate =>
      'Solo se comparte con tu servidor NeoAgent, que lo guarda cifrado.';

  @override
  String get phoneSyncPointWrites =>
      'Los eventos que añade tu agente los crea este teléfono y se sincronizan como siempre.';

  @override
  String get phoneSyncCalendarHint =>
      'Eventos desde hace 30 días hasta dentro de 90';

  @override
  String get phoneSyncContacts => 'Contactos';

  @override
  String get phoneSyncContactsHint => 'Nombres, correos y números de teléfono';

  @override
  String get phoneSyncOtherAgent =>
      'Este teléfono comparte con otro agente. Compartir aquí lo pasa a este agente.';

  @override
  String get phoneSyncDenied =>
      'NeoAgent aún no tiene acceso. Permítelo en Ajustes y vuelve.';

  @override
  String get openPhoneSettings => 'Abrir Ajustes';

  @override
  String get phoneSyncShare => 'Compartir con NeoAgent';

  @override
  String get phoneSyncStop => 'Dejar de compartir';

  @override
  String get phoneSyncWaiting => 'Esperando la primera sincronización…';

  @override
  String phoneSyncLastSyncedArg1(String time) {
    return 'Última sincronización $time';
  }

  @override
  String get calendarLink => 'Enlace del calendario';

  @override
  String get calendarLinkHelper =>
      'La dirección iCal del calendario. Quien la tenga puede leer el calendario, así que mantenla privada.';

  @override
  String get calendarLinkName => 'Nombre (opcional)';

  @override
  String get calendarLinkAdded => 'Calendario añadido';
}
