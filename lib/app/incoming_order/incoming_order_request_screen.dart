import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/services/incoming_order_handler.dart';
import 'package:door_delights_driver/theme/app_them_data.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class IncomingOrderRequestScreen extends StatefulWidget {
  final String orderId;
  final String type;
  final String title;
  final String body;
  final String? autoAction;
  final Map<String, dynamic>? preview;

  const IncomingOrderRequestScreen({
    super.key,
    required this.orderId,
    required this.type,
    this.title = '',
    this.body = '',
    this.autoAction,
    this.preview,
  });

  @override
  State<IncomingOrderRequestScreen> createState() =>
      _IncomingOrderRequestScreenState();
}

class _IncomingOrderRequestScreenState
    extends State<IncomingOrderRequestScreen> {
  IncomingOrderDisplayData? _data;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.autoAction == IncomingOrderHandler.acceptAction ||
        widget.autoAction == IncomingOrderHandler.declineAction) {
      await IncomingOrderHandler.processAction(
        action: widget.autoAction!,
        orderId: widget.orderId,
        type: widget.type,
      );
      return;
    }

    // Show FCM preview immediately, then enrich from Firestore.
    final previewData =
        IncomingOrderHandler.previewFromPayload(widget.preview);
    if (previewData != null && mounted) {
      setState(() {
        _data = previewData;
        _loading = false;
      });
    }

    final data = await IncomingOrderHandler.loadDisplayData(
      orderId: widget.orderId,
      type: widget.type,
      preview: widget.preview,
    );
    if (!mounted) return;
    setState(() {
      _data = data ?? previewData;
      _loading = false;
    });
  }

  Future<void> _onAccept() async {
    if (_busy) return;
    setState(() => _busy = true);
    await IncomingOrderHandler.processAction(
      action: IncomingOrderHandler.acceptAction,
      orderId: widget.orderId,
      type: widget.type,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _onDecline() async {
    if (_busy) return;
    setState(() => _busy = true);
    await IncomingOrderHandler.processAction(
      action: IncomingOrderHandler.declineAction,
      orderId: widget.orderId,
      type: widget.type,
    );
    if (mounted) setState(() => _busy = false);
  }

  String _amountLabel() {
    final raw = _data?.amount ?? '0';
    try {
      return Constant.amountShow(amount: raw);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Half-screen card over dimmed background (PickMe-style intent).
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppThemeData.driverApp300,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppThemeData.driverApp300.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
                  : Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _amountLabel(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if ((_data?.vehicleLabel ?? '').isNotEmpty)
                                    _chip(_data!.vehicleLabel),
                                  if ((_data?.paymentMethod ?? '').isNotEmpty)
                                    _chip(_data!.paymentMethod),
                                  if ((_data?.distance ?? '').isNotEmpty)
                                    _chip('${_data!.distance} km'),
                                ],
                              ),
                              const SizedBox(height: 18),
                              if ((_data?.pickup ?? '').isNotEmpty) ...[
                                _locationRow(
                                  color: AppThemeData.driverApp300,
                                  title: _data!.pickup,
                                  subtitle: (_data?.duration ?? '').isNotEmpty
                                      ? _data!.duration
                                      : widget.body,
                                ),
                                const SizedBox(height: 14),
                              ],
                              if ((_data?.destination ?? '').isNotEmpty)
                                _locationRow(
                                  color: const Color(0xFFE53935),
                                  title: _data!.destination,
                                  subtitle: '',
                                ),
                              if ((_data?.pickup ?? '').isEmpty &&
                                  (_data?.destination ?? '').isEmpty &&
                                  widget.body.isNotEmpty)
                                Text(
                                  widget.body,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                  ),
                                ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _busy ? null : _onAccept,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Accept Now'.tr(),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: const Color(0xFF3A3A3C),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _busy ? null : _onDecline,
                              child: const SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(Icons.close,
                                    color: Colors.white70, size: 22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _locationRow({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
