import { WebPlugin } from '@capacitor/core';

import type { BmNumberScannerPlugin, ScanResult } from './definitions';

export class BmNumberScannerWeb extends WebPlugin implements BmNumberScannerPlugin {
  async scan(): Promise<ScanResult> {
    throw this.unimplemented('Number scanning is not available on web.');
  }
}
