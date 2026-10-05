#!/usr/bin/env node

/**
 * 9Router Patcher - Fixes known bugs in 9Router on macOS/Linux/Windows:
 * 1. Missing mitm directory when creating .mitm.lock (ENOENT)
 * 2. killAllAppProcesses killing its own parent sudo process (Connection reset by peer)
 * 3. Bypasses sudo -S when running as root (preventing empty password failure)
 * 4. Bypasses sudo in DNS helper functions when running as root
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('\x1b[36m%s\x1b[0m', '🔧 [9Router Patcher] Đang kiểm tra vị trí cài đặt 9Router...');

function find9RouterDir() {
  const possiblePaths = [];

  // Try which 9router
  try {
    const whichOut = execSync(process.platform === 'win32' ? 'where 9router' : 'which 9router', { encoding: 'utf8' }).trim();
    if (whichOut) {
      const binPath = whichOut.split('\n')[0].trim();
      let realPath = binPath;
      try {
        realPath = fs.realpathSync(binPath);
      } catch (e) {}

      // If pointing to cli.js, parent is 9router root
      if (realPath.endsWith('cli.js')) {
        possiblePaths.push(path.dirname(realPath));
      }
    }
  } catch (e) {}

  // Check npm root -g
  try {
    const npmRoot = execSync('npm root -g', { encoding: 'utf8' }).trim();
    if (npmRoot) {
      possiblePaths.push(path.join(npmRoot, '9router'));
    }
  } catch (e) {}

  // Common NVM and system paths
  if (process.env.HOME) {
    possiblePaths.push(
      path.join(process.env.HOME, '.nvm', 'versions', 'node', process.version, 'lib', 'node_modules', '9router'),
      '/usr/local/lib/node_modules/9router',
      '/opt/homebrew/lib/node_modules/9router'
    );
  }

  if (process.env.APPDATA) {
    possiblePaths.push(path.join(process.env.APPDATA, 'npm', 'node_modules', '9router'));
  }

  for (const p of possiblePaths) {
    if (fs.existsSync(path.join(p, 'cli.js'))) {
      return p;
    }
  }

  return null;
}

const routerDir = find9RouterDir();
if (!routerDir) {
  console.error('\x1b[31m%s\x1b[0m', '❌ Không tìm thấy thư mục cài đặt 9router! Hãy đảm bảo bạn đã chạy: npm install -g 9router');
  process.exit(1);
}

console.log('\x1b[32m%s\x1b[0m', `✅ Tìm thấy 9Router tại: ${routerDir}`);

let patchedCount = 0;

// 1. Patch cli.js (Prevent kill parent sudo process)
const cliPath = path.join(routerDir, 'cli.js');
if (fs.existsSync(cliPath)) {
  let cliContent = fs.readFileSync(cliPath, 'utf8');
  let changed = false;

  // Add sudo skip & ppid skip
  if (!cliContent.includes('cmd.includes("sudo")') && cliContent.includes('lines.forEach(line => {')) {
    const target = 'const isAppProcess =\n              (cmd.includes("node") && cmd.includes("9router") && (cmd.includes("cli.js") || cmd.includes("/9router")))\n              || cmd.includes("next-server");\n            if (isAppProcess) {\n              const parts = line.trim().split(/\\s+/);\n              const pid = parts[1];\n              if (pid && !isNaN(pid) && pid !== process.pid.toString()) {\n                pids.push(pid);\n              }';
    const repl = 'if (cmd.includes("sudo")) return;\n            const isAppProcess =\n              (cmd.includes("node") && cmd.includes("9router") && (cmd.includes("cli.js") || cmd.includes("/9router")))\n              || cmd.includes("next-server");\n            if (isAppProcess) {\n              const parts = line.trim().split(/\\s+/);\n              const pid = parts[1];\n              if (pid && !isNaN(pid) && pid !== process.pid.toString() && pid !== process.ppid.toString()) {\n                pids.push(pid);\n              }';
    if (cliContent.includes(target)) {
      cliContent = cliContent.replace(target, repl);
      changed = true;
    }
  }

  if (changed) {
    fs.writeFileSync(cliPath, cliContent, 'utf8');
    console.log('\x1b[32m%s\x1b[0m', '  ✔ [Vá lỗi 1] Đã sửa cli.js: Chặn 9router tự ngắt tiến trình sudo cha');
    patchedCount++;
  } else {
    console.log('\x1b[33m%s\x1b[0m', '  - [Vá lỗi 1] cli.js đã được vá từ trước hoặc không cần sửa.');
  }
}

// 2. Patch chunk 915.js (MITM server logic)
const chunk915Path = path.join(routerDir, 'app', '.next-cli-build', 'server', 'chunks', '915.js');
if (fs.existsSync(chunk915Path)) {
  let c915 = fs.readFileSync(chunk915Path, 'utf8');
  let changed = false;

  // Patch mitm.lock mkdirSync
  const targetLock = 'try{h.writeFileSync(K,String(process.pid),{flag:"wx"})}';
  const replLock = 'try{h.mkdirSync(C,{recursive:!0}),h.writeFileSync(K,String(process.pid),{flag:"wx"})}';
  if (c915.includes(targetLock)) {
    c915 = c915.replace(targetLock, replLock);
    changed = true;
    console.log('\x1b[32m%s\x1b[0m', '  ✔ [Vá lỗi 2] Đã sửa 915.js: Tự tạo thư mục mitm trước khi tạo lock file');
    patchedCount++;
  }

  // Patch isSudoPasswordRequired
  const targetSudoReq = 'isSudoPasswordRequired:function(){return!o&&r()&&!s()}';
  const replSudoReq = 'isSudoPasswordRequired:function(){return!o&&("function"!=typeof process.getuid||0!==process.getuid())}';
  if (c915.includes(targetSudoReq)) {
    c915 = c915.replace(targetSudoReq, replSudoReq);
    changed = true;
    console.log('\x1b[32m%s\x1b[0m', '  ✔ [Vá lỗi 3] Đã sửa 915.js: Kiểm tra mật khẩu sudo chính xác theo user ID');
    patchedCount++;
  }

  // Patch bypass sudo when running as root
  const targetSpawnSudo = 'else if(s()){let c=[`HOME=${H(i.homedir())}`';
  const replSpawnSudo = 'else if(s()&&("function"!=typeof process.getuid||0!==process.getuid())){if(!b||!b.trim()){throw Error("Sudo password is required to start MITM server");}let c=[`HOME=${H(i.homedir())}`';
  if (c915.includes(targetSpawnSudo)) {
    c915 = c915.replace(targetSpawnSudo, replSpawnSudo);
    changed = true;
    console.log('\x1b[32m%s\x1b[0m', '  ✔ [Vá lỗi 4] Đã sửa 915.js: Bỏ qua sudo khi đã chạy dưới quyền root');
    patchedCount++;
  }

  // Patch module 66936 r()
  const targetR = 'function r(){if(o)return!1;try{return f("command -v sudo",{stdio:"ignore",windowsHide:!0}),!0}catch{return!1}}';
  const replR = 'function r(){if(o||("function"==typeof process.getuid&&0===process.getuid()))return!1;try{return f("command -v sudo",{stdio:"ignore",windowsHide:!0}),!0}catch{return!1}}';
  if (c915.includes(targetR)) {
    c915 = c915.replace(targetR, replR);
    changed = true;
    console.log('\x1b[32m%s\x1b[0m', '  ✔ [Vá lỗi 5] Đã sửa 915.js: Cho phép root sửa file hosts và flush DNS trực tiếp');
    patchedCount++;
  }

  if (changed) {
    fs.writeFileSync(chunk915Path, c915, 'utf8');
  }
}

console.log('\x1b[36m%s\x1b[0m', `🎉 Hoàn tất vá lỗi 9Router (${patchedCount} bản vá đã áp dụng).`);
