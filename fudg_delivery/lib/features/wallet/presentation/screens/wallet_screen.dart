import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _loading = true;
  String? _error;

  /// Everything below starts empty and is filled from
  /// `GET /food/delivery/wallet`. It used to be seeded with ₹1,248.00 /
  /// ₹28,560.00 / ₹27,312.00 / ₹1,250.00 and five invented transactions,
  /// which is what the screen showed while loading and kept showing forever
  /// if the request failed.
  double _pocketBalance = 0;
  double _totalEarned = 0;
  double _totalWithdrawn = 0;
  double _totalBonus = 0;
  double _cashInHand = 0;
  double _minWithdrawal = 0;

  /// Presentation for one backend transaction row. The API sends
  /// `{type, amount, status, date, description, orderId}`; type decides the
  /// direction and the icon, status decides the pill colour.
  static bool _isCredit(Map<String, dynamic> tx) =>
      (tx['type']?.toString() ?? '') != 'withdrawal';

  static String _txTitle(Map<String, dynamic> tx) {
    switch (tx['type']?.toString()) {
      case 'withdrawal':
        return 'Withdrawal';
      case 'deposit':
        return 'Cash Deposit';
      case 'bonus':
        return 'Bonus';
      default:
        final orderId = tx['orderId']?.toString() ?? '';
        return orderId.isEmpty ? 'Delivery Earning' : 'Order #$orderId';
    }
  }

  static IconData _txIcon(Map<String, dynamic> tx) => _isCredit(tx)
      ? Icons.north_east_rounded
      : Icons.south_west_rounded;

  static String _txDate(Map<String, dynamic> tx) {
    final at = DateTime.tryParse(
      (tx['date'] ?? tx['createdAt'] ?? '').toString(),
    )?.toLocal();
    if (at == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '${at.day.toString().padLeft(2, '0')} ${months[at.month - 1]} '
        '${at.year}, ${hour12.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')} '
        '${at.hour < 12 ? 'AM' : 'PM'}';
  }

  static ({Color bg, Color fg}) _txStatusStyle(Map<String, dynamic> tx) {
    switch ((tx['status'] ?? '').toString().toLowerCase()) {
      case 'pending':
      case 'processing':
        return (bg: const Color(0xFFFFF3E0), fg: const Color(0xFFF57C00));
      case 'rejected':
      case 'failed':
        return (bg: const Color(0xFFFBE9E7), fg: const Color(0xFFD32F2F));
      default:
        return (bg: AppColors.primaryLight, fg: AppColors.primaryDark);
    }
  }

  /// `wallet.transactions` — payment / withdrawal / deposit rows.
  List<Map<String, dynamic>> _transactions = const [];

  final TextEditingController _withdrawController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  @override
  void dispose() {
    _withdrawController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(walletRepositoryProvider).getWallet();
    if (!mounted) return;
    result.when(
      success: (data) {
        // `getDeliveryPartnerWalletEnhanced` returns pocketBalance /
        // totalEarned / totalWithdrawn / totalBonus / cashInHand. There is no
        // `balance` key — the old code read one, always got null, and left the
        // hardcoded ₹1,248.00 on screen.
        final w = data['wallet'] as Map<String, dynamic>? ?? data;
        double n(String key) => (w[key] as num?)?.toDouble() ?? 0;
        setState(() {
          _pocketBalance = n('pocketBalance');
          _totalEarned = n('totalEarned');
          _totalWithdrawn = n('totalWithdrawn');
          _totalBonus = n('totalBonus');
          _cashInHand = n('cashInHand');
          _minWithdrawal = n('deliveryWithdrawalLimit');
          _transactions = (w['transactions'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _loading = false;
        });
      },
      failure: (error) => setState(() {
        _error = error.message;
        _loading = false;
      }),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showWithdrawDialog() {
    // Left empty. It used to be pre-filled with '1248' — the hardcoded
    // balance — so a rider tapping through withdrew a number the screen made
    // up rather than one they chose.
    _withdrawController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, MediaQuery.of(ctx).viewInsets.bottom + 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp)),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Available: ₹${_pocketBalance.toStringAsFixed(2)}'
              '${_minWithdrawal > 0 ? ' · Min: ₹${_minWithdrawal.toStringAsFixed(0)}' : ''}',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _withdrawController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.primaryDark),
                labelText: 'Withdrawal Amount',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(_withdrawController.text);
                  if (amt == null || amt <= 0) {
                    _showSnack('Please enter a valid amount');
                    return;
                  }
                  if (amt > _pocketBalance) {
                    _showSnack('Amount exceeds your available balance');
                    return;
                  }
                  if (_minWithdrawal > 0 && amt < _minWithdrawal) {
                    _showSnack(
                        'Minimum withdrawal is ₹${_minWithdrawal.toStringAsFixed(0)}');
                    return;
                  }
                  Navigator.of(ctx).pop();
                  final res = await ref.read(walletRepositoryProvider).withdraw(amt);
                  if (!mounted) return;
                  res.when(
                    // Re-read the wallet rather than fabricating a local row
                    // and decrementing the balance by hand — the backend
                    // decides what the new balance and ledger look like.
                    success: (_) {
                      _showSnack('Withdrawal request submitted');
                      _loadWalletData();
                    },
                    failure: (e) => _showSnack(e.message),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text('Confirm Withdrawal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/main');
                      }
                    },
                    child: Container(
                      width: 38.r,
                      height: 38.r,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 20.sp),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Wallet',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22.sp,
                            color: Colors.black87,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Manage your earnings and transactions',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Help Action Button
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      context.push('/help');
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36.r,
                          height: 36.r,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Icon(Icons.help_outline_rounded, color: Colors.black87, size: 20.sp),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Help',
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _loadWalletData,
                          child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 40.h),
                child: Column(
                  children: [
                    // Main Hero Wallet Card (Teal Gradient Card)
                    _buildHeroWalletCard(),

                    // Cash the rider is holding and owes back. Real figure
                    // from the wallet endpoint; hidden when there is none.
                    if (_cashInHand > 0) ...[
                      SizedBox(height: 14.h),
                      _buildCashInHandCard(),
                    ],

                    SizedBox(height: 14.h),

                    // Quick Actions 4-Grid Card
                    _buildQuickActionsCard(),

                    SizedBox(height: 14.h),

                    // Recent Transactions Card
                    _buildRecentTransactionsCard(),

                    SizedBox(height: 14.h),

                    // This Month Overview Grid Card
                    _buildThisMonthOverviewCard(),

                    SizedBox(height: 16.h),
                  ],
                ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Teal Hero Wallet Card Widget
  Widget _buildHeroWalletCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D40).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Balance Info & 3D Wallet Graphic
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Balance',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '₹${_pocketBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 28.sp,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          'Available to withdraw',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        SizedBox(width: 4.w),
                        GestureDetector(
                          onTap: () => _showSnack('Available for instant bank withdrawal'),
                          child: Icon(Icons.info_outline_rounded, color: Colors.white70, size: 15.sp),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // Withdraw Now Button
                    ElevatedButton(
                      onPressed: () {
                        HapticService.light();
                        _showWithdrawDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF004D40),
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Withdraw Now',
                            style: TextStyle(
                              color: const Color(0xFF004D40),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5.sp,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.chevron_right_rounded, color: const Color(0xFF004D40), size: 18.sp),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3D Mint Wallet Graphic Illustration Widget
              SizedBox(
                width: 95.r,
                height: 85.r,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 4.h,
                      child: Container(
                        width: 24.r,
                        height: 24.r,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB300),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 14.sp),
                      ),
                    ),
                    Positioned(
                      left: 14.w,
                      bottom: 0,
                      child: Container(
                        width: 20.r,
                        height: 20.r,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFC107),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Container(
                      width: 70.r,
                      height: 60.r,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5D67),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 6.h,
                            left: 10.w,
                            right: 10.w,
                            child: Container(
                              height: 20.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6A2A8),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Icon(Icons.attach_money_rounded, color: Colors.teal[800], size: 14.sp),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 14.r,
                              height: 14.r,
                              margin: EdgeInsets.only(right: 10.w),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFD54F),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          SizedBox(height: 14.h),

          // Bottom Two Cards Row (Total Earnings & Total Withdrawn)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.light();
                    context.push('/earnings');
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Earnings',
                              style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.75)),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '₹${_totalEarned.toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16.sp),
                              ],
                            ),
                            Text(
                              'All Time',
                              style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.65)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(width: 1.w, height: 40.h, color: Colors.white.withValues(alpha: 0.15)),
              SizedBox(width: 12.w),

              Expanded(
                child: GestureDetector(
                  onTap: () => _showSnack(
                      'Total payouts: ₹${_totalWithdrawn.toStringAsFixed(2)}'),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.outbox_rounded, color: Colors.white, size: 20.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Withdrawn',
                              style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.75)),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '₹${_totalWithdrawn.toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.sp, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16.sp),
                              ],
                            ),
                            Text(
                              'All Time',
                              style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.65)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Quick Actions Card Widget (4 Grid Items)
  Widget _buildQuickActionsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionItem(
            icon: Icons.account_balance_rounded,
            title: 'Withdraw',
            subtitle: 'To Bank Account',
            onTap: _showWithdrawDialog,
          ),
          _buildQuickActionItem(
            icon: Icons.access_time_rounded,
            title: 'Transaction\nHistory',
            subtitle: 'View all',
            onTap: () => _showSnack('Showing full transaction history'),
          ),
          _buildQuickActionItem(
            icon: Icons.percent_rounded,
            title: 'Earnings\nBreakdown',
            subtitle: 'Details',
            onTap: () => context.push('/earnings'),
          ),
          _buildQuickActionItem(
            icon: Icons.card_giftcard_rounded,
            title: 'Incentives',
            subtitle: 'View all',
            onTap: () => context.push('/refer-earn'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          onTap();
        },
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 22.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5.sp, color: Colors.black87, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // 3. Recent Transactions Card Widget
  Widget _buildRecentTransactionsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
              ),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  _showSnack('Showing all transactions');
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12.sp),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 16.sp),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          if (_transactions.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Text(
                'No transactions yet',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            )
          else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (_, _) => Divider(height: 18.h, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              final isCredit = _isCredit(tx);
              final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
              // The tip inside this payment, as stored by the server. Read,
              // never derived as amount - deliveryAmount; absent on older
              // servers, which is simply no tip.
              final tip = (tx['tipAmount'] as num?)?.toDouble() ?? 0;
              final statusStyle = _txStatusStyle(tx);

              return Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_txIcon(tx), color: AppColors.primaryDark, size: 18.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _txTitle(tx),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5.sp, color: Colors.black87),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          [
                            if ((tx['description'] ?? '').toString().isNotEmpty)
                              tx['description'].toString(),
                            _txDate(tx),
                          ].where((e) => e.isNotEmpty).join(' • '),
                          style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isCredit ? '+' : '-'} ₹${amount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.sp,
                          color: isCredit ? AppColors.primaryDark : Colors.black87,
                        ),
                      ),
                      // A customer chose to give this; worth saying so on the
                      // order it came from. Only when there is one.
                      if (tip > 0) ...[
                        SizedBox(height: 2.h),
                        Text(
                          'incl. ₹${tip.toStringAsFixed(tip % 1 == 0 ? 0 : 2)} tip',
                          style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: Colors.green[700]),
                        ),
                      ],
                      // Only shown when the server actually stated one. It
                      // used to default to "Completed", so a transaction whose
                      // status was missing — pending, failed or simply not
                      // projected — was labelled settled money.
                      if ((tx['status'] ?? '').toString().isNotEmpty) ...[
                        SizedBox(height: 3.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: statusStyle.bg,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            tx['status'].toString(),
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              color: statusStyle.fg,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 44.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              // A server error can run to hundreds of lines; unbounded it
              // pushes the retry button off the screen.
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
                onPressed: _loadWalletData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildCashInHandCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined,
              color: const Color(0xFFF57C00), size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash in hand',
                  style: TextStyle(
                      fontSize: 11.5.sp, color: Colors.grey[700]),
                ),
                SizedBox(height: 2.h),
                Text(
                  '₹${_cashInHand.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18.sp,
                      color: const Color(0xFFE65100)),
                ),
              ],
            ),
          ),
          Text(
            'COD collected,\nnot yet deposited',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // 4. "This Month Overview" Card Widget
  Widget _buildThisMonthOverviewCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Wallet Overview',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5.sp, color: AppColors.primaryDark),
              ),
              Row(
                children: [
                  Text(
                    'All time',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.calendar_today_rounded, color: AppColors.primaryDark, size: 14.sp),
                ],
              ),
            ],
          ),
          SizedBox(height: 14.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverviewColumn(
                icon: Icons.account_balance_wallet_outlined,
                amount: '₹${_totalEarned.toStringAsFixed(2)}',
                label: 'Total Earnings',
              ),
              Container(width: 1.w, height: 35.h, color: Colors.grey[200]),
              _buildOverviewColumn(
                icon: Icons.percent_rounded,
                amount: '₹${_totalBonus.toStringAsFixed(2)}',
                label: 'Total Incentives',
              ),
              Container(width: 1.w, height: 35.h, color: Colors.grey[200]),
              _buildOverviewColumn(
                icon: Icons.account_balance_rounded,
                amount: '₹${_totalWithdrawn.toStringAsFixed(2)}',
                label: 'Total Withdrawn',
              ),
              Container(width: 1.w, height: 35.h, color: Colors.grey[200]),
              _buildOverviewColumn(
                icon: Icons.currency_rupee_rounded,
                amount: '₹${_pocketBalance.toStringAsFixed(2)}',
                label: 'Current Balance',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewColumn({
    required IconData icon,
    required String amount,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 18.sp),
          SizedBox(height: 4.h),
          Text(
            amount,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5.sp, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9.5.sp, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
