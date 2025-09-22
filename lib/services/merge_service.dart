import '../models/player.dart';

class ChainInfo {
  final String name;
  final int size;
  ChainInfo(this.name, this.size);
}

class Dividend {
  final Player player;
  final int amount;
  Dividend(this.player, this.amount);
}

class MergeService {
  // 盤面上のチェーン名を買収チェーン名に置換する処理（実装例）
  void replaceChainOnBoard(String fromChain, String toChain) {
    // 実データの盤面上を書き換えるロジックを実装
    // 例：盤面2D配列を走査しfromChainをtoChainに置換
  }

  // 吸収されるチェーンの株主に配当を計算し配布する
  List<Dividend> calculateDividends(String chainName, List<Player> players) {
    // プレイヤーの保有株数を集計し、筆頭株主・第2株主判定
    List<MapEntry<Player, int>> holdings = players
      .map((p) => MapEntry(p, p.stockCount(chainName)))
      .where((e) => e.value > 0)
      .toList();

    holdings.sort((a, b) => b.value.compareTo(a.value));

    if (holdings.isEmpty) return [];

    int firstCount = holdings[0].value;
    Player firstPlayer = holdings[0].key;

    Player? secondPlayer;

    if (holdings.length > 1) {
      for (var h in holdings.skip(1)) {
        if (h.value < firstCount) {
          secondPlayer = h.key;
          break;
        }
      }
    }

    // 配当額はチェーン規模によって変動させる想定
    // 今回は便宜的に固定値として例示
    int firstDividend = 3000;
    int secondDividend = 1500;

    List<Dividend> dividends = [
      Dividend(firstPlayer, firstDividend)
    ];

    if (secondPlayer != null) {
      dividends.add(Dividend(secondPlayer, secondDividend));
    }

    return dividends;
  }

  // 配当配布処理
  void distributeDividends(List<Dividend> dividends) {
    for (var div in dividends) {
      div.player.cash += div.amount;
      print('${div.player.name} receives dividend of ${div.amount}');
    }
  }

  // 合併処理のメイン初期メソッド例
  void handleMerge(String acquiringChain, List<String> acquiredChains, List<Player> players) {
    // 盤面書き換え処理
    for (var chain in acquiredChains) {
      replaceChainOnBoard(chain, acquiringChain);
    }
    // 各吸収チェーンへ配当実行
    for (var chain in acquiredChains) {
      List<Dividend> dividends = calculateDividends(chain, players);
      distributeDividends(dividends);
    }
  }
}
