import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/wallet_state.dart';
import '../viewmodels/wallet_viewmodel.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController(text: '500');
  final ScrollController _scrollController = ScrollController();
  int _selectedPresetIndex = 1; // ₹500 selected by default

  final GlobalKey _addMoneyKey = GlobalKey();
  final GlobalKey _transactionsKey = GlobalKey();

  @override
  void dispose() {
    _amountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleAddMoney(BuildContext context) async {
    Haptics.medium();
    FocusScope.of(context).unfocus();
    final raw = _amountController.text.replaceAll('₹', '').replaceAll(',', '').trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount to add.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final msg = await ref.read(walletViewModelProvider.notifier).addMoney(amount);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: msg.toLowerCase().contains('success') || msg.toLowerCase().contains('completed')
              ? AppColors.primary
              : Colors.orange,
        ),
      );
    }
  }

  void _showSecurityModal(BuildContext context) {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDCFCE7),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bank-Grade Payment Security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your Eatinfinity Wallet is powered by PCI-DSS compliant Razorpay gateway with end-to-end 256-bit SSL encryption. Funds stored in your wallet can be used instantly for one-click checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Back Button, Title, Transaction History Button
            _buildTopHeader(context),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 2. Hero Wallet Balance Banner Card
                    _buildHeroWalletCard(context),

                    const SizedBox(height: 20),

                    // 3. Quick Actions Grid
                    _buildQuickActionsSection(context),

                    const SizedBox(height: 24),

                    // 4. Add Money to Wallet Section
                    Container(key: _addMoneyKey, child: _buildAddMoneySection(context)),

                    const SizedBox(height: 24),

                    // 5. Recent Transactions Section
                    Container(key: _transactionsKey, child: _buildRecentTransactionsSection(context)),

                    const SizedBox(height: 20),

                    // 6. Security & Encryption Banner Box
                    _buildSecurityBannerBox(context),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Top Navigation Header Row
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Circular Back Button
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                ),
              ),
            ],
          ),

          const Text(
            'My Wallet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),

          // Transaction History Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              ref.read(walletViewModelProvider.notifier).setFilterTab(WalletFilterTab.all);
              _scrollToKey(_transactionsKey);
            },
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'History',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Hero Wallet Balance Banner Card
  Widget _buildHeroWalletCard(BuildContext context) {
    final s = ref.watch(walletViewModelProvider);
    final coins = s.wallet.referralEarnings.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Column: Total Wallet Balance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Wallet Balance',
                  style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                if (s.status == WalletStatus.loading)
                  const SizedBox(
                    height: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  )
                else
                  Text(
                    '₹${s.wallet.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.shield_outlined, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            '100% Secure Payments',
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vertical Dashed Separator Line
          Container(width: 1, height: 75, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(width: 14),

          // Right Column: Fudg Coins (referral earnings)
          GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.referral);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text('🪙 ', style: TextStyle(fontSize: 12)),
                    Text(
                      'Eatinfinity Coins',
                      style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      coins,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Text('👑 ', style: TextStyle(fontSize: 10)),
                      Text(
                        'View Benefits',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Quick Actions Section
  Widget _buildQuickActionsSection(BuildContext context) {
    final s = ref.watch(walletViewModelProvider);

    final actions = [
      {
        'icon': Icons.add_card_rounded,
        'label': 'Add Money',
        'onTap': () => _scrollToKey(_addMoneyKey),
      },
      {
        'icon': Icons.local_offer_outlined,
        'label': s.totalCashbackEarned > 0 ? '₹${s.totalCashbackEarned.toStringAsFixed(0)} Cashback' : 'Cashback',
        'onTap': () {
          ref.read(walletViewModelProvider.notifier).setFilterTab(WalletFilterTab.creditsAndCashback);
          _scrollToKey(_transactionsKey);
        },
      },
      {
        'icon': Icons.undo_rounded,
        'label': s.totalRefunded > 0 ? '₹${s.totalRefunded.toStringAsFixed(0)} Refunds' : 'Refunds',
        'onTap': () {
          ref.read(walletViewModelProvider.notifier).setFilterTab(WalletFilterTab.refunds);
          _scrollToKey(_transactionsKey);
        },
      },
      {
        'icon': Icons.group_add_outlined,
        'label': 'Refer & Earn',
        'onTap': () => context.push(RouteNames.referral),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((act) {
            final onTap = act['onTap'] as VoidCallback;
            return GestureDetector(
              onTap: () {
                Haptics.light();
                onTap();
              },
              child: Container(
                width: 78,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE6F7F5),
                      ),
                      child: Icon(act['icon'] as IconData, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      act['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 4. Add Money to Wallet Section
  Widget _buildAddMoneySection(BuildContext context) {
    final s = ref.watch(walletViewModelProvider);
    final presets = [
      {'amount': '₹200', 'value': 200},
      {'amount': '₹500', 'value': 500},
      {'amount': '₹1,000', 'value': 1000},
      {'amount': '₹2,000', 'value': 2000},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Money to Wallet',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),

        // Preset Amount Pills + Custom Amount Field Row
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...List.generate(presets.length, (index) {
                      final item = presets[index];
                      final isSelected = _selectedPresetIndex == index;
                      return GestureDetector(
                        onTap: () {
                          Haptics.light();
                          setState(() {
                            _selectedPresetIndex = index;
                            _amountController.text = item['value'].toString();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFE6F7F5) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            item['amount'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? AppColors.primary : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Custom Amount Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Row(
            children: [
              Text(
                '₹',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter amount to top up',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_selectedPresetIndex != -1) {
                      setState(() => _selectedPresetIndex = -1);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Primary Add Money Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: s.isToppingUp ? null : () => _handleAddMoney(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: s.isToppingUp
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Proceed to Add Money',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 14),

        // Cashback banner, driven by live admin cashback settings
        if (s.cashbackSettings?.isEnabled == true)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.cashbackSettings!.bannerText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 5. Recent Transactions Section with Filter Tabs
  String _formatTxDate(DateTime? at) {
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '${at.day} ${months[at.month - 1]} ${at.year}, '
        '$h:$m ${at.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _buildRecentTransactionsSection(BuildContext context) {
    final s = ref.watch(walletViewModelProvider);
    final filteredList = s.filteredTransactions;

    final transactions = filteredList.map((t) {
      final positive = t.isCredit;
      return <String, dynamic>{
        'title': t.description.isNotEmpty
            ? t.description
            : (positive ? 'Money added' : 'Payment'),
        'subtitle': t.source ?? t.status,
        'amount': '${positive ? '+' : '-'} ₹${t.amount.abs().toStringAsFixed(2)}',
        'isPositive': positive,
        'date': _formatTxDate(t.date),
        'icon': t.isRefund
            ? Icons.undo_rounded
            : (positive
                ? Icons.account_balance_wallet_rounded
                : Icons.shopping_bag_rounded),
        'iconBg': positive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        'iconColor': positive ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Transactions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),

        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', WalletFilterTab.all, s.selectedTab),
              const SizedBox(width: 8),
              _buildFilterChip('Credits & Cashback', WalletFilterTab.creditsAndCashback, s.selectedTab),
              const SizedBox(width: 8),
              _buildFilterChip('Refunds', WalletFilterTab.refunds, s.selectedTab),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: transactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 36, color: const Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          s.status == WalletStatus.loading
                              ? 'Loading transactions…'
                              : s.errorMessage ?? 'No transactions found.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: List.generate(transactions.length, (index) {
                    final tx = transactions[index];
                    final isLast = index == transactions.length - 1;
                    final isPositive = tx['isPositive'] as bool;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tx['iconBg'] as Color,
                                ),
                                child: Icon(tx['icon'] as IconData, color: tx['iconColor'] as Color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx['title'] as String,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      tx['subtitle'] as String,
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    tx['amount'] as String,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    tx['date'] as String,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isLast) const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 52),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, WalletFilterTab tab, WalletFilterTab currentTab) {
    final isSelected = tab == currentTab;
    return GestureDetector(
      onTap: () {
        Haptics.light();
        ref.read(walletViewModelProvider.notifier).setFilterTab(tab);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  /// 6. Security & Encryption Banner Box
  Widget _buildSecurityBannerBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDCFCE7),
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Your payments are safe and secure',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 1),
                Text(
                  'Eatinfinity Wallet is protected by 256-bit SSL encryption',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showSecurityModal(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: Text(
                'Learn More',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
