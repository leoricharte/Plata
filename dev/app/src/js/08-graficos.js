/* ---------- Gráficos (SVG) ---------- */
function ringArcs(items, R, sw, gap) {
  const total = items.reduce((s, i) => s + i.v, 0) || 1, C = 2 * Math.PI * R;
  let cum = 0;
  return items.map((it) => {
    const share = it.v / total;
    const dash = Math.max(1, C * share - gap - sw);
    const off = -(cum * C + (gap + sw) / 2);
    cum += share;
    return { color: it.color, dash: dash.toFixed(1), off: off.toFixed(1) };
  });
}
function ringSVG(items, R, sw, gap, size, center, extra) {
  const cx = size / 2;
  const arcs = ringArcs(items, R, sw, gap).map((a) => '<circle cx="' + cx + '" cy="' + cx + '" r="' + R + '" fill="none" stroke="' + a.color + '" stroke-width="' + sw + '" stroke-linecap="round" stroke-dasharray="' + a.dash + ' 2000" stroke-dashoffset="' + a.off + '" transform="rotate(-90 ' + cx + ' ' + cx + ')"/>').join('');
  return '<svg viewBox="0 0 ' + size + ' ' + size + '" style="width:100%;height:auto;font-family:inherit" role="img" aria-label="Gráfico de anillo">' + (extra || '') + '<circle cx="' + cx + '" cy="' + cx + '" r="' + R + '" fill="none" stroke="#F3F3F5" stroke-width="' + sw + '"/>' + arcs + center + '</svg>';
}
function barsSVG(months) {
  const W = 334, H = 204, plotTop = 10, plotBot = 172, plotH = plotBot - plotTop, plotW = 282;
  const maxV = Math.max.apply(null, months.map((m) => Math.max(m.income, m.expense)).concat([1]));
  const yMax = Math.max(500, Math.ceil(maxV / 500) * 500);
  const yy = (v) => plotBot - (v / yMax) * plotH;
  let g = '';
  [0, yMax / 2, yMax].forEach((v) => {
    g += '<line x1="0" y1="' + yy(v) + '" x2="' + plotW + '" y2="' + yy(v) + '" stroke="' + (v === 0 ? '#D1D1D6' : '#E5E5EA') + '"/>' +
      '<text x="' + W + '" y="' + (yy(v) + 4) + '" text-anchor="end" font-size="13" fill="#6C6C70">' + axis(v) + '</text>';
  });
  const gw = plotW / months.length;
  months.forEach((m, i) => {
    const x0 = i * gw + (gw - 29) / 2;
    const he = Math.max(m.expense > 0 ? 3 : 0, (m.expense / yMax) * plotH), hi = Math.max(m.income > 0 ? 3 : 0, (m.income / yMax) * plotH);
    g += '<rect x="' + x0 + '" y="' + (plotBot - he) + '" width="13" height="' + he + '" rx="4" fill="#EDB03E"/>' +
      '<rect x="' + (x0 + 16) + '" y="' + (plotBot - hi) + '" width="13" height="' + hi + '" rx="4" fill="#6D8BEA"/>' +
      '<text x="' + (i * gw + gw / 2) + '" y="196" text-anchor="middle" font-size="13" fill="' + (m.cur ? '#1C1C1E' : '#6C6C70') + '" font-weight="' + (m.cur ? 600 : 400) + '">' + m.label + '</text>';
  });
  return '<svg viewBox="0 0 ' + W + ' ' + H + '" style="width:100%;height:auto;font-family:inherit" role="img" aria-label="Ingresos y gastos por mes">' + g + '</svg>';
}
function valAt(series, w) {
  const i = Math.min(series.length - 2, Math.max(0, Math.floor(w))), f = Math.min(1, Math.max(0, w - i));
  return series[i].v + (series[i + 1].v - series[i].v) * f;
}
function dateAt(series, w) {
  const i = Math.min(series.length - 2, Math.max(0, Math.floor(w))), f = Math.min(1, Math.max(0, w - i));
  return new Date(series[i].date.getTime() + (series[i + 1].date.getTime() - series[i].date.getTime()) * f);
}
function projSVG(series, sel) {
  const W = 334, x0 = 4, x1 = 288, top = 10, bot = 190, h = bot - top;
  const vals = series.map((s) => s.v);
  const maxV = Math.max.apply(null, vals), minV = Math.min.apply(null, vals);
  const hi = Math.max(1000, Math.ceil((maxV + 1) / 500) * 500);
  const lo = minV < 0 ? Math.floor(minV / 500) * 500 : 0;
  let step = hi - lo <= 2500 ? 500 : 1000;
  if ((hi - lo) / step > 12) { const raw = (hi - lo) / 6, mag = Math.pow(10, Math.floor(Math.log10(raw))); step = [1, 2, 5, 10].map((m) => m * mag).find((x) => x >= raw); }
  const Y = (v) => top + ((hi - Math.max(lo, Math.min(hi, v))) / (hi - lo)) * h;
  const X = (i) => x0 + i * ((x1 - x0) / (series.length - 1));
  let g = '';
  if (lo < 0) g += '<rect x="0" y="' + Y(0) + '" width="' + x1 + '" height="' + (Y(lo) - Y(0)) + '" fill="#FF3B30" fill-opacity=".1"/>';
  for (let v = lo, guard = 0; v <= hi && guard < 40; v += step, guard++) {
    g += '<line x1="0" y1="' + Y(v) + '" x2="' + x1 + '" y2="' + Y(v) + '" stroke="' + (v === 0 ? '#8E8E93' : '#E5E5EA') + '"' + (v === 0 ? ' stroke-dasharray="4 4"' : '') + '/>' +
      '<text x="' + W + '" y="' + (Y(v) + 4) + '" text-anchor="end" font-size="13" fill="#6C6C70">' + axis(v) + '</text>';
  }
  if (lo < 0) g += '<text x="' + (x1 - 6) + '" y="' + (Y(lo) - 6) + '" text-anchor="end" font-size="12" fill="var(--rt)">zona en rojo</text>';
  const pts = series.map((s, i) => X(i).toFixed(1) + ',' + Y(s.v).toFixed(1)).join(' ');
  const cur = { v: valAt(series, sel) };
  g += '<line x1="' + X(sel) + '" y1="' + top + '" x2="' + X(sel) + '" y2="' + bot + '" stroke="#8E8E93" stroke-dasharray="3 3"/>' +
    '<polyline points="' + pts + '" fill="none" stroke="#1A9D63" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>' +
    '<circle cx="' + X(sel) + '" cy="' + Y(cur.v) + '" r="7" fill="var(--card)" stroke="' + (cur.v < 0 ? '#FF3B30' : '#1A9D63') + '" stroke-width="3.5"/>';
  return '<svg viewBox="0 0 ' + W + ' 200" style="width:100%;height:auto;font-family:inherit" role="img" aria-label="Proyección semanal del balance">' + g + '</svg>';
}

