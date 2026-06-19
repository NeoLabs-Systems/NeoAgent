part of 'main.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtPrice(int cents, String currency, {String? interval}) {
  final amount = cents / 100;
  final sym = currency.toUpperCase() == 'USD' ? '\$' : '€';
  final str = amount == amount.truncateToDouble()
      ? '$sym${amount.toInt()}'
      : '$sym${amount.toStringAsFixed(2)}';
  if (interval == null || interval.isEmpty) return '$str forever';
  return '$str / $interval';
}

String _fmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  } catch (_) {
    return iso.substring(0, 10);
  }
}

String _fmtTs(int? ts) {
  if (ts == null) return '—';
  return _fmtDate(DateTime.fromMillisecondsSinceEpoch(ts * 1000).toIso8601String());
}

Color _statusColor(String? status) {
  switch (status) {
    case 'active':    return _success;
    case 'trialing':  return _warning;
    case 'past_due':  return _danger;
    default:          return _textMuted;
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
}

// ── Plan icon/color helpers ────────────────────────────────────────────────────

const List<_PlanStyle> _planStyles = <_PlanStyle>[
  _PlanStyle(Icons.spa_outlined,        Color(0xFF84BA87), Color(0x2084BA87)),
  _PlanStyle(Icons.bolt_outlined,       Color(0xFFE1B052), Color(0x20E1B052)),
  _PlanStyle(Icons.group_outlined,      Color(0xFF6FB0A4), Color(0x206FB0A4)),
  _PlanStyle(Icons.star_outline,        Color(0xFFDE8A78), Color(0x20DE8A78)),
  _PlanStyle(Icons.rocket_launch_outlined, Color(0xFFB39DDB), Color(0x20B39DDB)),
];

class _PlanStyle {
  const _PlanStyle(this.icon, this.color, this.bg);
  final IconData icon;
  final Color color;
  final Color bg;
}

_PlanStyle _styleForPlan(int index) =>
    _planStyles[index % _planStyles.length];

// ── Main panel ────────────────────────────────────────────────────────────────

enum _BillingTab { overview, plans, history }

class BillingPanel extends StatefulWidget {
  const BillingPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<BillingPanel> createState() => _BillingPanelState();
}

class _BillingPanelState extends State<BillingPanel> {
  _BillingTab _tab = _BillingTab.overview;
  bool _annual = false;

  NeoAgentController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.refreshBilling();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = _c.billingSubscription;
    final planName = sub?['plan']?['name'] as String? ?? '';
    final status = sub?['status'] as String? ?? '';
    final compact = MediaQuery.sizeOf(context).width < 860;

    return _EntranceMotion(
      child: ListView(
        padding: _pagePadding(context),
        children: <Widget>[
          // ── Page header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('SETTINGS', style: _sectionEyebrowStyle()),
                      const SizedBox(height: 6),
                      Text('Billing & subscription',
                          style: _displayTitleStyle(26)),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your plan, track usage, update payment, and review invoices.',
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                      if (planName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        _BillingStatusPill(plan: planName, status: status),
                      ],
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('SETTINGS', style: _sectionEyebrowStyle()),
                            const SizedBox(height: 8),
                            Text('Billing & subscription',
                                style: _displayTitleStyle(32)),
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 640),
                              child: Text(
                                'Manage your plan, track usage, update payment, and review invoices — all in one place.',
                                style: TextStyle(
                                    color: _textSecondary, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (planName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _BillingStatusPill(plan: planName, status: status),
                        ),
                    ],
                  ),
          ),

          // ── Tab bar ──────────────────────────────────────────────────────
          _BillingTabBar(
            selected: _tab,
            invoiceCount: _c.billingInvoices.length,
            onSelect: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 20),

          // ── Tab content ──────────────────────────────────────────────────
          if (_c.isLoadingBilling && sub == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_tab == _BillingTab.overview)
            _BillingOverviewTab(
              controller: _c,
              onChangePlan: () => setState(() => _tab = _BillingTab.plans),
            )
          else if (_tab == _BillingTab.plans)
            _BillingPlansTab(
              controller: _c,
              annual: _annual,
              onToggleAnnual: (v) => setState(() => _annual = v),
            )
          else
            _BillingHistoryTab(controller: _c),
        ],
      ),
    );
  }
}

// ── Status pill ───────────────────────────────────────────────────────────────

class _BillingStatusPill extends StatelessWidget {
  const _BillingStatusPill({required this.plan, required this.status});

  final String plan;
  final String status;

  @override
  Widget build(BuildContext context) {
    final dotColor = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _borderLight),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: dotColor.withValues(alpha: 0.45), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$plan · $status',
            style: GoogleFonts.geist(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _BillingTabBar extends StatelessWidget {
  const _BillingTabBar({
    required this.selected,
    required this.invoiceCount,
    required this.onSelect,
  });

  final _BillingTab selected;
  final int invoiceCount;
  final ValueChanged<_BillingTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          _tab(_BillingTab.overview, 'Overview', null),
          _tab(_BillingTab.plans, 'Plans', null),
          _tab(_BillingTab.history, 'Billing history',
              invoiceCount > 0 ? '$invoiceCount' : null),
        ],
      ),
    );
  }

  Widget _tab(_BillingTab tab, String label, String? badge) {
    final active = selected == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? _bgSecondary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: GoogleFonts.geist(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? _textPrimary : _textMuted,
                ),
              ),
              if (badge != null) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _accentMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.geist(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _BillingOverviewTab extends StatefulWidget {
  const _BillingOverviewTab({
    required this.controller,
    required this.onChangePlan,
  });

  final NeoAgentController controller;
  final VoidCallback onChangePlan;

  @override
  State<_BillingOverviewTab> createState() => _BillingOverviewTabState();
}

class _BillingOverviewTabState extends State<_BillingOverviewTab> {
  bool _canceling = false;

  NeoAgentController get _c => widget.controller;

  Future<void> _openPortal() async {
    final url = await _c.createPortalSession();
    if (url != null) await _openUrl(url);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        title: Text('Cancel subscription',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Your subscription will remain active until the end of the billing period.',
          style: TextStyle(color: _textSecondary),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep plan',
                style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Cancel subscription',
                style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _canceling = true);
    await _c.cancelBillingSubscription();
    if (mounted) setState(() => _canceling = false);
  }

  @override
  Widget build(BuildContext context) {
    final sub = _c.billingSubscription;
    if (sub == null) {
      return _NoSubscriptionCard(onViewPlans: widget.onChangePlan);
    }

    final plan = sub['plan'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final planName = plan['name'] as String? ?? 'Unknown';
    final priceCents = (plan['price_cents'] as num?)?.toInt() ?? 0;
    final currency = plan['currency'] as String? ?? 'usd';
    final interval = plan['interval'] as String? ?? '';
    final status = sub['status'] as String? ?? '';
    final periodEnd = sub['current_period_end'] as String?;
    final cancelAtEnd = sub['cancel_at_period_end'] == true;
    final isTrialing = status == 'trialing';
    final trialEnds = sub['trial_ends_at'] as String?;
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Current plan card ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border.all(color: _borderLight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _planCardContent(planName, priceCents, currency, interval,
                        status, periodEnd, cancelAtEnd, isTrialing, trialEnds),
                    const SizedBox(height: 16),
                    _planCardActions(compact),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _planCardContent(
                          planName, priceCents, currency, interval, status,
                          periodEnd, cancelAtEnd, isTrialing, trialEnds),
                    ),
                    const SizedBox(width: 20),
                    _planCardActions(compact),
                  ],
                ),
        ),
        const SizedBox(height: 24),

        // ── Usage this period ────────────────────────────────────────────
        Row(
          children: <Widget>[
            Text('Usage this period',
                style: GoogleFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                )),
            const Spacer(),
            if (periodEnd != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _bgCard,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.refresh, size: 12, color: _textMuted),
                    const SizedBox(width: 5),
                    Text('Resets ${_fmtDate(periodEnd)}',
                        style: TextStyle(fontSize: 12, color: _textMuted)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _UsageGrid(controller: _c, plan: plan),
      ],
    );
  }

  Widget _planCardContent(
    String planName,
    int priceCents,
    String currency,
    String interval,
    String status,
    String? periodEnd,
    bool cancelAtEnd,
    bool isTrialing,
    String? trialEnds,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'CURRENT PLAN',
          style: GoogleFonts.geistMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(planName,
                style: GoogleFonts.geist(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: _textPrimary,
                )),
            const SizedBox(width: 10),
            Text(
              _fmtPrice(priceCents, currency, interval: interval),
              style: TextStyle(
                fontSize: 15,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isTrialing
              ? 'Trial ends ${_fmtDate(trialEnds)}'
              : cancelAtEnd
                  ? 'Cancels at end of period · ${_fmtDate(periodEnd)}'
                  : periodEnd != null
                      ? 'Renews ${_fmtDate(periodEnd)}'
                      : status,
          style: TextStyle(fontSize: 13, color: _textMuted),
        ),
      ],
    );
  }

  Widget _planCardActions(bool compact) {
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
      children: <Widget>[
        FilledButton.icon(
          onPressed: widget.onChangePlan,
          icon: const Icon(Icons.swap_horiz_outlined, size: 16),
          label: const Text('Change plan'),
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: _bgPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _canceling ? null : _cancel,
          icon: _canceling
              ? const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('Cancel subscription'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _danger,
            side: BorderSide(color: _danger.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openPortal,
          icon: const Icon(Icons.open_in_new_outlined, size: 14),
          label: const Text('Manage payment'),
          style: TextButton.styleFrom(
            foregroundColor: _textMuted,
            textStyle: const TextStyle(fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ),
      ],
    );
  }
}

class _NoSubscriptionCard extends StatelessWidget {
  const _NoSubscriptionCard({required this.onViewPlans});

  final VoidCallback onViewPlans;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.credit_card_off_outlined, size: 40, color: _textMuted),
          const SizedBox(height: 16),
          Text('No active subscription',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          Text('Choose a plan to get started.',
              style: TextStyle(fontSize: 13, color: _textMuted)),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onViewPlans,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: _bgPrimary,
            ),
            child: const Text('View plans'),
          ),
        ],
      ),
    );
  }
}

// ── Usage grid ────────────────────────────────────────────────────────────────

class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.controller, required this.plan});

  final NeoAgentController controller;
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final usage = controller.tokenUsage;
    final usageLimits = controller.usageAndLimits;

    final cards = <_UsageCardData>[
      _UsageCardData(
        icon: Icons.bolt_outlined,
        label: 'Agent runs (7d)',
        value: usage?.last7DaysRuns ?? 0,
        max: null,
        display: usage != null ? '${usage.last7DaysRuns}' : '—',
      ),
      _UsageCardData(
        icon: Icons.token_outlined,
        label: 'Weekly tokens',
        value: usageLimits?.weeklyUsage ?? usage?.last7DaysTokens ?? 0,
        max: usageLimits?.weeklyLimit,
        display: _fmtTokenCount(
            usageLimits?.weeklyUsage ?? usage?.last7DaysTokens ?? 0),
      ),
      _UsageCardData(
        icon: Icons.timer_outlined,
        label: '4h token window',
        value: usageLimits?.fourHourUsage ?? 0,
        max: usageLimits?.fourHourLimit,
        display: _fmtTokenCount(usageLimits?.fourHourUsage ?? 0),
      ),
      _UsageCardData(
        icon: Icons.memory_outlined,
        label: 'Total runs',
        value: usage?.totalRuns ?? 0,
        max: null,
        display: usage != null ? _fmtTokenCount(usage.totalRuns) : '—',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 560 ? 1 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: crossCount == 1 ? 3.5 : 2.6,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _UsageCard(data: cards[i]),
        );
      },
    );
  }

  static String _fmtTokenCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

class _UsageCardData {
  const _UsageCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
    required this.display,
  });

  final IconData icon;
  final String label;
  final int value;
  final int? max;
  final String display;
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.data});

  final _UsageCardData data;

  @override
  Widget build(BuildContext context) {
    final ratio = data.max != null && data.max! > 0
        ? (data.value / data.max!).clamp(0.0, 1.0)
        : null;
    final barColor = ratio == null
        ? _accentAlt
        : ratio > 0.85
            ? _danger
            : ratio > 0.65
                ? _warning
                : _accentAlt;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(data.icon, size: 15, color: _accentAlt),
              const SizedBox(width: 7),
              Expanded(
                child: Text(data.label,
                    style: TextStyle(fontSize: 12, color: _textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(data.display,
                  style: GoogleFonts.geist(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  )),
              if (data.max != null) ...<Widget>[
                const SizedBox(width: 4),
                Text(' / ${_UsageGrid._fmtTokenCount(data.max!)}',
                    style: TextStyle(fontSize: 13, color: _textMuted)),
              ],
            ],
          ),
          if (ratio != null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: _bgSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Plans tab ─────────────────────────────────────────────────────────────────

class _BillingPlansTab extends StatefulWidget {
  const _BillingPlansTab({
    required this.controller,
    required this.annual,
    required this.onToggleAnnual,
  });

  final NeoAgentController controller;
  final bool annual;
  final ValueChanged<bool> onToggleAnnual;

  @override
  State<_BillingPlansTab> createState() => _BillingPlansTabState();
}

class _BillingPlansTabState extends State<_BillingPlansTab> {
  String? _checkingOut;

  NeoAgentController get _c => widget.controller;

  Future<void> _checkout(String planId) async {
    setState(() => _checkingOut = planId);
    final url = await _c.createCheckoutSession(planId);
    if (!mounted) return;
    setState(() => _checkingOut = null);
    if (url != null) await _openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final allPlans = _c.billingPlans;
    if (allPlans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('No plans configured yet.',
              style: TextStyle(color: _textMuted)),
        ),
      );
    }

    // Filter by interval: annual = 'year', monthly = 'month'
    final monthly =
        allPlans.where((p) => p['interval'] == 'month' || p['price_cents'] == 0).toList();
    final yearly =
        allPlans.where((p) => p['interval'] == 'year').toList();
    final hasAnnual = yearly.isNotEmpty;
    final plans = widget.annual && hasAnnual ? yearly : monthly;
    final currentPlanId =
        _c.billingSubscription?['plan_id'] as String?;

    // Savings pct
    int? savingsPct;
    if (hasAnnual && monthly.isNotEmpty && yearly.isNotEmpty) {
      final mp = (monthly.first['price_cents'] as num?)?.toInt() ?? 0;
      final yp = (yearly.first['price_cents'] as num?)?.toInt() ?? 0;
      if (mp > 0) {
        savingsPct = (((mp * 12 - yp) / (mp * 12)) * 100).round();
      }
    }

    // Recommended = middle plan (or plan with sort_order matching middle index)
    final recommendedIndex = plans.length > 2 ? 1 : (plans.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Monthly / Annual toggle ──────────────────────────────────────
        Row(
          children: <Widget>[
            _IntervalToggle(
              annual: widget.annual,
              onToggle: hasAnnual ? widget.onToggleAnnual : null,
            ),
            if (savingsPct != null && savingsPct > 0) ...<Widget>[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Save up to $savingsPct% yearly',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _success,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ── Plan cards ────────────────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth < 480
                ? 1
                : constraints.maxWidth < 900
                    ? plans.length.clamp(1, 2)
                    : plans.length.clamp(1, 3);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: crossCount == 1 ? 2.0 : 0.72,
              ),
              itemCount: plans.length,
              itemBuilder: (_, i) => _PlanCard(
                plan: plans[i],
                style: _styleForPlan(i),
                recommended: i == recommendedIndex,
                current: plans[i]['id'] == currentPlanId,
                loading: _checkingOut == plans[i]['id'] as String?,
                onSelect: () =>
                    _checkout(plans[i]['id'] as String),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _IntervalToggle extends StatelessWidget {
  const _IntervalToggle({required this.annual, this.onToggle});

  final bool annual;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _pill('Monthly', !annual, () => onToggle?.call(false)),
          _pill('Annual', annual, () => onToggle?.call(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.geist(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? _bgPrimary : _textMuted,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.style,
    required this.recommended,
    required this.current,
    required this.loading,
    required this.onSelect,
  });

  final Map<String, dynamic> plan;
  final _PlanStyle style;
  final bool recommended;
  final bool current;
  final bool loading;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final name = plan['name'] as String? ?? '';
    final desc = plan['description'] as String? ?? '';
    final priceCents = (plan['price_cents'] as num?)?.toInt() ?? 0;
    final currency = plan['currency'] as String? ?? 'usd';
    final interval = plan['interval'] as String? ?? '';
    final features = _asList<String>(plan['features']);

    return Stack(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border.all(
              color: recommended
                  ? _accent.withValues(alpha: 0.5)
                  : _borderLight,
              width: recommended ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Icon + name
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: style.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(style.icon, color: style.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(name,
                              style: GoogleFonts.geist(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                letterSpacing: -0.3,
                              )),
                          if (desc.isNotEmpty)
                            Text(desc,
                                style: TextStyle(
                                    fontSize: 12, color: _textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      () {
                        final sym = currency.toUpperCase() == 'USD' ? '\$' : '€';
                        final amt = priceCents / 100;
                        return priceCents == 0
                            ? '${sym}0'
                            : amt == amt.truncateToDouble()
                                ? '$sym${amt.toInt()}'
                                : '$sym${amt.toStringAsFixed(2)}';
                      }(),
                      style: GoogleFonts.geist(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    if (interval.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 4),
                      Text(' / $interval',
                          style: TextStyle(
                              fontSize: 13, color: _textMuted)),
                    ] else ...<Widget>[
                      const SizedBox(width: 6),
                      Text('forever',
                          style: TextStyle(
                              fontSize: 13, color: _textMuted)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Features
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.check_circle_outline,
                          size: 15, color: _accentAlt),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 13, color: _textSecondary)),
                      ),
                    ],
                  ),
                )),

                const Spacer(),
                const SizedBox(height: 14),

                // Action button
                SizedBox(
                  width: double.infinity,
                  child: current
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _border),
                            foregroundColor: _textMuted,
                          ),
                          child: const Text('Current plan'),
                        )
                      : FilledButton(
                          onPressed: loading ? null : onSelect,
                          style: FilledButton.styleFrom(
                            backgroundColor: recommended ? _accent : _bgSecondary,
                            foregroundColor:
                                recommended ? _bgPrimary : _textPrimary,
                          ),
                          child: loading
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5),
                                )
                              : Text(
                                  priceCents == 0
                                      ? 'Get started'
                                      : 'Choose $name'),
                        ),
                ),
              ],
            ),
          ),
        ),

        // Recommended badge
        if (recommended)
          Positioned(
            top: -1,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  'RECOMMENDED',
                  style: GoogleFonts.geistMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: _bgPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static List<T> _asList<T>(dynamic val) {
    if (val is List) return val.whereType<T>().toList();
    return <T>[];
  }
}

// ── Billing history tab ───────────────────────────────────────────────────────

class _BillingHistoryTab extends StatefulWidget {
  const _BillingHistoryTab({required this.controller});

  final NeoAgentController controller;

  @override
  State<_BillingHistoryTab> createState() => _BillingHistoryTabState();
}

class _BillingHistoryTabState extends State<_BillingHistoryTab> {
  bool _openingPortal = false;

  NeoAgentController get _c => widget.controller;

  Future<void> _openPortal() async {
    setState(() => _openingPortal = true);
    final url = await _c.createPortalSession();
    if (!mounted) return;
    setState(() => _openingPortal = false);
    if (url != null) await _openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _c.billingInvoices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── Payment method card ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _bgCard,
            border: Border.all(color: _borderLight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _bgSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: Icon(Icons.credit_card_outlined,
                    size: 20, color: _textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Payment method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text('Manage via Stripe Customer Portal',
                        style: TextStyle(fontSize: 12, color: _textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _openingPortal ? null : _openPortal,
                icon: _openingPortal
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.open_in_new_outlined, size: 14),
                label: const Text('Update'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textSecondary,
                  side: BorderSide(color: _borderLight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Billing history ──────────────────────────────────────────────
        Row(
          children: <Widget>[
            Text('Billing history',
                style: GoogleFonts.geist(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                )),
            const Spacer(),
            if (invoices.isNotEmpty)
              TextButton.icon(
                onPressed: _openPortal,
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Export all'),
                style: TextButton.styleFrom(
                  foregroundColor: _textMuted,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (invoices.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _bgCard,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('No invoices yet.',
                  style: TextStyle(color: _textMuted, fontSize: 13)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: _bgCard,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: _bgSecondary,
                  child: Row(
                    children: <Widget>[
                      _hCell('Date', flex: 2),
                      _hCell('Description', flex: 3),
                      _hCell('Invoice', flex: 2),
                      _hCell('Status', flex: 2),
                      _hCell('Amount', flex: 2),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
                ...invoices.asMap().entries.map((e) => _InvoiceRow(
                    invoice: e.value,
                    last: e.key == invoices.length - 1)),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _hCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.geistMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: _textMuted,
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.last});

  final Map<String, dynamic> invoice;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] as String? ?? '—';
    final created = invoice['created'] as int?;
    final amountPaid = (invoice['amount_paid'] as num?)?.toInt() ?? 0;
    final currency = invoice['currency'] as String? ?? 'usd';
    final pdfUrl = invoice['invoice_pdf'] as String?;
    final hostedUrl = invoice['hosted_invoice_url'] as String?;

    final sym = currency.toUpperCase() == 'USD' ? '\$' : '€';
    final amountStr =
        '$sym${(amountPaid / 100).toStringAsFixed(2)}';

    Color statusColor;
    switch (status) {
      case 'paid':
        statusColor = _success;
        break;
      case 'open':
      case 'uncollectible':
        statusColor = _warning;
        break;
      case 'void':
        statusColor = _textMuted;
        break;
      default:
        statusColor = _textMuted;
    }

    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Text(_fmtTs(created),
                  style: TextStyle(fontSize: 13, color: _textSecondary)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _deriveDesc(invoice),
                style: TextStyle(fontSize: 13, color: _textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                invoice['number'] as String? ?? '—',
                style: TextStyle(
                    fontSize: 12,
                    color: _textMuted,
                    fontFamily: 'GeistMono'),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(amountStr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  )),
            ),
            SizedBox(
              width: 36,
              child: IconButton(
                icon: const Icon(Icons.download_outlined, size: 16),
                color: _textMuted,
                padding: EdgeInsets.zero,
                tooltip: 'Download PDF',
                onPressed: pdfUrl != null
                    ? () => _openUrl(pdfUrl)
                    : hostedUrl != null
                        ? () => _openUrl(hostedUrl)
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _deriveDesc(Map<String, dynamic> inv) {
    final lines = inv['lines'] as List?;
    if (lines != null && lines.isNotEmpty) {
      final first = lines.first;
      if (first is Map) return first['description'] as String? ?? '';
    }
    return inv['description'] as String? ?? 'Invoice';
  }
}
