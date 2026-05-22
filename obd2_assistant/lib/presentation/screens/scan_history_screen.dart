import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/scan_record.dart';
import '../../data/repositories/scan_history_repository_impl.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final _scanHistoryRepo = ScanHistoryRepositoryImpl();
  List<ScanRecord> _scans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  String _formatDate(DateTime date, {bool fullMonth = false}) {
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (fullMonth) {
      final months = [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
        'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
      ];
      final monthStr = months[date.month - 1];
      return '$day $monthStr ${date.year} à $hour:$minute';
    } else {
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month/${date.year} $hour:$minute';
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final scans = await _scanHistoryRepo.getAllScans();
      setState(() {
        _scans = scans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement: $e')),
      );
    }
  }

  Future<void> _deleteScan(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer ce diagnostic ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _scanHistoryRepo.deleteScan(id);
      _loadHistory();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vider l\'historique ?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous supprimer définitivement tous les diagnostics enregistrés ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Vider'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _scanHistoryRepo.clearAll();
      _loadHistory();
    }
  }

  Color _getSeverityColor(String safety) {
    final lower = safety.toLowerCase();
    if (lower.contains('do not drive') || lower.contains('critical') || lower.contains('rouge') || lower.contains('danger')) {
      return AppColors.error;
    } else if (lower.contains('caution') || lower.contains('attention') || lower.contains('orange') || lower.contains('warning')) {
      return AppColors.accent;
    }
    return AppColors.success;
  }

  IconData _getSeverityIcon(String safety) {
    final lower = safety.toLowerCase();
    if (lower.contains('do not drive') || lower.contains('critical') || lower.contains('danger')) {
      return Icons.gpp_bad_rounded;
    } else if (lower.contains('caution') || lower.contains('attention')) {
      return Icons.warning_amber_rounded;
    }
    return Icons.verified_user_rounded;
  }

  void _showScanDetail(ScanRecord scan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rapport Diagnostic',
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                        ),
                        Text(
                          _formatDate(scan.date, fullMonth: true),
                          style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 28),
                  )
                ],
              ),
            ),
            const Divider(height: 24, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Safety Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(scan.safety).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _getSeverityColor(scan.safety).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(_getSeverityIcon(scan.safety), color: _getSeverityColor(scan.safety), size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NIVEAU DE SÉCURITÉ',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: _getSeverityColor(scan.safety)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                scan.safety.isEmpty ? 'Non renseigné' : scan.safety,
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DTC / Code d'erreurs
                  Text(
                    'Codes Défauts (DTCs)',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                  ),
                  const SizedBox(height: 8),
                  scan.storedDtcs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.success),
                              const SizedBox(width: 8),
                              Text('Aucun défaut stocké', style: GoogleFonts.outfit(color: Colors.black87)),
                            ],
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: scan.storedDtcs
                              .map((dtc) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.error.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      dtc,
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 15),
                                    ),
                                  ))
                              .toList(),
                        ),
                  const SizedBox(height: 20),

                  // Urgency / Issue
                  if (scan.urgency.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Degré d\'urgence : ${scan.urgency}',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (scan.issue.isNotEmpty) ...[
                    Text(
                      'Description du Problème',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        scan.issue,
                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // AI Analysis Complete Text
                  Text(
                    'Analyse Détaillée IA',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      scan.aiSummary,
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Raw Live Data snapshot
                  if (scan.liveDataSnapshot.isNotEmpty) ...[
                    Text(
                      'Données Capteurs (Snapshot)',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: scan.liveDataSnapshot.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final key = scan.liveDataSnapshot.keys.elementAt(index);
                          final val = scan.liveDataSnapshot[key];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('PID $key', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: AppColors.secondaryText)),
                                Text(val ?? '', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primaryText)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Historique des Scans',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.primaryText),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_scans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
              tooltip: 'Vider l\'historique',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun historique de scan',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Les diagnostics complets que vous effectuez s\'afficheront automatiquement ici.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _scans.length,
                    itemBuilder: (context, index) {
                      final scan = _scans[index];
                      final hasDtc = scan.storedDtcs.isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.04),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _showScanDetail(scan),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: _getSeverityColor(scan.safety),
                                  width: 5,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_getSeverityIcon(scan.safety), color: _getSeverityColor(scan.safety), size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(scan.date),
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondaryText),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondaryText, size: 22),
                                      onPressed: () => _deleteScan(scan.id),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  scan.storedDtcs.isEmpty
                                      ? '✅ Aucun défaut détecté'
                                      : '⚠️ Défauts : ${scan.storedDtcs.join(', ')}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: hasDtc ? AppColors.error : AppColors.success,
                                  ),
                                ),
                                if (scan.issue.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    scan.issue,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Voir le rapport complet',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
