import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:gestao_leitores/services/firestore_service.dart';
import 'package:gestao_leitores/models/leitor.dart';
import 'package:gestao_leitores/screens/rating_service.dart'; // Serviço de rating

class RankingPage extends StatefulWidget {
  @override
  _RankingPageState createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final RatingService ratingService = RatingService(FirestoreService());
  late Future<List<LeitorRating>> leaderboard;

  @override
  void initState() {
    super.initState();
    leaderboard = ratingService.getLeaderboardOnce();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ranking de Leitores"),
      ),
      body: FutureBuilder<List<LeitorRating>>(
        future: leaderboard,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final leitorRatings = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: leitorRatings.length,
            itemBuilder: (context, index) {
              final leitor = leitorRatings[index];

              // Determinar classificação e número de estrelas com base na média
              String classificacao;
              int estrelas;

              if (leitor.media <= 2) {
                classificacao = "Péssimo";
                estrelas = 1;
              } else if (leitor.media <= 4) {
                classificacao = "Insatisfatório";
                estrelas = 2;
              } else if (leitor.media <= 6) {
                classificacao = "Razoável";
                estrelas = 3;
              } else if (leitor.media <= 8) {
                classificacao = "Bom";
                estrelas = 4;
              } else {
                classificacao = "Excelente";
                estrelas = 5;
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(child: Text(leitor.nome[0])),
                  title: Text(leitor.nome),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Estrelas + Classificação
                      Row(
                        children: [
                          RatingBarIndicator(
                            rating: estrelas.toDouble(),
                            itemBuilder: (context, _) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemSize: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            classificacao,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Notas resumidas na mesma linha
                      Text(
                        "D: ${leitor.mediaDiccao.toStringAsFixed(0)}, "
                        "R: ${leitor.mediaRitmo.toStringAsFixed(0)}, "
                        "P: ${leitor.mediaSinaisPontuacao.toStringAsFixed(0)}, "
                        "E: ${leitor.mediaEnsaio.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    // ação ao clicar no item
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
