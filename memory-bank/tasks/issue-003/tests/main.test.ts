import { describe, it, expect } from 'vitest';
import { add } from '../code/main';
describe('add', () => { it('adds', () => { expect(add(2,3)).toBe(5); }); });
