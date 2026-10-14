part of 'main.dart';

class _ProviderUsernameForm extends StatefulWidget {
  const _ProviderUsernameForm({required this.controller});

  final NeoAgentController controller;

  @override
  State<_ProviderUsernameForm> createState() => _ProviderUsernameFormState();
}

class _ProviderUsernameFormState extends State<_ProviderUsernameForm> {
  final _username = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: AuthProviderIcon(
            provider: controller.pendingRegistrationProvider,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          appStrings.providerChooseUsername,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appStrings.providerChooseUsernameBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary),
        ),
        const SizedBox(height: 24),
        _FormTextField(
          controller: _username,
          label: appStrings.username,
          onChanged: (_) => controller.clearInlineError(),
        ),
        if (controller.errorMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          _InlineError(message: controller.errorMessage!),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: controller.isAuthenticating
              ? null
              : () => controller.completeProviderRegistration(_username.text),
          child: Text(appStrings.continue2),
        ),
        TextButton(
          onPressed: controller.isAuthenticating
              ? null
              : controller.cancelProviderRegistration,
          child: Text(appStrings.cancel),
        ),
      ],
    );
  }
}
