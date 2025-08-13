import 'package:flutter/material.dart';
import 'package:gestao_leitores/models/leitor.dart';
import 'package:gestao_leitores/models/usuarios.dart';
import 'package:gestao_leitores/screens/escala_form.dart';
import 'package:gestao_leitores/screens/escala_liturgica_view.dart';
import 'package:gestao_leitores/screens/leitor_form.dart';
import 'package:gestao_leitores/screens/leitores_list.dart';
import 'package:gestao_leitores/screens/ranking_page.dart';
import 'package:gestao_leitores/screens/rating_service.dart';
import 'package:gestao_leitores/screens/register_form.dart';
import 'package:gestao_leitores/services/firestore_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:gestao_leitores/screens/presenca_form.dart';
import 'package:gestao_leitores/screens/presenca_view.dart';

// >>> Importa o serviço (cálculo do ranking)

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, this.leitor, this.usuario}) : super(key: key);

  final Leitor? leitor;
  final Usuario? usuario;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService service = FirestoreService();
  final RatingService ratingService = RatingService(FirestoreService());

  final Map<DateTime, List<String>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  void _addEvent(DateTime day) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova nota / evento'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Descrição'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      setState(() {
        final key = DateTime(day.year, day.month, day.day);
        _events.putIfAbsent(key, () => []).add(controller.text.trim());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pt_BR', null); // ou 'pt_PT'
  }

  // Abre a tela de ranking inline (sem criar ficheiro separado)
  void _abrirRanking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Ranking de Leitores'),
            backgroundColor: Colors.teal.shade700,
          ),
          body: FutureBuilder<List<LeitorRating>>(
            future: ratingService.getLeaderboardOnce(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erro ao carregar ranking'));
              }
              final lista = snap.data ?? [];
              if (lista.isEmpty) {
                return const Center(child: Text('Sem avaliações válidas no momento.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = lista[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(r.nome),
                    subtitle: Text(
                      'Média: ${r.media.toStringAsFixed(1)}  '
                      '(D:${r.mediaDiccao.toStringAsFixed(1)} | '
                      'V:${r.mediaColocacaoVoz.toStringAsFixed(1)} | '
                      'S:${r.mediaSinaisPontuacao.toStringAsFixed(1)} | '
                      'R:${r.mediaRitmo.toStringAsFixed(1)} | '
                      'E:${r.mediaEnsaio.toStringAsFixed(1)})',
                    ),
                    trailing: Text('${r.avaliacoes} aval.'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Gestão de Leitores'),
            if (widget.usuario != null)
              Text(
                widget.usuario!.nome,
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: StreamBuilder<List<Leitor>>(
        stream: service.getLeitores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final leitores = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // ---------- CALENDÁRIO ----------
              TableCalendar(
                locale: 'pt_BR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) =>
                    _selectedDay != null && isSameDay(d, _selectedDay),
                calendarFormat: CalendarFormat.month,
                eventLoader: (day) =>
                    _events[DateTime(day.year, day.month, day.day)] ?? [],
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  _addEvent(selected); // abre diálogo para nova nota
                },
              ),
              const SizedBox(height: 8),

              // ---------- CARD COM TOTAL ----------
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeitoresPage()),
                  );
                },
                child: Card(
                  color: Colors.teal.shade50,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.groups, color: Colors.teal),
                    title: const Text('Total de leitores cadastrados'),
                    trailing: Text(
                      '${leitores.length}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

                 const SizedBox(height: 8),

        // ---------- BOTÃO: RANKING DE LEITORES (novo botão) ----------
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RankingPage()), // Navegação para o RankingPage
            );
          },
          child: Card(
            color: Colors.amber.shade50,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ListTile(
              leading: Icon(Icons.leaderboard, color: Colors.teal),
              title: Text('Ranking de Leitores'),
            ),
          ),
        ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.teal.shade700,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomBarButton(
                icon: Icons.person_add,
                label: 'Leitor',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LeitorForm()),
                ),
              ),
              _BottomBarButton(
                icon: Icons.person_add,
                label: 'Utilizador',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterScreen()),
                ),
              ),
              _BottomBarButton(
                icon: Icons.event,
                label: 'Nova Escala',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EscalaForm()),
                ),
              ),
              _BottomBarButton(
                icon: Icons.view_list,
                label: 'Ver Escalas',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          EscalaLiturgicaView(usuario: widget.usuario)),
                ),
              ),
              _BottomBarButton(
                icon: Icons.check_circle_outline,
                label: 'Presenças',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PresencaForm()),
                ),
              ),
              _BottomBarButton(
                icon: Icons.list_alt,
                label: 'Ver Presenças',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PresencaView()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
