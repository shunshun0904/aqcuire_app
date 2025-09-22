import 'package:flutter/material.dart';
import '../models/player.dart';

class AcquireHomePage extends StatefulWidget {
  @override
  _AcquireHomePageState createState() => _AcquireHomePageState();
}

class _AcquireHomePageState extends State<AcquireHomePage> {
  final int rows = 12;
  final int cols = 9;

  List<List<int>> board = [];

  List<Player> players = [
    Player(name: 'Player 1', cash: 6000),
    Player(name: 'Player 2', cash: 6000),
  ];
  int currentPlayerIndex = 0;

  final List<String> columnLabels = ['A','B','C','D','E','F','G','H','I'];

  @override
  void initState() {
    super.initState();
    board = List.generate(rows, (_) => List.filled(cols, 0));
  }

  void onBuyStockPressed(Player player, String hotel, int quantity, int pricePerStock) {
    bool success = player.buyStock(hotel, quantity, pricePerStock);
    if (success) {
      print('${player.name} bought $quantity stocks of $hotel');
    } else {
      print('Not enough cash to buy stocks');
    }
    setState(() {});
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
          Container(
            height: 20,
            child: Row(
              children: [
                SizedBox(width: 30),
                ...columnLabels.map((label) =>
                    Expanded(child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))))
                ).toList(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: rows,
              itemBuilder: (context, rowIndex) {
                return Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: Text((rowIndex + 1).toString(), style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Row(
                        children: List.generate(cols, (colIndex) {
                          int cellValue = board[rowIndex][colIndex];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  board[rowIndex][colIndex] = 1;
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
