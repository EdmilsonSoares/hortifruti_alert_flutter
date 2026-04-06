import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const TelaInicial(),
    );
  }
}

class Fruta {
  String nome;
  DateTime dataVencimento;
  Duration duracaoOriginal;

  Fruta({
    required this.nome,
    required this.duracaoOriginal,
    DateTime? vencimento,
  }) : dataVencimento = vencimento ?? DateTime.now().add(duracaoOriginal);

  // Converte a Fruta para um "Mapa" (formato que vira JSON)
  Map<String, dynamic> toJson() => {
    'nome': nome,
    'vencimento': dataVencimento.toIso8601String(),
    'duracaoOriginal': duracaoOriginal.inSeconds,
  };

  // Cria uma Fruta a partir de um "Mapa" vindo do JSON
  factory Fruta.fromJson(Map<String, dynamic> json) {
    return Fruta(
      nome: json['nome'],
      duracaoOriginal: Duration(seconds: json['duracaoOriginal']),
      vencimento: DateTime.parse(json['vencimento']),
    );
  }

  Duration get tempoRestante {
    Duration diferenca = dataVencimento.difference(DateTime.now());
    return diferenca.isNegative ? Duration.zero : diferenca;
  }
}

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  List<Fruta> listaDeFrutas = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    // TIMER OTIMIZADO: 30 segundos (Equilíbrio entre bateria e precisão)
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    // Transformamos nossa lista de objetos em uma String JSON
    String encodedData = jsonEncode(
      listaDeFrutas.map((item) => item.toJson()).toList(),
    );
    await prefs.setString('lista_frutas', encodedData);
  }

  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('lista_frutas');

    if (savedData != null) {
      Iterable decodedData = jsonDecode(savedData);
      setState(() {
        listaDeFrutas =
            decodedData.map((item) => Fruta.fromJson(item)).toList();
      });
    }
  }

  void _abrirFormulario({Fruta? frutaParaEditar, int? index}) {
    // Se estiver editando, começa com os valores atuais. Se não, começa vazio.
    String nome = frutaParaEditar?.nome ?? "";
    int horas = frutaParaEditar?.duracaoOriginal.inHours ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(frutaParaEditar == null ? "Cadastrar Novo Item" : "Editar Item"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ENTRADA DE DADOS: NOME
              TextFormField(
                initialValue: nome,
                decoration: const InputDecoration(labelText: "Nome do Item"),
                onChanged: (valor) => nome = valor,
              ),
              // ENTRADA DE DADOS: TEMPO
              TextFormField(
                initialValue: horas > 0 ? horas.toString() : "",
                decoration: const InputDecoration(labelText: "Horas para expirar"),
                keyboardType: TextInputType.number,
                onChanged: (valor) => horas = int.tryParse(valor) ?? 0,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF6961),
                foregroundColor: Colors.white,
              ),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () {
                if (nome.isNotEmpty && horas > 0) {
                  setState(() {
                    Duration duracao = Duration(hours: horas);
                    if (frutaParaEditar == null) {
                      // MODO CADASTRO: Adiciona novo
                      listaDeFrutas.add(Fruta(nome: nome, duracaoOriginal: duracao));
                    } else {
                      // MODO EDIÇÃO: Atualiza o existente
                      listaDeFrutas[index!] = Fruta(nome: nome, duracaoOriginal: duracao);
                    }
                  });
                  _salvarDados(); // Grava no disco
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Salvar", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Hortifruti Alert",
          style: TextStyle(
            color: Colors.white, // Define a cor branca
            fontWeight: FontWeight.bold, // Define o negrito
            fontSize: 24,
          ),
        ),
        centerTitle: true, // Centraliza o título
        backgroundColor: const Color(0xFF426042),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6AAA1E), Color(0xFF0D570D)],
          ),
        ),
        child:
            listaDeFrutas.isEmpty
                ? const Center(
                  child: Text(
                    "Nenhum item monitorado.",
                    style: TextStyle(color: Colors.white),
                  ),
                )
                : ListView.builder(
                  itemCount: listaDeFrutas.length,
                  itemBuilder: (context, index) {
                    final item = listaDeFrutas[index];
                    final tempo = item.tempoRestante;

                    return Dismissible(
                      // A chave precisa ser única. Usamos o nome + a data de vencimento.
                      key: Key(item.nome + item.dataVencimento.toString()),

                      // Direção do arrasto (da direita para a esquerda)
                      direction: DismissDirection.endToStart,

                      // O que aparece "atrás" do card enquanto arrastamos
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        // Alinhado com o Card
                        decoration: BoxDecoration(
                          color: const Color(0xFF426042),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),

                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Confirmar Exclusão"),
                              content: Text("Deseja remover '${item.nome}' do monitoramento?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false), // Retorna FALSE (não deleta)
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6961), // Seu vermelho pastel
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text("Cancelar"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true), // Retorna TRUE (deleta)
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text("Excluir", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        );
                      },

                      // Lógica que acontece após o arrasto completo
                      onDismissed: (direction) {
                        setState(() {
                          listaDeFrutas.removeAt(index);
                        });
                        _salvarDados(); // Atualiza o banco de dados
                        // Feedback rápido para o usuário
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${item.nome} removido da lista"),),
                        );
                      },

                      child: Card(
                        color: Colors.white.withValues(alpha: 0.9),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.timer,
                            size: 32,
                            color: tempo.inMinutes <= 0 ? Colors.red : Colors.green,
                          ),
                          title: Text(
                            item.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20,),
                          ),
                          subtitle: Text(
                            "${tempo.inDays}d ${tempo.inHours % 24}h ${tempo.inMinutes % 60}m",
                            style: TextStyle(
                              fontSize: 18,
                              color: tempo.inMinutes <= 0 ? Colors.red : Colors.black54,
                              fontWeight: tempo.inMinutes <= 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),

                          onLongPress: () {
                            // Abrimos o formulário de edição
                            _abrirFormulario(frutaParaEditar: item, index: index);
                          },

                          trailing: IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              // Ressetar cronômetro - Abrimos uma caixa de diálogo antes de qualquer ação
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Confirmar Reposição"),
                                    content: Text(
                                      "Você deseja resetar o cronômetro de '${item.nome}'?",
                                    ),
                                    actions: [
                                      // Botão para desistir
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFFF6961,
                                          ),
                                          foregroundColor: const Color(
                                            0xFFFFFFFF,
                                          ),
                                        ),
                                        child: const Text(
                                          "Cancelar",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Botão para confirmar o reset
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            // Só aqui o tempo é resetado
                                            item.dataVencimento = DateTime.now()
                                                .add(item.duracaoOriginal);
                                          });
                                          _salvarDados(); // Grava no disco após adicionar
                                          Navigator.pop(
                                            context,
                                          ); // Fecha o aviso
                                        },
                                        child: const Text(
                                          "Confirmar",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.green, size: 30),
      ),
    );
  }
}
