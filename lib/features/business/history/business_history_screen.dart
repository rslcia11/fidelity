import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/theme/app_theme.dart';

class BusinessHistoryScreen extends StatefulWidget {
  final String businessId;

  const BusinessHistoryScreen({super.key, required this.businessId});

  @override
  State<BusinessHistoryScreen> createState() => _BusinessHistoryScreenState();
}

class _BusinessHistoryScreenState extends State<BusinessHistoryScreen> {
  final supabase = Supabase.instance.client;
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
          .select('*, profiles!inner(full_name)')
          .eq('business_id', widget.businessId)
          .eq('status', 'approved');

      var rewardsQuery = supabase
          .from('rewards')
          .select('*, profiles!inner(full_name)')
          .eq('business_id', widget.businessId);

      if (_dateRange != null) {
        final start = _dateRange!.start.toIso8601String();
        final end = _dateRange!.end
            .add(const Duration(days: 1))
            .toIso8601String();

        final sQ = scansQuery.gte('scanned_at', start).lt('scanned_at', end);
        final rQ = rewardsQuery.gte('earned_at', start).lt('earned_at', end);

        final scansResponse = await sQ.order('scanned_at', ascending: false);
        final rewardsResponse = await rQ.order('earned_at', ascending: false);

        if (mounted) {
          setState(() {
            _scans = List<Map<String, dynamic>>.from(scansResponse);
            _rewards = List<Map<String, dynamic>>.from(rewardsResponse);
            _isLoading = false;
          });
        }
      } else {
        final scansResponse = await scansQuery.order(
          'scanned_at',
          ascending: false,
        );
        final rewardsResponse = await rewardsQuery.order(
          'earned_at',
          ascending: false,
        );

        if (mounted) {
          setState(() {
            _scans = List<Map<String, dynamic>>.from(scansResponse);
            _rewards = List<Map<String, dynamic>>.from(rewardsResponse);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _selectDateRange() async {
    final initialDateRange =
        _dateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historial de Actividad'),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Escaneos'),
              Tab(text: 'Premios'),
            ],
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black38,
            indicatorColor: Colors.black,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _dateRange == null
                    ? Icons.filter_alt_outlined
                    : Icons.filter_alt,
              ),
              onPressed: _selectDateRange,
              color: _dateRange == null ? null : Colors.black,
            ),
            if (_dateRange != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() => _dateRange = null);
                  _loadHistory();
                },
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.accentPurple),
                ),
              )
            : TabBarView(children: [_buildScansList(), _buildRewardsList()]),
      ),
    );
  }

  Widget _buildScansList() {
    if (_scans.isEmpty)
      return const Center(child: Text('No hay escaneos en este periodo'));
    return ListView.builder(
      itemCount: _scans.length,
      itemBuilder: (context, index) {
        final scan = _scans[index];
        final profile = scan['profiles'];
        final profileName = profile['full_name'] ?? 'Usuario';
        return ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: Text(
            profileName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            EcuadorDateUtils.formatEcuadorTime(scan['scanned_at']),
          ),
          trailing: const Text(
            '+1 Punto',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildRewardsList() {
    if (_rewards.isEmpty)
      return const Center(child: Text('No hay premios en este periodo'));
    return ListView.builder(
      itemCount: _rewards.length,
      itemBuilder: (context, index) {
        final reward = _rewards[index];
        final profile = reward['profiles'];
        final profileName = profile['full_name'] ?? 'Usuario';
        return ListTile(
          leading: const Icon(Icons.card_giftcard, color: AppTheme.accentPurple),
          title: Text(
            profileName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            EcuadorDateUtils.formatEcuadorTime(reward['earned_at']),
          ),
          trailing: Text(
            '-${reward['points_used']} Pts',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}
