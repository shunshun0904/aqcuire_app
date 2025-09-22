import 'package:flutter/material.dart';

void main() {
  runApp(AcquireApp());
}

class AcquireApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acquire Board Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AcquireHomePage(),
    );
  }
}

class AcquireHomePage extends StatefulWidget {
  @override
  _AcquireHomePageState createState() => _AcquireHomePageState();
}

class _AcquireHomePageState extends State<AcquireHomePage> {
  // 盤面サイズ設定：行12、列9
  final int rows = 12; // 数字で表される行
  final int cols = 9;  // アルファベットで表される列

  // 盤面状態（0=空き、1=タイル設置など）
  List<List<int>> board = [];

  List<Player> players = [
    Player(name: 'Player 1', cash: 6000),
    Player(name: 'Player 2', cash: 6000),
  ];
  int currentPlayerIndex = 0;

  // 列のラベル（アルファベット）
  final List<String> columnLabels = ['A','B','C','D','E','F','G','H','I'];

  @override
  void initState() {
    super.initState();
    board = List.generate(rows, (_) => List.filled(cols, 0));
  }

  @override
  Widget build(BuildContext context) {
    final currentPlayer = players[currentPlayerIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Acquire Board Game 12x9'),
      ),
      body: Column(
        children: [
          // プレイヤー情報表示
          Container(
            padding: EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: players.map((p) {
                return Column(
                  children: [
                    Text(p.name, style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Cash: \$${p.cash}'),
                  ],
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 10),
          // 盤面列ラベル表示
          Container(
            height: 20,
            child: Row(
              children: [
                SizedBox(width: 30), // 行ラベルのためのスペース
                ...columnLabels.map((label) => Expanded(
                  child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
                )).toList(),
              ],
            ),
          ),
          // 盤面表示
          Expanded(
            child: ListView.builder(
              itemCount: rows,
              itemBuilder: (context, rowIndex) {
                return Row(
                  children: [
                    // 行ラベル（数字、1始まりで表示）
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: Text((rowIndex + 1).toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // 各マス
                    Expanded(
                      child: Row(
                        children: List.generate(cols, (colIndex) {
                          int cellValue = board[rowIndex][colIndex];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  board[rowIndex][colIndex] = 1; // タイル設置例
                                  currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.all(1),
                                height: 30,
                                decoration: BoxDecoration(
                                  color: cellValue == 0 ? Colors.white : Colors.blueAccent,
                                  border: Border.all(color: Colors.black12),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Current Player: ${currentPlayer.name}', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class Player {
  final String name;
  int cash;

  Player({required this.name, required this.cash});
}