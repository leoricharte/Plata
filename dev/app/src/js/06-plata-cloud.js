/* ---------- Plata Cloud (beta cerrada) ---------- */
/* Plata Cloud · cifrado de extremo a extremo. El servidor solo recibe texto cifrado; la clave sale de una frase de 12 palabras que solo la persona conoce. */
const PCC = (() => {
  const WL = 'abandon ability able about above absent absorb abstract absurd abuse access accident account accuse achieve acid acoustic acquire across act action actor actress actual adapt add addict address adjust admit adult advance advice aerobic affair afford afraid again age agent agree ahead aim air airport aisle alarm album alcohol alert alien all alley allow almost alone alpha already also alter always amateur amazing among amount amused analyst anchor ancient anger angle angry animal ankle announce annual another answer antenna antique anxiety any apart apology appear apple approve april arch arctic area arena argue arm armed armor army around arrange arrest arrive arrow art artefact artist artwork ask aspect assault asset assist assume asthma athlete atom attack attend attitude attract auction audit august aunt author auto autumn average avocado avoid awake aware away awesome awful awkward axis baby bachelor bacon badge bag balance balcony ball bamboo banana banner bar barely bargain barrel base basic basket battle beach bean beauty because become beef before begin behave behind believe below belt bench benefit best betray better between beyond bicycle bid bike bind biology bird birth bitter black blade blame blanket blast bleak bless blind blood blossom blouse blue blur blush board boat body boil bomb bone bonus book boost border boring borrow boss bottom bounce box boy bracket brain brand brass brave bread breeze brick bridge brief bright bring brisk broccoli broken bronze broom brother brown brush bubble buddy budget buffalo build bulb bulk bullet bundle bunker burden burger burst bus business busy butter buyer buzz cabbage cabin cable cactus cage cake call calm camera camp can canal cancel candy cannon canoe canvas canyon capable capital captain car carbon card cargo carpet carry cart case cash casino castle casual cat catalog catch category cattle caught cause caution cave ceiling celery cement census century cereal certain chair chalk champion change chaos chapter charge chase chat cheap check cheese chef cherry chest chicken chief child chimney choice choose chronic chuckle chunk churn cigar cinnamon circle citizen city civil claim clap clarify claw clay clean clerk clever click client cliff climb clinic clip clock clog close cloth cloud clown club clump cluster clutch coach coast coconut code coffee coil coin collect color column combine come comfort comic common company concert conduct confirm congress connect consider control convince cook cool copper copy coral core corn correct cost cotton couch country couple course cousin cover coyote crack cradle craft cram crane crash crater crawl crazy cream credit creek crew cricket crime crisp critic crop cross crouch crowd crucial cruel cruise crumble crunch crush cry crystal cube culture cup cupboard curious current curtain curve cushion custom cute cycle dad damage damp dance danger daring dash daughter dawn day deal debate debris decade december decide decline decorate decrease deer defense define defy degree delay deliver demand demise denial dentist deny depart depend deposit depth deputy derive describe desert design desk despair destroy detail detect develop device devote diagram dial diamond diary dice diesel diet differ digital dignity dilemma dinner dinosaur direct dirt disagree discover disease dish dismiss disorder display distance divert divide divorce dizzy doctor document dog doll dolphin domain donate donkey donor door dose double dove draft dragon drama drastic draw dream dress drift drill drink drip drive drop drum dry duck dumb dune during dust dutch duty dwarf dynamic eager eagle early earn earth easily east easy echo ecology economy edge edit educate effort egg eight either elbow elder electric elegant element elephant elevator elite else embark embody embrace emerge emotion employ empower empty enable enact end endless endorse enemy energy enforce engage engine enhance enjoy enlist enough enrich enroll ensure enter entire entry envelope episode equal equip era erase erode erosion error erupt escape essay essence estate eternal ethics evidence evil evoke evolve exact example excess exchange excite exclude excuse execute exercise exhaust exhibit exile exist exit exotic expand expect expire explain expose express extend extra eye eyebrow fabric face faculty fade faint faith fall false fame family famous fan fancy fantasy farm fashion fat fatal father fatigue fault favorite feature february federal fee feed feel female fence festival fetch fever few fiber fiction field figure file film filter final find fine finger finish fire firm first fiscal fish fit fitness fix flag flame flash flat flavor flee flight flip float flock floor flower fluid flush fly foam focus fog foil fold follow food foot force forest forget fork fortune forum forward fossil foster found fox fragile frame frequent fresh friend fringe frog front frost frown frozen fruit fuel fun funny furnace fury future gadget gain galaxy gallery game gap garage garbage garden garlic garment gas gasp gate gather gauge gaze general genius genre gentle genuine gesture ghost giant gift giggle ginger giraffe girl give glad glance glare glass glide glimpse globe gloom glory glove glow glue goat goddess gold good goose gorilla gospel gossip govern gown grab grace grain grant grape grass gravity great green grid grief grit grocery group grow grunt guard guess guide guilt guitar gun gym habit hair half hammer hamster hand happy harbor hard harsh harvest hat have hawk hazard head health heart heavy hedgehog height hello helmet help hen hero hidden high hill hint hip hire history hobby hockey hold hole holiday hollow home honey hood hope horn horror horse hospital host hotel hour hover hub huge human humble humor hundred hungry hunt hurdle hurry hurt husband hybrid ice icon idea identify idle ignore ill illegal illness image imitate immense immune impact impose improve impulse inch include income increase index indicate indoor industry infant inflict inform inhale inherit initial inject injury inmate inner innocent input inquiry insane insect inside inspire install intact interest into invest invite involve iron island isolate issue item ivory jacket jaguar jar jazz jealous jeans jelly jewel job join joke journey joy judge juice jump jungle junior junk just kangaroo keen keep ketchup key kick kid kidney kind kingdom kiss kit kitchen kite kitten kiwi knee knife knock know lab label labor ladder lady lake lamp language laptop large later latin laugh laundry lava law lawn lawsuit layer lazy leader leaf learn leave lecture left leg legal legend leisure lemon lend length lens leopard lesson letter level liar liberty library license life lift light like limb limit link lion liquid list little live lizard load loan lobster local lock logic lonely long loop lottery loud lounge love loyal lucky luggage lumber lunar lunch luxury lyrics machine mad magic magnet maid mail main major make mammal man manage mandate mango mansion manual maple marble march margin marine market marriage mask mass master match material math matrix matter maximum maze meadow mean measure meat mechanic medal media melody melt member memory mention menu mercy merge merit merry mesh message metal method middle midnight milk million mimic mind minimum minor minute miracle mirror misery miss mistake mix mixed mixture mobile model modify mom moment monitor monkey monster month moon moral more morning mosquito mother motion motor mountain mouse move movie much muffin mule multiply muscle museum mushroom music must mutual myself mystery myth naive name napkin narrow nasty nation nature near neck need negative neglect neither nephew nerve nest net network neutral never news next nice night noble noise nominee noodle normal north nose notable note nothing notice novel now nuclear number nurse nut oak obey object oblige obscure observe obtain obvious occur ocean october odor off offer office often oil okay old olive olympic omit once one onion online only open opera opinion oppose option orange orbit orchard order ordinary organ orient original orphan ostrich other outdoor outer output outside oval oven over own owner oxygen oyster ozone pact paddle page pair palace palm panda panel panic panther paper parade parent park parrot party pass patch path patient patrol pattern pause pave payment peace peanut pear peasant pelican pen penalty pencil people pepper perfect permit person pet phone photo phrase physical piano picnic picture piece pig pigeon pill pilot pink pioneer pipe pistol pitch pizza place planet plastic plate play please pledge pluck plug plunge poem poet point polar pole police pond pony pool popular portion position possible post potato pottery poverty powder power practice praise predict prefer prepare present pretty prevent price pride primary print priority prison private prize problem process produce profit program project promote proof property prosper protect proud provide public pudding pull pulp pulse pumpkin punch pupil puppy purchase purity purpose purse push put puzzle pyramid quality quantum quarter question quick quit quiz quote rabbit raccoon race rack radar radio rail rain raise rally ramp ranch random range rapid rare rate rather raven raw razor ready real reason rebel rebuild recall receive recipe record recycle reduce reflect reform refuse region regret regular reject relax release relief rely remain remember remind remove render renew rent reopen repair repeat replace report require rescue resemble resist resource response result retire retreat return reunion reveal review reward rhythm rib ribbon rice rich ride ridge rifle right rigid ring riot ripple risk ritual rival river road roast robot robust rocket romance roof rookie room rose rotate rough round route royal rubber rude rug rule run runway rural sad saddle sadness safe sail salad salmon salon salt salute same sample sand satisfy satoshi sauce sausage save say scale scan scare scatter scene scheme school science scissors scorpion scout scrap screen script scrub sea search season seat second secret section security seed seek segment select sell seminar senior sense sentence series service session settle setup seven shadow shaft shallow share shed shell sheriff shield shift shine ship shiver shock shoe shoot shop short shoulder shove shrimp shrug shuffle shy sibling sick side siege sight sign silent silk silly silver similar simple since sing siren sister situate six size skate sketch ski skill skin skirt skull slab slam sleep slender slice slide slight slim slogan slot slow slush small smart smile smoke smooth snack snake snap sniff snow soap soccer social sock soda soft solar soldier solid solution solve someone song soon sorry sort soul sound soup source south space spare spatial spawn speak special speed spell spend sphere spice spider spike spin spirit split spoil sponsor spoon sport spot spray spread spring spy square squeeze squirrel stable stadium staff stage stairs stamp stand start state stay steak steel stem step stereo stick still sting stock stomach stone stool story stove strategy street strike strong struggle student stuff stumble style subject submit subway success such sudden suffer sugar suggest suit summer sun sunny sunset super supply supreme sure surface surge surprise surround survey suspect sustain swallow swamp swap swarm swear sweet swift swim swing switch sword symbol symptom syrup system table tackle tag tail talent talk tank tape target task taste tattoo taxi teach team tell ten tenant tennis tent term test text thank that theme then theory there they thing this thought three thrive throw thumb thunder ticket tide tiger tilt timber time tiny tip tired tissue title toast tobacco today toddler toe together toilet token tomato tomorrow tone tongue tonight tool tooth top topic topple torch tornado tortoise toss total tourist toward tower town toy track trade traffic tragic train transfer trap trash travel tray treat tree trend trial tribe trick trigger trim trip trophy trouble truck true truly trumpet trust truth try tube tuition tumble tuna tunnel turkey turn turtle twelve twenty twice twin twist two type typical ugly umbrella unable unaware uncle uncover under undo unfair unfold unhappy uniform unique unit universe unknown unlock until unusual unveil update upgrade uphold upon upper upset urban urge usage use used useful useless usual utility vacant vacuum vague valid valley valve van vanish vapor various vast vault vehicle velvet vendor venture venue verb verify version very vessel veteran viable vibrant vicious victory video view village vintage violin virtual virus visa visit visual vital vivid vocal voice void volcano volume vote voyage wage wagon wait walk wall walnut want warfare warm warrior wash wasp waste water wave way wealth weapon wear weasel weather web wedding weekend weird welcome west wet whale what wheat wheel when where whip whisper wide width wife wild will win window wine wing wink winner winter wire wisdom wise wish witness wolf woman wonder wood wool word work world worry worth wrap wreck wrestle wrist write wrong yard year yellow you young youth zebra zero zone zoo'.split(' '), IDX = {}; WL.forEach((w, i) => { IDX[w] = i; });
  /* La misma frase en español, sin tildes ni eñes (lista BIP-39 en español, dominio público): la palabra N en español y en inglés codifican los mismos 11 bits, así que es la misma llave escrita con otras palabras. */
  const WLES = 'abaco abdomen abeja abierto abogado abono aborto abrazo abrir abuelo abuso acabar academia acceso accion aceite acelga acento aceptar acido aclarar acne acoger acoso activo acto actriz actuar acudir acuerdo acusar adicto admitir adoptar adorno aduana adulto aereo afectar aficion afinar afirmar agil agitar agonia agosto agotar agregar agrio agua agudo aguila aguja ahogo ahorro aire aislar ajedrez ajeno ajuste alacran alambre alarma alba album alcalde aldea alegre alejar alerta aleta alfiler alga algodon aliado aliento alivio alma almeja almibar altar alteza altivo alto altura alumno alzar amable amante amapola amargo amasar ambar ambito ameno amigo amistad amor amparo amplio ancho anciano ancla andar anden anemia angulo anillo animo anis anotar antena antiguo antojo anual anular anuncio anadir anejo ano apagar aparato apetito apio aplicar apodo aporte apoyo aprender aprobar apuesta apuro arado arana arar arbitro arbol arbusto archivo arco arder ardilla arduo area arido aries armonia arnes aroma arpa arpon arreglo arroz arruga arte artista asa asado asalto ascenso asegurar aseo asesor asiento asilo asistir asno asombro aspero astilla astro astuto asumir asunto atajo ataque atar atento ateo atico atleta atomo atraer atroz atun audaz audio auge aula aumento ausente autor aval avance avaro ave avellana avena avestruz avion aviso ayer ayuda ayuno azafran azar azote azucar azufre azul baba babor bache bahia baile bajar balanza balcon balde bambu banco banda bano barba barco barniz barro bascula baston basura batalla bateria batir batuta baul bazar bebe bebida bello besar beso bestia bicho bien bingo blanco bloque blusa boa bobina bobo boca bocina boda bodega boina bola bolero bolsa bomba bondad bonito bono bonsai borde borrar bosque bote botin boveda bozal bravo brazo brecha breve brillo brinco brisa broca broma bronce brote bruja brusco bruto buceo bucle bueno buey bufanda bufon buho buitre bulto burbuja burla burro buscar butaca buzon caballo cabeza cabina cabra cacao cadaver cadena caer cafe caida caiman caja cajon cal calamar calcio caldo calidad calle calma calor calvo cama cambio camello camino campo cancer candil canela canguro canica canto cana canon caoba caos capaz capitan capote captar capucha cara carbon carcel careta carga carino carne carpeta carro carta casa casco casero caspa castor catorce catre caudal causa cazo cebolla ceder cedro celda celebre celoso celula cemento ceniza centro cerca cerdo cereza cero cerrar certeza cesped cetro chacal chaleco champu chancla chapa charla chico chiste chivo choque choza chuleta chupar ciclon ciego cielo cien cierto cifra cigarro cima cinco cine cinta cipres circo ciruela cisne cita ciudad clamor clan claro clase clave cliente clima clinica cobre coccion cochino cocina coco codigo codo cofre coger cohete cojin cojo cola colcha colegio colgar colina collar colmo columna combate comer comida comodo compra conde conejo conga conocer consejo contar copa copia corazon corbata corcho cordon corona correr coser cosmos costa craneo crater crear crecer creido crema cria crimen cripta crisis cromo cronica croqueta crudo cruz cuadro cuarto cuatro cubo cubrir cuchara cuello cuento cuerda cuesta cueva cuidar culebra culpa culto cumbre cumplir cuna cuneta cuota cupon cupula curar curioso curso curva cutis dama danza dar dardo datil deber debil decada decir dedo defensa definir dejar delfin delgado delito demora denso dental deporte derecho derrota desayuno deseo desfile desnudo destino desvio detalle detener deuda dia diablo diadema diamante diana diario dibujo dictar diente dieta diez dificil digno dilema diluir dinero directo dirigir disco diseno disfraz diva divino doble doce dolor domingo don donar dorado dormir dorso dos dosis dragon droga ducha duda duelo dueno dulce duo duque durar dureza duro ebano ebrio echar eco ecuador edad edicion edificio editor educar efecto eficaz eje ejemplo elefante elegir elemento elevar elipse elite elixir elogio eludir embudo emitir emocion empate empeno empleo empresa enano encargo enchufe encia enemigo enero enfado enfermo engano enigma enlace enorme enredo ensayo ensenar entero entrar envase envio epoca equipo erizo escala escena escolar escribir escudo esencia esfera esfuerzo espada espejo espia esposa espuma esqui estar este estilo estufa etapa eterno etica etnia evadir evaluar evento evitar exacto examen exceso excusa exento exigir exilio existir exito experto explicar exponer extremo fabrica fabula fachada facil factor faena faja falda fallo falso faltar fama familia famoso faraon farmacia farol farsa fase fatiga fauna favor fax febrero fecha feliz feo feria feroz fertil fervor festin fiable fianza fiar fibra ficcion ficha fideo fiebre fiel fiera fiesta figura fijar fijo fila filete filial filtro fin finca fingir finito firma flaco flauta flecha flor flota fluir flujo fluor fobia foca fogata fogon folio folleto fondo forma forro fortuna forzar fosa foto fracaso fragil franja frase fraude freir freno fresa frio frito fruta fuego fuente fuerza fuga fumar funcion funda furgon furia fusil futbol futuro gacela gafas gaita gajo gala galeria gallo gamba ganar gancho ganga ganso garaje garza gasolina gastar gato gavilan gemelo gemir gen genero genio gente geranio gerente germen gesto gigante gimnasio girar giro glaciar globo gloria gol golfo goloso golpe goma gordo gorila gorra gota goteo gozar grada grafico grano grasa gratis grave grieta grillo gripe gris grito grosor grua grueso grumo grupo guante guapo guardia guerra guia guino guion guiso guitarra gusano gustar haber habil hablar hacer hacha hada hallar hamaca harina haz hazana hebilla hebra hecho helado helio hembra herir hermano heroe hervir hielo hierro higado higiene hijo himno historia hocico hogar hoguera hoja hombre hongo honor honra hora hormiga horno hostil hoyo hueco huelga huerta hueso huevo huida huir humano humedo humilde humo hundir huracan hurto icono ideal idioma idolo iglesia iglu igual ilegal ilusion imagen iman imitar impar imperio imponer impulso incapaz indice inerte infiel informe ingenio inicio inmenso inmune innato insecto instante interes intimo intuir inutil invierno ira iris ironia isla islote jabali jabon jamon jarabe jardin jarra jaula jazmin jefe jeringa jinete jornada joroba joven joya juerga jueves juez jugador jugo juguete juicio junco jungla junio juntar jupiter jurar justo juvenil juzgar kilo koala labio lacio lacra lado ladron lagarto lagrima laguna laico lamer lamina lampara lana lancha langosta lanza lapiz largo larva lastima lata latex latir laurel lavar lazo leal leccion leche lector leer legion legumbre lejano lengua lento lena leon leopardo lesion letal letra leve leyenda libertad libro licor lider lidiar lienzo liga ligero lima limite limon limpio lince lindo linea lingote lino linterna liquido liso lista litera litio litro llaga llama llanto llave llegar llenar llevar llorar llover lluvia lobo locion loco locura logica logro lombriz lomo lonja lote lucha lucir lugar lujo luna lunes lupa lustro luto luz maceta macho madera madre maduro maestro mafia magia mago maiz maldad maleta malla malo mama mambo mamut manco mando manejar manga maniqui manjar mano manso manta manana mapa maquina mar marco marea marfil margen marido marmol marron martes marzo masa mascara masivo matar materia matiz matriz maximo mayor mazorca mecha medalla medio medula mejilla mejor melena melon memoria menor mensaje mente menu mercado merengue merito mes meson meta meter metodo metro mezcla miedo miel miembro miga mil milagro militar millon mimo mina minero minimo minuto miope mirar misa miseria misil mismo mitad mito mochila mocion moda modelo moho mojar molde moler molino momento momia monarca moneda monja monto mono morada morder moreno morir morro morsa mortal mosca mostrar motivo mover movil mozo mucho mudar mueble muela muerte muestra mugre mujer mula muleta multa mundo muneca mural muro musculo museo musgo musica muslo nacar nacion nadar naipe naranja nariz narrar nasal natal nativo natural nausea naval nave navidad necio nectar negar negocio negro neon nervio neto neutro nevar nevera nicho nido niebla nieto ninez nino nitido nivel nobleza noche nomina noria norma norte nota noticia novato novela novio nube nuca nucleo nudillo nudo nuera nueve nuez nulo numero nutria oasis obeso obispo objeto obra obrero observar obtener obvio oca ocaso oceano ochenta ocho ocio ocre octavo octubre oculto ocupar ocurrir odiar odio odisea oeste ofensa oferta oficio ofrecer ogro oido oir ojo ola oleada olfato olivo olla olmo olor olvido ombligo onda onza opaco opcion opera opinar oponer optar optica opuesto oracion orador oral orbita orca orden oreja organo orgia orgullo oriente origen orilla oro orquesta oruga osadia oscuro osezno oso ostra otono otro oveja ovulo oxido oxigeno oyente ozono pacto padre paella pagina pago pais pajaro palabra palco paleta palido palma paloma palpar pan panal panico pantera panuelo papa papel papilla paquete parar parcela pared parir paro parpado parque parrafo parte pasar paseo pasion paso pasta pata patio patria pausa pauta pavo payaso peaton pecado pecera pecho pedal pedir pegar peine pelar peldano pelea peligro pellejo pelo peluca pena pensar penon peon peor pepino pequeno pera percha perder pereza perfil perico perla permiso perro persona pesa pesca pesimo pestana petalo petroleo pez pezuna picar pichon pie piedra pierna pieza pijama pilar piloto pimienta pino pintor pinza pina piojo pipa pirata pisar piscina piso pista piton pizca placa plan plata playa plaza pleito pleno plomo pluma plural pobre poco poder podio poema poesia poeta polen policia pollo polvo pomada pomelo pomo pompa poner porcion portal posada poseer posible poste potencia potro pozo prado precoz pregunta premio prensa preso previo primo principe prision privar proa probar proceso producto proeza profesor programa prole promesa pronto propio proximo prueba publico puchero pudor pueblo puerta puesto pulga pulir pulmon pulpo pulso puma punto punal puno pupa pupila pure quedar queja quemar querer queso quieto quimica quince quitar rabano rabia rabo racion radical raiz rama rampa rancho rango rapaz rapido rapto rasgo raspa rato rayo raza razon reaccion realidad rebano rebote recaer receta rechazo recoger recreo recto recurso red redondo reducir reflejo reforma refran refugio regalo regir regla regreso rehen reino reir reja relato relevo relieve relleno reloj remar remedio remo rencor rendir renta reparto repetir reposo reptil res rescate resina respeto resto resumen retiro retorno retrato reunir reves revista rey rezar rico riego rienda riesgo rifa rigido rigor rincon rinon rio riqueza risa ritmo rito rizo roble roce rociar rodar rodeo rodilla roer rojizo rojo romero romper ron ronco ronda ropa ropero rosa rosca rostro rotar rubi rubor rudo rueda rugir ruido ruina ruleta rulo rumbo rumor ruptura ruta rutina sabado saber sabio sable sacar sagaz sagrado sala saldo salero salir salmon salon salsa salto salud salvar samba sancion sandia sanear sangre sanidad sano santo sapo saque sardina sarten sastre satan sauna saxofon seccion seco secreto secta sed seguir seis sello selva semana semilla senda sensor senal senor separar sepia sequia ser serie sermon servir sesenta sesion seta setenta severo sexo sexto sidra siesta siete siglo signo silaba silbar silencio silla simbolo simio sirena sistema sitio situar sobre socio sodio sol solapa soldado soledad solido soltar solucion sombra sondeo sonido sonoro sonrisa sopa soplar soporte sordo sorpresa sorteo sosten sotano suave subir suceso sudor suegra suelo sueno suerte sufrir sujeto sultan sumar superar suplir suponer supremo sur surco sureno surgir susto sutil tabaco tabique tabla tabu taco tacto tajo talar talco talento talla talon tamano tambor tango tanque tapa tapete tapia tapon taquilla tarde tarea tarifa tarjeta tarot tarro tarta tatuaje tauro taza tazon teatro techo tecla tecnica tejado tejer tejido tela telefono tema temor templo tenaz tender tener tenis tenso teoria terapia terco termino ternura terror tesis tesoro testigo tetera texto tez tibio tiburon tiempo tienda tierra tieso tigre tijera tilde timbre timido timo tinta tio tipico tipo tira tiron titan titere titulo tiza toalla tobillo tocar tocino todo toga toldo tomar tono tonto topar tope toque torax torero tormenta torneo toro torpedo torre torso tortuga tos tosco toser toxico trabajo tractor traer trafico trago traje tramo trance trato trauma trazar trebol tregua treinta tren trepar tres tribu trigo tripa triste triunfo trofeo trompa tronco tropa trote trozo truco trueno trufa tuberia tubo tuerto tumba tumor tunel tunica turbina turismo turno tutor ubicar ulcera umbral unidad unir universo uno untar una urbano urbe urgente urna usar usuario util utopia uva vaca vacio vacuna vagar vago vaina vajilla vale valido valle valor valvula vampiro vara variar varon vaso vecino vector vehiculo veinte vejez vela velero veloz vena vencer venda veneno vengar venir venta venus ver verano verbo verde vereda verja verso verter via viaje vibrar vicio victima vida video vidrio viejo viernes vigor vil villa vinagre vino vinedo violin viral virgo virtud visor vispera vista vitamina viudo vivaz vivero vivir vivo volcan volumen volver voraz votar voto voz vuelo vulgar yacer yate yegua yema yerno yeso yodo yoga yogur zafiro zanja zapato zarza zona zorro zumo zurdo'.split(' '), IDXES = {}; WLES.forEach((w, i) => { IDXES[w] = i; });
  const enc = new TextEncoder(), dec = new TextDecoder(), S = crypto.subtle;
  const b64u = (u) => { let s = ''; for (let i = 0; i < u.length; i += 8192) s += String.fromCharCode.apply(null, u.subarray(i, i + 8192)); return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); };
  const unb64u = (t) => { t = t.replace(/-/g, '+').replace(/_/g, '/'); while (t.length % 4) t += '='; const bin = atob(t), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; };
  const sum4 = async (seed) => (new Uint8Array(await S.digest('SHA-256', seed)))[0] >> 4;
  async function toPhrase(seed, lang) { // 128 bits + 4 de suma de verificación = 132 bits = 12 palabras de 11 bits
    const bits = []; seed.forEach((b) => { for (let i = 7; i >= 0; i--) bits.push((b >> i) & 1); });
    const c = await sum4(seed); for (let i = 3; i >= 0; i--) bits.push((c >> i) & 1);
    const out = []; for (let i = 0; i < 12; i++) { let v = 0; for (let j = 0; j < 11; j++) v = (v << 1) | bits[i * 11 + j]; out.push((lang === 'es' ? WLES : WL)[v]); }
    return out;
  }
  const fold = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, ''); // sin tildes ni eñes: «cañón» y «canon» son la misma palabra
  const wordIdx = (w, lang) => { w = fold(w).trim(); const L = lang === 'es' ? WLES : WL, X = lang === 'es' ? IDXES : IDX; if (w in X) return X[w]; if (w.length < 4) return -1; const m = L.filter((x) => x.indexOf(w) === 0); return m.length === 1 ? X[m[0]] : -1; };
  async function fromPhraseIn(text, lang) { // devuelve la semilla o null si falta una palabra, sobra una o hay un error de escritura
    const ws = fold(text).split(/[^a-z]+/).filter(Boolean); if (ws.length !== 12) return null;
    const bits = []; for (const w of ws) { const v = wordIdx(w, lang); if (v < 0) return null; for (let j = 10; j >= 0; j--) bits.push((v >> j) & 1); }
    const seed = new Uint8Array(16); for (let i = 0; i < 128; i++) seed[i >> 3] |= bits[i] << (7 - (i & 7));
    let c = 0; for (let i = 128; i < 132; i++) c = (c << 1) | bits[i];
    return (await sum4(seed)) === c ? seed : null;
  }
  /* Acepta la frase en español o en inglés (unas pocas palabras existen en las dos listas: con kc se elige la lectura que corresponde a la cuenta) */
  async function fromPhrase(text, kc) {
    let first = null;
    for (const lang of ['es', 'en']) { const sd = await fromPhraseIn(text, lang); if (!sd) continue; if (!kc || (await keyCheck(sd)) === kc) return sd; first = first || sd; }
    return kc ? null : first;
  }
  const newSeed = () => crypto.getRandomValues(new Uint8Array(16));
  async function hk(seed, info, usage, bits) {
    const base = await S.importKey('raw', seed, 'HKDF', false, ['deriveKey', 'deriveBits']), p = { name: 'HKDF', hash: 'SHA-256', salt: enc.encode('plata-cloud-v1'), info: enc.encode(info) };
    return usage ? S.deriveKey(p, base, { name: 'AES-GCM', length: 256 }, false, usage) : new Uint8Array(await S.deriveBits(p, base, bits));
  }
  const dataKey = (seed) => hk(seed, 'data', ['encrypt', 'decrypt']);
  const keyCheck = async (seed) => b64u(await hk(seed, 'check', null, 256)); // comprobación que ve el servidor: no revela la clave de datos
  const writeKey = async (seed) => b64u(await hk(seed, 'write', null, 256)); // permiso para escribir o borrar la copia: sin la frase no se puede pisar
  async function gz(bytes, mode) {
    const cs = new (mode === 'c' ? CompressionStream : DecompressionStream)('gzip'), w = cs.writable.getWriter(); w.write(bytes); w.close();
    return new Uint8Array(await new Response(cs.readable).arrayBuffer());
  }
  async function seal(key, obj, rev) { // con rev, la revisión viaja DENTRO del cifrado: el servidor no puede devolver una copia vieja como nueva
    const body = rev ? { plata: 2, rev: rev, d: obj } : obj;
    let bytes = enc.encode(JSON.stringify(body)), z = 0;
    if (typeof CompressionStream === 'function') { try { bytes = await gz(bytes, 'c'); z = 1; } catch (e) { bytes = enc.encode(JSON.stringify(body)); z = 0; } }
    const iv = crypto.getRandomValues(new Uint8Array(12)), ct = new Uint8Array(await S.encrypt({ name: 'AES-GCM', iv: iv, additionalData: enc.encode('plata1') }, key, bytes));
    const out = new Uint8Array(2 + 12 + ct.length); out[0] = 1; out[1] = z; out.set(iv, 2); out.set(ct, 14); return b64u(out);
  }
  async function open(key, blob) {
    const u = unb64u(blob); if (u[0] !== 1) throw new Error('version');
    let bytes = new Uint8Array(await S.decrypt({ name: 'AES-GCM', iv: u.subarray(2, 14), additionalData: enc.encode('plata1') }, key, u.subarray(14)));
    if (u[1] === 1) bytes = await gz(bytes, 'd');
    return JSON.parse(dec.decode(bytes));
  }
  /* aprobar un inicio de sesión desde otro dispositivo: ECDH P-256 efímero + AES-GCM. El servidor solo retransmite texto cifrado. */
  const EC = { name: 'ECDH', namedCurve: 'P-256' }, LAAD = enc.encode('plata-link1');
  async function linkNew() { const kp = await S.generateKey(EC, false, ['deriveKey']), raw = await S.exportKey('raw', kp.publicKey); return { priv: kp.privateKey, pub: b64u(new Uint8Array(raw)) }; }
  const linkKey = async (priv, pubB64) => S.deriveKey({ name: 'ECDH', public: await S.importKey('raw', unb64u(pubB64), EC, false, []) }, priv, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
  /* Comparación numérica con compromiso previo: el dispositivo activo se compromete con su clave y su aleatorio ANTES de ver el aleatorio
   * del nuevo, y el código de 6 dígitos depende de las dos claves y los dos aleatorios. Nadie en medio puede fabricar una clave con el mismo código. */
  const rnd = (n) => b64u(crypto.getRandomValues(new Uint8Array(n)));
  const h64 = async (t) => b64u(new Uint8Array(await S.digest('SHA-256', enc.encode(t))));
  async function linkCommit() {
    const kp = await S.generateKey(EC, false, ['deriveKey']), apub = b64u(new Uint8Array(await S.exportKey('raw', kp.publicKey))), na = rnd(16);
    return { priv: kp.privateKey, apub: apub, na: na, c: await h64('plata-commit1|' + apub + '|' + na) };
  }
  const linkVerify = async (c, apub, na) => !!c && c === await h64('plata-commit1|' + apub + '|' + na);
  async function linkCode(pub, apub, na, nn) { const d = new Uint8Array(await S.digest('SHA-256', enc.encode('plata-sas1|' + pub + '|' + apub + '|' + na + '|' + nn))); return String(((d[0] << 24 | d[1] << 16 | d[2] << 8 | d[3]) >>> 0) % 1000000).padStart(6, '0'); }
  async function linkSeal(priv, reqPub, seed) { const key = await linkKey(priv, reqPub), iv = crypto.getRandomValues(new Uint8Array(12)); return { iv: b64u(iv), ct: b64u(new Uint8Array(await S.encrypt({ name: 'AES-GCM', iv: iv, additionalData: LAAD }, key, seed))) }; }
  async function linkOpen(priv, apub, iv, ct) { return new Uint8Array(await S.decrypt({ name: 'AES-GCM', iv: unb64u(iv), additionalData: LAAD }, await linkKey(priv, apub), unb64u(ct))); }
  return { newSeed, toPhrase, fromPhrase, dataKey, keyCheck, writeKey, seal, open, b64u, unb64u, wordIdx, WL, linkNew, linkCommit, linkVerify, linkCode, linkSeal, linkOpen, rnd };
})();

/* Plata Cloud · combinar el perfil de este dispositivo con el de la nube.
 * Con la última versión sincronizada como base (3 vías): lo que cambió solo de un lado gana sin discusión; si cambió de los dos, gana la edición más reciente.
 * Los saldos se suman por diferencia (así un gasto hecho en el teléfono y otro en el computador cuentan los dos). Lo borrado se respeta con las lápidas. */
const MG_COLS = ['accounts', 'cards', 'savings', 'subs', 'transactions', 'expected_income', 'expected_expense', 'planned', 'jobs', 'budgetSets'];
const MG_FIELDS = ['settings', 'history', 'recurring', 'budget', 'cats', 'ovr', 'firstHalf', 'halfSnaps'];
const MG_OBJ = ['settings', 'budget', 'ovr', 'halfSnaps'];
const MG_DELTA = { accounts: ['balance'], cards: ['balance'], savings: ['balance'] };
const mgSig = (v) => JSON.stringify(v === undefined ? null : v);
const mgCmp = (it) => JSON.stringify(it, (k, v) => (k === 'mod' ? undefined : v));
const mgR2 = (n) => Math.round(n * 100) / 100;
const mgMap = (list) => { const m = new Map(); (Array.isArray(list) ? list : []).forEach((it) => { if (it && it.id != null) m.set(String(it.id), it); }); return m; };
function mergeCol(col, B, L, R, tL, tR) {
  const bm = mgMap(B), lm = mgMap(L), rm = mgMap(R), out = [], seen = new Set();
  const order = []; (L || []).concat(R || []).forEach((it) => { if (it && it.id != null && !seen.has(String(it.id))) { seen.add(String(it.id)); order.push(String(it.id)); } });
  order.forEach((id) => {
    const l = lm.get(id), r = rm.get(id), b = bm.get(id);
    if (l && r) {
      if (mgCmp(l) === mgCmp(r)) { out.push(l.mod >= r.mod ? l : r); return; }
      if (b && mgCmp(l) === mgCmp(b)) { out.push(r); return; }
      if (b && mgCmp(r) === mgCmp(b)) { out.push(l); return; }
      const w = JSON.parse(JSON.stringify((r.mod || 0) > (l.mod || 0) ? r : l)); // gana la edición más reciente; empate: este dispositivo
      (MG_DELTA[col] || []).forEach((f) => { if (b && typeof b[f] === 'number' && typeof l[f] === 'number' && typeof r[f] === 'number') w[f] = mgR2(b[f] + (l[f] - b[f]) + (r[f] - b[f])); });
      if (col === 'savings') { const seenL = new Set(), log = []; (l.log || []).concat(r.log || []).forEach((x) => { const k = x.date + '|' + x.amount + '|' + (x.from || ''); if (!seenL.has(k)) { seenL.add(k); log.push(x); } }); log.sort((a, c) => (a.date < c.date ? -1 : a.date > c.date ? 1 : 0)); w.log = log; }
      w.mod = Math.max(l.mod || 0, r.mod || 0); out.push(w); return;
    }
    const it = l || r, tomb = l ? tR : tL, other = l ? 'r' : 'l';
    const t = tomb.get(col + '|' + id), inBase = !!b;
    if (t && t > (it.mod || 0)) return; // el otro lado lo borró después de la última edición
    if (inBase && !t && mgCmp(it) === mgCmp(b)) return; // estaba en la base, el otro lado ya no lo tiene y aquí no cambió: se fue
    out.push(it);
  });
  return out;
}
const mgEmpty = (v) => v === undefined || v === null || v === '' || (Array.isArray(v) && !v.length) || (typeof v === 'object' && v && !Object.keys(v).length);
function mergeObj(B, L, R) { // por llave, con la misma regla de 3 vías
  const out = {}, keys = new Set(Object.keys(L || {}).concat(Object.keys(R || {})));
  keys.forEach((k) => {
    const l = L && L[k], r = R && R[k], b = B && B[k], inL = L && k in L, inR = R && k in R;
    if (inL && inR) { out[k] = mgSig(l) === mgSig(r) ? l : (B && mgSig(l) === mgSig(b)) ? r : (B && mgSig(r) === mgSig(b)) ? l : (mgEmpty(l) && !mgEmpty(r)) ? r : l; }
    else if (inL) { if (!(B && k in B && mgSig(l) === mgSig(b))) out[k] = l; }
    else if (!(B && k in B && mgSig(r) === mgSig(b))) out[k] = r;
  });
  return out;
}
function mergeData(base, local, remote) {
  const B = base || null, now = Date.now(), horizon = now - 90 * 864e5;
  const tm = (d) => { const m = new Map(); (d.tomb || []).forEach((x) => { if (x && x.t > horizon) m.set(x.c + '|' + String(x.id), Math.max(m.get(x.c + '|' + String(x.id)) || 0, x.t)); }); return m; };
  const tL = tm(local), tR = tm(remote), out = Object.assign({}, remote, local);
  MG_COLS.forEach((c) => { out[c] = mergeCol(c, B && B[c], local[c], remote[c], tL, tR); });
  const fm = {}; MG_FIELDS.forEach((f) => {
    const l = local[f], r = remote[f], b = B && B[f], fl = (local.fmod || {})[f] || 0, fr = (remote.fmod || {})[f] || 0;
    if (MG_OBJ.indexOf(f) >= 0) out[f] = mergeObj(b, l, r);
    else out[f] = mgSig(l) === mgSig(r) ? l : (B && mgSig(l) === mgSig(b)) ? r : (B && mgSig(r) === mgSig(b)) ? l : (fr > fl ? r : l);
    fm[f] = Math.max(fl, fr);
  });
  out.fmod = fm;
  const tombs = new Map(); [tL, tR].forEach((m) => m.forEach((t, k) => tombs.set(k, Math.max(tombs.get(k) || 0, t))));
  out.tomb = []; tombs.forEach((t, k) => { const i = k.indexOf('|'), c = k.slice(0, i), id = k.slice(i + 1); const live = (out[c] || []).some((x) => x && String(x.id) === id && (x.mod || 0) >= t); if (!live) out.tomb.push({ c, id, t }); });
  out.demo = false;
  return out;
}

/* Plata Cloud · motor de sincronización y pantallas de cuenta. Mientras sea beta solo se ve con ?cloudbeta=1. */
const CLK = 'plata.cloud', CLB = 'plata.cloudbase', CL_COOL = 60000;
const CL = { st: {}, busy: false, t: null, status: 'idle', ui: null, api: PLATA_CLOUD_API, applying: false, key: null, first: null };
(function () {
  try { CL.st = JSON.parse(localStorage.getItem(CLK)) || {}; } catch (e) { CL.st = {}; }
  try {
    const q = /[?&]cloudbeta=(\d)/.exec(location.search); if (q) localStorage.setItem('plata.cloudbeta', q[1]);
    if (location.hostname === 'localhost') { const a = /[?&]cloudapi=([^&]+)/.exec(location.search); if (a) sessionStorage.setItem('plata.cloudapi', decodeURIComponent(a[1])); const s = sessionStorage.getItem('plata.cloudapi'); if (s) CL.api = s; }
  } catch (e) { /* sin almacenamiento */ }
})();
/* Nazca (importar datos de banco) está oculto: se activa tocando varias veces «Claude» en Créditos. */
const nazcaOn = () => { try { return localStorage.getItem('plata.nazca') !== '0'; } catch (e) { return false; } };
const clBeta = () => { try { return !!PLATA_CLOUD_API && localStorage.getItem('plata.cloudbeta') !== '0'; } catch (e) { return !!PLATA_CLOUD_API; } };
const clSave = () => { try { localStorage.setItem(CLK, JSON.stringify(CL.st)); } catch (e) { /* sin almacenamiento */ } };
const clIn = () => !!(CL.st.tok && CL.st.seed);
const clOn = () => clIn() && CL.st.mode === 'cloud';
const clBaseGet = () => { try { const s = localStorage.getItem(CLB); return s ? JSON.parse(s) : null; } catch (e) { return null; } };
const clBaseSet = (o) => { try { if (o) localStorage.setItem(CLB, JSON.stringify(o)); else localStorage.removeItem(CLB); } catch (e) { /* sin espacio */ } };
const clKey = async () => CL.key || (CL.key = await PCC.dataKey(PCC.unb64u(CL.st.seed)));
function clDrop() { const em = CL.st.email, was = CL.st.mode === 'cloud' || CL.st.seed; clWipe(); CL.st.email = em; if (was) CL.st.gone = 1; clSave(); CL.status = 'idle'; try { renderAll(); } catch (e) { /* aún sin pantalla */ } clRefresh(); }
const clGone = () => !!(clBeta() && CL.st.gone && !CL.st.tok);
function clGoneClear() { if (!CL.st.gone) return; delete CL.st.gone; clSave(); try { updGdot(); renderAll(); } catch (e) { /* aún sin pantalla */ } }
function clGoneHTML() {
  if (!clGone()) return '';
  return '<div class="cstrip cloudw gone" id="clGone" data-cloud="1">' + PC_CLOUDS + '<span class="ct"><b>Cuenta borrada</b>Tu cuenta de Plata Cloud ya no existe. Guarda tu archivo local para no perder tus datos.</span><button class="cb red" data-act="save">Guardar</button><button class="cx" data-act="cl:gonex" aria-label="Cerrar">×</button></div>';
}
function clWipe() { CL.st = {}; CL.key = null; CL.wk = null; CL.wkS = null; CL.first = null; clearTimeout(CL.t); clSave(); clBaseSet(null); CL.status = 'idle'; }
async function clFetch(path, method, body, extra) {
  const h = Object.assign({ 'Content-Type': 'application/json' }, extra || {}); if (CL.st.tok) h.Authorization = 'Bearer ' + CL.st.tok;
  if (CL.st.seed && !h['X-Plata-Write']) { if (CL.wkS !== CL.st.seed) { CL.wk = await PCC.writeKey(PCC.unb64u(CL.st.seed)); CL.wkS = CL.st.seed; } h['X-Plata-Write'] = CL.wk; }
  const r = await fetch(CL.api + path, { method: method || 'GET', headers: h, body: body ? JSON.stringify(body) : undefined });
  let j = {}; try { j = await r.json(); } catch (e) { /* sin cuerpo */ }
  if (r.status === 401 && CL.st.tok && path !== '/auth/logout') clDrop();
  return { s: r.status, j: j };
}
const clSnap = () => { const o = clone(data); o.demo = false; return o; };
const clSig = (o) => JSON.stringify(o);
function clApply(m) {
  CL.applying = true;
  try { data = migrate(clone(m)); data.demo = false; persist(); renderAll(); updGdot(); if ($('#welcome') && hasData()) { hideWelcome(); setTab('resumen'); } } finally { CL.applying = false; }
}
async function clPut(rev, obj, next) {
  const blob = await PCC.seal(await clKey(), obj, next);
  const r = await clFetch('/sync', 'PUT', { base: rev, next: next, blob: blob, v: 2, dev: syncDevice().plat, demo: false });
  if (r.s === 200) CL.st.v2 = 1;
  return r;
}
/* Abre la copia de la nube y comprueba que la revisión cifrada dentro coincide con la que dice el servidor (contra copias viejas reenviadas) */
async function clOpen(blob, rev) {
  const x = await PCC.open(await clKey(), blob);
  if (x && x.plata === 2) { if (x.rev !== rev) throw new Error('rev'); if (!CL.st.v2) { CL.st.v2 = 1; clSave(); } return x.d; }
  if (CL.st.v2) throw new Error('rev'); // ya vimos copias con revisión cifrada: una sin ella no se acepta
  return x;
}
function clDone(rev, obj) { CL.st.rev = rev; CL.st.last = Date.now(); clSave(); clBaseSet(obj); CL.status = 'ok'; }
/* Jalar para recargar: desde el tope de una pantalla, al soltar tras ~70px sincroniza con Plata Cloud (o recarga la vista si no hay sesión) */
(function () {
  const PULL = 150; /* px de dedo: antes 70, y saltaba al rozar la pantalla */
  let sc = null, y0 = 0, x0 = 0, dy = 0, ind = null, ok2 = false;
  const ok = (t) => { const el = t && t.closest && t.closest('.screen'); if (!el || el.scrollTop > 0) return null; if (t.closest('input,textarea,select,[data-noswipe],#impslide,.sheet,.modal')) return null; return el; };
  document.addEventListener('touchstart', (e) => { sc = e.touches.length === 1 && !document.querySelector('#welcome, .sheet.open, #cloudsheet') ? ok(e.target) : null; if (sc) { y0 = e.touches[0].clientY; x0 = e.touches[0].clientX; dy = 0; ok2 = true; } }, { passive: true });
  document.addEventListener('touchmove', (e) => {
    if (!sc) return; dy = e.touches[0].clientY - y0;
    /* un gesto que sube, o que va más de lado que hacia abajo, no es jalar para recargar */
    if (dy < -8 || Math.abs(e.touches[0].clientX - x0) > dy * 0.6 + 12) ok2 = false;
    if (!ok2 || dy < 0 || sc.scrollTop > 0) { if (ind) ind.style.opacity = 0; return; }
    if (!ind) { ind = document.createElement('div'); ind.style.cssText = 'position:fixed;left:50%;top:calc(env(safe-area-inset-top,0px) + 8px);transform:translateX(-50%);z-index:60;padding:6px 12px;border-radius:999px;background:var(--fill,#eee);color:var(--ink,#111);font:600 13px Inter,sans-serif;pointer-events:none;transition:opacity .15s'; document.body.appendChild(ind); }
    ind.textContent = dy > PULL ? 'Suelta para sincronizar' : 'Jala para sincronizar'; ind.style.opacity = Math.max(0, Math.min(1, (dy - 40) / 60));
  }, { passive: true });
  document.addEventListener('touchend', () => {
    if (ind) { ind.style.opacity = 0; }
    if (sc && ok2 && dy > PULL) { if (clIn() && clOn()) { clSync('manual'); toast('Sincronizando…'); } else { try { persist(); } catch (e) { /* sin almacenamiento */ } location.reload(); } }
    sc = null; dy = 0; ok2 = false;
  }, { passive: true });
})();
async function clSync(why) {
  if (CL.busy || CL.hold || !clOn()) return;
  if (!syncAllowed()) { CL.status = 'demo'; clRefresh(); return; }
  if (typeof navigator !== 'undefined' && navigator.onLine === false) { CL.status = 'offline'; clRefresh(); return; }
  CL.busy = true; CL.status = 'syncing'; clRefresh();
  try {
    for (let i = 0; i < 4; i++) {
      const g = await clFetch('/sync'); if (g.s === 401) return; if (g.s !== 200) throw new Error('http' + g.s);
      const rev = g.j.rev || 0, next = g.j.next || rev + 1, base = clBaseGet(), stale = !CL.st.last || Date.now() - CL.st.last > 80 * 864e5, local = clSnap();
      if (CL.st.v2 && rev > 0 && rev < (CL.st.rev || 0)) throw new Error('rev'); // la nube nunca retrocede
      if (rev === 0) { const p = await clPut(0, local, next); if (p.s === 409) continue; if (p.s !== 200) throw new Error('http' + p.s); clDone(p.j.rev, local); break; }
      /* Un dispositivo sin datos nunca borra ni pisa lo que hay en la nube: se carga la nube (así volver al modo Cloud con un perfil vacío no la vacía) */
      if (rev > 0 && !hasData()) { const rm = await clOpen(g.j.blob, rev); if (hasDataOf(rm)) { clApply(rm); clDone(rev, rm); break; } }
      /* Al volver al modo Cloud, la copia de este dispositivo no reemplaza la de la nube sin preguntar ni verificar el correo */
      if (why === 'mode' && rev > 0 && hasData()) { const rm = await clOpen(g.j.blob, rev); if (clSig(local) !== clSig(rm)) { CL.status = 'idle'; clLocalUp(); return; } clDone(rev, rm); break; }
      let remote = null; if (rev !== CL.st.rev || !base) remote = await clOpen(g.j.blob, rev);
      if (remote && (!base || stale) && hasData() && clSig(clSnap()) !== clSig(remote)) { CL.first = { remote: remote, rev: rev }; CL.status = 'choose'; clFirstSheet(); return; }
      const merged = remote ? (((!base || stale) && !hasData()) ? remote : mergeData(base && !stale ? base : null, local, remote)) : local; /* un perfil vacío (p. ej. inicio rápido) nunca pisa lo que ya hay en la nube */
      if (clSig(merged) !== clSig(local)) clApply(merged);
      const ref = remote || base;
      if (!ref || clSig(merged) !== clSig(ref)) { const p = await clPut(rev, merged, next); if (p.s === 409) continue; if (p.s === 403) { CL.status = p.j && p.j.error === 'wk' ? 'error' : 'demo'; return; } if (p.s !== 200) throw new Error('http' + p.s); clDone(p.j.rev, merged); }
      else clDone(rev, merged);
      break;
    }
  } catch (e) { CL.status = (e && e.name === 'TypeError') ? 'offline' : 'error'; }
  finally { CL.busy = false; clRefresh(); }
}
function clDirty() { if (CL.applying || CL.hold || !clOn() || !syncAllowed()) return; clearTimeout(CL.t); CL.t = setTimeout(() => clSync('edit'), 6000); }
function clWipeRun() {
  const tok = String(Date.now()); let n = 5;
  askConfirm('Borrando en 5 s…', 'Se borrarán los datos de tu nube. Toca Cancelar si fue sin querer.', [], '', 'Cancelar');
  const bk = document.getElementById('alertback'); if (bk) bk.dataset.t = tok;
  const alive = () => { const x = document.getElementById('alertback'); return x && x.dataset.t === tok ? x : null; };
  const iv = setInterval(async () => {
    const x = alive(); if (!x) { clearInterval(iv); return; }
    n -= 1;
    if (n > 0) { const h = x.querySelector('h4'); if (h) h.textContent = 'Borrando en ' + n + ' s…'; return; }
    clearInterval(iv); x.classList.remove('in'); setTimeout(() => x.remove(), 220);
    try {
      const r = await clFetch('/sync', 'DELETE');
      if (r.s === 200) { CL.st.mode = 'local'; CL.st.modeAt = Date.now(); CL.st.last = 0; clSave(); CL.status = 'idle'; clRefresh(); setTimeout(() => askConfirm('Listo', 'Borramos los datos de tu nube. Pasaste al modo Local; lo de este dispositivo sigue intacto.', [], '', 'Entendido'), 300); }
      else if (r.s === 401) { CL.ui = { step: 'email' }; clSheet(); }
      else if (r.s === 403) toast('Tu frase no coincide con la de la cuenta. Cierra sesión y vuelve a entrar con tu frase.');
      else toast('No pudimos borrar tus datos. Inténtalo más tarde.');
    } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); }
  }, 1000);
}
function clLocalUp() {
  CL.st.mode = 'local'; clSave(); clRefresh(); CL.promote = true; CL.fromProf = !!ui.profSheet;
  askConfirm('¿Cargar la copia local como la de la nube?', 'Los datos de este dispositivo reemplazarán tu copia en la nube y en tus otros dispositivos. Primero te enviaremos un código de verificación a tu correo.', [{ label: 'Enviar código', dest: true, fn: async () => {
    try { const r = await clFetch('/sync/confirm', 'POST', { lang: String(resolveLang() || 'es').slice(0, 2) }); if (r.s === 429) { toast('Demasiados intentos. Prueba en una hora.'); CL.promote = false; return; } if (r.s !== 200) { toast('No pudimos enviar el código. Inténtalo más tarde.'); CL.promote = false; return; } } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); CL.promote = false; return; }
    CL.ui = { step: 'replaceauth', err: '' }; clSheet(); } }], '', 'No, seguir en modo local');
}
async function clFirstPick(how) {
  const f = CL.first; if (!f) return; CL.first = null; clClose(); CL.busy = true; CL.status = 'syncing'; clRefresh();
  try {
    if (how === 'remote') { clApply(f.remote); clDone(f.rev, f.remote); }
    else if (how === 'merge') { const m = mergeData(null, clSnap(), f.remote); clApply(m); const p = await clPut(f.rev, m); if (p.s !== 200) throw new Error('http'); clDone(p.j.rev, m); }
    else { CL.busy = false; clLocalUp(); return; }
    toast('Listo, ya está sincronizado');
  } catch (e) { CL.status = 'error'; }
  finally { CL.busy = false; clRefresh(); }
}
function clAgo(t) { const m = Math.round((Date.now() - t) / 60000); return m < 1 ? 'hace un momento' : m < 60 ? 'hace ' + m + ' min' : m < 1440 ? 'hace ' + Math.round(m / 60) + ' h' : 'hace ' + Math.round(m / 1440) + ' d'; }
function clStatusText() {
  if (CL.st.mode !== 'cloud') return 'Modo local: este dispositivo no se sincroniza.';
  if (data && data.demo) return 'Hay un demo cargado: la sincronización está en pausa.';
  return { syncing: 'Sincronizando…', offline: 'Sin conexión. Se reintenta solo.', error: 'No se pudo sincronizar. Se reintenta solo.', login: 'Tu sesión venció. Inicia sesión de nuevo.', choose: 'Falta elegir qué conservar.' }[CL.status] || (CL.st.last ? 'Sincronizado ' + clAgo(CL.st.last) : 'Listo para sincronizar.');
}
function clStatHTML() {
  const bad = CL.status === 'error' || CL.status === 'offline' || CL.status === 'login' || CL.status === 'choose' || CL.status === 'demo', busy = CL.status === 'syncing';
  const lab = busy ? 'Sincronizando…' : bad ? 'Sin sincronizar' : 'Sincronizado', col = bad ? '#FF9500' : 'var(--gt)';
  return '<div class="sub" id="clStat" style="padding:0 4px;margin:12px 0 4px;text-align:center;line-height:1.1"><span style="display:inline-flex;align-items:center;gap:6px;color:' + col + ';font-weight:600">' + RMI(bad ? 'error-warning-fill' : 'checkbox-circle-fill', 20, bad ? '#FF9500' : '#22B573') + lab + '</span><div style="margin-top:-2px;font-size:13px">' + (CL.st.last ? 'Última sincronización · ' + clAgo(CL.st.last) : 'Aún sin sincronizar') + '</div></div>';
}
let clWas = null; /* se fija con el primer refresco */
function clRefresh() { const on = clBeta() && clOn(); if (clWas !== on) { clWas = on; try { renderAll(); } catch (e) { /* aún sin pantalla */ } } clWas = on; try { updGdot(); if (CL._hs !== CL.status) { CL._hs = CL.status; if (on) renderResumen(); } } catch (e) { /* aún sin pantalla */ } const sx = $('#clStat'); if (sx) sx.outerHTML = clStatHTML(); const c = $('#clCard'); if (c) c.outerHTML = clCardHTML(); const d = $('#demoCard'); if (d && typeof demoNoticeHTML === 'function') d.outerHTML = demoNoticeHTML(); }
function clCardHTML() {
  if (!clBeta()) return cloudCardHTML();
  const head = '<div class="crow">' + pcLogo(30) + '<span class="clhr"><span class="betapill b2">B E T A</span>' + (clIn() ? '<button class="cldots" data-act="cl:menu" aria-label="Más opciones">' + RMI('more-fill', 22, 'currentColor') + '</button>' : '') + '</span></div>';
  if (!clIn()) return '<div id="clCard"><div class="scard clt" style="padding:12px 16px 14px">' + PC_CLOUDS + head +
    '<div class="sub" style="font-size:13px;margin:2px 0 4px">Sincroniza tus datos entre dispositivos, cifrados de extremo a extremo. Por invitación durante la marcha blanca; si aún no tienes, te apuntamos a la lista de espera.</div>' + clPriceHTML(false) +
    '<button class="clb" data-act="cl:open">Crear cuenta o entrar</button></div></div>';
  const cloud = CL.st.mode === 'cloud', cool = Math.max(0, Math.ceil((CL_COOL - (Date.now() - (CL.st.modeAt || 0))) / 1000));
  return '<div id="clCard"><div class="scard clt" style="padding:12px 16px 14px">' + PC_CLOUDS + head +
    '<div class="clacc"><div style="min-width:0"><div class="cle">' + esc(CL.st.email || '') + '</div><div class="sub" style="font-size:13px">' + esc(clStatusText()) + '</div></div>' +
    (cloud ? '<button class="clsm" data-act="cl:sync">Sincronizar</button>' : '') + '</div>' +
    '<div class="clseg"><button class="' + (!cloud ? 'on' : '') + '" data-act="cl:mode:local">Local</button><button class="' + (cloud ? 'on' : '') + '" data-act="cl:mode:cloud">Cloud</button></div>' +
    (cool > 0 && CL.st.modeAt ? '<div class="sub" style="font-size:12px;margin-top:6px;text-align:center">Podrás cambiar de modo otra vez en ' + cool + ' s.</div>' : '') + '</div></div>';
}
const clWords = (ws) => '<div class="clw" data-notr>' + ws.map((w, i) => '<span><i>' + (i + 1) + '</i>' + w + '</span>').join('') + '</div>';
const clXS = RMI('close-line', 24, 'currentColor');
function clPageHide() { const o = document.getElementById('clpage'); if (o) o.remove(); }
function clClose() { CL.promote = false; clearInterval(CL.lp); CL.lk = null; clPageHide(); closeSheet(); }
function clPage(o) {
  let w = document.getElementById('clpage');
  if (!w) { w = document.createElement('div'); w.id = 'clpage'; document.body.appendChild(w); }
  w.innerHTML = '<div class="clpg"><button class="clpx" data-act="cl:x" aria-label="Cerrar">' + clXS + '</button><div class="clbrand">' + pcLogo(120) + '<div class="clbt">Tus datos, en todos tus dispositivos</div></div><div class="clpr"><div class="clpb">' + (o.logo === false ? '' : '<div class="clpl">' + pcLogo(34) + '</div>') + '<h1>' + o.title + '</h1><div class="clps">' + o.sub + '</div>' + (o.body || '') + '</div><div class="clpf">' + (o.foot || '') + '</div></div></div>';
}
const clCodeIn = '<div class="clin"><input id="clCode" class="sinput code" inputmode="numeric" autocomplete="one-time-code" maxlength="7" placeholder="000 000"></div>';
function clSheet() {
  clearInterval(CL.tm); CL.lock = false; if ((CL.ui || {}).step !== 'linkwait') clearInterval(CL.lp);
  if ((CL.ui || {}).step === 'tour') { clPageHide(); closeSheet(); clTourShow(CL.ui); return; }
  clTourHide(); closeSheet();
  const u = CL.ui || { step: 'email' }, err = '<div class="clmsg" id="clMsg">' + esc(u.err || '') + '</div>', S = (title, sub, body, foot, logo) => clPage({ title: title, sub: sub, body: body, foot: foot, logo: logo });
  if (u.step === 'email') S('Plata Cloud', 'Escribe tu correo. Si ya tienes acceso, te mandamos un código para entrar, sin contraseña. Si aún no, te apuntamos a la lista de espera.', '<div class="clin"><input id="clEmail" class="sinput" type="email" inputmode="email" autocomplete="email" placeholder="correo@ejemplo.com" value="' + esc(u.email || '') + '"></div>' + err, '<button class="clb" data-act="cl:start">Enviarme el código</button><button class="clb alt" data-act="cl:link">Pedir aprobación desde otro dispositivo</button>');
  else if (u.step === 'nolist') S('Plata Cloud es solo por invitación', 'Todavía estamos en marcha blanca y vamos abriendo cupos de a poco. Este correo aún no tiene acceso, pero puedes apuntarte a la lista de espera y te avisamos cuando te toque.', '<div class="clmail" data-notr>' + esc(u.email) + '</div>' + err, '<button class="clb" data-act="cl:wljoin">Unirme a la lista de espera</button><button class="clb alt" data-act="cl:wlback">Usar otro correo</button>');
  else if (u.step === 'listed') S(u.fresh ? 'Listo, estás en la lista' : 'Ya estás en la lista de espera', 'Te avisaremos por correo cuando abramos tu cupo. No tienes que hacer nada más. Si recibes una invitación, vuelve aquí y entra con este mismo correo.', '<div class="clmail" data-notr>' + esc(u.email) + '</div>', '<button class="clb" data-act="cl:x">Entendido</button><button class="clb alt" data-act="cl:wlback">Usar otro correo</button>');
  else if (u.step === 'linkwait') S('Aprueba desde otro dispositivo', u.code ? 'En tu otro dispositivo apareció un código. Apruébalo solo si es exactamente este:' : 'Abre Plata en un dispositivo donde ya tengas sesión: en Ajustes verás la solicitud. En unos segundos aparecerá un código aquí y allá. También te mandamos un aviso por correo.', (u.code ? '<div class="clmcode" data-notr>' + esc(u.code.slice(0, 3) + ' ' + u.code.slice(3)) + '</div>' : '') + '<div class="clwait"><i></i>' + (u.code ? 'Esperando aprobación…' : 'Esperando al otro dispositivo…') + '</div>' + err, '<button class="clb alt" data-act="cl:linkmail">Usar el código del correo</button><button class="clb alt" data-act="cl:lkcancel">Cancelar</button>');
  else if (u.step === 'code') S('Revisa tu correo', 'Te enviamos un código. Vence en 10 minutos. Si no llega, revisa spam.', '<div class="clmail" data-notr>' + esc(u.email) + '</div>' + clCodeIn + err, '<button class="clb" data-act="cl:verify">Entrar</button><button class="clb alt" data-act="cl:resend">Enviar otro código</button>');
  else if (u.step === 'newkey') S('Tu frase de recuperación', '<span>Estas 12 palabras son la llave de tus datos.</span> <b>Nadie más puede recuperarlas, ni nosotros.</b> <span>Anótalas en papel y guárdalas en un lugar seguro. Si pierdes tus dispositivos y la frase, tus datos de la nube no se podrán abrir.</span>', clWords(u.words), '<button class="clb" data-act="cl:saved">Ya las guardé</button>');
  else if (u.step === 'quiz') S('Confírmala', 'Para asegurarnos de que la anotaste, escribe estas palabras.', u.pos.map((p) => '<div class="clin"><input class="sinput clq" data-p="' + p + '" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" placeholder="Palabra ' + (p + 1) + '"></div>').join('') + err, '<button class="clb" data-act="cl:quiz">Confirmar</button><button class="clb alt" data-act="cl:back">Ver la frase otra vez</button>');
  else if (u.step === 'enter') S('Escribe tu frase', 'Esta cuenta ya existe. Escribe las 12 palabras de tu frase de recuperación para abrir tus datos en este dispositivo.', '<div class="clin"><input id="clPhrase" class="sinput" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" placeholder="palabra1 palabra2 palabra3 …"></div>' + '<div style="font-size:13px;line-height:1.4;color:var(--sec);margin:10px 4px 0">Sabemos que es algo tedioso, pero así tus datos se quedan cifrados y seguros: solo tú puedes abrirlos.</div>' + err, '<button class="clb" data-act="cl:enter">Abrir mis datos</button>');
  else if (u.step === 'show') S('Tu frase de recuperación', 'Guárdala en papel y no la compartas con nadie.', clWords(u.words), '<button class="clb alt" data-act="cl:x">Cerrar</button>');
  else if (u.step === 'delcode') S('Confirma el borrado', 'Enviamos un código a tu correo para confirmar. Escríbelo para borrar tu cuenta de Plata Cloud.', '<div class="clred">Esto borrará tu cuenta y toda tu copia en la nube. No lo hagas si no deseas perder tus datos.</div>' + clCodeIn + err, '<button class="clb dng" data-act="cl:delgo">Borrar mi cuenta</button><button class="clb alt" data-act="cl:x">Cancelar</button>');
  else if (u.step === 'replaceauth') S('¿¡Quién anda ahí!?', 'Enviamos un código a tu correo. Escríbelo para poder reemplazar tu copia en la nube con un archivo de perfil.', clCodeIn + err, '<button class="clb" data-act="cl:rcheck">Continuar</button><button class="clb alt" data-act="cl:x">Cancelar</button>');
  else if (u.step === 'wipeq') S('Confirma que eres tú', 'Para borrar los datos de tu nube, escribe estas palabras de tu frase de recuperación.', u.pos.map((p) => '<div class="clin"><input class="sinput clq" data-p="' + p + '" autocapitalize="none" autocomplete="off" autocorrect="off" spellcheck="false" placeholder="Palabra ' + (p + 1) + '"></div>').join('') + err, '<button class="clb dng" data-act="cl:wipeok">Borrar datos de la nube</button><button class="clb alt" data-act="cl:x">Cancelar</button>');
  else if (u.step === 'wipeauth') S('¿¡Quién anda ahí!?', 'Enviamos un código a tu correo. Escríbelo para borrar tus datos también de la nube.', '<div class="clred">Esto vaciará tu copia en la nube y tus otros dispositivos. No se puede deshacer.</div>' + clCodeIn + err, '<button class="clb dng" data-act="cl:wipego">Borrar mis datos</button><button class="clb alt" data-act="cl:x">Cancelar</button>');
  else if (u.step === 'replacepick') S('Elige tu archivo', 'Código confirmado. Ahora elige el archivo de perfil con el que quieres reemplazar tu copia en la nube.', '<div class="clred">Esto borrará tu última sincronización. No lo hagas si no deseas perder tus datos.</div>' + err, '<button class="clb dng" data-act="cl:rpick">Elegir archivo</button><button class="clb alt" data-act="cl:x">Cancelar</button>');
  else if (u.step === 'preview') S('¿Reconoces a esta persona?', 'Revisa que sea el correcto antes de subirlo. Reemplazará lo que tienes en la nube.', clPrevHTML((CL.pend || {}).obj || {}, (CL.pend || {}).meta) + err, (CL.promote ? '<button class="clb" data-act="cl:rgo">Sí, subir esta copia</button><button class="clb alt" data-act="cl:x">Cancelar</button>' : '<button class="clb" data-act="cl:rgo">Sí, subir este archivo</button><button class="clb alt" data-act="cl:rother">Elegir otro archivo</button><button class="clb alt" data-act="cl:rback">Cancelar</button>'));
  else if (u.step === 'done') S('Listo', 'Tu cuenta está lista. Tus datos se sincronizan cifrados entre tus dispositivos.', '', '<button class="clb" data-act="cl:x">Entendido</button>');
  if (u.step === 'newkey') {
    const b = document.querySelector('[data-act="cl:saved"]'), x = document.querySelector('#clpage .clpx'); let n = 5;
    if (b && x) {
      CL.lock = true; x.style.opacity = '.4'; b.classList.add('wait'); b.textContent = 'Ya las guardé (' + n + ')';
      CL.tm = setInterval(() => { n--; if (n > 0) { b.textContent = 'Ya las guardé (' + n + ')'; return; } clearInterval(CL.tm); CL.lock = false; b.textContent = 'Ya las guardé'; b.classList.remove('wait'); x.style.opacity = ''; }, 1000);
    }
  }
}
function clFirstSheet() {
  const ic = (n) => RMI(n, 26, '#fff');
  const opt = (a, col, d, t, sub, rec) => '<button class="clopt" data-act="cl:f:' + a + '"><span class="clot" style="background:' + col + '">' + ic(d) + '</span><span><b>' + t + (rec ? '<i>Recomendado</i>' : '') + '</b><span class="s">' + sub + '</span></span></button>';
  clPage({ title: '¿Qué conservamos?', sub: 'Tu cuenta ya tiene datos en la nube y este dispositivo también. Elige cómo seguir.', logo: true,
    body: '<div style="margin-top:12px">' +
      opt('merge', '#22B573', 'git-merge-line', 'Combinar los dos', 'Junta lo de este dispositivo y lo de la nube. Es lo más seguro.', true) +
      opt('remote', '#4C8DF6', 'cloud-line', 'Quedarme con la nube', 'Reemplaza los datos de este dispositivo.') +
      opt('local', '#B98AE6', 'smartphone-line', 'Quedarme con este dispositivo', 'Reemplaza la copia de la nube.') + '</div>' });
}
const clMsg = (t) => { if (CL.ui) CL.ui.err = t; const m = $('#clMsg'); if (m) m.textContent = t || ''; };
async function clAuthDone(isNew) {
  CL.st.mode = 'cloud'; CL.st.modeAt = 0; clSave();
  if (!isNew && $('#welcome') && !hasData()) { clClose(); wcloudGo(); return; } /* desde la bienvenida: carga tu nube o inicia el recorrido, sin volver a la pantalla inicial */
  if (isNew) { CL.hold = true; CL.ui = { step: 'tour', i: 0 }; clSheet(); clRefresh(); return; }
  CL.ui = { step: 'done' }; clSheet(); clRefresh(); setTimeout(() => clSync('first'), 300);
}
function clTourEnd() { CL.hold = false; clTourHide(); if (CL.fromProf) { CL.fromProf = false; openProfile(); } else clClose(); clRefresh(); setTimeout(() => clSync('tour'), 300); }
function clUpDone(obj, rev, msg) { clApply(obj); stampSaved(); ui.dirty = 0; try { persist(); } catch (e) { /* sin almacenamiento */ } clDone(rev, obj); toast(msg); }
function clWipeAsk(a, run) {
  askConfirm(a === 'wipe' ? '¿Borrar todos tus datos?' : '¿Borrar datos y volver al inicio?', 'Estás en modo Cloud: se vaciará también tu copia en la nube y en tus otros dispositivos. Primero te enviaremos un código de verificación a tu correo. Guarda tu archivo de perfil antes si quieres conservarlos.', [{ label: 'Enviar código', dest: true, fn: async () => {
    try { const r = await clFetch('/sync/confirm', 'POST', { lang: String(resolveLang() || 'es').slice(0, 2) }); if (r.s === 429) { toast('Demasiados intentos. Prueba en una hora.'); return; } if (r.s !== 200) { toast('No pudimos enviar el código. Inténtalo más tarde.'); return; } } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); return; }
    CL.wipe = run; CL.fromProf = false; CL.ui = { step: 'wipeauth', err: '' }; clSheet(); } }]);
}
async function clReplace(obj, code) {
  const g = await clFetch('/sync'), rev = (g.j && g.j.rev) || 0, next = (g.j && g.j.next) || rev + 1;
  const blob = await PCC.seal(await clKey(), obj, next);
  const r = await clFetch('/sync', 'PUT', { base: rev, next: next, blob: blob, v: 2, dev: syncDevice().plat, demo: false, replace: true, code: code || undefined });
  if (r.s === 200) CL.st.v2 = 1;
  return r;
}
async function clFileChosen(f) {
  let obj, meta = {}; try { const raw = JSON.parse(await f.text()); meta = (raw && raw.meta) || {}; obj = migrate(raw); } catch (e) { toast('No pude leer ese archivo de perfil'); return; }
  meta = { at: Number(meta.at) || f.lastModified || 0, plat: typeof meta.plat === 'string' ? meta.plat.slice(0, 40) : '' };
  if (obj.demo) { toast('Ese archivo es de una demostración y no se puede subir.'); return; }
  obj.demo = false;
  const pv = CL.ui && CL.ui.step === 'preview' ? (CL.pend || {}) : null;
  if (pv || CL.loadMode === 'tour' || !CL.st.rev || (CL.ui && CL.ui.step === 'replacepick')) { CL.pend = pv ? { obj: obj, meta: meta, mode: pv.mode, code: pv.code, tourI: pv.tourI } : { obj: obj, meta: meta, mode: CL.loadMode, code: (CL.ui || {}).code, tourI: (CL.ui || {}).i }; CL.ui = { step: 'preview', err: '' }; clSheet(); return; }
  toast('Primero confirma tu correo.');
}
function clDateLbl(t) {
  if (!t) return 'Sin fecha';
  const d = new Date(t), dias = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'], meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  let h = d.getHours(); const ap = h >= 12 ? 'p. m.' : 'a. m.'; h = h % 12 || 12;
  return dias[d.getDay()] + ' ' + d.getDate() + ' ' + meses[d.getMonth()] + ' ' + d.getFullYear() + ', ' + h + ':' + String(d.getMinutes()).padStart(2, '0') + ' ' + ap;
}
const clIco = (k) => RMI(k === 'clock' ? 'time-line' : k === 'desk' ? 'computer-line' : 'smartphone-line', 20, 'currentColor');
const clMetaRow = (k, v) => '<div class="clpv-r"><i>' + clIco(k) + '</i><span>' + v + '</span></div>';
function clPrevHTML(o, meta) {
  const st = o.settings || {}, nm = [st.first, st.last].map((x) => (x || '').trim()).filter(Boolean).join(' ') || (st.nick || '').trim() || 'Sin nombre';
  const ph = /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+\/=]+$/.test(st.photo || '') ? st.photo : '';
  const accs = (o.accounts || []).filter((a) => !a.hid), mon = [...new Set(accs.map((a) => a.cur || 'USD'))];
  const sc = (o.settings || {}).currency, main = mon.indexOf(sc) >= 0 ? sc : (mon.slice().sort((x, y) => accs.filter((q) => (q.cur || 'USD') === y).length - accs.filter((q) => (q.cur || 'USD') === x).length)[0] || ''), more = Math.max(0, mon.length - 1);
  let bal = 0; try { bal = accs.reduce((t, a) => t + usd(a.balance, a.cur), 0); } catch (e) { /* moneda desconocida */ }
  const cell = (l, v) => '<div><span class="sub">' + l + '</span><b>' + v + '</b></div>';
  return '<div class="clprev"><div class="clpv-card"><div class="clpv-h">' + avatarHTML(52, ph || '', true) + '<div><b data-notr>' + esc(nm) + '</b>' + '' + '</div></div>' +
    '<div class="stats clpv-s">' + cell('Balance actual', fmt(bal)) + cell('Cuentas', accs.length) + cell('Moneda principal', esc(main || '—') + (more ? '<small>' + (more === 1 ? 'y una más' : 'y ' + more + ' más') + '</small>' : '')) + '</div>' +
    '<div class="clpv-m">' + clMetaRow(/escritorio/.test((meta || {}).plat || '') ? 'desk' : 'phone', 'Guardado por última vez en <b>' + esc((meta || {}).plat || 'una plataforma no indicada') + '</b>') + clMetaRow('clock', clDateLbl((meta || {}).at)) + '</div>' + (anRead(o) ? '<div class="clpv-an">' + anNoteHTML(anRead(o), '', 1) + '</div>' : '') + '</div>' + (anRead(o) ? anNoteHTML(anRead(o), 'pv', 2) : '') + '<div class="clpv-f">' + RMI('lock-unlock-line', 15, 'currentColor') + 'Esta vista previa se abre solo en tu dispositivo y solo después de verificar tu correo, para que confirmes que este archivo es tuyo. <a class="clk" href="https://plataapp.net/transparencia" target="_blank" rel="noopener">Ver más…</a></div></div>';
}
async function clFileGo() {
  const P = CL.pend; if (!P) return; const obj = P.obj;
  if (P.mode === 'tour' || !CL.st.rev) {
    try { const r = await clReplace(obj, ''); if (r.s !== 200) throw new Error('http'); CL.pend = null; clUpDone(obj, r.j.rev, 'Archivo de perfil cargado'); } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); return; }
    if (P.mode === 'tour') clTourEnd(); else { clPageHide(); closeSheet(); }
    return;
  }
  try {
    const r = await clReplace(obj, P.code);
    if (r.s === 400) { clMsg('Código incorrecto o vencido. Vuelve a empezar.'); return; }
    if (r.s !== 200) throw new Error('http');
    CL.pend = null; if (CL.promote) { CL.promote = false; CL.st.mode = 'cloud'; CL.st.modeAt = Date.now(); clSave(); } clUpDone(obj, r.j.rev, 'Archivo cargado y copia reemplazada');
    clPageHide(); if (CL.fromProf) { CL.fromProf = false; openProfile(); } else closeSheet();
  } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); }
}
function clTourHide() { const o = document.getElementById('cltour'); if (o) o.remove(); }
function clTourShow(u) {
  const T = [['Bienvenido a Plata Cloud', 'Tu cuenta está lista. Tus datos se cifran en tu dispositivo antes de salir: nadie más puede leerlos, ni nosotros.'],
    ['Local o Cloud', 'En modo Local tus datos se quedan solo en este dispositivo. En modo Cloud se sincronizan entre todos los que uses. Puedes cambiar de modo cuando quieras desde tu perfil.'],
    ['Tu frase de recuperación', 'Es la única forma de abrir tus datos en un dispositivo nuevo. Si no la guardaste, puedes verla en el menú de tres puntos de tu perfil.'],
    ['Tus datos', hasData() ? 'Encontramos datos en este dispositivo. Se subirán a tu nube, cifrados, para que los tengas en todos tus dispositivos.' : 'Tu nube está vacía. Si tienes un archivo de perfil guardado, puedes cargarlo ahora.']];
  const i = u.i || 0, last = i === 3, svg = (PC_CLOUDS.match(/<svg[\s\S]*?<\/svg>/) || [''])[0].replace(/ style="[^"]*"/, '');
  const clouds = [[150, 6, 46, .3, 0], [100, 22, 70, .2, -22], [190, 40, 90, .24, -40], [90, 58, 58, .18, -12], [140, 76, 80, .26, -55], [80, 90, 64, .16, -30]].map((c) => '<span class="cltc" style="top:' + c[1] + '%;width:' + c[0] + 'px;opacity:' + c[3] + ';animation-duration:' + c[2] + 's;animation-delay:' + c[4] + 's">' + svg + '</span>').join('');
  const dots = '<div class="cldots2">' + T.map((x, k) => '<i class="' + (k === i ? 'on' : '') + '"></i>').join('') + '</div>';
  const btns = !last ? '<button class="clb" data-act="cl:next">Siguiente</button>'
    : hasData() ? '<button class="clb" data-act="cl:tourend">Subir mis datos</button><button class="clb alt" data-act="cl:tourload">Cargar un archivo de perfil en su lugar</button>'
      : '<button class="clb" data-act="cl:tourwiz">Configurar mi Plata</button><button class="clb alt" data-act="cl:tourload">Cargar archivo de perfil</button>';
  const st = (data && data.settings) || {}, nick = (st.nick || st.first || '').trim(), g = st.gender;
  const hello = g === 'm' ? 'Bienvenido a la nube' : g === 'f' ? 'Bienvenida a la nube' : 'Te damos la bienvenida a la nube';
  const ck = RMI('check-line', 20, '#fff');
  const feats = ['Tus datos al día en todos tus dispositivos', 'Cifrado de punta a punta: ni nosotros podemos leerlos', 'Sin contraseñas: solo un código en tu correo', 'Opcional: vuelve a Local cuando quieras'].map((f) => '<div class="cltf"><i>' + ck + '</i><span>' + f + '</span></div>').join('');
  const body = i === 0
    ? '<div class="cltb" key="0">' + pcLogo(46) + '<h3><span>' + hello + '</span>' + (nick ? '<span data-notr>, </span><span data-notr class="cltn">' + esc(nick) + '</span>' : '') + '</h3><div class="cltp">Gracias por unirte a Plata Cloud. Ahora:</div><div class="cltfs">' + feats + '</div></div>' + dots + btns
    : '<div class="cltb" key="' + i + '">' + pcLogo(46) + '<h3>' + T[i][0] + '</h3><div class="cltp">' + T[i][1] + '</div></div>' + dots + btns;
  let o = document.getElementById('cltour');
  if (o && o.querySelector('.cltc2')) { o.querySelector('.cltc2').innerHTML = body; const k = o.querySelector('.cltskip'); if (k && last) k.remove(); return; }
  if (!o) { o = document.createElement('div'); o.id = 'cltour'; document.body.appendChild(o); }
  o.innerHTML = '<div class="cltwin"><div class="cltsky">' + clouds + '</div>' + (last ? '' : '<button class="cltskip" data-act="cl:tourend">Omitir</button>') + '<div class="cltc2">' + body + '</div></div>';
}

function clLinkWait() {
  clearInterval(CL.lp);
  CL.lp = setInterval(async () => {
    const u = CL.ui; if (!u || u.step !== 'linkwait' || CL.lpBusy) { if (!u || u.step !== 'linkwait') clearInterval(CL.lp); return; }
    const back = (msg) => { clearInterval(CL.lp); CL.lk = null; CL.ui = { step: 'email', email: u.email, err: msg }; clSheet(); };
    if (Date.now() - u.t0 > 610000) { back('La solicitud venció. Inténtalo otra vez.'); return; }
    CL.lpBusy = true;
    try {
      const r = await clFetch('/link/poll', 'POST', { email: u.email, rid: u.rid }); if (r.s !== 200) return;
      const st = r.j.st;
      if (st === 'p' || st === 'n') return;
      if (st === 'd') { back('Rechazaron la solicitud desde el otro dispositivo.'); return; }
      if (st === 'x') { back('No hay un dispositivo que pueda aprobarla. Usa el código del correo.'); return; }
      if (st === 'c') { // el otro dispositivo ya se comprometió: recién ahora elegimos nuestro aleatorio
        if (!u.c) { u.c = r.j.c; u.nn = PCC.rnd(16); }
        if (u.c !== r.j.c) { back('La solicitud cambió a mitad de camino. Inténtalo otra vez.'); return; }
        await clFetch('/link/poll', 'POST', { email: u.email, rid: u.rid, step: 'nonce', nn: u.nn }); return;
      }
      if (!u.nn || !(await PCC.linkVerify(u.c, r.j.apub, r.j.na))) { back('No pudimos verificar al otro dispositivo. Usa el código del correo.'); return; }
      if (st === 'r') { if (!u.code) { u.apub = r.j.apub; u.code = await PCC.linkCode(u.pub, r.j.apub, r.j.na, u.nn); clSheet(); } return; }
      if (st !== 'a' || r.j.apub !== u.apub) { back('No pudimos verificar la aprobación. Usa el código del correo.'); return; }
      clearInterval(CL.lp);
      const seed = await PCC.linkOpen(CL.lk, r.j.apub, r.j.iv, r.j.ct), kc = await PCC.keyCheck(seed);
      if (kc !== r.j.kc) { back('No pudimos verificar la aprobación. Usa el código del correo.'); return; }
      if (CL.st.email && CL.st.email !== u.email) clWipe();
      CL.st.tok = r.j.token; CL.st.email = u.email; CL.st.seed = PCC.b64u(seed); CL.st.kc = kc; CL.key = null; clSave(); CL.lk = null;
      await clAuthDone();
    } catch (e) { /* se reintenta en el siguiente ciclo */ } finally { CL.lpBusy = false; }
  }, 2000);
}
const clLinkRefresh = () => { try { renderWebCloud(); if (ui.tab === 'resumen') renderResumen(); } catch (e) { /* aún sin pantalla */ } };
async function clLinkCheck() {
  if (!clIn() || document.hidden || !clBeta() || CL.lkBusy) return;
  CL.lkBusy = true; clearTimeout(CL.lkT);
  try {
    const r = await clFetch('/link/pending'); if (r.s !== 200) return;
    const q = r.j.req;
    if (!q) { if (CL.link) { CL.link = null; clLinkRefresh(); } return; }
    if (!CL.link || CL.link.pub !== q.pub) {
      CL.link = { pub: q.pub, plat: q.plat, tz: q.tz, t: q.t, code: '', st: q.st };
      if (q.st === 'p') {
        const x = await PCC.linkCommit();
        const c = await clFetch('/link/step', 'POST', { step: 'commit', pub: q.pub, c: x.c });
        if (c.s === 200) Object.assign(CL.link, { priv: x.priv, apub: x.apub, na: x.na, st: 'c' });
      }
      clLinkRefresh();
    } else if (CL.link.priv && CL.link.st === 'c' && q.st === 'n' && q.nn) {
      const v = await clFetch('/link/step', 'POST', { step: 'reveal', pub: q.pub, apub: CL.link.apub, na: CL.link.na });
      if (v.s === 200) { CL.link.code = await PCC.linkCode(q.pub, CL.link.apub, CL.link.na, q.nn); CL.link.st = 'r'; clLinkRefresh(); }
    }
  } catch (e) { /* sin red */ } finally {
    CL.lkBusy = false;
    if (CL.link && CL.link.priv && CL.link.st === 'c') CL.lkT = setTimeout(clLinkCheck, 1500); // mientras se arma el código, más seguido
  }
}
async function clLinkAnswer(ok, seen) {
  const L = CL.link; if (!L) return;
  if (ok && (!seen || seen !== L || seen.code !== L.code)) { toast('La solicitud cambió. Revisa el código otra vez.'); clLinkRefresh(); return; } // se aprueba solo la solicitud cuyo código vio la persona
  try {
    let body = { step: 'answer', pub: L.pub, ok: false };
    if (ok) { if (L.st !== 'r' || !L.priv) return; const x = await PCC.linkSeal(L.priv, L.pub, PCC.unb64u(CL.st.seed)); body = { step: 'answer', pub: L.pub, ok: true, iv: x.iv, ct: x.ct }; }
    const r = await clFetch('/link/step', 'POST', body);
    if (r.s === 200) { CL.link = null; clLinkRefresh(); toast(ok ? 'Dispositivo aprobado' : 'Solicitud rechazada'); }
    else if (r.s === 404 || r.s === 409) { CL.link = null; clLinkRefresh(); toast('La solicitud ya venció'); }
    else toast('No pudimos conectar. Inténtalo más tarde.');
  } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); }
}
const CLTZ = 'AD=Europe/Andorra;AE=Asia/Dubai;AF=Asia/Kabul;AG=America/Antigua;AI=America/Anguilla;AL=Europe/Tirane;AM=Asia/Yerevan;AO=Africa/Luanda;AQ=Antarctica/McMurdo,Antarctica/Casey,Antarctica/Davis,Antarctica/DumontDUrville,Antarctica/Mawson,Antarctica/Palmer,Antarctica/Rothera,Antarctica/Syowa,Antarctica/Troll,Antarctica/Vostok;AR=America/Argentina/Buenos_Aires,America/Argentina/Cordoba,America/Argentina/Salta,America/Argentina/Jujuy,America/Argentina/Tucuman,America/Argentina/Catamarca,America/Argentina/La_Rioja,America/Argentina/San_Juan,America/Argentina/Mendoza,America/Argentina/San_Luis,America/Argentina/Rio_Gallegos,America/Argentina/Ushuaia;AS=Pacific/Pago_Pago;AT=Europe/Vienna;AU=Australia/Lord_Howe,Antarctica/Macquarie,Australia/Hobart,Australia/Melbourne,Australia/Sydney,Australia/Broken_Hill,Australia/Brisbane,Australia/Lindeman,Australia/Adelaide,Australia/Darwin,Australia/Perth,Australia/Eucla;AW=America/Aruba;AX=Europe/Mariehamn;AZ=Asia/Baku;BA=Europe/Sarajevo;BB=America/Barbados;BD=Asia/Dhaka;BE=Europe/Brussels;BF=Africa/Ouagadougou;BG=Europe/Sofia;BH=Asia/Bahrain;BI=Africa/Bujumbura;BJ=Africa/Porto-Novo;BL=America/St_Barthelemy;BM=Atlantic/Bermuda;BN=Asia/Brunei;BO=America/La_Paz;BQ=America/Kralendijk;BR=America/Noronha,America/Belem,America/Fortaleza,America/Recife,America/Araguaina,America/Maceio,America/Bahia,America/Sao_Paulo,America/Campo_Grande,America/Cuiaba,America/Santarem,America/Porto_Velho,America/Boa_Vista,America/Manaus,America/Eirunepe,America/Rio_Branco;BS=America/Nassau;BT=Asia/Thimphu;BW=Africa/Gaborone;BY=Europe/Minsk;BZ=America/Belize;CA=America/St_Johns,America/Halifax,America/Glace_Bay,America/Moncton,America/Goose_Bay,America/Blanc-Sablon,America/Toronto,America/Iqaluit,America/Atikokan,America/Winnipeg,America/Resolute,America/Rankin_Inlet,America/Regina,America/Swift_Current,America/Edmonton,America/Cambridge_Bay,America/Inuvik,America/Vancouver,America/Creston,America/Dawson_Creek,America/Fort_Nelson,America/Whitehorse,America/Dawson;CC=Indian/Cocos;CD=Africa/Kinshasa,Africa/Lubumbashi;CF=Africa/Bangui;CG=Africa/Brazzaville;CH=Europe/Zurich;CI=Africa/Abidjan;CK=Pacific/Rarotonga;CL=America/Santiago,America/Coyhaique,America/Punta_Arenas,Pacific/Easter;CM=Africa/Douala;CN=Asia/Shanghai,Asia/Urumqi;CO=America/Bogota;CR=America/Costa_Rica;CU=America/Havana;CV=Atlantic/Cape_Verde;CW=America/Curacao;CX=Indian/Christmas;CY=Asia/Nicosia,Asia/Famagusta;CZ=Europe/Prague;DE=Europe/Berlin,Europe/Busingen;DJ=Africa/Djibouti;DK=Europe/Copenhagen;DM=America/Dominica;DO=America/Santo_Domingo;DZ=Africa/Algiers;EC=America/Guayaquil,Pacific/Galapagos;EE=Europe/Tallinn;EG=Africa/Cairo;EH=Africa/El_Aaiun;ER=Africa/Asmara;ES=Europe/Madrid,Africa/Ceuta,Atlantic/Canary;ET=Africa/Addis_Ababa;FI=Europe/Helsinki;FJ=Pacific/Fiji;FK=Atlantic/Stanley;FM=Pacific/Chuuk,Pacific/Pohnpei,Pacific/Kosrae;FO=Atlantic/Faroe;FR=Europe/Paris;GA=Africa/Libreville;GB=Europe/London;GD=America/Grenada;GE=Asia/Tbilisi;GF=America/Cayenne;GG=Europe/Guernsey;GH=Africa/Accra;GI=Europe/Gibraltar;GL=America/Nuuk,America/Danmarkshavn,America/Scoresbysund,America/Thule;GM=Africa/Banjul;GN=Africa/Conakry;GP=America/Guadeloupe;GQ=Africa/Malabo;GR=Europe/Athens;GS=Atlantic/South_Georgia;GT=America/Guatemala;GU=Pacific/Guam;GW=Africa/Bissau;GY=America/Guyana;HK=Asia/Hong_Kong;HN=America/Tegucigalpa;HR=Europe/Zagreb;HT=America/Port-au-Prince;HU=Europe/Budapest;ID=Asia/Jakarta,Asia/Pontianak,Asia/Makassar,Asia/Jayapura;IE=Europe/Dublin;IL=Asia/Jerusalem;IM=Europe/Isle_of_Man;IN=Asia/Kolkata;IO=Indian/Chagos;IQ=Asia/Baghdad;IR=Asia/Tehran;IS=Atlantic/Reykjavik;IT=Europe/Rome;JE=Europe/Jersey;JM=America/Jamaica;JO=Asia/Amman;JP=Asia/Tokyo;KE=Africa/Nairobi;KG=Asia/Bishkek;KH=Asia/Phnom_Penh;KI=Pacific/Tarawa,Pacific/Kanton,Pacific/Kiritimati;KM=Indian/Comoro;KN=America/St_Kitts;KP=Asia/Pyongyang;KR=Asia/Seoul;KW=Asia/Kuwait;KY=America/Cayman;KZ=Asia/Almaty,Asia/Qyzylorda,Asia/Qostanay,Asia/Aqtobe,Asia/Aqtau,Asia/Atyrau,Asia/Oral;LA=Asia/Vientiane;LB=Asia/Beirut;LC=America/St_Lucia;LI=Europe/Vaduz;LK=Asia/Colombo;LR=Africa/Monrovia;LS=Africa/Maseru;LT=Europe/Vilnius;LU=Europe/Luxembourg;LV=Europe/Riga;LY=Africa/Tripoli;MA=Africa/Casablanca;MC=Europe/Monaco;MD=Europe/Chisinau;ME=Europe/Podgorica;MF=America/Marigot;MG=Indian/Antananarivo;MH=Pacific/Majuro,Pacific/Kwajalein;MK=Europe/Skopje;ML=Africa/Bamako;MM=Asia/Yangon;MN=Asia/Ulaanbaatar,Asia/Hovd;MO=Asia/Macau;MP=Pacific/Saipan;MQ=America/Martinique;MR=Africa/Nouakchott;MS=America/Montserrat;MT=Europe/Malta;MU=Indian/Mauritius;MV=Indian/Maldives;MW=Africa/Blantyre;MX=America/Mexico_City,America/Cancun,America/Merida,America/Monterrey,America/Matamoros,America/Chihuahua,America/Ciudad_Juarez,America/Ojinaga,America/Mazatlan,America/Bahia_Banderas,America/Hermosillo,America/Tijuana;MY=Asia/Kuala_Lumpur,Asia/Kuching;MZ=Africa/Maputo;NA=Africa/Windhoek;NC=Pacific/Noumea;NE=Africa/Niamey;NF=Pacific/Norfolk;NG=Africa/Lagos;NI=America/Managua;NL=Europe/Amsterdam;NO=Europe/Oslo;NP=Asia/Kathmandu;NR=Pacific/Nauru;NU=Pacific/Niue;NZ=Pacific/Auckland,Pacific/Chatham;OM=Asia/Muscat;PA=America/Panama;PE=America/Lima;PF=Pacific/Tahiti,Pacific/Marquesas,Pacific/Gambier;PG=Pacific/Port_Moresby,Pacific/Bougainville;PH=Asia/Manila;PK=Asia/Karachi;PL=Europe/Warsaw;PM=America/Miquelon;PN=Pacific/Pitcairn;PR=America/Puerto_Rico;PS=Asia/Gaza,Asia/Hebron;PT=Europe/Lisbon,Atlantic/Madeira,Atlantic/Azores;PW=Pacific/Palau;PY=America/Asuncion;QA=Asia/Qatar;RE=Indian/Reunion;RO=Europe/Bucharest;RS=Europe/Belgrade;RU=Europe/Kaliningrad,Europe/Moscow,Europe/Kirov,Europe/Volgograd,Europe/Astrakhan,Europe/Saratov,Europe/Ulyanovsk,Europe/Samara,Asia/Yekaterinburg,Asia/Omsk,Asia/Novosibirsk,Asia/Barnaul,Asia/Tomsk,Asia/Novokuznetsk,Asia/Krasnoyarsk,Asia/Irkutsk,Asia/Chita,Asia/Yakutsk,Asia/Khandyga,Asia/Vladivostok,Asia/Ust-Nera,Asia/Magadan,Asia/Sakhalin,Asia/Srednekolymsk,Asia/Kamchatka,Asia/Anadyr;RW=Africa/Kigali;SA=Asia/Riyadh;SB=Pacific/Guadalcanal;SC=Indian/Mahe;SD=Africa/Khartoum;SE=Europe/Stockholm;SG=Asia/Singapore;SH=Atlantic/St_Helena;SI=Europe/Ljubljana;SJ=Arctic/Longyearbyen;SK=Europe/Bratislava;SL=Africa/Freetown;SM=Europe/San_Marino;SN=Africa/Dakar;SO=Africa/Mogadishu;SR=America/Paramaribo;SS=Africa/Juba;ST=Africa/Sao_Tome;SV=America/El_Salvador;SX=America/Lower_Princes;SY=Asia/Damascus;SZ=Africa/Mbabane;TC=America/Grand_Turk;TD=Africa/Ndjamena;TF=Indian/Kerguelen;TG=Africa/Lome;TH=Asia/Bangkok;TJ=Asia/Dushanbe;TK=Pacific/Fakaofo;TL=Asia/Dili;TM=Asia/Ashgabat;TN=Africa/Tunis;TO=Pacific/Tongatapu;TR=Europe/Istanbul;TT=America/Port_of_Spain;TV=Pacific/Funafuti;TW=Asia/Taipei;TZ=Africa/Dar_es_Salaam;UA=Europe/Simferopol,Europe/Kyiv;UG=Africa/Kampala;UM=Pacific/Midway,Pacific/Wake;US=America/New_York,America/Detroit,America/Kentucky/Louisville,America/Kentucky/Monticello,America/Indiana/Indianapolis,America/Indiana/Vincennes,America/Indiana/Winamac,America/Indiana/Marengo,America/Indiana/Petersburg,America/Indiana/Vevay,America/Chicago,America/Indiana/Tell_City,America/Indiana/Knox,America/Menominee,America/North_Dakota/Center,America/North_Dakota/New_Salem,America/North_Dakota/Beulah,America/Denver,America/Boise,America/Phoenix,America/Los_Angeles,America/Anchorage,America/Juneau,America/Sitka,America/Metlakatla,America/Yakutat,America/Nome,America/Adak,Pacific/Honolulu;UY=America/Montevideo;UZ=Asia/Samarkand,Asia/Tashkent;VA=Europe/Vatican;VC=America/St_Vincent;VE=America/Caracas;VG=America/Tortola;VI=America/St_Thomas;VN=Asia/Ho_Chi_Minh;VU=Pacific/Efate;WF=Pacific/Wallis;WS=Pacific/Apia;YE=Asia/Aden;YT=Indian/Mayotte;ZA=Africa/Johannesburg;ZM=Africa/Lusaka;ZW=Africa/Harare';
let clTzMap = null;
function clWhere(tz) { /* "Ciudad, País" en el idioma de la app */
  if (!tz) return '';
  const city = tz.split('/').pop().replace(/_/g, ' ');
  if (!clTzMap) { clTzMap = {}; CLTZ.split(';').forEach((r) => { const q = r.split('='); q[1].split(',').forEach((z) => { clTzMap[z] = q[0]; }); }); }
  const cc = clTzMap[tz]; let name = '';
  if (cc) { try { name = new Intl.DisplayNames([String(resolveLang() || 'es')], { type: 'region' }).of(cc) || ''; } catch (e) { /* sin nombres de región */ } }
  return name ? city + ', ' + name : city;
}
const phraseLang = () => (String(resolveLang() || 'es').slice(0, 2) === 'es' ? 'es' : 'en'); // idioma de las palabras de la frase
const clPlatIco = (pl) => { const o = String(pl || '').split(' · ')[0]; return { os: o, ic: o === 'iPhone' || o === 'iPad' ? 'apple-line' : o === 'Android' ? 'android-line' : o === 'Mac' ? 'macbook-line' : o === 'Windows' ? 'windows-line' : o === 'Linux' ? 'computer-line' : 'smartphone-line' }; };
function clLinkHTML() {
  const L = CL.link; if (!clIn() || !L) return '';
  let hm = ''; try { hm = new Date(L.t).toLocaleTimeString(String(resolveLang() || 'es'), { hour: 'numeric', minute: '2-digit' }); } catch (e) { /* sin formato */ }
  const pl = clPlatIco(L.plat), wh = clWhere(L.tz), it = (ic, t) => '<span class="cli">' + RMI(ic, 15, 'currentColor') + '<span data-notr>' + esc(t) + '</span></span>';
  const code = L.code ? '<span class="cllc"><span>Código</span> <b data-notr>' + esc(L.code.slice(0, 3) + ' ' + L.code.slice(3)) + '</b></span>' : '<span class="cllc"><span>' + (L.priv ? 'Calculando código…' : 'Otro dispositivo está respondiendo') + '</span></span>';
  return '<div class="cllk"><div class="cllh"><b>Solicitud de inicio de sesión</b>' + code + '</div><div class="cllm">' + it(pl.ic, pl.os) + (wh ? it('global-line', wh) : '') + (hm ? it('time-line', hm) : '') + '</div><div class="cllb"><button class="clsm" data-act="cl:lkno">Rechazar</button>' + (L.code ? '<button class="clsm ok" data-act="cl:lkok">Aprobar</button>' : '') + '</div></div>';
}
async function clAct(arg, el) {
  const p = arg.split(':'), a = p[0], u = CL.ui || (CL.ui = { step: 'email' });
  if (a === 'x') { if (CL.lock) return; clearInterval(CL.lp); CL.lk = null; if (u.step === 'tour') { clTourEnd(); return; } clPageHide(); if (CL.fromProf) { CL.fromProf = false; openProfile(); } else closeSheet(); }
  else if (a === 'next') { u.i = (u.i || 0) + 1; clSheet(); }
  else if (a === 'tourend') clTourEnd();
  else if (a === 'tourwiz') { CL.hold = false; clTourHide(); clClose(); clRefresh(); if ($('#welcome')) wStart(true); else clTourEnd(); }
  else if (a === 'tourload') { CL.loadMode = 'tour'; $('#clfile').click(); }
  else if (a === 'load') {
    CL.fromProf = !!ui.profSheet; CL.loadMode = 'replace';
    if (!CL.st.rev) askConfirm('Cargar archivo de perfil', 'Esto reemplazará los datos de este dispositivo.', [{ label: 'Elegir archivo', dest: true, fn: () => { $('#clfile').click(); } }]);
    else askConfirm('Cargar archivo de perfil', 'Esto reemplazará los datos de este dispositivo y tu copia en la nube. Primero te enviaremos un código de verificación a tu correo.', [{ label: 'Enviar código', dest: true, fn: async () => {
      try { const r = await clFetch('/sync/confirm', 'POST', { lang: String(resolveLang() || 'es').slice(0, 2) }); if (r.s === 429) { toast('Demasiados intentos. Prueba en una hora.'); return; } if (r.s !== 200) { toast('No pudimos enviar el código. Inténtalo más tarde.'); return; } } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); return; }
      CL.ui = { step: 'replaceauth', err: '' }; clSheet(); } }]);
  }
  else if (a === 'rcheck') {
    const code = (($('#clCode') || {}).value || '').replace(/\s/g, ''); if (!/^\d{6}$/.test(code)) { clMsg('Escribe el código completo.'); return; }
    el.disabled = true; try {
      const r = await clFetch('/sync/check', 'POST', { code: code });
      if (r.s === 400) { clMsg('Código incorrecto o vencido.'); el.disabled = false; return; }
      if (r.s !== 200) { clMsg('No pudimos conectar. Inténtalo más tarde.'); el.disabled = false; return; }
      if (CL.promote) { CL.pend = { obj: clSnap(), meta: { at: Date.now(), plat: syncDevice().plat }, mode: 'replace', code: code }; CL.ui = { step: 'preview', err: '' }; clSheet(); }
      else { CL.ui = { step: 'replacepick', code: code, err: '' }; clSheet(); }
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  }
  else if (a === 'wipego') {
    const code = (($('#clCode') || {}).value || '').replace(/\s/g, ''); if (!/^\d{6}$/.test(code)) { clMsg('Escribe el código completo.'); return; }
    el.disabled = true; try {
      const empty = migrate(clone(EMPTY)); empty.demo = false;
      const r = await clReplace(empty, code);
      if (r.s === 400) { clMsg('Código incorrecto o vencido.'); el.disabled = false; return; }
      if (r.s !== 200) { clMsg('No pudimos conectar. Inténtalo más tarde.'); el.disabled = false; return; }
      const run = CL.wipe; CL.wipe = null; clPageHide(); if (run) run(); clDone(r.j.rev, data);
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  }
  else if (a === 'rgo') { el.disabled = true; await clFileGo(); el.disabled = false; }
  else if (a === 'rother') { CL.loadMode = (CL.pend || {}).mode; $('#clfile').click(); }
  else if (a === 'rback') { const P = CL.pend || {}; CL.pend = null; CL.ui = P.mode === 'tour' ? { step: 'tour', i: P.tourI == null ? 3 : P.tourI } : P.code ? { step: 'replacepick', code: P.code, err: '' } : { step: 'done' }; if (P.mode !== 'tour' && !P.code) { clPageHide(); closeSheet(); } else clSheet(); }
  else if (a === 'rpick') { CL.loadMode = 'replace'; $('#clfile').click(); }
  else if (a === 'replace') {
    const code = (($('#clCode') || {}).value || '').replace(/\s/g, ''); if (!/^\d{6}$/.test(code)) { clMsg('Escribe el código completo.'); return; }
    el.disabled = true; try {
      const r = await clReplace(u.obj, code);
      if (r.s === 400) { clMsg('Código incorrecto o vencido.'); el.disabled = false; return; }
      if (r.s !== 200) { clMsg('No pudimos conectar. Inténtalo más tarde.'); el.disabled = false; return; }
      clUpDone(u.obj, r.j.rev, 'Archivo cargado y copia reemplazada');
      if (CL.fromProf) { CL.fromProf = false; openProfile(); } else closeSheet();
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  }
  else if (a === 'wljoin') {
    el.disabled = true; try {
      const r = await fetch(PLATA_CLOUD_API + '/waitlist', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: u.email, src: 'app', lang: String(resolveLang() || 'es').slice(0, 2), plat: syncDevice().plat, website: '' }) });
      if (r.status === 429) { clMsg('Demasiados intentos. Prueba en una hora.'); el.disabled = false; return; }
      if (!r.ok) throw new Error('http');
      try { localStorage.setItem('plata.cloudwl', '1'); } catch (e) { /* sin almacenamiento */ }
      CL.ui = { step: 'listed', email: u.email, fresh: true }; clSheet();
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  }
  else if (a === 'wlback') { CL.ui = { step: 'email', email: u.email }; clSheet(); }
  else if (a === 'gonex') clGoneClear();
  else if (a === 'open') { clGoneClear(); CL.fromProf = !!ui.profSheet; CL.ui = { step: 'email' }; clSheet(); }
  else if (a === 'start' || a === 'resend') {
    const em = a === 'start' ? (($('#clEmail') || {}).value || '').trim().toLowerCase() : u.email;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(em)) { clMsg('Escribe un correo válido.'); return; }
    el.disabled = true; try {
      const r = await clFetch('/auth/start', 'POST', { email: em, lang: String(resolveLang() || 'es').slice(0, 2) });
      if (r.s === 429) clMsg('Demasiados intentos. Prueba en una hora.'); else if (r.s !== 200) clMsg('No pudimos conectar. Inténtalo más tarde.'); else if (r.j && r.j.access === false) { CL.ui = { step: r.j.listed ? 'listed' : 'nolist', email: em }; clSheet(); } else { CL.ui = { step: 'code', email: em }; clSheet(); if (a === 'resend') toast('Te mandamos otro código'); }
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  } else if (a === 'verify') {
    const code = (($('#clCode') || {}).value || '').replace(/\s/g, ''); if (!/^\d{6}$/.test(code)) { clMsg('Escribe el código completo.'); return; }
    el.disabled = true; try {
      const r = await clFetch('/auth/verify', 'POST', { email: u.email, code: code, dev: syncDevice().plat });
      if (r.s !== 200 || !r.j.token) { clMsg('Código incorrecto o vencido.'); el.disabled = false; return; }
      if (CL.st.email && CL.st.email !== u.email) clWipe();
      CL.st.tok = r.j.token; CL.st.email = u.email; clSave();
      if (r.j.hasKey) { if (CL.st.seed && CL.st.kc === r.j.kc) await clAuthDone(); else { CL.st.seed = ''; CL.ui = { step: 'enter', kc: r.j.kc, email: u.email }; clSheet(); } }
      else { const seed = PCC.newSeed(); CL.ui = { step: 'newkey', seed: seed, wl: phraseLang(), words: await PCC.toPhrase(seed, phraseLang()), email: u.email }; clSheet(); }
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  } else if (a === 'link') {
    const em = (($('#clEmail') || {}).value || '').trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(em)) { clMsg('Escribe un correo válido.'); return; }
    el.disabled = true; try {
      const k = await PCC.linkNew(), rid = PCC.b64u(crypto.getRandomValues(new Uint8Array(24))), tz = (Intl.DateTimeFormat().resolvedOptions().timeZone || '');
      const r = await clFetch('/link/start', 'POST', { email: em, pub: k.pub, rid: rid, plat: syncDevice().plat, tz: tz, lang: String(resolveLang() || 'es').slice(0, 2) });
      if (r.s === 429) clMsg('Demasiados intentos. Prueba en una hora.'); else if (r.s !== 200) clMsg('No pudimos conectar. Inténtalo más tarde.');
      else if (r.j && r.j.access === false) { CL.ui = { step: r.j.listed ? 'listed' : 'nolist', email: em }; clSheet(); }
      else { CL.lk = k.priv; CL.ui = { step: 'linkwait', email: em, pub: k.pub, rid: rid, code: '', t0: Date.now() }; clSheet(); clLinkWait(); }
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  } else if (a === 'lkcancel' || a === 'linkmail') { clearInterval(CL.lp); CL.lk = null; CL.ui = { step: 'email', email: u.email }; clSheet(); }
  else if (a === 'lkok') { const L = CL.link; if (L && L.code) askConfirm('¿Aprobar este dispositivo?', 'Solo apruébalo si fuiste tú y el código es exactamente el mismo que ves en el dispositivo nuevo.', [{ label: 'Aprobar ' + L.code.slice(0, 3) + ' ' + L.code.slice(3), fn: () => clLinkAnswer(true, L) }]); }
  else if (a === 'lkno') clLinkAnswer(false);
  else if (a === 'saved') { const pos = []; while (pos.length < 3) { const x = Math.floor(Math.random() * 12); if (pos.indexOf(x) < 0) pos.push(x); } pos.sort((x, y) => x - y); u.pos = pos; u.step = 'quiz'; u.err = ''; clSheet(); }
  else if (a === 'back') { u.step = 'newkey'; clSheet(); }
  else if (a === 'quiz') {
    const ok = [].every.call(document.querySelectorAll('.clq'), (i) => PCC.wordIdx(i.value, u.wl) === PCC.wordIdx(u.words[Number(i.dataset.p)], u.wl) && PCC.wordIdx(i.value, u.wl) >= 0);
    if (!ok) { clMsg('Alguna palabra no coincide. Revisa tu frase.'); return; }
    el.disabled = true; try {
      const kc = await PCC.keyCheck(u.seed), r = await clFetch('/me/key', 'PUT', { kc: kc }, { 'X-Plata-Write': await PCC.writeKey(u.seed) });
      if (r.s === 200 || r.s === 409) { CL.st.seed = PCC.b64u(u.seed); CL.st.kc = kc; CL.key = null; if (r.s === 200) CL.st.v2 = 1; await clAuthDone(true); } else clMsg('No pudimos guardar la clave. Inténtalo otra vez.');
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  } else if (a === 'enter') {
    const txt = (($('#clPhrase') || {}).value || ''), seed0 = await PCC.fromPhrase(txt);
    if (!seed0) { clMsg('La frase no es válida. Revisa que sean 12 palabras y que estén bien escritas.'); return; }
    const seed = await PCC.fromPhrase(txt, u.kc) || seed0, kc = await PCC.keyCheck(seed); if (kc !== u.kc) { clMsg('Esa frase no corresponde a esta cuenta.'); return; }
    CL.st.seed = PCC.b64u(seed); CL.st.kc = kc; CL.key = null; clSave(); await clAuthDone();
  } else if (a === 'f') clFirstPick(p[1]);
  else if (a === 'sync') { clSync('manual'); }
  else if (a === 'menu') askConfirm('Plata Cloud', CL.st.email || '', [{ label: 'Ver frase de recuperación', fn: () => clAct('phrase', el) }, { label: 'Cerrar sesión', fn: () => clAct('out', el) }, { label: 'Cerrar sesión en otros dispositivos', fn: () => clAct('outall', el) }].concat((typeof navigator !== 'undefined' && navigator.onLine === false) ? [] : [{ label: 'Borrar datos de la nube', dest: true, fn: () => clAct('wipe', el) }]).concat([{ label: 'Borrar cuenta', dest: true, fn: () => clAct('del', el) }]));
  else if (a === 'wipe') askConfirm('¿Borrar los datos de la nube?', 'Se borra la copia que Plata Cloud guarda de tus datos (y su respaldo). Tu cuenta sigue activa y los datos de este dispositivo no se tocan, pero pasarás al modo Local. No se puede deshacer. Antes te pediremos 3 palabras de tu frase de recuperación.', [{ label: 'Continuar', dest: true, fn: async () => {
    const pos = []; while (pos.length < 3) { const x = Math.floor(Math.random() * 12); if (pos.indexOf(x) < 0) pos.push(x); } pos.sort((x, y) => x - y);
    CL.fromProf = !!ui.profSheet; CL.ui = { step: 'wipeq', pos: pos, wl: phraseLang(), words: await PCC.toPhrase(PCC.unb64u(CL.st.seed), phraseLang()), err: '' }; clSheet();
  } }]);
  else if (a === 'wipeok') {
    const ok = [].every.call(document.querySelectorAll('.clq'), (i) => PCC.wordIdx(i.value, u.wl) === PCC.wordIdx(u.words[Number(i.dataset.p)], u.wl) && PCC.wordIdx(i.value, u.wl) >= 0);
    if (!ok) { clMsg('Alguna palabra no coincide. Revisa tu frase.'); return; }
    clClose(); setTimeout(clWipeRun, 250);
  }
  else if (a === 'phrase') { CL.fromProf = !!ui.profSheet; askConfirm('Ver tu frase de recuperación', 'Asegúrate de que nadie más esté mirando tu pantalla.', [{ label: 'Mostrar', fn: async () => { CL.ui = { step: 'show', words: await PCC.toPhrase(PCC.unb64u(CL.st.seed), phraseLang()) }; clSheet(); } }]); }
  else if (a === 'mode') {
    const to = p[1], wait = Math.ceil((CL_COOL - (Date.now() - (CL.st.modeAt || 0))) / 1000);
    if (to === CL.st.mode) return;
    if (CL.st.modeAt && wait > 0) { toast('Espera ' + wait + ' s para volver a cambiar de modo'); return; }
    const go = () => { CL.st.mode = to; CL.st.modeAt = Date.now(); clSave(); clRefresh(); if (to === 'cloud') setTimeout(() => clSync('mode'), 200); setTimeout(clRefresh, CL_COOL + 200); };
    if (to === 'cloud') askConfirm('¿Activar Plata Cloud?', 'Los datos de este dispositivo se sincronizarán, cifrados, con tu cuenta.', [{ label: 'Activar', fn: go }]);
    else askConfirm('¿Volver al modo local?', 'Este dispositivo deja de sincronizarse. Tus datos se quedan aquí y la copia de la nube se conserva.', [{ label: 'Pasar a local', fn: go }]);
  } else if (a === 'out') askConfirm('¿Cerrar sesión?', 'Este dispositivo deja de sincronizarse y olvida tu frase. Tus datos locales se quedan, y para volver a entrar necesitarás el código del correo y tu frase.', [{ label: 'Cerrar sesión', fn: async () => { try { await clFetch('/auth/logout', 'POST'); } catch (e) { /* sin red */ } clWipe(); clRefresh(); toast('Sesión cerrada'); if ($('#welcome') && !ui.w) { try { welcomeHTML(); } catch (e) { /* sin bienvenida */ } } } }]);
  else if (a === 'outall') askConfirm('¿Cerrar sesión en tus otros dispositivos?', 'Úsalo si perdiste un dispositivo o crees que alguien más entró. Este dispositivo sigue con sesión; en los demás habrá que volver a entrar.', [{ label: 'Cerrar las demás', dest: true, fn: async () => {
    try { const r = await clFetch('/auth/logout-all', 'POST', { dev: syncDevice().plat }); if (r.s === 200 && r.j.token) { CL.st.tok = r.j.token; clSave(); toast('Listo: cerramos tus otras sesiones'); } else toast('No pudimos cerrar las sesiones. Inténtalo más tarde.'); } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); } } }]);
  else if (a === 'del') askConfirm('¿Borrar tu cuenta?', 'Se borran tu cuenta y tu copia en la nube. Los datos de este dispositivo no se tocan. No se puede deshacer. Te enviaremos un código de verificación a tu correo.', [{ label: 'Enviar código', dest: true, fn: async () => {
    try { const r = await clFetch('/sync/confirm', 'POST', { kind: 'delete', lang: String(resolveLang() || 'es').slice(0, 2) }); if (r.s === 429) { toast('Demasiados intentos. Prueba en una hora.'); return; } if (r.s !== 200) { toast('No pudimos enviar el código. Inténtalo más tarde.'); return; } } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); return; }
    CL.fromProf = !!ui.profSheet; CL.ui = { step: 'delcode', err: '' }; clSheet(); } }]);
  else if (a === 'delgo') {
    const code = (($('#clCode') || {}).value || '').replace(/\s/g, ''); if (!/^\d{6}$/.test(code)) { clMsg('Escribe el código completo.'); return; }
    el.disabled = true; try {
      const r = await clFetch('/account', 'DELETE', { code: code });
      if (r.s === 400) { clMsg('Código incorrecto o vencido.'); el.disabled = false; return; }
      if (r.s !== 200) { clMsg('No pudimos conectar. Inténtalo más tarde.'); el.disabled = false; return; }
      clWipe(); clRefresh(); clPageHide(); if (CL.fromProf) { CL.fromProf = false; openProfile(); } else closeSheet(); toast('Cuenta borrada');
    } catch (e) { clMsg('No pudimos conectar. Inténtalo más tarde.'); } el.disabled = false;
  }
  else if (a === 'pull') { demoExit(); if (clIn()) { CL.st.last = 0; clSave(); setTimeout(() => clSync('demo'), 400); } }
}
(function () {
  /* Si la sesión de Plata Cloud llegó por la mudanza desde el dominio viejo, la persona confirma que la cuenta es suya antes de sincronizar:
   * así, aunque alguien hubiera manipulado el dominio viejo, sus datos no se suben a una cuenta ajena. */
  let mud = false; try { mud = !!localStorage.getItem('plata.mudanza.cloud'); } catch (e) { /* sin almacenamiento */ }
  if (mud && clIn()) {
    CL.hold = true;
    const done = () => { try { localStorage.removeItem('plata.mudanza.cloud'); } catch (e) { /* sin almacenamiento */ } CL.hold = false; };
    setTimeout(() => askConfirm('¿Esta cuenta de Plata Cloud es tuya?', 'Plata se mudó a web.plataapp.net y trajo tu sesión: ' + (CL.st.email || '') + '. Si no reconoces este correo, toca "No es mía".', [{ label: 'Sí, es mía', fn: () => { done(); clSync('open'); } }, { label: 'No es mía', dest: true, fn: () => { done(); clWipe(); clRefresh(); toast('Sesión cerrada'); } }], '', 'Decidir después'), 1200);
  } else if (mud) { try { localStorage.removeItem('plata.mudanza.cloud'); } catch (e) { /* sin almacenamiento */ } }
  const go = () => { if (clOn()) clSync('open'); };
  setTimeout(go, 1500);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) go(); });
  window.addEventListener('online', go);
  setInterval(() => { if (!document.hidden && clOn()) clSync('tick'); }, 120000);
  setTimeout(clLinkCheck, 2500);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) clLinkCheck(); });
  setInterval(clLinkCheck, 12000);
})();

function loadStored() {
  try { const s = localStorage.getItem(KEY) || localStorage.getItem('finanzas.v2'); return s ? migrate(JSON.parse(s)) : null; } catch (e) { return null; }
}
let data = loadStored() || migrate(clone(EMPTY));
syncStamp();
const hasDataOf = (o) => !!o && ((o.transactions || []).length + (o.cards || []).length + (o.savings || []).length + (o.subs || []).length + (o.expected_income || []).length + (o.expected_expense || []).length + (o.planned || []).length > 0 || Object.keys(o.budget || {}).length > 0);
const hasData = () => data.transactions.length + data.cards.length + data.savings.length + data.subs.length + data.expected_income.length + data.expected_expense.length + data.planned.length > 0 || Object.keys(data.budget).length > 0;
const ui = { itemId: null, itemKind: null, itemDel: false, txId: null, txDel: false, tab: 'resumen', week: 8, hor: 13, variable: true, mov: 'all', interest: false, sheetType: 'out', sheetCat: 'Comida', sheetAcc: 'bank', dirty: 0, extra: 100, skipPending: false, form: null, confirmId: null };
try { ui.dirty = Number(localStorage.getItem(KEY_DIRTY)) || 0; } catch (e) { /* sin almacenamiento */ }
function updGdot() { const dm = !!(data && data.demo); document.querySelectorAll('.gdot').forEach((g) => { g.classList.toggle('dirty', ui.dirty > 0 && !dm && !(clBeta() && clOn())); g.classList.toggle('demo', dm); g.classList.toggle('gone', clGone() && !dm); }); }
document.addEventListener('DOMContentLoaded', updGdot);
setTimeout(updGdot, 0);
function persist() {
  syncStamp();
  updGdot();
  try { if (data && !data.demo) localStorage.removeItem(STASH_KEY); } catch (e) { /* sin almacenamiento */ }
  try { localStorage.setItem(KEY, JSON.stringify(data)); localStorage.setItem(KEY_DIRTY, String(ui.dirty)); } catch (e) { /* sin almacenamiento */ }
  clDirty();
}
const QD = /[?&]today=(\d{4}-\d{2}-\d{2})/.exec(location.search);
function getToday() {
  if (QD) return pd(QD[1]);
  const n = new Date();
  return new Date(n.getFullYear(), n.getMonth(), n.getDate());
}

