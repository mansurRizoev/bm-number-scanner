import { registerPlugin } from '@capacitor/core';

import type { BmNumberScannerPlugin } from './definitions';

const BmNumberScanner = registerPlugin<BmNumberScannerPlugin>('BmNumberScanner', {
  web: () => import('./web').then((m) => new m.BmNumberScannerWeb()),
});

export * from './definitions';
export { BmNumberScanner };
