/* Saldos: cómo un movimiento cambia lo que hay en una cuenta o lo que se debe en una tarjeta. */
import { round2 } from './numeros.mjs';

/** El saldo después de un movimiento. `signed` va con signo desde la cuenta (negativo = sale).
 *  En débito se suma tal cual; en crédito el saldo es deuda, así que un gasto (negativo) la sube y un pago (positivo) la baja. */
export const nextBalance = (balance, signed, credit) => round2(credit ? balance - signed : balance + signed);
