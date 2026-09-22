export type CoinId = 'scash' | 'shic' | 'pep' | 'dingo';
export type Coin = {
  id: CoinId; ticker: string; name: string; slip44: number; decimals: number;
  p2pkh: number; p2sh: number; wif: number; bech32?: string;
  genesis: string; node: string; explorer: string; color: string;
};

// WebSocket endpoints are served by the included electrum-ws-gateway. The
// gateway's upstream is TLS Electrum; it never receives wallet secrets.
export const COINS: Record<CoinId, Coin> = {
  scash: { id:'scash', ticker:'SCASH', name:'Scash', slip44:805, decimals:8, p2pkh:0, p2sh:5, wif:128, bech32:'scash', genesis:'e3bf1597a568216022dbda6a0945f09b005d19f041e7158c3cbca9d4029ee82d', node:'wss://scash.gozero.trade/electrum/scash', explorer:'https://explorer.scash.network/tx/', color:'#3866DC' },
  shic: { id:'shic', ticker:'SHIC', name:'Shibacoin', slip44:4474, decimals:8, p2pkh:63, p2sh:22, wif:158, genesis:'ff271edcc83f7d71e7a4e4b0a43b386a188e1470a28671cdbdc47e900118ac7f', node:'wss://shic.gozero.trade/electrum/shic', explorer:'https://shibaexplorer.com/tx/', color:'#D46B31' },
  pep: { id:'pep', ticker:'PEP', name:'Pepecoin', slip44:3434, decimals:8, p2pkh:56, p2sh:22, wif:158, genesis:'37981c0c48b8d48965376c8a42ece9a0838daadb93ff975cb091f57f8c2a5faa', node:'wss://electrum.pepeblocks.com/electrum', explorer:'https://pepeblocks.com/tx/', color:'#4CAF50' },
  dingo: { id:'dingo', ticker:'DINGO', name:'Dingocoin', slip44:3, decimals:8, p2pkh:30, p2sh:22, wif:158, genesis:'1a91e3dace36e2be3bf030a65679fe821aa1d6ef92e7c9902eb318182c355691', node:'wss://elecx1.dingocoin.com/electrum', explorer:'https://explorer.dingocoin.com/tx/', color:'#B17C30' },
};
