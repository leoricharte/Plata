/* GENERADO por `npm run motor` desde src/motor/. No lo edites: tus cambios se pierden. */
var Motor = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // app/src/motor/index.mjs
  var index_exports = {};
  __export(index_exports, {
    MAXAMT: () => MAXAMT,
    addDays: () => addDays,
    addMonths: () => addMonths,
    clampAmt: () => clampAmt,
    isQ: () => isQ,
    iso: () => iso,
    nextRep: () => nextRep,
    pad: () => pad,
    pd: () => pd,
    qDays: () => qDays,
    qMake: () => qMake,
    qNext: () => qNext,
    repN: () => repN,
    round2: () => round2,
    sum: () => sum
  });

  // app/src/motor/numeros.mjs
  var round2 = (n) => Math.round(n * 100) / 100;
  var MAXAMT = 999999999;
  var clampAmt = (n) => typeof n === "number" && isFinite(n) ? Math.max(-MAXAMT, Math.min(MAXAMT, n)) : typeof n === "number" ? 0 : n;
  var sum = (a, f) => a.reduce((s, x) => s + f(x), 0);

  // app/src/motor/fechas.mjs
  var pad = (n) => String(n).padStart(2, "0");
  var iso = (d) => d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  var pd = (s) => {
    const p = String(s).split("-").map(Number);
    return new Date(p[0], p[1] - 1, p[2]);
  };
  var addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  var addMonths = (d, n) => new Date(d.getFullYear(), d.getMonth() + n, 1);

  // app/src/motor/repeticiones.mjs
  var isQ = (r) => typeof r === "string" && r.charAt(0) === "q";
  var qDays = (r) => {
    const m = String(r).match(/^q(\d+),(\d+)$/);
    const c = (n) => Math.min(31, Math.max(1, Math.round(n) || 1));
    const a = c(m ? +m[1] : 15), b = c(m ? +m[2] : 30);
    return a <= b ? [a, b] : [b, a];
  };
  var qMake = (a, b) => {
    const x = qDays("q" + a + "," + b);
    return "q" + x[0] + "," + x[1];
  };
  var repN = (v) => v === "m" || isQ(v) ? v : Number(v) || 0;
  function qNext(d, r, incl) {
    const dd = qDays(r), y = d.getFullYear(), m = d.getMonth(), last = new Date(y, m + 1, 0).getDate();
    for (let i = 0; i < 2; i++) {
      const x = Math.min(dd[i], last);
      if (incl ? x >= d.getDate() : x > d.getDate()) return new Date(y, m, x);
    }
    const l2 = new Date(y, m + 2, 0).getDate();
    return new Date(y, m + 1, Math.min(dd[0], l2));
  }
  function nextRep(d, rep) {
    if (isQ(rep)) return qNext(d, rep, false);
    if (rep === "m") {
      const y = d.getFullYear(), m = d.getMonth() + 1, last = new Date(y, m + 1, 0).getDate();
      return new Date(y, m, Math.min(d.getDate(), last));
    }
    return addDays(d, Number(rep) || 7);
  }
  return __toCommonJS(index_exports);
})();
