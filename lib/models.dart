import 'package:flutter/material.dart';
import 'dart:collection';

// ゲームの進行フェーズを定義
enum GamePhase {
  placeTile,
  foundHotel, // ホテルを設立するフェーズ
  merger, // 合併処理中
  disposeOfShares, // 合併後の株処理
  buyStock,
  drawTile,
  gameOver, // ゲーム終了
}

// 合併情報を保持するクラス
class MergerInfo {
  final HotelChain survivor; // 存続ホテル
  final List<HotelChain> defuncts; // 吸収されるホテル
  final Map<Player, int> majorityShareholders; // 筆頭株主ボーナス
  final Map<Player, int> minorityShareholders; // 次点株主ボーナス

  // 株処理が必要なプレイヤーのキュー
  final ListQueue<Player> shareDisposalQueue;

  MergerInfo({
    required this.survivor,
    required this.defuncts,
    required this.majorityShareholders,
    required this.minorityShareholders,
    required this.shareDisposalQueue,
  });
}

// タイルの位置と状態を表現
class Tile {
  final int row;
  final int col;
  final String label; // 例: "3A"

  Tile({required this.row, required this.col})
      : label = '${row + 1}${String.fromCharCode('A'.codeUnitAt(0) + col)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tile &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

// ホテルチェーンの情報を表現
class HotelChain {
  final String name;
  final Color color;
  List<Tile> tiles = [];
  int stockCount = 25; // 各ホテルの株の総数は25枚
  int get size => tiles.length;
  bool get isActive => size > 0;

  HotelChain({required this.name, required this.color});
}

// プレイヤーの状態を表現
class Player {
  final String name;
  int cash;
  List<Tile> hand = []; // 手持ちのタイル
  Map<HotelChain, int> stocks = {}; // 保有株
  final bool isComputer;
  List<Tile> deadTiles = []; // 配置不能でゲームから除外されたタイル

  Player({required this.name, this.cash = 6000, this.isComputer = false}) {
    // stocksマップを初期化
    // GameStateが生成される前にPlayerが作られるため、ここでは初期化できない
  }
}

// ゲーム全体の盤面や状態を管理
class GameState {
  final int rows = 12;
  final int cols = 9;
  final int playerCount;

  List<Player> players = [];
  int currentPlayerIndex = 0;
  Player get currentPlayer => players[currentPlayerIndex];
  GamePhase currentPhase = GamePhase.placeTile;

  // 盤面上のタイルを管理
  Map<String, Tile> boardTiles = {};

  // 全108枚のタイルが入るバッグ
  List<Tile> tileBag = [];

  // 7つのホテルチェーン
  List<HotelChain> hotelChains = [
    HotelChain(name: 'Luxor', color: Colors.deepOrange),
    HotelChain(name: 'Tower', color: Colors.yellow),
    HotelChain(name: 'American', color: Colors.blue),
    HotelChain(name: 'Festival', color: Colors.green),
    HotelChain(name: 'Worldwide', color: Colors.brown),
    HotelChain(name: 'Continental', color: Colors.cyan),
    HotelChain(name: 'Imperial', color: Colors.pink),
  ];
  List<HotelChain> get activeChains => hotelChains.where((hc) => hc.isActive).toList();
  List<HotelChain> get inactiveChains => hotelChains.where((hc) => !hc.isActive).toList();
  Tile? lastPlacedTile; // ホテル設立/合併を引き起こしたタイル
  MergerInfo? mergerInfo; // 現在の合併情報

  GameState({this.playerCount = 2}) {
    _initializeGame();
    // Playerのstocksマップをここで初期化
    for (var player in players) {
      for (var hotel in hotelChains) {
        player.stocks[hotel] = 0;
      }
    }
  }

  // ゲームの初期化処理
  void _initializeGame() {
    // プレイヤーを作成
    players.add(Player(name: 'Player 1', isComputer: false)); // プレイヤー1は人間
    for (int i = 1; i < playerCount; i++) {
      players.add(Player(name: 'Computer ${i}', isComputer: true));
    }

    // タイルバッグを生成
    tileBag = [];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        tileBag.add(Tile(row: r, col: c));
      }
    }
    tileBag.shuffle();

    // 各プレイヤーにタイルを6枚配る
    for (var player in players) {
      drawTiles(player, 6);
    }

    // 開始タイルを決定し、盤面に配置するロジック
    // 各プレイヤーの手札から、盤面の中央から最も遠いタイルを探す
    Tile? farthestTile;
    Player? startingPlayer;
    double maxDistance = -1;

    for (var player in players) {
      for (var tile in player.hand) {
        final distance = _distanceFromCenter(tile);
        if (distance > maxDistance) {
          maxDistance = distance;
          farthestTile = tile;
          startingPlayer = player;
        }
      }
    }

    // 開始プレイヤーとタイルが決定したら、そのタイルを盤面に置く
    if (startingPlayer != null && farthestTile != null) {
      boardTiles[farthestTile.label] = farthestTile;
      startingPlayer.hand.remove(farthestTile);
      drawTiles(startingPlayer, 1); // 1枚補充
      // 開始プレイヤーの次のプレイヤーからゲームを開始する
      currentPlayerIndex = (players.indexOf(startingPlayer) + 1) % players.length;
    }
  }

  // プレイヤーがタイルをバッグから引く
  void drawTiles(Player player, int count) {
    for (var i = 0; i < count && tileBag.isNotEmpty; i++) {
      player.hand.add(tileBag.removeLast());
    }
  }

  // ターン終了時にゲーム終了条件をチェック
  void checkForGameOver() {
    final isAnyHotelTooBig = activeChains.any((h) => h.size >= 41);
    final areAllHotelsSafe = activeChains.isNotEmpty && activeChains.every((h) => h.size >= 11);

    if (isAnyHotelTooBig || areAllHotelsSafe) {
      currentPhase = GamePhase.gameOver;
      _calculateFinalScores();
    }
  }

  // 最終スコア計算
  void _calculateFinalScores() {
    // 1. 全てのホテルチェーンの株主ボーナスを支払う
    for (var hotel in activeChains) {
       final shareholders = _getShareholders(hotel);
       if (shareholders.isEmpty) continue;

      // 筆頭株主と次点株主を取得
      final majorityHolders = shareholders.entries.where((e) => e.value == shareholders.values.first).map((e) => e.key).toList();
      final secondHighestCount = shareholders.values.length > 1 ? shareholders.values.elementAt(1) : 0;
      final minorityHolders = shareholders.entries.where((e) => e.value == secondHighestCount && e.value > 0).map((e) => e.key).toList();

      // ボーナス額を計算
      final majorityBonus = getBonus(hotel, isMajority: true);
      final minorityBonus = getBonus(hotel, isMajority: false);

       if (majorityHolders.length > 1) {
        final totalBonus = majorityBonus + minorityBonus;
        for (var holder in majorityHolders) {
          holder.cash += (totalBonus ~/ majorityHolders.length);
        }
      } else if (majorityHolders.isNotEmpty) {
        final holder = majorityHolders.first;
        holder.cash += majorityBonus;
        
        if (minorityHolders.isNotEmpty) {
           for (var mHolder in minorityHolders) {
             mHolder.cash += (minorityBonus ~/ minorityHolders.length);
           }
        }
      }
    }

    // 2. 全プレイヤーの株を現在の株価で売却
    for (var player in players) {
      for (var hotel in activeChains) {
        final stockCount = player.stocks[hotel] ?? 0;
        if (stockCount > 0) {
          player.cash += stockCount * getStockPrice(hotel);
          player.stocks[hotel] = 0;
        }
      }
    }
  }

  // --- ゲーム進行ロジック ---

  // 配置可能かチェックする
  bool isTilePlaceable(Tile tile) {
    // 既にタイルが置かれている場所には置けない
    if (boardTiles.containsKey(tile.label)) {
      return false;
    }

    final adjacentBoardTiles = getAdjacentTiles(tile)
        .where((t) => boardTiles.containsKey(t.label))
        .toList();

    final adjacentHotels = adjacentBoardTiles
        .map(getHotelForTile)
        .whereType<HotelChain>()
        .toSet();

    // ケース1: 合併を引き起こす場合
    if (adjacentHotels.length > 1) {
      // 複数の安全なホテルを合併させるタイルは配置不可
      if (adjacentHotels.every((h) => h.size >= 11)) {
        return false;
      }
    }

    // ケース2: 新しいホテルを設立する場合
    if (adjacentHotels.isEmpty && adjacentBoardTiles.isNotEmpty) {
      // 全てのホテルチェーンが活動中の場合、新しいホテルは設立できない
      if (inactiveChains.isEmpty) {
        return false;
      }
    }

    // 上記のどの条件にも当てはまらなければ配置可能
    return true;
  }

  // 手札のタイルがすべて配置不能かチェックし、配置不能なタイルを交換する
  void checkAndReplaceUnplayableTiles(Player player) {
    List<Tile> unplayableHand = [];
    for (var tile in player.hand) {
      if (!isTilePlaceable(tile)) {
        unplayableHand.add(tile);
      }
    }

    // 手札が全て配置不能だった場合
    if (unplayableHand.length == player.hand.length) {
      // 配置不能なタイルをdeadTilesに移動
      player.deadTiles.addAll(unplayableHand);
      player.hand.clear();
      // 新しいタイルを引く
      drawTiles(player, unplayableHand.length);
    }
  }

  // タイルを配置した後のアクションを返す
  GamePhase placeTile(Tile tile) {
    // 配置不能なタイルは置けない
    if (!isTilePlaceable(tile)) {
      // 本来はUI側で制御すべきだが、念のため
      return currentPhase;
    }

    // 1. 盤面にタイルを置く
    boardTiles[tile.label] = tile;
    currentPlayer.hand.remove(tile);
    lastPlacedTile = tile;

    // 2. 隣接するタイルとホテルを調べる
    final adjacentTiles = getAdjacentTiles(tile).where((t) => boardTiles.containsKey(t.label)).toList();
    final adjacentHotels = adjacentTiles.map(getHotelForTile).whereType<HotelChain>().toSet().toList();

    if (adjacentHotels.isEmpty) {
      // 隣にホテルがない場合
      if (adjacentTiles.isNotEmpty) {
        // 隣に孤立タイルがある -> ホテル設立
        return GamePhase.foundHotel;
      } else {
        // 隣に何もない -> ただのタイル配置
        return GamePhase.buyStock;
      }
    } else if (adjacentHotels.length == 1) {
      // 隣にホテルが1つ -> ホテル拡大
      final hotel = adjacentHotels.first;
      hotel.tiles.add(tile);
      // 隣接する孤立タイルもすべてホテルに含める
      for (var adjacentTile in adjacentTiles) {
        if (getHotelForTile(adjacentTile) == null) {
          hotel.tiles.add(adjacentTile);
        }
      }
      return GamePhase.buyStock;
    } else {
      // 隣にホテルが2つ以上 -> 合併
      _prepareMerger(adjacentHotels);
      return GamePhase.merger;
    }
  }

  // 合併の準備をする
  void _prepareMerger(List<HotelChain> involvedHotels) {
    // サイズでソートして、最大のホテルを決定
    involvedHotels.sort((a, b) => b.size.compareTo(a.size));
    final survivor = involvedHotels.first;
    final defuncts = involvedHotels.sublist(1);

    // TODO: もし最大のホテルが複数ある場合、プレイヤーが選択するルール

    // 各廃業ホテルについて株主ボーナスを計算
    final Map<Player, int> majorityPayouts = {};
    final Map<Player, int> minorityPayouts = {};
    final ListQueue<Player> disposalQueue = ListQueue();

    for (var defunct in defuncts) {
      final shareholders = _getShareholders(defunct);
      
      // 筆頭株主と次点株主を取得
      final majorityHolders = shareholders.entries.where((e) => e.value == shareholders.values.first).map((e) => e.key).toList();
      final secondHighestCount = shareholders.values.length > 1 ? shareholders.values.elementAt(1) : 0;
      final minorityHolders = shareholders.entries.where((e) => e.value == secondHighestCount).map((e) => e.key).toList();

      // ボーナス額を計算
      final majorityBonus = getBonus(defunct, isMajority: true);
      final minorityBonus = getBonus(defunct, isMajority: false);

      // ボーナスを分配
      if (majorityHolders.length > 1) {
        // 筆頭株主が複数いる場合、筆頭と次点のボーナスを合算して分配
        final totalBonus = majorityBonus + minorityBonus;
        for (var holder in majorityHolders) {
          majorityPayouts[holder] = (majorityPayouts[holder] ?? 0) + (totalBonus ~/ majorityHolders.length);
        }
      } else if (majorityHolders.isNotEmpty) {
        // 筆頭株主が1人の場合
        final holder = majorityHolders.first;
        majorityPayouts[holder] = (majorityPayouts[holder] ?? 0) + majorityBonus;
        
        // 次点株主ボーナスの分配
        if (minorityHolders.isNotEmpty) {
           for (var mHolder in minorityHolders) {
             minorityPayouts[mHolder] = (minorityPayouts[mHolder] ?? 0) + (minorityBonus ~/ minorityHolders.length);
           }
        }
      }

      // 株処理キューにプレイヤーを追加
      for (var player in players) {
        if ((player.stocks[defunct] ?? 0) > 0 && !disposalQueue.contains(player)) {
          disposalQueue.add(player);
        }
      }
    }

    mergerInfo = MergerInfo(
      survivor: survivor,
      defuncts: defuncts,
      majorityShareholders: majorityPayouts,
      minorityShareholders: minorityPayouts,
      shareDisposalQueue: disposalQueue,
    );
  }

  // 合併処理を実行
  void handleMerger() {
    if (mergerInfo == null) return;

    // ボーナスを支払う
    mergerInfo!.majorityShareholders.forEach((player, amount) {
      player.cash += amount;
    });
    mergerInfo!.minorityShareholders.forEach((player, amount) {
      player.cash += amount;
    });

    // ホテルタイルを統合
    for (var defunct in mergerInfo!.defuncts) {
      mergerInfo!.survivor.tiles.addAll(defunct.tiles);
      defunct.tiles.clear();
    }
    // 合併を引き起こしたタイルも追加
    mergerInfo!.survivor.tiles.add(lastPlacedTile!);
  }

  // 合併後の株を処理する
  void disposeShares(HotelChain defunctHotel, int sell, int trade) {
    if (mergerInfo == null || mergerInfo!.shareDisposalQueue.isEmpty) return;

    final player = mergerInfo!.shareDisposalQueue.first;
    final survivor = mergerInfo!.survivor;
    final totalShares = player.stocks[defunctHotel] ?? 0;

    if (sell + trade > totalShares) return; // 持っている以上の株は処理できない

    // 1. 株を売る
    final sellPrice = getStockPrice(defunctHotel);
    player.cash += sell * sellPrice;
    player.stocks[defunctHotel] = (player.stocks[defunctHotel] ?? 0) - sell;

    // 2. 株を交換する (2:1)
    final tradeShares = (trade / 2).floor();
    if (survivor.stockCount >= tradeShares) {
      player.stocks[defunctHotel] = (player.stocks[defunctHotel] ?? 0) - trade;
      player.stocks[survivor] = (player.stocks[survivor] ?? 0) + tradeShares;
      survivor.stockCount -= tradeShares;
    }
  }

  // 株処理キューを次に進める
  void advanceDisposalQueue() {
    if (mergerInfo == null || mergerInfo!.shareDisposalQueue.isEmpty) return;

    // 現在のプレイヤーをキューから削除
    mergerInfo!.shareDisposalQueue.removeFirst();

    // キューが空になったら、合併フェーズを終了して株購入へ
    if (mergerInfo!.shareDisposalQueue.isEmpty) {
      currentPhase = GamePhase.buyStock;
      mergerInfo = null; // 合併情報をクリア
    }
  }

  // ホテルを設立する
  void foundHotel(HotelChain hotel, Tile tile) {
    // 設立されたホテルにタイルを追加
    hotel.tiles.add(tile);
    // 隣接していた孤立タイルもすべて追加
    final adjacentTiles = getAdjacentTiles(tile).where((t) => boardTiles.containsKey(t.label)).toList();
    for (var adjacentTile in adjacentTiles) {
      if (getHotelForTile(adjacentTile) == null) {
        hotel.tiles.add(adjacentTile);
      }
    }

    // 設立したプレイヤーは株を1枚もらう（株が残っていれば）
    if (hotel.stockCount > 0) {
      currentPlayer.stocks[hotel] = (currentPlayer.stocks[hotel] ?? 0) + 1;
      hotel.stockCount--;
    }
  }

  // 株を購入する
  bool buyStocks(Map<HotelChain, int> stocksToBuy) {
    int totalCost = 0;
    int totalShares = 0;

    // 合計コストと枚数を計算
    stocksToBuy.forEach((hotel, count) {
      totalCost += getStockPrice(hotel) * count;
      totalShares += count;
    });

    // バリデーション
    if (totalShares > 3) return false; // 3枚まで
    if (currentPlayer.cash < totalCost) return false; // 所持金が足りない
    // TODO: 各ホテルの残り株数のチェック

    // 購入処理
    currentPlayer.cash -= totalCost;
    stocksToBuy.forEach((hotel, count) {
      currentPlayer.stocks[hotel] = (currentPlayer.stocks[hotel] ?? 0) + count;
      hotel.stockCount -= count;
    });

    return true;
  }


  // --- ヘルパーメソッド ---

  // 株主とその持ち株数を降順で返す
  Map<Player, int> _getShareholders(HotelChain hotel) {
    final Map<Player, int> shareholders = {};
    for (var player in players) {
      if ((player.stocks[hotel] ?? 0) > 0) {
        shareholders[player] = player.stocks[hotel]!;
      }
    }
    // 持ち株数で降順にソート
    return Map.fromEntries(
        shareholders.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)));
  }

  // 株主ボーナス額を取得する
  int getBonus(HotelChain hotel, {required bool isMajority}) {
    final price = getStockPrice(hotel);
    return isMajority ? price * 10 : price * 5;
  }

  // 株価を取得する
  int getStockPrice(HotelChain hotel) {
    final size = hotel.size;
    if (size == 0) return 0;
    if (size >= 2 && size <= 5) return size * 100;
    if (size >= 6 && size <= 10) return 600;
    if (size >= 11 && size <= 20) return 700;
    if (size >= 21 && size <= 30) return 800;
    if (size >= 31 && size <= 40) return 900;
    if (size >= 41) return 1000;
    return 0; // 該当しない場合
  }

  // 指定されたタイルが属するホテルを返す
  HotelChain? getHotelForTile(Tile tile) {
    for (var hotel in activeChains) {
      if (hotel.tiles.contains(tile)) {
        return hotel;
      }
    }
    return null;
  }

  // 指定されたタイルの隣接タイルリストを返す
  List<Tile> getAdjacentTiles(Tile tile) {
    final List<Tile> neighbors = [];
    // 上
    if (tile.row > 0) neighbors.add(Tile(row: tile.row - 1, col: tile.col));
    // 下
    if (tile.row < rows - 1) neighbors.add(Tile(row: tile.row + 1, col: tile.col));
    // 左
    if (tile.col > 0) neighbors.add(Tile(row: tile.row, col: tile.col - 1));
    // 右
    if (tile.col < cols - 1) neighbors.add(Tile(row: tile.row, col: tile.col + 1));
    return neighbors;
  }

  // 盤面の中央からの距離を計算する（開始タイル決定用）
  double _distanceFromCenter(Tile tile) {
    final centerRow = rows / 2;
    final centerCol = cols / 2;
    return ((tile.row - centerRow).abs() + (tile.col - centerCol).abs());
  }
}
