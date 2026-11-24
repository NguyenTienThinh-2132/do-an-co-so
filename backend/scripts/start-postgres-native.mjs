// Creates a NEW native PostgreSQL cluster for this project on D:, never resets an existing admin.
import { randomBytes,randomUUID } from 'node:crypto';
import { existsSync,readFileSync,writeFileSync,mkdirSync,unlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { resolve,dirname,join,isAbsolute } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createConnection } from 'node:net';
import pg from 'pg';
const backend=fileURLToPath(new URL('../',import.meta.url));
const configPath=join(backend,'.env.native-cluster.json');
let config;
function command(file,args,quiet=false){
 const result=spawnSync(file,args,{cwd:backend,windowsHide:true,stdio:quiet?'ignore':'inherit',timeout:90000});
 if(result.error||result.status!==0)throw new Error('Native PostgreSQL command failed');
}
async function portUsed(port){return new Promise(res=>{
 const socket=createConnection({host:'127.0.0.1',port});
 const finish=v=>{socket.destroy();res(v);};socket.once('connect',()=>finish(true));socket.once('error',()=>finish(false));socket.setTimeout(1500,()=>finish(false));
});}
function readAppUrl(){
 const file=join(backend,'.env');if(!existsSync(file))return null;
 const match=readFileSync(file,'utf8').match(/^DATABASE_URL=(.+)$/m);if(!match)return null;
 try{return new URL(match[1].trim());}catch{return null;}
}
async function appReady(){
 const url=readAppUrl();if(!url||url.hostname!=='127.0.0.1'||url.port!==String(config.port)||url.pathname!=='/finai_tv3_demo'||decodeURIComponent(url.username)!=='finai_app')return false;
 const client=new pg.Client({connectionString:url.toString(),connectionTimeoutMillis:5000});
 try{await client.connect();await client.query('SELECT 1');return true;}catch{return false;}finally{await client.end().catch(()=>{});}
}
try {
 if(existsSync(configPath)){
  config=JSON.parse(readFileSync(configPath,'utf8'));
  if(config.version!==1||config.port!==5433||!isAbsolute(config.dataDirectory)||config.adminUser!=='finai_admin')throw new Error('Unexpected native cluster config');
  const marker=JSON.parse(readFileSync(join(dirname(config.dataDirectory),'finai-cluster.json'),'utf8'));
  if(marker.clusterId!==config.clusterId||resolve(marker.dataDirectory)!==resolve(config.dataDirectory))throw new Error('Cluster identity mismatch');
 } else {
  const dataDirectory=resolve('D:/FinAIData/postgres18');
  const markerPath=join(dirname(dataDirectory),'finai-cluster.json');
  if(existsSync(dataDirectory)||existsSync(markerPath))throw new Error('Existing data path; refusing initialization');
  if(await portUsed(5433))throw new Error('Local port already in use');
  config={version:1,clusterId:randomUUID(),binDirectory:resolve(process.env.FINAI_PG_BIN||'D:/PostgreSQL/pgsql/bin'),dataDirectory,port:5433,adminUser:'finai_admin',adminPassword:randomBytes(32).toString('hex')};
  if(!existsSync(join(config.binDirectory,'initdb.exe')))throw new Error('Missing native PostgreSQL binaries');
  mkdirSync(dirname(dataDirectory),{recursive:true});
  writeFileSync(configPath,JSON.stringify(config,null,2),{flag:'wx',mode:0o600});
  writeFileSync(markerPath,JSON.stringify({clusterId:config.clusterId,dataDirectory}),{flag:'wx'});
 }
 const versionPath=join(config.dataDirectory,'PG_VERSION');
 if(!existsSync(versionPath)){
  if(existsSync(config.dataDirectory))throw new Error('Partial cluster directory exists; requires review');
  const passwordFile=join(backend,'.env.native-init-password-'+Date.now());
  writeFileSync(passwordFile,config.adminPassword+'\n',{flag:'wx',mode:0o600});
  try{command(join(config.binDirectory,'initdb.exe'),['-D',config.dataDirectory,'-U',config.adminUser,'--pwfile='+passwordFile,'--auth-local=scram-sha-256','--auth-host=scram-sha-256','--encoding=UTF8','--locale=C']);}
  finally{unlinkSync(passwordFile);}
 }
 if(readFileSync(versionPath,'utf8').trim()!=='18')throw new Error('Unexpected PostgreSQL major version');
 const status=spawnSync(join(config.binDirectory,'pg_ctl.exe'),['status','-D',config.dataDirectory],{windowsHide:true,stdio:'ignore'});
 if(status.status!==0){
  if(await portUsed(config.port))throw new Error('Port belongs to another server');
  command(join(config.binDirectory,'pg_ctl.exe'),['start','-D',config.dataDirectory,'-l',join(dirname(config.dataDirectory),'postgresql.log'),'-o',`-h 127.0.0.1 -p ${config.port}`,'-w','-t','30']);
 }
 const admin=new pg.Client({host:'127.0.0.1',port:config.port,user:config.adminUser,password:config.adminPassword,database:'postgres',connectionTimeoutMillis:5000});
 try{
  await admin.connect();const r=await admin.query('SHOW data_directory');
  if(resolve(r.rows[0].data_directory).toLowerCase()!==resolve(config.dataDirectory).toLowerCase())throw new Error('Unexpected server directory');
 }finally{await admin.end().catch(()=>{});}
 if(!await appReady()){
  const child=spawnSync(process.execPath,[join(backend,'scripts','setup-postgres-local.mjs')],{cwd:backend,windowsHide:true,stdio:'inherit',env:{...process.env,FINAI_ADMIN_USER:config.adminUser,FINAI_ADMIN_PASSWORD:config.adminPassword,FINAI_ADMIN_PORT:String(config.port)},timeout:30000});
  if(child.error||child.status!==0)throw new Error('FinAI database setup incomplete');
 }
 console.log('PASS: PostgreSQL trực tiếp của FinAI đang chạy tại 127.0.0.1:5433, data ở D:/FinAIData/postgres18.');
 console.log('Tài khoản app đã đăng nhập được. Không dùng Docker; dữ liệu/mật khẩu cluster 5432 giữ nguyên.');
}catch{
 console.error('Chưa hoàn tất PostgreSQL native. Dừng để giữ dữ liệu/cấu hình; xem trạng thái và log local, không reset hoặc xóa cluster hiện có.');process.exitCode=1;
}
