import 'package:flutter/material.dart';
import 'models.dart';

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
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: GameSetupScreen(), // 初期画面をセットアップスクリーンに変更
      debugShowCheckedModeBanner: false,
    );
  }
}

// ゲーム設定画面
class GameSetupScreen extends StatefulWidget {
  @override
  _GameSetupScreenState createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  int _playerCount = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup New Game'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Number of Players:', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 10),
              DropdownButton<int>(
                value: _playerCount,
                items: List.generate(5, (i) => i + 2) // 2から6までのリストを生成
                    .map((count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count players'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _playerCount = value;
                    });
                  }
                },
              ),
              SizedBox(height: 30),
              ElevatedButton(
                child: Text('Start Game'),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AcquireHomePage(playerCount: _playerCount),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class AcquireHomePage extends StatefulWidget {
  final int playerCount;
  const AcquireHomePage({Key? key, required this.playerCount}) : super(key: key);

  @override
  _AcquireHomePageState createState() => _AcquireHomePageState();
}

class _AcquireHomePageState extends State<AcquireHomePage> {
  late GameState gameState;

  @override
  void initState() {
    super.initState();
    gameState = GameState(playerCount: widget.playerCount);
    // 最初のプレイヤーがコンピュータなら、即座にターンを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && gameState.currentPlayer.isComputer) {
        handleComputerTurn();
      }
    });
  }

  // ゲームの状態を更新し、UIを再描画するためのメソッド
  void updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acquire'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              PlayerInfoPanel(gameState: gameState),
              SizedBox(
                height: 400, // 必要に応じて調整
                child: GameBoard(gameState: gameState, onTileTapped: handleTileTap),
              ),
              ControlPanel(
                gameState: gameState,
                onPlaceTile: handlePlaceTile,
                onEndTurn: handleEndTurn,
                onDisposeOfShares: handleDisposeOfShares,
                onAdvanceDisposalQueue: handleAdvanceDisposalQueue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // タイルがタップされたときの処理
  void handleTileTap(int row, int col) {
    // このメソッドは現在使用されていませんが、将来の機能のために残しておきます。
    // タイル配置はControlPanelのActionChipから直接handlePlaceTileを呼び出します。
    print("Board tile tapped: $row, $col");
  }

  // 手持ちのタイルが選択されたときの処理
  void handlePlaceTile(Tile tile) {
    if (gameState.currentPhase != GamePhase.placeTile) return;

    // 配置可能かチェック
    if (!gameState.isTilePlaceable(tile)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('This tile cannot be placed here (would merge two safe hotels).'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      final nextPhase = gameState.placeTile(tile);
      gameState.currentPhase = nextPhase;

      if (nextPhase == GamePhase.foundHotel) {
        showFoundHotelDialog();
      } else if (nextPhase == GamePhase.merger) {
        // ★修正点: 人間プレイヤーの合併時にダイアログを表示する
        showMergerDialog();
      }
    });
  }

  // ホテル設立ダイアログ
  void showFoundHotelDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Found a New Hotel Chain!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose a hotel to found:'),
              ...gameState.inactiveChains.map((hotel) {
                return ListTile(
                  title: Text(hotel.name),
                  leading: Icon(Icons.business, color: hotel.color),
                  onTap: () {
                    Navigator.of(context).pop();
                    handleFoundHotel(hotel);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ホテル設立処理
  void handleFoundHotel(HotelChain hotel) {
    setState(() {
      gameState.foundHotel(hotel, gameState.lastPlacedTile!);
      gameState.currentPhase = GamePhase.buyStock;
    });
  }

  // 合併ダイアログ
  void showMergerDialog() {
    final mergerInfo = gameState.mergerInfo!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Merger!'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('${mergerInfo.survivor.name} is acquiring:'),
                ...mergerInfo.defuncts.map((h) => Text('- ${h.name}')),
                SizedBox(height: 10),
                Text('Shareholder Payouts:'),
                ...mergerInfo.defuncts.map((defunct) {
                  final majorityBonus = gameState.getBonus(defunct, isMajority: true);
                  final minorityBonus = gameState.getBonus(defunct, isMajority: false);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${defunct.name}:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('  Majority: \$${majorityBonus}'),
                      Text('  Minority: \$${minorityBonus}'),
                    ],
                  );
                }),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                handleMerger();
              },
            ),
          ],
        );
      },
    );
  }

  // 合併処理（ダイアログの後、またはコンピュータのターンで呼ばれる）
  void handleMerger() {
    setState(() {
      gameState.handleMerger(); // ボーナス支払いとタイル統合
      
      // 株の処理キューがあるかチェック
      if (gameState.mergerInfo != null && gameState.mergerInfo!.shareDisposalQueue.isNotEmpty) {
        gameState.currentPhase = GamePhase.disposeOfShares;
        // キューの先頭がコンピュータなら、即座に処理を開始
        if (mounted && gameState.mergerInfo!.shareDisposalQueue.first.isComputer) {
          Future.delayed(Duration(milliseconds: 500), handleComputerMergerShares);
        }
        // キューの先頭が人間なら、UIが更新されて操作を待つ
      } else {
        // 株処理が不要なら、株購入フェーズへ
        gameState.currentPhase = GamePhase.buyStock;
      }
    });
  }

  // 株の処理
  void handleDisposeOfShares(HotelChain defunctHotel, int sell, int trade) {
    setState(() {
      gameState.disposeShares(defunctHotel, sell, trade);
    });
  }

  // 株処理キューを進める
  void handleAdvanceDisposalQueue() {
    setState(() {
      gameState.advanceDisposalQueue();
      // 次のプレイヤーがキューにいるかチェック
      if (gameState.currentPhase == GamePhase.disposeOfShares) {
        // 次のプレイヤーがコンピュータなら、その処理を自動実行
        if (mounted && gameState.mergerInfo!.shareDisposalQueue.first.isComputer) {
          Future.delayed(Duration(milliseconds: 500), handleComputerMergerShares);
        }
      }
    });
  }


  // ターンを終了する処理
  void handleEndTurn() {
    if (!mounted) return;
    setState(() {
      // ゲーム終了チェック
      gameState.checkForGameOver();
      if (gameState.currentPhase == GamePhase.gameOver) {
        showGameOverDialog();
        return;
      }

      gameState.drawTiles(gameState.currentPlayer, 1);
      gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % gameState.players.length;
      gameState.currentPhase = GamePhase.placeTile;

      // 次のプレイヤーがコンピュータなら、そのターンを自動実行
      if (gameState.currentPlayer.isComputer && mounted) {
        Future.delayed(Duration(milliseconds: 500), handleComputerTurn);
      }
    });
  }

  // コンピュータのターン処理のメインループ
  void handleComputerTurn() {
    if (!gameState.currentPlayer.isComputer || !mounted || gameState.currentPhase == GamePhase.gameOver) return;

    setState(() {
      // --- 1. タイル配置フェーズ ---
      if (gameState.currentPhase == GamePhase.placeTile) {
        gameState.checkAndReplaceUnplayableTiles(gameState.currentPlayer);
        
        final placeableTiles = gameState.currentPlayer.hand.where((t) => gameState.isTilePlaceable(t)).toList();
        if (placeableTiles.isEmpty) {
          handleEndTurn();
          return;
        }

        final tileToPlay = (placeableTiles..shuffle()).first;
        final nextPhase = gameState.placeTile(tileToPlay);
        gameState.currentPhase = nextPhase;
        
        Future.delayed(Duration(milliseconds: 500), handleComputerTurn);
        return;
      }

      // --- 2. ホテル設立フェーズ ---
      if (gameState.currentPhase == GamePhase.foundHotel) {
        final hotelToFound = (gameState.inactiveChains..shuffle()).first;
        gameState.foundHotel(hotelToFound, gameState.lastPlacedTile!);
        gameState.currentPhase = GamePhase.buyStock;

        Future.delayed(Duration(milliseconds: 500), handleComputerTurn);
        return;
      }

      // --- 3. 合併フェーズ ---
      if (gameState.currentPhase == GamePhase.merger) {
        // コンピュータはダイアログなしで即座に合併処理を実行
        handleMerger();
        return;
      }

      // --- 4. 株購入フェーズ ---
      if (gameState.currentPhase == GamePhase.buyStock) {
        final affordableHotels = gameState.activeChains
            .where((h) => gameState.currentPlayer.cash >= gameState.getStockPrice(h) && h.stockCount > 0)
            .toList();
        if (affordableHotels.isNotEmpty) {
          final hotelToBuy = (affordableHotels..shuffle()).first;
          int maxCanBuy = 3;
          int affordableCount = (gameState.currentPlayer.cash / gameState.getStockPrice(hotelToBuy)).floor();
          int buyCount = [maxCanBuy, affordableCount, hotelToBuy.stockCount].reduce((a, b) => a < b ? a : b);
          
          if(buyCount > 0) {
            gameState.buyStocks({hotelToBuy: buyCount});
          }
        }
        handleEndTurn();
        return;
      }
    });
  }

  // コンピュータの合併時の株処理
  void handleComputerMergerShares() {
    if (!mounted || gameState.currentPhase != GamePhase.disposeOfShares) return;

    bool needsHumanInteraction = false;

    setState(() {
      while (gameState.mergerInfo != null && gameState.mergerInfo!.shareDisposalQueue.isNotEmpty) {
        if (gameState.mergerInfo!.shareDisposalQueue.first.isComputer) {
          final defunct = gameState.mergerInfo!.defuncts.first;
          gameState.disposeShares(defunct, 0, 0); // 全て保持する戦略
          gameState.advanceDisposalQueue();
        } else {
          needsHumanInteraction = true;
          break;
        }
      }

      if (!needsHumanInteraction) {
        gameState.currentPhase = GamePhase.buyStock;
        // コンピュータのターンの続き（株購入）へ
        Future.delayed(Duration(milliseconds: 500), handleComputerTurn);
      }
    });
  }

  // ゲーム終了ダイアログ
  void showGameOverDialog() {
    final sortedPlayers = List<Player>.from(gameState.players)
      ..sort((a, b) => b.cash.compareTo(a.cash));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Game Over!'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Final Scores:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...sortedPlayers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final player = entry.value;
                  return ListTile(
                    leading: Text('#${index + 1}'),
                    title: Text(player.name),
                    trailing: Text('\$${player.cash}'),
                  );
                }),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('New Game'),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }
}

// プレイヤー情報を表示するウィジェット
class PlayerInfoPanel extends StatelessWidget {
  final GameState gameState;
  const PlayerInfoPanel({Key? key, required this.gameState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10.0,
        runSpacing: 10.0,
        children: gameState.players.map((player) {
          final isCurrent = player == gameState.currentPlayer;
          return Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: isCurrent ? Colors.blue.shade700 : Colors.grey,
                width: isCurrent ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(player.name, style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Cash: \$${player.cash}'),
                SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: gameState.activeChains.map((hotel) {
                    final stockCount = player.stocks[hotel] ?? 0;
                    if (stockCount == 0) return SizedBox.shrink();
                    return Chip(
                      label: Text('${hotel.name}: $stockCount', style: TextStyle(fontSize: 10)),
                      backgroundColor: hotel.color.withOpacity(0.7),
                      padding: EdgeInsets.all(2),
                    );
                  }).toList(),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ゲーム盤面を表示するウィジェット
class GameBoard extends StatelessWidget {
  final GameState gameState;
  final Function(int, int) onTileTapped;
  const GameBoard({Key? key, required this.gameState, required this.onTileTapped}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cols = gameState.cols;
    final rows = gameState.rows;
    final columnLabels = List.generate(cols, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 30),
              ...columnLabels.map((label) => Expanded(
                child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
              )).toList(),
            ],
          ),
          Expanded(
            child: AbsorbPointer(
              absorbing: gameState.currentPlayer.isComputer,
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
                      ...List.generate(cols, (colIndex) {
                        final tile = Tile(row: rowIndex, col: colIndex);
                        final hotel = gameState.getHotelForTile(tile);
                        final isPlaced = hotel != null || gameState.boardTiles.containsKey(tile.label);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onTileTapped(rowIndex, colIndex),
                            child: Container(
                              height: 30,
                              margin: const EdgeInsets.all(1.0),
                              decoration: BoxDecoration(
                                color: hotel?.color ?? (isPlaced ? Colors.grey[400] : Colors.white),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: isPlaced ? Center(child: Text(tile.label, style: TextStyle(fontSize: 8, color: Colors.white))) : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 操作パネルと手持ちタイルを表示するウィジェット
class ControlPanel extends StatelessWidget {
  final GameState gameState;
  final Function(Tile) onPlaceTile;
  final VoidCallback onEndTurn;
  final Function(HotelChain, int, int) onDisposeOfShares;
  final VoidCallback onAdvanceDisposalQueue;


  const ControlPanel({
    Key? key,
    required this.gameState,
    required this.onPlaceTile,
    required this.onEndTurn,
    required this.onDisposeOfShares,
    required this.onAdvanceDisposalQueue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final player = gameState.currentPlayer;
    final phase = gameState.currentPhase;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${player.name}\'s Turn (${phase.name})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),

          if (phase == GamePhase.placeTile) ...[
            if (!player.isComputer) ...[
              Text('Your Tiles:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: player.hand.map((tile) {
                  final isPlaceable = gameState.isTilePlaceable(tile);
                  return ActionChip(
                    label: Text(tile.label),
                    onPressed: isPlaceable ? () => onPlaceTile(tile) : null,
                    backgroundColor: isPlaceable ? Colors.blue[100] : Colors.grey[300],
                    tooltip: isPlaceable ? 'Place this tile' : 'Cannot place this tile',
                  );
                }).toList(),
              ),
            ] else ...[
              Text('Computer is thinking...'),
            ]
          ],

          if (phase == GamePhase.buyStock)
            BuyStockPanel(gameState: gameState, onEndTurn: onEndTurn),

          if (phase == GamePhase.foundHotel)
            Text('You\'ve founded a new chain! Choose one from the dialog.'),

          if (phase == GamePhase.merger)
            Text('Merger in progress...'),

          if (phase == GamePhase.disposeOfShares)
            DisposeOfSharesPanel(
              gameState: gameState,
              onConfirm: onDisposeOfShares,
              onContinue: onAdvanceDisposalQueue,
            ),
          
          if (phase == GamePhase.gameOver)
            Text('Game Over! Check the results.'),
        ],
      ),
    );
  }
}

// 株購入用ウィジェット
class BuyStockPanel extends StatefulWidget {
  final GameState gameState;
  final VoidCallback onEndTurn;

  const BuyStockPanel({Key? key, required this.gameState, required this.onEndTurn}) : super(key: key);

  @override
  _BuyStockPanelState createState() => _BuyStockPanelState();
}

class _BuyStockPanelState extends State<BuyStockPanel> {
  final Map<HotelChain, int> _buyCounts = {};

  @override
  Widget build(BuildContext context) {
    final activeHotels = widget.gameState.activeChains;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Buy Stocks (up to 3):', style: TextStyle(fontWeight: FontWeight.bold)),
        ...activeHotels.map((hotel) {
          return Row(
            children: [
              Icon(Icons.business, color: hotel.color),
              SizedBox(width: 8),
              Text('${hotel.name} (\$${widget.gameState.getStockPrice(hotel)})'),
              Spacer(),
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                onPressed: () {
                  setState(() {
                    _buyCounts[hotel] = (_buyCounts[hotel] ?? 0) - 1;
                    if (_buyCounts[hotel]! < 0) _buyCounts[hotel] = 0;
                  });
                },
              ),
              Text(_buyCounts[hotel]?.toString() ?? '0'),
              IconButton(
                icon: Icon(Icons.add_circle_outline),
                onPressed: () {
                  final total = _buyCounts.values.fold(0, (sum, count) => sum + count);
                  if (total < 3) {
                    setState(() {
                      _buyCounts[hotel] = (_buyCounts[hotel] ?? 0) + 1;
                    });
                  }
                },
              ),
            ],
          );
        }).toList(),
        SizedBox(height: 10),
        ElevatedButton(
          child: Text('Confirm Buy & End Turn'),
          onPressed: () {
            final totalToBuy = _buyCounts.values.fold(0, (sum, item) => sum + item);
            final success = widget.gameState.buyStocks(_buyCounts);
            if (success) {
              if (totalToBuy > 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Stocks purchased successfully!'),
                  duration: Duration(seconds: 2),
                ));
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('No stocks were purchased.'),
                  duration: Duration(seconds: 2),
                ));
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Could not buy stocks. Check cash or share limits.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ));
              return;
            }
            widget.onEndTurn();
          },
        )
      ],
    );
  }
}

// 合併時の株処理用ウィジェット
class DisposeOfSharesPanel extends StatefulWidget {
  final GameState gameState;
  final Function(HotelChain, int, int) onConfirm;
  final VoidCallback onContinue;

  const DisposeOfSharesPanel({
    Key? key,
    required this.gameState,
    required this.onConfirm,
    required this.onContinue,
  }) : super(key: key);

  @override
  _DisposeOfSharesPanelState createState() => _DisposeOfSharesPanelState();
}

class _DisposeOfSharesPanelState extends State<DisposeOfSharesPanel> {
  late Player currentPlayer;
  late HotelChain defunctHotel;
  late int totalShares;
  int sellCount = 0;
  int tradeCount = 0;

  @override
  void initState() {
    super.initState();
    _updateState();
  }

  @override
  void didUpdateWidget(covariant DisposeOfSharesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameState.mergerInfo?.shareDisposalQueue.first != currentPlayer) {
      setState(() {
        _updateState();
      });
    }
  }

  void _updateState() {
    if (widget.gameState.mergerInfo == null || widget.gameState.mergerInfo!.shareDisposalQueue.isEmpty) return;
    currentPlayer = widget.gameState.mergerInfo!.shareDisposalQueue.first;
    defunctHotel = widget.gameState.mergerInfo!.defuncts.first;
    totalShares = currentPlayer.stocks[defunctHotel] ?? 0;
    sellCount = 0;
    tradeCount = 0;
  }


  @override
  Widget build(BuildContext context) {
    if (widget.gameState.mergerInfo == null || widget.gameState.mergerInfo!.shareDisposalQueue.isEmpty) {
      return SizedBox.shrink();
    }
    final survivorHotel = widget.gameState.mergerInfo!.survivor;
    final canTrade = (tradeCount / 2).floor() <= survivorHotel.stockCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${currentPlayer.name}, dispose of your ${totalShares} shares in ${defunctHotel.name}:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text('Sell (Price: \$${widget.gameState.getStockPrice(defunctHotel)})'),
        Slider(
          value: sellCount.toDouble(),
          min: 0,
          max: totalShares.toDouble(),
          divisions: totalShares > 0 ? totalShares : 1,
          label: sellCount.toString(),
          onChanged: (value) {
            setState(() {
              int newSell = value.round();
              int maxTrade = totalShares - newSell;
              if (tradeCount > maxTrade) tradeCount = maxTrade - (maxTrade % 2);
              sellCount = newSell;
            });
          },
        ),
        Text('Trade for ${survivorHotel.name} (2 for 1)'),
        Slider(
          value: tradeCount.toDouble(),
          min: 0,
          max: totalShares.toDouble(),
          divisions: (totalShares ~/ 2) > 0 ? (totalShares ~/ 2) : 1,
          label: tradeCount.toString(),
          onChanged: (value) {
            setState(() {
              int newTrade = (value ~/ 2) * 2;
              int maxSell = totalShares - newTrade;
              if (sellCount > maxSell) sellCount = maxSell;
              tradeCount = newTrade;
            });
          },
        ),
        SizedBox(height: 10),
        Text('Keep: ${(totalShares - sellCount - tradeCount).round()}'),
        SizedBox(height: 10),
        if (!canTrade)
          Text('Not enough stock in ${survivorHotel.name} to trade!', style: TextStyle(color: Colors.red)),
        ElevatedButton(
          child: Text('Confirm'),
          onPressed: canTrade ? () {
            widget.onConfirm(defunctHotel, sellCount.round(), tradeCount.round());
            widget.onContinue();
          } : null,
        )
      ],
    );
  }
}