/* ---------- Nazca · pasarela por banco ----------
 * Un lector por banco y tipo de estado de cuenta. Nazca reconoce el banco por el CONTENIDO del archivo (no por su nombre) y usa el lector que
 * corresponde. Si ninguno lo reconoce, la pantalla lo dice y deja elegir el banco a mano o usar el lector genérico de CSV.
 * Un banco solo pasa a "activo" cuando hay un lector probado con un estado de cuenta real de ese banco (con los datos cambiados en las pruebas).
 * Para agregar un banco: archivo nuevo en esta carpeta con detect(doc) y read(doc), lo agregas a READERS y lo marcas activo en CATALOG. */
const NazcaBancos = (() => {
  const READERS = [typeof NazcaBCP !== 'undefined' ? NazcaBCP : require('./bcp-ahorros.js'), typeof NazcaInterbank !== 'undefined' ? NazcaInterbank : require('./interbank-ahorros.js'), typeof NazcaCapitalOne !== 'undefined' ? NazcaCapitalOne : require('./capitalone-tarjeta.js'), typeof NazcaChime !== 'undefined' ? NazcaChime : require('./chime-checking.js'), typeof NazcaSeen !== 'undefined' ? NazcaSeen : require('./seen-tarjeta.js'), typeof NazcaBofA !== 'undefined' ? NazcaBofA : require('./bofa-cheques.js'), typeof NazcaAppleCard !== 'undefined' ? NazcaAppleCard : require('./applecard-tarjeta.js'), typeof NazcaCommunityBank !== 'undefined' ? NazcaCommunityBank : require('./communitybank-cuenta.js'), typeof NazcaIO !== 'undefined' ? NazcaIO : require('./io-tarjeta.js'), typeof NazcaCapitalOneCuenta !== 'undefined' ? NazcaCapitalOneCuenta : require('./capitalone-cuenta.js'), typeof NazcaBBVA !== 'undefined' ? NazcaBBVA : require('./bbva-cuenta.js'), typeof NazcaInterbankTarjeta !== 'undefined' ? NazcaInterbankTarjeta : require('./interbank-tarjeta.js'), typeof NazcaBCPTarjeta !== 'undefined' ? NazcaBCPTarjeta : require('./bcp-tarjeta.js'), typeof NazcaMercadoPago !== 'undefined' ? NazcaMercadoPago : require('./mercadopago-cuenta.js'), typeof NazcaTJX !== 'undefined' ? NazcaTJX : require('./tjx-tarjeta.js'), typeof NazcaMilestone !== 'undefined' ? NazcaMilestone : require('./milestone-tarjeta.js')];
  /* Lo que se ve al elegir país y banco. active: hay lector. Los demás salen como "Próximamente". */
  const CATALOG = [
    { id: 'PE', name: 'Perú', banks: [
      { id: 'bcp', name: 'Banco de Crédito del Perú', hq: 'La Molina, Lima', active: true },
      { id: 'interbank', name: 'Interbank', hq: 'La Victoria, Lima', active: true },
      { id: 'io', name: 'iO', hq: 'La Molina, Lima', active: true },
    { id: 'yape', name: 'Yape', hq: 'La Molina, Lima', active: true },
      { id: 'bbva', name: 'BBVA Perú', hq: 'San Isidro, Lima', active: true },
      { id: 'scotiabank', name: 'Scotiabank Perú', hq: 'San Isidro, Lima', active: false } ] },
    { id: 'US', name: 'Estados Unidos', banks: [
      { id: 'capitalone', name: 'Capital One', hq: 'McLean, Virginia', active: true },
      { id: 'chime', name: 'Chime', hq: 'San Francisco, California', active: true },
      { id: 'seen', name: 'Seen', hq: 'Salt Lake City, Utah', active: true },
      { id: 'bofa', name: 'Bank of America', hq: 'Charlotte, North Carolina', active: true },
      { id: 'applecard', name: 'Apple Card', hq: 'Cupertino, California', active: true },
      { id: 'communitybank', name: 'Community Bank, N.A.', hq: 'Canton, New York', active: true },
      { id: 'tjx', name: 'TJX Rewards', hq: 'Framingham, Massachusetts', active: true },
      { id: 'milestone', name: 'Milestone', hq: 'Beaverton, Oregon', active: true } ] },
    { id: 'CL', name: 'Chile', banks: [
      { id: 'mercadopago', name: 'Mercado Pago', hq: 'Las Condes, Santiago', active: true } ] } ];
  CATALOG.forEach((c) => c.banks.sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) || a.name.localeCompare(b.name, 'es', { sensitivity: 'base' })));   /* los bancos de cada país en orden alfabético; los no disponibles, al final */
  /* Devuelve el lector que reconoce el documento (el resultado de NazcaPDF.read) o null. onlyBank: si la persona ya eligió un banco, solo prueba ese. */
  function detect(doc, onlyBank) {
    for (const r of READERS) if ((!onlyBank || r.bank === onlyBank) && r.detect(doc) >= 1) return r;
    return null;
  }
  /* Algunos bancos exportan un CSV con columnas propias: por las columnas se reconoce el banco (el mismo caso que en el PDF: se identifica por el contenido).
   * flip: ese CSV imprime las compras en positivo y los pagos en negativo; Plata los guarda al revés. */
  const CSV_SIGNATURES = [{ bank: 'applecard', kind: 'tarjeta', label: 'Apple Card · Tarjeta de crédito', cur: 'USD', flip: true, need: ['transaction date', 'clearing date', 'merchant', 'type', 'amount (usd)', 'purchased by'] }];
  function detectCsv(headers) {
    const h = (headers || []).map((x) => String(x).trim().toLowerCase());
    return CSV_SIGNATURES.find((sg) => sg.need.every((n) => h.indexOf(n) >= 0)) || null;
  }
  return { READERS, CATALOG, detect, detectCsv };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaBancos;
