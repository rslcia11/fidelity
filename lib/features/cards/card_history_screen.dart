import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/reward_transfer_service.dart';

class CardHistoryScreen extends StatefulWidget {
  final String loyaltyCardId;
  final String businessId;
  final String businessName;

  const CardHistoryScreen({
    super.key,
    required this.loyaltyCardId,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<CardHistoryScreen> createState() => _CardHistoryScreenState();
}

class _CardHistoryScreenState extends State<CardHistoryScreen> {
  final supabase = Supabase.instance.client;
  final _transferService = RewardTransferService(Supabase.instance.client);
  List<Map<String, dynamic>> _scans = [];
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      var scansQuery = supabase
          .from('scans')
          .select('*, businesses(name)')
          .eq('loyalty_card_id', widget.loyaltyCardId)
          .eq('status', 'approved');

      var rewardsQuery = supabase
          .from('rewards')
          .select('*, description, businesses(name, reward_description)')
          .eq('loyalty_card_id', widget.loyaltyCardId);

      if (_dateRange != null) {
        final start = _dateRange!.start.toIso8601String();
        final end = _dateRange!.end
            .add(const Duration(days: 1))
            .toIso8601String();
        scansQuery = scansQuery.gte('scanned_at', start).lt('scanned_at', end);
        rewardsQuery = rewardsQuery
            .gte('earned_at', start)
            .lt('earned_at', end);
      }

      final responses = await Future.wait([
        scansQuery.order('scanned_at', ascending: false),
        rewardsQuery.order('earned_at', ascending: false),
      ]);

      if (mounted) {
        setState(() {
          _scans = List<Map<String, dynamic>>.from(responses[0]);
          _rewards = List<Map<String, dynamic>>.from(responses[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange:
          _dateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() => _dateRange = pickedRange);
      _loadHistory();
    }
  }

  bool _canTransfer(Map<String, dynamic> reward) {
    final status = reward['status'] ?? 'pending';
    return status == 'pending';
  }

  Future<void> _showTransferDialog(Map<String, dynamic> reward) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMessage;
    bool showInviteButton = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TRANSFERIR PREMIO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa el email de tu amigo para transferirle este premio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: 'Email del destinatario',
                      hintText: 'amigo@ejemplo.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa un email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Ingresa un email válido';
                      }
                      return null;
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.accentPink,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: AppTheme.accentPink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (showInviteButton) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _shareAppLink,
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('INVITAR A UN AMIGO'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentPink,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'CANCELAR',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setModalState(() {
                                      isLoading = true;
                                      errorMessage = null;
                                      showInviteButton = false;
                                    });

                                    final email = emailController.text.trim();

                                    // 1. Buscar usuario por email
                                    final user = await _transferService
                                        .findUserByEmail(email);

                                    // 2. Si no existe, mostrar mensaje y botón de invitar
                                    if (user == null) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorMessage =
                                            'Esa cuenta no existe. Dile a tu fideliamigo que descargue la app y que cree una cuenta para que le puedas transferir el premio.';
                                        showInviteButton = true;
                                      });
                                      return;
                                    }

                                    // 3. Si existe pero es negocio, mostrar error específico
                                    if (user['role'] != 'client') {
                                      setModalState(() {
                                        isLoading = false;
                                        errorMessage =
                                            'No se puede transferir un premio a una cuenta de negocio.';
                                      });
                                      return;
                                    }

                                    // 4. Ejecutar la transferencia
                                    try {
                                      await _transferService.transferReward(
                                        reward['id'] as String,
                                        email,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        _loadHistory();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '¡Premio transferido exitosamente!',
                                            ),
                                            backgroundColor:
                                                AppTheme.accentGreen,
                                          ),
                                        );
                                      }
                                    } on TransferException catch (e) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorMessage = e.message;
                                      });
                                    } catch (e) {
                                      setModalState(() {
                                        isLoading = false;
                                        errorMessage =
                                            'Error al transferir. Intenta de nuevo.';
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'TRANSFERIR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareAppLink() async {
    const message =
        '¡Descarga Fidelity! Tu amigo te transferió un premio. Descarga aquí: https://fidelity.app/download';
    await Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 100,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            widget.businessName.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _dateRange == null
                    ? Icons.calendar_today_rounded
                    : Icons.calendar_today_rounded,
                color: _dateRange == null
                    ? Colors.black26
                    : AppTheme.accentPurple,
              ),
              onPressed: _selectDateRange,
            ),
            if (_dateRange != null)
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.accentPink,
                ),
                onPressed: () {
                  setState(() => _dateRange = null);
                  _loadHistory();
                },
              ),
          ],
          bottom: TabBar(
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            indicatorSize: TabBarIndicatorSize.label,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(width: 4, color: Colors.black),
              insets: EdgeInsets.symmetric(horizontal: 16),
            ),
            tabs: const [
              Tab(text: 'ESCANEOS'),
              Tab(text: 'PREMIOS'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildHistoryList(_scans, isScan: true),
                  _buildHistoryList(_rewards, isScan: false),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryList(
    List<Map<String, dynamic>> items, {
    required bool isScan,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: (isScan ? AppTheme.accentGreen : AppTheme.accentPink)
                    .withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isScan ? Icons.history_rounded : Icons.card_giftcard_rounded,
                size: 64,
                color: isScan ? AppTheme.accentGreen : AppTheme.accentPink,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isScan ? 'SIN ACTIVIDAD' : 'SIN PREMIOS',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const Text(
              'Pronto verás tus movimientos aquí.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black26,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final date = isScan ? item['scanned_at'] : item['earned_at'];
        final String actionTitle = isScan
            ? '+1 PUNTO FIDELITY'
            : 'PREMIO GANADO';
        final accent = isScan ? AppTheme.accentGreen : AppTheme.accentPink;

        // Status logic for rewards
        final String status = !isScan
            ? (item['status'] ?? 'pending')
            : 'approved';
        Color statusColor = AppTheme.accentYellow;
        String statusLabel = 'PENDIENTE';

        if (status == 'approved') {
          statusColor = AppTheme.accentGreen;
          statusLabel = 'ENTREGADO';
        } else if (status == 'rejected') {
          statusColor = AppTheme.accentPink;
          statusLabel = 'RECHAZADO';
        }

        return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: !isScan && status == 'pending'
                      ? statusColor.withOpacity(0.3)
                      : Colors.black.withOpacity(0.04),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isScan ? accent : statusColor).withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isScan
                              ? Icons.add_rounded
                              : Icons.card_giftcard_rounded,
                          color: isScan ? accent : statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isScan
                                  ? actionTitle
                                  : (item['businesses']?['reward_description']
                                            ?.toString()
                                            .toUpperCase() ??
                                        item['reward_description']
                                            ?.toString()
                                            .toUpperCase() ??
                                        'PREMIO'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (!isScan && item['description'] != null)
                              Text(
                                item['description'].toString(),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              EcuadorDateUtils.formatEcuadorTime(
                                date,
                              ).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black26,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isScan)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (_canTransfer(item)) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => _showTransferDialog(item),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPurple.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppTheme.accentPurple.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.swap_horiz_rounded,
                                        color: AppTheme.accentPurple,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'TRANSFERIR',
                                        style: TextStyle(
                                          color: AppTheme.accentPurple,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 8,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '-${item['points_used']} PTS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isScan &&
                      item['businesses'] != null &&
                      item['businesses']['name'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 12,
                          color: Colors.black26,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item['businesses']['name'].toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            )
            .animate(delay: AppTheme.animDelayStaggered(index))
            .fadeIn(duration: AppTheme.animDurationStandard)
            .slideY(
              begin: AppTheme.animSlideYBegin,
              curve: AppTheme.animCurveStandard,
            );
      },
    );
  }
}
