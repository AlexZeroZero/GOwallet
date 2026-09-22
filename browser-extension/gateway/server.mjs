import { WebSocketServer } from 'ws';
import tls from 'node:tls';
import http from 'node:http';

const port=Number(process.env.PORT||8790);
const allowed=new Set((process.env.ALLOWED_ORIGINS||'chrome-extension://').split(','));
const upstreams={scash:{host:process.env.SCASH_HOST||'10.66.66.1',port:Number(process.env.SCASH_PORT||50001),serverName:'scash.gozero.trade'},shic:{host:process.env.SHIC_HOST||'10.66.66.1',port:Number(process.env.SHIC_PORT||50011),serverName:'shic.gozero.trade'}};
const server=http.createServer((req,res)=>{if(req.url==='/healthz'){res.writeHead(200,{'content-type':'text/plain'});res.end('ok\n');return}res.writeHead(404);res.end()});
const wss=new WebSocketServer({noServer:true,maxPayload:64*1024});
server.on('upgrade',(req,socket,head)=>{const m=/^\/electrum\/(scash|shic)$/.exec(req.url||'');const origin=req.headers.origin||'';const originOK=[...allowed].some(x=>x.endsWith('://')?origin.startsWith(x):origin===x);if(!m||!originOK){socket.destroy();return}wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws,m[1]));});
wss.on('connection',(ws,coin)=>{const up=upstreams[coin];const tcp=tls.connect({host:up.host,port:up.port,servername:up.serverName,rejectUnauthorized:true},()=>{});tcp.setEncoding('utf8');let buf='';tcp.on('data',chunk=>{buf+=chunk;for(;;){const i=buf.indexOf('\n');if(i<0)break;const line=buf.slice(0,i);buf=buf.slice(i+1);if(line)ws.send(line)}});const close=()=>{if(!tcp.destroyed)tcp.destroy();if(ws.readyState===ws.OPEN)ws.close()};tcp.on('error',close);tcp.on('close',close);ws.on('message',raw=>{const s=raw.toString();if(s.length>65536||!/^\s*\{/.test(s))return;tcp.write(s.endsWith('\n')?s:s+'\n')});ws.on('close',()=>tcp.destroy());});
server.listen(port,'127.0.0.1',()=>console.log(`GOwallet Electrum WSS gateway on 127.0.0.1:${port}`));
