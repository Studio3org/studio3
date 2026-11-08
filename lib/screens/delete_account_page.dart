import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/piece_summary.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/auth_session.dart';
import '../services/device_service.dart';
import '../services/order_service.dart';
import '../services/piece_service.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/orders/order_list_row.dart';
import '../widgets/settings_tile.dart';
import '../widgets/studio/studio.dart';
import 'order_detail_page.dart';
import 'profile/widgets/profile_masonry_grid.dart' show openProfilePiece;

/// Something that keeps the account from being deleted (a row on `SettingsDelete`): what it is,
/// a line under it, and the piece's title on the right. Opens the piece or the order.
class DeletionBlocker {
  const DeletionBlocker({
    required this.label,
    this.subtitle,
    this.value,
    this.piece,
    this.order,
    this.asSeller = false,
  });

  final String label;
  final String? subtitle;
  final String? value;

  /// A listed piece: opens its page.
  final PieceSummary? piece;

  /// A sale or purchase: opens the order.
  final Order? order;
  final bool asSeller;
}

const _inProgress = {'pending_payment', 'paid', 'shipped', 'awaiting_confirmation', 'disputed'};
const _payoutWaiting = {'pending', 'ready_to_release', 'transfer_failed'};

/// What is still in progress, in the board's order: a running auction, anything else listed,
/// a sale or purchase on its way (or waiting for payment, or with an issue open), a payout not
/// paid yet. [pieces] are the pieces on the orders, by id, for their titles.
///
/// The server refuses to delete while anything is listed or a sale or purchase is in progress
/// (the same list); payouts are the board's addition. Events they host with tickets wait on
/// ticket sales (BACKEND_CHANGES B22, on hold), and one server check in place of this
/// (`GET /api/user/me/deletion-check`) is B34.
List<DeletionBlocker> deletionBlockers({
  required List<PieceSummary> listed,
  required List<Order> sales,
  required List<Order> purchases,
  required Map<String, PieceSummary> pieces,
}) {
  String? titleOf(Order order) {
    final piece = orderPiece(order, pieces);
    return piece == null ? null : orderPieceTitle(piece);
  }

  String orderLabel(Order order, {required bool sale}) => switch (order.status) {
    'pending_payment' => sale ? 'Sale waiting for payment' : 'Purchase waiting for payment',
    'disputed' => 'Issue open',
    _ => 'Piece shipping',
  };

  return [
    for (final piece in listed.where((p) => p.isAuction))
      DeletionBlocker(
        label: 'Auction running',
        subtitle: piece.auctionEndsAt == null ? null : 'Ends ${orderRowDate(piece.auctionEndsAt)}',
        value: orderPieceTitle(piece),
        piece: piece,
      ),
    for (final piece in listed.where((p) => !p.isAuction))
      DeletionBlocker(label: 'Listed for sale', value: orderPieceTitle(piece), piece: piece),
    for (final order in sales.where((o) => _inProgress.contains(o.status)))
      DeletionBlocker(
        label: orderLabel(order, sale: true),
        subtitle: saleStep(order).text,
        value: titleOf(order),
        order: order,
        asSeller: true,
      ),
    for (final order in purchases.where((o) => _inProgress.contains(o.status)))
      DeletionBlocker(
        label: orderLabel(order, sale: false),
        subtitle: purchaseStep(order),
        value: titleOf(order),
        order: order,
      ),
    for (final order in sales.where(
      (o) => o.status == 'completed' && _payoutWaiting.contains(o.payoutStatus),
    ))
      DeletionBlocker(label: 'Payout pending', value: titleOf(order), order: order, asSeller: true),
  ];
}

/// Delete account (`SettingsDelete`, Flow 12; Apple requires it). While anything is in
/// progress: "Finish these first", "Your account can be deleted once nothing is in progress.",
/// a row for each ([deletionBlockers]), what deleting removes, and Delete account grey at the
/// bottom. Once nothing is: Delete account in Ink, which asks them to type DELETE (and, as the
/// server still requires, their password).
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, this.debugBlockers});

  /// For tests: what is in progress, instead of loading it.
  @visibleForTesting
  final List<DeletionBlocker>? debugBlockers;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  List<DeletionBlocker> _blockers = const [];
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final given = widget.debugBlockers;
    if (given != null) {
      _blockers = given;
      _loading = false;
      return;
    }
    _load();
  }

  /// Reads the listings, sales and purchases (first pages). One that fails counts as empty:
  /// the server still refuses the delete and says why.
  Future<void> _load() async {
    if (widget.debugBlockers != null) return;
    final username = AuthSession.instance.user?.username ?? '';
    Future<T> orEmpty<T>(Future<T> Function() read, T empty) async {
      try {
        return await read();
      } catch (_) {
        return empty;
      }
    }

    final results = await Future.wait<Object>([
      orEmpty<List<PieceSummary>>(
        () => username.isEmpty ? Future.value(const []) : PieceService.instance.getUserPiecesForSale(username),
        const [],
      ),
      orEmpty<List<Order>>(() async => (await OrderService.instance.getMySales()).items, const []),
      orEmpty<List<Order>>(() async => (await OrderService.instance.getMyOrders()).items, const []),
    ]);
    final listed = (results[0] as List<PieceSummary>).where((p) => p.status != 'sold').toList();
    final sales = results[1] as List<Order>;
    final purchases = results[2] as List<Order>;
    final pieces = <String, PieceSummary>{};
    await loadOrderPieces([...sales, ...purchases], pieces);
    if (!mounted) return;
    setState(() {
      _blockers = deletionBlockers(listed: listed, sales: sales, purchases: purchases, pieces: pieces);
      _loading = false;
    });
  }

  Future<void> _open(DeletionBlocker blocker) async {
    final piece = blocker.piece;
    final order = blocker.order;
    if (piece != null) {
      openProfilePiece(context, piece);
      return;
    }
    if (order == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => OrderDetailPage(orderId: order.id, isSeller: blocker.asSeller)),
    );
    if (mounted) _load();
  }

  Future<void> _delete() async {
    final password = await showStudioSheet<String>(context: context, builder: (_) => const _ConfirmDeleteSheet());
    if (password == null || password.isEmpty || !mounted) return;
    setState(() => _deleting = true);
    try {
      await DeviceService.instance.unregisterCurrentDevice();
      await AuthService.instance.deleteAccount(password);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on ApiException catch (e) {
      // A wrong password, or something in progress this page didn't see: the server says which.
      if (!mounted) return;
      setState(() => _deleting = false);
      showStudioToast(context, e.message, icon: null);
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showStudioToast(context, 'Could not delete your account. Please try again.', icon: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    final blocked = _blockers.isNotEmpty;
    return Scaffold(
      backgroundColor: c.background,
      appBar: StudioTopBar(context: context, title: 'Delete account'),
      body: _loading
          ? const SettingsListSkeleton()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    children: [
                      Text(
                        blocked ? 'Finish these first' : 'Delete your account?',
                        style: StudioType.sans(
                          24,
                          weight: StudioType.medium,
                          letterSpacing: -0.4,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        blocked
                            ? 'Your account can be deleted once nothing is in progress.'
                            : "Nothing is in progress, so your account can be deleted. This can't be undone.",
                        style: StudioType.sans(15, height: 1.5, color: c.textSecondary),
                      ),
                      if (blocked) ...[
                        const SizedBox(height: 14),
                        for (final blocker in _blockers)
                          SettingsRow(
                            label: blocker.label,
                            subtitle: blocker.subtitle,
                            value: blocker.value,
                            onTap: () => _open(blocker),
                          ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Removes your profile, pieces, Scenes and messages. Sale records are kept as '
                        'the law requires.',
                        style: StudioType.sans(13, height: 1.5, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: StudioButton(
                    label: 'Delete account',
                    loading: _deleting,
                    onPressed: blocked || _deleting ? null : _delete,
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Delete your account?", type DELETE, then the password (the server asks for it), Delete
/// account (on once both are in) and Cancel. Pops the password, or null.
class _ConfirmDeleteSheet extends StatefulWidget {
  const _ConfirmDeleteSheet();

  @override
  State<_ConfirmDeleteSheet> createState() => _ConfirmDeleteSheetState();
}

class _ConfirmDeleteSheetState extends State<_ConfirmDeleteSheet> {
  final _word = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready => _word.text.trim().toUpperCase() == 'DELETE' && _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.studio;
    return StudioSheet(
      horizontalPadding: StudioSpace.marginForm,
      gap: 14,
      children: [
        Text('Delete your account?', style: StudioType.title22(color: c.textPrimary)),
        Text('Type DELETE to confirm.', style: StudioType.body14(color: c.textSecondary)),
        StudioUnderlineField(
          label: 'Type DELETE',
          controller: _word,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        StudioUnderlineField(
          label: 'Your password',
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        StudioButton(
          label: 'Delete account',
          onPressed: _ready ? () => Navigator.pop(context, _password.text) : null,
        ),
        StudioButton(label: 'Cancel', variant: StudioButtonVariant.text, onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

/// Settings' Delete account row: the page above.
Future<void> openDeleteAccount(BuildContext context) =>
    Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const DeleteAccountPage()));
