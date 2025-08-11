import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:gestao_leitores/models/usuarios.dart';
import 'package:gestao_leitores/screens/eventos_religiosos.dart';
import 'package:gestao_leitores/screens/login_form.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../models/escala_liturgica.dart';
import '../models/leitor.dart';
import '../services/firestore_service.dart';
import 'escala_form.dart';

class EscalaLiturgicaView extends StatefulWidget {
  final Usuario? usuario;

  const EscalaLiturgicaView({super.key, this.usuario});

  @override
  State<EscalaLiturgicaView> createState() => _EscalaLiturgicaViewState();
}

class _EscalaLiturgicaViewState extends State<EscalaLiturgicaView> {
  final FirestoreService _service = FirestoreService();
  final _searchController = TextEditingController();

  List<EscalaLiturgica> _todasEscalas = [];
  List<EscalaLiturgica> _escalasFiltradas = [];

  bool _buscando = false;
  bool _offline = false;

  // NOVO: toggle para filtrar por “Recentes”
  bool _filtrarRecentes = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_PT', null);
    _verificarConectividade();
  }

  void _verificarConectividade() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _offline = connectivityResult == ConnectivityResult.none;
    });
  }

  // Helpers de data
  DateTime _hojeSemHora() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escalas"),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            label: const Text('Eventos', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EventosReligiososScreen(usuario: widget.usuario),
                ),
              );
            },
          ),
          if (widget.usuario == null)
            TextButton.icon(
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Login', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Nova Escala',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EscalaForm(usuario: widget.usuario)),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_offline)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Você está offline. Mostrando escalas salvas no cache.',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome do leitor',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _filtrarEscalasPorNome,
                  child: const Text("Buscar"),
                ),
                const SizedBox(width: 8),
                // NOVO: botão “Recentes”
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filtrarRecentes = !_filtrarRecentes;
                      // Permitimos combinar com busca; não mexemos no _buscando aqui
                    });
                  },
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Recentes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _filtrarRecentes ? Colors.teal : null,
                    foregroundColor: _filtrarRecentes ? Colors.white : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpar filtro',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _buscando = false;
                      _filtrarRecentes = false;
                      _escalasFiltradas = _todasEscalas;
                    });
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EscalaLiturgica>>(
              stream: _service.getEscalasLiturgicas(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Base
                _todasEscalas = snapshot.data!;

                // ORDENAR: novas em cima (data desc)
                _todasEscalas.sort((a, b) {
                  final da = _parseDate(a.data);
                  final db = _parseDate(b.data);
                  if (da == null && db == null) return 0;
                  if (da == null) return 1; // sem data vai para baixo
                  if (db == null) return -1;
                  return db.compareTo(da); // desc
                });

                // Aplicar filtro "Recentes" (datas > hoje)
                List<EscalaLiturgica> base = _todasEscalas;
                if (_filtrarRecentes) {
                  final hoje = _hojeSemHora();
                  base = base.where((e) {
                    final d = _parseDate(e.data);
                    return d != null && d.isAfter(hoje);
                  }).toList();
                }

                // Se estamos em modo busca, usamos os resultados; senão, a base
                final listaParaExibir = _buscando ? _escalasFiltradas : base;

                if (listaParaExibir.isEmpty) {
                  return const Center(child: Text("Nenhuma escala encontrada."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: listaParaExibir.length,
                  itemBuilder: (context, index) {
                    final escala = listaParaExibir[index];

                    final d = _parseDate(escala.data);
                    final hoje = _hojeSemHora();
                    // Antigas = antes ou igual a hoje
                    final isAntiga = (d == null) ? false : !d.isAfter(hoje);

                    return FutureBuilder<Map<String, Leitor>>(
                      future: _buscarLeitoresDaEscala(escala),
                      builder: (context, snapshotLeitores) {
                        if (!snapshotLeitores.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final leitores = snapshotLeitores.data!;
                        return _buildCard(escala, leitores, isAntiga);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, Leitor>> _buscarLeitoresDaEscala(
      EscalaLiturgica escala) async {
    final ids = {
      escala.introdutorId,
      escala.primeiraLeituraLLId,
      escala.primeiraLeituraPTId,
      escala.segundaLeituraLLId,
      escala.segundaLeituraPTId,
      escala.evangelhoId,
    }.where((id) => id.trim().isNotEmpty).toList();

    final leitores = await _service.getLeitoresByIds(ids);
    return {for (var leitor in leitores) leitor.id: leitor};
  }

  Future<void> _filtrarEscalasPorNome() async {
    final nomeBuscado = _searchController.text.trim().toLowerCase();
    if (nomeBuscado.isEmpty) {
      setState(() {
        _buscando = false;
        _escalasFiltradas = _todasEscalas;
      });
      return;
    }

    // Procurar por nome dos leitores envolvidos na escala
    List<EscalaLiturgica> resultados = [];

    for (final escala in _todasEscalas) {
      final ids = {
        escala.introdutorId,
        escala.primeiraLeituraLLId,
        escala.primeiraLeituraPTId,
        escala.segundaLeituraLLId,
        escala.segundaLeituraPTId,
        escala.evangelhoId,
      }.where((id) => id.trim().isNotEmpty).toList();

      final leitores = await _service.getLeitoresByIds(ids);
      final leitorEncontrado = leitores
          .any((leitor) => leitor.nome.toLowerCase().contains(nomeBuscado));

      if (leitorEncontrado) {
        resultados.add(escala);
      }
    }

    // Se o filtro "Recentes" estiver activo, combinamos com ele
    if (_filtrarRecentes) {
      final hoje = _hojeSemHora();
      resultados = resultados.where((e) {
        final d = _parseDate(e.data);
        return d != null && d.isAfter(hoje);
      }).toList();
    }

    setState(() {
      _escalasFiltradas = resultados;
      _buscando = true;
    });
  }

  Widget _buildCard(
    EscalaLiturgica escala,
    Map<String, Leitor> leitores,
    bool isAntiga,
  ) {
    final Color bg = isAntiga ? Colors.grey.shade900 : Colors.white;
    final Color primaryText = isAntiga ? Colors.white : Colors.black87;
    final Color secondaryText = isAntiga ? Colors.grey.shade300 : Colors.grey;

    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 32,
                  color: isAntiga ? Colors.teal.shade200 : Colors.teal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        escala.domingo,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      Text(
                        _formatarData(escala.data),
                        style: TextStyle(fontSize: 14, color: secondaryText),
                      ),
                    ],
                  ),
                ),
                if (widget.usuario != null)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color:
                              isAntiga ? Colors.indigo.shade200 : Colors.indigo,
                        ),
                        tooltip: 'Editar escala',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EscalaForm(
                                escala: escala,
                                usuario: widget.usuario,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  )
              ],
            ),
            Divider(height: 24, color: isAntiga ? Colors.teal.shade200 : Colors.teal),
            _leitorLinhaCond(
              "Introdutor",
              escala.introdutorId,
              leitores,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            _leitorLinhaCond(
              "1ª Leitura (Língua Local)",
              escala.primeiraLeituraLLId,
              leitores,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            _leitorLinhaCond(
              "1ª Leitura (Português)",
              escala.primeiraLeituraPTId,
              leitores,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            _leitorLinhaCond(
              "2ª Leitura (Língua Local)",
              escala.segundaLeituraLLId,
              leitores,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            _leitorLinhaCond(
              "2ª Leitura (Português)",
              escala.segundaLeituraPTId,
              leitores,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
            _leitorLinhaCond(
              "Evangelho",
              escala.evangelhoId,
              leitores,
              primaryText: primaryText,
              secondaryText: secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _leitorLinhaCond(
    String label,
    String? id,
    Map<String, Leitor> leitores, {
    required Color primaryText,
    required Color secondaryText,
  }) {
    if (id == null || id.trim().isEmpty) return const SizedBox.shrink();

    final leitor = leitores[id];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            leitor?.nome ?? '—',
            style: TextStyle(fontSize: 15, color: primaryText),
          ),
          if (widget.usuario != null)
            if (leitor?.contacto != null && leitor!.contacto.trim().isNotEmpty)
              Text(
                leitor.contacto,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
        ],
      ),
    );
  }

  String _formatarData(String isoDate) {
    final data = DateTime.tryParse(isoDate);
    if (data == null) return isoDate;
    return DateFormat("EEEE, dd 'de' MMMM", 'pt_PT').format(data);
  }

  Future<bool> isOffline() async {
    final result = await Connectivity().checkConnectivity();
    return result == ConnectivityResult.none;
  }
}
