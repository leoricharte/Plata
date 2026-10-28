#!/usr/bin/env node
// Genera lo que Swift necesita para igualar el cifrado de Plata Cloud (PCC en dev/app/src/app.html) ejecutando el código REAL de la web:
//   Tests/.../Fixtures/cloud.json — los datos de la aprobación de dispositivos (claves P-256, compromiso, código de 6 dígitos y semilla cifrada).
//   (La frase, las claves derivadas y las copias cifradas ya las cubren CryptoTests y los vectores de gen-vectors.mjs.)
//
//   node swift/tools/gen-cloud.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const html = readFileSync(join(root, 'dev/app/src/app.html'), 'utf8');
const i0 = html.indexOf('const PCC = (() => {'), i1 = html.indexOf('\n})();', i0) + 6;
const PCC = new Function(html.slice(i0, i1) + '\nreturn PCC;')();
const S = globalThis.crypto.subtle, enc = new TextEncoder();
const hex = (u) => Buffer.from(u).toString('hex');
const unhex = (h) => new Uint8Array(Buffer.from(h, 'hex'));

const seeds = ['a1b2c3d4e5f60718293a4b5c6d7e8f90'];
const fx = { link: {} };
// aprobación de dispositivos
const EC = { name: 'ECDH', namedCurve: 'P-256' };
const kpA = await S.generateKey(EC, true, ['deriveKey']), kpN = await S.generateKey(EC, true, ['deriveKey']);
const rawPub = async (k) => PCC.b64u(new Uint8Array(await S.exportKey('raw', k.publicKey)));
const pkcs8 = async (k) => PCC.b64u(new Uint8Array(await S.exportKey('pkcs8', k.privateKey)));
const apub = await rawPub(kpA), npub = await rawPub(kpN), seed = unhex(seeds[0]);
const sealed = await PCC.linkSeal(kpA.privateKey, npub, seed);
const h64 = (t) => PCC.b64u(new Uint8Array(createHash('sha256').update(t).digest()));
fx.link = {
  apub, npub, aPriv: await pkcs8(kpA), nPriv: await pkcs8(kpN), seed: hex(seed), iv: sealed.iv, ct: sealed.ct,
  na: PCC.rnd(16), nn: PCC.rnd(16),
};
fx.link.commit = h64('plata-commit1|' + apub + '|' + fx.link.na);
fx.link.verifyOk = await PCC.linkVerify(fx.link.commit, apub, fx.link.na);
fx.link.verifyBad = await PCC.linkVerify(fx.link.commit, apub, fx.link.nn);
fx.link.code = await PCC.linkCode(npub, apub, fx.link.na, fx.link.nn);
const opened = await PCC.linkOpen(kpN.privateKey, apub, sealed.iv, sealed.ct);
if (hex(opened) !== hex(seed)) throw new Error('linkOpen no devuelve la semilla');

const dir = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures');
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, 'cloud.json'), JSON.stringify(fx, null, 1));
console.log('cloud.json listo · código', fx.link.code);
