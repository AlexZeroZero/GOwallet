import type { Coin } from './coins.js';

export type Balance={confirmed:number;unconfirmed:number};
export type HistoryRow={tx_hash:string;height:number;fee?:number};
export class ElectrumClient {
  private ws?:WebSocket; private next=1; private pending=new Map<number,{resolve:(v:any)=>void,reject:(e:any)=>void}>();
  constructor(public readonly url:string){}
  async connect(){if(this.ws?.readyState===WebSocket.OPEN)return; await new Promise<void>((resolve,reject)=>{const w=new WebSocket(this.url);this.ws=w;const timer=setTimeout(()=>{w.close();reject(Error('连接节点超时'))},10000);w.onopen=()=>{clearTimeout(timer);resolve()};w.onerror=()=>{clearTimeout(timer);reject(Error('WSS 网关连接失败'))};w.onmessage=e=>{try{const m=JSON.parse(e.data);if(typeof m.id==='number'){const p=this.pending.get(m.id);if(!p)return;this.pending.delete(m.id);m.error?p.reject(Error(m.error.message||'节点错误')):p.resolve(m.result)}}catch{}};w.onclose=()=>{for(const p of this.pending.values())p.reject(Error('节点连接已关闭'));this.pending.clear()}})}
  async call(method:string,params:any[]=[]){await this.connect();const id=this.next++;return new Promise<any>((resolve,reject)=>{this.pending.set(id,{resolve,reject});this.ws!.send(JSON.stringify({jsonrpc:'2.0',id,method,params})+'\n')})}
  close(){this.ws?.close();this.ws=undefined}
  async verify(coin:Coin){const result=await this.call('server.features');if(!result||typeof result.genesis_hash!=='string'||result.genesis_hash.toLowerCase()!==coin.genesis)throw Error(`节点链不匹配：${coin.ticker}`);return result}
  async balance(scriptHash:string){const hash=await this.call('blockchain.scripthash.get_balance', [scriptHash]);return {confirmed:Number(hash?.confirmed||0),unconfirmed:Number(hash?.unconfirmed||0)} as Balance}
}
