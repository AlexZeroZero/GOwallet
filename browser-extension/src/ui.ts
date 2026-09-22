import { COINS, type CoinId } from './coins.js';
import { derive, newMnemonic, validMnemonic } from './wallet.js';
import { saveVault, loadVault, hasVault } from './vault.js';
import { ElectrumClient } from './electrum.js';
import { formatAmount } from './encoding.js';

let mnemonic = '';
let selected: CoinId = 'scash';
let client: ElectrumClient | undefined;
const $ = <T extends HTMLElement>(selector: string) => document.querySelector<T>(selector)!;
const english = () => localStorage.getItem('lang') === 'en';
const t = (zh: string, en: string) => english() ? en : zh;

function header() {
  return `<header class="topbar"><div class="brand"><img src="../assets/logo.svg" alt="GOwallet"><span>GOwallet</span></div><button class="language" id="language">${english() ? '中文' : 'EN'}</button></header>`;
}
function footer() {
  return `<footer><span><b class="footer-dot"></b>${t('非托管 · 本地密钥', 'Non-custodial · Local keys')}</span><a href="https://github.com/AlexZeroZero/GOwallet" target="_blank">${t('开源代码', 'Source')}</a></footer>`;
}
function frame(content: string) {
  document.documentElement.lang = english() ? 'en' : 'zh-CN';
  document.body.innerHTML = `<main class="shell">${header()}<section id="content">${content}</section>${footer()}</main>`;
  $('#language').onclick = () => { localStorage.setItem('lang', english() ? 'zh' : 'en'); render(); };
}
function render() { frame(''); showHome(); }

async function showHome() {
  const content = $('#content');
  if (!mnemonic) {
    content.innerHTML = `<div class="welcome card"><div class="welcome-mark"><span>G</span><i></i></div><div class="eyebrow">GOWALLET · POW ASSETS</div><h1>${t('你的资产，你掌握', 'Your assets, your keys')}</h1><p>${t('轻量、非托管的多币种浏览器钱包', 'A compact, non-custodial wallet for PoW coins')}</p><div class="welcome-actions"><button class="button primary" id="create"><span>＋</span>${t('创建新钱包', 'Create wallet')}</button><button class="button secondary" id="restore">${t('恢复已有钱包', 'Restore wallet')}<span>›</span></button></div><div class="security-note"><span>✦</span>${t('助记词仅在本机生成和加密保存', 'Your seed is generated and encrypted locally')}</div></div>`;
    $('#create').onclick = () => setup(newMnemonic()); $('#restore').onclick = () => setup(''); return;
  }
  const coin = COINS[selected];
  content.innerHTML = `<div class="wallet-head"><div><div class="eyebrow">${t('钱包资产', 'WALLET ASSETS')}</div><h1>${t('我的资产', 'My assets')}</h1></div><button class="icon-button" id="lock" title="${t('锁定钱包', 'Lock wallet')}">⌁</button></div><nav class="coin-list" aria-label="Coins">${Object.values(COINS).map(x => `<button class="coin ${x.id === selected ? 'active' : ''}" data-coin="${x.id}"><i style="background:${x.color}">${x.ticker[0]}</i><span>${x.ticker}</span>${x.id === selected ? '<b>✓</b>' : ''}</button>`).join('')}</nav><article class="asset-card card"><div class="asset-title"><div class="coin-heading"><i style="background:${coin.color}">${coin.ticker[0]}</i><div><strong>${coin.name}</strong><small>${coin.ticker} · ${t('主网', 'Mainnet')}</small></div></div><span class="status" id="node-status"><b></b>${t('检查节点', 'Checking')}</span></div><div class="balance-label">${t('可用余额', 'Available balance')}</div><div class="balance" id="balance">— <small>${coin.ticker}</small></div><div class="address-label"><span>${t('收款地址', 'Receive address')}</span><button class="copy-button" id="copy">${t('复制', 'Copy')}</button></div><div class="address" id="address"></div><div class="actions"><button class="button primary" id="receive"><span>↓</span>${t('收款', 'Receive')}</button><button class="button secondary" id="send"><span>↑</span>${t('发送', 'Send')}</button></div></article><div class="compact-notice"><span>ⓘ</span>${t('节点由币种项目或第三方独立运营，故障不改变链上资产归属。', 'Nodes are independently operated; outages do not change on-chain ownership.')}</div>`;
  document.querySelectorAll<HTMLButtonElement>('[data-coin]').forEach(button => button.onclick = () => { selected = button.dataset.coin as CoinId; showHome(); });
  $('#lock').onclick = () => { client?.close(); mnemonic = ''; showHome(); };
  const copy = async () => { try { await navigator.clipboard.writeText($('#address').textContent || ''); $('#copy').textContent = t('已复制', 'Copied'); setTimeout(() => { if ($('#copy')) $('#copy').textContent = t('复制', 'Copy'); }, 1600); } catch { /* clipboard permission is optional */ } };
  $('#copy').onclick = copy; $('#receive').onclick = copy;
  $('#send').onclick = () => alert(t('发送交易将在网关和签名回归测试完成后开放。', 'Sending will open after gateway and signing regression tests pass.'));
  refresh();
}

async function refresh() {
  const coin = COINS[selected]; const derived = derive(mnemonic, coin); $('#address').textContent = derived.address;
  try { client?.close(); client = new ElectrumClient(coin.node); await client.verify(coin); const balance = await client.balance(derived.scriptHash); $('#balance').innerHTML = `${formatAmount(BigInt(balance.confirmed), coin.decimals)} <small>${coin.ticker}</small>`; $('#node-status').innerHTML = `<b class="online"></b>${t('节点在线', 'Node online')}`; }
  catch { $('#balance').innerHTML = `— <small>${coin.ticker}</small>`; $('#node-status').innerHTML = `<b></b>${t('节点未连接', 'Node offline')}`; }
}

function setup(initial: string) {
  frame(`<div class="form-page"><button class="back-button" id="back">‹ <span>${t('返回', 'Back')}</span></button><div class="form card"><div class="form-icon">${initial ? '✦' : '↺'}</div><div class="eyebrow">${initial ? t('新钱包', 'NEW WALLET') : t('恢复钱包', 'RESTORE WALLET')}</div><h1>${initial ? t('设置钱包密码', 'Set wallet password') : t('恢复已有钱包', 'Restore wallet')}</h1><p class="form-lead">${initial ? t('密码用于保护本机钱包数据，不能找回助记词。', 'This password protects local data and cannot recover a lost seed.') : t('输入 12 个英文助记词，恢复本机钱包。', 'Enter your 12-word English seed to restore the wallet.')}</p>${initial ? `<div class="seed-box"><span>${t('请离线抄写并妥善保存', 'Write down and store offline')}</span><code>${initial}</code></div>` : '<textarea id="mnemonic" placeholder="输入 12 个英文助记词"></textarea>'}<label>${t('钱包密码', 'Wallet password')}<input id="password" type="password" minlength="12" placeholder="${t('至少 12 位字符', 'At least 12 characters')}"></label><button class="button primary full" id="save">${t('保存并进入', 'Save and continue')} <span>→</span></button><p class="error" id="error"></p></div></div>`);
  $('#back').onclick = () => render(); $('#save').onclick = async () => { const words = initial || $<HTMLTextAreaElement>('#mnemonic').value.trim(); const password = $<HTMLInputElement>('#password').value; if (!validMnemonic(words) || password.length < 12) { $('#error').textContent = t('请检查助记词和密码（密码至少 12 位）', 'Check your seed and password (12+ characters)'); return; } await saveVault(words, password); mnemonic = words; render(); showHome(); };
}

async function boot() {
  if (await hasVault()) { frame(`<div class="unlock-page"><div class="unlock-mark"><span>G</span><i></i></div><div class="eyebrow">GOWALLET</div><h1>${t('欢迎回来', 'Welcome back')}</h1><p>${t('输入密码解锁本机钱包', 'Enter your password to unlock')}</p><div class="unlock-card card"><label>${t('钱包密码', 'Wallet password')}<input id="password" type="password" placeholder="••••••••••••"></label><button class="button primary full" id="unlock">${t('解锁钱包', 'Unlock wallet')} <span>→</span></button><p class="error" id="error"></p></div><button class="text-button" id="reset-view">${t('使用其他钱包', 'Use another wallet')}</button></div>`); $('#unlock').onclick = async () => { try { mnemonic = await loadVault($<HTMLInputElement>('#password').value) || ''; render(); showHome(); } catch { $('#error').textContent = t('密码错误，请重试', 'Wrong password, try again'); } }; $('#reset-view').onclick = () => { mnemonic = ''; showHome(); }; } else render();
}
boot();
