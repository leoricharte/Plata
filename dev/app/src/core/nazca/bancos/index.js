/* ---------- Nazca · pasarela por banco ----------
 * Un lector por banco y tipo de estado de cuenta. Nazca reconoce el banco por el CONTENIDO del archivo (no por su nombre) y usa el lector que
 * corresponde. Si ninguno lo reconoce, la pantalla lo dice y deja elegir el banco a mano o usar el lector genérico de CSV.
 * Un banco solo pasa a "activo" cuando hay un lector probado con un estado de cuenta real de ese banco (con los datos cambiados en las pruebas).
 * Para agregar un banco: archivo nuevo en esta carpeta con detect(doc) y read(doc), lo agregas a READERS y lo marcas activo en CATALOG. */
const NazcaBancos = (() => {
  const READERS = [typeof NazcaBCP !== 'undefined' ? NazcaBCP : require('./bcp-ahorros.js'), typeof NazcaInterbank !== 'undefined' ? NazcaInterbank : require('./interbank-ahorros.js'), typeof NazcaCapitalOne !== 'undefined' ? NazcaCapitalOne : require('./capitalone-tarjeta.js'), typeof NazcaChime !== 'undefined' ? NazcaChime : require('./chime-checking.js')];
  /* Lo que se ve al elegir país y banco. active: hay lector. Los demás salen como "Próximamente". */
  const CATALOG = [
    { id: 'PE', name: 'Perú', banks: [
      { id: 'bcp', name: 'Banco de Crédito del Perú', hq: 'La Molina, Lima', active: true },
      { id: 'interbank', name: 'Interbank', hq: 'La Victoria, Lima', active: true },
      { id: 'bbva', name: 'BBVA Perú', hq: 'San Isidro, Lima', active: false },
      { id: 'scotiabank', name: 'Scotiabank Perú', hq: 'San Isidro, Lima', active: false } ] },
    { id: 'US', name: 'Estados Unidos', banks: [
      { id: 'capitalone', name: 'Capital One', hq: 'McLean, Virginia', active: true },
      { id: 'chime', name: 'Chime', hq: 'San Francisco, California', active: true } ] } ];
  /* Devuelve el lector que reconoce el documento (el resultado de NazcaPDF.read) o null. onlyBank: si la persona ya eligió un banco, solo prueba ese. */
  function detect(doc, onlyBank) {
    for (const r of READERS) if ((!onlyBank || r.bank === onlyBank) && r.detect(doc) >= 1) return r;
    return null;
  }
  return { READERS, CATALOG, detect };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaBancos;
