# bm-number-scanner

Capacitor-плагин: открывает нативный экран камеры и распознаёт номер с помощью OCR
(ML Kit на Android, Vision на iOS). Номер также можно выбрать из галереи.

## Требования

- Capacitor >= 8
- Android: minSdk 24, разрешение `CAMERA`
- iOS: 15+, ключ `NSCameraUsageDescription` в `Info.plist`

## Установка

```bash
npm install bm-number-scanner
npx cap sync
```

## Использование

```ts
import { BmNumberScanner } from 'bm-number-scanner';

try {
  const { value } = await BmNumberScanner.scan({
    pattern: '\\d{10}',
    hint: 'Наведите камеру на номер',
    galleryTitle: 'Загрузить из галереи',
  });
  console.log('Номер:', value);
} catch (e) {
  // Пользователь нажал «Назад» — ошибка с сообщением "cancelled"
}
```

## API

<docgen-index>

* [`scan(...)`](#scan)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### scan(...)

```typescript
scan(options?: ScanOptions | undefined) => Promise<ScanResult>
```

Opens the native camera screen and resolves with the recognized number.
Rejects with message "cancelled" when the user taps back.

| Param         | Type                                                |
| ------------- | --------------------------------------------------- |
| **`options`** | <code><a href="#scanoptions">ScanOptions</a></code> |

**Returns:** <code>Promise&lt;<a href="#scanresult">ScanResult</a>&gt;</code>

--------------------


### Interfaces


#### ScanResult

| Prop        | Type                | Description        |
| ----------- | ------------------- | ------------------ |
| **`value`** | <code>string</code> | Recognized number. |


#### ScanOptions

| Prop               | Type                | Description                                                                                                                       | Default                |
| ------------------ | ------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| **`pattern`**      | <code>string</code> | Regular expression (without slashes) a recognized number must match. Spaces and dashes are removed from the text before matching. | <code>"\\d{6,}"</code> |
| **`hint`**         | <code>string</code> | Hint above the frame. @default "Наведите камеру на номер"                                                                         |                        |
| **`galleryTitle`** | <code>string</code> | Gallery button title. @default "Загрузить из галереи"                                                                             |                        |

</docgen-api>

## Разработка

```bash
npm install
npm run build          # docgen + tsc + rollup
npm run lint           # eslint, prettier, swiftlint
npm run fmt            # автоисправление форматирования
npm run verify         # сборка и проверка iOS, Android и web
```

Структура:

- `src/` — TypeScript-определения и web-заглушка
- `android/` — Java-реализация (`ScannerActivity`, ML Kit)
- `ios/` — Swift-реализация (`ScannerViewController`, Vision)

Подробнее — в [CONTRIBUTING.md](CONTRIBUTING.md).

## Лицензия

MIT © Mansur Rizoev
