import { describe, it, expect } from 'vitest';
import { tokenSavings } from '../code/main';
describe('tokenSavings', ()=>{
  it('works', ()=>{
    const r = tokenSavings(1000, 223);
    expect(r.saved).toBe(777);
    expect(Number((r.rate*100).toFixed(1))).toBe(77.7);
  });
});
