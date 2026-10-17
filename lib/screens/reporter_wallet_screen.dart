import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/redeem_request.dart';
import '../state/app_state.dart';
import '../services/api_service.dart';
import '../core/navigation/auth_guard.dart';
import 'redeem_request_screen.dart';

/// Rewards & earnings: the coin balance, what it is worth, how much has been
/// earned and withdrawn, every coin earned (which story, when) and every
/// withdrawal request (amount, where to, status, reference).
///
/// Data: GET /rewards/wallet/, /rewards/transactions/, /rewards/payouts/.
class ReporterWalletScreen extends StatefulWidget {
  const ReporterWalletScreen({super.key});

  @override
  State<ReporterWalletScreen> createState() => _ReporterWalletScreenState();
}

enum _Tab { earnings, withdrawals }

class _ReporterWalletScreenState extends State<ReporterWalletScreen> {
  RewardWallet? _wallet;
  List<RewardTransaction> _transactions = [];
  List<RewardPayout> _payouts = [];
  bool _loading = false;
  bool _failed = false;
  bool _openingPayout = false;
  bool _loadingMore = false;
  String? _txNext;
  String? _payoutNext;
  _Tab _tab = _Tab.earnings;

  static const _red = Color(0xFFE0001B);
  static const _green = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadWallet();
    });
  }

  Future<void> _loadWallet() async {
    if (_loading || !AppState.instance.isLoggedIn) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // The three load together; history failing must not hide the
      // balance, so each history call is caught on its own.
      const empty = (items: <dynamic>[], next: null as String?);
      final api = ApiService.instance;
      final wallet = api.getRewardWallet();
      final txPage = api.getRewardTransactionsPage().catchError((_) => empty);
      final payoutPage = api.getRewardPayoutsPage().catchError((_) => empty);
      final w = await wallet;
      final tx = await txPage;
      final po = await payoutPage;
      if (!mounted) return;
      setState(() {
        _wallet = RewardWallet.fromJson(w);
        _transactions = _parseTx(tx.items);
        _txNext = tx.next;
        _payouts = _parsePayouts(po.items);
        _payoutNext = po.next;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'వివరాలు లోడ్ కాలేదు. ఇంటర్నెట్ చూసి మళ్లీ ప్రయత్నించండి.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'మళ్లీ', onPressed: _loadWallet),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<RewardTransaction> _parseTx(List<dynamic> items) => items
      .whereType<Map>()
      .map((j) => RewardTransaction.fromJson(Map<String, dynamic>.from(j)))
      .toList();

  static List<RewardPayout> _parsePayouts(List<dynamic> items) => items
      .whereType<Map>()
      .map((j) => RewardPayout.fromJson(Map<String, dynamic>.from(j)))
      .toList();

  /// Next cursor page of the open tab (while `meta.next` is not null).
  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final earnings = _tab == _Tab.earnings;
    final next = earnings ? _txNext : _payoutNext;
    if (next == null) return;
    setState(() => _loadingMore = true);
    try {
      final api = ApiService.instance;
      if (earnings) {
        final page = await api.getRewardTransactionsPage(nextUrl: next);
        if (!mounted) return;
        setState(() {
          _transactions = [..._transactions, ..._parseTx(page.items)];
          _txNext = page.next;
        });
      } else {
        final page = await api.getRewardPayoutsPage(nextUrl: next);
        if (!mounted) return;
        setState(() {
          _payouts = [..._payouts, ..._parsePayouts(page.items)];
          _payoutNext = page.next;
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('ఇంకా లోడ్ కాలేదు. మళ్లీ ప్రయత్నించండి.'),
      ));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openPayout() async {
    if (_openingPayout) return;
    _openingPayout = true;
    try {
      if (!await ensureAuth(context) || !mounted) return;
      await _loadWallet();
      final wallet = _wallet;
      if (!mounted || wallet == null) return;
      if (wallet.availableCoins < wallet.minimumWithdrawalCoins) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'విత్‌డ్రా కోసం ఇంకా ${wallet.minimumWithdrawalCoins - wallet.availableCoins} కాయిన్లు కావాలి',
          ),
        ));
        return;
      }
      final submitted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RedeemRequestScreen(
            availableCoins: wallet.availableCoins,
            minimumCoins: wallet.minimumWithdrawalCoins,
            coinValue: wallet.coinValueRupees,
          ),
        ),
      );
      if (mounted && submitted == true) {
        setState(() => _tab = _Tab.withdrawals);
        await _loadWallet();
      }
    } finally {
      _openingPayout = false;
    }
  }

  // --- formatting -----------------------------------------------------------

  static String rupees(double v) =>
      '₹${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2)}';

  static String date(DateTime d) {
    const m = [
      'జన',
      'ఫిబ్ర',
      'మార్చి',
      'ఏప్రి',
      'మే',
      'జూన్',
      'జూలై',
      'ఆగ',
      'సెప్టెం',
      'అక్టో',
      'నవం',
      'డిసెం'
    ];
    final l = d.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} ${m[l.month - 1]} ${l.year}, $h:$mm ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  String _statusLabel(RedeemStatus s) => switch (s) {
        RedeemStatus.requested => 'పెండింగ్',
        RedeemStatus.processing => 'ప్రాసెసింగ్',
        RedeemStatus.paid => 'చెల్లించబడింది',
        RedeemStatus.rejected => 'తిరస్కరించబడింది',
        RedeemStatus.cancelled => 'రద్దు చేయబడింది',
      };

  Color _statusColor(RedeemStatus s) => switch (s) {
        RedeemStatus.requested => const Color(0xFFD97706),
        RedeemStatus.processing => const Color(0xFF3B82F6),
        RedeemStatus.paid => _green,
        RedeemStatus.rejected => const Color(0xFFEF4444),
        RedeemStatus.cancelled => const Color(0xFF6B7280),
      };

  /// What a ledger line was for, in plain words.
  String _txLabel(RewardTransaction t) => switch (t.kind) {
        RewardTxKind.earn => 'వార్త ఆమోదం – రివార్డ్',
        RewardTxKind.hold => 'విత్‌డ్రా అభ్యర్థన – హోల్డ్',
        RewardTxKind.release => 'విత్‌డ్రా రద్దు – తిరిగి జమ',
        RewardTxKind.paid => 'విత్‌డ్రా చెల్లించబడింది',
        RewardTxKind.adminCredit => 'అడ్మిన్ జమ',
        RewardTxKind.adminDebit => 'అడ్మిన్ కోత',
        RewardTxKind.other => 'కాయిన్ మార్పు',
      };

  /// The sign, colour and icon of a ledger line.
  ({String sign, Color color, IconData icon}) _txStyle(RewardTransaction t) {
    if (t.isNeutral) {
      return (
        sign: '',
        color: const Color(0xFF3B82F6),
        icon: Icons.check_circle_outline_rounded
      );
    }
    if (t.kind == RewardTxKind.hold) {
      return (
        sign: '−',
        color: const Color(0xFFD97706),
        icon: Icons.hourglass_top_rounded
      );
    }
    return t.isCredit
        ? (sign: '+', color: _green, icon: Icons.add_circle_outline_rounded)
        : (sign: '−', color: _red, icon: Icons.remove_circle_outline_rounded);
  }

  Widget _moreButton(String? next, Color muted) {
    if (next == null) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        key: const Key('wallet_load_more'),
        onPressed: _loadingMore ? null : _loadMore,
        child: _loadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _red))
            : const Text('ఇంకా చూపించు',
                style: TextStyle(color: _red, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF6F6F8);
    final card = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final line = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEDEDF0);

    final w = _wallet;
    final coinValue = w?.coinValueRupees ?? 1.0;
    final available = w?.availableCoins ?? 0;
    final minimum = w?.minimumWithdrawalCoins ?? AppState.tokensNeededToRedeem;
    final progress = minimum > 0 ? (available / minimum).clamp(0.0, 1.0) : 1.0;
    final canRedeem = w != null && available >= minimum;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('రివార్డ్‌లు & ఆదాయాలు',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _loadWallet,
        child: ListView(
          key: const Key('wallet_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (w == null && _loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator(color: _red)),
              )
            else if (w == null && _failed)
              _ErrorPanel(onRetry: _loadWallet, muted: muted)
            else ...[
              _balanceCard(
                  available,
                  w?.availableValueRupees ?? available * coinValue,
                  coinValue,
                  minimum,
                  progress,
                  canRedeem),
              const SizedBox(height: 14),
              _statsGrid(w, coinValue, card, ink, muted, line),
              const SizedBox(height: 22),
              _tabs(card, ink, muted, line),
              const SizedBox(height: 12),
              if (_tab == _Tab.earnings) ...[
                ..._earnings(coinValue, card, ink, muted, line),
                _moreButton(_txNext, muted),
              ] else ...[
                ..._withdrawals(coinValue, card, ink, muted, line),
                _moreButton(_payoutNext, muted),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(int coins, double value, double coinValue, int minimum,
      double progress, bool canRedeem) {
    return Container(
      key: const Key('wallet_balance_card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0001B), Color(0xFFB00012)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB00012).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('అందుబాటులో ఉన్న బ్యాలెన్స్',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rupees(value),
                  key: const Key('wallet_available_rupees'),
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('$coins కాయిన్లు',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canRedeem
                ? 'మీరు ఇప్పుడు విత్‌డ్రా చేసుకోవచ్చు'
                : 'విత్‌డ్రా కోసం ఇంకా ${minimum - coins} కాయిన్లు కావాలి',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 4),
          // How coins turn into money — from the backend, not assumed.
          Text(
            '1 కాయిన్ = ${rupees(coinValue)} · కనీస విత్‌డ్రా $minimum కాయిన్లు (${rupees(minimum * coinValue)})',
            key: const Key('wallet_rate'),
            style: TextStyle(
                fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('wallet_withdraw'),
              // Disabled below the minimum (the line above says how many
              // more coins are needed).
              onPressed: canRedeem
                  ? () {
                      HapticFeedback.lightImpact();
                      _openPayout();
                    }
                  : null,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('విత్‌డ్రా చేయండి',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB00012),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.black38,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(RewardWallet? w, double coinValue, Color card, Color ink,
      Color muted, Color line) {
    Widget tile(
        String key, IconData icon, Color color, String label, int coins) {
      return Expanded(
        child: Container(
          key: Key('wallet_stat_$key'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: muted,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(rupees(coins * coinValue),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
              Text('$coins కాయిన్లు',
                  style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [
          tile('earned', Icons.trending_up_rounded, _green, 'మొత్తం సంపాదన',
              w?.lifetimeEarnedCoins ?? 0),
          const SizedBox(width: 10),
          tile(
              'withdrawn',
              Icons.check_circle_outline_rounded,
              const Color(0xFF3B82F6),
              'విత్‌డ్రా చేసినవి',
              w?.redeemedCoins ?? 0),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          tile('available', Icons.account_balance_wallet_outlined, _red,
              'అందుబాటులో', w?.availableCoins ?? 0),
          const SizedBox(width: 10),
          tile('locked', Icons.hourglass_top_rounded, const Color(0xFFD97706),
              'విత్‌డ్రా పెండింగ్', w?.lockedCoins ?? 0),
        ]),
      ],
    );
  }

  Widget _tabs(Color card, Color ink, Color muted, Color line) {
    Widget tab(_Tab t, String label, int count) {
      final on = _tab == t;
      return Expanded(
        child: InkWell(
          key: Key('wallet_tab_${t.name}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _tab = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: on ? _red : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('$label ($count)',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        tab(_Tab.earnings, 'సంపాదన చరిత్ర', _transactions.length),
        tab(_Tab.withdrawals, 'విత్‌డ్రాలు', _payouts.length),
      ]),
    );
  }

  List<Widget> _earnings(
      double coinValue, Color card, Color ink, Color muted, Color line) {
    if (_transactions.isEmpty) {
      return [
        _Empty(
          icon: Icons.emoji_events_outlined,
          text:
              'ఇంకా సంపాదన లేదు. మీ వార్త ఆమోదం పొందినప్పుడు కాయిన్లు ఇక్కడ కనిపిస్తాయి.',
          muted: muted,
        )
      ];
    }
    return [
      for (final t in _transactions)
        Container(
          key: Key('wallet_tx_${t.id}'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _txStyle(t).color.withValues(alpha: 0.12),
                child: Icon(_txStyle(t).icon, color: _txStyle(t).color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_txLabel(t),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: ink)),
                    if (t.title != null) ...[
                      const SizedBox(height: 2),
                      Text(t.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: ink)),
                    ],
                    if (t.note != null) ...[
                      const SizedBox(height: 2),
                      Text(t.note!,
                          style: TextStyle(fontSize: 12, color: muted)),
                    ],
                    const SizedBox(height: 4),
                    Text(date(t.createdAt),
                        style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_txStyle(t).sign}${t.absCoins} కాయిన్లు',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, color: _txStyle(t).color),
                  ),
                  const SizedBox(height: 2),
                  Text(rupees(t.amountFor(coinValue)),
                      style: TextStyle(fontSize: 12.5, color: muted)),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _withdrawals(
      double coinValue, Color card, Color ink, Color muted, Color line) {
    if (_payouts.isEmpty) {
      return [
        _Empty(
          icon: Icons.receipt_long_rounded,
          text: 'ఇంకా విత్‌డ్రా అభ్యర్థనలు లేవు.',
          muted: muted,
        )
      ];
    }
    return [
      for (final p in _payouts)
        Container(
          key: Key('wallet_payout_${p.id}'),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(rupees(p.amountFor(coinValue)),
                        key: Key('wallet_payout_amount_${p.id}'),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: ink)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          _statusColor(p.parsedStatus).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_statusLabel(p.parsedStatus),
                        style: TextStyle(
                            color: _statusColor(p.parsedStatus),
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${p.coinsRequested} కాయిన్లు',
                  style: TextStyle(fontSize: 13, color: muted)),
              const SizedBox(height: 8),
              _kv('పంపేది', '${p.payoutMethod} · ${p.destination}', ink, muted),
              _kv('అభ్యర్థన తేదీ', date(p.createdAt), ink, muted),
              if (p.approvedAt != null)
                _kv('ఆమోదించిన తేదీ', date(p.approvedAt!), ink, muted),
              if (p.paidAt != null)
                _kv('చెల్లించిన తేదీ', date(p.paidAt!), ink, muted),
              if (p.rejectedAt != null)
                _kv(
                    p.parsedStatus == RedeemStatus.cancelled
                        ? 'రద్దు తేదీ'
                        : 'తిరస్కరించిన తేదీ',
                    date(p.rejectedAt!),
                    ink,
                    muted),
              if (p.parsedStatus == RedeemStatus.requested ||
                  p.parsedStatus == RedeemStatus.processing)
                _kv(
                    'గమనిక',
                    '${p.coinsRequested} కాయిన్లు చెల్లింపు వరకు హోల్డ్‌లో ఉంటాయి',
                    ink,
                    muted),
              if (p.reference != null)
                _kv('రిఫరెన్స్', p.reference!, ink, muted),
              if (p.parsedStatus == RedeemStatus.rejected &&
                  p.adminNotes != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('కారణం: ${p.adminNotes}',
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFFEF4444))),
                )
              else if (p.adminNotes != null)
                _kv('గమనిక', p.adminNotes!, ink, muted),
            ],
          ),
        ),
    ];
  }

  Widget _kv(String k, String v, Color ink, Color muted) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k, style: TextStyle(fontSize: 12.5, color: muted)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontSize: 12.5, color: ink, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text, required this.muted});
  final IconData icon;
  final String text;
  final Color muted;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 44, color: muted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13.5, height: 1.5)),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry, required this.muted});
  final VoidCallback onRetry;
  final Color muted;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: muted),
            const SizedBox(height: 12),
            Text('వివరాలు లోడ్ కాలేదు',
                style: TextStyle(color: muted, fontSize: 14)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: onRetry, child: const Text('మళ్లీ ప్రయత్నించండి')),
          ],
        ),
      );
}
