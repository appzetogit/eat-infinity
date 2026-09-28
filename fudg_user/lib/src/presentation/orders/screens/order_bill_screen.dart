import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/error/failures.dart';
import '../../../di/order_providers.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';

/// The bill for a placed order, as the server renders it.
///
/// The page sits behind the customer's token, so it is fetched through the API
/// client and handed to the WebView as markup -- pointing the WebView at the URL
/// would send no Authorization header and show a 401 page. The markup is
/// self-contained (inline styles, no scripts or remote assets), so it renders
/// with JavaScript off and nothing further to load.
///
/// Every figure on it is the server's. Nothing here adds anything up.
class OrderBillScreen extends ConsumerStatefulWidget {
  final String orderId;

  /// The number the customer knows the order by, for the share sheet.
  final String orderNumber;

  const OrderBillScreen({super.key, required this.orderId, this.orderNumber = ''});

  @override
  ConsumerState<OrderBillScreen> createState() => _OrderBillScreenState();
}

class _OrderBillScreenState extends ConsumerState<OrderBillScreen> {
  WebViewController? _controller;
  String? _html;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final html = await ref.read(orderRemoteDataSourceProvider).getInvoiceHtml(widget.orderId);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setBackgroundColor(Colors.white)
        ..loadHtmlString(html);
      if (!mounted) return;
      setState(() {
        _html = html;
        _controller = controller;
        _loading = false;
      });
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = f.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load the bill. Check your connection and try again.";
        _loading = false;
      });
    }
  }

  String get _label => widget.orderNumber.isNotEmpty ? widget.orderNumber : widget.orderId;

  Future<void> _share() async {
    final html = _html;
    if (html == null) return;
    try {
      // Shared as an .html file: it opens in any browser, which can print it
      // or save it as a PDF, without the app shipping a PDF renderer.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(utf8.encode(html), mimeType: 'text/html')],
          fileNameOverrides: ['Eatinfinity-bill-$_label.html'],
          subject: 'Bill for order $_label',
        ),
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, "Couldn't open the share sheet.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        title: Text('Bill · $_label'),
        actions: [
          if (_html != null)
            IconButton(
              tooltip: 'Share bill',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: _share,
            ),
        ],
      ),
      body: SafeArea(child: _body(isDark)),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final controller = _controller;
    if (_error != null || controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                _error ?? "We couldn't load the bill.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    // The bill is designed on white, as paper; it is not re-themed for dark mode.
    return ColoredBox(color: Colors.white, child: WebViewWidget(controller: controller));
  }
}
