export type Unit = { code:string; name:string; kind:string; base_code:string; factor:number; decimals:number };
export type ItemUnitConfig = { base_unit?:string|null; stock_unit?:string|null; purchase_unit?:string|null; issue_unit?:string|null; pack_qty?:number|null };

export function toBaseQty(qty:number, unit:Unit, item?:ItemUnitConfig):number {
  if (!Number.isFinite(qty)) throw new Error('Quantity tidak valid');
  const pack = item?.pack_qty && item.pack_qty > 0 ? item.pack_qty : 1;
  return qty * unit.factor * (unit.kind === 'count' && unit.code !== unit.base_code ? pack : 1);
}
export function fromBaseQty(baseQty:number, unit:Unit, item?:ItemUnitConfig):number {
  if (!Number.isFinite(baseQty)) throw new Error('Base quantity tidak valid');
  const pack = item?.pack_qty && item.pack_qty > 0 ? item.pack_qty : 1;
  return baseQty / unit.factor / (unit.kind === 'count' && unit.code !== unit.base_code ? pack : 1);
}
export function assertCompatible(baseCode:string, unit:Unit){ if(unit.base_code !== baseCode) throw new Error(`Unit ${unit.code} tidak kompatibel dengan base unit ${baseCode}`); }
