export interface ScanOptions {
  /**
   * Regular expression (without slashes) a recognized number must match.
   * Spaces and dashes are removed from the text before matching.
   * @default "\\d{6,}"
   */
  pattern?: string;
  /** Hint above the frame. @default "Наведите камеру на номер" */
  hint?: string;
  /** Gallery button title. @default "Загрузить из галереи" */
  galleryTitle?: string;
}

export interface ScanResult {
  /** Recognized number. */
  value: string;
}

export interface BmNumberScannerPlugin {
  /**
   * Opens the native camera screen and resolves with the recognized number.
   * Rejects with message "cancelled" when the user taps back.
   */
  scan(options?: ScanOptions): Promise<ScanResult>;
}
