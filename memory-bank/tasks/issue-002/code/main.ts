export function tokenSavings(original:number, reduced:number){
  if (original<=0) throw new Error('original>0 required');
  const saved = original - reduced;
  return { saved, rate: saved/original };
}
