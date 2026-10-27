# Registro de cambios

## Beta 4 (en desarrollo)

- **Tutorial de primera vez (compilaciones 449–450):** al terminar la bienvenida, quien usa Plata por primera vez ve consejos de uno en uno, con un anillo verde sobre el botón clave y el fondo ligeramente atenuado. Cada consejo sale una sola vez, cuando llegas a esa parte (Cuentas, el +, el menú de añadir, la hoja de transacción, Presupuesto, Proyección y Ajustes), y «Omitir tutorial» siempre está a la vista. No aparece con datos de demostración ni con perfiles que ya existían. Se activa o se repite desde el interruptor «Tutorial» del perfil.
- **Inicio rápido en tu moneda (451):** el Inicio rápido ahora usa la moneda de tu zona (soles en Perú) en vez de dólares.
- **Recurrentes en Revisión (457):** Plata detecta, sumando todas tus cuentas, ingresos que se repiten (los propone como trabajo), cobros con ritmo y monto fijos de servicios conocidos (suscripción) y otros gastos regulares (gasto fijo). Nada se crea hasta que aceptas y se puede deshacer.
- **Revisión más limpia (454–456):** las sugerencias ahora son tarjetas en un carrusel con una pestaña por tipo (Transferencias, Pagos, Repetidos, Montos, Estados), con textos más cortos y la explicación en «¿Por qué?».
- **Plata para Windows (453):** la ventana de la app de escritorio ya no usa la barra gris de Windows: Plata dibuja la suya, transparente, con el fondo y el tema de la app, y el botón beta dice «Beta para Windows».
- **Nazca activo para todos (452):** la importación de estados de cuenta ya no depende de un interruptor oculto.
- **Cuatro tarjetas más (Estados Unidos, 438–448):** Capital One crédito (estados en inglés y en español, cuotas de membresía en la tabla Fees), TJX Rewards (Synchrony), Milestone Mastercard (Concora Credit) y ajustes a Apple Card («Daily Cash Adjustment») y Seen (descripciones partidas en tres líneas). Todos se probaron con estados reales y se comprueba que el saldo anterior, los movimientos y el saldo nuevo cuadren.
- **Bancos en orden alfabético (444–445):** en cada país, y con los no disponibles al final.
- **Estados sin movimientos (439):** un estado de cuenta que cuadra pero no tiene movimientos ya no es un error; Plata avisa «sin movimientos».
- **Foto de perfil (436–437):** editor de recorte (arrastrar y zoom). Tocar la foto abre el recorte y se guarda con el check.
- **Revisión (427–435):** panel al final de Cuentas que recorre lo guardado y propone transferencias entre tus cuentas, pagos de tarjeta, movimientos repetidos y montos raros; agrupa los movimientos propios, empareja transferencias hasta con 5 días de diferencia, avisa de estados faltantes, permite convertir las casi seguras y deshacer. El banner es ámbar y se puede cerrar.
- **Cuentas de ahorro (426):** intereses ganados y rendimiento real; la importación crea ahorros con su rendimiento.
- **Importar varios archivos (430):** el aviso nombra el archivo que no cuadra y el que tuvo filas sin leer.
- **Arreglos:** color elegido a mano en cuentas con logo (429), selector de color (431), Capital One cuenta con «Instant transfer…» (432), Chime y el Cash Bonus (433), comercios que empiezan con «New…» en Capital One (441).
- **Sitio:** la tipografía Inter se sirve desde el propio dominio (el sitio ya no consulta a Google Fonts); textos de transparencia y del BCP al día, y un tono más sobrio.
- **Servidor:** roles (incluido Auditor de solo lectura), tokens por persona y registro de auditoría; el panel del equipo pasó a un repositorio privado. Base de Nazca en el Worker (casos enmascarados para vigilar los lectores).

- **Importar desde tu banco (CSV), con Nazca:** Nazca es el nuevo motor de importación de Plata. En Movimientos o en Ajustes, eliges el archivo CSV que descargaste de tu banca por internet y Plata lo lee en tu dispositivo, sin subirlo a ningún servidor. Detecta solas las columnas, el formato de fechas y números, cargos y abonos, y la moneda. Antes de importar ves cada movimiento con su categoría sugerida (aprende de lo que ya registraste), quitas los que no quieras, y Plata marca los que parecen repetidos o ya importados. Eliges si sumar al saldo, no tocarlo o usar el saldo que trae el archivo. Se puede deshacer.
- **Nazca aprende cuatro lectores más (Estados Unidos):** Bank of America (cuenta de cheques, estado en español), Apple Card (PDF y también el CSV de Apple, que se reconoce por sus columnas) y Community Bank, N.A. (cuenta corriente). Todos se verifican con "Cuadra" y las tarjetas crean la tarjeta con tasa, fecha de pago y pago mínimo. Bank of America en inglés y Community Bank con muchos movimientos aún no están probados con estados reales.
- **Importar datos de banco, con PDF del BCP:** el botón ahora abre un menú: *Importar archivo* (tarjetas de crédito de bancos que Nazca no conoce: se reconocen por sus pistas —línea de crédito, pago mínimo, fecha de pago, tasa—, se acomodan los signos y se crea la tarjeta con esos datos, sin verificado; Seen —tarjeta de crédito— también se reconoce y se verifica, con su tasa anual, fecha de pago, mínimo y límite; Chime también se reconoce y se verifica; el lector genérico ahora entiende columnas Cargo/Abono, monto neto, fechas al final, saldos, paréntesis y formato europeo; el BCP pide DNI y los demás bancos no piden nada hasta que el archivo lo necesite; Capital One —tarjeta de crédito, en dólares— ya se reconoce y se verifica: crea la tarjeta con su tasa anual, fecha de pago, pago mínimo y línea de crédito; CSV o PDF; si el banco no está en la lista de Nazca, lee el PDF de forma genérica —fecha, descripción y monto— y se revisa como un CSV, sin sello de verificado; CSV o PDF: Nazca reconoce el banco por el contenido y, si el PDF tiene contraseña, la pide en su propia pantalla) o *Elegir banco* (Perú → BCP e Interbank; BBVA y Scotiabank salen como «No disponible»). Con el BCP subes el PDF del estado de cuenta de ahorros: si tiene contraseña la escribes para abrirlo, y Plata no la guarda ni la revisa. Nazca reconoce el banco por el contenido, lee cargos y abonos por su columna, completa el año de las fechas (30SET) y **comprueba que cuadra** con los totales y el saldo final del banco. Con Interbank (cuenta de ahorros) lee los montos con signo, ignora la página-guía con movimientos de ejemplo y además comprueba que el saldo corra fila por fila. Puedes crear una cuenta nueva o sumar los movimientos a una existente; si te equivocas, deshacer también quita la cuenta que creó. El lector de PDF (pdf.js de Mozilla) se descarga desde web.plataapp.net solo cuando importas un PDF; el PDF no se sube a ningún servidor.

## Beta 3

- **Seguridad (compilación 421):** revisión completa. La app limpia y escapa todo lo que llega de un archivo de perfil o de la nube, y solo ejecuta su propio código. Aprobar un dispositivo nuevo ahora muestra un código de 6 dígitos en las dos pantallas, que nadie en medio puede imitar. Pisar o borrar tu copia en la nube exige tu frase, no solo tu correo. La nube rechaza copias viejas que intenten pasar por nuevas. Nuevo: "Cerrar sesión en otros dispositivos".
- **Entrar o crear cuenta:** Plata Cloud aparece en la app para todos, sin activarlo aparte. El acceso sigue siendo por invitación.
- **Sin invitación:** si el correo no tiene acceso, la misma pantalla te apunta a la lista de espera, o te avisa si ya estabas en ella.
- **Empezar en la nube:** si es tu primera vez con datos, te lleva a un recorrido como el de Empezar, con aviso de Plata Cloud y un último paso para abrir Plata en tu otro dispositivo (código QR en escritorio, enlace en celular).
- **Copia local a la nube:** al volver a modo Cloud, cargar la copia de este dispositivo como la de la nube pide confirmación y un código por correo.
- **Precio:** early supporters, 30% menos durante un año, renovable según el contexto. Primer mes gratis (marcha blanca), por invitación.
- **Notas y rachas:** al segundo mes seguido subes de nivel; tu nota luce un laurel y un broche.
- **Navegación renovada:** cuatro pestañas y un botón + junto a la barra para registrar o planear en un toque; Ahorro ahora vive dentro de Proyección.
- **Transferencias:** mueve plata entre tus cuentas sin que cuente como gasto ni ingreso.
- **Marcas:** logos y colores automáticos de bancos, billeteras y suscripciones.
- **Monedas:** al cambiar la moneda de una cuenta, tarjeta o meta, elige mantener los montos o convertirlos.
- **Más rápido:** desliza un movimiento para editarlo, posponerlo o borrarlo (clic derecho en escritorio); avisos cuando algo se ve raro.
- **Transparencia y aviso legal:** actualizados con la cuenta de Plata Cloud, el cifrado, la frase de recuperación y los términos de la marcha blanca.

## Beta 2

- **Plata llega a tu mesa:** la versión de escritorio ya está disponible. Entra a la web desde tu PC o Mac para verla.
- **Arma tu Bento. (exclusivo para escritorio):** crea un set de gráficos con tus finanzas, al estilo Bento.
- **Modo oscuro:** nuevo ajuste de apariencia con Auto (sigue al sistema), Claro y Oscuro. Se elige al empezar y se cambia en el perfil. La franja superior del iPhone también cambia de color.
- **Calendario:** en oscuro, el día de hoy se marca en verde Plata.
- **Novedades:** aviso la primera vez que abres la app tras actualizar, y acceso desde Ajustes.
- **Vista web:** en pantallas anchas la app se organiza como un bento con todas las secciones a la vez, con la paleta de Prensa.
- **Bentos:** en escritorio, tablero 16:9 con widgets de tus datos; varios Bentos con nombre propio, vista con navegación, edición con + / − y arrastrar y soltar para colocar cada widget donde quieras, captura en PNG con QR a plataapp.net y @plataapp.
- **Asistente de inicio (escritorio):** el paso de moneda usa un mapamundi para elegir región y ver sus monedas, con las elegidas como píldoras junto a la pregunta, y el asistente avanza con la rueda del ratón o las flechas del teclado.
- **Sitio web:** plataapp.net ahora tiene secciones nuevas para conocer mejor Plata: Cómo usar, Prensa, Transparencia, Ayuda y Novedades.

## Beta 1

Primera versión pública de Plata.
